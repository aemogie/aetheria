(define-module (aetheria home base)
  #:use-module ((guix gexp) #:select (gexp
                                      scheme-file))
  #:use-module ((gnu services) #:select (service))
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
  #:use-module ((gnu packages base) #:select (gnu-make))
  #:use-module ((gnu packages gcc) #:select (gcc))
  #:use-module ((gnu packages version-control) #:select (git))
  #:use-module ((gnu packages text-editors) #:select (nano))
  #:use-module ((gnu packages vim) #:select (vim))
  #:use-module ((gnu packages emacs) #:select (emacs-pgtk-xwidgets))
  #:use-module ((gnu packages xdisorg) #:select (wl-clipboard))
  #:use-module ((gnu packages terminals) #:select (foot))
  #:use-module ((gnu packages fonts) #:select (font-iosevka
					       font-iosevka-comfy
					       font-google-noto
					       font-google-noto-emoji
					       font-google-noto-sans-cjk
					       font-google-noto-serif-cjk))
  #:use-module ((rosenthal packages wm) #:select (hyprland))
  #:export (%aetheria-base-home-services
            %aetheria-base-home-packages
            %aetheria-base-home
            %aetheria-desktop-home-services
            %aetheria-desktop-home-packages
            %aetheria-desktop-home))

(define dotguile-gexp
  #~(;; default .guile
     (cond ((false-if-exception (resolve-interface '(ice-9 readline)))
            =>
            (lambda (module)
              ;; Enable completion and input history at the REPL.
              ((module-ref module 'activate-readline))))
           (else
            (display "Consider installing the 'guile-readline' package for
convenient interactive line editing and input history.\n\n")))

     (unless (getenv "INSIDE_EMACS")
       (cond ((false-if-exception (resolve-interface '(ice-9 colorized)))
              =>
              (lambda (module)
                ;; Enable completion and input history at the REPL.
                ((module-ref module 'activate-colorized))))
             (else
              (display "Consider installing the 'guile-colorized' package
for a colorful Guile experience.\n\n"))))
     ;; end of default .guile

     ;; do we just pray these exist?
     (use-modules ((guix inferior) #:select (cached-channel-instance))
                  ((guix store) #:select (with-store)))

     (define channel-list (@@(guix scripts time-machine) channel-list))
     (define cached-inferior
       (with-store store (cached-channel-instance store (channel-list '()))))
     (define inferior-guile-path
       (string-append cached-inferior "/share/guile/site/3.0"))
     (add-to-load-path inferior-guile-path)))

(define %aetheria-base-home-services
  (list
   (service home-bash-service-type)
   ;; started from hyprland config which is being persisted locally for now
   (service home-shepherd-service-type (home-shepherd-configuration (auto-start? #f)))
   (service home-files-service-type
            `((".guile" ,(scheme-file "dotguile" dotguile-gexp #:splice? #t))
              (".Xdefaults" ,%default-xdefaults)))

   (service home-xdg-configuration-files-service-type
            `(("gdb/gdbinit" ,%default-gdbinit)
              ("nano/nanorc" ,%default-nanorc)))))

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
   hyprland wl-clipboard foot
   emacs-pgtk-xwidgets ;; TODO: emacs module?
   font-iosevka font-iosevka-comfy
   ;; no tofu or something, i dont really know
   font-google-noto font-google-noto-emoji font-google-noto-sans-cjk font-google-noto-serif-cjk
   %aetheria-base-home-packages))

(define %aetheria-desktop-home
  (home-environment
   (services %aetheria-desktop-home-services)
   (packages %aetheria-desktop-home-packages)))
