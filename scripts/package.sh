#!/bin/bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd -P)
work=$(cd "${1:?Usage: package.sh <build volume> <output directory> <version>}" && pwd -P)
output=$(cd "${2:?Output directory must exist}" && pwd -P)
version=${3:?Provide an app version, for example 0.1.0}
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
options=darwin64ClangDPInt32Opt
platform="OpenFOAM-14/platforms/$options"
third_platform=ThirdParty-14/platforms/darwin64ClangDPInt32
app="$output/OpenFOAM-14.app"
sign_identity=${OPENFOAM_DEVELOPER_ID:--}
code_sign=(--force --sign "$sign_identity")
if [[ $sign_identity != - ]]; then
    code_sign+=(--timestamp --options runtime)
fi
[[ -x "$work/$platform/bin/foamRun" && -x "$work/$platform/bin/blockMesh" ]]
[[ -x "$work/mpi/bin/mpirun" ]]
[[ ! -e "$app" ]]

stage=$(mktemp -d "$work/.package.XXXXXX")
staged_output=
trap 'rm -rf "$stage"; if [[ -n "$staged_output" ]]; then rm -rf "$staged_output"; fi' EXIT
runtime="$stage/runtime"
mkdir -p "$runtime/OpenFOAM-14" "$runtime/ThirdParty-14"
rsync -a --exclude=.git --exclude=/platforms/ \
    "$work/OpenFOAM-14/" "$runtime/OpenFOAM-14/"
mkdir -p "$runtime/$platform"
rsync -a --exclude='libparMetisDecomp.dylib' \
    "$work/$platform/bin" "$work/$platform/lib" "$runtime/$platform/"
rsync -a "$work/ThirdParty-14/etc" "$work/ThirdParty-14/COPYING" "$runtime/ThirdParty-14/"
mkdir -p "$runtime/$third_platform"
rsync -a --exclude=/parmetis-4.0.3/ --exclude='libparmetis.dylib' --exclude=/metis-5.1.0/bin/ \
    "$work/$third_platform/" "$runtime/$third_platform/"
mkdir -p "$runtime/ThirdParty-14/licenses"
cp "$work/ThirdParty-14/scotch_7.0.12/LICENSE_en.txt" "$runtime/ThirdParty-14/licenses/Scotch.txt"
cp "$work/ThirdParty-14/metis-5.1.0/LICENSE.txt" "$runtime/ThirdParty-14/licenses/METIS.txt"
cp "$work/ThirdParty-14/Zoltan-3.90/COPYRIGHT_AND_LICENSE" "$runtime/ThirdParty-14/licenses/Zoltan.txt"
rsync -a --exclude=/share/doc/openmpi/html/ "$work/mpi/" "$runtime/mpi/"

# Foundation and ThirdParty libraries can carry absolute or bare install names.
# Use the mount point shared by the release launcher and the packaged runtime.
relocate() {
    local file=$1 identity dependency library name
    local -a changes=()
    identity=$(otool -D "$file" | sed -n '2p')
    if [[ -n "$identity" ]]; then
        changes+=(-id "/Volumes/OpenFOAM-14/${file#"$runtime/"}")
    fi

    while IFS= read -r dependency; do
        [[ -n "$dependency" && "$dependency" != "$identity" ]] || continue
        case "$dependency" in
            */libPstream.dylib|libPstream.dylib)
                # Linux selects Pstream by soname. Mach-O links to the dummy library.
                library="$runtime/$platform/lib/openmpi-system/libPstream.dylib" ;;
            /usr/lib/*|/System/*|@loader_path/*)
                continue ;;
            "$work"/*)
                library="$runtime/${dependency#"$work/"}" ;;
            /*)
                echo "Unbundled dependency: $dependency in $file" >&2
                return 1 ;;
            *)
                name=${dependency##*/}
                for library in "${file%/*}/$name" "$runtime/$platform/lib/$name" "$runtime/mpi/lib/$name" \
                    "$runtime/$third_platform/lib/openmpi-system/$name" \
                    "$runtime/$third_platform/lib/$name"; do
                    [[ -f "$library" ]] && break
                done ;;
        esac
        [[ -f "$library" ]] || {
            echo "Unresolved dependency: $dependency in $file" >&2
            return 1
        }
        changes+=(-change "$dependency" "/Volumes/OpenFOAM-14/${library#"$runtime/"}")
    done < <(otool -L "$file" | sed -n '2,$s/^[[:space:]]*\(.*\) (compatibility version.*$/\1/p')

    if (( ${#changes[@]} )); then
        chmod u+w "$file"
        install_name_tool "${changes[@]}" "$file"
    fi
    if [[ $sign_identity != - && $2 == *executable* ]]; then
        # OpenFOAM executables load Open MPI and user-built libraries.
        codesign "${code_sign[@]}" --entitlements "$repo/app/runtime.entitlements" "$file"
    else
        codesign "${code_sign[@]}" "$file"
    fi
}

while IFS= read -r -d '' file; do
    kind=$(file -b "$file")
    if [[ $kind == *Mach-O* ]]; then
        relocate "$file" "$kind"
    fi
done < <(find "$runtime/$platform" "$runtime/ThirdParty-14/platforms" \
    "$runtime/OpenFOAM-14/wmake" "$runtime/mpi" -type f \
    \( -name '*.dylib' -o -perm -100 \) -print0)

uuidgen > "$runtime/.runtime-id"
staged_app="$stage/OpenFOAM-14.app"
resources="$staged_app/Contents/Resources"
plist="$staged_app/Contents/Info.plist"
mkdir -p "$resources" "$staged_app/Contents/MacOS"
cp "$repo/app/Info.plist" "$plist"
xcrun clang -arch arm64 -mmacosx-version-min=15.0 -framework Foundation \
    "$repo/app/launch.m" -o "$staged_app/Contents/MacOS/OpenFOAM"
command_launcher="$staged_app/Contents/MacOS/OpenFOAM-14.command"
# Terminal opens the command as a separate quarantined executable.
cp "$staged_app/Contents/MacOS/OpenFOAM" "$command_launcher"
codesign "${code_sign[@]}" "$command_launcher"
plutil -replace CFBundleVersion -string "$version" "$plist"
plutil -replace CFBundleShortVersionString -string "$version" "$plist"
cp "$repo/assets/OpenFOAM14.icns" "$resources/"
cp "$repo/app/openfoam-14" "$repo/app/session.bash" "$resources/"
cp "$runtime/.runtime-id" "$resources/runtime-id"
hdiutil create -fs 'Case-sensitive APFS' -format UDZO -srcfolder "$runtime" \
    -volname OpenFOAM-14 "$resources/OpenFOAM-14.dmg"
# Disk image creation can attach Finder metadata that code signing rejects.
xattr -rd com.apple.FinderInfo "$staged_app" 2>/dev/null || true
xattr -rd com.apple.ResourceFork "$staged_app" 2>/dev/null || true

if [[ $sign_identity != - ]]; then
    codesign --force --timestamp --sign "$sign_identity" "$resources/OpenFOAM-14.dmg"
fi
codesign "${code_sign[@]}" "$staged_app"
staged_output=$(mktemp -d "$output/.openfoam14.XXXXXX")
ditto "$staged_app" "$staged_output/OpenFOAM-14.app"
mv -n "$staged_output/OpenFOAM-14.app" "$output/"
test ! -e "$staged_output/OpenFOAM-14.app"
