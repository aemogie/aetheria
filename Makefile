GUIX := guix time-machine -C channels.lock.scm --

.PHONY: geiser-repl update-lockfile build-container run-container

update-lockfile: tmplock := $(shell mktemp)
update-lockfile:
	guix time-machine -C channels.scm -- describe -f channels > "$(tmplock)" && \
	  cat "$(tmplock)" > channels.lock.scm
	rm -f "$(tmplock)"

geiser-repl:
	$(GUIX) repl --listen=tcp:37146

build-container: configuration.scm channels.lock.scm
ifneq ("$(wildcard ./result/run-container)","")
	rm ./result/run-container
endif
	mkdir -p result
	$(GUIX) system container configuration.scm -r"result/run-container"

# yes, build-container produces this, but make doesnt know that. its just a PHONY target
# the names are just a coincidence, plus im trying to learn make
run-container:
	sudo ./result/run-container --share="$(shell pwd)=/config"

build-system: configuration.scm channels.lock.scm
	$(GUIX) system build configuration.scm -r"result/system"

build-vm:
	$(GUIX) system vm --full-boot -r"result/run-vm" configuration.scm
