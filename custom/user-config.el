
(progn
  (defun e:setup-font ()
    (interactive)
    ;; エンコーディング設定
    (set-language-environment "Japanese")
    (let ((coding-system 'utf-8))
      (prefer-coding-system          coding-system)
      (set-default-coding-systems    coding-system)
      (set-buffer-file-coding-system coding-system)
      (set-terminal-coding-system    coding-system)
      (set-keyboard-coding-system    coding-system))
    ;; フォント設定
    (let* ((charsets '(japanese-jisx0208
                       japanese-jisx0208-1978
                       japanese-jisx0212
                       japanese-jisx0213-1
                       japanese-jisx0213-2
                       japanese-jisx0213.2004-1
                       japanese-jisx0213-a
                       katakana-jisx0201
                       katakana-sjis))
           (fontspec (font-spec :family e:font-name)))
      (setq face-font-rescale-alist `((,e:font-name . ,e:font-rescale)))
      (set-face-attribute 'default nil :family e:font-name :height e:font-height)
      (dolist (charset charsets)
        (set-fontset-font t charset fontspec)))
    ;; 対策: East Asian Ambiguous Width
    (add-to-list 'load-path (expand-file-name "locale-eaw" e:external-directory))
    (when (require 'eaw nil t)
      (eaw-fullwidth))
    ;;
    t)
  ;; いろいろあったのでこんな感じで
  (add-hook 'window-setup-hook 'e:setup-font))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package core-dotspacemacs
  :config
  (spaceline-define-segment buffer-encoding-abbrev
    "The line ending convention used in the buffer."
    (let ((buf-coding (format "%s" buffer-file-coding-system)))
      (list (replace-regexp-in-string "-with-signature\\|-unix\\|-dos\\|-mac" "" buf-coding)
            (concat (and (string-match "with-signature" buf-coding) "ⓑ")
                    (and (string-match "unix"           buf-coding) "ⓤ")
                    (and (string-match "dos"            buf-coding) "ⓓ")
                    (and (string-match "mac"            buf-coding) "ⓜ")
                    )))
    :separator " "))

(use-package auto-shell-command
  :config
  (progn
    (defun e:ascmd:toggle:after (&rest args)
      (message "ascmd: %s." (if ascmd:active "enabled" "disabled")))
    (advice-add 'ascmd:toggle :after 'e:ascmd:toggle:after))
  (defvar e:ascmd:additional nil)
  (defun e:ascmd:rsync-command (&rest args)
    (let ((result '("rsync"))
          (srcs nil)
          (dest nil)
          (arg nil))
      (while args
        (setq arg (pop args))
        (case arg
          (:src  (push (pop args) srcs))
          (:dest (setq dest (pop args)))
          (:gitignore  (push "--cvs-exclude --filter=\":- .gitignore\"" result))
          (:rsh        (push (format "--rsh=\"%s\""        (pop args)) result))
          (:rsync-path (push (format "--rsync-path=\"%s\"" (pop args)) result))
          (:filter     (push (format "--filter=\"%s\""     (pop args)) result))
          (:include    (push (format "--include=\"%s\""    (pop args)) result))
          (:exclude    (push (format "--exclude=\"%s\""    (pop args)) result))
          (t (push arg result))))
      (format "%s %s %s"
              (s-join " " (reverse result))
              (s-join " " (reverse srcs))
              dest)))
  (defun e:ascmd:exec (command)
    (let ((process-exec-p (ascmd:process-exec-p)))
      (ascmd:add-command-queue command)
      (unless process-exec-p
        (ascmd:shell-deferred command)) t))
  (defun e:helm:ascmd:exec ()
    (interactive)
    (let ((candidates (-concat (-map 'cadr ascmd:setting)
                               e:ascmd:additional)))
      (helm :sources '((name . "ascmd")
                       (candidates . candidates)
                       (action . e:ascmd:exec)))))
  (let ((private-file (expand-file-name "ascmd.el" e:private-directory)))
    (when (file-exists-p private-file)
      (load-file private-file))))

(use-package atomic-chrome
  :config
  (atomic-chrome-start-server))

(use-package display-line-numbers
  :config
  (when (fboundp 'display-line-numbers-mode)
    (defun display-line-numbers-mode-on ()
      "`display-line-numbers-mode'を有効化."
      (interactive)
      (display-line-numbers-mode 1))
    (defun display-line-numbers-mode-off ()
      "`display-line-numbers-mode'を無効化."
      (interactive)
      (display-line-numbers-mode 0))
    (add-hook 'prog-mode-hook 'display-line-numbers-mode-on)
    (add-hook 'find-file-hook 'display-line-numbers-mode-on)
    (add-hook 'html-mode-hook 'display-line-numbers-mode-on)
    (setq-default display-line-numbers-width 4)))

(use-package evil
  :config
  ;; variables
  (progn
    (setq evil-cross-lines t)
    (setq evil-insert-state-map (make-sparse-keymap))
    (setq evil-move-cursor-back nil))
  ;; advices
  (progn
    (defun e:evil-force-normal-state ()
      (when (member evil-state '(insert hybrid visual))
        (evil-force-normal-state)))
    (defun e:save-buffer:after (&rest args)
      (e:evil-force-normal-state))
    (defun e:keyboard-quit:before (&rest args)
      (e:evil-force-normal-state))
    (advice-add 'save-buffer :after 'e:save-buffer:after)
    (advice-add 'keyboard-quit :before 'e:keyboard-quit:before))
  ;; keybindings
  (bind-keys
   ;; モーションモード(motion -> normal -> visual)
   :map evil-motion-state-map
   ("C-^" . nil) ;; evil-buffer
   ;; 通常モード
   :map evil-normal-state-map
   ("<down>" . evil-next-visual-line)
   ("<up>" . evil-previous-visual-line)
   ("j" . evil-next-visual-line)
   ("k" . evil-previous-visual-line)
   ("gj" . evil-next-line)
   ("gk" . evil-previous-line)
   ;; ビジュアルモード
   :map evil-visual-state-map
   ;; 挿入モード
   :map evil-insert-state-map
   ;; オペレーターモード
   :map evil-operator-state-map
   ;; 置き換えモード
   :map evil-replace-state-map
   ;; Emacsモード
   :map evil-emacs-state-map))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package dired
  :defer t
  :config
  (when (e:system-type-darwin-p)
    (cond
     ((executable-find "gls")
      (setq insert-directory-program "gls"))
     ((require 'ls-lisp nil t)
      (setq ls-lisp-use-insert-directory-program nil)
      (setq ls-lisp-dirs-first t))))
  (setq dired-use-ls-dired t)
  (setq dired-listing-switches "-ahl")
  (setq dired-dwim-target t)
  (setq dired-recursive-copies 'always)
  (setq dired-recursive-deletes 'top)
  (use-package wdired
    :config
    (bind-keys
     :map dired-mode-map
     ("e" . wdired-change-to-wdired-mode)))
  (use-package dired-filter
    :config
    (add-hook 'dired-mode-hook 'dired-filter-mode))

  (use-package dired-quick-sort
    :config
    (bind-keys
     :map dired-mode-map
     ("s" . hydra-dired-quick-sort/body))
    (add-hook 'dired-mode-hook 'dired-quick-sort)))

(use-package eww
  :defer t
  :config
  (defvar e:eww-enable-colorize nil)
  (defun e:eww-colorize-region:around (&rest args)
    (when e:eww-enable-colorize
      (apply (car args) (cdr args))))
  (defun e:eww-colorize-on ()
    (interactive)
    (setq-local e:eww-enable-colorize t)
    (eww-reload))
  (defun e:eww-colorize-off ()
    (interactive)
    (setq-local e:eww-enable-colorize nil)
    (eww-reload))
  (advice-add 'eww-colorize-region :around 'e:eww-colorize-region:around)
  (advice-add 'shr-colorize-region :around 'e:eww-colorize-region:around))

(use-package navi2ch
  :load-path "lisp/navi2ch"
  :defer t
  :commands (navi2ch)
  :init
  (setq navi2ch-net-http-proxy "127.0.0.1:9080")
  :config
  (when (require 'prodigy nil t)
    (let ((cmd (expand-file-name "2chproxy.pl/2chproxy.pl" e:external-directory))
          (yml (expand-file-name "2chproxy.yml" e:custom-directory)))
      (when (and (executable-find cmd)
                 (file-exists-p yml))
        (prodigy-define-service
          :name "2chproxy.pl"
          :command (format "%s --config %s" cmd yml)
          :tags '(general)
          :kill-signal 'sigkill)))
    (defun e:prodigy:2chproxy.pl ()
      (interactive)
      (e:prodigy-start-service "2chproxy.pl"))
    (e:prodigy:2chproxy.pl)))

(use-package skk
  :defer t
  :config
  (when (and (executable-find "google-ime-skk")
             (require 'prodigy nil t))
    (prodigy-define-service
      :name "google-ime-skk"
      :command "google-ime-skk"
      :tags '(general)
      :kill-signal 'sigkill)
    (defun e:prodigy:google-ime-skk ()
      (interactive)
      (e:prodigy-start-service "google-ime-skk"))
    (e:prodigy:google-ime-skk))
  (defun e:skk-latin-mode-on:before (&rest args)
    (unless skk-mode-invoked
      (skk-mode-invoke)))
  (require 'skk-study nil t)
  (advice-add 'skk-latin-mode-on :before 'e:skk-latin-mode-on:before)
  (add-hook 'evil-hybrid-state-entry-hook 'skk-latin-mode-on)
  (add-hook 'evil-hybrid-state-exit-hook  'skk-mode-exit))

(use-package tramp
  :defer t
  :init
  (set-variable 'tramp-default-host "localhost")
  (let* ((files (--filter (not (file-directory-p it))
                          (-map 'abbreviate-file-name (directory-files "~/.ssh/conf.d/hosts" t))))
         (functions (--map (list 'tramp-parse-sconfig it) files)))
    (dolist (method '("ssh" "scp"))
      (let ((functions (append (tramp-get-completion-function method) functions)))
        (tramp-set-completion-function method functions)))))

(use-package which-key
  :defer t
  :config
  (setq which-key-idle-delay 1.0)
  (setq which-key-idle-secondary-delay 0.1))
