;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; File:         takl.sch
; Description:  TAKL benchmark from the Gabriel tests
; Author:       Richard Gabriel
; Created:      12-Apr-85
; Modified:     12-Apr-85 10:07:00 (Bob Shaw)
;               22-Jul-87 (Will Clinger)
; Language:     Scheme
; Status:       Public Domain
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
 
;;; TAKL -- The TAKeuchi function using lists as counters.

(scheme::%set-stack-limit #f)

(define listn)

(define (listn n)
  (if (not (= 0 n))
      (cons n (listn (- n 1)))))
 
(define 18l (listn 18))
(define 12l (listn 12))
(define  6l (listn 6))

(define shorterp)
(define mas)

(define (mas x y z)
  (if (not (shorterp y x))
      z
      (mas (mas (cdr x)
                 y z)
            (mas (cdr y)
                 z x)
            (mas (cdr z)
                 x y))))
 
(define (shorterp x y)
  (and (not (null? y))
       (or (null? x)
           (shorterp (cdr x)
                     (cdr y)))))

(defbench gabriel-takl
  (account
   (mas 18l 12l 6l)))
 
;(run-benchmark "TAKL" (lambda () (mas 18l 12l 6l)))
