(define-module (aetheria hosts mirae file-systems)
  #:use-module ((gnu system file-systems) #:select (file-system-label
                                                    file-system
                                                    file-system-mount-point
                                                    %base-file-systems))
  #:use-module ((gnu services linux) #:select (vfs-mapping-service-type vfs-mapping))
  #:use-module ((gnu services) #:select (simple-service))
  #:use-module ((aetheria system file-systems) #:select (btrfs-file-system
                                                         persist-bind))
  #:export (mirae-file-systems
            mirae-persist))

(define (mirae-part subvol mount-point)
 (btrfs-file-system
  #:mount-point mount-point
  #:device (file-system-label "mirae-main")
  #:ssd? #t
  #:subvolume subvol))

;; figure out a place to put encrypted secrets
;; create way to create the source directory, other than manually doing it
(define persist-part
  (mirae-part "@persist" "/@persist"))


(define mirae-partitions
  (list
    (file-system
      (device (file-system-label "mirae-boot"))
      (mount-point "/boot")
      (type "vfat")
      (mount-may-fail? #t))
    (file-system
      (inherit (mirae-part "@aetheria-root" "/"))
      (mount-may-fail? #f)
      (needed-for-boot? #t))
    (file-system
      (inherit (mirae-part "@aetheria-store" "/gnu/store"))
      (mount-may-fail? #f)
      (needed-for-boot? #t))
     (mirae-part "@aetheria-meta" "/var/guix")
     persist-part))

(define (make-persist-service path user)
  (vfs-mapping
   (source (string-append (file-system-mount-point persist-part) path))
   (destination path)
   (user user)
   (name (string-append "persist-" path))))

;; TODO: move to (aetheria system persist) or (aetheria services persist)
;; when repopulating comes depending on how i implement it
(define mirae-persist
  (simple-service
   'mirae-persist
   vfs-mapping-service-type
   (list
    ;; TODO: these arent unique to mirae
    ;; TODO: figure out sops-guix
    (make-persist-service "/etc/NetworkManager/system-connections/" "root")
    ;; dont think this is dangerous info tho, maybe generate?
    (make-persist-service "/var/lib/bluetooth/" "root")
    ;; should be migrated to guix home's mounts when i get to it

    ;; guix caches channel checkouts here
    (make-persist-service "/root/.cache/guix/" "root")
    (make-persist-service "/home/aemogie/.cache/guix/" "aemogie")
    (make-persist-service "/home/aemogie/.config/guix/" "aemogie")

    ;; syncthing backed
    (make-persist-service "/home/aemogie/sync" "aemogie")
    (make-persist-service "/home/aemogie/.password-store" "aemogie")
    (make-persist-service "/home/aemogie/Music" "aemogie")

    ;; stateful
    (make-persist-service "/home/aemogie/.local/share/direnv/" "aemogie")
    (make-persist-service "/home/aemogie/.gnupg/" "aemogie")
    (make-persist-service "/home/aemogie/.librewolf/" "aemogie")
    (make-persist-service "/home/aemogie/dev/" "aemogie"))))

(define mirae-file-systems
  (append
   mirae-partitions
   %base-file-systems))
