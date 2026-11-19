# Builds the single-file presentation from src/: python3 docs/apresentacao/build.py
# The output is committed; edit src/, never the generated HTML.

import base64
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"
OUT = ROOT / "silver-proposals-tcc.html"

FONTS = [
    ("Newsreader", "normal", 400, "newsreader-latin-400-normal.woff2"),
    ("Newsreader", "italic", 400, "newsreader-latin-400-italic.woff2"),
    ("Newsreader", "normal", 500, "newsreader-latin-500-normal.woff2"),
    ("Newsreader", "italic", 500, "newsreader-latin-500-italic.woff2"),
    ("Libre Franklin", "normal", 400, "libre-franklin-latin-400-normal.woff2"),
    ("Libre Franklin", "normal", 500, "libre-franklin-latin-500-normal.woff2"),
    ("Libre Franklin", "normal", 600, "libre-franklin-latin-600-normal.woff2"),
    ("Libre Franklin", "normal", 800, "libre-franklin-latin-800-normal.woff2"),
    ("JetBrains Mono", "normal", 500, "jetbrains-mono-latin-500-normal.woff2"),
    ("JetBrains Mono", "normal", 600, "jetbrains-mono-latin-600-normal.woff2"),
    ("JetBrains Mono", "normal", 700, "jetbrains-mono-latin-700-normal.woff2"),
]
STYLES = ["base.css", "slides.css"]
SCRIPTS = ["kit.js", "slides-a.js", "slides-b.js", "slides-c.js", "slides-d.js", "engine.js"]


def font_faces() -> str:
    rules = ["/* Fontes OFL embutidas no build (Newsreader, Libre Franklin, JetBrains Mono; licenças em src/fonts/). */"]
    for family, style, weight, file in FONTS:
        data = base64.b64encode((SRC / "fonts" / file).read_bytes()).decode()
        rules.append(
            f'@font-face {{ font-family: "{family}"; font-style: {style}; font-weight: {weight}; '
            f"font-display: block; src: url(data:font/woff2;base64,{data}) format(\"woff2\"); }}"
        )
    return "\n".join(rules)


def main() -> None:
    template = (SRC / "index.html").read_text(encoding="utf-8")
    styles = "\n".join(f"<style>\n{(SRC / name).read_text(encoding='utf-8')}</style>" for name in STYLES)
    scripts = "\n".join(f"<script>\n{(SRC / name).read_text(encoding='utf-8')}</script>" for name in SCRIPTS)
    html = (
        template.replace("<!-- FONTS -->", f"<style>\n{font_faces()}\n</style>")
        .replace("<!-- STYLES -->", styles)
        .replace("<!-- SCRIPTS -->", scripts)
    )
    OUT.write_text(html, encoding="utf-8")
    print(f"{OUT.name}: {len(html.encode()) / 1024:.0f} KB")


if __name__ == "__main__":
    main()
