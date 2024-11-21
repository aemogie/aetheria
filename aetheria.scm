(define-module (aetheria) #:export (%project-root))

(define %project-root
  (if  (current-filename)
       (dirname (current-filename))
       "/projects/aetheria"))
