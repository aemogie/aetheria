(use-modules
 ((guix profiles) #:select (packages->manifest))
 ((gnu packages guile) #:select (guile-3.0))
 ((gnu packages base) #:select (gnu-make)))

(packages->manifest (list guile-3.0 gnu-make))
