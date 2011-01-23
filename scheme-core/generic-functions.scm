;;;; generic-functions.scm
;;;;
;;;; A CLOS-like (but very reduced) implementation of generic functions

;;; Generic Functions

(define (signature-list->english type-names)
  "Given a list of symbols, <type-names>, return an English string
   listing each element."
  (define (vowel? letter)
    (member letter '(#\a #\e #\i #\o #\u #\y #\A #\E #\I #\O #\U #\Y)))
  (define (type-name-connective type-name)
    (cond ((eq? type-name #t) "a")
          ((vowel? (string-ref (symbol-name type-name) 0)) "an")
          (#t "a")))  (let ((need-commas? (> (length type-names) 2))
        (need-and? (> (length type-names) 1))
        (op (open-output-string)))
    (let loop ((names type-names) (pos 0))
      (cond ((null? names) (get-output-string op))
            (#t
             (unless (or (symbol? (car names)) (eq? (car names) #t))
               (error "Type names must be symbols or #t: ~a" (car names)))
             (when (and (> pos 0) need-commas?) (display ", " op))

             (when (null? (cdr names))
               (when need-and?
                 (when (= pos 1) (display " " op))
                 (display "and " op)))
             (format op "~a ~a" (type-name-connective (car names)) (car names))
             (loop (cdr names) (+ 1 pos)))))))

(define (generic-function? obj)
  "Returns #t if <obj> is a generic function."
  (and (closure? obj)
       (aif (assq 'generic-function? (%property-list obj))
            (cdr it)
            #f)))

(define *generic-function-method-list-cache* (make-hash :equal))

(define (invalidate-method-list-cache!)
  "%Invalidiates the method list cache."
  (set! *generic-function-method-list-cache* (make-hash :equal)))

(define (generic-function-methods generic-function)
  (check generic-function? generic-function)
  (get-property generic-function 'method-table ()))

(define (compute-methods-for-signature generic-function signature)
  "Computes the methods defined on <generic-function> that apply to <signature>."
  (let ((method-list (get-property generic-function 'method-table ())))
    (map cdr (filter (lambda (method-list-entry)
                       (classes<=? signature (car method-list-entry)))
                     method-list))))

(define (methods-for-signature generic-function signature)
  "Returns the methods defined on  <generic-function> that apply to <signature>."
  (let ((sig-key (cons generic-function signature)))
    (aif (hash-ref *generic-function-method-list-cache* sig-key #f)
         it
         (let ((method-list (compute-methods-for-signature generic-function signature)))
           (hash-set! *generic-function-method-list-cache* sig-key method-list)
           method-list))))


(define (%generic-function gf-name arity doc-string)
  (letrec ((new-gf (lambda gf-args
                     (let ((current-methods (methods-for-signature new-gf (map type-of gf-args))))
                       (assert (not (null? current-methods)))
                       (letrec ((call-next-method (lambda ()
                                                 (let ((next-fn (pop! current-methods)))
                                                   (apply next-fn call-next-method gf-args)))))
                         (call-next-method))))))

    (set-property! new-gf 'name gf-name)
    (set-property! new-gf 'generic-function? #t)
    (set-property! new-gf 'documentation (aif doc-string it "Generic Function"))
    (set-property! new-gf 'method-table ())
    (set-property! new-gf 'generic-function-arity arity)

    new-gf))

(defmacro (define-generic-function lambda-list . code)
  (unless (list? lambda-list)
    (error "Generic function lambda lists must be proper lists: ~a" lambda-list))
  (let ((fn-name (car lambda-list))
        (fn-args (cdr lambda-list)))
    (unless (symbol? fn-name)
      (error "Generic function names must be symbols: ~a" fn-name))
    (unless (every? symbol? fn-args)
      (error "Generic function argument names must be symbols: ~a" fn-args))

    (mvbind (doc-string declarations code) (parse-code-body code)
      (with-gensyms (function-sym)
        `(begin
           (%define-global ',fn-name (%generic-function ',fn-name ,(length fn-args) ,doc-string))

           ,(if (null? code)
                `(define-method (,fn-name ,@(map #L(list _ #t) (cdr lambda-list)))
                   (error "generic function ~a undefined on arguments of type ~a" ,function-sym
                          (list ,@(map (lambda (arg-name) `(type-of ,arg-name)) fn-args))))
                `(define-method (,fn-name ,@(map #L(list _ #t) (cdr lambda-list)))
                   ,@code))

           ,fn-name)))))


(define (generic-function-signatures function)
  "Returns a list of the defined signatures of generic function <function>."
  (aif (get-property function 'method-table)
       (map car it)
       '()))

(define (%update-method-list! method-list method-signature method-closure)
  "Updates <method-list> to include <method-closure> as the definition
   for <method-signature>. If <method-signature> is already defined in the
   method list, then the existing definition is replaced."
  (aif (find (lambda (method-list-entry)
               (classes=? (car method-list-entry) method-signature))
             method-list)
       (begin
         (set-cdr! it method-closure)
         method-list)
       (insert-ordered method-list (cons method-signature method-closure) classes<=? car)))

(define (%add-generic-function-method generic-function method-signature method-closure)
  "Adds the method defined by <method-closure>, with the signature <method-signature>,
   to <generic-function>"
  (unless (generic-function? generic-function)
    (error "Generic function expected" generic-function))
  (unless (closure? method-closure)
    (error "Closure expected" method-closure))
  (unless (or (null? method-signature) (list? method-signature))
    (error "Method signatures must be lists" method-signature))

  (invalidate-method-list-cache!)
  (set-property! generic-function 'method-table
                            (%update-method-list! (get-property generic-function 'method-table)
                                                  method-signature method-closure)))


(defmacro (define-method lambda-list . code)
  (unless (list? lambda-list)
    (error "Method lambda lists must be proper lists: ~a" lambda-list))
  (let ((fn-expr (car lambda-list))
        (fn-args (cdr lambda-list)))

    (unless (every? (lambda (fn-arg) (or (symbol? fn-arg)
                                         (and (list? fn-arg) (length=2? fn-arg))))
                    fn-args)
      (error "Method arguments must be specified as 2-element lists or symbols." fn-args))

    (let ((fn-args (map (lambda (fn-arg) (if (symbol? fn-arg) (list fn-arg #t) fn-arg)) fn-args)))
      (unless (every? (lambda (argument) (symbol? (car argument))) fn-args)
        (error "Method argument names must be symbol." fn-args))
      (unless (every? (lambda (argument) (every? valid-class-name? (cdr argument))) fn-args)
        (error "Methods argument types must be classes." fn-args))

      (let ((fn-arg-names (map car fn-args))
            (fn-signature (map cadr fn-args)))
        `(begin
           (unless (= ,(length fn-args) (get-property ,fn-expr 'generic-function-arity -1))
             (error "Arity mismatch in method definition for ~a, generic function expects ~a arguments, method expects ~a."
                    ',fn-expr
                    (get-property ,fn-expr 'generic-function-arity -1)
                    (length ',fn-args)))

           (%add-generic-function-method ,fn-expr ',fn-signature
                                         (lambda (call-next-method ,@fn-arg-names)  ,@code)))))))