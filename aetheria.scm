(define-module (aetheria)
  #:use-module (gnu system) ;; operating-system?
  #:export (%project-root
            config-for-os))

(define %project-root
  (if (current-filename) ;; #f in repl
       (dirname (current-filename))
       "/projects/aetheria"))

(define* (config-for-os #:optional (hostname (gethostname)))
  (define module-name `(aetheria hosts ,(string->symbol hostname)))
  (define os-var-name (string->symbol (string-append hostname "-operating-system")))

  (define host-module
    (resolve-module module-name #t #:ensure #f))
  (unless host-module
    (error (format #f "configuration not found. ensure that module ~a exists"
                   module-name)))
  (define host-os-var
    (module-variable host-module os-var-name))
  (unless host-os-var
    (error (format #f "module ~a exists, but variable '~a' doesn't exist"
                   module-name os-var-name)))
  (define host-os (variable-ref host-os-var))
  (unless (operating-system? host-os)
    (error (format #f "module ~a has variable '~a' but isn't of type <operating-system>"
                   module-name os-var-name)))
  host-os)
