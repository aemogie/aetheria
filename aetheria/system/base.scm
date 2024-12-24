(define-module (aetheria system base)
  ;; modify-services uses this?? but i thought macros were hygenic
  #:use-module ((srfi srfi-1) #:select (delete))
  #:use-module ((gnu services) #:select (service
                                         modify-services
                                         simple-service))
  #:use-module ((gnu services desktop) #:select (%desktop-services))
  #:use-module ((gnu services xorg) #:select (gdm-service-type))
  #:use-module ((gnu services base) #:select (guix-service-type
                                              guix-configuration
                                              guix-extension
                                              %default-substitute-urls
                                              %default-authorized-guix-keys))
  #:use-module ((gnu services guix) #:select (guix-home-service-type))
  #:use-module ((gnu system) #:select (operating-system))
  #:use-module ((gnu bootloader) #:select (bootloader-configuration))
  #:use-module ((gnu bootloader grub) #:select (grub-efi-bootloader))
  #:use-module ((gnu system file-systems) #:select (%base-file-systems))
  #:use-module ((gnu system accounts) #:select (user-account))
  #:use-module ((gnu packages package-management) #:select (guix-for-channels))
  #:use-module ((guix gexp) #:select (local-file))
  #:use-module ((aetheria) #:select (%project-root))
  #:use-module ((aetheria services kmonad) #:select (kmonad-service-type))
  #:use-module ((aetheria home base) #:select (%aetheria-base-home))
  #:export (%aetheria-base-system
            %aetheria-base-services
            %aetheria-user-template))

;; this isnt cached whatsoever
;; updated note: inferiors may fix this. for now im using inferiors in my ~/.guile
;; doubly updated note: inferiors live in user's home directory
(define (aetheria-guix prev)
  ;; TOOD: can i make these be modules?
  (define locked (primitive-load-path "channels.lock.scm"))
  (guix-configuration
   (inherit prev)
   (channels locked)
   (guix (guix-for-channels locked))))

(define nonguix-substitute-service
  (simple-service
   'nonguix-substitute-service
   guix-service-type
   (guix-extension
    (substitute-urls (list "https://substitutes.nonguix.org"))
    (authorized-keys (list (local-file
                            (string-append %project-root "/substitutes/nonguix.pub")))))))

(define %aetheria-user-template
  (user-account
   (name "user")
   (group "users")
   (password (crypt "password" "$6$aetheria"))
   (supplementary-groups '("wheel" "netdev" "audio" "video" "input"))))

(define %aetheria-base-services
  (cons*
   (service guix-home-service-type (list (list "root" %aetheria-base-home)))
   nonguix-substitute-service
   (service kmonad-service-type) ;; for udev rules
   (modify-services %desktop-services
     ;; TODO: figure out how to set system-wide channel in a non-annoying way
     ;; (guix-service-type prev => (aetheria-guix prev))
     (delete gdm-service-type))))

(define %aetheria-base-system
  (operating-system
    (host-name "aetheria")
    (locale "en_GB.utf8")
    ;; TODO: look into moving to host-specific configuration. maybe introduce
    ;; another abstraction which is then rendered to an <operating-system>?
    (bootloader (bootloader-configuration
                 (bootloader grub-efi-bootloader)
                 (targets '("/boot"))))
    (services %aetheria-base-services)
    (file-systems %base-file-systems)))
