;; -*- no-byte-compile: t; -*-
;;; lang/haskell/packages.el

(package! haskell-mode)
(package! hindent)

;;
(cond
 ((featurep! +lsp) (depends-on! :tools lsp)
  (package! lsp-haskell)))
 ((featurep! +dante)
       (package! dante)
       (when (featurep! :completion company)
         (package! company-ghc)))
      (t
       (package! intero)
       (package! hindent))
