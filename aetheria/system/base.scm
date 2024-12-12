(define-module (aetheria system base)
  ;; modify-services uses this?? but i thought macros were hygenic
  #:use-module ((srfi srfi-1) #:select (delete))
  #:use-module ((gnu services) #:select (service
                                         modify-services))
  #:use-module ((gnu services desktop) #:select (%desktop-services))
  #:use-module ((gnu services xorg) #:select (gdm-service-type))
  #:use-module ((gnu services base) #:select (guix-service-type
                                              guix-configuration
                                              %default-substitute-urls
                                              %default-authorized-guix-keys))
  #:use-module ((gnu services guix) #:select (guix-home-service-type))
  #:use-module ((gnu system) #:select (operating-system))
  #:use-module ((gnu bootloader) #:select (bootloader-configuration))
  #:use-module ((gnu bootloader grub) #:select (grub-efi-bootloader))
  #:use-module ((gnu system file-systems) #:select (%base-file-systems))
  #:use-module ((gnu packages package-management) #:select (guix-for-channels))
  #:use-module ((guix gexp) #:select (local-file))
  #:use-module ((aetheria) #:select (%project-root))
  #:use-module ((aetheria users aemogie) #:select (aemogie))
  #:export (%aetheria-base-system))

(define (aetheria-guix prev)
  ;; TOOD: can i make these be modules?
  (define locked (primitive-load-path "channels.lock.scm"))
  (guix-configuration
   (inherit prev)
   (channels locked)
   ;; this isnt cached whatsoever
   ;; updated note: inferiors may fix this. for now im using inferiors in my ~/.guile
   ;; (guix (guix-for-channels locked))
   (substitute-urls
    (cons* "https://substitutes.nonguix.org"
           %default-substitute-urls))
   (authorized-keys
    (cons* (local-file
            (string-append %project-root "/substitutes/nonguix.pub"))
           %default-authorized-guix-keys))))

(define %aetheria-base-system
  (operating-system
    (host-name "aetheria")
    (locale "en_GB.utf8")
    ;; TODO: look into moving to host-specific configuration. maybe introduce
    ;; another abstraction which is then rendered to an <operating-system>?
    (bootloader (bootloader-configuration
                 (bootloader grub-efi-bootloader)
                 (targets '("/boot"))))
    (services (cons*
               (service guix-home-service-type)
               (modify-services %desktop-services
                 (delete gdm-service-type)
                 ;; TODO: figure out how to set system-wide channel in a non-annoying way
                 (guix-service-type prev => (aetheria-guix prev)))))
    (file-systems %base-file-systems)))
