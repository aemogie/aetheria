;; -*- mode: scheme; -*-


(use-modules (gnu)
	     (gnu bootloader)
	     (gnu bootloader grub)
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
                (supplementary-groups '("wheel" "audio" "video")))
               %base-user-accounts))

  ;; This will be ignored.
  (bootloader (bootloader-configuration
               (bootloader grub-bootloader)
               (targets '("does-not-matter"))))
  ;; This will be ignored, too.
  (file-systems (list (file-system
                        (device "does-not-matter")
                        (mount-point "/")
                        (type "does-not-matter")))))

