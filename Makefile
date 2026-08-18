SHELL := /bin/bash

# Install layout follows the C model, because a Vox library is shaped like a C
# one: an interface you compile against and an implementation you link against.
#   .lib -> $(INCDIR)   alongside the system headers, like <sys/wait.h>
#   .so  -> $(LIBDIR)   alongside every other shared object, so ldconfig sees it
#
# PREFIX/DESTDIR are honoured so distro packaging (Copr/rpm), Nix, and a plain
# `make install` all drive the same rules rather than each inventing a layout.
PREFIX  ?= /usr
DESTDIR ?=
INCDIR  := $(DESTDIR)$(PREFIX)/include/vox
LIBDIR  := $(DESTDIR)$(PREFIX)/lib64

VOX ?= vox
# The compiler must be told where its own coreasm lives, or an installed copy
# silently shadows a development one and you build against the wrong runtime.
VOX_CORE_PATH ?=
ifneq ($(VOX_CORE_PATH),)
export VOX_CORE_PATH
endif

LIBS  := textkit process
BUILD := build

.PHONY: all build install uninstall test clean $(LIBS)

all: build

build: $(LIBS)

# Each library builds from <name>/<name>.vox into build/lib<name>.so, with the
# compiler emitting build/lib<name>.lib beside it as the interface.
$(LIBS):
	@mkdir -p $(BUILD)
	$(VOX) $@/$@.vox --shared -o $(BUILD)/lib$@.so

install: build
	install -d "$(INCDIR)" "$(LIBDIR)"
	for lib in $(LIBS); do \
	    install -m 0644 "$(BUILD)/lib$$lib.lib" "$(INCDIR)/$$lib.lib"; \
	    install -m 0755 "$(BUILD)/lib$$lib.so"  "$(LIBDIR)/lib$$lib.so"; \
	done

uninstall:
	for lib in $(LIBS); do \
	    rm -f "$(INCDIR)/$$lib.lib" "$(LIBDIR)/lib$$lib.so"; \
	done
	-rmdir "$(INCDIR)" 2>/dev/null || true

# Each library's own demo is its test: compile it against the built library and
# diff against the recorded expected output.
test: build
	@fail=0; \
	for lib in $(LIBS); do \
	    demo="$$lib/$${lib}_demo.vox"; \
	    [ -f "$$demo" ] || continue; \
	    $(VOX) "$$demo" --link "$$lib" --lib-path $(BUILD) -o $(BUILD)/$${lib}_demo || { fail=1; continue; }; \
	    LD_LIBRARY_PATH=$(BUILD) $(BUILD)/$${lib}_demo > $(BUILD)/$${lib}_demo.out 2>&1 || true; \
	    if diff -q "$$lib/$${lib}_demo.expected" $(BUILD)/$${lib}_demo.out >/dev/null 2>&1; then \
	        echo "PASS $$lib"; \
	    else \
	        echo "FAIL $$lib"; diff -u "$$lib/$${lib}_demo.expected" $(BUILD)/$${lib}_demo.out || true; fail=1; \
	    fi; \
	done; \
	exit $$fail

clean:
	rm -rf $(BUILD)
