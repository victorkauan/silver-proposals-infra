# TCC presentation

The HTML presentation of the TCC (in Brazilian Portuguese). It is one self-contained file,
[`silver-proposals-tcc.html`](silver-proposals-tcc.html), with no runtime dependencies: open it in a browser.

## Build

```bash
python3 docs/apresentacao/build.py
```

`build.py` joins `src/` (styles, scripts, and the OFL fonts in `src/fonts/`, embedded as base64) into the HTML file.
Edit `src/` and run the build; never edit the generated file. The build is reproducible: the same sources produce
the same bytes.

| File | Role |
|---|---|
| `src/engine.js` | Stage, navigation, and steps |
| `src/kit.js` | Drawing and animation helpers (diagrams, tokens, counters) |
| `src/slides-*.js` | One file per act; each slide declares its steps |
| `src/base.css`, `src/slides.css` | Themes, stage, and per-slide styles |

Each slide has steps `{ dur, draw(p, ctx) }`, where `p` goes from 0 to 1. Drawing is a pure function of `p`, so the
engine can play, finish, or undo any step. Elements with `data-at="k"` appear from step `k` on.

## Presenting

| Key | Action |
|---|---|
| → space PageDown, click | next step |
| ← PageUp | previous step |
| ↓ ↑ | next or previous slide |
| number + Enter | go to a slide |
| G | slide index |
| R | replay the slide |
| T | light or dark theme |
| F | full screen |
| B | black screen |
| ? | shortcuts |

## Modes

| Query | Effect |
|---|---|
| `?print` | every slide in its final state, one per page, for PDF export |
| `?instant` | no animation |
| `?instant&at=0.5#5.2` | slide 5, step 2, drawn at 50% (for debugging an animation) |
| `?theme=light` | start in the light theme |

## PDF

Open `silver-proposals-tcc.html?print` in Chrome or Edge, print, choose **Save as PDF**, and set margins to
**None** with **Background graphics** on. The page size is 1920×1080.

## Fonts

Newsreader, Libre Franklin, and JetBrains Mono, from the Fontsource packages (5.3.0), under the SIL Open Font
License 1.1. The license of each family is in `src/fonts/`.
