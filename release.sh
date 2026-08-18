#!/bin/bash

set -e

PUBLISH=0
FORCE_COPR=0
BUMP=""
SET_VERSION=""
SHOW_VERSIONS=0
_expect=""
for arg in "$@"; do
    # --set-version takes a value as the next argument.
    if [ -n "$_expect" ]; then
        case "$_expect" in
            set) SET_VERSION="$arg" ;;
        esac
        _expect=""
        continue
    fi
    case "$arg" in
        --set-version) _expect=set ; continue ;;
        --set-version=*) SET_VERSION="${arg#*=}" ; continue ;;
        --show-versions) SHOW_VERSIONS=1 ; continue ;;
    esac
    case "$arg" in
        --publish) PUBLISH=1 ;;
        --force-copr) FORCE_COPR=1 ;;
        --bump-patch) [ -n "$BUMP" ] && { echo "Only one --bump-* flag at a time." >&2; exit 1; }; BUMP=patch ;;
        --bump-minor) [ -n "$BUMP" ] && { echo "Only one --bump-* flag at a time." >&2; exit 1; }; BUMP=minor ;;
        --bump-major) [ -n "$BUMP" ] && { echo "Only one --bump-* flag at a time." >&2; exit 1; }; BUMP=major ;;
        --help|-h)
            cat <<'USAGE'
./release.sh [flags]

  (no flags)          print this and exit (a bare run does nothing)
  --publish           build the .7z, then publish: crates.io, Copr, GitHub release

  --bump-patch        0.1.0 -> 0.1.1   package version, all mirrors
  --bump-minor        0.1.1 -> 0.2.0
  --bump-major        0.9.4 -> 1.0.0

  --show-versions     print what every place currently says, and exit
  --set-version X.Y.Z      force every place to X.Y.Z (repairs drift)

  --force-copr        trigger a Copr rebuild even if this version was already sent

Version places: Cargo.toml (authoritative), Cargo.lock, vox-libs.spec,
flake.nix. Each library's own `Library <name> version` line is separate on
purpose: that is its interface version, matched by a consumer's `see`, and
it moves only when that library's surface changes.

A bump or set asks safeguarding questions, refuses on a dirty tree, verifies
every mirror agrees afterwards, and never commits -- you review and sign.

RELEASE_TITLE="vox-libs X.Y.Z - subtitle" gives the GitHub release a subtitle;
its notes always come from CHANGELOG.md's section for that version.
USAGE
            exit 0 ;;
    esac
done

# --- Version bump -------------------------------------------------------
# Runs before VERSION is read below, so the archive and every publish target
# downstream use the NEW number. Deliberately does not commit: the repo owner
# signs commits with a hardware key, so the bump is left staged-in-tree for
# them to review and sign.
bump_version() {
    local kind="$1" cur major minor patch new

    # A bump rewrites tracked files. Doing that on top of unrelated edits
    # produces a commit that mixes a version bump with whatever else was in
    # flight, which is exactly the commit you don't want to bisect later.
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        echo "Working tree is not clean. Commit or stash first -- a version bump" >&2
        echo "should be its own reviewable change, not mixed into other work." >&2
        exit 1
    fi

    cur=$(grep '^version' Cargo.toml | head -1 | sed 's/.*"\(.*\)".*/\1/')
    if ! [[ "$cur" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        echo "Cannot parse current version from Cargo.toml: '$cur'" >&2
        exit 1
    fi
    major="${BASH_REMATCH[1]}"; minor="${BASH_REMATCH[2]}"; patch="${BASH_REMATCH[3]}"

    # Lower components reset -- 0.3.7 --minor-> 0.4.0, 0.8.23 --major-> 1.0.0.
    case "$kind" in
        patch) new="$major.$minor.$((patch + 1))" ;;
        minor) new="$major.$((minor + 1)).0" ;;
        major) new="$((major + 1)).0.0" ;;
    esac

    echo "Version bump: $cur -> $new ($kind)"
    echo

    # Safeguards. `read` returns non-zero on EOF, so a non-interactive run with
    # nothing piped in aborts rather than hanging or silently assuming yes.
    local ans
    if ! read -r -p "Have README.md and each library's header comment been checked for stale sections? (y) If not, this script will terminate -- update the documentation before bumping. " ans; then
        echo >&2; echo "No answer (non-interactive?). Aborting without bumping." >&2; exit 1
    fi
    case "$ans" in [Yy]|[Yy][Ee][Ss]) ;; *) echo "Aborting. Update the documentation, then re-run." >&2; exit 1 ;; esac

    if ! read -r -p "Does CHANGELOG.md have a $new entry describing this release? (y) " ans; then
        echo >&2; echo "No answer (non-interactive?). Aborting without bumping." >&2; exit 1
    fi
    case "$ans" in [Yy]|[Yy][Ee][Ss]) ;; *) echo "Aborting. Add the CHANGELOG entry, then re-run." >&2; exit 1 ;; esac

    write_version_everywhere "$new"

    echo
    echo "Bumped to $new in:"
    git diff --name-only
    echo
    echo "Not committed -- review the diff, then commit and sign it yourself."
}

