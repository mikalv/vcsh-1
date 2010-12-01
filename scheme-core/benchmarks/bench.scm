;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; bench.scm
;;;
;;; A simple set of benchmarks to evaluate interpreter performance
;;;

(define-package "bench"
  (:uses "scheme" "csv")
  (:exports "account"
            "test-benchmarks"
            "bench"
            "hash-bench"
            "fast-bench"))

;; To prevent timing inconsistancies caused by run-time heap
;; expansion, expand the heap ahead of time.

(enlarge-heap 64)

;; Turn the stack limit off.
;(scheme::%set-stack-limit #f)

(define-structure benchmark-result
  seq
  system
  test-name
  timings
  (run-time :default #f))

(define (benchmark-result-cpu-time benchmark-result)
  (if (not (benchmark-result? benchmark-result))
      #f
      (car (benchmark-result-timings benchmark-result))))

(define *benchmarks* '())

(define benchmark-time-sym (gensym))

(defmacro (account . code)
  `(begin
     (gc)
     (set! ,benchmark-time-sym (estimate-execution-time (lambda () ,@code)))))

(define *estimate-min-test-duration* 5)
(define *benchmark-result-bar-length* 40)
(define *benchmark-result-name-length* 25)

(define (estimate-execution-time closure)
  "Estimate the time in milliseconds it takes to execute the (parameterless)
   closure, returning a two element list consisting of the total cpu time, and the time
   net of garbage collection. The estimate is obtained by repeatedly calling the closure
   until at least *estimate-min-test-duration*  seconds of clock time pass. The
   repeat count is computed by starting at 1 and successively doubling until
   the time threshold is crossed."
  (define (execution-time count closure)
    (gc)
    (format #t "~a." count)
    (flush-port (current-output-port))
    (let ((result (scheme::%time-apply0 (lambda () (repeat count (apply closure))))))
      (let ((cpu-time (vector-ref result 1))
	    (net-time (- (vector-ref result 1)
			 (vector-ref result 2))))
	(list cpu-time
	      (* 1000 (/ cpu-time count))
	      (* 1000 (/ net-time count))))))
  (define (iter count)
    (let ((result (execution-time count closure)))
      (if (> (car result) *estimate-min-test-duration* )
	  (cdr result)
	  (iter (* count 2)))))
  (iter 1))

(defmacro (defbench benchname . code)
  `(begin
     (unless (member ',benchname *benchmarks*)
       (push! ',benchname *benchmarks*))
     (define  ,benchname (lambda ()
                           (let ((,benchmark-time-sym #f))
                             ,@code
                             ,benchmark-time-sym)))))


(define *last-benchmark-result-set* '())

(define *reference-benchmark-result-sets* (make-hash :equal))

(define (benchmark-system-info)
  "Return a list describing the current build of scan and the hardware it's
   running on."
  (let ((si (system-info)))
    (list (hash-ref si :system-name)
          (hash-ref si :platform-name)
          (hash-ref si :build-type))))

(define (add-reference-result result)
  "Adds benchmark result <result> to the current reference results, listed
   under the current system type."
  (hash-push! *reference-benchmark-result-sets* (benchmark-system-info) result))


(define (benchmark-result-named? result name)
  (eq? (benchmark-result-test-name result) name))

(define (find-test-result test-name results)
  (find #L(benchmark-result-named? _ test-name) results))

(define (most-current-benchmarks-for-result-set results)
  "Given a list of benchmark results <results>, return a list composed
   only of the most current results for each test."
  (map #L(find-test-result _ results)
       (list->set (map benchmark-result-test-name results))))

(define (reference-result-set :optional (system (benchmark-system-info)))
  "Returns the best reference results for <system>. <system> defaults to
   the current system."
  (most-current-benchmarks-for-result-set
   (aif (hash-ref *reference-benchmark-result-sets* system)
     it
     ())))

(define (select-benchmark-result :optional (set-type "result"))
  "Allow the user to pick from a list of available benchmark result sets,
   returning the set."
  (catch 'none-chosen
    (let ((choice (repl-choose (cons :last-run (hash-keys *reference-benchmark-result-sets*))
			       (format #f "Pick a ~a set" set-type))))
      (most-current-benchmarks-for-result-set
       (if (eq? choice :last-run)
	   *last-benchmark-result-set*
	   (hash-ref *reference-benchmark-result-sets* choice ()))))))

(define *benchmark-scale-factor* 2.0)

(define (display-benchmark-result name actual nominal)

  (define (bar value max-value)
    (let ((value (inexact->exact (* (/ value max-value) *benchmark-result-bar-length*)))
          (nominal (inexact->exact  (/  *benchmark-result-bar-length* *benchmark-scale-factor*)))
          (max-value *benchmark-result-bar-length*))
      (let ((limited-value (min value max-value)))
        (string-set! (format #f "[~a~a~a"
                             (make-string limited-value #\-)
                             (make-string (- max-value limited-value) #\space)
                             (if (> value max-value) ">> " "]  "))
                     nominal #\+))))

  (display (pad-to-width name *benchmark-result-name-length*))
  (dynamic-let ((*flonum-print-precision* 3))
    (if nominal
        (let ((scaled-value (/ actual nominal)))
          (format #t "~a~a (~a ms.)\n"
                  (bar scaled-value *benchmark-scale-factor*)
                  scaled-value
                  actual))
        (format #t "-- No Reference Data -- (~a ms.)\n" actual))))


(define *benchmark-results-filename* "benchmark_results.scm")



(push! '(:bench bench "Runs the benchmark suite")
       scheme::*repl-abbreviations*)

(push! '(:pbr promote-benchmark-results
              "Promotes the current benchmark results to 'official' status")
       scheme::*repl-abbreviations*)

(push! '(:cbr compare-benchmark-results
             "Compares two sets of benchmark results.")
       scheme::*repl-abbreviations*)


(define (save-benchmark-results)
  "Saves the current set of benchmark results to disk."
  (with-port of (open-output-file *benchmark-results-filename*)
    (display ";;;; Saved benchmark results - DO NOT ALTER!!!\n" of)
    (display ";;;; \n" of)
    (display ";;;; \n" of)
    (display "\n" of)
    (let ((results (qsort (append-map #L(hash-ref *reference-benchmark-result-sets* _ ())
                                      (hash-keys *reference-benchmark-result-sets*))
                          <
                          benchmark-result-seq)))
      (dolist (result results)
        (write result of)
        (newline of)))
    (display "; end benchmark results\n" of)))

(define *current-benchmark-sequence* #f)

(define (next-benchmark-sequence)
  (incr! *current-benchmark-sequence*)
  *current-benchmark-sequence*)

(define (load-benchmark-results)
  "Loads the current set of benchmark results from disk."
  (catch-all
   (with-port ip (open-input-file *benchmark-results-filename*)
     (hash-clear! *reference-benchmark-result-sets*)
     (let loop ((max-seq -1))
       (let ((result (read ip)))
         (cond ((eof-object? result)
                (set! *current-benchmark-sequence* max-seq)
                max-seq)
               ((benchmark-result? result)
                (hash-push! *reference-benchmark-result-sets*
                            (benchmark-result-system result)
                            result)
                (loop (max max-seq (benchmark-result-seq result))))
               (#t
                (error "Bad benchmark result: ~s" result))))))))

(load-benchmark-results)

(define (promote-benchmark-results)
  "Makes the current set of benchmark results the reference for the
   current system."
  (dolist (results *last-benchmark-result-set*)
    (hash-push! *reference-benchmark-result-sets* (benchmark-system-info) results))
  (save-benchmark-results))

(define (display-benchmark-results results :optional (reference (reference-result-set)))
  (dynamic-let ((*info* #f))
    (gc)
    (format #t "\nBenchmark results (shorter bar is better):\n")
    (dolist (result (qsort results
			   (lambda (s1 s2) (string< (symbol-name s1) (symbol-name s2)))
			   benchmark-result-test-name))
      (display-benchmark-result (benchmark-result-test-name result)
                                (benchmark-result-cpu-time result)
                                (benchmark-result-cpu-time (find-test-result (benchmark-result-test-name result)
                                                                             reference))))))


(define (bench . tests)
  (define (run-named-benchmark bench-name)
    (dynamic-let ((*info* #f))
      (gc)
      (format #t "\n~a: " bench-name)
      ((symbol-value bench-name))))

  (define (sort-benchmark-names names)
    (qsort names #L2(< (strcmp _0 _1) 0) symbol-name))

  (let* ((tests (if (null? tests) *benchmarks* tests))
         (results (map (lambda (test)
                           (make-benchmark-result :test-name test
                                                  :seq (next-benchmark-sequence)
                                                  :timings  (run-named-benchmark test)
                                                  :system (benchmark-system-info)
                                                  :run-time (current-date)))
                       (sort-benchmark-names tests))))

    (set! *last-benchmark-result-set* results)

    (display-benchmark-results results)
    (format #t "\nEvaluate (promote-benchmark-results) to make these results the standard for ~s\n"
            (benchmark-system-info))
    (format #t "\nEvaluate (compare-benchmark-results) to benchmark results\n")
    (values)))

(define (compare-benchmark-results)
  (let ((from (select-benchmark-result))
	(reference (select-benchmark-result "reference")))
    (display-benchmark-results from reference)))


(define (list-from-by b inc elems)
  (define (list-from-by-1 b elems accum)
    (if (<= elems 0)
	accum
	(list-from-by-1 (+ b inc) (- elems 1) (cons b accum))))
  (list-from-by-1 b elems '()))


(define *repeat-only-once* #f)

(defmacro (bench-repeat n . code)
  `(repeat (if *repeat-only-once* 1 ,n)
     ,@code))

(load "standard-benchmarks.scm")

