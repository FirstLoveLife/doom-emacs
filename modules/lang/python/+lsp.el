;;; lang/python/+lsp.el -*- lexical-binding: t; -*-
;;;###if (featurep! +lsp)

(after! python
  ;; dir containing Microsoft.Python.LanguageServer.dll
  (setq ms-pyls-dir (expand-file-name "~/.emacs.d/.local/python-language-server/output/bin/Release/"))

  ;; this gets called when we do lsp-describe-thing-at-point in lsp-methods.el
  ;; we remove all of the "&nbsp;" entities that MS PYLS adds this is mostly
  ;; harmless for other language servers
  (defun render-markup-content (kind content)
    (message kind)
    (replace-regexp-in-string "\_" "_"
                              (replace-regexp-in-string "&nbsp;" " " content)))
  (setq lsp-render-markdown-markup-content #'render-markup-content)

  ;; it's crucial that we send the correct Python version to MS PYLS, else it
  ;; returns no docs in many cases furthermore, we send the current Python's
  ;; (can be virtualenv) sys.path as searchPaths
  (defun get-python-ver-and-syspath (workspace-root)
    "return list with pyver-string and json-encoded list of python search paths."
    (let ((python (executable-find python-shell-interpreter))
          (ver "import sys; print(\"%s.%s\" % (sys.version_info[0], sys.version_info[1]));")
          (sp (concat "import json; sys.path.insert(0, '" workspace-root "'); print(json.dumps(sys.path))")))
      (with-temp-buffer
        (call-process python nil t nil "-c" (concat ver sp))
        (subseq (split-string (buffer-string) "\n") 0 2))))

  ;; I based most of this on the vs.code implementation:
  ;; https://github.com/Microsoft/vscode-python/blob/master/src/client/activation/languageServer/languageServer.ts#L219
  ;; (it still took quite a while to get right, but here we are!)
  (defun ms-pyls-extra-init-params (workspace)
    (destructuring-bind (pyver pysyspath) (get-python-ver-and-syspath (lsp--workspace-root workspace))
      `(:interpreter (
                      :properties (
                                   :InterpreterPath ,(executable-find python-shell-interpreter)
                                   :DatabasePath ,ms-pyls-dir
                                   :Version ,pyver))
                     ;; preferredFormat "markdown" or "plaintext"
                     ;; experiment to find what works best -- over here mostly plaintext
                     :displayOptions (
                                      :preferredFormat "plaintext"
                                      :trimDocumentationLines :json-false
                                      :maxDocumentationLineLength 0
                                      :trimDocumentationText :json-false
                                      :maxDocumentationTextLength 0)
                     :searchPaths ,(json-read-from-string pysyspath))))

  (lsp-define-stdio-client lsp-python "python"
                           #'projectile-project-root
                           `("dotnet" ,(concat ms-pyls-dir
                                               "Microsoft.Python.LanguageServer.dll"))
                           :extra-init-params #'ms-pyls-extra-init-params)
  ;; lsp-python-enable is created by macro above
  (add-hook 'python-mode-hook
            (lambda ()
              (lsp-python-enable))))
