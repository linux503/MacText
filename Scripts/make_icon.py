#!/usr/bin/env python3
"""Build a complete macOS AppIcon.icns for MacText.

Avoids shell/@2x filename corruption. Ships a FULL-BLEED opaque square —
do not pre-mask a squircle. Dock/Finder apply Apple's mask once; pre-masking
plus system masking makes the tile look smaller than other apps.

Also regenerates assets/MacTextIcon-flat.png: pure black, no glass card —
large Futura Condensed ExtraBold MT + amber caret.
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
DOCS_ASSETS = ROOT / "docs" / "assets"
SRC_CANDIDATES = [
    ASSETS / "MacTextIcon-flat.png",
    RES / "MacTextIcon.png",
]

# Brand colors (Ink / Monokai-aligned)
LIME = (184, 224, 74, 255)
WHITE = (245, 245, 247, 255)
AMBER = (245, 165, 36, 255)
BLACK = (0, 0, 0, 255)

FONT_CANDIDATES = [
    ("/System/Library/Fonts/Supplemental/Futura.ttc", 4),  # Condensed ExtraBold
    ("/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf", 0),
    ("/System/Library/Fonts/Supplemental/Impact.ttf", 0),
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


def compose_flat(size: int = 1024) -> Path:
    """Pure black full-bleed MT mark — no frosted card / corner frame."""
    from PIL import Image, ImageDraw, ImageFont, ImageFilter

    font = None
    font_size = 580
    for path, index in FONT_CANDIDATES:
        p = Path(path)
        if not p.exists():
            continue
        try:
            font = ImageFont.truetype(str(p), font_size, index=index)
            break
        except OSError:
            continue
    if font is None:
        raise SystemExit("No suitable display font found for icon")

    img = Image.new("RGBA", (size, size), BLACK)
    probe = ImageDraw.Draw(img)
    mb = probe.textbbox((0, 0), "M", font=font)
    tb = probe.textbbox((0, 0), "T", font=font)
    mw = mb[2] - mb[0]
    tw = tb[2] - tb[0]
    gap = -24
    total_w = mw + gap + tw
    total_h = max(mb[3] - mb[1], tb[3] - tb[1])

    x0 = (size - total_w) // 2 - mb[0]
    y0 = (size - total_h) // 2 - min(mb[1], tb[1]) - 40
    mx, tx = x0, x0 + mw + gap

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.text((mx + 4, y0 + 8), "M", font=font, fill=(0, 0, 0, 200))
    sd.text((tx + 4, y0 + 8), "T", font=font, fill=(0, 0, 0, 200))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    img = Image.alpha_composite(img, shadow)

    # Soft lime bloom on M only (not a card)
    bloom = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bloom)
    bd.text((mx, y0), "M", font=font, fill=(184, 224, 74, 64))
    bloom = bloom.filter(ImageFilter.GaussianBlur(18))
    img = Image.alpha_composite(img, bloom)

    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.text((mx, y0), "M", font=font, fill=LIME)
    ld.text((tx, y0), "T", font=font, fill=WHITE)

    ink_bottom = max(y0 + mb[3], y0 + tb[3])
    uw = int(total_w * 0.36)
    uh = max(14, size // 64)
    ux = (size - uw) // 2
    uy = ink_bottom + max(18, size // 48)
    ld.rounded_rectangle((ux, uy, ux + uw, uy + uh), radius=uh // 2, fill=AMBER)
    img = Image.alpha_composite(img, layer)

    bg = Image.new("RGB", (size, size), (0, 0, 0))
    bg.paste(img, mask=img.split()[-1])
    final = bg.convert("RGBA")

    ASSETS.mkdir(parents=True, exist_ok=True)
    out = ASSETS / "MacTextIcon-flat.png"
    final.save(out, "PNG")

    if DOCS_ASSETS.exists():
        for px, name in ((256, "icon-256.png"), (512, "icon-512.png"), (256, "icon.png")):
            final.resize((px, px), Image.Resampling.LANCZOS).save(DOCS_ASSETS / name, "PNG")

    print(f"    composed flat: {out.name} (Futura Condensed ExtraBold, pure black)")
    return out


def render_master(src: Path, out: Path, size: int = 1024) -> None:
    """Scale source to a full-bleed opaque square. System applies the squircle."""
    out.parent.mkdir(parents=True, exist_ok=True)
    run(["sips", "-s", "format", "png", "-z", str(size), str(size), str(src), "--out", str(out)])
    data = out.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"Master is not PNG: {out}")
    w, h = struct.unpack(">II", data[16:24])
    if (w, h) != (size, size):
        raise SystemExit(f"Master size mismatch: {w}x{h} != {size}x{size}")


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
    print("==> Composing MacText icon (pure black · no card)")
    src = compose_flat(1024)

    print(f"==> Building AppIcon.icns from {src}")
    RES.mkdir(parents=True, exist_ok=True)
    master = RES / "MacTextIcon.png"

    render_master(src, master, 1024)
    print("    master: full-bleed square (system masks Dock/Finder)")

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
