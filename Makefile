SHELL := /bin/sh

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

# Where the .so will live once installed, as the running system will see it:
# LIBDIR with any staging prefix stripped off. Recorded into each .lib (see
# the install target). Derived rather than hardcoded so that overriding LIBDIR
# -- as the Nix build does, to $out/lib -- keeps the recorded path truthful.
RECORDED_LIBDIR := $(patsubst $(DESTDIR)%,%,$(LIBDIR))

VOX ?= vox
# The compiler must be told where its own coreasm lives, or an installed copy
# silently shadows a development one and you build against the wrong runtime.
VOX_CORE_PATH ?=
ifneq ($(VOX_CORE_PATH),)
export VOX_CORE_PATH
endif

LIBS  := textkit process json
BUILD := build

.PHONY: all build install uninstall test clean $(LIBS)

all: build

build: $(LIBS)

# Each library builds from <name>/<name>.vox into build/lib<name>.so, with the
# compiler emitting build/lib<name>.lib beside it as the interface.
$(LIBS):
	@mkdir -p $(BUILD)
	$(VOX) $@/$@.vox --shared -o $(BUILD)/lib$@.so

# A .lib records where its .so was when the compiler emitted it, as a path
# relative to the .lib itself ("./libfoo.so"). Installing splits the pair --
# interface into $(INCDIR), implementation into $(LIBDIR) -- so that relative
# path stops resolving and the installed library is unusable without a manual
# --lib-path. Rewrite Location to the absolute installed path as we copy, the
# way a .pc file gets its prefix substituted at install time. PREFIX-relative,
# and DESTDIR is deliberately excluded from the recorded path: staging is a
# build-time detail, not where the file will live.
install: build
	install -d "$(INCDIR)" "$(LIBDIR)"
	for lib in $(LIBS); do \
	    sed 's|^Location ".*"\.$$|Location "$(RECORDED_LIBDIR)/lib'"$$lib"'.so".|' \
	        "$(BUILD)/lib$$lib.lib" > "$(BUILD)/$$lib.lib.installed"; \
	    install -m 0644 "$(BUILD)/$$lib.lib.installed" "$(INCDIR)/$$lib.lib"; \
	    install -m 0755 "$(BUILD)/lib$$lib.so"  "$(LIBDIR)/lib$$lib.so"; \
	done

uninstall:
	for lib in $(LIBS); do \
	    rm -f "$(INCDIR)/$$lib.lib" "$(LIBDIR)/lib$$lib.so"; \
	done
	-rmdir "$(INCDIR)" 2>/dev/null || true

# Each library's own demo is its test: compile it against the built library and
# diff against the recorded expected output.
#
# A library may also ship <name>/<name>_tests.vox: a program of named
# assertions that prints nothing but its headings and a tally, and exits
# non-zero when a claim does not hold. It is checked twice over -- its exit
# status has to be 0, and its transcript has to match <name>_tests.expected --
# so a library gates itself here rather than only being demonstrated.
test: build
	@fail=0; \
	for lib in $(LIBS); do \
	    demo="$$lib/$${lib}_demo.vox"; \
	    if [ -f "$$demo" ]; then \
	        if $(VOX) "$$demo" --link "$$lib" --lib-path $(BUILD) -o $(BUILD)/$${lib}_demo; then \
	            LD_LIBRARY_PATH=$(BUILD) $(BUILD)/$${lib}_demo > $(BUILD)/$${lib}_demo.out 2>&1 || true; \
	            if diff -q "$$lib/$${lib}_demo.expected" $(BUILD)/$${lib}_demo.out >/dev/null 2>&1; then \
	                echo "PASS $$lib demo"; \
	            else \
	                echo "FAIL $$lib demo"; diff -u "$$lib/$${lib}_demo.expected" $(BUILD)/$${lib}_demo.out || true; fail=1; \
	            fi; \
	        else fail=1; fi; \
	    fi; \
	    tests="$$lib/$${lib}_tests.vox"; \
	    [ -f "$$tests" ] || continue; \
	    $(VOX) "$$tests" --link "$$lib" --lib-path $(BUILD) -o $(BUILD)/$${lib}_tests || { fail=1; continue; }; \
	    if LD_LIBRARY_PATH=$(BUILD) $(BUILD)/$${lib}_tests > $(BUILD)/$${lib}_tests.out 2>&1; then \
	        if diff -q "$$lib/$${lib}_tests.expected" $(BUILD)/$${lib}_tests.out >/dev/null 2>&1; then \
	            echo "PASS $$lib tests"; \
	        else \
	            echo "FAIL $$lib tests"; diff -u "$$lib/$${lib}_tests.expected" $(BUILD)/$${lib}_tests.out || true; fail=1; \
	        fi; \
	    else \
	        echo "FAIL $$lib tests"; cat $(BUILD)/$${lib}_tests.out; fail=1; \
	    fi; \
	done; \
	exit $$fail

clean:
	rm -rf $(BUILD)
