
;;;; compiler-meaning.scm --
;;;;
;;;; The semantic analysis phase. This maps basic lisp into an
;;;; s-expression tree of fast-op assembler instructinos.
;;;;
;;;; (C) Copyright 2001-2011 East Coast Toolworks Inc.
;;;; (C) Portions Copyright 1988-1994 Paradigm Associates Inc.
;;;;
;;;; See the file "license.terms" for information on usage and
;;;; redistribution of this file, and for a DISCLAIMER OF ALL
;;;; WARRANTIES.

(define *show-meanings* #f)

(define (l-list-vars l-list)
  (let retry ((l-list l-list))
    (cond ((null? l-list)
           ())
          ((atom? l-list)
           `(,l-list))
          (#t
           (cons (car l-list) (retry (cdr l-list)))))))

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

(define expanded-form-meaning) ; forward decl

(define (symbol-binding-type-of sym)
  (if (symbol-bound? sym)
      (type-of (symbol-value sym))
      '#f))

(define (warn-if-global-unbound var)
  (unless (symbol-bound? var)
    (compile-warning var "Global variable unbound: ~s" var)))

(define (meaning/application form cenv)
  `(:apply ,(expanded-form-meaning (car form) cenv)
           ,(map #L(expanded-form-meaning _ cenv) (cdr form))))

(define (meaning/symbol form cenv)
  (cond ((keyword? form)
         `(:literal ,form))
        ((bound-in-cenv? form cenv)
         `(:local-ref ,form))
        (#t
         (warn-if-global-unbound form)
         `(:global-ref ,form))))

(define *special-form-handlers* #h(:eq))

(define (special-form-symbols)
  ;; REVISIT: Currently unioning in toplevel special forms and type names... need to do something better
  (hash-keys *special-form-handlers*))

(defmacro (define-special-form pattern . code)
  (check pair? pattern)
  (check symbol? (car pattern))
  `(eval-when (:compile-toplevel :load-toplevel :execute)
     (hash-push! *special-form-handlers* ',(car pattern)
                 (cons (lambda (form)
                         (and (pair? form)
                              (dbind-matches? ,(cdr pattern) (cdr form))))
                       (lambda (form cenv)
                         (dbind ,(cdr pattern) (cdr form)
                           ,@code))))))

(define-special-form (scheme::%lambda p-list l-list . body)
  (define (code-body-form body-forms)
    "Return a single form that is semantically equivalent to <body-forms>."
    (case (length body-forms)
      ((0) '(values))
      ((1) (first body-forms))
      (#t `(begin ,@body-forms))))
  `(:closure (,l-list . ,p-list)
               ,(expanded-form-meaning (code-body-form body)
                                       (extend-cenv l-list cenv))))


(define-special-form (begin . args)
  (let recur ((args args))
    (cond ((null? args)
           `(:literal ()))
          ((length=1? args)
           (expanded-form-meaning (car args) cenv))
          (#t
           `(:sequence
             ,(expanded-form-meaning (car args) cenv)
             ,(recur (cdr args)))))))

(define-special-form (or . args)
  (let recur ((args args))
    (cond ((null? args)
           `(:literal #f))
          ((length=1? args)
           (expanded-form-meaning (car args) cenv))
          (#t
           `(:sequence
             ,(expanded-form-meaning (car args) cenv)
             (:if-true
              (:retval)
              ,(recur (cdr args))))))))

(define-special-form (and . args)
  (let recur ((args args))
    (cond ((null? args)
           `(:literal #t))
          ((length=1? args)
           (expanded-form-meaning (car args) cenv))
          (#t
           `(:sequence
             ,(expanded-form-meaning (car args) cenv)
             (:if-true
              ,(recur (cdr args))
              (:literal #f)))))))

(define-special-form (if cond-form then-form)
  `(:sequence
    ,(expanded-form-meaning cond-form cenv)
    (:if-true
     ,(expanded-form-meaning then-form cenv)
     (:literal ()))))

(define-special-form (if cond-form then-form else-form)
  `(:sequence
    ,(expanded-form-meaning cond-form cenv)
    (:if-true
     ,(expanded-form-meaning then-form cenv)
     ,(expanded-form-meaning else-form cenv))))

(define-special-form (set! var val-form)
  (cond ((keyword? var)
         (compile-error form "Cannot rebind a keyword: ~s" var))
        ((bound-in-cenv? var cenv)
         `(:sequence
           ,(expanded-form-meaning val-form cenv)
           (:local-set! ,var)))
        (#t
         (warn-if-global-unbound var)
         `(:sequence
           ,(expanded-form-meaning val-form cenv)
           (:global-set! ,var)))))

(define compile)

(define-special-form (scheme::%define name defn)
  `(:global-def ,name
                ,((compile defn))))

(define-special-form (quote value)
  `(:literal ,value))

(define-special-form (the-environment)
  `(:get-env))

(define-special-form (scheme::%preserve-initial-fsp global-var body-form)
  (warn-if-global-unbound global-var)
  `(:sequence
    (:sequence
     (:get-fsp)
     (:global-set! ,global-var))
    ,(expanded-form-meaning body-form cenv)))

(define-special-form (scheme::%preserve-initial-frame global-var body-form)
  (warn-if-global-unbound global-var)
  `(:global-preserve-frame
    ,global-var
    ,(expanded-form-meaning body-form cenv)))

(define-special-form (scheme::%%catch tag-form body-form)
  `(:catch
    ,(expanded-form-meaning tag-form cenv)
    ,(expanded-form-meaning body-form cenv)))

(define-special-form (scheme::%%throw tag-form value-form)
  `(:throw
    ,(expanded-form-meaning tag-form cenv)
    ,(expanded-form-meaning value-form cenv)))

(define-special-form (scheme::%%with-unwind-fn after-fn-form body-form)
  `(:with-unwind-fn
    ,(expanded-form-meaning after-fn-form cenv)
    ,(expanded-form-meaning body-form cenv)))

(define-special-form (scheme::%%get-fsp)
  `(:get-fsp))

(define-special-form (scheme::%%get-frame)
  `(:get-frame))

(define-special-form (scheme::%%get-hframes)
  `(:get-hframes))

(define-special-form (scheme::%%set-hframes new-hframes)
  `(:set-hframes 
    ,(expanded-form-meaning new-hframes cenv)))

(define (expanded-form-meaning form cenv)
  (call-with-compiler-tracing *show-meanings* '("MEANING-OF" "IS")
    (lambda (form)
      (cond ((symbol? form)
             (meaning/symbol form cenv))
            ((fast-op? form)
             form)
            ((atom? form)
             `(:literal ,form))
            ((hash-has? *special-form-handlers* (car form))
             (aif (find #L((car _) form) (hash-ref *special-form-handlers* (car form)))
                  ((cdr it) form cenv)
                  (error "Invalid syntax for ~a: ~s" (car form) form)))
            (#t
             (meaning/application form cenv))))
    form))

