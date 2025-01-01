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
                                         service-type?
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

(define-syntax kmonad-keyboard-service
  (lambda (expr)
    (define (validate-block whom block)
      (unless (and (pair? block)
                   (list? block))
        (error 'hi block (pair? block) (list? block))
        (syntax-violation whom "expression not a valid statement" block))

      (define (go rest)
        (syntax-case rest ()
          ;; if a keyword is immediately followed by another keyword,
          ;; with no argument between
          ((kw1 kw2 rest ...) (and (keyword? (syntax->datum #'kw1))
                                   (keyword? (syntax->datum #'kw2)))
           (let* ((kw-name (symbol->string (keyword->symbol (syntax->datum #'kw1))))
                  (msg (string-append "keyword `#:" kw-name "' needs an argument")))
             (syntax-violation whom msg block)))
          ;; if a keyword is the last element in the list
          ((kw) (keyword? (syntax->datum #'kw))
           (let* ((kw-name (symbol->string (keyword->symbol (syntax->datum #'kw))))
                  (msg (string-append "keyword `#:" kw-name "' ends abruptly")))
             (syntax-violation whom msg block)))
          ;; shift the window
          ((this rest ...) (go #'(rest ...)))
          ;; void return
          (() *unspecified*)))
      (go (cdr block)))

    (define (process-defcfg whom block)
      (validate-block whom block)
      (define (go rest processed name target-type)
        (syntax-case rest ()
          ;; TODO: type check later at eval time. for now we just take the
          ;; entire <syntax> object, to drag along the lexical scope
          ((#:name name rest ...)
           (go #'(rest ...) processed #'name target-type))
          ((#:target-type target-type rest ...)
           (go #'(rest ...) processed name #'target-type))

          ;; defcfg block uses symbols for what should be
          ;; keywords. let the users use keywords in the dsl, but
          ;; translate it here
          ((kw rest ...) (keyword? (syntax->datum #'kw))
           (let* ((deconstructed (syntax->datum #'kw))
                  (modified (keyword->symbol deconstructed))
                  (reconstructed (datum->syntax #'kw modified #:source #'kw)))
             (go #'(rest ...) (cons reconstructed processed) name target-type)))

          ;; shift window
          ((this rest ...)
           (go #'(rest ...) (cons #'this processed) name target-type))

          ;; got to the end but couldn't find required fields
          (() (not name)
           (syntax-violation whom "missing `#:name' in `defcfg' statement" block))
          (() (not target-type)
           (syntax-violation whom "missing `#:target-type' in `defcfg' statement" block))

          ;; done. now reverse because `cons` prepends, while the
          ;; pattern matcher consumes from the front
          (() (values (reverse processed) name target-type))))

      ;; starts as
      ;; (defcfg args ...) -> (rest (args ...)) (processed (defcfg))
      (go (cdr block) #'(defcfg) #f #f))

    (define (process-defsrc whom block)
      (validate-block whom block)
      (define (go args name keys)
        (syntax-case args ()
          ;; keyboards can be named, which can then in turn be referenced by
          ;; `(genlayer #:source ...)'
          ((#:name name rest ...)
           (go #'(rest ...) #'name keys))
          ((keyword value rest ...) (keyword? (syntax->datum #'keyword))
           (go #'(rest ...) name keys))
          ((key rest ...)
           (go #'(rest ...) name (cons #'key keys)))
          (() (cons name (reverse keys)))))
      (go (cdr block) #'#f #'()))

    (define (process-genlayer whom block)
      (validate-block whom block)
      (syntax-case (cdr block) ()
        ((name #:source source mapper) #'(name source mapper))
        ((name mapper #:source source) #'(name source mapper))
        ((name mapper) #'(name #f mapper))
        ((_)
         (syntax-violation whom "missing either `name' or `mapper' in `genlayer' block" block))
        ((_ ...)
         (syntax-violation whom "extraneous arguments in `genlayer' block" block))
        (()
         (syntax-violation whom "missing `name' and `mapper' in `genlayer' block" block))))

    (define (process-config whom expr)
      (define (go rest processed name target-type sources genlayers)
        (syntax-case rest (defcfg defsrc genlayer deflayer)
          (((defcfg args ...) rest ...) (and (not name)
                                             (not target-type))
           (call-with-values
               (lambda () (process-defcfg whom #'(defcfg args ...)))
             (lambda (defcfg-block name target-type)
               (go #'(rest ...) (cons defcfg-block processed)
                   name target-type sources genlayers))))
          (((defcfg args ...) rest ...)
           (syntax-violation whom "multiple `defcfg' blocks not allowed"
                             #'(defcfg args ...)))

          ;; accumulate sources for genlayer
          (((defsrc args ...) rest ...)
           (let ((src (process-defsrc whom #'(defsrc args ...))))
             (go #'(rest ...) (cons #'(defsrc args ...) processed)
                 name target-type (cons src sources) genlayers)))

          (((genlayer args ...) rest ...)
           (let ((gen (process-genlayer whom #'(genlayer args ...))))
             (go #'(rest ...) processed
                 name target-type sources (cons gen genlayers))))

          ;; validate-block already throws syntax-violations where appropriate
          (((other args ...) rest ...) (validate-block whom #'(other args ...))
           (go #'(rest ...) (cons #'(other args ...) processed)
               name target-type sources genlayers))

          (()
           (values (reverse processed)
                   name target-type sources genlayers))))
      (go expr '() #f #f '() '()))

    (define (make-genlayers whom sources genlayers)
      (define (make-layer genlayer)
        (syntax-case genlayer ()
          ((name source mapper)
           #`(let ((found (assq source sources)))
               (if found `(deflayer name ,@(if source '(#:source source) '())
                            ,@(map mapper (cdr found)))
                   ;; syntax-violation at eval-time omg
                   (syntax-violation
                    '#,whom
                    (if source
                        (string-append "`genlayer' statement expects "
                                       "a `defsrc' statement with the name `"
                                       (symbol->string source) "'")
                        (string-append "`genlayer' statement expects "
                                       "an unnamed `defsrc' statement"))
                    source))))
          (invalid (syntax-violation
                        (syntax->datum whom)
                        "misconstructed internal `genlayer' data structure"
                        #'invalid))))
      #`(let ((sources `#,sources)) ;; bind at eval-time
          (list #,@(map make-layer genlayers))))

    (define (make-service-type whom name target-type)
      #`(let ((name `#,name) ;; bind at eval-time
              (target-type #,target-type))
          ;; idk a nice way to use/import these values other than this
          (if (service-type? target-type)
              (service-type
               (name (symbol-append 'kmonad- name))
               (extensions (list ((@(gnu services) service-extension) target-type identity)))
               (description (string-append "KMonad configuration for keyboard: "
                                           (symbol->string name))))
              ;; i did it again omg
              (syntax-violation '#,whom "not a <service-type>" #'#,target-type))))

    (syntax-case expr ()
      ((whom expr ...)
       (call-with-values (lambda () (process-config (syntax->datum #'whom) #'(expr ...)))
         (lambda (config name target-type sources genlayers)
           ;; we already throw errors if we do encounter a `defcfg'
           ;; statement. this is in case its still undefined
           (unless (and name target-type)
             (syntax-violation (syntax->datum #'whom) "missing `defcfg' statement" #'(expr ...)))
           (define full-config
             (if (null? genlayers)
                 #`(quasiquote #,config)
                 #`(append (quasiquote #,config)
                           #,(make-genlayers #'whom sources genlayers))))
           (define service-type (make-service-type #'whom name target-type))
           #`(service #,service-type (cons '#,name #,full-config)))))
      ((whom) (syntax-violation (syntax->datum #'whom) "missing arguments" expr)))))
