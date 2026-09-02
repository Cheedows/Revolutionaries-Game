#!/usr/bin/env python3
"""Does the built APK actually lock the screen the way the project asks?

`display/window/handheld/orientation` is an int in Godot 4, and the Android
exporter casts whatever it finds there to int on the way into the manifest. A
string does not fail the export: it casts to 0, which is SCREEN_LANDSCAPE. So
a project can read "portrait", pass a test that compares it to "portrait", and
ship every build hard-locked sideways with nothing anywhere saying so. That is
exactly what this project did.

Nothing but the artefact settles it, so this reads the APK back. It decodes
AndroidManifest.xml — Android's binary XML, not text — finds the activity's
android:screenOrientation, and fails unless it is one the game can be played
in.

    python3 tools/android/check_orientation.py build/revolutionaries-debug.apk
"""

import struct
import sys
import zipfile

# Android's own values for android:screenOrientation, which are not Godot's.
ANDROID_ORIENTATION = {
    -1: "unspecified", 0: "landscape", 1: "portrait", 2: "user", 3: "behind",
    4: "sensor", 5: "nosensor", 6: "sensorLandscape", 7: "sensorPortrait",
    8: "reverseLandscape", 9: "reversePortrait", 10: "fullSensor",
    11: "userLandscape", 12: "userPortrait", 13: "fullUser", 14: "locked",
}

# What the game may ship as: upright, or upright either way up. Anything that
# permits landscape is a bug, because the layout is one narrow column.
WANTED = {"portrait", "reversePortrait", "sensorPortrait", "userPortrait"}

SCREEN_ORIENTATION_ATTR = 0x0101001E

CHUNK_STRING_POOL = 0x0001
CHUNK_RESOURCE_MAP = 0x0180
CHUNK_START_ELEMENT = 0x0102


def _strings(blob, offset):
    """The manifest's string pool, which holds every name in it."""
    count, _styles, flags, strings_start, _ = struct.unpack_from(
        "<IIIII", blob, offset + 8)
    utf8 = bool(flags & (1 << 8))
    offsets = [struct.unpack_from("<I", blob, offset + 28 + 4 * i)[0]
               for i in range(count)]
    base = offset + strings_start

    def one(index):
        at = base + offsets[index]
        if utf8:
            # Two lengths, each one or two bytes: characters, then bytes.
            if blob[at] & 0x80:
                at += 2
            else:
                at += 1
            length = blob[at]
            if length & 0x80:
                length = ((length & 0x7F) << 8) | blob[at + 1]
                at += 2
            else:
                at += 1
            return blob[at:at + length].decode("utf-8", "replace")
        length = struct.unpack_from("<H", blob, at)[0]
        return blob[at + 2:at + 2 + length * 2].decode("utf-16-le", "replace")

    return [one(i) for i in range(count)]


def orientations(blob):
    """Every android:screenOrientation the manifest sets, as Android's ints.

    Attribute names in a compiled manifest are usually blank in the string
    pool and identified by resource id instead, so the resource map is what
    says which attribute is which.
    """
    at = 8
    kind, _header, size = struct.unpack_from("<HHI", blob, at)
    if kind != CHUNK_STRING_POOL:
        raise ValueError("not an AndroidManifest.xml: no string pool")
    pool = _strings(blob, at)
    at += size

    resources = []
    kind, _header, size = struct.unpack_from("<HHI", blob, at)
    if kind == CHUNK_RESOURCE_MAP:
        resources = [struct.unpack_from("<I", blob, at + 8 + 4 * i)[0]
                     for i in range((size - 8) // 4)]
        at += size

    found = []
    while at < len(blob):
        kind, _header, size = struct.unpack_from("<HHI", blob, at)
        if size == 0:
            break
        if kind == CHUNK_START_ELEMENT:
            start = struct.unpack_from("<H", blob, at + 24)[0]
            count = struct.unpack_from("<H", blob, at + 28)[0]
            for i in range(count):
                _ns, name, _raw, _kind, data = struct.unpack_from(
                    "<iiiiI", blob, at + 16 + start + i * 20)
                named = pool[name] if 0 <= name < len(pool) else ""
                is_it = named.endswith("screenOrientation") or (
                    0 <= name < len(resources)
                    and resources[name] == SCREEN_ORIENTATION_ATTR)
                if is_it:
                    found.append(data if data < 0x80000000 else data - (1 << 32))
        at += size
    return found


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    with zipfile.ZipFile(sys.argv[1]) as apk:
        blob = apk.read("AndroidManifest.xml")

    found = orientations(blob)
    if not found:
        print("The manifest sets no screenOrientation at all, so Android will"
              " follow the\ndevice and the game will be played sideways.")
        return 1

    named = [ANDROID_ORIENTATION.get(value, str(value)) for value in found]
    wrong = [name for name in named if name not in WANTED]
    for name in named:
        print("  android:screenOrientation = %s%s"
              % (name, "" if name in WANTED else "   <- not upright"))
    if wrong:
        print("\nThe APK is not locked upright. The project setting is an int"
              " —\nDisplayServer.SCREEN_PORTRAIT is 1 — and a string there"
              " casts to 0, which is\nlandscape. Check that"
              " game/project.godot says"
              " window/handheld/orientation=1\nand not a word in quotes.")
        return 1
    print("\nUpright, as the layout needs.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