# Writes a version into every place that mirrors it, then proves they agree.
# Shared by --bump-* and --set-version so there is ONE list of mirrors: a
# second copy is how flake.nix ended up a release behind in the first place.
#
# The patterns match whatever value is currently there rather than a specific
# old one, so this works even when the mirrors have already drifted apart --
# which is exactly the case --set-version exists to repair.
#
write_version_everywhere() {
    local new="$1"
    sed -i "0,/^version = \".*\"/s//version = \"$new\"/" Cargo.toml
    [ -f vox-libs.spec ] && sed -i "0,/^Version:\( *\).*/s//Version:\1$new/" vox-libs.spec
    [ -f flake.nix ]   && sed -i "0,/version = \".*\"/s//version = \"$new\"/" flake.nix

    # Regenerate Cargo.lock's own record of this package's version.
    cargo check --quiet >/dev/null 2>&1 || true

    verify_version_consistency "$new"
}

# Prints what every mirror currently says. Used before an override so the
# drift is visible before it is overwritten, rather than silently flattened.
show_version_mirrors() {
    echo "Current version in each place:"
    printf '  %-24s %s\n' "Cargo.toml"  "$(grep -m1 '^version' Cargo.toml | sed 's/.*"\(.*\)".*/\1/')  <- authoritative"
    [ -f Cargo.lock ]  && printf '  %-24s %s\n' "Cargo.lock"  "$(grep -A1 'name = "vox-libs"' Cargo.lock | grep -m1 '^version' | sed 's/.*"\(.*\)".*/\1/')"
    [ -f vox-libs.spec ] && printf '  %-24s %s\n' "vox-libs.spec" "$(grep -m1 '^Version:' vox-libs.spec | awk '{print $2}')"
    [ -f flake.nix ]   && printf '  %-24s %s\n' "flake.nix"   "$(grep -m1 'version = "' flake.nix | sed 's/.*"\(.*\)".*/\1/')"
}

# Force every mirror to an explicit version. This is the repair tool for when
# they have drifted apart -- unlike --bump-*, it does not care what any of
# them currently say.
set_version() {
    local new="$1" ans cargo_cur
    if ! [[ "$new" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Not a semver version: '$new' (expected X.Y.Z)" >&2; exit 1
    fi
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        echo "Working tree is not clean. Commit or stash first." >&2; exit 1
    fi

    cargo_cur=$(grep -m1 '^version' Cargo.toml | sed 's/.*"\(.*\)".*/\1/')
    echo
    show_version_mirrors
    echo
    echo "Cargo.toml is the authoritative version and currently says $cargo_cur."
    if [ "$new" != "$cargo_cur" ]; then
        echo "You are overriding to $new, which DISAGREES with it -- that changes the"
        echo "release's identity, not just a stale mirror. Make sure that is intended."
    fi
    echo

    if ! read -r -p "Set every place above (except the VS Code extension) to $new? (y) " ans; then
        echo >&2; echo "No answer (non-interactive?). Aborting." >&2; exit 1
    fi
    case "$ans" in [Yy]|[Yy][Ee][Ss]) ;; *) echo "Aborting -- nothing changed." >&2; exit 1 ;; esac

    write_version_everywhere "$new"
    echo
    echo "Set to $new in:"
    git diff --name-only
    echo
    echo "Not committed -- review the diff, then commit and sign it yourself."
}

