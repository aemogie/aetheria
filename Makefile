guix := guix time-machine -C channels.lock.scm --

VERBOSITY ?= 3

.PHONY: geiser-repl update-lockfile build-system run-container run-vm foreign-host-rebuild

geiser-repl:
	$(guix) repl --listen=tcp:37146

--build-dirs:
	@mkdir -p build/tmp

build/tmp/channels.lock.scm: --build-dirs
	echo "(use-modules (guix channels))" > build/tmp/channels.lock.scm
	guix time-machine -C channels.scm -- describe -f channels >> build/tmp/channels.lock.scm || exit 1
# doesnt depend on channels.scm as you might need to update lockfile without updating channels
update-lockfile: build/tmp/channels.lock.scm
	rm channels.lock.scm
	mv build/tmp/channels.lock.scm channels.lock.scm


build/system: configuration.scm channels.lock.scm --build-dirs
	$(guix) system build -v $(VERBOSITY) configuration.scm -r"build/tmp/system" || exit 1
	rm build/system
	mv build/tmp/system build/system
build-system: build/system


build/run-container: configuration.scm channels.lock.scm --build-dirs
	$(guix) system container -v $(VERBOSITY) configuration.scm -r"build/tmp/run-container" || exit 1
	rm build/run-container
	mv build/tmp/run-container build/run-container

run-container: build/run-container
	sudo build/run-container --share="$(shell pwd)=/config"

build/run-vm: configuration.scm channels.lock.scm --build-dirs
	$(guix) system vm -v $(VERBOSITY) --full-boot -r"build/tmp/run-vm" configuration.scm || exit 1
	rm build/run-vm
	mv build/tmp/run-vm build/run-vm

run-vm: build/run-vm
	build/run-vm

build/fs: configuration.scm channels.lock.scm --build-dirs
	mkdir -p build/fs
# todo: load these definitions from configuration.scm through gnu make's guile support
	sudo mount -L serena -o no-atime,discard=async,ssd,subvol=@ -m build/fs/
	sudo mount -L serena -o no-atime,discard=async,ssd,subvol=@aetheria-store -m build/fs/gnu/store
	sudo mount -L serena -o no-atime,discard=async,ssd,subvol=@aetheria-meta -m build/fs/var/guix
	sudo mount -L BOOTTMP -m build/fs/boot
	sudo $(guix) system init -v $(VERBOSITY) configuration.scm build/fs
	sudo umount build/fs/boot
	sudo umount build/fs/var/guix
	sudo umount build/fs/gnu/store
	sudo umount build/fs/
foreign-host-rebuild: build/fs
	sudo rm -r build/fs

reconfigure: configuration.scm channels.lock.scm
	sudo $(guix) system reconfigure -v $(VERBOSITY) configuration.scm

clean:
	rm build/tmp/run-vm
	rm build/tmp/system
	rm build/tmp/channels
	rm build/tmp/run-container
