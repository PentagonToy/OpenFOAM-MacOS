#!/bin/bash
set -eo pipefail

work=${1:?Usage: build.sh <mounted case-sensitive workspace> [jobs]}
jobs=${2:-5}
repo=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$work"
work=$PWD

[[ $(uname -m) == arm64 && $(uname -s) == Darwin ]] || {
    echo "An Apple Silicon Mac is required." >&2
    exit 1
}

for tool in cmake gmake xcrun; do
    command -v "$tool" >/dev/null || {
        echo "Missing build tool: $tool" >&2
        exit 1
    }
done

probe=$(mktemp -d "$work/.case-check.XXXXXX")
touch "$probe/lower"
if [[ -e "$probe/LOWER" ]]; then
    rm "$probe/lower"
    rmdir "$probe"
    echo "Use a case-sensitive build volume." >&2
    exit 1
fi
rm "$probe/lower"
rmdir "$probe"

prepare_source() {
    local name=$1 revision=$2
    local patch="$repo/patches/$name-${revision:0:10}.patch"
    if [[ ! -e "$name" ]]; then
        git init -q "$name"
    fi
    if ! git -C "$name" rev-parse --verify HEAD >/dev/null 2>&1; then
        git -C "$name" fetch --depth=1 "https://github.com/OpenFOAM/$name.git" "$revision"
        git -C "$name" checkout --detach FETCH_HEAD
    fi

    [[ $(git -C "$name" rev-parse HEAD) == "$revision" ]] || {
        echo "Unexpected upstream revision in $name." >&2
        return 1
    }

    if ! git -C "$name" apply --cached --reverse --check "$patch" 2>/dev/null; then
        git -C "$name" apply --index --whitespace=nowarn "$patch"
    fi
}

runtime_patch="$repo/patches/macos-runtime-library-search.patch"
if [[ ${OPENFOAM_OFFLINE:-0} == 1 ]]; then
    [[ -f OpenFOAM-14/etc/bashrc && -x ThirdParty-14/Allwmake ]] || {
        echo "Extract the release source archive onto the build volume first." >&2
        exit 1
    }
else
    prepare_source OpenFOAM-14 0dc18906914a67b73ab53dc33ca9b0c619601dfb
    prepare_source ThirdParty-14 6f75cb6aa1a3d8f1ba768840f9ee535244b4c70a
    if ! git -C OpenFOAM-14 apply --reverse --check "$runtime_patch" 2>/dev/null; then
        git -C OpenFOAM-14 apply "$runtime_patch"
    fi
fi

export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-15.0}
export CMAKE_POLICY_VERSION_MINIMUM=3.5
export HOME="$work/.build-home"
mkdir -p "$HOME"
"$repo/scripts/build-mpi.sh" "$work" "$jobs"
export PATH="$work/mpi/bin:$PATH"

# The upstream setup uses conditionals whose failures do not indicate an error.
if ! source "$work/OpenFOAM-14/etc/bashrc" PARMETIS_TYPE=none; then
    echo "Could not initialise the Foundation 14 build environment." >&2
    exit 1
fi
[[ $WM_PROJECT_VERSION == 14 && $WM_MPLIB == SYSTEMOPENMPI && -n $FOAM_EXT_LIBBIN ]]

# The package replaces bare dylib names with paths on the runtime volume.
export WM_LDFLAGS="${WM_LDFLAGS:+$WM_LDFLAGS }-Wl,-headerpad_max_install_names"
for rule in "$WM_DIR/rules/darwin64Clang/"{c,c++}; do
    if ! grep -Eq '^LINKLIBSO.*WM_LDFLAGS' "$rule"; then
        sed -E -i '' '/^LINK(LIBSO|EXE)[[:space:]]*=/s/$/ $(WM_LDFLAGS)/' "$rule"
    fi
done
scotch_rules="$WM_THIRD_PARTY_DIR/etc/wmakeFiles/scotch/Makefile.inc.i686_mac_darwin.shlib-OpenFOAM"
if ! grep -Eq '^ARFLAGS.*WM_LDFLAGS' "$scotch_rules"; then
    sed -i '' '/^ARFLAGS.*-dynamiclib/s/-dynamiclib/$(WM_LDFLAGS) -dynamiclib/' "$scotch_rules"
fi

ThirdParty-14/Allwmake -j "$jobs"
for library in scotch metis; do
    [[ -r "$FOAM_EXT_LIBBIN/lib$library.dylib" ]] || {
        echo "ThirdParty build did not produce lib$library.dylib." >&2
        exit 1
    }
done
OpenFOAM-14/Allwmake -j "$jobs" -s
[[ -x "$FOAM_APPBIN/foamRun" && -x "$FOAM_APPBIN/blockMesh" ]]
