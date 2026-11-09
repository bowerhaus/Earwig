"""Draws the README's banner and its following diagram (plan 011, decisions 9 and 10).

Each is an HTML page rendered to PNG by headless Chrome at twice its CSS size, the way
scripts/app_icon/make_app_icon.py renders the icon, so it looks the same in every browser and
can be rebuilt. The colours are the app's (`EarwigTheme`).

    uv run --with pillow scripts/readme/make_readme_images.py

Outputs: docs/banner.png (1280 x 640 CSS pixels, also the repo's social preview) and
docs/diagrams/following.png. The banner's screenshots come from docs/screenshots/.
"""

import html
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent.parent
DOCS = ROOT / "docs"
SHOTS = DOCS / "screenshots"
MARK = ROOT / "Earwig/Resources/Assets.xcassets/EarwigMark.imageset/EarwigMark@3x.png"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

SKY = "#5CB8F3"
SURFACE = "#2B82CC"
TEXT = "#FFFFFF"
SECONDARY = "#D2E7F8"
ACCENT = "#FFD24A"
CUE = "#FFD3AE"
FAINT = "rgba(255,255,255,0.45)"
FONT = "'SF Pro Rounded', ui-rounded, -apple-system, 'Helvetica Neue', sans-serif"

# The banner's three screenshots, left to right, the take in front; the Script screen comes from the phone.
BANNER_SHOTS = ["scripts.png", "screen-take.png", "script.png"]
STAND_IN = "finished.png"


def render(page: str, out: Path, width: int, height: int, transparent: bool = False) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "page.html"
        path.write_text(page)
        subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=2",
                        f"--window-size={width},{height}", f"--screenshot={out}", "--allow-file-access-from-files",
                        *(["--default-background-color=00000000"] if transparent else []),
                        path.as_uri()], check=True, capture_output=True)
    with Image.open(out) as image:
        assert image.size == (width * 2, height * 2), f"{out.name} is {image.size}"
        # The diagram's rounded panel keeps its transparent corners on GitHub's light and dark pages.
        (image.convert("RGBA") if transparent else image.convert("RGB")).save(out, optimize=True)
    print(f"wrote {out.relative_to(ROOT)}")


def banner() -> None:
    shots = []
    for name in BANNER_SHOTS:
        path = SHOTS / name
        if not path.exists():
            print(f"note: {name} is missing; {STAND_IN} stands in until it is taken")
            path = SHOTS / STAND_IN
        shots.append(path.as_uri())
    left, middle, right = shots
    page = f"""<!doctype html><html><head><meta charset="utf-8"><style>
    html, body {{ margin: 0; width: 1280px; height: 640px; overflow: hidden; background: {SKY}; font-family: {FONT}; }}
    .words {{ position: absolute; left: 76px; top: 150px; width: 470px; color: {TEXT}; }}
    .mark {{ width: 132px; height: 132px; display: block; margin-left: -10px; }}
    h1 {{ margin: 12px 0 18px; font-size: 92px; font-weight: 700; letter-spacing: -1px; line-height: 1; }}
    p {{ margin: 0; font-size: 29px; line-height: 1.3; color: {SECONDARY}; font-weight: 500; }}
    p b {{ color: {ACCENT}; font-weight: 600; }}
    .phone {{ position: absolute; width: 236px; border-radius: 34px; border: 5px solid {SURFACE};
             box-shadow: 0 24px 50px rgba(14, 60, 110, 0.35); }}
    .a {{ left: 560px; top: 96px; transform: rotate(-4deg); }}
    .b {{ left: 780px; top: 56px; z-index: 2; width: 252px; }}
    .c {{ left: 1000px; top: 100px; transform: rotate(4deg); }}
    </style></head><body>
    <div class="words">
      <img class="mark" src="{MARK.as_uri()}">
      <h1>Earwig</h1>
      <p>Your script in one earpiece, <b>a few words ahead</b>. It follows what you actually say.</p>
    </div>
    <img class="phone a" src="{left}"><img class="phone b" src="{middle}"><img class="phone c" src="{right}">
    </body></html>"""
    render(page, DOCS / "banner.png", 1280, 640)


