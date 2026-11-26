export OPAL_PREFIX="$OPENFOAM14_ROOT/mpi"
export PRTE_PREFIX="$OPAL_PREFIX" PMIX_PREFIX="$OPAL_PREFIX"
if [[ ! -x "$OPAL_PREFIX/bin/mpirun" ]]; then
    echo "The bundled Open MPI runtime is missing." >&2
    exit 1
fi
export PATH="$OPAL_PREFIX/bin:$PATH"
source "$OPENFOAM14_ROOT/OpenFOAM-14/etc/bashrc" PARMETIS_TYPE=none || exit
if [[ $- == *i* ]]; then
    if [[ -n ${OPENFOAM14_PACKAGE_VERSION:-} ]]; then
        mpi_label='Open MPI included'
        if IFS= read -r mpi_line < <("$OPAL_PREFIX/bin/mpirun" --version 2>/dev/null) &&
            [[ $mpi_line == 'mpirun (Open MPI) '* ]]; then
            mpi_label="Open MPI ${mpi_line#'mpirun (Open MPI) '} included"
        fi
        printf '\n  %-8s %s\n' Ready "$OPENFOAM14_ROOT (read-only)"
        printf '  %-8s %s\n' Package "$OPENFOAM14_PACKAGE_VERSION · $mpi_label" \
            Try 'foamRun -help' Leave 'exit · then openfoam-14 --eject to unmount'
        printf '\n'
        unset OPENFOAM14_PACKAGE_VERSION mpi_label mpi_line
    fi
    PS1='(OpenFOAM-14) \W\$ '
fi
