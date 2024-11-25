(define-module (aetheria system serena)
  #:use-module ((srfi srfi-1) #:select (find))
  #:use-module ((ice-9 match) #:select (match-lambda))
  #:use-module ((guix gexp) #:select (gexp program-file))
  #:use-module ((guix packages) #:select (package))
  #:use-module ((gnu system) #:select (operating-system-user-services
                                       %base-packages
                                       operating-system))
  #:use-module ((gnu system file-systems) #:select (file-system-mount-point))
  #:use-module ((gnu system linux-initrd) #:select (%base-initrd-modules))
  #:use-module ((gnu services) #:select (service modify-services))
  #:use-module ((gnu services guix) #:select (guix-home-service-type))
  #:use-module ((gnu home) #:select (home-environment
                                     home-environment-user-services))
  #:use-module ((gnu home services) #:select (home-files-service-type))
  #:use-module ((gnu packages wm) #:select (cage))
  #:use-module ((gnu packages gnuzilla) #:select (icecat))
  #:use-module ((nongnu packages linux) #:select (linux
                                                  linux-firmware
                                                  sof-firmware))
  #:use-module ((nongnu system linux-initrd) #:select (microcode-initrd))
  #:use-module ((aetheria system base) #:select (%aetheria-base-system))
  #:use-module ((aetheria system serena file-systems) #:select (serena-file-systems))
  #:export (serena))

(define old-emacs-script
  (program-file
   "nivea-emacs"
   #~(begin
       (unsetenv "EMACSLOADPATH")
       (execl #$(string-append
                 ;; nivea root mount-point
                 ;; in the future hopefully would be tmpfs
                 "/mnt/nivea"
                 ;; would be a nivea-meta partition in the future
                 "/nix/var/nix"
                 ;; latest system profile symlink. needs nivea-store mounted to resolve
                 "/profiles/system"
                 ;; this would be "deployed" into runtime root
                 ;; currently i could just forego most of the previous stuff
                 ;; and just do `/mnt/nivea/etc/static/...` as it's not ephemeral
                 "/etc/profiles/per-user/aemogie"
                 ;; finally, emacs
                 "/bin/emacs")))))

;; migrate as much as possible out of hsot config
(define serena
  (operating-system
    (inherit %aetheria-base-system)
    (host-name "serena")
    (timezone "Asia/Colombo")
    (locale "en_GB.utf8")
    (kernel linux)
    (initrd microcode-initrd)
    (initrd-modules
     (cons* "vmd" ;; intel vmd so it sees my disks
            %base-initrd-modules))
    (firmware (list linux-firmware
                    sof-firmware))
    (file-systems serena-file-systems)
    (packages
     (cons* cage icecat ;; good enough to begin
            %base-packages))
    (services
     (modify-services (operating-system-user-services %aetheria-base-system)
       (guix-home-service-type
        config =>
        (map (match-lambda
               ((user he)
                `(,user ,(home-environment
                          (inherit he)
                          (services
                           (modify-services (home-environment-user-services he)
                             (home-files-service-type
                              files => (cons* `("emacs" ,old-emacs-script)
                                              files))))))))
             config))))))

;; consumed by (@ (aetheria) system-config)
serena
