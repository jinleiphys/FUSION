# FUSION visual identity

One idea, applied everywhere: **two nuclei meeting.**

The name is a nuclear process, the product joins two things that were separate
(an agent and the codes a physicist actually runs), and the mark is the moment
of contact. Every surface below is that same sentence said in a different
medium. If a new surface cannot be derived from it, the surface is wrong, not
the idea.

## The mark

```
▸◂
```

Two bodies converging, drawn in the two accent colours so they read as
different nuclei rather than a single arrow pair. It is deliberately not a
glyph that needs a font: it survives in a terminal, in a README, in a browser
tab, and at 16 pixels.

## Palette

Taken from the website, which had it first. Do not invent new colours; if a
surface needs one that is not here, argue for adding it here first.

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

**The two accents are the identity.** Plasma blue and core orange, used as a
pair, are what makes a FUSION surface recognisable. A surface that uses only
one of them is missing the point: the brand is the collision, not either
colour.

## Type

- Display: Avenir Next, Futura, Helvetica Neue, PingFang SC, Noto Sans SC
- Body: system UI stack, with PingFang SC and Noto Sans SC for Chinese
- Mono: SF Mono, Menlo, Consolas

Chinese and English are first-class on every surface. The site carries both in
parallel spans; documentation currently does not, which is a gap and not a
decision.

## Where it is applied

**Terminal (fusion-core, `packages/tui/src/logo.ts`).** The wordmark splits
FU | SION, rendered in the two accent colours, with `▸◂` straddling the seam:
the accent triangle is the last cell of the left array, the foreground one the
first cell of the right. Two differently coloured nuclei meeting exactly where
the two halves of the name join.

This is the only file the brand fork touches besides the rebase workflow, and
it must stay that way. Colour comes from the theme, not from the logo, which is
why the logo file carries no colour values at all.

**Terminal colours (`data/fusion-theme.json`).** An opencode theme carrying the
palette above, installed by `scripts/fusion_init.py` into
`<config>/themes/fusion.json`, which opencode reads and ranks above its
built-ins. It lives in the customization layer, so the terminal matches the
website without a single line of forked code.

*Verification status, stated rather than implied:* the file is derived from a
theme shipped with opencode, key for key, with only colour values replaced, and
every definition it references exists. **The TUI actually rendering it has not
been verified**, because that needs an interactive terminal. A check that ran
`opencode` with a deliberately invalid theme name and watched it exit 0 proved
that non-interactive commands do not validate the theme at all, so passing one
is not evidence.

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
4. **No new colours without editing this file.** The drift this project has
   already had to repair, twice in one day, came from two places holding the
   same information.
5. **No em-dashes**, in any generated text, Chinese or English.
