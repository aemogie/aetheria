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
  #:use-module ((gnu system) #:select (%base-packages
                                       operating-system))
  #:use-module ((gnu system accounts) #:select (user-account))
  #:use-module ((gnu system shadow) #:select (%base-user-accounts))
  #:use-module ((gnu system file-systems) #:select (%base-file-systems))
  #:use-module ((gnu packages wm) #:select (cage))
  #:use-module ((gnu packages gnuzilla) #:select (icecat))
  #:use-module ((gnu bootloader) #:select (bootloader-configuration))
  #:use-module ((gnu bootloader grub) #:select (grub-efi-bootloader))
  #:use-module ((guix gexp) #:select (local-file))
  #:use-module ((aetheria) #:select (%project-root))
  #:use-module ((aetheria home aemogie) #:select (aemogie))
  #:export (%aetheria-base-system))

(define services
  (cons*
   (service guix-home-service-type
            `(("aemogie" ,aemogie)))
   (modify-services %desktop-services
     (delete gdm-service-type)
     ;; TODO: figure out how to set system-wide channel in a non-annoying way
     (guix-service-type config =>
                        (guix-configuration
                         (inherit config)
                         (substitute-urls
                          (cons* "https://substitutes.nonguix.org"
                                 %default-substitute-urls))
                         (authorized-keys
                          (cons* (local-file
                                  (string-append %project-root "/substitutes/nonguix.pub"))
                                 %default-authorized-guix-keys)))))))

(define accounts
  (list (user-account
         (name "aemogie")
         (group "users")
         (password (crypt "password" "$6$aetheria"))
         (supplementary-groups '("wheel" "netdev" "audio" "video")))))

(define %aetheria-base-system
  (operating-system
    (host-name "aetheria")
    (bootloader (bootloader-configuration
                 (bootloader grub-efi-bootloader)
                 (targets '("/boot"))))
    (users (append accounts %base-user-accounts))
    (packages
     (cons* cage icecat ;; good enough to begin
            %base-packages))
    (services services)
    (file-systems %base-file-systems)))
