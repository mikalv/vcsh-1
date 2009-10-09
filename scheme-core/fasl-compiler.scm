;;;; fasl-compiler.scm
;;;; June 6th, 2006
;;;; Mike Schaeffer
;;;
;;; A variant of compiler.scm that emits a FASL file, rather than a text file

(define-package "fasl-compiler"
  (:uses "scheme")
  (:exports "compile-file"
            "*verbose*"
            "*output-file-name*"
            "*debug*"
            "*show-meanings*"
            "*show-expansions*"
            "*show-actions*"
            "*files-to-compile*"
            "*initial-package*"
            "*compiler-target-bindings*"))

;;;; Compiler diagnostics

(define *compiler-output-port* (current-error-port))
(define *compiler-error-port* (current-error-port))

(define (trace-message write? . format-args)
  "Write a compiler trace message if <write?> is true. <format-args> are passed
   into format to generate the output text, written to the compiler output port.
   If <write?> is #f, nothing is done."
  (when write?
    (trace-indent *compiler-output-port*)
    (apply format *compiler-output-port* format-args)))

(define (call-with-compiler-tracing trace? label fn . args)
  (let ((trace? (and trace? (list? args))))
    (define (parse-label)
      (cond ((string? label) (values label "TO"))
            ((list? label)
             (case (length label)
               ((0) (values "FROM" "TO"))
               ((1) (values (car label) "TO"))
               (#t (values (car label) (cadr label)))))
            (#t
             (error "Invalid trace label: ~s" label))))
    (define (message prefix label args)
      (when trace?
        (trace-indent *compiler-output-port*)
        (format  *compiler-output-port* "~a ~a:" prefix label)
        (dolist (arg args)
          (format *compiler-output-port* " ~s"arg))
        (newline *compiler-output-port*)))
    (if trace?
        (values-bind (parse-label) (from-label to-label)
          (message ">" from-label args)
          (values-bind (in-trace-level (apply fn args)) results
            (message "<" to-label results)
            (apply values results)))
        (apply fn args))))

;;;; Compiler environment

(define (compiler-evaluate form)
  "Evaluates <form> with *compiler-target-bindings*, signaling a compiler-error in
   the event of a failure."
  (catch 'end-compiler-evaluate
    (trace-message *show-actions* "==> COMPILER-EVALUATE: ~s\n" form)
    (handler-bind  ((runtime-error
                     (if *debug*
                         handle-runtime-error
                         (lambda args
                           (compile-error form "Runtime error while evaluating toplevel form: ~s" args)
                           (throw 'end-compiler-evaluate)))))
      (with-global-environment *compiler-target-bindings*
        (eval form)))))

(define *show-expansions* #f)
(define *show-meanings* #f)
(define *show-actions* #f)
(define *debug* #f)
(define *verbose* #f)
(define *initial-package* "user")

(define *compiler-target-bindings* (scheme::%current-global-environment))
;; (define *compiler-target-bindings* #f)

(define (symbol-value-with-bindings symbol bindings :optional (unbound-value #f))
  (check symbol? symbol)
  (locally-capture (symbol-value symbol-bound?)
      (with-global-environment bindings
          (if (not (symbol-bound? symbol))
              unbound-value
              (symbol-value symbol)))))


;;;; Ways to signal compilation events

(define (compile-warning context-form message . args)
  (signal 'compile-warning context-form message args))

(define (compile-error context-form message . message-args)
  (signal 'compile-error context-form #f message message-args))

(define (compile-fatal-error context-form message . message-args)
  (signal 'compile-error context-form #t message message-args))


;;;; The expander
;;;;
;;;; This is the the initial phase of compilation. It takes raw source s-exprs
;;;; and expands any user macros or special forms into the base language.

(define (apply-expander expander form :optional (bindings #f))
  (call-with-compiler-tracing (and *show-expansions* (pair? form)) '("EXPAND" "INTO")
    (lambda (form)
      (if bindings
          (with-global-environment bindings
            (expander form))
          (expander form)))
    form))

(define (maybe-expand-user-macro form)
  (aif (and (pair? form)
            (symbol? (car form))
            (macro? (symbol-value-with-bindings (car form) *compiler-target-bindings*)))
       (catch 'end-compiler-macroexpand
              (handler-bind
                  ((runtime-error
                    (if *debug*
                        handle-runtime-error
                        (lambda (message args . rest)
                          (compile-error form (format #f "Macro signaled error: ~I" message args) args)
                          (throw 'end-compiler-macroexpand (values #f ()))))))
                (values #t (apply-expander (lambda (form)
                                             ((scheme::%macro-transformer it) form ()))
                                           form
                                           *compiler-target-bindings*))))
       (values #f form)))

(define (fully-expand-user-macros form)
  (values-bind (maybe-expand-user-macro form) (expanded? expanded-form)
    (if expanded?
        (fully-expand-user-macros expanded-form)
        form)))

(define (translate-form-sequence forms allow-definitions?)
  "Translates a sequence of forms into another sequence of forms by removing
   any nested begins or defines."
  ;; Note that this would be an expansion step, were it not for the fact
  ;; that this takes a list of forms and produces a list of forms. (Instead
  ;; of form to form.)
  (define (begin-block? form) (and (pair? form) (eq? (car form) 'begin)))
  (define (define? form) (and (pair? form) (eq? (car form) 'scheme::%define)))
  (define (define-binding-pair form) (cons (cadr form) (cddr form)))

  (let expand-next-form ((remaining-forms forms)
                         (local-definitions ())
                         (body-forms ()))
    (let ((next-form (fully-expand-user-macros (car remaining-forms))))
      (cond
       ((begin-block? next-form)
        (expand-next-form (append (cdr next-form) (cdr remaining-forms) )
                          local-definitions
                          body-forms))
       ((define? next-form)
        (unless allow-definitions?
          (compile-error next-form "Definitions not allowed here."))
        (unless (null? body-forms)
          (compile-error next-form "Local defines must be the first forms in a block."))
        (expand-next-form (cdr remaining-forms)
                          (cons (define-binding-pair next-form) local-definitions)
                          body-forms))
       ((null? remaining-forms)
        (if (null? local-definitions)
            `(,@(map expand-form body-forms))
            (expand-form
             `((letrec ,local-definitions
                 ,@body-forms)))))
       (#t
        (expand-next-form (cdr remaining-forms)
                          local-definitions
                          (append body-forms (cons next-form))))))))


(define (expand-if form)
  (unless (or (length=3? form) (length=4? form))
    (compile-error form "Invalid if, bad length."))
  (map expand-form form))

(define (expand-begin form)
  `(begin ,@(translate-form-sequence (cdr form) #f)))

(define (valid-lambda-list? lambda-list)
  (or (symbol? lambda-list)
      (null? lambda-list)
      (and (pair? lambda-list)
           (symbol? (car lambda-list))
           (valid-lambda-list? (cdr lambda-list)))))

(define (valid-variable-list? vars)
  (or (null? vars)
      (and (pair? vars)
           (symbol? (car vars))
           (valid-variable-list? (cdr vars)))))

(define (expand-%lambda form)
  (unless (or (list? (cadr form)) (null? (cadr form)))
    (compile-error form "Invalid %lambda, expected property list"))
  (unless (valid-lambda-list? (caddr form))
    (compile-error form "Invalid %lambda, bad lambda list"))
  `(scheme::%lambda ,(cadr form) ,(caddr form)
      ,@(translate-form-sequence (cdddr form) #t)))

(define (expand-set! form)
  (unless (length=3? form)
    (compile-error "Invalid set!, bad length." form))
  `(set! ,(cadr form) ,(expand-form (caddr form))))

(define (expand-%extend-env form)
  (unless (>= (length form) 3)
    (compile-error form "Invalid %extend-env, bad length."))
  (unless (valid-variable-list? (cadr form))
    (compile-error form "Invalid %extend-env, bad variable list."))
  (unless (= (length (cadr form) (caddr form)))
    (compile-error form "Invalid %extend-env, number of variables must equal number of bindings."))
  `(scheme::%extend-env ,(cadr form) ,(map expand-form (caddr form))
        ,@(map expand-form (cdddr form))))

(define (expand-list-let form)
  (define (varlist-valid? varlist)
    (cond ((null? varlist) #t)
          ((symbol? varlist) #t)
          ((and (pair? varlist) (symbol? (car varlist))) (varlist-valid? (cdr varlist)))
          (#t #f)))
  (unless (>= (length form) 3)
    (compile-error form "Invalid list-let, bad length."))
  (unless (varlist-valid? (cadr form))
    (compile-error form "Invalid list-let, bad variable list."))
  `(list-let ,(cadr form) ,(expand-form (caddr form))
     ,@(translate-form-sequence (cdddr form) #t)))

(define (parse-eval-when form)
  (unless (> (length form) 2)
    (compile-error form "Incomplete eval-when."))
  (let ((situations (cadr form))
        (forms (cddr form)))
    (unless (and (or (null? situations) (list? situations))
                 (every? #L(member _ '(:compile-toplevel :load-toplevel :execute)) situations))
      (compile-error form "Bad situations list, situations must be :compile-toplevel, :load-toplevel, or :execute."))
    (values situations forms)))

(define (expand-eval-when form)
  (values-bind (parse-eval-when form) (situations forms)
    (if (member :load-toplevel situations)
        `(begin ,@forms)
        #f)))

(define (expand-case form)
  (unless (>= (length form) 3)
    (compile-error form "Invalid case, bad length."))
  (unless (every? (lambda (case-clause)
                    (or (eq? case-clause #t)
                        (eq? case-clause 'else)
                        (and (list? case-clause) (> (length case-clause) 1))))
                  (cddr form))
    ;; REVISIT: a body-less case clause throws a compile error, and it's inscrutible
    (compile-error form "Invalid case, bad clause"))

  `(case ,(cadr form)
     ,@(map (lambda (case-clause)
              `(,(car case-clause) ,@(map expand-form (cdr case-clause))))
            (cddr form))))

(define (expand-cond form)
  (unless (>= (length form) 2)
    (compile-error form "Invalid cond, bad length."))
  (unless (every? (lambda (cond-clause)
                    (or (eq? cond-clause #t)
                        (eq? cond-clause 'else)
                        (list? cond-clause)))
                  (cdr form))
    (compile-error form "Invalid cond, bad clause."))

  `(cond ,@(map (lambda (cond-clause) (map expand-form cond-clause)) (cdr form))))


(define (expand-and/or form)
  `(,(car form) ,@(map expand-form (cdr form))))


(define (form-expander form)
  (cond ((null? form)
         ())
        ((list? form)
         (case (car form)
           ((quote)               form)
           ((or and)              (expand-and/or form))
           ((case)                (expand-case form))
           ((cond)                (expand-cond form))
           ((if)                  (expand-if form))
           ((scheme::%lambda)     (expand-%lambda form))
           ((set!)                (expand-set! form))
           ((begin)               (expand-begin form))
           ((%extend-env) (expand-%extend-env form))
           ((list-let)            (expand-list-let form))
           ((eval-when)           (expand-eval-when form))
           (#t
            (values-bind (maybe-expand-user-macro form) (expanded? expanded-form)
              (cond (expanded?
                     (expand-form expanded-form))
                    ((atom? expanded-form)
                     (expand-form expanded-form))
                    (#t
                     (map expand-form form)))))))
        ((symbol? form) form)
        ((atom? form)   form)
        (#t             (error "Don't know how to expand this form: ~s" form))))

(define (expand-form form)
  (apply-expander form-expander form))

;;;; Form Semantic Analysis

(define (l-list-vars l-list)
  (cond ((null? l-list) ())
        ((atom? l-list) `(,l-list))
        (#t (cons (car l-list) (l-list-vars (cdr l-list))))))

(define (extend-cenv l-list cenv)
  (cons (l-list-vars l-list) cenv))

(define (bound-in-cenv? var cenv)
  (let loop ((rest cenv))
    (cond ((null? rest) #f)
          ((atom? rest) (error "Malformed cenv: ~s" cenv))
          (#t
           (let ((cenv-frame (car rest)))
             (unless (list? cenv-frame)
               (error "Malformed frame ~s in cenv: ~s" cenv-frame cenv))
             (if (memq var (car rest))
                 #t
                 (loop (cdr rest))))))))

(define (meaning-macro-definition defn cenv)
  `(scheme::%macro ,(form-meaning (second defn))))

(define (meaning-function-definition defn cenv)

  (define (code-body-form body-forms)
    "Return a single form that is semantically equivalent to <body-forms>."
    (case (length body-forms)
      ((0) '(values))
      ((1) (first body-forms))
      (#t `(begin ,@body-forms))))

  (unless (and (list? defn) (>= (length defn) 3))
    (error "Invalid function syntax: ~s" defn))
  (list-let (fn-pos p-list l-list . body) defn
    (let ((body-form (form-meaning (code-body-form body)
                                   (extend-cenv l-list cenv))))
      (if (null? cenv)
          (scheme::%closure () (cons l-list body-form) p-list)
          ;; The compiler does not reify closures if they are defined in
          ;; the context of local variables. The interpreter must reify at
          ;; runtime to capture the correct variable bindings in the closure's
          ;; environment.
          `(scheme::%lambda ,p-list ,l-list ,body-form)))))

(define (meaning-function-application form cenv)
  (map #L(form-meaning _ cenv) form))

(define (meaning-selective-evaluation form cenv)
  (cons (car form) (map #L(form-meaning _ cenv) (cdr form))))

(define (meaning-set! form cenv)
  (list-let (fn-pos var val-form) form
    (if (bound-in-cenv? var cenv)
        form ;; local set handled by interpreter
        (scheme::assemble-fast-op :global-set! var (form-meaning val-form cenv)))))

(define (meaning-cond form cenv)
  `(cond ,(cadr form)
     ,@(map (lambda (cond-clause)
              `(,(form-meaning (car cond-clause) cenv)
                ,@(map #L(form-meaning _ cenv) (cdr cond-clause))))
            (cddr form))))

(define (meaning-case form cenv)
  `(case ,(cadr form)
     ,@(map (lambda (case-clause)
              `(,(car case-clause)
                ,@(map #L(form-meaning _ cenv) (cdr case-clause))))
            (cddr form))))

(define (meaning-list-let form cenv)
  (list-let (fn-pos vars val-form . body) form
    `(list-let ,vars ,(form-meaning val-form cenv)
       ,@(map #L(form-meaning _ (extend-cenv vars cenv)) body))))

(define (meaning-%extend-env form cenv)
  `(scheme::%extend-env ,(cadr form) ,(map #L(form-meaning _ cenv) (caddr form))
    ,@(map #L(form-meaning _ cenv) (cdddr form))))

(define (meaning-%define form cenv)
  (list-let (fn-pos name defn) form
    `(scheme::%define ,name ,(form-meaning defn cenv))))

(define (form-meaning form :optional (cenv ()))
  (call-with-compiler-tracing *show-meanings* '("MEANING-OF" "IS")
    (lambda (form)
      (cond ((and (symbol? form) (not (bound-in-cenv? form cenv)))
             (scheme::assemble-fast-op :global-ref form))
            ((atom? form)
             form)
            (#t
             (case (car form)
               ((scheme::%macro)  (meaning-macro-definition form cenv))
               ((scheme::%lambda) (meaning-function-definition form cenv))
               ((or and if begin) (meaning-selective-evaluation form cenv))
               ((cond)            (meaning-cond form cenv))
               ((case)            (meaning-case form cenv))
               ((set!)            (meaning-set! form cenv))
               ((list-let)        (meaning-list-let form cenv))
               ((%extend-env)     (meaning-%extend-env form cenv))
               ((scheme::%define) (meaning-%define form cenv))
               ((quote)           form)
               (#t                (meaning-function-application form cenv))))))
    form))

;;;; Form Compiler

(define (compile-form form)
  (form-meaning (expand-form form)))

;;;; File Compiler

;;; The file reader

(define *compiler-reader* read)
(define *compiler-location-map* #f)


(define (compile-read-error message port port-location)
  (signal 'compile-read-error message port port-location))


(define (port-location-string port :optional (port-location ()))
  (if (null? port-location)
      (format #f "~a(...)" (port-name port))
      (format #f "~a(~a, ~a)" (port-name port) (car port-location) (cdr port-location))))

(define (form-location-string form)
  (aif (and (hash? *compiler-location-map*)
            (hash-ref *compiler-location-map* form #f))
       (port-location-string (car it) (cdr it))
       "(...)"))

(define (compiler-read port)
  (let ((loc (begin
               (flush-whitespace port #t)
               (port-location port))))
    (handler-bind ((read-error (lambda (message port loc)
                                 (compile-read-error message port loc))))
      (dynamic-let ((*location-mapping* *compiler-location-map*)
                    (*package* (with-global-environment *compiler-target-bindings*
                                 *package*)))
        (trace-message *show-actions* "* READ in ~s\n" *package*)
        (*compiler-reader* port #f)))))

;;; The evaluator

(define (compiler-define var val)
  (trace-message *show-actions* "==> COMPILER-DEFINE: ~s := ~s\n" var val)
  (locally-capture (scheme::%define-global)
      (with-global-environment *compiler-target-bindings*
          (scheme::%define-global var val))))

;;; The main loop

(define (form-list-reader forms)
  "Makes a reader for the list of forms <forms>. A reader is a closure
   that returns a form on each call and an eof-object when there are no
   more forms to be read."
  (lambda ()
    (if (null? forms)
        (scheme::%make-eof)
        (let ((form (car forms)))
          (set! forms (cdr forms))
          form))))

(define *output-stream* #f)

(define (process-toplevel-eval-when form load-time-eval? compile-time-eval?)
  (values-bind (parse-eval-when form) (situations forms)
    (let ((load-time-eval? (and load-time-eval? (member :load-toplevel situations)))
          (compile-time-eval? (or (member :compile-toplevel situations)
                                  (and compile-time-eval?
                                       (member :execute-toplevel situations)))))
      (when (or load-time-eval? compile-time-eval?)
        (process-toplevel-forms (form-list-reader forms) load-time-eval? compile-time-eval?)))))




(define (process-toplevel-include form)
  (unless (and (list? form) (length=2? form) (string? (second form)))
    (compile-error #f "Invalid include form: ~s" form))
  (let ((file-spec (second form)))
    (define (file-spec-files)
      (if (wild-glob-pattern? file-spec)
          (directory file-spec)
          (list file-spec)))
    (dolist (filename (file-spec-files))
      (call-with-compiler-tracing *show-actions* '("BEGIN-INCLUDE" "END-INCLUDE")
                                  (lambda (filename)
                                    (when (currently-compiling-file? filename)
                                      (compile-fatal-error #f "Recursive include of ~s while compiling ~s"
                                                           filename *files-currently-compiling*))
                                    (compile-file/simple filename))
        filename))))

(define (process-toplevel-form form load-time-eval? compile-time-eval?)
  (trace-message *show-actions* "* PROCESS-TOPLEVEL-FORM~a~a: ~s\n"
                 (if load-time-eval? " [load-time]" "")
                 (if compile-time-eval? " [compile-time]" "")
                 form)
  (cond ((pair? form)
         (case (car form)
           ((scheme::%define)
            (let ((var (second form))
                  (val (compile-form (third form))))

            ;; error checking here???
            (compiler-define var (compiler-evaluate val))
            (emit-definition var val)))
           ((begin)
            (process-toplevel-forms (form-list-reader (cdr form)) load-time-eval? compile-time-eval?))
           ((include)
            (process-toplevel-include form))
           ((eval-when)
            (process-toplevel-eval-when form load-time-eval? compile-time-eval?))
           (#t
            (values-bind (maybe-expand-user-macro form) (expanded? expanded-form)
              (cond (expanded?
                     (process-toplevel-form expanded-form load-time-eval? compile-time-eval?))
                    (#t
                     (when compile-time-eval?
                       (compiler-evaluate form))
                     (when load-time-eval?
                       (emit-action form *output-stream*))))))))))

(define (process-toplevel-forms reader load-time-eval? compile-time-eval?)
  (let loop ((next-form (reader)))
    (unless (eof-object? next-form)
      (process-toplevel-form next-form load-time-eval? compile-time-eval?)
      (loop (reader)))))

(define (expand-port-forms ip *output-stream*)
  (process-toplevel-forms (lambda () (compiler-read ip)) #t #f))


;;; FASL file generaiton

(define (form->compiled-procedure form)
  "Compute a compiled procedure that evaluates <form> and returns the
   result of that evaluation."
  (compile-form `(lambda () ,form)))

(define (emit-action form *output-stream*)
  (trace-message *show-actions* "==> EMIT-ACTION: ~s\n" form)
  (fasl-write-op scheme::FASL-OP-LOADER-APPLY0 (list (form->compiled-procedure form)) *output-stream*))

(define (evaluated-object? obj)
  "Returns true if <obj> is an object that has specific handling in the scheme
   evaluator. If <obj> evaluates to itself, returns #f."
  (or (scheme::fast-op? obj)
      (symbol? obj)
      (pair? obj)))

(define (emit-definition var val)
  (trace-message *show-actions*"==> EMIT-DEFINITION: ~s := ~s\n" var val)
  (trace-message *verbose* "; defining ~a\n" var)
  (if (evaluated-object? val)
      (fasl-write-op scheme::FASL-OP-LOADER-DEFINEA0 (list var (form->compiled-procedure val)) *output-stream*)
      (fasl-write-op scheme::FASL-OP-LOADER-DEFINEQ (list var val) *output-stream*)))

;;; Error reporting

(define (end-compile-abnormally return-code *output-stream*)
  (abort-fasl-writes *output-stream*)
  (throw 'end-compile-now return-code))

(define (compiler-message context-desc message-type message message-args)
  "Display a compiler message to the compiler error port. <context-desc> is a description
   of the context for the message. <message-type> is the type of message to be written.
   <message> is a format string with the message text and <message-args> is a list of
   arguments to the message format string."
  (format *compiler-error-port* "~a ~a - ~I\n" context-desc message-type message message-args))

(define (compiler-message/form context-form message-type message message-args)
  "Display a compiler message to the compiler error port. <context-form> is a form
   that provides context for the message, if appropriate. <message-type> is the
   type of message to be written. <message> is a format string with the message text
   and <message-args> is a list of arguments to the message format string."
  (compiler-message (form-location-string context-form) message-type message message-args))

;;; Compilation setup


(define *files-currently-compiling* ())

(define (currently-compiling-file? filename)
  (if (any? #L(filename-string=? _ filename) *files-currently-compiling*)
      filename
      #f))

;; TODO: dynamic-let in a specific global environment

(define (compile-file/simple filename)
  ;; REVISIT: Logic to restore *package* after compiling a file. Ideally, this should
  ;; match the behavior of scheme::call-as-loader, although it is unclear how this
  ;; relates to the way we do cross-compilation.
  (let ((original-package (with-global-environment *compiler-target-bindings*
                            *package*)))
    (dynamic-let ((*files-currently-compiling* (cons filename *files-currently-compiling*)))
      (trace-message *verbose* "; Compiling file: ~a\n" filename)
      (with-port input-port (open-input-file filename)
         (fasl-write-op scheme::FASL-OP-BEGIN-LOAD-UNIT (list filename) *output-stream*)
         (expand-port-forms input-port *output-stream*)
         (fasl-write-op scheme::FASL-OP-END-LOAD-UNIT (list filename) *output-stream*)))
    (with-global-environment *compiler-target-bindings*
      (set! *package* original-package))))

(define (compile-file/checked filename)
  (let ((compile-error-count 0))
    (handler-bind ((compile-read-error
                    (lambda (message port port-location)
                      (compiler-message (port-location-string port port-location) :read-error message ())
                      (end-compile-abnormally 1 *output-stream*)))
                   (compile-error
                    (lambda (context-form fatal? message details)
                      (compiler-message/form context-form :error message details)
                      (incr! compile-error-count)
                      (when fatal?
                        (end-compile-abnormally 1 *output-stream*))))
                   (compile-warning
                    (lambda (context-form message args)
                      (compiler-message/form context-form :warning message args))))
      (compile-file/simple filename *output-stream*)
      compile-error-count)))

(defmacro (with-compiler-output-stream os filename . code)
  (with-gensyms (output-port-sym)
    `(with-port ,output-port-sym (open-output-file ,filename :binary)
       (with-fasl-stream ,os ,output-port-sym
         (dynamic-let ((*output-stream* ,os))
           ,@code)))))

(define (compile-files filenames output-file-name)
  (with-compiler-output-stream output-fasl-stream  output-file-name
    (let next-file ((filenames filenames) (error-count 0))
      (cond ((not (null? filenames))
             (next-file (cdr filenames)
                        (+ error-count (compile-file/checked (car filenames)))))
            ((> error-count 0)
             (format *compiler-error-port* "; ~a error(s) detected while compiling.\n" error-count)
             (end-compile-abnormally 2 output-fasl-stream))
            (#t
             ())))))

(define (input-file-name->output-file-name input-filename)
  (cond ((list? input-filename)
         (if (length=1? input-filename)
             (input-file-name->output-file-name (first input-filename))
             "a.scf"))
        ((string? input-filename)
         (string-append (filename-no-extension input-filename) ".scf"))
        (#t
         (error "Invalid input filename: ~s" input-filename))))


(define (compile-file filename :optional (output-file-name #f))
  (let ((output-file-name (cond ((string? output-file-name) output-file-name)
                                ((not output-file-name) (input-file-name->output-file-name filename))
                                (#t (error "Invalid output filename: ~s" filename))))
        (filenames (if (list? filename) filename (list filename))))
    (set! *compiler-location-map* (make-hash :eq))
    (catch 'end-compile-now
      (handler-bind ((runtime-error
                      (if *debug*
                          handle-runtime-error
                          (lambda (message args)
                            ;;(show-runtime-error message args)
                            (format *compiler-error-port*
                                    "\n\n\nINTERNAL COMPILER ERROR!, message=~s\n\targs=~s\n"
                                    message args)
                            (throw 'end-compile-now 127)))))

        (compile-files filenames output-file-name)

        (format *compiler-output-port* "; Compile completed successfully.\n"))
      0)))

