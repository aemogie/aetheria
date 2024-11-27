;; DO NOT MODIFY!
;; instead, make your changes to channels.scm, then run `make update-lockfile`
(use-modules
  ((guix channels)
   #:select
   (channel
     make-channel-introduction
     openpgp-fingerprint
     %default-guix-channel)))

(list (channel
        (name 'nonguix)
        (url "https://gitlab.com/nonguix/nonguix")
        (branch "master")
        (commit
          "8dbfc04639cf198bef92d6f7f90472564bdb5727")
        (introduction
          (make-channel-introduction
            "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
            (openpgp-fingerprint
              "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))
      (channel
        (name 'rosenthal)
        (url "https://codeberg.org/hako/rosenthal.git")
        (branch "trunk")
        (commit
          "d219e6e52062bea953116763dd1fa602942e2e24")
        (introduction
          (make-channel-introduction
            "7677db76330121a901604dfbad19077893865f35"
            (openpgp-fingerprint
              "13E7 6CD6 E649 C28C 3385  4DF5 5E5A A665 6149 17F7"))))
      (channel
        (name 'guix)
        (url "https://git.savannah.gnu.org/git/guix.git")
        (branch "master")
        (commit
          "e5140eebdfc04b90c046856d95b2ef50c12fee72")
        (introduction
          (make-channel-introduction
            "9edb3f66fd807b096b48283debdcddccfea34bad"
            (openpgp-fingerprint
              "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA")))))
