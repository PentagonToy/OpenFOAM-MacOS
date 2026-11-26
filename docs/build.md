# Build OpenFOAM 14 for macOS

Start with the source pair used by [rathse/openfoam-macos](https://github.com/rathse/openfoam-macos). The pinned revisions are [OpenFOAM-14 at `0dc1890691`](https://github.com/OpenFOAM/OpenFOAM-14/commit/0dc18906914a67b73ab53dc33ca9b0c619601dfb) and [ThirdParty-14 at `6f75cb6aa1`](https://github.com/OpenFOAM/ThirdParty-14/commit/6f75cb6aa1a3d8f1ba768840f9ee535244b4c70a). Build with Apple Clang on case-sensitive APFS and use that pair to establish a reproducible baseline before validating newer Foundation 14 patch releases.

The app holds OpenFOAM and Open MPI in a read-only, case-sensitive disk image. The Cask links `openfoam-14`. Keep cases and user-built binaries in writable directories.

On an Apple Silicon Mac with Xcode Command Line Tools, CMake and GNU Make 4 (`gmake`) on `PATH`, run the following from this repository. Use a writable case-sensitive APFS volume with a mount path free of spaces and choose an existing output directory.

```sh
scripts/build.sh /Volumes/OpenFOAM14-build 5
scripts/package.sh /Volumes/OpenFOAM14-build /path/to/output 0.1.0
scripts/smoke-test.sh "/path/to/output/OpenFOAM-14.app/Contents/Resources/openfoam-14" /path/to/output
```

The patches are tracked in [patches](../patches). They derive from `rathse/openfoam-macos@28912e8`, with the ParMETIS source omitted. The build pins the Open MPI source checksum and builds it with its bundled support libraries. It also compiles Scotch, METIS and Zoltan for OpenFOAM. The default package uses ad hoc signing for local testing.

To rebuild without upstream repositories, extract the corresponding release source archive onto a fresh build volume and run:

```sh
tar -xzf /path/to/openfoam-14-0.1.0-source.tar.gz -C /Volumes/OpenFOAM14-build
OPENFOAM_OFFLINE=1 scripts/build.sh /Volumes/OpenFOAM14-build 5
```

Keep the source archive and this packaging repository together. The archive contains the prepared OpenFOAM and ThirdParty trees and the checksummed Open MPI tarball.

The [macOS build workflow](../.github/workflows/macos-build.yml) runs these steps on an Apple Silicon GitHub Actions runner and archives the development app and test logs.

For release builds, set `OPENFOAM_DEVELOPER_ID` to the Developer ID Application identity before running `package.sh`. Notarise and staple the app before creating the distribution DMG. Sign, notarise and staple `openfoam-14-<version>-arm64.dmg`, then generate the tap's `Casks/openfoam-14.rb` from the completed DMG with `scripts/cask.sh`.

## First release checks

Verify Finder and CLI launch on an Apple Silicon Mac without the build environment. Confirm that the packaged binaries resolve OpenFOAM and MPI libraries from their intended locations. The smoke-test script runs the Foundation `incompressibleFluid/cavity` tutorial in separate writable directories for serial and two-rank MPI execution. Set the minimum macOS version from the compatibility results.
