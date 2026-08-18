Name:           vox-libs
Version:        0.1.0
Release:        1%{?dist}
Summary:        Shared libraries for the Vox programming language

License:        GPL-3.0-or-later
URL:            https://github.com/Vox-lang/vox-libs
Source0:        %{url}/archive/v%{version}/vox-libs-%{version}.tar.gz

# The libraries are compiled BY vox, so the compiler is a build dependency
# here — the inverse of the vox package, where nasm/binutils are runtime
# Requires because vox only shells out to them for a user's program. vox is
# published in this same Copr project, so it is present in the buildroot.
BuildRequires:  make
BuildRequires:  vox
BuildRequires:  nasm
BuildRequires:  binutils

# A consumer links the installed .so at build time and loads it at run time;
# nothing here needs vox after the build.

# The .so files are Vox-emitted assembly with no debug sections that
# find-debuginfo can attribute; skip debuginfo generation entirely, as the
# vox package does and for the same reason.
%global debug_package %{nil}

%description
Shared libraries written in Vox, for Vox programs to see: textkit (text
utilities) and process (wait-status decoding). Interfaces install to
%{_includedir}/vox as .lib files alongside the system headers; shared
objects install to %{_libdir} where ldconfig indexes them.

Vox itself has no standard library, deliberately: the compiler never
assumes these are installed. They are ordinary libraries you choose.

%prep
%autosetup -n vox-libs-%{version}

%build
make VOX=vox

%check
make test VOX=vox

%install
# LIBDIR/INCDIR passed explicitly so multilib chroots (i386: %%{_libdir} =
# /usr/lib) land files where %%files expects them, not a hardcoded lib64.
make install VOX=vox DESTDIR=%{buildroot} PREFIX=/usr \
     LIBDIR=%{buildroot}%{_libdir} INCDIR=%{buildroot}%{_includedir}/vox

%files
%license LICENSE
%doc README.md
%{_includedir}/vox/
%{_libdir}/lib*.so

%changelog
* Tue Aug 18 2026 TheJostler <josj@tegosec.com> - 0.1.0-1
- Initial packaging: textkit and process
