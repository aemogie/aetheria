verbosity ?= 3

guix := guix time-machine -C channels.lock.scm --
sources := $(wildcard aetheria/**/*.scm)
guix_system_options := -v $(verbosity) -L. -e "((@ (aetheria) config-for-os))"

.PHONY: geiser-repl update-lockfile build-system run-container run-vm clean

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


build/system: $(sources) channels.lock.scm --build-dirs
	$(guix) system build $(guix_system_options) -r"build/tmp/system" || exit 1
	rm -f build/system
	mv build/tmp/system build/system
build-system: build/system

build/run-container: $(sources) channels.lock.scm --build-dirs
	$(guix) system container $(guix_system_options) -r"build/tmp/run-container" || exit 1
	rm -f build/run-container
	mv build/tmp/run-container build/run-container

run-container: build/run-container
	sudo build/run-container --share="$(shell pwd)=/config"

build/run-vm: $(sources) channels.lock.scm --build-dirs
	$(guix) system vm $(guix_system_options) --full-boot -r"build/tmp/run-vm" || exit 1
	rm -f build/run-vm
	mv build/tmp/run-vm build/run-vm

run-vm: build/run-vm
	build/run-vm

reconfigure: $(sources) channels.lock.scm
	sudo $(guix) system reconfigure $(guix_system_options)

clean_link = @[[ -h $(1) ]] && rm $(1) || echo "clean: skipping $(1)"
clean_dir = @[[ -d $(1) ]] && rmdir $(1) || echo "clean: skipping $(1)"

clean:
	$(call clean_link,build/tmp/run-vm)
	$(call clean_link,build/tmp/system)
	$(call clean_link,build/tmp/channels)
	$(call clean_link,build/tmp/run-container)
	$(call clean_dir,build/tmp/)

	$(call clean_link,build/run-vm)
	$(call clean_link,build/system)
	$(call clean_link,build/channels)
	$(call clean_link,build/run-container)
	$(call clean_dir,build/)
