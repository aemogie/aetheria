(define-module (aetheria build-system raw)
  #:use-module ((ice-9 match) #:select (match))
  #:use-module ((guix monads) #:select (mlet))
  #:use-module ((guix store) #:select (%store-monad))
  #:use-module ((guix gexp) #:select (lower-object))
  #:use-module ((guix build-system) #:select (bag build-system))
  #:export (raw-build-system))

(define* (build _name _inputs #:key system source target #:allow-other-keys)
  (mlet %store-monad ((obj source))
    (apply lower-object obj system (if target `(#:target ,target) '()))))

;; copied and tweaked from trivial build system
(define* (lower name #:key source inputs native-inputs outputs
                system target #:rest rest)
  (bag
    (name name)
    (system system)
    (target target)
    (host-inputs inputs)
    (build-inputs native-inputs)
    (outputs outputs)
    (build build)
    (arguments `(#:source ,source #:target ,target))))

(define raw-build-system
  (build-system
    (name 'identity)
    (description "source must be a derivation that can be returned raw")
    (lower lower)))
