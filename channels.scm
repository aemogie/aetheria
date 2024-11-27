(use-modules ((guix channels)
              #:select (channel
                        make-channel-introduction
                        openpgp-fingerprint
                        %default-guix-channel)))

(list (channel
        (name 'nonguix)
        (url "https://gitlab.com/nonguix/nonguix")
        (branch "master")
        (introduction
         (make-channel-introduction
          "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
          (openpgp-fingerprint
           "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))
       (channel
	(name 'rosenthal)
	(url "https://codeberg.org/hako/rosenthal.git")
	(branch "trunk")
	(introduction
	 (make-channel-introduction
	  "7677db76330121a901604dfbad19077893865f35"
	  (openpgp-fingerprint
	   "13E7 6CD6 E649 C28C 3385  4DF5 5E5A A665 6149 17F7"))))
       (channel
	(inherit %default-guix-channel)
        ;; meson update breaks umockdev (umockdev <- upower <- ??? <- system config)
        (commit "cd26d76fedb7ab13ad91bd5dcfce119892b8e62e")))
