(define-module (aetheria users aemogie)
  #:use-module ((ice-9 match) #:select (match))
  #:use-module ((guix gexp) #:select (gexp
                                      program-file))
  #:use-module ((gnu services) #:select (simple-service
                                         modify-services))
  #:use-module ((gnu home) #:select (home-environment
                                     home-environment-user-services))
  #:use-module ((gnu home services) #:select (home-files-service-type))
  #:use-module ((aetheria services kmonad) #:select (kmonad-keyboard-service))
  #:use-module ((aetheria home services kmonad) #:select (home-kmonad-service-type))
  #:use-module ((aetheria home base) #:select (%aetheria-desktop-home
                                               %aetheria-desktop-home-services))
  #:export (make-aemogie-home))

;; TODO: configure guix's own emacs
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

(define* (make-aemogie-home hostname)
  (home-environment
   (inherit %aetheria-desktop-home)
   (services
    (append (match hostname
              ("serena" (list kmonad-config
                              (simple-service
                               'old-emacs-script home-files-service-type
                               (list (list "emacs" (old-emacs-script))))))
              (_ '()))
            %aetheria-desktop-home-services))))

(make-aemogie-home (gethostname))
