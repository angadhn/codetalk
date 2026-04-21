(function () {
  'use strict';

  // Initialize each .codetalk block independently
  var codetalks = document.querySelectorAll('.codetalk');
  for (var cw = 0; cw < codetalks.length; cw++) {
    initCodetalk(codetalks[cw]);
  }

  function initCodetalk(container) {
    var prosePane = container.querySelector('.codetalk__prose');
    if (!prosePane) return;

    var allCodePanes = Array.prototype.slice.call(
      container.querySelectorAll('.codetalk__code')
    );
    if (!allCodePanes.length) return;

    var fileSections = Array.prototype.slice.call(
      prosePane.querySelectorAll('.codetalk__file-section')
    );
    var fileTabs = Array.prototype.slice.call(
      container.querySelectorAll('.codetalk__file-tab')
    );
    var activeFileIdx = -1;
    var fullyInView = false;

    // ── Build per-file data ──────────────────────────────────────

    function parseAnnotation(step) {
      return {
        start: parseInt(step.getAttribute('data-start'), 10),
        end:   parseInt(step.getAttribute('data-end'),   10),
        element: step
      };
    }

    var files = [];

    if (fileSections.length > 0) {
      for (var f = 0; f < fileSections.length; f++) {
        var sec = fileSections[f];
        var label = sec.getAttribute('data-file');
        var cp = null;
        for (var c = 0; c < allCodePanes.length; c++) {
          if (allCodePanes[c].getAttribute('data-file') === label) {
            cp = allCodePanes[c]; break;
          }
        }
        if (!cp) continue;

        var stepsInSec = Array.prototype.slice.call(
          sec.querySelectorAll('.codetalk__step')
        );
        files.push({
          label: label,
          codePane: cp,
          codeInner: cp.querySelector('.codetalk__code-inner'),
          section: sec,
          steps: stepsInSec,
          annotations: stepsInSec.map(parseAnnotation),
          lines: [],
          preambleBottom: 0,
          activeStepIndices: []
        });
      }
    } else {
      // Fallback: no file-section wrappers (single-file)
      var cp0 = allCodePanes[0];
      var stepsAll = Array.prototype.slice.call(
        prosePane.querySelectorAll('.codetalk__step')
      );
      files.push({
        label: cp0.getAttribute('data-file') || '',
        codePane: cp0,
        codeInner: cp0.querySelector('.codetalk__code-inner'),
        section: prosePane,
        steps: stepsAll,
        annotations: stepsAll.map(parseAnnotation),
        lines: [],
        preambleBottom: 0,
        activeStepIndices: []
      });
    }

    if (!files.length) return;

    function cur() { return files[activeFileIdx]; }

    // ── File switching ───────────────────────────────────────────

    function switchFile(idx) {
      if (idx === activeFileIdx) return;

      if (activeFileIdx >= 0) {
        var prev = files[activeFileIdx];
        prev.codePane.classList.add('codetalk__code--hidden');
        prev.section.classList.remove('codetalk__file-section--active');
        for (var i = 0; i < prev.steps.length; i++) {
          prev.steps[i].classList.remove('codetalk__step--active');
        }
        for (var i = 0; i < prev.lines.length; i++) {
          prev.lines[i].classList.remove('codetalk__line--active', 'codetalk__line--dim');
        }
        prev.activeStepIndices = [];
        if (fileTabs[activeFileIdx]) {
          fileTabs[activeFileIdx].classList.remove('codetalk__file-tab--active');
        }
      }

      activeFileIdx = idx;
      var next = files[idx];
      next.codePane.classList.remove('codetalk__code--hidden');
      next.section.classList.add('codetalk__file-section--active');
      if (fileTabs[idx]) {
        fileTabs[idx].classList.add('codetalk__file-tab--active');
      }

      measurePreamble();
      checkActiveAnnotation();
    }

    // ── Tab click handlers ───────────────────────────────────────

    for (var t = 0; t < fileTabs.length; t++) {
      (function (idx) {
        fileTabs[idx].addEventListener('click', function () {
          switchFile(idx);
        });
      })(t);
    }

    // ── Annotation trigger detection ─────────────────────────────
    // Sticky behavior: the active annotation stays active as long as ANY
    // part of its line range is in view. When its last line scrolls out
    // (or its first line scrolls below the pane), pick whichever other
    // annotation has the largest visible range.

    function checkActiveAnnotation() {
      var file = cur();
      if (!file || !file.codeInner) return;

      var paneRect = file.codeInner.getBoundingClientRect();
      var paneTop = paneRect.top;
      var paneBottom = paneRect.bottom;

      function rectsFor(ann) {
        var firstLine = file.codeInner.querySelector('[data-line="' + ann.start + '"]');
        var lastLine  = file.codeInner.querySelector('[data-line="' + ann.end   + '"]');
        if (!firstLine || !lastLine) return null;
        return {
          first: firstLine.getBoundingClientRect(),
          last: lastLine.getBoundingClientRect()
        };
      }

      var prev = file.activeStepIndices || [];
      var currentIdx = prev.length ? prev[0] : -1;

      if (currentIdx >= 0) {
        var rects = rectsFor(file.annotations[currentIdx]);
        if (rects && rects.last.bottom >= paneTop && rects.first.top <= paneBottom) {
          positionActiveSteps();
          return;
        }
      }

      var bestIdx = -1;
      for (var i = 0; i < file.annotations.length; i++) {
        var r = rectsFor(file.annotations[i]);
        if (!r) continue;
        if (r.last.bottom >= paneTop && r.first.top <= paneBottom) {
          bestIdx = i;
          break;
        }
      }

      var newActive = bestIdx >= 0 ? [bestIdx] : [];
      if (newActive.length === prev.length && newActive.every(function (v, j) { return v === prev[j]; })) {
        positionActiveSteps();
        return;
      }
      file.activeStepIndices = newActive;
      updateDisplay();
    }

    // ── Position active steps near their annotated lines ─────────

    function positionActiveSteps() {
      var file = cur();
      if (!file) return;
      var indices = file.activeStepIndices || [];
      if (!indices.length) return;

      var proseRect = prosePane.getBoundingClientRect();
      var lastBottom = file.preambleBottom;

      for (var j = 0; j < indices.length; j++) {
        var ann = file.annotations[indices[j]];
        var step = ann.element;
        var firstLine = file.codeInner.querySelector('[data-line="' + ann.start + '"]');
        if (!firstLine) continue;

        var lineRect = firstLine.getBoundingClientRect();
        var idealTop = lineRect.top - proseRect.top;
        var stepHeight = step.offsetHeight;
        var maxTop = proseRect.height - stepHeight;

        var top = Math.max(lastBottom, Math.min(idealTop, maxTop));
        step.style.top = top + 'px';
        lastBottom = top + stepHeight + 8;
      }
    }

    // ── Update highlighting and prose ────────────────────────────

    function updateDisplay() {
      var file = cur();
      if (!file) return;

      var lines = file.lines;
      var steps = file.steps;
      var activeSet = file.activeStepIndices || [];
      var anns = file.annotations;

      if (!activeSet.length) {
        for (var i = 0; i < lines.length; i++) {
          lines[i].classList.remove('codetalk__line--active', 'codetalk__line--dim');
        }
      } else {
        var activeLines = {};
        for (var a = 0; a < activeSet.length; a++) {
          var ann = anns[activeSet[a]];
          for (var ln = ann.start; ln <= ann.end; ln++) {
            activeLines[ln] = true;
          }
        }
        for (var i = 0; i < lines.length; i++) {
          var n = parseInt(lines[i].getAttribute('data-line'), 10);
          if (activeLines[n]) {
            lines[i].classList.add('codetalk__line--active');
            lines[i].classList.remove('codetalk__line--dim');
          } else {
            lines[i].classList.remove('codetalk__line--active');
            lines[i].classList.add('codetalk__line--dim');
          }
        }
      }

      updateSpotlight();

      var activeSetObj = {};
      for (var a = 0; a < activeSet.length; a++) {
        activeSetObj[activeSet[a]] = true;
      }
      for (var i = 0; i < steps.length; i++) {
        if (activeSetObj[i]) {
          steps[i].classList.add('codetalk__step--active');
        } else {
          steps[i].classList.remove('codetalk__step--active');
        }
      }

      positionActiveSteps();
    }

    // ── Preamble measurement ─────────────────────────────────────

    function measurePreamble() {
      var file = cur();
      if (!file) return;
      var el = file.section.querySelector('.codetalk__preamble');
      if (!el) { file.preambleBottom = 0; return; }
      var style = window.getComputedStyle(el);
      file.preambleBottom = el.offsetTop + el.offsetHeight +
        (parseFloat(style.marginBottom) || 0);
    }

    // ── Init ─────────────────────────────────────────────────────

    for (var f = 0; f < files.length; f++) {
      files[f].lines = Array.prototype.slice.call(
        files[f].codeInner.querySelectorAll('.codetalk__line')
      );
    }

    // ── Spotlight: dim surroundings when annotation is active ─────

    var dimmedElements = [];

    function updateSpotlight() {
      var file = cur();
      var hasActive = file && file.activeStepIndices && file.activeStepIndices.length > 0;
      var shouldDim = fullyInView && hasActive;

      if (shouldDim) {
        container.classList.add('codetalk--spotlighting');
        if (!dimmedElements.length) {
          var parent = container.parentNode;
          var children = parent ? Array.prototype.slice.call(parent.children) : [];
          var cwIndex = children.indexOf(container);

          for (var i = 0; i < children.length; i++) {
            var el = children[i];
            if (el === container || el.classList.contains('codetalk__preamble') || el.classList.contains('codetalk')) continue;

            var dist = Math.abs(i - cwIndex);
            var opacity = dist <= 1 ? 0.25 : dist <= 2 ? 0.12 : 0.06;
            el.style.transition = 'opacity 0.5s ease';
            el.style.opacity = opacity;
            el.style.pointerEvents = 'none';
            dimmedElements.push(el);
          }

          var nav = document.querySelector('body > nav');
          var footer = document.querySelector('body > footer');
          if (nav) {
            nav.style.transition = 'opacity 0.5s ease';
            nav.style.opacity = '0.06';
            nav.style.pointerEvents = 'none';
            dimmedElements.push(nav);
          }
          if (footer) {
            footer.style.transition = 'opacity 0.5s ease';
            footer.style.opacity = '0.06';
            footer.style.pointerEvents = 'none';
            dimmedElements.push(footer);
          }
        }
      } else {
        container.classList.remove('codetalk--spotlighting');
        for (var i = 0; i < dimmedElements.length; i++) {
          dimmedElements[i].style.opacity = '';
          dimmedElements[i].style.pointerEvents = '';
        }
        dimmedElements = [];
      }
    }

    function checkFullyInView() {
      var rect = container.getBoundingClientRect();
      var vpHeight = window.innerHeight;
      var height = rect.height;
      if (height <= 0) { fullyInView = false; updateSpotlight(); return; }

      var aboveViewport = Math.max(0, -rect.top);
      var belowViewport = Math.max(0, rect.bottom - vpHeight);
      var hiddenRatio = (aboveViewport + belowViewport) / height;

      fullyInView = hiddenRatio <= 0.05;
      updateSpotlight();
    }

    var scrollTicking = false;
    window.addEventListener('scroll', function () {
      if (!scrollTicking) {
        requestAnimationFrame(function () {
          checkFullyInView();
          scrollTicking = false;
        });
        scrollTicking = true;
      }
    });
    checkFullyInView();

    for (var f = 0; f < files.length; f++) {
      (function (idx) {
        var ticking = false;
        files[idx].codeInner.addEventListener('scroll', function () {
          if (idx !== activeFileIdx) return;
          if (!ticking) {
            requestAnimationFrame(function () {
              checkActiveAnnotation();
              ticking = false;
            });
            ticking = true;
          }
        });
      })(f);
    }

    switchFile(0);

    // ── Size container to fit tallest file (up to 70vh, min 10 lines) ─
    var maxCodeContent = 0;
    var singleLineHeight = 0;
    for (var f = 0; f < files.length; f++) {
      var linesEl = files[f].codeInner.querySelector('.codetalk__code-lines');
      if (linesEl) {
        maxCodeContent = Math.max(maxCodeContent, linesEl.scrollHeight);
      }
      if (!singleLineHeight && files[f].lines.length) {
        singleLineHeight = files[f].lines[0].offsetHeight;
      }
    }
    var minCodeContent = singleLineHeight * 10;
    var chrome = container.querySelector('.codetalk__code-area').offsetHeight
               - files[activeFileIdx].codeInner.clientHeight;
    var idealHeight = Math.max(maxCodeContent, minCodeContent) + chrome;
    var maxHeight = window.innerHeight * 0.7;
    if (idealHeight < maxHeight) {
      container.style.height = idealHeight + 'px';
    }
  }
})();
