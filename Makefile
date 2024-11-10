GUIX := guix time-machine -C channels.lock.scm --
VERBOSITY = 3

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
	$(GUIX) system container -v $(VERBOSITY) configuration.scm -r"result/run-container"

# yes, build-container produces this, but make doesnt know that. its just a PHONY target
# the names are just a coincidence, plus im trying to learn make
run-container: build-container
	sudo ./result/run-container --share="$(shell pwd)=/config"

build-system: configuration.scm channels.lock.scm
ifneq ("$(wildcard ./result/system)","")
	rm ./result/system
endif
	$(GUIX) system build -v $(VERBOSITY) configuration.scm -r"result/system"

build-vm:
ifneq ("$(wildcard ./result/run-vm)","")
	rm ./result/run-vm
endif
	$(GUIX) system vm -v $(VERBOSITY) --full-boot -r"result/run-vm" configuration.scm
