#!/usr/bin/env python3
"""Draw the app icon and the mark as SVG and render them into the asset catalogue (plan 007).

Run it with uv, which supplies Pillow (not in the Mac's Python); any working directory will do:
    uv run --with pillow scripts/app_icon/make_app_icon.py

The mark is 2d-j from issue #21's concepts page: a white earwig crawling at 35 degrees
on the theme's sky blue, drawn to the insect's proportions with no face. One mark serves
the Home Screen tile, the splash and the logo.

- light:  white insect on sky blue, opaque (the App Store icon)
- dark:   transparent ground so iOS supplies its dark backdrop; a slightly cooler white
          so it does not glare; the cuts in near-black, which reads as gaps
- tinted: greyscale on a transparent ground, for iOS to tint
- mark:   the white insect alone on nothing, its cuts true gaps (an SVG mask), for the
          splash and the logo: EarwigMark.imageset at @2x and @3x for a 160 pt box

Writes AppIcon-{light,dark,tinted}.svg and EarwigMark.svg beside this script, renders
each with headless Chrome (which renders SVG exactly; ImageMagick is not installed),
writes the two Contents.json files, then checks the PNGs with Pillow. It also writes the
mark's geometry as Swift (Earwig/Critter/CritterGeometry.swift) for the earwig that
walks across the screen (plan 014). Running it twice changes nothing.
"""

import json
import re
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

SIZE = 1024
ROTATION = -35  # degrees; negative turns the insect anticlockwise, so it crawls up and to the right
SCALE = 1.06  # about the centre, after the turn, so the insect fills the tile

SCRIPT_DIR = Path(__file__).resolve().parent
REPO = SCRIPT_DIR.parent.parent
CATALOGUE = REPO / "Earwig" / "Resources" / "Assets.xcassets"
ICON_SET = CATALOGUE / "AppIcon.appiconset"
MARK_SET = CATALOGUE / "EarwigMark.imageset"
MARK_POINTS = 160  # the box the mark image is made for; a smaller use scales it down
GEOMETRY = REPO / "Earwig" / "Critter" / "CritterGeometry.swift"  # the walking earwig's (plan 014)
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# ground None is a transparent ground. cut None cuts the body with real gaps (a mask) rather
# than lines in a colour. The colours match EarwigTheme (light: background and text).
PALETTES = {
    "light": {"ground": "#5CB8F3", "insect": "#FFFFFF", "cut": "#5CB8F3"},
    "dark": {"ground": None, "insect": "#E9F3FC", "cut": "#0B1B2B"},
    "tinted": {"ground": None, "insect": "#D9D9D9", "cut": "#141414"},
}
MARK = {"ground": None, "insect": "#FFFFFF", "cut": None}

# The insect upright in the 1024 box, head up, before the turn (decision 2). Every stroke has
# round caps and joins. The right side is the left side mirrored about x 512.
HEAD = (512, 258, 44, 48)  # cx, cy, rx, ry
PRONOTUM = (460, 296, 104, 68, 18)  # x, y, width, height, rx
WING_CASES = (454, 356, 116, 102, 26)
WING_SPLIT = ((512, 366), (512, 448), 7)  # from, to, width
ABDOMEN = "M456 452 C448 540 468 640 486 704 L538 704 C556 640 576 540 568 452 Z"
CUT_YS = (520, 582, 644)
CUT_WIDTH = 11
ANTENNA = ("M492 224 C464 172 442 130 416 86", 22)
LEGS = (
    ("M462 336 L404 302 L362 330", 22),
    ("M456 398 L394 410 L354 400", 22),
    ("M460 448 L406 490 L372 530", 22),
)
FORCEPS = ("M488 702 C430 764 424 856 496 896", 44)


def stroke(colour: str, width: float) -> str:
    return (f'fill="none" stroke="{colour}" stroke-width="{width}" '
            'stroke-linecap="round" stroke-linejoin="round"')


def path(d: str, colour: str, width: float) -> str:
    return f'<path d="{d}" {stroke(colour, width)}/>'


