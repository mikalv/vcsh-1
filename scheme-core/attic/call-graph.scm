
;;;; call-graph.scm --
;;;;
;;;; An attempt at a tool for extracting call graphs from running
;;;; images.
;;;;
;;;; (C) Copyright 2001-2011 East Coast Toolworks Inc.
;;;; (C) Portions Copyright 1988-1994 Paradigm Associates Inc.
;;;;
;;;; See the file "license.terms" for information on usage and
;;;; redistribution of this file, and for a DISCLAIMER OF ALL
;;;; WARRANTIES.

(define-package "call-graph"
  (:uses "scheme")
  (:exports "package-call-graph"
            "call-graph"
            "procedure-global-bindings"
            "map-bindings"))

(define (closure-global-bindings fn)
  (list->set/eq
   (let recur ((fast-op (cdr (scheme::%closure-code fn))))
     (mvbind (opcode args) (compiler::parse-fast-op fast-op)
       (case opcode
         ((:literal :local-ref :get-env)
          ())
         ((:global-ref)
          (list (car args)))
         ((:global-set!)
          (cons (car args)
                (recur (cadr args))))
         ((:local-set!)
          (recur (cadr args)))
         ((:apply)
          (append (recur (car args))
                  (append-map recur (cadr args))))
         ((:if-true)
          (append (recur (car args))
                  (recur (cadr args))
                  (recur (caddr args))))
         ((:and/2 :or/2 :sequence)
          (append (recur (car args))
                  (recur (cadr args))))
         ((:closure)
          (recur (cadr args)))
         ((:global-def)
          (cons (car args)
                (recur (cadr args))))
         (#t
          (error "Unexpected fast-op: ~s" fast-op)))))))

(define (procedure-global-bindings fn)
  (etypecase fn
    ((closure)
     (aif (get-property fn 'scheme::method-table)
          (list->set/eq (append-map #L(closure-global-bindings (cdr _)) it))
          (closure-global-bindings fn)))
    ((subr)
     ())))

(define (map-bindings fn cg)
  (map #L(cons (car _)
               (fn (cdr _)))
       cg))

(define (call-graph symbols)
  (map #L(cons _ (procedure-global-bindings (symbol-value _)))
       (filter #L(and (symbol-bound? _)
                      (procedure? (symbol-value _)))
               symbols)))

(define (filter-bindings pred cg)
  (map-bindings #L(filter pred _) cg))

(define (remove-externals cg local-pkg)
  (filter-bindings #L(eq? (symbol-package _) local-pkg) cg))

(define (package-call-graph package :keyword (externals? #t))
  (let ((cg (call-graph (local-package-symbols (->package package)))))
    (if externals?
        cg
        (remove-externals cg (->package package)))))

