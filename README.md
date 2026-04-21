# codetalk

Pin source files alongside markdown prose. As the reader scrolls, the code
pane spotlights the lines being discussed. Useful for walking humans (or AI
agents) through a codebase one region at a time.

A Jekyll plugin plus a small standalone demo build. Drop it into a static
site, or use this repo as a template for standalone annotated code pages.

## Quickstart (standalone, no Jekyll)

See a working example in under a minute:

```bash
git clone https://github.com/angadhn/codetalk.git
cd codetalk
open index.html          # macOS; on Linux use xdg-open, on Windows: start index.html
```

`index.html` is committed pre-built with source code, CSS, and JS all
inlined, so it works from `file://` — no server required.

Then make your own:

1. **Add a source file.** Drop any file you want to annotate into `_code/`,
   e.g. `_code/myproject/server.py`.
2. **Copy `codetalk-1.md` to `myproject.md`** and edit the front matter to
   point at your file, then rewrite the prose — `## <filename>` starts a file
   section; `### Lines N-M` starts a step.

   ```yaml
   ---
   title: "My walkthrough"
   scripts:
     - file: myproject/server.py
       label: server.py
   ---

   ## server.py

   A paragraph above the first `### Lines` heading becomes the preamble —
   regular body text shown above the codetalk grid.

   ### Lines 10-25

   This prose is spotlighted when lines 10–25 are visible in the code pane.

   ### Lines 40-55

   Second step.
   ```

3. **Build.** `build.rb` takes the source markdown as its first argument and
   writes a matching `.html` beside it:

   ```bash
   bundle install                         # one-time; pulls rouge, kramdown, sass-embedded
   bundle exec ruby build.rb myproject.md # writes myproject.html
   open myproject.html
   ```

   With no arguments it rebuilds the sample: `codetalk-1.md` → `index.html`.

### Edit / rebuild loop

Once the initial build works, the inner loop is two commands:

```bash
# edit any of:
#   myproject.md            ← the prose and line ranges
#   _code/myproject/*.py    ← the source being annotated
bundle exec ruby build.rb myproject.md
# then refresh the browser (Cmd-R / Ctrl-R)
```

Nothing is cached — `build.rb` re-reads the markdown, re-highlights every
source file, recompiles the SCSS, and writes a fresh HTML file each run. A
rebuild on the sample takes well under a second.

### Authoring syntax cheat sheet

- **`scripts:` front matter** — list of files to pin. Paths are resolved
  relative to `_code/`. A bare basename (no slash) is auto-located by a
  recursive walk of `_code/`.
- **`## <label>`** (h2) — starts a file section. The label must match the
  `label` field in front matter.
- **`### Lines N`** or **`### Lines N-M`** (h3) — starts a step. The range
  drives the scroll spotlight.
- **Preamble** — any prose before the first `### Lines` inside a file
  section. Rendered above the codetalk grid in normal body text.
- **Two blank lines inside a step** — end of annotation, the rest is normal
  body text that resumes after the codetalk block. One blank line = normal
  paragraph break inside the step.
- **Multiple `## <label>` sections back-to-back** — grouped into a single
  codetalk block with tabs. A non-matching h2 or any h1 between them breaks
  the group, which starts a new codetalk block.

## Install into a Jekyll site

The plugin is layout-agnostic: any page or document with `scripts:` in its
front matter gets the codetalk transform, regardless of the `layout:` value.
You do not need to create a dedicated layout.

### One-time setup

1. **Copy the engine files:**

   ```bash
   cp codetalk.rb   <your-site>/_plugins/
   cp codetalk.js   <your-site>/assets/js/
   cp _codetalk.scss <your-site>/_sass/
   ```

2. **Import the SCSS** from your main stylesheet (e.g. `assets/css/main.scss`
   or wherever you `@import` partials):

   ```scss
   @import "codetalk";
   ```

3. **Add `rouge` to your `Gemfile`** (if your theme doesn't already depend on
   it) and `bundle install`:

   ```ruby
   gem 'rouge', '~> 4.0'
   ```

4. **Create the `_code/` directory** at your site root. Source files live
   here. Jekyll ignores directories starting with `_` by default, so these
   files don't get copied verbatim to `_site/` — the plugin reads them at
   build time instead.

