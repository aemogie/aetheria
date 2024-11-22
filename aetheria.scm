(define-module (aetheria)
  #:use-module ((gnu system) #:select (operating-system?))
  #:export (%project-root
            config-for-os))

(define %project-root
  (if (current-filename) ;; #f in repl
       (dirname (current-filename))
       "/projects/aetheria"))

(define* (config-for-os #:optional (hostname (gethostname)))
  (define host-file-name (string-append "aetheria/hosts/" hostname ".scm"))
  (define os (primitive-load-path host-file-name)) ;; the default error is good enough
  (unless (operating-system? os)
    (error "file ~a doesn't produce an <operating-system>" host-file-name))
  os)
