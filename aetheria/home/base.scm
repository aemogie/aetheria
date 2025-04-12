(define-module (aetheria home base)
  #:use-module ((guix gexp) #:select (gexp
                                      plain-file))
  #:use-module ((gnu services) #:select (service))
  #:use-module ((gnu services shepherd) #:select (shepherd-service))
  #:use-module ((gnu system shadow) #:select (%default-dotguile
                                              %default-xdefaults
                                              %default-gdbinit
                                              %default-nanorc))
  #:use-module ((gnu home) #:select (home-environment))
  #:use-module ((gnu home services) #:select (home-files-service-type
                                              home-xdg-configuration-files-service-type))
  #:use-module ((gnu home services shepherd) #:select (home-shepherd-service-type
                                                       home-shepherd-configuration))
  #:use-module ((gnu home services shells) #:select (home-bash-service-type))
  #:use-module ((gnu packages base) #:select (gnu-make))
  #:use-module ((gnu packages gcc) #:select (gcc))
  #:use-module ((gnu packages version-control) #:select (git))
  #:use-module ((gnu packages vim) #:select (vim))
  #:use-module ((gnu packages shellutils) #:select (direnv))
  #:use-module ((aetheria home services security) #:select (home-security-service-type))
  #:use-module ((aetheria home services desktop) #:select (home-desktop-service-type))
  #:export (%aetheria-base-home-services
            %aetheria-base-home-packages
            %aetheria-base-home
            %aetheria-desktop-home))

;; TODO: clean this up into individual services
(define %aetheria-base-home-services
  (list
   (service home-bash-service-type)
   (service home-security-service-type)
   ;; started from hyprland config which is being persisted locally for now
   (service home-shepherd-service-type
            (home-shepherd-configuration
             (auto-start? #f)
             (daemonize? #f)
             (services (list (shepherd-service
                              (provision '(repl))
                              (modules '((shepherd service repl)))
                              (free-form #~(repl-service)))))))
   (service home-files-service-type
            `((".guile" ,%default-dotguile)
              (".Xdefaults" ,%default-xdefaults)))

   (service home-xdg-configuration-files-service-type
            `(("gdb/gdbinit" ,%default-gdbinit)
              ("nano/nanorc" ,%default-nanorc)))))

(define %aetheria-base-home-packages
  ;; just tiny/essential cli stuff. shouldnt require any graphics, all things
  ;; you can use over ssh for exmaple. fyi: i dont use vim, but the keybinds
  ;; are definitely better than whatever nano got
  (list direnv git vim))

(define %aetheria-base-home
  (home-environment
   (services %aetheria-base-home-services)
   (packages %aetheria-base-home-packages)))

(define %aetheria-desktop-home
  (home-environment
   (inherit %aetheria-base-home)
   (services (cons (service home-desktop-service-type)
                   %aetheria-base-home-services))))
