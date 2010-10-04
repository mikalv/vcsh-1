;;;; subrs.scm
;;;; January 19th, 2008
;;;; Mike Schaeffer
;;;
;;; Lisp references to native SUBRs.

;; primitive functions
(%define %call-with-global-environment #.(scheme::%subr-by-name "%call-with-global-environment"))
(%define %catch-apply0 #.(scheme::%subr-by-name "%catch-apply0"))
(%define %closure #.(scheme::%subr-by-name "%closure"))
(%define %closure-code #.(scheme::%subr-by-name "%closure-code"))
(%define %closure-env #.(scheme::%subr-by-name "%closure-env"))
(%define %copy-structure #.(scheme::%subr-by-name "%copy-structure"))
(%define %current-global-environment #.(scheme::%subr-by-name "%current-global-environment"))
(%define %debug-flags #.(scheme::%subr-by-name "%debug-flags"))
(%define %debug-printer #.(scheme::%subr-by-name "%debug-printer"))
(%define %define-global #.(scheme::%subr-by-name "%define-global"))
(%define %directory #.(scheme::%subr-by-name "%directory"))
(%define %dump-heap-state #.(scheme::%subr-by-name "%dump-heap-state"))
(%define %fasl-load #.(scheme::%subr-by-name "%fasl-load"))
(%define %fast-op #.(scheme::%subr-by-name "%fast-op"))
(%define %fast-op-args #.(scheme::%subr-by-name "%fast-op-args"))
(%define %fast-op-opcode #.(scheme::%subr-by-name "%fast-op-opcode"))
(%define %file-details #.(scheme::%subr-by-name "%file-details"))
(%define %get-current-frames #.(scheme::%subr-by-name "%get-current-frames"))
(%define %handler-frames #.(scheme::%subr-by-name "%handler-frames"))
(%define %hash-binding-vector #.(scheme::%subr-by-name "%hash-binding-vector"))
(%define %immediate? #.(scheme::%subr-by-name "%immediate?"))
(%define %instance-map #.(scheme::%subr-by-name "%instance-map"))
(%define %instance-proto #.(scheme::%subr-by-name "%instance-proto"))
(%define %instance-slots #.(scheme::%subr-by-name "%instance-slots"))
(%define %internal-files #.(scheme::%subr-by-name "%internal-files"))
(%define %list->values #.(scheme::%subr-by-name "%list->values"))
(%define %macro #.(scheme::%subr-by-name "%macrocons"))
(%define %macro-transformer #.(scheme::%subr-by-name "%macro-transformer"))
(%define %macrocons #.(scheme::%subr-by-name "%macrocons"))
(%define %make-eof #.(scheme::%subr-by-name "%make-eof"))
(%define %memref #.(scheme::%subr-by-name "%memref"))
(%define %obaddr #.(scheme::%subr-by-name "%obaddr"))
(%define %package-bindings #.(scheme::%subr-by-name "%package-bindings"))
(%define %package-use-list #.(scheme::%subr-by-name "%package-use-list"))
(%define %packagecons #.(scheme::%subr-by-name "%packagecons"))
(%define %panic #.(scheme::%subr-by-name "%panic"))
(%define %property-list #.(scheme::%subr-by-name "%property-list"))
(%define %representation-of #.(scheme::%subr-by-name "%representation-of"))
(%define %set-closure-code #.(scheme::%subr-by-name "%set-closure-code"))
(%define %set-closure-env #.(scheme::%subr-by-name "%set-closure-env"))
(%define %set-debug-flags #.(scheme::%subr-by-name "%set-debug-flags"))
(%define %set-handler-frames #.(scheme::%subr-by-name "%set-handler-frames"))
(%define %set-instance-proto! #.(scheme::%subr-by-name "%set-instance-proto!"))
(%define %set-interrupt-mask! #.(scheme::%subr-by-name "%set-interrupt-mask!"))
(%define %set-package-name #.(scheme::%subr-by-name "%set-package-name"))
(%define %set-package-use-list! #.(scheme::%subr-by-name "%set-package-use-list!"))
(%define %set-property-list! #.(scheme::%subr-by-name "%set-property-list!"))
(%define %set-stack-limit #.(scheme::%subr-by-name "%set-stack-limit"))
(%define %set-trap-handler! #.(scheme::%subr-by-name "%set-trap-handler!"))
(%define %show-type-stats #.(scheme::%subr-by-name "%show-type-stats"))
(%define %slot-ref #.(scheme::%subr-by-name "%slot-ref"))
(%define %slot-set! #.(scheme::%subr-by-name "%slot-set!"))
(%define %stress-c-heap #.(scheme::%subr-by-name "%stress-c-heap"))
(%define %stress-lisp-heap #.(scheme::%subr-by-name "%stress-lisp-heap"))
(%define %structure-layout #.(scheme::%subr-by-name "%structure-layout"))
(%define %structure-length #.(scheme::%subr-by-name "%structure-length"))
(%define %structure-ref #.(scheme::%subr-by-name "%structure-ref"))
(%define %structure-set! #.(scheme::%subr-by-name "%structure-set!"))
(%define %structure? #.(scheme::%subr-by-name "%structure?"))
(%define %structurecons #.(scheme::%subr-by-name "%structurecons"))
(%define %subr-type-code #.(scheme::%subr-by-name "%subr-type-code"))
(%define %symbol-value #.(scheme::%subr-by-name "%symbol-value"))
(%define %sysob #.(scheme::%subr-by-name "%sysob"))
(%define %system-info #.(scheme::%subr-by-name "system-info"))
(%define %test-blocking-input #.(scheme::%subr-by-name "%test-blocking-input"))
(%define %time-apply0 #.(scheme::%subr-by-name "%time-apply0"))
(%define %trap-handler #.(scheme::%subr-by-name "%trap-handler"))
(%define %unbound-marker #.(scheme::%subr-by-name "%unbound-marker"))
(%define %values #.(scheme::%subr-by-name "%values"))
(%define %values->list #.(scheme::%subr-by-name "%values->list"))

(%define * #.(scheme::%subr-by-name "*"))
(%define + #.(scheme::%subr-by-name "+"))
(%define - #.(scheme::%subr-by-name "-"))
(%define ->ieee-754-bits #.(scheme::%subr-by-name "->ieee-754-bits"))
(%define / #.(scheme::%subr-by-name "/"))
(%define < #.(scheme::%subr-by-name "<"))
(%define <= #.(scheme::%subr-by-name "<="))
(%define = #.(scheme::%subr-by-name "="))
(%define > #.(scheme::%subr-by-name ">"))
(%define >= #.(scheme::%subr-by-name ">="))
(%define acos #.(scheme::%subr-by-name "acos"))
(%define add-symbol-to-package #.(scheme::%subr-by-name "add-symbol-to-package"))
(%define angle #.(scheme::%subr-by-name "angle"))
(%define append #.(scheme::%subr-by-name "append"))
(%define append! #.(scheme::%subr-by-name "append!"))
(%define apply #.(scheme::%subr-by-name "apply"))
(%define asin #.(scheme::%subr-by-name "asin"))
(%define ass #.(scheme::%subr-by-name "ass"))
(%define assoc #.(scheme::%subr-by-name "assoc"))
(%define assq #.(scheme::%subr-by-name "assq"))
(%define assv #.(scheme::%subr-by-name "assv"))
(%define atan #.(scheme::%subr-by-name "atan"))
(%define binary-port? #.(scheme::%subr-by-name "binary-port?"))
(%define bitwise-and #.(scheme::%subr-by-name "bitwise-and"))
(%define bitwise-arithmatic-shift-right #.(scheme::%subr-by-name "bitwise-arithmatic-shift-right"))
(%define bitwise-not #.(scheme::%subr-by-name "bitwise-not"))
(%define bitwise-or #.(scheme::%subr-by-name "bitwise-or"))
(%define bitwise-shift-left #.(scheme::%subr-by-name "bitwise-shift-left"))
(%define bitwise-shift-right #.(scheme::%subr-by-name "bitwise-shift-right"))
(%define bitwise-xor #.(scheme::%subr-by-name "bitwise-xor"))
(%define boolean? #.(scheme::%subr-by-name "boolean?"))
(%define car #.(scheme::%subr-by-name "car"))
(%define cdr #.(scheme::%subr-by-name "cdr"))
(%define ceiling #.(scheme::%subr-by-name "ceiling"))
(%define char->integer #.(scheme::%subr-by-name "char->integer"))
(%define char-ready? #.(scheme::%subr-by-name "char-ready?"))
(%define char? #.(scheme::%subr-by-name "char?"))
(%define character->string #.(scheme::%subr-by-name "character->string"))
(%define clone-c-data-port #.(scheme::%subr-by-name "clone-c-data-port"))
(%define clone-instance #.(scheme::%subr-by-name "clone-instance"))
(%define close-port #.(scheme::%subr-by-name "close-port"))
(%define closure? #.(scheme::%subr-by-name "closure?"))
(%define complex? #.(scheme::%subr-by-name "complex?"))
(%define cons #.(scheme::%subr-by-name "cons"))
(%define cos #.(scheme::%subr-by-name "cos"))
(%define debug-write #.(scheme::%subr-by-name "debug-write"))
(%define delete-file #.(scheme::%subr-by-name "delete-file"))
(%define delq #.(scheme::%subr-by-name "delq"))
(%define enlarge-heap #.(scheme::%subr-by-name "enlarge-heap"))
(%define env-lookup #.(scheme::%subr-by-name "env-lookup"))
(%define environment #.(scheme::%subr-by-name "environment"))
(%define eof-object? #.(scheme::%subr-by-name "eof-object?"))
(%define eq? #.(scheme::%subr-by-name "eq?"))
(%define equal? #.(scheme::%subr-by-name "equal?"))
(%define eqv? #.(scheme::%subr-by-name "eqv?"))
(%define exact->inexact #.(scheme::%subr-by-name "exact->inexact"))
(%define exact? #.(scheme::%subr-by-name "exact?"))
(%define exp #.(scheme::%subr-by-name "exp"))
(%define expt #.(scheme::%subr-by-name "expt"))
(%define fast-read #.(scheme::%subr-by-name "fast-read"))
(%define find-package #.(scheme::%subr-by-name "find-package"))
(%define floor #.(scheme::%subr-by-name "floor"))
(%define flush-port #.(scheme::%subr-by-name "flush-port"))
(%define flush-whitespace #.(scheme::%subr-by-name "flush-whitespace"))
(%define for-each #.(scheme::%subr-by-name "for-each"))
(%define fresh-line #.(scheme::%subr-by-name "fresh-line"))
(%define gc #.(scheme::%subr-by-name "gc"))
(%define gc-info #.(scheme::%subr-by-name "gc-info"))
(%define gc-runtime #.(scheme::%subr-by-name "gc-runtime"))
(%define get-output-string #.(scheme::%subr-by-name "get-output-string"))
(%define has-slot? #.(scheme::%subr-by-name "has-slot?"))
(%define hash->a-list #.(scheme::%subr-by-name "hash->a-list"))
(%define hash->list #.(scheme::%subr-by-name "hash->list"))
(%define hash-clear! #.(scheme::%subr-by-name "hash-clear!"))
(%define hash-copy #.(scheme::%subr-by-name "hash-copy"))
(%define hash-for-each #.(scheme::%subr-by-name "hash-for-each"))
(%define hash-has? #.(scheme::%subr-by-name "hash-has?"))
(%define hash-ref #.(scheme::%subr-by-name "hash-ref"))
(%define hash-ref* #.(scheme::%subr-by-name "hash-ref*"))
(%define hash-remove! #.(scheme::%subr-by-name "hash-remove!"))
(%define hash-set! #.(scheme::%subr-by-name "hash-set!"))
(%define hash-type #.(scheme::%subr-by-name "hash-type"))
(%define hash? #.(scheme::%subr-by-name "hash?"))
(%define ieee-754-bits-> #.(scheme::%subr-by-name "ieee-754-bits->"))
(%define imag-part #.(scheme::%subr-by-name "imag-part"))
(%define inexact->display-string #.(scheme::%subr-by-name "inexact->display-string"))
(%define inexact->exact #.(scheme::%subr-by-name "inexact->exact"))
(%define inexact? #.(scheme::%subr-by-name "inexact?"))
(%define infinite? #.(scheme::%subr-by-name "infinite?"))
(%define input-port? #.(scheme::%subr-by-name "input-port?"))
(%define instance? #.(scheme::%subr-by-name "instance?"))
(%define integer->char #.(scheme::%subr-by-name "integer->char"))
(%define integer? #.(scheme::%subr-by-name "integer?"))
(%define keyword? #.(scheme::%subr-by-name "keyword?"))
(%define last-pair #.(scheme::%subr-by-name "last-pair"))
(%define length #.(scheme::%subr-by-name "length"))
(%define list->hash #.(scheme::%subr-by-name "list->hash"))
(%define list->vector #.(scheme::%subr-by-name "list->vector"))
(%define list-copy #.(scheme::%subr-by-name "list-copy"))
(%define log #.(scheme::%subr-by-name "log"))
(%define macro? #.(scheme::%subr-by-name "macro?"))
(%define magnitude #.(scheme::%subr-by-name "magnitude"))
(%define make-hash #.(scheme::%subr-by-name "make-hash"))
(%define make-instance #.(scheme::%subr-by-name "make-instance"))
(%define make-list #.(scheme::%subr-by-name "make-list"))
(%define make-package! #.(scheme::%subr-by-name "make-package!"))
(%define make-polar #.(scheme::%subr-by-name "make-polar"))
(%define make-rectangular #.(scheme::%subr-by-name "make-rectangular"))
(%define make-vector #.(scheme::%subr-by-name "make-vector"))
(%define map #.(scheme::%subr-by-name "map"))
(%define map-pair #.(scheme::%subr-by-name "map-pair"))
(%define modulo #.(scheme::%subr-by-name "modulo"))
(%define nan? #.(scheme::%subr-by-name "nan?"))
(%define newline #.(scheme::%subr-by-name "newline"))
(%define not #.(scheme::%subr-by-name "not"))
(%define null? #.(scheme::%subr-by-name "null?"))
(%define number->string #.(scheme::%subr-by-name "number->string"))
(%define number? #.(scheme::%subr-by-name "number?"))
(%define open-c-data-output #.(scheme::%subr-by-name "open-c-data-output"))
(%define open-debug-port #.(scheme::%subr-by-name "open-debug-port"))
(%define open-input-file #.(scheme::%subr-by-name "open-input-file"))
(%define open-input-string #.(scheme::%subr-by-name "open-input-string"))
(%define open-null-port #.(scheme::%subr-by-name "open-null-port"))
(%define open-output-file #.(scheme::%subr-by-name "open-output-file"))
(%define open-output-string #.(scheme::%subr-by-name "open-output-string"))
(%define output-port? #.(scheme::%subr-by-name "output-port?"))
(%define package-name #.(scheme::%subr-by-name "package-name"))
(%define package? #.(scheme::%subr-by-name "package?"))
(%define pair? #.(scheme::%subr-by-name "pair?"))
(%define peek-char #.(scheme::%subr-by-name "peek-char"))
(%define port-io-counts #.(scheme::%subr-by-name "port-io-counts"))
(%define port-location #.(scheme::%subr-by-name "port-location"))
(%define port-mode #.(scheme::%subr-by-name "port-mode"))
(%define port-name #.(scheme::%subr-by-name "port-name"))
(%define port-translate-mode #.(scheme::%subr-by-name "port-translate-mode"))
(%define primitive? #.(scheme::%subr-by-name "primitive?"))
(%define procedure? #.(scheme::%subr-by-name "procedure?"))
(%define quotient #.(scheme::%subr-by-name "quotient"))
(%define random #.(scheme::%subr-by-name "random"))
(%define rational? #.(scheme::%subr-by-name "rational?"))
(%define read-binary-fixnum #.(scheme::%subr-by-name "read-binary-fixnum"))
(%define read-binary-flonum #.(scheme::%subr-by-name "read-binary-flonum"))
(%define read-binary-string #.(scheme::%subr-by-name "read-binary-string"))
(%define read-char #.(scheme::%subr-by-name "read-char"))
(%define read-line #.(scheme::%subr-by-name "read-line"))
(%define real-part #.(scheme::%subr-by-name "real-part"))
(%define real? #.(scheme::%subr-by-name "real?"))
(%define realtime #.(scheme::%subr-by-name "realtime"))
(%define realtime-time-zone-offset #.(scheme::%subr-by-name "realtime-time-zone-offset"))
(%define remainder #.(scheme::%subr-by-name "remainder"))
(%define rich-write #.(scheme::%subr-by-name "rich-write"))
(%define round #.(scheme::%subr-by-name "round"))
(%define runtime #.(scheme::%subr-by-name "runtime"))
(%define send #.(scheme::%subr-by-name "send"))
(%define set-car! #.(scheme::%subr-by-name "set-car!"))
(%define set-cdr! #.(scheme::%subr-by-name "set-cdr!"))
(%define set-environment-variable! #.(scheme::%subr-by-name "set-environment-variable!"))
(%define set-port-translate-mode! #.(scheme::%subr-by-name "set-port-translate-mode!"))
(%define set-random-seed! #.(scheme::%subr-by-name "set-random-seed!"))
(%define set-symbol-package! #.(scheme::%subr-by-name "set-symbol-package!"))
(%define set-symbol-value! #.(scheme::%subr-by-name "set-symbol-value!"))
(%define sin #.(scheme::%subr-by-name "sin"))
(%define sleep #.(scheme::%subr-by-name "sleep"))
(%define sqrt #.(scheme::%subr-by-name "sqrt"))
(%define strcmp #.(scheme::%subr-by-name "strcmp"))
(%define string->number #.(scheme::%subr-by-name "string->number"))
(%define string->uninterned-symbol #.(scheme::%subr-by-name "string->uninterned-symbol"))
(%define string-append #.(scheme::%subr-by-name "string-append"))
(%define string-copy #.(scheme::%subr-by-name "string-copy"))
(%define string-downcase #.(scheme::%subr-by-name "string-downcase"))
(%define string-downcase! #.(scheme::%subr-by-name "string-downcase!"))
(%define string-first-character #.(scheme::%subr-by-name "string-first-character"))
(%define string-first-substring #.(scheme::%subr-by-name "string-first-substring"))
(%define string-fold #.(scheme::%subr-by-name "string-fold"))
(%define string-length #.(scheme::%subr-by-name "string-length"))
(%define string-ref #.(scheme::%subr-by-name "string-ref"))
(%define string-search #.(scheme::%subr-by-name "string-search"))
(%define string-search-from-right #.(scheme::%subr-by-name "string-search-from-right"))
(%define string-set! #.(scheme::%subr-by-name "string-set!"))
(%define string-trim #.(scheme::%subr-by-name "string-trim"))
(%define string-trim-left #.(scheme::%subr-by-name "string-trim-left"))
(%define string-trim-right #.(scheme::%subr-by-name "string-trim-right"))
(%define string-upcase #.(scheme::%subr-by-name "string-upcase"))
(%define string-upcase! #.(scheme::%subr-by-name "string-upcase!"))
(%define string? #.(scheme::%subr-by-name "string?"))
(%define substring #.(scheme::%subr-by-name "substring"))
(%define sxhash #.(scheme::%subr-by-name "sxhash"))
(%define symbol-bound? #.(scheme::%subr-by-name "symbol-bound?"))
(%define symbol-name #.(scheme::%subr-by-name "symbol-name"))
(%define symbol-package #.(scheme::%subr-by-name "symbol-package"))
(%define symbol-value #.(scheme::%subr-by-name "symbol-value"))
(%define symbol? #.(scheme::%subr-by-name "symbol?"))
(%define system #.(scheme::%subr-by-name "system"))
(%define system-info #.(scheme::%subr-by-name "system-info")) ;; REVISIT: deprecated
(%define tan #.(scheme::%subr-by-name "tan"))
(%define temporary-file-name #.(scheme::%subr-by-name "temporary-file-name"))
(%define throw #.(scheme::%subr-by-name "throw"))
(%define truncate #.(scheme::%subr-by-name "truncate"))
(%define unbind-symbol! #.(scheme::%subr-by-name "unbind-symbol!"))
(%define unread-char #.(scheme::%subr-by-name "unread-char"))
(%define unwind-protect #.(scheme::%subr-by-name "unwind-protect"))
(%define vector #.(scheme::%subr-by-name "vector"))
(%define vector->list #.(scheme::%subr-by-name "vector->list"))
(%define vector-copy #.(scheme::%subr-by-name "vector-copy"))
(%define vector-fill! #.(scheme::%subr-by-name "vector-fill!"))
(%define vector-ref #.(scheme::%subr-by-name "vector-ref"))
(%define vector-resize #.(scheme::%subr-by-name "vector-resize"))
(%define vector-resize! #.(scheme::%subr-by-name "vector-resize!"))
(%define vector-set! #.(scheme::%subr-by-name "vector-set!"))
(%define vector? #.(scheme::%subr-by-name "vector?"))
(%define write-binary-fixnum #.(scheme::%subr-by-name "write-binary-fixnum"))
(%define write-binary-flonum #.(scheme::%subr-by-name "write-binary-flonum"))
(%define write-binary-string #.(scheme::%subr-by-name "write-binary-string"))
(%define write-char #.(scheme::%subr-by-name "write-char"))
(%define write-strings #.(scheme::%subr-by-name "write-strings"))
