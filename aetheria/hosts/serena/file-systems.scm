(define-module (aetheria hosts serena file-systems)
  #:use-module (gnu system file-systems)
  #:use-module (aetheria system file-systems)
  #:export (serena-file-systems))

;; TOOD: figure out how to change grub.cfg path, then migrate to serena-boot
(define boot
  (file-system
    (device (file-system-label "BOOTTMP"))
    (mount-point "/boot")
    (type "vfat")
    (mount-may-fail? #t)))

(define (serena-part subvol mount-point)
  (file-system
    (inherit (btrfs-file-system
              #:mount-point mount-point
              #:device (file-system-label "serena")
              #:ssd? #t
              #:subvolume subvol))
    (needed-for-boot? #t)))

(define rootfs
  (file-system
    (inherit (serena-part "@" "/"))
    (mount-may-fail? #f)
    ;; TODO: figure out how to wipe+snapshot btrfs on boot
    ;; using tmpfs till then
    (mount-point "/")
    (device "none")
    (type "tmpfs")
    (options #f)))

(define aetheria-store
  (file-system
    (inherit (serena-part "@aetheria-store" "/gnu/store"))
    (mount-may-fail? #f)))

(define aetheria-meta (serena-part "@aetheria-meta" "/var/guix"))

;; figure out a place to put encrypted secrets
;; create way to create the source directory, other than manually doing it
(define persist-part
  (btrfs-file-system
   #:mount-point "/@persist"
   #:device (file-system-label "serena-persist")))

(define nivea
  (file-system
    (mount-point "/mnt/nivea")
    (device (file-system-label "NIXOS"))
    (type "ext4")
    (flags '(read-only))
    (mount-may-fail? #t)))

(define nivea-home ;; migrate to serena-persist btrfs pool
  (file-system
    (mount-point "/mnt/nivea/home")
    (device (file-system-label "NIXHOME"))
    (type "ext4")
    (dependencies (list nivea))
    (mount-may-fail? #t)))

(define serena-partitions
  (list
   ;; == 256gb ssd
   boot           ;; /boot
   rootfs         ;; / (overriden temporarily to tmpfs)
   aetheria-store ;; /gnu/store
   aetheria-meta  ;; /var/guix
   nivea          ;; /mnt/nivea
   ;; == 1tb hdd
   persist-part   ;; /@persist
   nivea-home))   ;; /mnt/nivea/home

;; move to new module in (aetheria system) when repopulating comes
(define serena-persist
  (map (lambda (p) (persist-bind persist-part p))
       '("/etc/NetworkManager/system-connections" ;; TODO: figure out sops-guix
         ;; /root/* should be migrated to guix home's mounts when i get to it
         "/root/.cache/guix" ;; guix caches channel checkouts here
         "/root/.mozilla/icecat" ;; use root for icecat, im not breaking my user home
         "/tmp/emacs" ;; a hacky script to launch nivea's emacs for now
         "/projects")))

(define serena-file-systems
  (append
   serena-partitions
   serena-persist
   (list
    (persist-bind nivea "/nix/store")  ;; TODO: move to btrfs pool TODO: think
    ;; of how to make /@persist read-only while making the mounted versions
    ;; read/write
    ;; (remount-read-only (file-system-mount-point persist-part)
    ;;                    #:after serena-persist)
    )
   %base-file-systems))
