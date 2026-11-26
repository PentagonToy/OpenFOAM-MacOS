# macOS compatibility notes

The [openfoam-app](https://github.com/gerlero/openfoam-app) issue tracker documents macOS packaging and launch failures that can affect a Foundation build as well.

| Upstream report | How this package addresses it |
| --- | --- |
| [Tutorial scripts lose library paths](https://github.com/gerlero/openfoam-app/issues/5) and [MPI fails through a system shell](https://github.com/gerlero/openfoam-app/issues/333) | The package links its native libraries to the runtime volume. The smoke test runs a case from a system Bash subprocess in serial and on two MPI ranks. |
| [Finder launch fails while CLI works](https://github.com/gerlero/openfoam-app/issues/105) and [a runtime mount fails](https://github.com/gerlero/openfoam-app/issues/263) | Finder and the CLI use the same launcher. It verifies the mounted runtime's identity before using it. |
| [Shell selection changes in an active OpenFOAM session](https://github.com/gerlero/openfoam-app/issues/325) and [PATH conflicts](https://github.com/gerlero/openfoam-app/issues/371) | The launcher selects Bash by absolute path and puts bundled Open MPI ahead of system MPI. The smoke test checks the selected `mpirun`, argument boundaries, stdout and exit status. |
| [Clang rejects a custom boundary condition](https://github.com/gerlero/openfoam-app/issues/87) and [a user library fails to load](https://github.com/gerlero/openfoam-app/issues/235) | Use Apple Clang and write binaries to `$FOAM_USER_APPBIN` or `$FOAM_USER_LIBBIN`. The Foundation macOS patch uses the OpenFOAM library search path when a system subprocess loses `DYLD_LIBRARY_PATH`. |
| [ParaView launch fails through `paraFoam`](https://github.com/gerlero/openfoam-app/issues/403) | Start with `foamToVTK` to export results for a separately installed ParaView. |

If a different disk already occupies `/Volumes/OpenFOAM-14`, identify it in Finder before ejecting it. Run `openfoam-14 --eject` after closing your OpenFOAM sessions to detach the matching runtime.

Builds disable the `pipe2` configure probe so the bundled Libevent uses its portable pipe implementation on macOS 15. The release workflow checks the actual signed DMG on macOS 15.
