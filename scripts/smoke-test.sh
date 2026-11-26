#!/bin/bash
set -euo pipefail

launcher=${1:?Usage: smoke-test.sh <openfoam-14 launcher> <output directory>}
output=$(cd "${2:?Output directory must exist}" && pwd -P)
launcher=$(cd "$(dirname "$launcher")" && pwd -P)/$(basename "$launcher")

"$launcher" --help | grep '^Usage: openfoam-14'
"$launcher" --version | grep '^OpenFOAM Foundation 14'
status=0
result=$("$launcher" -- /bin/bash -c 'printf "%s" "$1"; exit 23' probe 'one argument') || status=$?
[[ $result == 'one argument' && $status == 23 ]]

# Keep the two runs independent so the serial output cannot pass the MPI check.
case_dir=$(mktemp -d "$output/cavity.XXXXXX")
"$launcher" /bin/bash -c '
    set -euo pipefail
    [[ $WM_PROJECT_VERSION == 14 && $WM_PROJECT_DIR == /Volumes/OpenFOAM-14/OpenFOAM-14 ]]
    [[ $(command -v mpirun) == /Volumes/OpenFOAM-14/mpi/bin/mpirun ]]
    cd "$1"
    ditto "$FOAM_TUTORIALS/incompressibleFluid/cavity" serial
    ditto serial parallel
    chmod -R u+w serial parallel
    cd serial
    blockMesh > log.blockMesh 2>&1
    foamRun > log.foamRun 2>&1
    grep -qx End log.foamRun
    cd ../parallel
    cat > system/decomposeParDict <<\DICT
FoamFile
{
    version 2.0;
    format ascii;
    class dictionary;
    object decomposeParDict;
}
numberOfSubdomains 2;
method scotch;
DICT
    blockMesh > log.blockMesh 2>&1
    decomposePar > log.decomposePar 2>&1
    mpirun -np 2 foamRun -parallel > log.foamRun 2>&1
    reconstructPar -latestTime > log.reconstructPar 2>&1
    grep -Eq "^nProcs[[:space:]]*:[[:space:]]*2$" log.foamRun
    grep -qx End log.foamRun
    grep -qx End log.reconstructPar
    test -f 10/U
' smoke-test "$case_dir"
echo "Serial and two-rank cavity runs passed in $case_dir."
