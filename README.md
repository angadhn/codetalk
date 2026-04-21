# codetalk

Pin source files alongside markdown prose. As the reader scrolls, the code
pane spotlights the lines being discussed. Useful for walking humans (or AI
agents) through a codebase one region at a time.

A Jekyll plugin plus a small standalone demo build. Drop it into a static
site, or use this repo as a template for standalone annotated code pages.

## Quick preview

`index.html` is checked in pre-built. Open it in a browser:

```
open index.html
```

Because the code, CSS, and JS are inlined into a single file, it works on
`file://` — no local server required.

## Regenerate the standalone demo

```
bundle install
bundle exec ruby build.rb
```

`build.rb` reads `codetalk-1.md`, syntax-highlights the referenced source
files with Rouge, runs the same HTML transform the Jekyll plugin uses, and
writes a self-contained `index.html`.

## Install into a Jekyll site

1. Copy `codetalk.rb` into your site's `_plugins/` directory.
2. Copy `_codetalk.scss` into `_sass/` and add `@import "codetalk";` to your
   main stylesheet.
3. Copy `codetalk.js` into `assets/js/`. The plugin injects its own
   `<script>` tag before `</body>` at render time — no layout edit needed.
4. Create `_code/` at your site root and put source files inside. Paths in
   front matter are resolved relative to `_code/`; a basename with no slash
   is auto-located via a single recursive index.
5. Add the `rouge` gem to your `Gemfile` (the plugin uses it for highlighting).
6. Add `scripts:` to any page's front matter and write `## <filename>` +
   `### Lines N-M` sections in the body. The plugin works with any layout —
   it triggers on the presence of `scripts:`, not on a `layout:` value.

## Authoring syntax

Front matter lists the files to pin:

```yaml
---
title: "Mapping the Spaceship Design Space"
scripts:
  - file: codetalk-1/spaceship-region.py
    label: spaceship-region.py
  - file: codetalk-1/plot-config.yaml
    label: plot-config.yaml
---
```

In the body, each `## <label>` starts a file section. Each `### Lines N` or
`### Lines N-M` inside a section becomes a step: when any of those lines are
visible in the code pane, that step's prose is spotlighted.

```markdown
## spaceship-region.py

Prose above the first step is the preamble — shown before the codetalk grid.

### Lines 7-15

Annotation for lines 7 through 15. This prose floats into view when the
reader scrolls the code pane so lines 7–15 are showing.

### Lines 77-78

Second step, just two lines.
```

A blank line between two paragraphs inside a step is a normal paragraph
break. **Two** consecutive blank lines inside a step mark where the
annotation ends and normal body text resumes:

```markdown
### Lines 102-107

This is the annotation for lines 102–107.


This paragraph is no longer part of the step — it rejoins the regular body
text after the codetalk block.
```

## Other static-site generators

The HTML transform lives in Ruby because the Jekyll plugin runs it at render
time. Ports to Hugo, 11ty, Astro, etc. would need the transform
reimplemented in the host language — PRs welcome. `codetalk.rb` factors the
logic into a plain `Codetalk` module with no Jekyll dependency, so `build.rb`
is a reasonable reference for what a port has to do.

## Files in this repo

| File | Role |
|---|---|
| `codetalk.rb` | `Codetalk` transform module + Jekyll plugin registration |
| `codetalk.js` | Scroll spotlight, tab switching, spotlight-on-page-enter |
| `_codetalk.scss` | Styles — import into your site's SCSS |
| `build.rb` | Standalone demo builder (no Jekyll needed) |
| `codetalk-1.md` | Sample annotation page |
| `_code/codetalk-1/` | Source files referenced by the sample |
| `index.html` | Pre-built standalone demo |
| `Gemfile` | `rouge`, `kramdown`, `sass-embedded` |

## License

MIT — see `LICENSE`.
