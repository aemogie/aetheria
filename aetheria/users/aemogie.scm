(define-module (aetheria users aemogie)
  #:use-module ((srfi srfi-1) #:select (filter-map))
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

(define (serena-keyboard)
  ;; order is irrelevant as we'll be using match-lambda to generate the layers
  ;; formatting is just so that it's pretty

  (define fn-keys
    ;; keys f1, f8 and f9 dont work well anymore, have to press with
    ;; force. don't rely. same applies for action key variants of these keys
    ;; as well
    '(f1   f2   f3   f4   f5   f6   f7   f8   f9   f10  f11  f12  ins))

  (define action-keys
    (filter-map
     (lambda (fn-key)
       (match fn-key
         ;; "help" key for windows laptops. emits `windows + f1`.
         ('f1 #f)
         ;; won't get fired for some reason. libinput shows it, evtest shows
         ;; it. kmonad doesnt
         ('f2 'brdown)
         ('f3 'brup) ;; wont fire this either
         ;; "monitor" key for windows. emits `windows + p` the windows projection keybind.
         ('f4 #f)
         ;; blank key, emits nothing when pressed without `fn` key
         ('f5 #f)
         ('f6 'mute)
         ('f7 'volumedown)
         ('f8 'volumeup)
         ('f9 'previoussong)
         ('f10 'playpause)
         ('f11 'nextsong)
         ;; rfkill/airplane mode key. the name was merged into kmonad a while back, but that
         ;; commit has yet to make it into any releases
         ('f12 'missing247) ;; this doesnt get fired either
         ('ins 'sysrq) ;; print screen
         (_ #f)))
     fn-keys))

  (define main
    ;; esc and del are common to the rows
    ;; initial space helps keep alignment
    `( esc                     ,@(append fn-keys action-keys)                        del
       #\`   1     2     3     4     5     6     7     8     9     0     #\-   #\=   bspc
       tab   q     w     e     r     t     y     u     i     o     p     #\[   #\]   #\\
       caps  a     s     d     f     g     h     j     k     l     #\;   #\'   ret
       lsft  z     x     c     v     b     n     m     #\,   #\.   #\/   rsft
       lctl  lmet  lalt              spc               ralt  rctl  lft   up    down  rght))

  (define keypad
    '( home end  pgup pgdn
       nlck kp/  kp*  kp-
       kp7  kp8  kp9  kp+
       kp4  kp5  kp6
       kp1  kp2  kp3  kprt
       kp0       kp.))

  (append main keypad))

(define (make-kmonad-config hostname)
  (define src
    (match hostname
      ("serena" (serena-keyboard))
      (els (error "keyboard source not defined for host" els))))
  (define input-file
    (match hostname
      ("serena" "/dev/input/by-path/platform-i8042-serio-0-event-kbd")
      (els (error "keyboard input file not defined for host" els))))

  `((defcfg
      input (device-file ,input-file)
      output (uinput-sink "KMonad Remapped Keyboard")
      fallthrough #t)
    (defsrc ,@src)
    ;; kmonad defaults to the first deflayer
    (deflayer initial
      ,@(map (match-lambda
               ('caps '(tap-next esc (layer-toggle navigation)))
               ('ret '(tap-next ret (layer-toggle navigation)))
               ((or 'up 'rght 'down 'lft) 'XX)
               ((or 'home 'end) 'XX)
               ((or 'esc 'lctl) 'XX)
               ('nlck 'XX)
               (els els))
             src))

    ;; this is fake control because this doesnt add lctl to keys not
    ;; specified in defsrc
    (deflayer navigation
      ,@(map (match-lambda
               ('h 'lft)
               ('j 'down)
               ('k 'up)
               ('l 'right)
               ('g 'home)
               (#\; 'end)
               ((? integer? int) (symbol-append 'C- (string->symbol (number->string int))))
               ((? char? char) (symbol-append 'C- (list->symbol (list char))))
               ((? symbol? sym) (symbol-append 'C- sym)))
             src))))

(define* (make-aemogie-home hostname)
  (home-environment
   (inherit %aetheria-desktop-home)
   (packages (append (match hostname
                       ("serena" (list old-emacs-script))
                       (_ '()))
                     %aetheria-desktop-home-packages))
   (services (append (match hostname
                       ("serena" (list
                                  (kmonad-keyboard-service
                                   'serena-builtin home-kmonad-service-type
                                   (make-kmonad-config hostname))))
                       (_ '()))
                     %aetheria-desktop-home-services))))

(make-aemogie-home (gethostname))
