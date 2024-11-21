(define-module (aetheria hosts serena)
  #:use-module (gnu)
  #:use-module (gnu bootloader)
  #:use-module (gnu bootloader grub)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu system linux-initrd)
  #:use-module (gnu services desktop) ;; %desktop-services
  #:use-module (gnu services xorg) ;; gdm-service-type
  #:use-module (gnu packages wm) ;; cage
  #:use-module (gnu packages gnuzilla) ;; icecat
  #:use-module (aetheria)
  #:use-module (aetheria hosts serena file-systems)
  #:export (serena-operating-system))

(define aetheria-accounts
  (list (user-account
         (name "aemogie")
         (group "users")
         (password (crypt "password" "$6$aetheria+seren"))
         (supplementary-groups '("wheel" "netdev" "audio" "video")))))

(define aetheria-services
  (modify-services %desktop-services
    (delete gdm-service-type)
    ;; TODO: figure out how to set system-wide channel in a non-annoying way
    (guix-service-type
     config =>
     (guix-configuration
      (inherit config)
      (substitute-urls (cons* "https://substitutes.nonguix.org"
                              %default-substitute-urls))
      (authorized-keys (cons* (local-file (string-append %project-root "/substitutes/nonguix.pub"))
                              %default-authorized-guix-keys))))))

;; migrate as much as possible out of hsot config
(define serena-operating-system
  (operating-system
    (kernel linux)
    (initrd microcode-initrd)
    (initrd-modules
     (cons* "vmd" ;; intel vmd so it sees my disks
            %base-initrd-modules))
    (firmware (list linux-firmware))
    (host-name "serena")
    (timezone "Asia/Colombo")
    (locale "en_GB.utf8")

    (users (append aetheria-accounts %base-user-accounts))

    (packages
     (cons* cage icecat ;; good enough to begin
            %base-packages))
    (services aetheria-services)

    (bootloader
     (bootloader-configuration
      (bootloader grub-efi-bootloader)
      (targets '("/boot"))))

    (file-systems serena-file-systems)))

serena-operating-system
