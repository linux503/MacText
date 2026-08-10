#!/usr/bin/env python3
"""Build a complete macOS AppIcon.icns for MacText.

Avoids shell/@2x filename corruption and produces a Dock-ready squircle icon
with transparent corners (matches system masking even without Asset Catalog).
"""
from __future__ import annotations

import struct
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "Resources"
ASSETS = ROOT / "assets"
SRC_CANDIDATES = [
    ASSETS / "MacTextIcon-flat.png",
    RES / "MacTextIcon.png",
]

# iconset name pieces — never write contiguous "local@domain" strings in sources
AT = "@"
TWO_X = "2x.png"


def icon_name(base: str, retina: bool = False) -> str:
    """base like '16x16' -> icon_16x16.png or icon_16x16@2x.png"""
    if retina:
        return f"icon_{base}{AT}{TWO_X}"
    return f"icon_{base}.png"


# (pixels, iconset filename)
ICONSET_ENTRIES = [
    (16, icon_name("16x16")),
    (32, icon_name("16x16", retina=True)),
    (32, icon_name("32x32")),
    (64, icon_name("32x32", retina=True)),
    (128, icon_name("128x128")),
    (256, icon_name("128x128", retina=True)),
    (256, icon_name("256x256")),
    (512, icon_name("256x256", retina=True)),
    (512, icon_name("512x512")),
    (1024, icon_name("512x512", retina=True)),
]

# OSType mapping for .icns
ICNS_MAP = [
    (icon_name("16x16"), b"icp4"),
    (icon_name("16x16", True), b"ic11"),
    (icon_name("32x32"), b"icp5"),
    (icon_name("32x32", True), b"ic12"),
    (icon_name("128x128"), b"ic07"),
    (icon_name("128x128", True), b"ic13"),
    (icon_name("256x256"), b"ic08"),
    (icon_name("256x256", True), b"ic14"),
    (icon_name("512x512"), b"ic09"),
    (icon_name("512x512", True), b"ic10"),
]


def run(cmd: list[str]) -> None:
    subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def render_master(src: Path, out: Path, size: int = 1024) -> None:
    """Composite flat art into a transparent-corner squircle at exact pixel size."""
    import AppKit

    source = AppKit.NSImage.alloc().initWithContentsOfFile_(str(src))
    if source is None or not source.isValid():
        raise SystemExit(f"Cannot load source icon: {src}")

    # Draw into a 1x bitmap so Retina lockFocus does not produce 2x canvases
    rep = AppKit.NSBitmapImageRep.alloc().initWithBitmapDataPlanes_pixelsWide_pixelsHigh_bitsPerSample_samplesPerPixel_hasAlpha_isPlanar_colorSpaceName_bytesPerRow_bitsPerPixel_(
        None,
        size,
        size,
        8,
        4,
        True,
        False,
        AppKit.NSCalibratedRGBColorSpace,
        0,
        0,
    )
    AppKit.NSGraphicsContext.saveGraphicsState()
    ctx = AppKit.NSGraphicsContext.graphicsContextWithBitmapImageRep_(rep)
    AppKit.NSGraphicsContext.setCurrentContext_(ctx)
    ctx.setImageInterpolation_(AppKit.NSImageInterpolationHigh)

    AppKit.NSColor.clearColor().set()
    AppKit.NSRectFill(AppKit.NSMakeRect(0, 0, size, size))

    radius = size * 0.2237
    path = AppKit.NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(
        AppKit.NSMakeRect(0, 0, size, size), radius, radius
    )
    path.addClip()
    source.drawInRect_fromRect_operation_fraction_(
        AppKit.NSMakeRect(0, 0, size, size),
        AppKit.NSZeroRect,
        AppKit.NSCompositingOperationSourceOver,
        1.0,
    )
    AppKit.NSGraphicsContext.restoreGraphicsState()

    png = bytes(rep.representationUsingType_properties_(AppKit.NSBitmapImageFileTypePNG, None))
    # Guard against accidental Retina 2x PNG headers
    w, h = struct.unpack(">II", png[16:24])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(png)
    if (w, h) != (size, size):
        run(["sips", "-z", str(size), str(size), str(out), "--out", str(out)])


