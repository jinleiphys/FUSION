# FUSION visual identity

The visual idea is literal: **two nuclei meeting.**

FUSION takes its name from the reaction. The product connects an agent to the
nuclear-physics codes it drives, and the mark shows the two sides at contact.
New brand work should keep that image instead of adding a second metaphor.

## The mark

```
▸◂
```

The two accent colours make the shapes read as separate nuclei, rather than a
single arrow pair. The mark uses ordinary text characters, so it remains
legible in a terminal, a README, a browser tab, and at 16 pixels.

## Palette

The website used this palette first. Add a colour here before using it on a new
surface; otherwise the definitions will drift.

| Token | Hex | Role |
|---|---|---|
| `void` | `#05080f` | the deepest background, the chamber before the beam |
| `chamber` | `#0a101d` | panels, cards |
| `chamber-2` | `#0d1524` | raised elements |
| `ink` | `#e9eef8` | primary text |
| `dim` | `#8fa0b8` | secondary text |
| `faint` | `#5b6a80` | captions, disabled |
| **`plasma`** | **`#52b7ff`** | **first accent.** Links, primary actions, the left nucleus |
| **`core`** | **`#ffa028`** | **second accent.** Highlights, the right nucleus |
| `hairline` | `rgba(140,170,215,.13)` | dividers |

Use plasma blue and core orange as a pair. A one-accent treatment loses the
image of two bodies meeting and no longer reads as FUSION.

## Type

- Display: Avenir Next, Futura, Helvetica Neue, PingFang SC, Noto Sans SC
- Body: system UI stack, with PingFang SC and Noto Sans SC for Chinese
- Mono: SF Mono, Menlo, Consolas

Support Chinese and English wherever the surface permits. The site already
carries both in parallel spans. The documentation does not yet cover both
languages throughout.

## Where it is applied

**Terminal (fusion-core, `packages/tui/src/logo.ts`).** The wordmark splits
FU | SION, rendered in the two accent colours, with `▸◂` straddling the seam:
the accent triangle is the last cell of the left array, the foreground one the
first cell of the right. Two differently coloured nuclei meeting exactly where
the two halves of the name join.

The brand fork touches only this file and the rebase workflow. Colour comes
from the theme, so the logo file contains no colour values.

**Terminal colours (`data/fusion-theme.json`).** An opencode theme carrying the
palette above, installed by `scripts/fusion_init.py` into
`<config>/themes/fusion.json`, which opencode reads and ranks above its
built-ins. It lives in the customization layer, so the terminal matches the
website without a single line of forked code.

The file follows an opencode theme key for key, with only the colour values
changed, and every referenced definition exists. **Rendering in the TUI has not
been verified**, because that check needs an interactive terminal. A
non-interactive run also accepts a deliberately invalid theme name and exits 0,
so it cannot validate the theme.

**Web (fusion-web).** The palette above is already its `:root`. The mark should
appear as the favicon and at section eyebrows.

**GitHub (this repository).** The banner in `assets/brand/`, and the mark in
prose where a visual break helps.

## Rules

1. **Two colours, always as a pair.** One alone is not the brand.
2. **The mark is text.** If a surface cannot render `▸◂`, it does not get a
   fallback image, it gets nothing. A brand that needs an image to exist does
   not work in a terminal.
3. **Dark first.** Every surface is designed against `void`. Light variants are
   a port, not the origin.
4. **No new colours without editing this file.** Keep the palette in one place.
5. **No em-dashes**, in any generated text, Chinese or English.