# A sed that silently matches nothing is the failure mode here: the bump
# "succeeds", one mirror keeps the old number, and it isn't noticed until a
# package built from that mirror ships the wrong version. Check rather than
# assume.
verify_version_consistency() {
    local want="$1" bad=0 got
    check() { # file, human name, extracted value
        if [ -n "$3" ] && [ "$3" != "$want" ]; then
            echo "  MISMATCH $1: expected $want, found $3" >&2; bad=1
        fi
    }
    check Cargo.toml  "" "$(grep -m1 '^version' Cargo.toml | sed 's/.*"\(.*\)".*/\1/')"
    [ -f vox-libs.spec ] && check vox-libs.spec "" "$(grep -m1 '^Version:' vox-libs.spec | awk '{print $2}')"
    [ -f flake.nix ]   && check flake.nix   "" "$(grep -m1 'version = "' flake.nix | sed 's/.*"\(.*\)".*/\1/')"
    [ -f Cargo.lock ]  && check Cargo.lock  "" "$(grep -A1 'name = "vox-libs"' Cargo.lock | grep -m1 '^version' | sed 's/.*"\(.*\)".*/\1/')"
    if [ "$bad" -ne 0 ]; then
        echo "Version mirrors disagree after the bump -- fix them before releasing." >&2
        exit 1
    fi
    echo "All version mirrors agree on $want."
}

if [ -n "$_expect" ]; then
    echo "--set-version needs a version, e.g. --set-version 0.3.7" >&2
    exit 1
fi
if [ "$SHOW_VERSIONS" -eq 1 ]; then
    show_version_mirrors
    exit 0
fi
if [ -n "$BUMP" ] && [ -n "$SET_VERSION" ]; then
    echo "--bump-* and --set-version do the same job differently; pick one." >&2
    exit 1
fi
if [ -n "$SET_VERSION" ]; then
    set_version "$SET_VERSION"
fi
if [ -n "$BUMP" ]; then
    bump_version "$BUMP"
fi

# Building, archiving, and publishing only happen with --publish. A bare
# --bump-*/--set-version/--show-versions run is version management only: it
# stops here, leaving the bump staged for review and signing, and never
# spends a minute on make/strip/7z that a bump does not need.
if [ "$PUBLISH" -eq 0 ]; then
    # No flags and nothing to do: say so rather than exiting silently.
    if [ -z "$BUMP" ] && [ -z "$SET_VERSION" ]; then
        echo "Nothing to do. See ./release.sh --help (a bare run neither builds nor publishes)."
    fi
    exit 0
fi

# Extract version from Cargo.toml
VERSION=$(grep '^version' Cargo.toml | head -1 | sed 's/.*"\(.*\)".*/\1/')

# Get OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Output directory -- under build/, so it's covered by the existing
# blanket `build` gitignore rule without needing a separate entry.
DIST_DIR="build/dist"
mkdir -p "$DIST_DIR"

# Create archive name
ARCHIVE_NAME="$DIST_DIR/vox-libs.${VERSION}.${OS}.${ARCH}.7z"

# Build every library through the Makefile. VOX comes from PATH (an
# installed compiler) unless the caller overrides it; make test proves each
# demo against the freshly built .so before anything is packaged.
echo "Building via make..."
make VOX="${VOX:-vox}"
make test VOX="${VOX:-vox}"

# Strip the shared objects so the shipped artifact matches an installed one.
for so in build/lib*.so; do
    if [ -f "$so" ] && file "$so" 2>/dev/null | grep -q 'not stripped'; then
        echo "Stripping $so for packaging..."
        strip "$so"
    fi
done
if ! ls build/lib*.so >/dev/null 2>&1; then
    echo "build/lib*.so missing after make -- aborting before packaging." >&2
    exit 1
fi

# Create the archive: the built .so/.lib pairs plus the sources they came
# from, so the archive is usable both ways.
7z a "$ARCHIVE_NAME" \
    build/lib*.so \
    build/lib*.lib \
    textkit/ \
    process/ \
    LICENSE \
    README.md \
    CHANGELOG.md \
    Makefile

echo "Created: $ARCHIVE_NAME"

# Each target below is independent, so one failing (e.g. "this version is
# already published" on a re-run) shouldn't block the others. Every step is
# wrapped in `if ! ...; then` -- bash's `set -e` doesn't trigger on a command
# tested by `if`, so this doesn't need `set +e` -- and failures are collected
# for a summary at the end instead of exiting immediately.
FAILED=()

