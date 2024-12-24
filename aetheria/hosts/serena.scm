(define-module (aetheria hosts serena)
  #:use-module ((srfi srfi-1) #:select (filter-map))
  #:use-module ((ice-9 match) #:select (match-lambda))
  #:use-module ((guix gexp) #:select (gexp program-file))
  #:use-module ((gnu system) #:select (operating-system-user-services
                                       %base-packages
                                       operating-system))
  #:use-module ((gnu system linux-initrd) #:select (%base-initrd-modules))
  #:use-module ((gnu system accounts) #:select (user-account))
  #:use-module ((gnu system shadow) #:select (%base-user-accounts))
  #:use-module ((gnu services) #:select (service
                                         modify-services))
  #:use-module ((gnu services guix) #:select (guix-home-service-type))
  #:use-module ((gnu home) #:select (home-environment
                                     home-environment?
                                     home-environment-user-services))
  #:use-module ((gnu home services) #:select (home-files-service-type))
  #:use-module ((gnu packages wm) #:select (cage))
  #:use-module ((gnu packages gnuzilla) #:select (icecat))
  #:use-module ((nongnu packages linux) #:select (linux
                                                  linux-firmware
                                                  sof-firmware))
  #:use-module ((nongnu system linux-initrd) #:select (microcode-initrd))
  #:use-module ((aetheria system base) #:select (%aetheria-base-system))
  #:use-module ((aetheria services kmonad) #:select (kmonad-service-type
                                                     kmonad-keyboard-service))
  #:use-module ((aetheria hosts serena file-systems) #:select (serena-file-systems))
  #:use-module ((aetheria home base) #:select (%aetheria-base-home))
  #:use-module ((aetheria home services kmonad) #:select (home-kmonad-service-type))
  #:use-module ((aetheria users aemogie) #:select (aemogie))
  #:export (serena))

(define (old-emacs-script)
  (define path
    (string-append
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
     "/bin/emacs"))
  (program-file
   "nivea-emacs"
   #~(begin
       (unsetenv "EMACSLOADPATH")
       (apply execl (cons #$path (program-arguments))))))

;; todo: move to (aetheria users aemogie)
(define kmonad-config
  (kmonad-keyboard-service
   (defcfg
     #:name serena-builtin
     #:target-type home-kmonad-service-type
     #:input (device-file "/dev/input/by-path/platform-i8042-serio-0-event-kbd")
     #:output (uinput-sink "KMonad Remapped Keyboard")
     #:fallthrough #t)
   (defsrc
     caps)
   (deflayer initial ;; kmonad defaults to the first deflayer
     (tap-next esc lctl))))

(define serena-accounts
  `(("aemogie"
     ,(home-environment
       (inherit aemogie)
       (services (cons*
                  kmonad-config
                  (modify-services (home-environment-user-services aemogie)
                    (home-files-service-type
                     files =>
                     (cons (list "emacs" (old-emacs-script))
                           files))))))
     ,(user-account
       (name "aemogie")
       (group "users")
       (password (crypt "password" "$6$aetheria"))
       (supplementary-groups '("wheel" "netdev" "audio" "video" "input"))))
    ("root" ,%aetheria-base-home #f)))

;; maybe introduce a wrapper record that can then be rendered down to <operating-system>?
(define serena
  (operating-system
    (inherit %aetheria-base-system)
    (host-name "serena")
    (timezone "Asia/Colombo")
    (kernel linux)
    (initrd microcode-initrd)
    (initrd-modules
     (cons* "vmd" ;; intel vmd so it sees my disks
            %base-initrd-modules))
    (firmware (list linux-firmware
                    sof-firmware))
    (file-systems serena-file-systems)
    (users (append (filter-map caddr serena-accounts)
                   %base-user-accounts))
    (packages
     (cons* cage icecat ;; good enough to begin
            %base-packages))
    (services
     (cons*
      (service kmonad-service-type) ;; for udev rules
      (modify-services (operating-system-user-services %aetheria-base-system)
        (guix-home-service-type
         config =>
         (append (filter-map
                  (match-lambda ((name (? home-environment? he) _) `(,name ,he)))
                  serena-accounts)
                 config)))))))

;; consumed by (@ (aetheria) system-config)
serena
