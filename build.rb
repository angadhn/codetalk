# frozen_string_literal: true

# build.rb — render codetalk-1.md into a self-contained index.html.
#
# Reuses the Codetalk module from codetalk.rb so the standalone demo and
# the Jekyll plugin produce identical output. Dependencies declared in
# Gemfile; run via `bundle exec ruby build.rb`.

require 'bundler/setup'
require 'yaml'
require 'kramdown'
require 'kramdown-parser-gfm'
require 'rouge'
require 'sass-embedded'

require_relative 'codetalk'

ROOT        = __dir__
SOURCE_MD   = File.join(ROOT, 'codetalk-1.md')
CODE_DIR    = File.join(ROOT, '_code')
SCSS_PATH   = File.join(ROOT, '_codetalk.scss')
JS_PATH     = File.join(ROOT, 'codetalk.js')
OUTPUT_HTML = File.join(ROOT, 'index.html')

abort("Missing source markdown: #{SOURCE_MD}") unless File.exist?(SOURCE_MD)

# ── 1. Parse front matter + body ───────────────────────────────────

raw = File.read(SOURCE_MD)
front_matter, body = if raw =~ /\A---\s*\n(.*?)\n---\s*\n(.*)\z/m
                       [YAML.safe_load(Regexp.last_match(1)), Regexp.last_match(2)]
                     else
                       [{}, raw]
                     end

title = front_matter['title'] || 'Codetalk'

# ── 2. Preprocess markdown (double-blank-line break markers) ───────

processed_md = Codetalk.preprocess_markdown(body)

# ── 3. Load sources + syntax-highlight ─────────────────────────────

code_index = Codetalk.build_code_index(CODE_DIR)
scripts    = Codetalk.normalize_scripts(front_matter['scripts'], code_index)
sources    = Codetalk.load_sources(scripts, CODE_DIR)

# ── 4. Render markdown → HTML ──────────────────────────────────────

rendered = Kramdown::Document.new(
  processed_md,
  input: 'GFM',
  hard_wrap: false,
  syntax_highlighter: nil
).to_html

# ── 5. Compile SCSS → CSS ──────────────────────────────────────────

compiled_css = Sass.compile(SCSS_PATH, style: :compressed).css

# Tufte-ish base styles so the standalone page renders on its own.
# The codetalk grid expects a narrow-ish container it can extend rightward
# out of via width:140%; margin-right:-40%.
base_css = <<~CSS
  *, *::before, *::after { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; }
  body {
    font-family: 'et-book', 'Palatino', 'Palatino Linotype', 'Palatino LT STD',
                 'Book Antiqua', Georgia, serif;
    background: #fffff8;
    color: hsl(0, 0%, 20%);
    line-height: 1.6;
  }
  .wrapper {
    max-width: 50%;
    margin: 0 auto 0 12.5%;
    padding: 3rem 0 6rem;
    position: relative;
  }
  @media (max-width: 900px) {
    .wrapper { max-width: 92%; margin: 0 auto; padding: 1.5rem 0 3rem; }
  }
  h1 {
    font-weight: 400;
    font-size: 2.25rem;
    line-height: 1.2;
    margin: 0 0 1.5rem;
    color: hsl(0, 0%, 10%);
  }
  p { font-size: 1.1rem; line-height: 1.7; }
  a { color: #1e6bb8; }
  code { font-family: Consolas, Monaco, 'Andale Mono', monospace; font-size: 0.9em; }
CSS

# Minimal Rouge token fallbacks — the detailed palette is already in
# _codetalk.scss, scoped to .codetalk__code-inner. The rouge default CSS
# isn't needed.

# ── 6. Assemble standalone page ────────────────────────────────────
#
# Include a <script src="codetalk.js" inlined></script> marker so
# transform_html's "unless html.include?('codetalk.js')" short-circuits and
# it doesn't inject a second (external) script tag.

js_source = File.read(JS_PATH)

shell = <<~HTML
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>#{title} — Codetalk</title>
    <style>
  #{base_css}
  #{compiled_css}
    </style>
  </head>
  <body>
    <main class="wrapper">
      <h1>#{title}</h1>
      #{rendered}
    </main>
    <!-- codetalk.js inlined below -->
    <script>
  #{js_source}
    </script>
  </body>
  </html>
HTML

# ── 7. Run the Codetalk transform ──────────────────────────────────

final = Codetalk.transform_html(shell, sources)

File.write(OUTPUT_HTML, final)

puts "wrote #{OUTPUT_HTML} (#{File.size(OUTPUT_HTML)} bytes)"
