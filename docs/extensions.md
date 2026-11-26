# Build an add-on

Use an add-on that supports OpenFOAM Foundation 14. Build from a writable copy of its source with the Xcode Command Line Tools installed. Add-ons with names that differ only in letter case need a case-sensitive APFS volume.

For a project with an `Allwmake` script, run it from the add-on's source directory:

```sh
openfoam-14 -- ./Allwmake
```

Use the launcher for both build and run commands so they select the same Foundation runtime. In `Make/files`, target `$(FOAM_USER_APPBIN)` for executables and `$(FOAM_USER_LIBBIN)` for shared libraries. The app adds both locations to each session. Put the add-on's libraries in the case dictionary using its documented `libs` entries.

## Example with cfMesh 1.2.0

Use the [cfMesh 1.2.0 source archive](https://sourceforge.net/projects/cfmesh/files/1.2.0/) with the [Foundation 14 patch](../patches/cfMesh-1.2.0-081078932d.patch) from rathse/openfoam-macos. The source archive used here has SHA-256 `429f3fb2d73c2a9831f49a5bde1a26510847a80973f86a3b3fdac3e4101e9577`.

From a writable case-sensitive directory containing that archive, run the following commands. Replace the patch path with the one in your OpenFOAM-MacOS checkout.

```sh
tar -xzf cfMesh-1.2.0.tgz --exclude='*/platforms/*'
cd cfMesh-1.2.0
git apply /path/to/OpenFOAM-MacOS/patches/cfMesh-1.2.0-081078932d.patch
openfoam-14 -- ./Allwmake
cp -R tutorials/cartesianMesh/singleOrifice ../singleOrifice
cd ../singleOrifice
openfoam-14 -- surfaceToFMS singleOrifice.stl
openfoam-14 -- FMSToVTK singleOrifice.fms singleOrifice
```

The example writes `singleOrifice.fms` and `singleOrifice.vtm` in the working copy. It was verified on Apple Silicon with the packaged Foundation 14 runtime.

The patch builds cfMesh with Apple Clang and disables OpenMP on macOS. In the same case, `cartesianMesh` stopped during surface smoothing and `checkMesh` reported one face-ordering failure. The surface conversion above is the verified example.
