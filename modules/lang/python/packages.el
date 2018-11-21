;; -*- no-byte-compile: t; -*-
;;; lang/python/packages.el

;; requires: python setuptools

(package! nose)
(package! pip-requirements)
;; Environmet management
(package! pipenv)
(when (featurep! +pyenv)
  (package! pyenv-mode))
(when (featurep! +pyvenv)
  (package! pyvenv))
(when (featurep! +conda)
  (package! conda))

;; Programming environment
;; lsp
(cond ((and (featurep! :tools +lsp)
            (featurep! +lsp))
       (package! lsp-python))
      ((package! anaconda-mode)
       (when (featurep! :completion company)
         (package! company-anaconda))))
