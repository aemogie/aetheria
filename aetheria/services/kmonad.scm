(define-module (aetheria services kmonad)
  #:use-module ((srfi srfi-1) #:select (find))
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
      (cons 'defcfg
            (map (lambda (arg)
                   (if (keyword? arg) (keyword->symbol arg) arg))
                 args))))

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

    ((? keyword? key)
     (string-append ":" (symbol->string (keyword->symbol key))))
    ((? string? str)
     (string-append "\"" str "\""))

    (#(vec ...)
     (string-append "#(" (string-join (map serialize-kbd vec) " ") ")"))
    ((lst ...)
     (string-append "(" (string-join (map serialize-kbd lst) " ") ")"))

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

;; an llm could never write this bullshit... i hope...
;; TODO: this is unmaintainable, rewrite in syntax-case
(define-syntax process-config
  ;; (stack ... (!method-name args))
  ;; (!process-defcfg (name target-type) (remainder ...) (processed ...))
  ;; (!process-outer (name target-type) (remainder ...) (processed ...))
  ;; (!validate-arguments name target-type)
  ;; (!make-service-type name target-type sexp)
  ;; (!make-service <service-type> value)
  (syntax-rules (!process-defcfg
                 defcfg
                 !process-outer
                 !validate-arguments
                 !make-service-type
                 !make-service)
    ((_ (stack ...
               ;; ignore propagated name as we override it with the matched
               ;; `name` here
               (!process-defcfg (_ target-type) (#:name name rest ...) processed)))
     (process-config
      (stack ...
             (!process-defcfg (name target-type) (rest ...) processed))))
    
    ((_ (stack ...
               ;; ignore propagated target-type as we override it with the
               ;; matched `target-type` here
               (!process-defcfg (name _) (#:target-type target-type rest ...) processed)))
     (process-config
      (stack ...
             (!process-defcfg (name target-type) (rest ...) processed))))

    ((_ (stack ...
               (!process-defcfg propagated (this rest ...) (processed ...))))
     (process-config
      (stack ...
             (!process-defcfg propagated (rest ...) (processed ... this)))))
    
    ((_ (stack ...
               (!process-outer _ rest (processed ...))
               (!process-defcfg propagated () (args ...))))
     ;; we exit out of !process-defcfg mode, and put the defcfg block into
     ;; the `processed`
     (process-config
      (stack ...
             (!process-outer propagated rest (processed ... (defcfg args ...))))))
    
    ((_ (stack ...
               (!process-defcfg propagated () (args ...))))
     (syntax-error "can only return from !process-defcfg to !process-outer" (stack ...)))

    
    ((_ (stack
         ...
         (!process-outer propagated ((defcfg args ...) rest ...) processed)))
     (process-config
      (stack ...
             (!process-outer propagated (rest ...) processed)
             (!process-defcfg propagated (args ...) ()))))
    
    ((_ (stack ...
               (!process-outer propagated (this rest ...) (processed ...))))
     (process-config
      (stack ...
             (!process-outer propagated (rest ...) (processed ... this)))))
    
    ((_ (stack ...
               (!process-outer (name target-type) () processed)))
     (process-config
      (stack ...
             (!make-service-type name target-type processed)
             (!validate-arguments name target-type))))

    ((_ (stack ... (!validate-arguments #f _)))
     (syntax-error "missing `#:name` field in your `defcfg` block"))
    
    ((_ (stack ... (!validate-arguments _ #f)))
     (syntax-error "missing `#:target-type` field in your `defcfg` block"))
    
    ((_ (stack ... (!validate-arguments x y)))
     (process-config (stack ...)))
    
    ((_ (stack ... (!make-service-type name* target-type sexp)))
     (process-config
      (stack ...
             (!make-service
              (service-type
               (name (symbol-append 'kmonad- 'name*))
               (extensions (list (service-extension target-type identity)))
               (description (string-append "KMonad configuration for keyboard: "
                                           (symbol->string 'name*))))
              (cons 'name* 'sexp)))))
    ((_ (stack ... (!make-service type value)))
     (service type value))))

(define-syntax-rule (kmonad-keyboard-service expr ...)
  (process-config ((!process-outer (#f #f) (expr ...) ()))))
