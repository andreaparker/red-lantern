"""Audit the distributable ZIP without launching the app or changing a display."""

import plistlib
import stat
import sys
import zipfile
from pathlib import Path

ROOT = "Red Lantern.app/Contents/"
FILES = {
    ROOT + "Info.plist",
    ROOT + "MacOS/RedLantern",
    ROOT + "MacOS/LanternGuardian",
    ROOT + "Resources/AppIcon.icns",
    ROOT + "Resources/LICENSE",
    ROOT + "_CodeSignature/CodeResources",
}
PRIVATE_MARKERS = (
    b"/Users/",
    b"/private/var/folders/",
    b"PRIVATE KEY-----",
)


def check_file(package, entry):
    mode = entry.external_attr >> 16
    assert stat.S_ISREG(mode), f"Not a regular file: {entry.filename}"
    data = package.read(entry)
    assert data, f"Empty file: {entry.filename}"
    for marker in PRIVATE_MARKERS:
        assert marker not in data, f"Private build data in {entry.filename}"
    if "/MacOS/" in entry.filename:
        assert mode & stat.S_IXUSR, f"Not executable: {entry.filename}"


def check_manifest(package):
    entries = package.infolist()
    assert len(entries) == len({entry.filename for entry in entries}), "Duplicate entries"
    files = {entry.filename for entry in entries if not entry.is_dir()}
    assert files == FILES, f"Unexpected package files: {files ^ FILES}"
    return entries


def check_archive(path):
    with zipfile.ZipFile(path) as package:
        entries = check_manifest(package)
        for entry in entries:
            if not entry.is_dir():
                check_file(package, entry)
        bundled = plistlib.loads(package.read(ROOT + "Info.plist"))
        source = plistlib.loads(Path("Info.plist").read_bytes())
        assert bundled == source, "Packaged app metadata differs from source"
        assert package.testzip() is None, "ZIP integrity check failed"
    print("PASS: release contents, executable permissions, metadata, and private-path checks")


if __name__ == "__main__":
    check_archive(sys.argv[1])
