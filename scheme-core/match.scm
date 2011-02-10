;;;; match.scm
;;;;
;;;; The patterh matcher, and dbind.

;;; REVISIT: Add unify?

;; REVISIT: need configurable equal?/eq? predicate for match? ?
;; REVISIT: Add ?? ?? key/value pattern var for matching 'extra slots'

(define (match-pattern-var? var)
  (and (symbol? var)
       (char=? (string-ref (symbol-name var) 0) #\?)))

(define (match-universal-pattern-var? var)
  (and (match-pattern-var? var)
       (equal? (symbol-name var) "??")))


(define (match-pattern-variables pat)
  "Returns the list of match variables in match pattern <pat>. See match?
   for more details on matching patterns."
  (define (maybe-extend-var-list var vars)
    (aif (memq var vars)
         vars
         (cons var vars)))

  (let recur ((pat pat) (vars ()))
    (cond ((match-pattern-var? pat)
           (maybe-extend-var-list pat vars))

          ((pair? pat)
           (recur (cdr pat) (recur (car pat) vars)))

          ((structure? pat)
           (let loop ((slots (structure-slots pat)) (vars vars))
             (if (null? slots)
                 vars
                 (loop (cdr slots) (recur (structure-slot-by-name pat (car slots)) vars)))))

          ((hash? pat) 
           (let ((keys (hash-keys pat)))
             (let loop ((keys keys) (vars vars))
               (cond ((null? keys)
                      vars)
                     ((match-pattern-var? (car keys))
                      (error "Match pattern variables not allowed in hash keys: ~s" pat))
                     ((hash-has? pat (car keys))
                      (loop (cdr keys) (recur (hash-ref pat (car keys)) vars)))
                     (#t
                      #f)))))

          ((vector? pat)
           (let loop ((ii 0) (vars vars))
             (if (>= ii (length pat))
                 vars
                 (loop (+ ii 1) (recur (vector-ref pat ii) vars)))))
          (#t
           vars))))

(define (match? pat form)
  "Determines if <form> matches pattern <pat>.  A form matches a pattern if
   it can be equal? to the pattern with a consistent set of pattern variable
   bindings.  Pattern variables are variables in the pattern that can be bound to
   arbitrary values, as long as each instance of the same pattern variable is bound
   to the same thing. Pattern variables are denotes as symbols with #\\? as the
   first character of their name. Pattern variables with a symbol-name of \"??\"
   are special pattern variables that do not establish a binding; These pattern
   variables are universal and can match anything anywere.  Returns an a-list
   ((<var> . <val>) ... ) if <form> matches, and #f otherwise."
  (define (maybe-extend-env? env var val)
    (aif (assq var env)
         (if (equal? val (cdr it))
             env
             #f)
         (alist-cons var val env)))
  (let recur ((pat pat) (form form) (env ()))
    (cond ((not env)
           #f)
          ((match-pattern-var? pat)
           (if (match-universal-pattern-var? pat)
               env
               (maybe-extend-env? env pat form)))
          ((and (pair? pat) (pair? form))
           (let ((nenv (recur (car pat) (car form) env)))
             (recur (cdr pat) (cdr form) nenv)))
          ((and (structure? pat) (structure? form)
                (eq? (structure-type pat) (structure-type form)))
           (let loop ((slots (structure-slots pat)) (nenv env))
             (if (or (not env) (null? slots))
                 nenv
                 (loop (cdr slots) (recur (structure-slot-by-name pat (car slots))
                                          (structure-slot-by-name form (car slots))
                                          nenv)))))
          ((and (hash? pat) (hash? form))
           (let ((pat-keys (hash-keys pat)))
             (if (and (set-equivalent? pat-keys (hash-keys form) (hash-type pat))
                      (eq? (hash-type pat) (hash-type form)))
                 (let loop ((keys pat-keys) (nenv env))
                   (cond ((null? keys) nenv)
                         ((match-pattern-var? (car keys))
                          (error "Match pattern variables not allowed in hash keys: ~s" pat))
                         ((hash-has? form (car keys))
                          (loop (cdr keys)
                                (recur (hash-ref pat (car keys))
                                       (hash-ref form (car keys))
                                       nenv)))
                         (#t
                          #f)))
                 #f)))
          ((and (vector? pat) (vector? form)
                (= (length pat) (length form)))
           (let loop ((ii 0) (nenv env))
             (if (or (not nenv) (>= ii (length pat)))
                 nenv
                 (loop (+ ii 1) (recur (vector-ref pat ii) (vector-ref form ii) nenv)))))
          ((and (atom? pat) (atom? form)
                (equal? pat form))
           env)
          (#t
           #f))))

(defmacro (bind-if-match pat val if-true-form if-false-form)
  (with-gensyms (match-var)
     (let ((pat-vars (match-pattern-variables pat)))
       `(let ((,match-var (match? ',pat ,val)))
          (if ,match-var
              (let (,@(map #L(list _ `(cdr (assq ',_ ,match-var))) (remove match-universal-pattern-var? pat-vars)))
                ,if-true-form)
              ,if-false-form)))))

(define (dbind-match-variables binding)
  "Returns the list of all match variables in the dbind pattern
   <binding>. If a variable appears more than once in the pattern,
   it will appear more than once in the list of variables."
  (let recur ((binding binding))
    (cond ((symbol? binding)
           `(,binding))
          ((pair? binding)
           `(,@(recur (car binding))
             ,@(recur (cdr binding))))
          ((vector? binding)
           `(,@(let loop ((ii 0))
                 (if (= ii (length binding))
                     ()
                     `(,@(loop (+ ii 1))
                       ,@(recur (vector-ref binding ii)))))
             ))
          ((null? binding)
           ())
          (#t
           (error "Invalid dbind binding: ~s" binding)))))

(defmacro (dbind-matches? binding value)
  (define (find-dbind-match-predicates binding value)
    ;; REVISIT: no dbind specific typechecking. Does this matter?
    (cond ((symbol? binding)
           ())
          ((pair? binding)
           `((pair? ,value)
             ;; REVISIT: this generates inefficient code with repeated calls to cdr
             ,@(find-dbind-match-predicates (car binding) `(car ,value))
             ,@(find-dbind-match-predicates (cdr binding) `(cdr ,value))))
          ((vector? binding)
           `((vector? ,value)
             (= (length ,value) ,(length binding))

             ,@(let loop ((ii 0))
                 (if (= ii (length binding))
                     ()
                     `(,@(find-dbind-match-predicates (vector-ref binding ii) `(vector-ref ,value ,ii))
                       ,@(loop (+ ii 1)))))
             ))
          ((null? binding)
           `((null? ,value)))
          (#t
           (error "Invalid dbind binding: ~s" binding))))

  (with-gensyms (value-sym)
    `(let ((,value-sym ,value))
       (and ,@(find-dbind-match-predicates binding value-sym)))))

(defmacro (dbind-if-match binding value if-true-form if-false-form)
  (with-gensyms (value-sym)
    `(let ((,value-sym ,value))
       (if (dbind-matches? ,binding ,value-sym)
           (dbind ,binding ,value-sym ,if-true-form)
           ,if-false-form))))

(defmacro (dbind binding value . code)
  (define (find-dbind-binding-forms binding value)
    ;; REVISIT: no dbind specific typechecking. Does this matter?
    (cond ((symbol? binding)
           `((,binding ,value)))
          ((pair? binding)
           `(,@(find-dbind-binding-forms (car binding) `(car ,value))
             ;; REVISIT: this generates inefficient code with repeated calls to cdr
             ,@(find-dbind-binding-forms (cdr binding) `(cdr ,value))))
          ((vector? binding)
           (let loop ((ii 0))
             (if (= ii (length binding))
                 ()
                 `(,@(find-dbind-binding-forms (vector-ref binding ii) `(vector-ref ,value ,ii))
                   ,@(loop (+ ii 1))))))
          ((null? binding)
           ())
          (#t
           (error "Invalid dbind binding: ~s" binding))))
  (with-gensyms (value-sym)
   `(let ((,value-sym ,value))
      (let (,@(find-dbind-binding-forms binding value-sym))
        ,@code))))