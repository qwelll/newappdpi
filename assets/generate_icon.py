#!/usr/bin/env python3
"""Generates the PreferenceBundle icon (48/96/144 px) without third-party modules.

The icon is drawn as a tiny PNG by encoding raw RGBA scanlines with zlib; it depicts a
screen outline with four shrinking bars, i.e. "more content on the same display".
"""

import os
import struct
import zlib

SIZE = 1
BACKGROUND = (0x1C, 0x1C, 0x1E, 0xFF)
ACCENT = (0x0A, 0x84, 0xFF, 0xFF)
ACCENT_LIGHT = (0x64, 0xB5, 0xF6, 0xFF)


def rounded_rect(px, size, x0, y0, x1, y1, radius, color):
    """Fills the rounded rectangle [x0,x1) x [y0,y1) into a flat RGBA list."""
    for y in range(int(y0), int(y1)):
        for x in range(int(x0), int(x1)):
            # corner distance test
            cx = min(max(x, x0 + radius), x1 - radius)
            cy = min(max(y, y0 + radius), y1 - radius)
            if (x - cx) ** 2 + (y - cy) ** 2 > radius ** 2:
                continue
            i = (y * size + x) * 4
            px[i:i + 4] = bytes(color)


def render(size):
    px = bytearray(BACKGROUND * (size * size))
    unit = size / 24.0
    rounded_rect(px, size, 2 * unit, 2 * unit, 22 * unit, 22 * unit, 4 * unit, (0x2C, 0x2C, 0x30, 0xFF))
    rounded_rect(px, size, 3.5 * unit, 3.5 * unit, 20.5 * unit, 20.5 * unit, 3 * unit, (0xF2, 0xF2, 0xF7, 0xFF))
    bar_widths = (13, 10, 7, 11)
    for index, width in enumerate(bar_widths):
        y = 6.5 * unit + index * 3 * unit
        color = ACCENT if index % 2 == 0 else ACCENT_LIGHT
        rounded_rect(px, size, 6.5 * unit, y, 6.5 * unit + width * unit, y + 1.6 * unit, 0.8 * unit, color)
    return px


def write_png(path, width, height, rgba):
    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw.extend(rgba[y * stride:(y + 1) * stride])

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as handle:
        handle.write(png)


def main():
    # assets/ sits next to the PreferenceBundle directory.
    resources = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                             "AppDPIPrefs", "Resources")
    os.makedirs(resources, exist_ok=True)
    # Theos copies Resources verbatim, so the base variant must be 48px (2x of 24pt).
    for size, name in ((48, "icon.png"), (96, "icon@2x.png"), (144, "icon@3x.png")):
        write_png(os.path.join(resources, name), size, size, render(size))
        print("wrote", name, size)


if __name__ == "__main__":
    main()
