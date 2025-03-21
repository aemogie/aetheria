(define-module (aetheria home base)
  #:use-module ((guix gexp) #:select (gexp
                                      scheme-file
                                      file-append
                                      plain-file))
  #:use-module ((gnu services) #:select (service
                                         simple-service))
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
  #:use-module ((gnu home services desktop) #:select (home-dbus-service-type))
  #:use-module ((gnu home services sound) #:select (home-pipewire-service-type))
  #:use-module ((gnu home services gnupg) #:select (home-gpg-agent-service-type
                                                    home-gpg-agent-configuration))
  #:use-module ((gnu packages base) #:select (gnu-make))
  #:use-module ((gnu packages gcc) #:select (gcc))
  #:use-module ((gnu packages version-control) #:select (git))
  #:use-module ((gnu packages vim) #:select (vim))
  #:use-module ((gnu packages gnupg) #:select (gnupg
                                               pinentry-tty))
  #:use-module ((gnu packages wm) #:select (hyprland
                                            waybar
                                            cage))
  #:use-module ((gnu packages linux) #:select (bluez))
  #:use-module ((gnu packages librewolf) #:select (librewolf))
  #:use-module ((gnu packages emacs) #:select (emacs-pgtk-xwidgets))
  #:use-module ((gnu packages xdisorg) #:select (wl-clipboard))
  #:use-module ((gnu packages terminals) #:select (foot))
  #:use-module ((gnu packages fonts) #:select (font-iosevka
                                               font-iosevka-comfy
                                               font-google-noto
                                               font-google-noto-emoji
                                               font-google-noto-sans-cjk
                                               font-google-noto-serif-cjk))
  #:export (%aetheria-base-home-services
            %aetheria-base-home-packages
            %aetheria-base-home
            %aetheria-desktop-home-services
            %aetheria-desktop-home-packages
            %aetheria-desktop-home))

(define %aetheria-base-home-services
  (list
   (service home-bash-service-type)
   ;; started from hyprland config which is being persisted locally for now
   (service home-shepherd-service-type
            (home-shepherd-configuration
             (auto-start? #f)
             (daemonize? #f)
             (services (list (shepherd-service
                              (provision '(repl))
                              (modules '((shepherd service repl)))
                              (free-form #~(repl-service)))))))
   (service home-gpg-agent-service-type
            (home-gpg-agent-configuration
             (ssh-support? #t)
             (pinentry-program
              ;; default pinentry-curses doesnt work with eshell/eat
              (file-append pinentry-tty "/bin/pinentry-tty"))
             (extra-content "allow-loopback-pinentry")))
   (service home-files-service-type
            `((".guile" ,%default-dotguile)
              (".Xdefaults" ,%default-xdefaults)
              (".gnupg/gpg.conf" ,(plain-file "gpg.conf" "pinentry-mode loopback"))))

   (service home-xdg-configuration-files-service-type
            `(("gdb/gdbinit" ,%default-gdbinit)
              ("nano/nanorc" ,%default-nanorc)))))

(define %aetheria-base-home-packages
  ;; just tiny/essential cli stuff. shouldnt require any graphics, all things
  ;; you can use over ssh for exmaple. fyi: i dont use vim, but the keybinds
  ;; are definitely better than whatever nano got
  (list gnu-make git gcc vim gnupg))

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
   hyprland waybar wl-clipboard cage bluez
   librewolf foot emacs-pgtk-xwidgets ;; TODO: emacs module?
   font-iosevka font-iosevka-comfy
   ;; no tofu or something, i dont really know
   font-google-noto font-google-noto-emoji font-google-noto-sans-cjk font-google-noto-serif-cjk
   %aetheria-base-home-packages))

(define %aetheria-desktop-home
  (home-environment
   (services %aetheria-desktop-home-services)
   (packages %aetheria-desktop-home-packages)))