That's the install. No layout edits, no `<script>` tags, no `<link>` tags —
the plugin injects `/assets/js/codetalk.js` automatically before `</body>`
on any page that has a codetalk on it.

### Write a codetalk page

Any page or collection document with a `scripts:` key and matching `##`
sections in the body will be transformed. The plugin does not care about the
layout, permalink, or collection. Example:

```markdown
---
title: "My walkthrough"
layout: default         # or post, note, whatever your theme uses
scripts:
  - file: myproject/server.py
    label: server.py
  - file: myproject/config.yaml
    label: config.yaml
---

## server.py

### Lines 10-25

...prose...

## config.yaml

### Lines 1-8

...prose...
```

When Jekyll builds, the two `##` sections above become a two-tab codetalk
block with the source files highlighted by Rouge.

### Dark-theme hosts

The SCSS ships with a `[data-theme="dark"]` block for prose colours. If your
site toggles dark mode via that attribute on `<html>` or `<body>`, it will
"just work." If your site uses a different dark-mode mechanism (class,
media query), override the relevant selectors in your own SCSS.

### Common gotchas

- **`## <label>` must match the `label:` in front matter exactly.** Mismatched
  labels simply don't trigger the transform — the `##` renders as a normal
  heading.
- **Nothing highlights in the preamble.** The preamble is prose that sits
  above the grid; the scroll spotlight only applies to `### Lines` steps.
- **The grid is 140% wide and extends right by default.** This fits a Tufte-
  style narrow-column layout where the body column is ~55% of the viewport.
  If your theme has a full-width content column, tweak the `.codetalk`
  `width` / `margin-right` rules in your site's SCSS.

## How it works

1. **Generator phase** (`Codetalk::CodetalkGenerator` in `codetalk.rb`)
   - Walks pages + collection documents, picks any with `scripts:` set.
   - Preprocesses markdown to convert double-blank-line break markers into a
     `<div class="codetalk-body-break">` sentinel.
   - Reads each referenced source file, syntax-highlights it with Rouge, and
     splits the result into per-line strings with spans re-opened at line
     boundaries so each line is valid standalone HTML.
2. **Post-render hook**
   - Scans the rendered page HTML for `<h2>` tags that match a file label.
   - Groups consecutive matching h2s into a single codetalk block (a
     non-matching h2 or any h1 breaks the group).
   - For each group, rewrites the HTML: file tabs → code panes with
     pre-highlighted lines → prose column with `<div class="codetalk__step">`
     wrappers carrying `data-start` / `data-end`.
   - Converts sidenotes inside steps into footnotes (sidenotes don't fit in
     the narrow prose column).
   - Injects a `<script src="/assets/js/codetalk.js">` before `</body>`.
3. **Client-side** (`codetalk.js`)
   - On scroll, finds the first annotation whose line range intersects the
     visible portion of the code pane. That step's prose is spotlighted;
     all others fade. When the whole codetalk is fully in view, it also dims
     sibling page elements so the reader's attention stays in the block.

## Other static-site generators

Jekyll only, for now. The transform lives in Ruby because Jekyll runs it as
a `:post_render` hook. Ports to Hugo, 11ty, Astro, etc. would need the
transform reimplemented in the host language — PRs welcome. `codetalk.rb`
factors the logic into a plain `Codetalk` module with no Jekyll dependency,
and `build.rb` is a working reference for what a port has to do.

## Files in this repo

| File | Role |
|---|---|
| `codetalk.rb` | `Codetalk` transform module + Jekyll plugin registration |
| `codetalk.js` | Scroll spotlight, tab switching, page-level dimming |
| `_codetalk.scss` | Styles — import into your site's SCSS |
| `build.rb` | Standalone demo builder (no Jekyll needed) |
| `codetalk-1.md` | Sample annotation page |
| `_code/codetalk-1/` | Source files referenced by the sample |
| `index.html` | Pre-built standalone demo (check this in so forkers can open it directly) |
| `Gemfile` | `rouge`, `kramdown`, `kramdown-parser-gfm`, `sass-embedded` |

## License

MIT — see `LICENSE`.