def cuts() -> list[tuple[tuple[float, float], tuple[float, float], float]]:
    """The three cuts across the abdomen and the split between the wing cases, each as its two
    ends and its width: one source for the icon's SVG and the walking earwig's Swift."""
    lines = []
    for y in CUT_YS:
        inset = 0.1 * (y - 450)  # the abdomen tapers, so the cuts shorten as they go down
        lines.append(((456 + inset, y), (568 - inset, y), CUT_WIDTH))
    lines.append(WING_SPLIT)
    return lines


def cut_lines(colour: str) -> list[str]:
    """The cuts as SVG: across the abdomen horizontally, the split vertically."""
    lines = []
    for (x1, y1), (x2, y2), width in cuts():
        run = f"H{x2:g}" if y1 == y2 else f"V{y2:g}"
        lines.append(path(f"M{x1:g} {y1:g} {run}", colour, width))
    return lines


def body(colour: str) -> list[str]:
    cx, cy, rx, ry = HEAD
    x, y, w, h, r = PRONOTUM
    wx, wy, ww, wh, wr = WING_CASES
    return [
        f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{colour}"/>',
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{colour}"/>',
        f'<path d="{ABDOMEN}" fill="{colour}"/>',
        f'<rect x="{wx}" y="{wy}" width="{ww}" height="{wh}" rx="{wr}" fill="{colour}"/>',
    ]


def limbs(colour: str) -> list[str]:
    """Antennae, legs and forceps for the left side, then mirrored for the right."""
    half = [path(d, colour, w) for d, w in (ANTENNA, *LEGS, FORCEPS)]
    return half + ['<g transform="translate(1024 0) scale(-1 1)">', *half, "</g>"]


def insect(p: dict) -> list[str]:
    """The insect upright. With a cut colour the cuts are painted over the body; with none they
    are cut out of it by a mask, so the ground shows through whatever it is."""
    if p["cut"] is not None:
        # The body first, the cuts over it, then the wing cases over the cuts and their split.
        head, pronotum, abdomen, wings = body(p["insect"])
        *abdomen_cuts, split = cut_lines(p["cut"])
        return [head, pronotum, abdomen, *abdomen_cuts, wings, split, *limbs(p["insect"])]
    mask = ['<mask id="cuts" maskUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024">',
            f'<rect width="{SIZE}" height="{SIZE}" fill="#FFF"/>',
            *cut_lines("#000"), "</mask>",
            '<g mask="url(#cuts)">', *body(p["insect"]), "</g>"]
    return mask + limbs(p["insect"])


def svg(p: dict) -> str:
    half = SIZE // 2
    lines = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">']
    if p["ground"]:
        lines.append(f'<rect width="{SIZE}" height="{SIZE}" fill="{p["ground"]}"/>')
    lines.append(f'<g transform="rotate({ROTATION} {half} {half}) translate({half} {half}) '
                 f'scale({SCALE}) translate(-{half} -{half})">')
    lines += [f"  {part}" for part in insect(p)]
    lines += ["</g>", "</svg>", ""]
    return "\n".join(lines)


def render(svg_path: Path, png_path: Path, pixels: int, transparent: bool) -> None:
    # Wrapped in a page with no margin so the SVG sits exactly in the window.
    with tempfile.TemporaryDirectory() as tmp:
        page = Path(tmp) / "icon.html"
        page.write_text('<!doctype html><html><body style="margin:0;background:transparent">'
                        f'<img src="{svg_path.as_uri()}" width="{pixels}" height="{pixels}" style="display:block">'
                        "</body></html>")
        command = [CHROME, "--headless", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                   f"--window-size={pixels},{pixels}", f"--screenshot={png_path}", "--allow-file-access-from-files"]
        if transparent:
            command.append("--default-background-color=00000000")
        subprocess.run(command + [page.as_uri()], check=True, capture_output=True)


def check(png_path: Path, pixels: int, opaque: bool) -> None:
    with Image.open(png_path) as image:
        assert image.size == (pixels, pixels), f"{png_path.name} is {image.size}"
        if opaque:
            # The App Store rejects an icon with an alpha channel.
            image.convert("RGB").save(png_path, optimize=True)
        else:
            assert image.mode == "RGBA", f"{png_path.name} has no alpha ({image.mode})"
            assert image.getpixel((0, 0))[3] == 0, f"{png_path.name} corner isn't transparent"
            image.save(png_path, optimize=True)


