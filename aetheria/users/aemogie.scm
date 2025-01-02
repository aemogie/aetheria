(define-module (aetheria users aemogie)
  #:use-module ((ice-9 match) #:select (match-lambda
                                         match))
  #:use-module ((guix gexp) #:select (gexp
                                      program-file))
  #:use-module ((guix packages) #:select (package))
  #:use-module ((guix licenses) #:select (gpl3) #:prefix license:)
  #:use-module ((guix monads) #:select (return
                                        with-monad))
  #:use-module ((guix store) #:select (%store-monad))
  #:use-module ((gnu services) #:select (simple-service
                                         modify-services))
  #:use-module ((gnu home) #:select (home-environment
                                     home-environment-user-services))
  #:use-module ((gnu home services) #:select (home-files-service-type))
  #:use-module ((aetheria services kmonad) #:select (kmonad-keyboard-service))
  #:use-module ((aetheria home services kmonad) #:select (home-kmonad-service-type))
  #:use-module ((aetheria home base) #:select (%aetheria-desktop-home
                                               %aetheria-desktop-home-packages
                                               %aetheria-desktop-home-services))
  #:use-module ((aetheria build-system file-like) #:select (program-file-build-system))
  #:export (make-aemogie-home))

;; TODO: configure guix's own emacs
(define old-emacs-script
  (let* ;; nivea root mount-point in the future hopefully would be tmpfs
      ((nivea "/mnt/nivea")
       ;; would be a nivea-meta partition in the future
       (nix-state-dir "/nix/var/nix")
       ;; latest system profile symlink. needs nivea-store mounted to resolve
       (system-profile (string-append nix-state-dir "/profiles/system"))
       ;; this would be "deployed" into runtime root
       ;; currently i could just forego most of the previous stuff
       ;; and just do `/mnt/nivea/etc/static/...` as it's not ephemeral
       (user-profile "/etc/profiles/per-user/aemogie")
       ;; finally, emacs
       (path (string-append nivea system-profile user-profile "/bin/emacs"))
       (script (program-file
                "nivea-emacs"
                #~(begin
                    (unsetenv "EMACSLOADPATH") ;; conflicts and gives errors
                    (apply execl (cons #$path (program-arguments)))))))
    (package
      (name "nivea-emacs")
      (version "0")
      (source script)
      (build-system program-file-build-system)
      (synopsis "launch emacs from nivea")
      (description "a script to launch emacs from serena's nivea partition")
      ;; this repo is gpl3 so, those two lines of gexp up there are the same as well
      (license license:gpl3)
      (home-page "https://github.com/aemogie/nivea"))))

(define kmonad-config
  (let* ((src '(caps))
         (initial (map (match-lambda
                         ('caps '(tap-next esc lctl))
                         (els els))
                       src)))
    `((defcfg
        input (device-file "/dev/input/by-path/platform-i8042-serio-0-event-kbd")
        output (uinput-sink "KMonad Remapped Keyboard")
        fallthrough #t)
      (defsrc ,@src)
      ;; kmonad defaults to the first deflayer
      (deflayer initial ,@initial))))

(define* (make-aemogie-home hostname)
  (home-environment
   (inherit %aetheria-desktop-home)
   (packages (append (match hostname
                       ("serena" (list old-emacs-script))
                       (_ '()))
                     %aetheria-desktop-home-packages))
   (services (append (match hostname
                       ("serena" (list
                                  (kmonad-keyboard-service 'serena-builtin
                                                           home-kmonad-service-type
                                                           kmonad-config)))
                       (_ '()))
                     %aetheria-desktop-home-services))))

(make-aemogie-home (gethostname))