# The following diagram: one line of the Harbour Walk at three moments.
WORDS = "We're starting at the old harbour, just as the tide turns. The plan is simple:".split()
PHRASE_END = 10  # the index of "turns.", the end of the first phrase

MOMENTS = [
    {
        "title": "Reading along",
        "heard": 2, "you": 2, "voice": 7, "voice_label": "voice",
        "caption": "The voice runs a set lead ahead of you, five words by default, and keeps pace as you speed up or slow down.",
    },
    {
        "title": "You pause",
        "heard": 5, "you": 5, "voice": PHRASE_END, "voice_label": "waits",
        "caption": "The voice reaches the end of the phrase and waits there. As you come to the end, it gives you the next one.",
    },
    {
        "title": "You go off script",
        "heard": PHRASE_END + 1, "you": None, "voice": PHRASE_END, "voice_label": "holds",
        "caption": "Talk off script after a phrase and the voice holds. Say a line of the script and it picks you up from there.",
    },
]


def moment(m: dict) -> str:
    spans = []
    for index, word in enumerate(WORDS):
        classes = ["w"]
        if index < m["heard"]:
            classes.append("heard")
        if index == m["you"]:
            classes.append("you")
        marks = ""
        if index == m["voice"]:
            marks += f'<span class="tag voice">{m["voice_label"]}</span>'
        if index == m["you"]:
            marks += '<span class="tag me">you</span>'
        spans.append(f'<span class="{" ".join(classes)}">{marks}{html.escape(word)}</span>')
        if index == PHRASE_END:
            off = '<span class="off">(off script)</span><span class="tag me">you</span>' if m["you"] is None else ""
            spans.append(f'<span class="gate">{off}</span>')
    return f"""<div class="moment"><div class="title">{m["title"]}</div>
    <div class="line">{"".join(spans)}</div><div class="caption">{m["caption"]}</div></div>"""


def following() -> None:
    page = f"""<!doctype html><html><head><meta charset="utf-8"><style>
    html, body {{ margin: 0; width: 1200px; height: 694px; overflow: hidden; background: transparent; font-family: {FONT}; }}
    .panel {{ margin: 0; height: 694px; box-sizing: border-box; padding: 34px 40px; background: {SKY}; border-radius: 28px; }}
    .moment {{ background: {SURFACE}; border-radius: 22px; padding: 18px 26px 18px; margin-bottom: 20px; }}
    .moment:last-child {{ margin-bottom: 0; }}
    .title {{ color: {ACCENT}; font-weight: 700; font-size: 20px; letter-spacing: 0.5px; text-transform: uppercase; }}
    .line {{ display: flex; align-items: flex-end; gap: 9px; height: 100px; padding-bottom: 8px; }}
    .w {{ position: relative; color: {TEXT}; font-size: 28px; font-weight: 600; line-height: 1; }}
    .w.heard {{ color: {FAINT}; }}
    .w.you {{ color: {TEXT}; text-decoration: underline 4px {TEXT}; text-underline-offset: 7px; }}
    .gate {{ position: relative; flex: 0 0 5px; align-self: stretch; margin: 26px 10px 0; background: {CUE}; border-radius: 3px; }}
    .gate::after {{ content: 'phrase end'; position: absolute; top: -24px; left: 50%; transform: translateX(-50%); color: {CUE}; font-size: 14px; font-weight: 600; white-space: nowrap; }}
    .tag {{ position: absolute; left: 50%; transform: translateX(-50%); bottom: 40px; padding: 3px 12px; border-radius: 999px;
            font-size: 17px; font-weight: 700; white-space: nowrap; }}
    .tag.voice {{ background: {ACCENT}; color: {SURFACE}; }}
    .tag.me {{ background: {TEXT}; color: {SURFACE}; }}
    .gate .tag.me {{ bottom: 36px; left: 14px; transform: none; }}
    .off {{ position: absolute; left: 76px; bottom: 38px; color: {CUE}; font-size: 19px; font-style: italic; white-space: nowrap; }}
        .caption {{ color: {SECONDARY}; font-size: 20px; line-height: 1.35; font-weight: 500; }}
    </style></head><body><div class="panel">{"".join(moment(m) for m in MOMENTS)}</div></body></html>"""
    render(page, DOCS / "diagrams/following.png", 1200, 694, transparent=True)


if __name__ == "__main__":
    banner()
    following()
