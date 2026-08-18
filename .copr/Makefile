# Copr "SCM" build method entry point (build source type "make srpm").
# Copr clones the repo into a mock chroot and runs, as root, with network:
#   make -f .copr/Makefile srpm outdir="<outdir>" spec="<spec_path>"
# Much simpler than the vox compiler's version of this file: the libraries
# are pure Vox source with no crates.io dependencies, so there is nothing
# to vendor — archive HEAD, build the SRPM, done. The mock build of that
# SRPM then compiles the libraries with the vox package from this same
# Copr project's buildroot.

outdir ?= $(CURDIR)/outdir
builddir := $(shell mktemp -d)

.PHONY: srpm
srpm:
	dnf -y install --setopt=install_weak_deps=False rpm-build git

	mkdir -p "$(outdir)" "$(builddir)/SOURCES" "$(builddir)/SPECS"

	$(eval VERSION := $(shell sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -1))

	git archive --prefix=vox-libs-$(VERSION)/ -o "$(builddir)/SOURCES/vox-libs-$(VERSION).tar.gz" HEAD

	cp vox-libs.spec "$(builddir)/SPECS/"

	rpmbuild -bs \
		--define "_topdir $(builddir)" \
		"$(builddir)/SPECS/vox-libs.spec"

	cp "$(builddir)"/SRPMS/*.src.rpm "$(outdir)/"
	rm -rf "$(builddir)"
