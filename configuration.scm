;; -*- mode: scheme; -*-


(use-modules (gnu)
             (gnu bootloader)
             (gnu bootloader grub)
             (nongnu packages linux)
             (nongnu system linux-initrd)
             (gnu services desktop)
             (gnu services xorg)
             (gnu packages wm)
             (gnu packages gnuzilla))

(define aetheria-accounts
  (list (user-account
         (name "aemogie")
         (group "users")
         (password (crypt "password" "$6$aetheria+seren"))
         (supplementary-groups '("wheel" "netdev" "audio" "video")))))

(define aetheria-services
  (modify-services %desktop-services
    (delete gdm-service-type)
    ;; TODO: figure out how to set system-wide channel in a non-annoying way
    (guix-service-type
     config =>
     (guix-configuration
      (inherit config)
      (substitute-urls (cons* "https://substitutes.nonguix.org"
                              %default-substitute-urls))
      (authorized-keys (cons* (local-file "substitutes/nonguix.pub")
                              %default-authorized-guix-keys))))))

;; TODO: move to module
(define (aetheria-file-systems)
  ;; TOOD: figure out how to change grub.cfg path, then migrate to serena-boot
  (define boot
    (file-system
      (device (file-system-label "BOOTTMP"))
      (mount-point "/boot")
      (type "vfat")))

  (define (serena-part subvol mount-point)
    (file-system
      (mount-point mount-point)
      (device (file-system-label "serena"))
      (type "btrfs")
      (flags '(no-atime))
      (options (format #f "subvol=~a,discard=async,ssd" subvol))))
  (define rootfs
    (file-system
      (inherit (serena-part "@" "/"))
      (needed-for-boot? #t)
      ;; TODO: figure out how to wipe+snapshot btrfs on boot
      ;; tmpfs till then
      (device "none")
      (type "tmpfs")
      (options #f)))
  (define aetheria-store
    (file-system
      (inherit (serena-part "@aetheria-store" "/gnu/store"))
      (needed-for-boot? #t)))
  (define aetheria-meta (serena-part "@aetheria-meta" "/var/guix"))

  (define nivea
    (file-system
      (mount-point "/mnt/nivea")
      (device (file-system-label "NIXOS"))
      (type "ext4")
      (flags '(read-only))))

  (define persist-part
    (file-system
      (mount-point "/@persist")
      (device (file-system-label "serena-persist"))
      (type "btrfs")
      (flags '(no-atime))))

  (define nivea-home ;; migrate to serena-persist btrfs pool
    (file-system
      (mount-point "/mnt/nivea/home")
      (device (file-system-label "NIXHOME"))
      (type "ext4")
      (dependencies (list nivea))))

  ;; TODO: rsync this to the serena btrfs pool, the only bind mounts should be from /@persist
  (define nivea-store
    (file-system
      (mount-point "/nix/store")
      (device "/mnt/nivea/nix/store")
      (type "none")
      (flags '(bind-mount no-atime read-only))
      (dependencies (list nivea))))

  ;; FIXME: this somehow stops `user-homes` from making the directory.
  ;; user-homes checks if `directory-exists?`, so this should only run after it does that
  (define (persist path)
    (file-system
      (mount-point path)
      (device (format #f "/@persist/~a" path))
      (type "none")
      (flags '(bind-mount no-atime))
      (dependencies (list persist-part))
      ;; FIXME: this doesnt work, still stops user home from being generated
      ;; user-homes activation checks if `directory-exists?`, that must mean
      ;; it was atleast created before that
      (shepherd-requirements '(user-homes))
      ;; would this fix it? but that's the default anyway. plus even if it
      ;; worked, won't it break stuff?
      (create-mount-point? #f)
      (mount-may-fail? #t)))

  (list
   ;; 256gb ssd
   boot           ;; /boot
   rootfs         ;; / (overriden temporarily to tmpfs)
   aetheria-store ;; /gnu/store
   aetheria-meta  ;; /var/guix
   nivea          ;; /mnt/nivea

   ;; 1tb hdd
   persist-part ;; /@persist
   nivea-home   ;; /mnt/nivea/home

   ;; bind-mounts (to be removed)
   nivea-store ;; /nix/store

   ;; persist
   (persist "/root/.cache/guix") ;; guix caches channel checkouts here
   ;; (persist "/home/aemogie/.cache/guix")

   (persist "/etc/NetworkManager/system-connections") ;; TODO: figure out sops-guix

   ;; persist icecat profile (for irc password)
   (persist "/root/.mozilla/icecat") ;; use sudo for icecat, im not breaking my user home

   (persist "/tmp/emacs") ;; a hacky script to launch nivea's emacs for now
   (persist "/projects")))

(operating-system
  (kernel linux)
  (initrd microcode-initrd)
  (initrd-modules
   (cons* "vmd" ;; intel vmd so it sees my disks
          %base-initrd-modules))
  (firmware (list linux-firmware))
  (host-name "serena")
  (timezone "Asia/Colombo")
  (locale "en_GB.utf8")

  (users (append aetheria-accounts %base-user-accounts))

  (packages ;; TODO: move to home config
   (cons* cage icecat ;; good enough to begin
          %base-packages))
  (services aetheria-services)

  (bootloader
   (bootloader-configuration
    (bootloader grub-efi-bootloader)
    (targets '("/boot"))))

  (file-systems (append (aetheria-file-systems) %base-file-systems)))