def write_icns(iconset: Path, dest: Path) -> list[str]:
    chunks: list[bytes] = []
    types: list[str] = []
    for name, ostype in ICNS_MAP:
        path = iconset / name
        if not path.exists():
            raise SystemExit(f"Missing iconset entry: {name}")
        data = path.read_bytes()
        # Verify PNG dimensions roughly via IHDR
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            raise SystemExit(f"Not PNG: {name}")
        w, h = struct.unpack(">II", data[16:24])
        chunks.append(ostype + struct.pack(">I", 8 + len(data)) + data)
        types.append(f"{ostype.decode()}:{w}x{h}")
    body = b"".join(chunks)
    dest.write_bytes(b"icns" + struct.pack(">I", 8 + len(body)) + body)
    return types


def main() -> int:
    src = next((p for p in SRC_CANDIDATES if p.exists()), None)
    if src is None:
        print("No source PNG found", file=sys.stderr)
        return 1

    print(f"==> Building AppIcon.icns from {src}")
    RES.mkdir(parents=True, exist_ok=True)
    master = RES / "MacTextIcon.png"

    # Render squircle-masked master
    try:
        render_master(src, master, 1024)
        print("    master: squircle + transparent corners")
    except Exception as exc:  # noqa: BLE001
        print(f"    AppKit render failed ({exc}); falling back to flat copy")
        run(["sips", "-s", "format", "png", "-z", "1024", "1024", str(src), "--out", str(master)])

    with tempfile.TemporaryDirectory(prefix="mactext-icon-") as tmp:
        tmp_path = Path(tmp)
        iconset = tmp_path / "AppIcon.iconset"
        iconset.mkdir()

        for px, name in ICONSET_ENTRIES:
            # sips mishandles '@' in --out paths — write plain then rename
            plain = tmp_path / f"gen_{px}_{abs(hash(name)) & 0xFFFF}.png"
            run(["sips", "-z", str(px), str(px), str(master), "--out", str(plain)])
            dest = iconset / name
            plain.replace(dest)
            data = dest.read_bytes()
            w, h = struct.unpack(">II", data[16:24])
            if (w, h) != (px, px):
                raise SystemExit(f"Size mismatch for {name}: {w}x{h} != {px}x{px}")

        names = sorted(p.name for p in iconset.iterdir())
        print(f"    iconset entries: {len(names)}")
        for n in names:
            print(f"      {n}")

        # Try Apple iconutil first (best Dock compatibility)
        util_out = tmp_path / "AppIcon-iconutil.icns"
        try:
            subprocess.check_call(
                ["iconutil", "-c", "icns", str(iconset), "-o", str(util_out)],
                stdout=subprocess.DEVNULL,
            )
            data = util_out.read_bytes()
            off = 8
            util_types: list[str] = []
            while off + 8 <= len(data):
                t = data[off : off + 4].decode("latin1")
                s = struct.unpack(">I", data[off + 4 : off + 8])[0]
                util_types.append(t)
                off += s
            if "ic10" in util_types and "ic09" in util_types:
                (RES / "AppIcon.icns").write_bytes(data)
                print(f"    iconutil OK types={util_types}")
            else:
                raise RuntimeError(f"iconutil missing large icons: {util_types}")
        except Exception as exc:  # noqa: BLE001
            print(f"    iconutil fallback ({exc})")
            types = write_icns(iconset, RES / "AppIcon.icns")
            print(f"    python icns types={types}")

    # Final verification
    data = (RES / "AppIcon.icns").read_bytes()
    off = 8
    types = []
    while off + 8 <= len(data):
        t = data[off : off + 4].decode("latin1")
        s = struct.unpack(">I", data[off + 4 : off + 8])[0]
        types.append(t)
        off += s
    need = {"ic07", "ic08", "ic09", "ic10"}
    missing = need - set(types)
    if missing:
        print(f"ERROR missing icns types: {missing}", file=sys.stderr)
        return 1
    print(f"OK: AppIcon.icns ({len(data)} bytes) types={types}")
    print(f"    {RES / 'AppIcon.icns'}")
    print(f"    {master}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
