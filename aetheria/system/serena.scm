(define-module (aetheria system serena)
  #:use-module ((gnu system) #:select (operating-system))
  #:use-module ((gnu system linux-initrd) #:select (%base-initrd-modules))
  #:use-module ((nongnu packages linux) #:select (linux
                                                  linux-firmware
                                                  sof-firmware))
  #:use-module ((nongnu system linux-initrd) #:select (microcode-initrd))
  #:use-module ((aetheria system base) #:select (%aetheria-base-system))
  #:use-module ((aetheria system serena file-systems) #:select (serena-file-systems))
  #:export (serena))

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
    (file-systems serena-file-systems)))

;; consumed by (@ (aetheria) config-for-os)
serena
