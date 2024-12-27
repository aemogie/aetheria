(define-module (aetheria services kmonad)
  #:use-module ((srfi srfi-1) #:select (find
                                        find-tail
                                        take-while))
  #:use-module ((ice-9 match) #:select (match-lambda))
  #:use-module ((guix records) #:select (define-record-type*))
  #:use-module ((srfi srfi-26) #:select (cut))
  #:use-module ((guix gexp) #:select (gexp
                                      file-append
                                      plain-file
                                      file-like?))
  #:use-module ((gnu packages haskell-apps) #:select (kmonad))
  #:use-module ((gnu services) #:select (service
                                         service-type
                                         service-extension
                                         for-home?))
  #:use-module ((gnu services shepherd) #:select (shepherd-root-service-type
                                                  shepherd-service))
  #:use-module ((gnu services base) #:select (udev-service-type))
  #:export (kmonad-service-type
            kmonad-keyboard-service))

;; TODO: move to serializers module, and expose?
(define serialize-kbd
  (match-lambda
    ;; processing before serializing. syntax transformations?
    ((and ('defcfg args ...)
          (? (cut find keyword? <>)))
     (serialize-kbd
      (cons 'defcfg (map (lambda (arg) (if (keyword? arg) (keyword->symbol arg) arg)) args))))

    ;; actual serialization
    (#t "true")
    (#f "false")

    ;; only 4 cases of escapes mentioned in tutorial.kbd
    ;; symbol variants are unsecaped and assumed to be intended
    (#\( "\\(")
    (#\) "\\)")
    (#\_ "\\_")
    ;; (#\\ "\\\\") ;; tutorial.kbd mentions this, but kmonad errors out at this
    ((? char? ch) (string ch))

    ((? symbol? sym) (symbol->string sym))
    ((? number? num) (number->string num))

    ((? keyword? key) (string-append ":" (symbol->string (keyword->symbol key))))
    ((? string? str) (string-append "\"" str "\""))

    (#(vec ...) (string-append "#(" (string-join (map serialize-kbd vec) " ") ")"))
    ((lst ...) (string-append "(" (string-join (map serialize-kbd lst) " ") ")"))

    (invalid (throw 'kbd-serialization invalid))))

(define flatten-config
  (match-lambda
    (((? symbol? name) . (? file-like? file)) (cons name file))
    (((? symbol? name) . (? string? str))
     (cons name (plain-file (string-append (symbol->string name) ".kbd") str)))
    (((? symbol? name) . (? list? sexp))
     (flatten-config
      (cons name (with-output-to-string
                   (lambda () (map display (map serialize-kbd sexp)))))))))

(define-record-type* <kmonad-configuration> kmonad-configuration
  make-kmonad-configuration
  kmonad-configuration?
  this-kmonad-configuration
  (values kmonad-configuration-values
          (default '())
          (sanitize
           (lambda (lst) (map flatten-config lst))))
  (home-service? kmonad-configuration-home-service? ;set automatically
                 (default for-home?)))

(define (kmonad-shepherd-service config)
  (define home-service? (kmonad-configuration-home-service? config))
  (map
   (match-lambda
     ((name . config-file)
      (shepherd-service
       (documentation
        (string-append "Run the kmonad daemon for configuration '" (symbol->string name) "'."))
       (provision (list (symbol-append 'kmonad- name)
                        (symbol-append 'km- name)))
       (requirement (if home-service? '() '(udev user-processes)))
       (modules '((shepherd support)))  ;for '%user-log-dir'
       (start
        #~(make-forkexec-constructor
           (list #$(file-append kmonad "/bin/kmonad")
                 #$config-file
                 "--log-level" "info")
           #:supplementary-groups '(input)
           #:log-file (string-append #$(if home-service? #~%user-log-dir "/var/log")
                                     #$(string-append "/kmonad-" (symbol->string name) ".log"))))
       (stop #~(make-kill-destructor)))))
   (kmonad-configuration-values config)))

(define kmonad-service-type
  (service-type
   (name 'kmonad)
   (description "the KMonad keyboard remapping service")
   (default-value (kmonad-configuration))
   (extensions (list (service-extension shepherd-root-service-type kmonad-shepherd-service)
                     (service-extension udev-service-type (const (list kmonad)))))
   (compose identity)
   (extend (lambda (config extensions)
             (kmonad-configuration
              (inherit config)
              (values (append (kmonad-configuration-values config)
                              extensions)))))))

;; TODO: rewrite with match statments
(define-syntax-rule (extract-keyword-argument-from-toplevel-function
                     function-name keyword toplevel)
  (let* ((function'
          (find (lambda (elt) (eq? (car elt) function-name)) toplevel))
         (function
          (if function' function'
              (throw 'bad-kmonad-configuration
                     (format #f "ensure you configuration has a `~a` block" function-name))))
         (tail' (find-tail (cut eq? keyword <>)
                           (cdr function))) ;; arguments
         (tail (if (and tail' (pair? tail') (pair? (cdr tail'))) tail'
                   (throw 'bad-kmonad-configuration
                          (format #f "ensure you `~a` block has an additional `~a` field!"
                                  function-name keyword))))
         (extracted (cadr tail))
         (updated-function
          (append (take-while (lambda (arg) (not (eq? keyword arg))) function)
                  (cddr tail))) ;; arguments after the keyword and it's value.
         (updated-toplevel
          (map (lambda (elt)
                 (if (eq? elt function) updated-function elt))
               toplevel)))
    (cons extracted updated-toplevel)))

(define-syntax-rule (kmonad-keyboard-service kbd-expr ...)
  (let* ((toplevel `(kbd-expr ...))
         (extracted-target (extract-keyword-argument-from-toplevel-function
                            'defcfg '#:target-type toplevel))
         (extracted-name (extract-keyword-argument-from-toplevel-function
                          ;; feed previous extraction into this
                          'defcfg '#:name (cdr extracted-target)))
         (type (begin
                 (service-type
                  (name (symbol-append 'kmonad- (car extracted-name)))
                  (extensions (list (service-extension
                                     ;; `(car extracted-target)` is a raw
                                     ;; symbol, because toplevel is quoted. we
                                     ;; need to look it up.
                                     (primitive-eval (car extracted-target))
                                     identity)))
                  (description (string-append "KMonad configuration for keyboard: "
                                              (symbol->string (car extracted-name))))))))
    (service type (cons (car extracted-name) ;; name
                        (cdr extracted-name))))) ;; updated
