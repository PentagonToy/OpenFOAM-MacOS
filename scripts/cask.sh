#!/bin/bash
set -euo pipefail

asset=${1:?Usage: cask.sh <openfoam-14-VERSION-arm64.dmg>}
name=${asset##*/}
if [[ ! $name =~ ^openfoam-14-([0-9]+\.[0-9]+\.[0-9]+)-arm64\.dmg$ ]]; then
    echo "The asset must be named openfoam-14-VERSION-arm64.dmg." >&2
    exit 1
fi
version=${BASH_REMATCH[1]}
checksum=$(shasum -a 256 < "$asset")
checksum=${checksum%% *}

cat <<CASK
cask "openfoam-14" do
  version "$version"
  sha256 "$checksum"

  url "https://github.com/PentagonToy/OpenFOAM-MacOS/releases/download/v#{version}/openfoam-14-#{version}-arm64.dmg"
  name "OpenFOAM 14"
  desc "Native macOS distribution of OpenFOAM Foundation 14"
  homepage "https://github.com/PentagonToy/OpenFOAM-MacOS"

  depends_on arch: :arm64
  depends_on macos: :sequoia
  app "OpenFOAM-14.app"
  binary "#{appdir}/OpenFOAM-14.app/Contents/Resources/openfoam-14"

  uninstall script: {
    executable:   "#{appdir}/OpenFOAM-14.app/Contents/Resources/openfoam-14",
    args:         ["--eject"],
    must_succeed: false,
  }

  caveats <<~EOS
    Quit OpenFOAM 14 sessions and run openfoam-14 --eject before upgrading.
    User cases and libraries remain in your OpenFOAM user directory.
  EOS
end
CASK
