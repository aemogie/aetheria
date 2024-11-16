;; -*- mode: scheme; -*-


(use-modules (gnu)
	     (gnu bootloader)
	     (gnu bootloader grub)
	     (gnu services desktop)
	     (nongnu packages linux)
	     (nongnu system linux-initrd))

(operating-system
  (kernel linux)
  (initrd microcode-initrd)
  (firmware (list linux-firmware))
  (host-name "serena")
  (timezone "Asia/Colombo")
  (locale "en_GB.utf8")

  (users (cons (user-account
                (name "aemogie")
                (group "users")
		(password (crypt "password" "$6$aetheria"))
                (supplementary-groups '("wheel" "audio" "video")))
	       %base-user-accounts))

  (packages (cons* ;; TODO: add wm?
	     %base-packages))
  (services %desktop-services)

  (bootloader
   (bootloader-configuration
    (bootloader grub-efi-bootloader)
    (targets '("/boot"))))

  (file-systems ;; WIP
   (let ((boot-part (file-system-label "serena-boot"))
	 (root-part (file-system-label "serena"))
	 (pers-part (file-system-label "serena-persist")))
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
      %base-file-systems))))