def corner_margin(png_path: Path) -> float:
    """How far, in points of a 1024 tile, the insect's nearest pixel stays inside the Home Screen
    mask (a superellipse of exponent 5 and radius 22.37%, as iOS draws it). Negative is clipped."""
    with Image.open(png_path) as image:
        alpha = image.convert("RGBA").getchannel("A")
        box = alpha.getbbox()
        width, height = image.size
        radius = 0.2237 * width
        margin = float("inf")
        pixels = alpha.load()
        for y in range(box[1], box[3]):
            for x in range(box[0], box[2]):
                if pixels[x, y] < 128:
                    continue
                dx, dy = abs(x + 0.5 - width / 2) - (width / 2 - radius), abs(y + 0.5 - height / 2) - (height / 2 - radius)
                if dx <= 0 or dy <= 0:
                    continue  # on a straight edge, not in a corner
                reach = (dx ** 5 + dy ** 5) ** 0.2
                margin = min(margin, radius - reach)
        return margin * SIZE / width


def write_json(path: Path, contents: dict) -> None:
    text = json.dumps(contents, indent=2, separators=(",", " : "))  # as Xcode writes it
    path.write_text(text + "\n")


def icon_contents() -> dict:
    images = [{"filename": "AppIcon-light.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}]
    for name in ("dark", "tinted"):
        images.append({"appearances": [{"appearance": "luminosity", "value": name}],
                       "filename": f"AppIcon-{name}.png", "idiom": "universal", "platform": "ios",
                       "size": "1024x1024"})
    return {"images": images, "info": {"author": "xcode", "version": 1}}


def mark_contents() -> dict:
    images = [{"idiom": "universal", "scale": "1x"}]
    images += [{"filename": f"EarwigMark@{factor}x.png", "idiom": "universal", "scale": f"{factor}x"} for factor in (2, 3)]
    return {"images": images, "info": {"author": "xcode", "version": 1}}


def path_segments(d: str) -> list[tuple]:
    """An SVG path of absolute M, L, C, H, V and Z commands as segments: ("move", x, y),
    ("line", x, y), ("curve", c1x, c1y, c2x, c2y, x, y) and ("close",)."""
    tokens = re.findall(r"[MLCHVZ]|-?\d+(?:\.\d+)?", d)
    segments, x, y, i = [], 0.0, 0.0, 0
    while i < len(tokens):
        command = tokens[i]
        i += 1
        if command == "Z":
            segments.append(("close",))
            continue
        count = {"M": 2, "L": 2, "C": 6, "H": 1, "V": 1}[command]
        values = [float(t) for t in tokens[i:i + count]]
        i += count
        if command == "H":
            x = values[0]
            segments.append(("line", x, y))
        elif command == "V":
            y = values[0]
            segments.append(("line", x, y))
        else:
            x, y = values[-2], values[-1]
            segments.append(("move" if command == "M" else "line" if command == "L" else "curve", *values))
    return segments


def swift_number(value: float) -> str:
    return f"{value:g}"


def swift_segments(d: str) -> str:
    parts = []
    for kind, *values in path_segments(d):
        if kind == "close":
            parts.append(".close")
        elif kind == "curve":
            c1x, c1y, c2x, c2y, x, y = map(swift_number, values)
            parts.append(f".curve(to: CGPoint(x: {x}, y: {y}), control1: CGPoint(x: {c1x}, y: {c1y}), control2: CGPoint(x: {c2x}, y: {c2y}))")
        else:
            x, y = map(swift_number, values)
            parts.append(f".{kind}(CGPoint(x: {x}, y: {y}))")
    return "[" + ", ".join(parts) + "]"


def swift_limb(d: str, width: float) -> str:
    return f"Limb(segments: {swift_segments(d)}, width: {swift_number(width)})"


def swift_geometry() -> str:
    """The mark's geometry as Swift, for the earwig that walks across the screen (plan 014,
    decision 1): the insect upright in the 1024 box, the left side's limbs only (the right side
    is their mirror about x 512), each limb pivoting on its first point."""
    cx, cy, rx, ry = HEAD
    px, py, pw, ph, pr = PRONOTUM
    wx, wy, ww, wh, wr = WING_CASES
    cut_limbs = [f"Limb(segments: [.move(CGPoint(x: {swift_number(x1)}, y: {swift_number(y1)})), "
                 f".line(CGPoint(x: {swift_number(x2)}, y: {swift_number(y2)}))], width: {swift_number(width)})"
                 for (x1, y1), (x2, y2), width in cuts()]
    antenna_tip = path_segments(ANTENNA[0])[-1][-1]
    forceps_tip = path_segments(FORCEPS[0])[-1][-1]
    top, bottom = antenna_tip - ANTENNA[1] / 2, forceps_tip + FORCEPS[1] / 2
    legs = ",\n            ".join(swift_limb(d, w) for d, w in LEGS)
    cut_list = ",\n            ".join(cut_limbs)
    return f"""// Generated by scripts/app_icon/make_app_icon.py from the mark's geometry (plan 014,
// decision 1). Do not edit: change the script and run it again.

import CoreGraphics

extension Critter {{
    /// The mark upright in its 1024 box, head up, before the icon's turn: the body, the cuts that
    /// separate its parts, and the left side's limbs, each pivoting on its first point. The right
    /// side is the left mirrored about x 512.
    enum Geometry {{
        static let box: CGFloat = {SIZE}
        /// The middle of the insect from its antennae's tips to its forceps' tips, and that length.
        static let centre = CGPoint(x: {SIZE // 2}, y: {swift_number((top + bottom) / 2)})
        static let length: CGFloat = {swift_number(bottom - top)}

        static let head = CGRect(x: {cx - rx}, y: {cy - ry}, width: {2 * rx}, height: {2 * ry})
        static let pronotum = Plate(rect: CGRect(x: {px}, y: {py}, width: {pw}, height: {ph}), radius: {pr})
        static let wingCases = Plate(rect: CGRect(x: {wx}, y: {wy}, width: {ww}, height: {wh}), radius: {wr})
        static let abdomen: [Segment] = {swift_segments(ABDOMEN)}
        /// The three cuts across the abdomen and the split between the wing cases, cut out of the body.
        static let cuts: [Limb] = [
            {cut_list}
        ]

        static let antenna = {swift_limb(*ANTENNA)}
        /// Front, middle and back.
        static let legs: [Limb] = [
            {legs}
        ]
        static let forceps = {swift_limb(*FORCEPS)}
    }}
}}
"""


def main() -> None:
    ICON_SET.mkdir(parents=True, exist_ok=True)
    MARK_SET.mkdir(parents=True, exist_ok=True)
    for name, palette in PALETTES.items():
        svg_path = SCRIPT_DIR / f"AppIcon-{name}.svg"
        png_path = ICON_SET / f"AppIcon-{name}.png"
        svg_path.write_text(svg(palette))
        opaque = palette["ground"] is not None
        render(svg_path, png_path, SIZE, transparent=not opaque)
        check(png_path, SIZE, opaque)
        print(f"wrote {svg_path.relative_to(REPO)} and {png_path.relative_to(REPO)}")
    write_json(ICON_SET / "Contents.json", icon_contents())

    mark_svg = SCRIPT_DIR / "EarwigMark.svg"
    mark_svg.write_text(svg(MARK))
    for factor in (2, 3):
        png_path = MARK_SET / f"EarwigMark@{factor}x.png"
        render(mark_svg, png_path, MARK_POINTS * factor, transparent=True)
        check(png_path, MARK_POINTS * factor, opaque=False)
        print(f"wrote {png_path.relative_to(REPO)}")
    write_json(MARK_SET / "Contents.json", mark_contents())

    # The tinted icon is the insect alone on nothing, so its alpha is the insect's footprint.
    margin = corner_margin(ICON_SET / "AppIcon-tinted.png")
    assert margin > 0, f"the insect is clipped by the tile's corners ({margin:.0f} pt outside)"
    print(f"the insect clears the tile's rounded corners by {margin:.0f} pt of 1024")

    GEOMETRY.parent.mkdir(parents=True, exist_ok=True)
    GEOMETRY.write_text(swift_geometry())
    print(f"wrote {GEOMETRY.relative_to(REPO)}")


if __name__ == "__main__":
    main()
