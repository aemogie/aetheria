(define-module (aetheria home base)
  #:use-module ((gnu services) #:select (service))
  #:use-module ((gnu system shadow) #:select (%default-dotguile
                                              %default-xdefaults
                                              %default-gdbinit
                                              %default-nanorc))
  #:use-module ((gnu home) #:select (home-environment))
  #:use-module ((gnu home services) #:select (home-files-service-type
                                              home-xdg-configuration-files-service-type))
  #:use-module ((gnu home services shepherd) #:select (home-shepherd-service-type))
  #:use-module ((gnu home services shells) #:select (home-bash-service-type))
  #:use-module ((gnu home services desktop) #:select (home-dbus-service-type))
  #:use-module ((gnu home services sound) #:select (home-pipewire-service-type))
  #:use-module ((gnu packages base) #:select (gnu-make))
  #:use-module ((gnu packages gcc) #:select (gcc))
  #:use-module ((gnu packages version-control) #:select (git))
  #:use-module ((gnu packages text-editors) #:select (nano))
  #:use-module ((gnu packages vim) #:select (vim))
  #:use-module ((gnu packages emacs) #:select (emacs-pgtk-xwidgets))
  #:use-module ((guix gexp) #:select (plain-file))
  #:export (%aetheria-base-home-services
            %aetheria-base-home-packages
            %aetheria-base-home
            %aetheria-desktop-home-services
            %aetheria-desktop-home-packages
            %aetheria-desktop-home))

(define %aetheria-base-home-services
  (list
   (service home-bash-service-type)
   ;; runs weirdly. C-c kills it for some reason?
   (service home-shepherd-service-type)
   (service home-files-service-type
            `((".guile" ,%default-dotguile)
              (".Xdefaults" ,%default-xdefaults)))

   (service home-xdg-configuration-files-service-type
            `(("gdb/gdbinit" ,%default-gdbinit)
              ("nano/nanorc" ,%default-nanorc)
              ;; should i persist this?
              ("guix/shell-authorized-directories"
               ,(plain-file "shell-authorized-directories"
                            "/projects/aetheria"))))))

(define %aetheria-base-home-packages
  ;; just tiny/essential cli stuff. shouldnt require any graphics, all things
  ;; you can use over ssh for exmaple. fyi: i dont use vim, but the keybinds
  ;; are definitely better than whatever nano got
  (list gnu-make git gcc vim))

(define %aetheria-base-home
  (home-environment
   (services %aetheria-base-home-services)
   (packages %aetheria-base-home-packages)))

(define %aetheria-desktop-home-services
  (cons*
   (service home-dbus-service-type)
   (service home-pipewire-service-type)
   %aetheria-base-home-services))

(define %aetheria-desktop-home-packages
  (cons*
   emacs-pgtk-xwidgets ;; TODO: emacs module?
   %aetheria-base-home-packages))

(define %aetheria-desktop-home
  (home-environment
   (services %aetheria-desktop-home-services)
   (packages %aetheria-desktop-home-packages)))