# --- crates.io ---
echo "Publishing to crates.io..."
if ! cargo publish; then
    echo "FAILED: crates.io" >&2
    FAILED+=("crates.io")
fi

# --- Fedora Copr ---
# Copr's own build history is unreliable to query here -- build IDs queried
# successfully earlier in development later 404'd as "does not exist", so a
# remote "has this version already built" check can't be trusted. Track it
# locally instead: a marker file recording the last version this machine
# triggered a Copr build for. This only prevents accidental duplicate
# *submissions* (e.g. re-running this script without a real change), not
# "did every chroot succeed" -- pass --force-copr to trigger regardless.
COPR_MARKER="$DIST_DIR/.copr-last-version"
if ! command -v copr-cli >/dev/null 2>&1; then
    echo "copr-cli not found (sudo dnf install copr-cli). Skipping Copr rebuild." >&2
    FAILED+=("Copr (copr-cli missing)")
elif [ ! -f "$HOME/.config/copr" ]; then
    echo "No Copr API token at ~/.config/copr. Generate one at" >&2
    echo "https://copr.fedorainfracloud.org/api/ and save it there. Skipping Copr rebuild." >&2
    FAILED+=("Copr (no token)")
elif [ "$FORCE_COPR" -eq 0 ] && [ -f "$COPR_MARKER" ] && [ "$(cat "$COPR_MARKER")" = "$VERSION" ]; then
    echo "Copr: $VERSION already triggered from this machine, skipping (pass --force-copr to rebuild anyway)."
else
    echo "Triggering Copr rebuild..."
    if ! copr-cli build-package vox-lang/Vox --name vox-libs --nowait; then
        echo "FAILED: Copr rebuild" >&2
        FAILED+=("Copr")
    else
        echo "$VERSION" > "$COPR_MARKER"
    fi
fi

# --- GitHub release ---
# Notes come straight from CHANGELOG.md's section for this version, so the
# release page and the changelog cannot drift apart. Runs last: if anything
# above failed you probably don't want a release announcing the version.
TAG="v$VERSION"
if ! command -v gh >/dev/null 2>&1; then
    echo "gh not found (https://cli.github.com). Skipping GitHub release." >&2
    FAILED+=("GitHub release (gh missing)")
elif gh release view "$TAG" >/dev/null 2>&1; then
    echo "GitHub release $TAG already exists, skipping."
else
    # A release tags a commit. Tagging one that was never pushed produces a
    # release nobody else can check out, so refuse rather than publish a
    # dangling reference.
    HEAD_SHA=$(git rev-parse HEAD)
    if ! git branch -r --contains "$HEAD_SHA" 2>/dev/null | grep -q .; then
        echo "HEAD ($HEAD_SHA) is not on any remote branch -- push before releasing." >&2
        FAILED+=("GitHub release (HEAD not pushed)")
    else
        NOTES=$(awk -v v="$VERSION" '
            $0 ~ "^## \\[" v "\\]" { inside=1; next }
            inside && /^## \[/ { exit }
            inside { print }
        ' CHANGELOG.md | sed '/./,$!d')

        if [ -z "$NOTES" ]; then
            echo "No '## [$VERSION]' section in CHANGELOG.md -- add one before releasing." >&2
            FAILED+=("GitHub release (no CHANGELOG section)")
        else
            # The subtitle is editorial and isn't in the changelog, so take it
            # from RELEASE_TITLE if set, else fall back to the bare version.
            TITLE="${RELEASE_TITLE:-vox-libs $VERSION}"
            echo "Creating GitHub release $TAG..."
            if ! gh release create "$TAG" \
                    --target "$HEAD_SHA" \
                    --title "$TITLE" \
                    --notes "$NOTES" \
                    "$ARCHIVE_NAME"; then
                echo "FAILED: GitHub release" >&2
                FAILED+=("GitHub release")
            fi
        fi
    fi
fi

echo
if [ "${#FAILED[@]}" -eq 0 ]; then
    echo "All publish targets succeeded."
else
    printf -v joined '%s, ' "${FAILED[@]}"
    echo "Failed: ${joined%, }" >&2
    exit 1
fi
