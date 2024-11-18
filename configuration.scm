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
             (gnu packages gnuzilla)
	     (gnu packages emacs)
             (gnu packages emacs-xyz)
	     (gnu packages fonts))

(operating-system
  (kernel linux)
  (initrd microcode-initrd)
  (initrd-modules (cons*
		   "vmd" ;; intel vmd so it sees my disks
		   %base-initrd-modules))
  (firmware (list linux-firmware))
  (host-name "serena")
  (timezone "Asia/Colombo")
  (locale "en_GB.utf8")

  (users (cons (user-account
                (name "aemogie")
                (group "users")
		(password (crypt "password" "$6$aetheria"))
                (supplementary-groups '("wheel" "netdev" "audio" "video")))
	       %base-user-accounts))

  (packages (cons* ;; TODO: add wm?
             font-iosevka-comfy
             cage icecat ;; good enough
	     emacs-next-pgtk-xwidgets
             gnu-make ;; for `make reconfigure`
	     %base-packages))
  (services (modify-services %desktop-services
	      (delete gdm-service-type)
	      ;; dont think this is how it's supposed to be done, it recomputes the channel on each build
	      ;; TODO: maybe look into inferiors? does that solve this?
	      (guix-service-type
	       config =>
	       (let ((channels (load "channels.lock.scm")))
		 (guix-configuration
		  (inherit config)
		  (channels channels)
		  (guix (guix-for-channels channels))
		  (substitute-urls (cons* "https://substitutes.nonguix.org"
					  %default-substitute-urls))
		  (authorized-keys (cons* (local-file "substitutes/nonguix.pub")
					  %default-authorized-guix-keys)))))))

  (bootloader
   (bootloader-configuration
    (bootloader grub-efi-bootloader)
    (targets '("/boot"))))

  (file-systems ;; WIP
   (let ((boot-part (file-system-label "serena-boot"))
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
	(device root-part)
	(type "btrfs")
	(flags '(no-atime))
	(options "subvol=@,discard=async,ssd"))
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
        (mount-point "/mnt/nivea/home")
        (device nivea-home-part)
        (type "ext4")
	(flags '(read-only)))
      (file-system
       (mount-point "/nix/store")
       (device "/mnt/nivea/nix/store")
       (type "none")
       (flags '(bind-mount read-only)))
      %base-file-systems))))
