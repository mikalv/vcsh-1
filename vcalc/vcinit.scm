;;;; vcinit.scm
;;;; Mike Schaeffer
;;
;; vCalc Initialization code

 
(define-package "vcalc"
  (:uses "scheme" "csv")
  (:includes "subrs.scm"
             "utils.scm"
             "standard-windows.scm"
             "colors.scm"
             "formatted-text.scm"
             "core.scm"
             "printer.scm"
             "postfix.scm"
             "keymap.scm"
             "tagged-object.scm"
             "vcalc-commands.scm"
             "default-keymap.scm"
             "vcalc-window.scm"
             )
  (:exports "all-vcalc-commands"
            "choose"
            "command-modes"
            "configure"
            "define-vcalc-command"
            "defconfig"
            "load-time-define"
            "vc-object->f-text"
            "write-vc-object"
            "describe-object"
            "*angle-mode*"
            "*default-base*"
            "*interest-accrual-mode*"
            "interactively-evaluate-objects"
            "*constant-library*"
            "*last-stack*"
            "*redo-stack*"
            "*last-stack-limit*"
            "*last-arguments*"
            "*stack*"
            "*current-window*"
            "*registers*"
            "apply-to-stack"
            "string->vc-object"
            "vc-object->string"
            "edit-text"
            "check-text"
            "keymap-bind-sequence!"
            "*global-keymap*"
            "*busy-keymap*"
            "keymap-describe-sequence!"
            "update"
            "write-to-string"
            "stack-empty?"
            "stack-depth"
            "stack-top"
            "stack-push"
            "stack-pop"
            "stack-ensure-arguments"
            "*number-precision*"
            "*number-format-mode*"
            "*seperator-mode*"
            "objects->postfix-program"
            "*recording-macro*"
            "*current-macro-seq*"
            "vc-error"
            "*register-watch-list*"
            "toggle-key-help"
            "last-key-number"
            "yes-or-no?"
            "copy-object-to-clipboard"
            "get-object-from-clipboard"
            "*vcalc-user-break?*"
            "tag-object"
            "show-console"
            "hide-console"
            ))

(define *debug* #f)

;;;; Bootstrap process

(define (setup-user-package)
  (when (find-package "vcalc-user")
    (delete-package! "vcalc-user"))
  (let ((p (make-package! "vcalc-user")))
    (use-package! "vcalc-commands" p)
    (install-config-variables! p)
    (reset-config-variables!)
    (in-package! p)))

(defconfig *display-console-at-startup* #f)


(define (vcalc-boot-1)
  (init-busy-keymap)
  (init-global-keymap)
  (setup-user-package)
  (init-vcalc-stack-window)
  (maybe-load-persistant-state)
  (ensure-visible-stack-window))

(define (vcalc-boot)
  (let ((minimal-boot? (aand (environment-variable "VCALC_MINIMAL_BOOT")
                             (text->boolean it))))
    (unless minimal-boot?
      (vcalc-boot-1))
    (when (or minimal-boot? *display-console-at-startup*)
      (show-console))))

;;; Initialize I/O to point to the correct places

(set-current-input-port *console-input-port*)
(set-current-error-port *console-error-port*)
(set-current-debug-port *console-error-port*)
(set-current-output-port *console-output-port*)

(define (run)
  ;(set-current-error-port scheme::*console-error-port*)
  ; (set-current-output-port scheme::*console-output-port*)
  (scheme::display-vcsh-banner)
  (vcalc-boot)
  (format #t "; vCalc Started\n\n")
  (repl))