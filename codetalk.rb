# frozen_string_literal: true

require 'rouge'
require 'set'

# Codetalk
#
# Pins source files alongside markdown prose. Each `## <filename>` section in
# a page is paired with syntax-highlighted code; `### Lines N-M` subsections
# become scroll-spotlighted steps.
#
# This file has two callers:
#
#   1. Jekyll — via the Generator + post_render hook at the bottom of the file.
#      Triggered automatically on any page/document with `scripts:` front matter.
#
#   2. build.rb — the standalone demo builder requires this file, then calls
#      the module methods directly (Codetalk.load_sources, .preprocess_markdown,
#      .transform_html) without involving Jekyll.
#
# All the transform logic lives in the Codetalk module so both callers share
# one source of truth.

module Codetalk
  ICON_MAP = {
    'py'    => 'python/python-original',
    'js'    => 'javascript/javascript-original',
    'ts'    => 'typescript/typescript-original',
    'css'   => 'css3/css3-original',
    'html'  => 'html5/html5-original',
    'java'  => 'java/java-original',
    'go'    => 'go/go-original',
    'rs'    => 'rust/rust-original',
    'rb'    => 'ruby/ruby-original',
    'php'   => 'php/php-original',
    'swift' => 'swift/swift-original',
    'r'     => 'r/r-original',
    'c'     => 'c/c-original',
    'cpp'   => 'cplusplus/cplusplus-original',
    'sh'    => 'bash/bash-original',
    'bash'  => 'bash/bash-original',
    'yaml'  => 'yaml/yaml-original',
    'yml'   => 'yaml/yaml-original',
    'json'  => 'json/json-original',
    'md'    => 'markdown/markdown-original',
    'lua'   => 'lua/lua-original',
    'kt'    => 'kotlin/kotlin-original',
    'scala' => 'scala/scala-original'
  }.freeze

  ROMAN = %w[i ii iii iv v vi vii viii ix x xi xii xiii xiv xv xvi xvii xviii xix xx].freeze

  module_function

  # Index files under _code/ for lookup by basename
  def build_code_index(code_dir)
    index = {}
    return index unless File.directory?(code_dir)

    Dir.glob(File.join(code_dir, '**', '*')).each do |f|
      next unless File.file?(f)
      rel = f.sub("#{code_dir}/", '')
      basename = File.basename(f)
      index[basename] ||= rel
    end
    index
  end

  # Accept: comma string, array of strings, or array of hashes
  # Auto-find files by basename in _code/
  def normalize_scripts(raw, code_index)
    return [] if raw.nil?

    entries = if raw.is_a?(String)
                raw.split(',').map(&:strip).reject(&:empty?)
              elsif raw.is_a?(Array)
                raw
              else
                []
              end

    entries.map do |entry|
      if entry.is_a?(Hash)
        entry = entry.dup
        entry['file'] = resolve_file(entry['file'], code_index) if entry['file']
        entry
      else
        { 'file' => resolve_file(entry.to_s.strip, code_index) }
      end
    end
  end

  def resolve_file(name, code_index)
    return name if name.include?('/')
    code_index[name] || name
  end

  # Load a list of scripts (normalized) into codetalk_sources
  def load_sources(scripts, code_dir, logger: default_logger)
    scripts.map do |script|
      path = File.join(code_dir, script['file'])
      unless File.exist?(path)
        logger.error("Codetalk error: source not found: #{path}")
        raise "Codetalk: source not found: #{path}"
      end
      label = script['label'] || File.basename(script['file'])
      source = File.read(path)
      {
        'label'             => label,
        'file'              => script['file'],
        'lines'             => File.readlines(path, chomp: true),
        'highlighted_lines' => highlight_source(source, script['file'])
      }
    end
  end

  # Replace double blank lines (3+ consecutive newlines) inside annotation
  # blocks with a break marker. Lets authors signal "the rest is body text"
  # by leaving an extra blank line between the annotation and following prose.
  def preprocess_markdown(content)
    content.gsub(
      /(### Lines?\s+\d+(?:\s*[-–]\s*\d+)?\s*\n)(.*?)(?=### Lines?\s+\d|## |\# |\z)/m
    ) do
      heading = Regexp.last_match(1)
      body = Regexp.last_match(2)
      if body =~ /\A(.*?\n)\n{2,}(.*)\z/m
        annotation = Regexp.last_match(1)
        body_text = Regexp.last_match(2)
        heading + annotation + "\n<div class=\"codetalk-body-break\"></div>\n\n" + body_text
      else
        heading + body
      end
    end
  end

  def highlight_source(source, filename)
    lexer = begin
      Rouge::Lexer.guess(filename: filename)
    rescue Rouge::Guesser::Ambiguous => e
      e.alternatives.first
    rescue StandardError
      Rouge::Lexers::PlainText.new
    end
    formatter = Rouge::Formatters::HTML.new
    highlighted = formatter.format(lexer.lex(source))
    lines = split_highlighted_lines(highlighted)
    lines = lines.map { |l| colorize_tree_line(l) } if filename =~ /architecture|tree/i
    lines
  end

  # Terminal-like coloring for tree/architecture files
  def colorize_tree_line(line)
    return %(<span class="c1">#{line}</span>) if line =~ /\A\s*#/

    line = line.gsub(%r{(?<![<\w/])(\w[\w.\-]*/)}m) { %(<span class="nb">#{Regexp.last_match(1)}</span>) }
    line = line.gsub(/(←.*)/) { %(<span class="c1">#{Regexp.last_match(1)}</span>) }
    line
  end

  # Split Rouge HTML into per-line strings; reopen spans at line boundaries
  # so each line stands alone as valid HTML.
  def split_highlighted_lines(html)
    raw_lines = html.split("\n")
    open_stack = []

    raw_lines.map do |raw|
      prefix = open_stack.join

      raw.scan(/<span[^>]*>|<\/span>/).each do |tag|
        if tag == '</span>'
          open_stack.pop if open_stack.any?
        else
          open_stack.push(tag)
        end
      end

      suffix = '</span>' * open_stack.length
      prefix + raw + suffix
    end
  end

  def icon_for(filename)
    ext = File.extname(filename).delete('.').downcase
    path = ICON_MAP[ext]
    if path
      url = "https://cdn.jsdelivr.net/gh/devicons/devicon/icons/#{path}.svg"
      %(<img src="#{url}" class="codetalk__file-icon" alt="">)
    else
      %(<i class="fa-solid fa-file-code codetalk__file-icon"></i>)
    end
  end

  # Main HTML transform. Finds ## <file-label> sections that match a known
  # source, groups consecutive ones into codetalk blocks (tabbed if multi-file),
  # and replaces them with the two-column code+prose HTML. Also injects a
  # script tag and converts sidenotes inside steps to footnotes.
  #
  # Returns the transformed HTML string.
  def transform_html(html, sources, js_path: '/assets/js/codetalk.js')
    return html if sources.nil? || sources.empty?

    label_set = Set.new(sources.map { |s| s['label'] })
    source_map = {}
    sources.each { |s| source_map[s['label']] = s }

    # ── 1. Find all <h2> tags, record position and label ───────────

    h2_pattern = /<h2[^>]*>(.*?)<\/h2>/m
    h2_entries = []
    search_pos = 0
    while (m = h2_pattern.match(html, search_pos))
      label = m[1].strip.gsub(/<[^>]+>/, '')
      h2_entries << {
        label: label,
        pos: m.begin(0),
        match_end: m.end(0),
        is_codetalk: label_set.include?(label)
      }
      search_pos = m.end(0)
    end

    codetalk_indices = h2_entries.each_index.select { |i| h2_entries[i][:is_codetalk] }
    return html if codetalk_indices.empty?

    # <h1> positions act as section boundaries
    h1_positions = []
    search_pos_h1 = 0
    h1_pattern = /<h1[^>]*>/m
    while (m = h1_pattern.match(html, search_pos_h1))
      h1_positions << m.begin(0)
      search_pos_h1 = m.end(0)
    end

    # ── 2. Group consecutive codetalk h2s into blocks ──────────────

    groups = []
    current_group = [codetalk_indices.first]

    codetalk_indices.drop(1).each do |idx|
      prev_idx = current_group.last
      prev_pos = h2_entries[prev_idx][:pos]
      curr_pos = h2_entries[idx][:pos]

      gap_h2s = (prev_idx + 1...idx).any? { |i| !h2_entries[i][:is_codetalk] }
      gap_h1s = h1_positions.any? { |p| p > prev_pos && p < curr_pos }

      if gap_h2s || gap_h1s || idx != prev_idx + 1
        groups << current_group
        current_group = [idx]
      else
        current_group << idx
      end
    end
    groups << current_group

    # ── 3. For each group, extract section content and build HTML ──
    # Process groups in reverse so position offsets stay valid.

    groups.reverse.each do |group|
      file_sections = []
      group_start = h2_entries[group.first][:pos]

      group.each do |idx|
        entry = h2_entries[idx]
        next_h2_pos = h2_entries.select { |e| e[:pos] > entry[:pos] }.map { |e| e[:pos] }.first
        next_h1_pos = h1_positions.select { |p| p > entry[:pos] }.first
        candidates = [next_h2_pos, next_h1_pos].compact
        section_end = if candidates.any?
                        candidates.min
                      else
                        html.index('</content>', entry[:pos]) ||
                          html.index('</article>', entry[:pos]) ||
                          html.length
                      end

        section_html = html[entry[:pos]...section_end]
        section_body = section_html.sub(/<h2[^>]*>.*?<\/h2>\s*/m, '')

        preamble_html = ''
        steps_body = ''

        parts = section_body.split(/(?=<h3[^>]*>\s*Lines?\s+\d)/m, 2)
        if parts.length > 1
          preamble_text = parts[0].strip
          steps_body = parts[1]
        elsif parts[0] =~ /<h3[^>]*>\s*Lines?\s+\d/m
          preamble_text = ''
          steps_body = parts[0]
        else
          preamble_text = parts[0].strip
          steps_body = ''
        end

        if !preamble_text.empty? && preamble_text =~ /\A\s*<h3[^>]*>\s*Lines?\s+\d/m
          steps_body = preamble_text + (steps_body.empty? ? '' : "\n" + steps_body)
          preamble_text = ''
        end

        unless preamble_text.empty?
          preamble_html = %(<div class="codetalk__preamble">\n#{preamble_text}\n</div>\n)
        end

        max_ann_line = 0
        trailing_body = []
        steps_html = steps_body.gsub(
          %r{<h3[^>]*>\s*Lines?\s+(\d+)(?:\s*[-–]\s*(\d+))?\s*</h3>(.*?)(?=<h3[^>]*>\s*Lines?\s+\d|\z)}m
        ) do
          start_line = Regexp.last_match(1)
          end_line   = Regexp.last_match(2) || start_line
          content    = Regexp.last_match(3).strip
          end_int = end_line.to_i
          max_ann_line = end_int if end_int > max_ann_line

          if content.include?('codetalk-body-break')
            parts2 = content.split(/<div\s+class="codetalk-body-break"><\/div>/m, 2)
            annotation = parts2[0].strip
            body_after = parts2[1]&.strip
            trailing_body << body_after unless body_after.nil? || body_after.empty?
            %(<div class="codetalk__step" data-start="#{start_line}" data-end="#{end_line}">\n#{annotation}\n</div>\n)
          else
            %(<div class="codetalk__step" data-start="#{start_line}" data-end="#{end_line}">\n#{content}\n</div>\n)
          end
        end

        file_sections << {
          label: entry[:label],
          preamble: preamble_html,
          steps: steps_html,
          trailing_body: trailing_body.join("\n"),
          end_pos: section_end,
          max_line: max_ann_line
        }
      end

      group_end = file_sections.last[:end_pos]
      labels = file_sections.map { |s| s[:label] }

      code_panes = labels.each_with_index.map do |label, idx|
        source = source_map[label]
        next '' unless source
        hidden = idx > 0 ? ' codetalk__code--hidden' : ''

        last_line = file_sections
                      .select { |s| s[:label] == label && s[:max_line] > 0 }
                      .map    { |s| s[:max_line] }
                      .max || source['highlighted_lines'].length
        visible_lines = source['highlighted_lines'][0...last_line]

        lines_html = visible_lines.each_with_index.map do |line_html, i|
          line_content = line_html.strip.empty? ? '&nbsp;' : line_html
          %(<div class="codetalk__line" data-line="#{i + 1}">#{line_content}</div>)
        end.join("\n")

        header = if labels.length == 1
                   %(<div class="codetalk__code-header">#{icon_for(label)} #{label}</div>\n)
                 else
                   ''
                 end

        %(<div class="codetalk__code#{hidden}" data-file="#{label}">\n#{header}<div class="codetalk__code-inner"><div class="codetalk__code-lines">\n#{lines_html}\n</div></div>\n</div>)
      end.join("\n")

      tabs_html = ''
      if labels.length > 1
        tabs = labels.each_with_index.map do |label, idx|
          active = idx == 0 ? ' codetalk__file-tab--active' : ''
          %(<button class="codetalk__file-tab#{active}" data-file="#{label}">#{icon_for(label)} #{label}</button>)
        end
        tabs_html = %(<div class="codetalk__file-tabs">\n#{tabs.join("\n")}\n</div>\n)
      end

      preambles_html = file_sections.map { |sec| sec[:preamble] }.reject(&:empty?).join("\n")

      prose_sections = file_sections.each_with_index.map do |sec, idx|
        active = idx == 0 ? ' codetalk__file-section--active' : ''
        %(<div class="codetalk__file-section#{active}" data-file="#{sec[:label]}">\n#{sec[:steps]}\n</div>)
      end.join("\n")

      all_trailing = file_sections.map { |s| s[:trailing_body] }.reject(&:empty?).join("\n")

      codetalk_html = <<~HTML
        #{preambles_html}
        <div class="codetalk">
          <div class="codetalk__code-area">
            #{tabs_html}#{code_panes}
          </div>
          <div class="codetalk__prose">
            #{prose_sections}
          </div>
        </div>
        #{all_trailing}
      HTML

      html = html[0...group_start] + codetalk_html + html[group_end..]
    end

    # ── Convert sidenotes to footnotes inside codetalk steps ─────

    footnote_counter = 0
    footnote_defs = []

    html = html.gsub(
      %r{(<div\s+class="codetalk__step"[^>]*>)(.*?)(</div>\s*(?=<div\s+class="codetalk__|</div>))}m
    ) do
      pre = Regexp.last_match(1)
      body = Regexp.last_match(2)
      post = Regexp.last_match(3)

      body = body.gsub(
        %r{<label\s+for="sn-(\d+)"\s+class="margin-toggle sidenote-number">\s*</label>\s*<input[^>]*class="margin-toggle"[^>]*>\s*<span\s+class="sidenote">(.*?)</span>}m
      ) do
        sn_num = Regexp.last_match(1).to_i
        fn_text = Regexp.last_match(2).strip
        footnote_counter += 1
        fn_id = "ctfn-#{footnote_counter}"
        footnote_defs << { id: fn_id, text: fn_text }
        numeral = ROMAN[sn_num - 1] || sn_num.to_s
        %(<sup class="codetalk-fnref"><a href="##{fn_id}" id="#{fn_id}-ref" class="codetalk-fnref-link">#{numeral}</a></sup>)
      end

      pre + body + post
    end

    unless footnote_defs.empty?
      fn_items = footnote_defs.map do |fn|
        %(<li id="#{fn[:id]}"><p>#{fn[:text]} <a href="##{fn[:id]}-ref" class="reversefootnote" role="doc-backlink">&#x21A9;</a></p></li>)
      end.join("\n")

      fn_html = <<~HTML
        <div class="footnotes codetalk-footnotes">
          <ol>
            #{fn_items}
          </ol>
        </div>
      HTML

      insertion_point = html.index('</content>') ||
                        html.index('</article>') ||
                        html.index('</body>')
      html = html[0...insertion_point] + fn_html + html[insertion_point..] if insertion_point
    end

    # ── Inject codetalk.js before </body> ───────────────────────

    unless html.include?('codetalk.js')
      script_tag = %(\n<script src="#{js_path}"></script>\n)
      if html.include?('</body>')
        html = html.sub('</body>', script_tag + '</body>')
      else
        html += script_tag
      end
    end

    html
  end

  # Minimal logger used when called outside Jekyll (by build.rb).
  def default_logger
    @default_logger ||= Object.new.tap do |o|
      def o.error(msg); warn(msg); end
      def o.info(msg); puts(msg); end
    end
  end
end

# ── Jekyll integration ──────────────────────────────────────────────
# Only loaded when this file runs inside a Jekyll build.

if defined?(Jekyll)
  module Jekyll
    class CodetalkGenerator < Generator
      safe true
      priority :low

      def generate(site)
        code_dir = File.join(site.source, '_code')
        code_index = ::Codetalk.build_code_index(code_dir)

        each_codetalk(site) do |doc|
          doc.content = ::Codetalk.preprocess_markdown(doc.content)

          scripts = ::Codetalk.normalize_scripts(doc.data['scripts'], code_index)
          doc.data['scripts'] = scripts
          doc.data['codetalk_sources'] = ::Codetalk.load_sources(
            scripts, code_dir, logger: jekyll_logger
          )
        end
      end

      private

      def jekyll_logger
        @jekyll_logger ||= Object.new.tap do |o|
          def o.error(msg); Jekyll.logger.abort_with('Codetalk error:', msg); end
          def o.info(msg); Jekyll.logger.info('Codetalk:', msg); end
        end
      end

      def each_codetalk(site, &block)
        site.pages.each { |p| yield p if scripts_present?(p) }
        site.collections.each_value do |col|
          col.docs.each { |d| yield d if scripts_present?(d) }
        end
      end

      def scripts_present?(doc)
        s = doc.data['scripts']
        return false if s.nil?
        return s.length > 0 if s.is_a?(Array)
        return !s.strip.empty? if s.is_a?(String)
        false
      end
    end
  end

  Jekyll::Hooks.register [:pages, :documents], :post_render do |doc|
    scripts = doc.data['scripts']
    next unless scripts&.any?
    sources = doc.data['codetalk_sources']
    next unless sources&.any?

    doc.output = ::Codetalk.transform_html(doc.output, sources)
  end
end
