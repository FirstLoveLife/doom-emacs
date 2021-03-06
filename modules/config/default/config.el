;;; config/default/config.el -*- lexical-binding: t; -*-

(defvar +default-minibuffer-maps
  `(minibuffer-local-map
    minibuffer-local-ns-map
    minibuffer-local-completion-map
    minibuffer-local-must-match-map
    minibuffer-local-isearch-map
    read-expression-map
    ,@(if (featurep! :completion ivy) '(ivy-minibuffer-map)))
  "A list of all the keymaps used for the minibuffer.")


;;
;; Reasonable defaults

(after! epa
  (setq epa-file-encrypt-to
        (or epa-file-encrypt-to
            ;; Collect all public key IDs with your username
            (unless (string-empty-p user-full-name)
              (cl-loop for key in (ignore-errors (epg-list-keys (epg-make-context) user-full-name))
                       collect (epg-sub-key-id (car (epg-key-sub-key-list key)))))
            user-mail-address)
        ;; With GPG 2.1, this forces gpg-agent to use the Emacs minibuffer to
        ;; prompt for the key passphrase.
        epa-pinentry-mode 'loopback))


(when (featurep! +smartparens)
  ;; disable :unless predicates with (sp-pair "'" nil :unless nil)
  ;; disable :post-handlers with (sp-pair "{" nil :post-handlers nil)
  ;; ...or specific :post-handlers with (sp-pair "{" nil :post-handlers '(:rem
  ;; ("| " "SPC")))
  (after! smartparens
    ;; Autopair quotes more conservatively; if I'm next to a word/before another
    ;; quote, I likely don't want another pair.
    (let ((unless-list '(sp-point-before-word-p
                         sp-point-after-word-p
                         sp-point-before-same-p)))
      (sp-pair "'"  nil :unless unless-list)
      (sp-pair "\"" nil :unless unless-list))

    ;; Expand {|} => { | }
    ;; Expand {|} => {
    ;;   |
    ;; }
    (dolist (brace '("(" "{" "["))
      (sp-pair brace nil
               :post-handlers '(("||\n[i]" "RET") ("| " "SPC"))
               ;; I likely don't want a new pair if adjacent to a word or opening brace
               :unless '(sp-point-before-word-p sp-point-before-same-p)))

    ;; Major-mode specific fixes
    (sp-local-pair '(ruby-mode enh-ruby-mode) "{" "}"
                   :pre-handlers '(:rem sp-ruby-pre-handler)
                   :post-handlers '(:rem sp-ruby-post-handler))

    ;; Don't do square-bracket space-expansion where it doesn't make sense to
    (sp-local-pair '(emacs-lisp-mode org-mode markdown-mode gfm-mode)
                   "[" nil :post-handlers '(:rem ("| " "SPC")))

    ;; Reasonable default pairs for comments
    (sp-local-pair (append sp--html-modes '(markdown-mode gfm-mode))
                   "<!--" "-->" :actions '(insert) :post-handlers '(("| " "SPC")))

    ;; Expand C-style doc comment blocks
    (defun +default-expand-doc-comment-block (&rest _ignored)
      (let ((indent (current-indentation)))
        (newline-and-indent)
        (save-excursion
          (newline)
          (insert (make-string indent 32) " */")
          (delete-char 2))))
    (sp-local-pair
     '(js2-mode typescript-mode rjsx-mode rust-mode c-mode c++-mode objc-mode
       java-mode php-mode css-mode scss-mode less-css-mode stylus-mode)
     "/*" "*/"
     :actions '(insert)
     :post-handlers '(("| " "SPC") ("|\n*/[i][d-2]" "RET") (+default-expand-doc-comment-block "*")))

    ;; Highjacks backspace to:
    ;;  a) balance spaces inside brackets/parentheses ( | ) -> (|)
    ;;  b) delete space-indented `tab-width' steps at a time
    ;;  c) close empty multiline brace blocks in one step:
    ;;     {
    ;;     |
    ;;     }
    ;;     becomes {|}
    ;;  d) refresh smartparens' :post-handlers, so SPC and RET expansions work
    ;;     even after a backspace.
    ;;  e) properly delete smartparen pairs when they are encountered, without
    ;;     the need for strict mode.
    ;;  f) do none of this when inside a string
    (advice-add #'delete-backward-char :override #'doom/delete-backward-char)

    ;; Makes `newline-and-indent' smarter when dealing with comments
    (advice-add #'newline-and-indent :around #'doom*newline-indent-and-continue-comments)))


;;
;; Keybinding fixes

;; This section is dedicated to "fixing" certain keys so that they behave
;; sensibly (and consistently with similar contexts).

;; Make SPC u SPC u [...] possible (#747)
(map! :map universal-argument-map
      :prefix doom-leader-key     "u" #'universal-argument-more
      :prefix doom-leader-alt-key "u" #'universal-argument-more)

(defun +default|setup-input-decode-map ()
  "Ensure TAB and [tab] are treated the same in TTY Emacs."
  (define-key input-decode-map (kbd "TAB") [tab]))
(add-hook 'tty-setup-hook #'+default|setup-input-decode-map)

;; Restore CUA keys in minibuffer
(define-key! :keymaps +default-minibuffer-maps
  [escape] #'abort-recursive-edit
  "C-v"    #'yank
  "C-z"    (λ! (ignore-errors (call-interactively #'undo)))
  "C-a"    #'move-beginning-of-line
  "C-b"    #'backward-word
  ;; A Doom convention where C-s on popups and interactive searches will invoke
  ;; ivy/helm for their superior filtering.
  "C-s"    (if (featurep! :completion ivy)
               #'counsel-minibuffer-history
             #'helm-minibuffer-history))

;; Consistently use q to quit windows
(after! tabulated-list
  (define-key tabulated-list-mode-map "q" #'quit-window))

;; OS specific fixes
(when IS-MAC
  ;; Fix MacOS shift+tab
  (define-key input-decode-map [S-iso-lefttab] [backtab])
  ;; Fix frame-switching key on MacOS
  (global-set-key (kbd "M-`") #'other-frame))


;;
;; Doom's keybinding scheme

(when (featurep! +bindings)
  ;; Make M-x more accessible
  (define-key! 'override
    "M-x"  #'execute-extended-command
    "A-x"  #'execute-extended-command)

  (define-key!
    ;; Buffer-local font scaling
    "M-+" (λ! (text-scale-set 0))
    "M-=" #'text-scale-increase
    "M--" #'text-scale-decrease
    ;; Simple window/frame navigation/manipulation
    "M-w" #'delete-window
    "M-W" #'delete-frame
    "M-n" #'+default/new-buffer
    "M-N" #'make-frame
    ;; Restore OS undo, save, copy, & paste keys (without cua-mode, because
    ;; it imposes some other functionality and overhead we don't need)
    "M-z" #'undo
    "M-s" #'save-buffer
    "M-c" (if (featurep 'evil) 'evil-yank 'copy-region-as-kill)
    "M-v" #'yank
    ;; Textmate-esque bindings
    "M-a" #'mark-whole-buffer
    "M-b" #'+default/compile
    "M-f" #'swiper
    "M-q" (if (daemonp) #'delete-frame #'evil-quit-all)
    ;; textmate-esque newline insertion
    [M-return]    #'evil-open-below
    [M-S-return]  #'evil-open-above
    ;; textmate-esque deletion
    [M-backspace] #'doom/backward-kill-to-bol-and-indent)

  ;; Smarter C-a/C-e for both Emacs and Evil. C-a will jump to indentation.
  ;; Pressing it again will send you to the true bol. Same goes for C-e, except
  ;; it will ignore comments+trailing whitespace before jumping to eol.
  (map! :gi "C-a" #'doom/backward-to-bol-or-indent
        :gi "C-e" #'doom/forward-to-last-non-comment-or-eol)

  (if (featurep 'evil)
      (load! "+evil-bindings")
    (load! "+emacs-bindings")))
