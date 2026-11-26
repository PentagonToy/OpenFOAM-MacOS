#!/bin/bash
set -euo pipefail

work=$(cd "${1:?Usage: build-mpi.sh <build volume> [jobs]}" && pwd -P)
jobs=${2:-5}
mpi_version=5.0.10
archive="$work/openmpi-$mpi_version.tar.gz"
digest=5692cc80554a7117c99eaa725d35100edd8bbf73423a5e265ff867979192df7d

if [[ -x "$work/mpi/bin/mpicc" && -x "$work/mpi/bin/mpirun" ]]; then
    exit 0
fi
if [[ ! -f "$archive" ]]; then
    if [[ ${OPENFOAM_OFFLINE:-0} == 1 ]]; then
        echo "Missing Open MPI source archive: $archive" >&2
        exit 1
    fi
    curl -fL --retry 3 "https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-$mpi_version.tar.gz" -o "$archive.part"
    mv "$archive.part" "$archive"
fi
printf '%s  %s\n' "$digest" "$archive" | shasum -a 256 -c -

export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-15.0}
export LDFLAGS=-Wl,-headerpad_max_install_names
gmake=$(command -v gmake)
stage=$(mktemp -d "$work/.openmpi.XXXXXX")
trap 'rm -rf "$stage"' EXIT
tar -xzf "$archive" -C "$stage"
cd "$stage/openmpi-$mpi_version"
# Recent SDKs expose pipe2 even for a macOS 15 deployment target.
ac_cv_func_pipe2=no ./configure --prefix="$work/mpi" \
    --with-libevent=internal --with-hwloc=internal --with-pmix=internal --with-prrte=internal \
    --without-libfabric --without-ucx --disable-mpi-fortran --disable-oshmem --disable-dlopen
"$gmake" -j "$jobs"
"$gmake" install DESTDIR="$stage/install"
licenses="$stage/install$work/mpi/share/licenses"
mkdir -p "$licenses"
cp LICENSE "$licenses/Open-MPI.txt"
cp 3rd-party/openpmix/LICENSE "$licenses/PMIx.txt"
cp 3rd-party/prrte/LICENSE "$licenses/PRRTE.txt"
cp 3rd-party/hwloc-2.7.1/COPYING "$licenses/hwloc.txt"
cp 3rd-party/libevent-2.1.12-stable-ompi/LICENSE "$licenses/Libevent.txt"
cp 3rd-party/treematch/LICENSE "$licenses/TreeMatch.txt"
mv "$stage/install$work/mpi" "$work/mpi"
