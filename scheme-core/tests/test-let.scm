(use-package! "unit-test")

(define-test let
  (let (unbound-var)
    (test-case (equal? unbound-var '())))
  (let ((closure (let lp ((x 10)) lp)))
    (test-case (closure? closure)))
  (let ((x (let lp ((x2 10)) x2)))
    (test-case (equal? x 10)))
  
  (let lp ((x 0) (y 10) z)
    (test-case (runtime-error? (lp)))
    ;(test-case (runtime-error? (lp 1 2 3 4))) Eventually, too many arguments should throw an error too...
    (test-case (equal? z '())))

  (let ((side-effect-0 #f)
	(side-effect-1 #f)
	(side-effect-2 #f))
    (let ((x 0)
	  (y 1)
	  (z 2))
      (set! side-effect-0 #t)
      (test-case (= x 0))
      (test-case (= y 1))
      (test-case (= z 2))
      (set! side-effect-1 #t)
      (set! x 10)
      (incr! y)
      (test-case (= x 10))
      (test-case (= y 2))
      (test-case (= z 2))
      (set! side-effect-2 #t))
    (test-case side-effect-0)
    (test-case side-effect-1)
    (test-case side-effect-2))

  (let ((x 10) 
	(y 20))
    (let ((x 100)
	  (y x))
      (test-case (= x 100))
      (test-case (= y 10)))))


(define-test let
  (let lp ((x 0) (y 10) z)
    (test-case (runtime-error? (lp))))

  (let lp ((x 0) (y 10) z)
    (test-case (equal? z '()))))