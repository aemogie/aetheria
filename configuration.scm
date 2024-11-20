;; -*- mode: scheme; -*-


(use-modules (gnu)
             (gnu bootloader)
             (gnu bootloader grub)
             (nongnu packages linux)
             (nongnu system linux-initrd)
             (gnu services desktop)
             (gnu services xorg)
             (gnu packages package-management)
             (gnu packages wm)
             (gnu packages gnuzilla))

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

  (users
   (cons* (user-account
           (name "aemogie")
           (group "users")
           (password (crypt "password" "$6$aetheria"))
           (supplementary-groups '("wheel" "netdev" "audio" "video")))
          %base-user-accounts))

  (packages;; TODO: move to home config
   (cons*
    cage icecat ;; good enough to begin
    gnu-make ;; for `make reconfigure`
    %base-packages))
  (services
   (modify-services %desktop-services
     (delete gdm-service-type)
     ;; dont think this is how it's supposed to be done, it recomputes the channel on each build
     ;; TODO: maybe look into inferiors? does that solve this?
     (guix-service-type
      config =>
      (let () ;; (channels (load "channels.lock.scm")))
        (guix-configuration
         (inherit config)
         ;; (channels channels)
         ;; (guix (guix-for-channels channels))
         (substitute-urls (cons* "https://substitutes.nonguix.org"
                                 %default-substitute-urls))
         (authorized-keys (cons* (local-file "substitutes/nonguix.pub")
                                 %default-authorized-guix-keys)))))))

  (bootloader
   (bootloader-configuration
    (bootloader grub-efi-bootloader)
    (targets '("/boot"))))

  (file-systems ;; WIP
   (let ((boot-part (file-system-label "BOOTTMP"))
         (root-part (file-system-label "serena"))
         (pers-part (file-system-label "serena-persist"))
         (nivea-home-part (file-system-label "NIXHOME"))
         (nivea-part (file-system-label "NIXOS")))
     (cons*
      (file-system
        (device boot-part)
        (mount-point "/boot")
        (type "vfat"))
      (file-system
        (mount-point "/")
        (needed-for-boot? #t)
        ;; (device root-part)
        ;; (type "btrfs")
        ;; (flags '(no-atime))
        ;; (options "subvol=@,discard=async,ssd")
        (device "none")
        (type "tmpfs")
        (check? #f))
      (file-system
        (mount-point "/gnu/store")
        (needed-for-boot? #t)
        (device root-part)
        (type "btrfs")
        (flags '(no-atime))
        (options "subvol=@aetheria-store,discard=async,ssd"))
      (file-system
        (mount-point "/var/guix")
        (needed-for-boot? #t)
        (device root-part)
        (type "btrfs")
        (flags '(no-atime))
        (options "subvol=@aetheria-meta,discard=async,ssd"))
      (file-system
        (mount-point "/persist")
        (device pers-part)
        (type "btrfs")
        (flags '(no-atime)))
      (file-system
        (mount-point "/mnt/nivea")
        (device nivea-part)
        (type "ext4")
        (flags '(read-only)))
      (file-system
        (mount-point "/nix/store")
        (device "/mnt/nivea/nix/store")
        (type "none")
        (flags '(bind-mount read-only)))
      (file-system
        (mount-point "/mnt/nivea/home")
        (device nivea-home-part)
        (type "ext4"))
      (file-system
        (mount-point "/tmp/config")
        (device "/mnt/nivea/home/aemogie/dev/aetheria")
        (type "none")
        (flags '(bind-mount)))
      (file-system
        (mount-point "/tmp/guix")
        (device "/mnt/nivea/home/aemogie/dev/vendor/guix")
        (type "none")
        (flags '(bind-mount read-only)))
      (file-system
        (mount-point "/persist/old")
        (device root-part)
        (type "btrfs")
        (flags '(no-atime))
        (options "subvol=@,discard=async,ssd"))
      ;; guix needs it's cache directories, so provide it until i figure out
      ;; granular opt-in
      ;; FIXME: this somehow stops `user-homes` from making the directory.
      ;; user-homes checks if `directory-exists?`, so this should only run after it does that
      (file-system
        (mount-point "/root/.cache/guix")
        (device "/persist/old/root/.cache/guix")
        (type "none")
        (flags '(bind-mount))
        ;; but this doesnt work? why?
        (shepherd-requirements '(user-homes)))
      ;; idk which of these guix needs, but having both fixes the cache issue
      (file-system
        (mount-point "/root/.config/guix")
        (device "/persist/old/root/.config/guix")
        (type "none")
        (flags '(bind-mount))
        (shepherd-requirements '(user-homes)))
      ;; just a lil script that runs emacs from github.com/aemogie/nivea
      ;; and i didnt know you can bind mount files until now
      (file-system
        (mount-point "/usr/bin/emacs")
        (device "/persist/old/home/aemogie/emacs")
        (type "none")
        (flags '(bind-mount))
        (shepherd-requirements '(user-homes)))
      %base-file-systems))))
