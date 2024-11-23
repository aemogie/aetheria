(define-module (aetheria)
  #:use-module ((gnu system) #:select (operating-system?))
  #:use-module ((gnu home) #:select (home-environment?))
  #:export (%project-root
            system-config
            home-config))

(define %project-root
  (if (current-filename) ;; #f in repl
       (dirname (current-filename))
       "/projects/aetheria"))

(define* (system-config #:optional (system (gethostname)))
  (define system-file-name (string-append "aetheria/system/" system ".scm"))
  (define os (primitive-load-path system-file-name)) ;; the default not-found error is good enough
  (unless (operating-system? os)
    (error "file ~a doesn't produce an <operating-system>" system-file-name))
  os)

(define* (home-config #:optional (home (getlogin)))
  (define home-file-name (string-append "aetheria/home/" home ".scm"))
  (define he (primitive-load-path home-file-name)) ;; the default not-found error is good enough
  (unless (home-environment? he)
    (error "file ~a doesn't produce an <home-environment>" home-file-name))
  he)

(system-config)
