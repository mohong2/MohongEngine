/* SeiunEngine Script API — i18n + UI core
 *
 * Multi-language architecture:
 *   - Each language is an external data file: lang/<id>.js  (a JS object, JSON-like)
 *   - Add a language by: 1) create lang/<id>.js defining window.I18N[<id>]={...}
 *                         2) add "<id>" to the LANGUAGES array below.
 *   - Elements carry a data-i18n="namespace.key" attribute; the value is looked up
 *     in the active language object and injected as HTML.
 *   - The language toggle buttons are generated automatically from LANGUAGES.
 */
(function () {
  'use strict';

  // List of available languages (language files must define window.I18N[<id>]).
  var LANGUAGES = [
    { id: 'en', label: 'EN' },
    { id: 'zh', label: '中文' }
    // future: { id: 'ja', label: '日本語' }
  ];

  var DEFAULT_LANG = 'en';
  var KEY = 'seiun-scriptapi-lang';
  var lang = DEFAULT_LANG;
  try { var saved = localStorage.getItem(KEY); if (saved) lang = saved; } catch (e) {}
  if (!LANGUAGES.some(function (l) { return l.id === lang; })) lang = DEFAULT_LANG;

  function getDict() {
    var d = window.I18N && window.I18N[lang];
    return d || (window.I18N && window.I18N[DEFAULT_LANG]) || {};
  }

  // Inject all language data files (by adding <script> tags). Loading them this way
  // works under file:// and means adding a language never breaks existing pages.
  function loadLanguageFiles() {
    LANGUAGES.forEach(function (l) {
      var s = document.createElement('script');
      s.src = 'lang/' + l.id + '.js';
      document.head.appendChild(s);
    });
  }

  function applyLanguage() {
    var dict = getDict();
    document.documentElement.setAttribute('lang', lang === 'zh' ? 'zh-CN' : lang);

    // Fill [data-i18n] elements from the active dict (value may contain HTML).
    document.querySelectorAll('[data-i18n]').forEach(function (el) {
      var key = el.getAttribute('data-i18n');
      var val = null;
      if (dict && Object.prototype.hasOwnProperty.call(dict, key)) val = dict[key];
      if (val === null || val === undefined) return; // fallback = static HTML text
      el.innerHTML = val;
    });

    renderToggle();
    document.documentElement.classList.remove('no-js');
  }

  function renderToggle() {
    document.querySelectorAll('[data-lang-toggle]').forEach(function (c) {
      c.innerHTML = '';
      var select = document.createElement('select');
      select.className = 'lang-select';
      select.setAttribute('aria-label', 'Language');
      LANGUAGES.forEach(function (l) {
        var o = document.createElement('option');
        o.value = l.id;
        o.textContent = l.label;
        o.selected = (l.id === lang);
        select.appendChild(o);
      });
      select.addEventListener('change', function () { setLang(select.value); });
      c.appendChild(select);
    });
  }

  // --- Smooth animation layer (runs regardless of language file readiness) ---

  // Scroll-reveal: elements with class "reveal" fade up when they enter the viewport.
  function initReveal() {
    var items = document.querySelectorAll('.reveal');
    if (!items.length) return;
    if (!('IntersectionObserver' in window)) {
      items.forEach(function (el) { el.classList.add('in'); });
      return;
    }
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (en.isIntersecting) { en.target.classList.add('in'); io.unobserve(en.target); }
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -8% 0px' });
    items.forEach(function (el, i) {
      if (!el.style.getPropertyValue('--d')) el.style.setProperty('--d', (i * 40) + 'ms');
      io.observe(el);
    });
  }

  // Table rows fade in from the left, staggered.
  function initTableRows() {
    document.querySelectorAll('tbody tr').forEach(function (tr, i) {
      tr.style.transitionDelay = (Math.min(i % 12, 10) * 35) + 'ms';
      setTimeout(function () { tr.classList.add('td-in'); }, 40 + i * 18);
    });
  }

  // Cursor spotlight on cards / notes (uses --mx/--my custom props).
  function initSpotlight() {
    var targets = document.querySelectorAll('.mcard,.note,.legend');
    targets.forEach(function (el) {
      el.addEventListener('mousemove', function (e) {
        var r = el.getBoundingClientRect();
        el.style.setProperty('--mx', (e.clientX - r.left) + 'px');
        el.style.setProperty('--my', (e.clientY - r.top) + 'px');
      });
    });
  }

  // Page exit: fade the current page out before following a same-origin link.
  function initPageTransition() {
    document.addEventListener('click', function (e) {
      var a = e.target.closest ? e.target.closest('a[href]') : null;
      if (!a) return;
      var href = a.getAttribute('href');
      if (!href || href.charAt(0) === '#' || href.indexOf('://') !== -1) return;
      e.preventDefault();
      document.body.classList.add('page-exit');
      setTimeout(function () { window.location.href = href; }, 220);
    });
  }

  function initAnimations() {
    autoReveal();
    initReveal();
    initTableRows();
    initSpotlight();
    initPageTransition();
    initActiveNav();
  }

  // Highlight the nav link matching the current page (based on the filename).
  function initActiveNav() {
    var file = (window.location.pathname.split('/').pop() || 'index.html').toLowerCase();
    document.querySelectorAll('.nav-links a').forEach(function (a) {
      var href = (a.getAttribute('href') || '').toLowerCase();
      if (href === file || (file === '' && href === 'index.html')) a.classList.add('active');
    });
  }

  // Automatically tag the main content blocks so the whole page animates in
  // without editing every HTML file.
  function autoReveal() {
    document.querySelectorAll('.wrap h1,.wrap h2,.wrap h3,.wrap .badge,' +
      '.wrap .hero,.wrap .note,.wrap .legend,.wrap .table-wrap,.wrap pre,.wrap .btns,' +
      '.wrap p.sub')
      .forEach(function (el) {
        el.classList.add('reveal');
      });
    // Reveal individual module cards with a stagger for a cascading effect.
    document.querySelectorAll('.mgrid .mcard').forEach(function (card, i) {
      card.classList.add('reveal');
      card.style.setProperty('--d', ((i % 4) * 90) + 'ms');
    });
  }

  function setLang(l) {
    lang = (LANGUAGES.some(function (x) { return x.id === l; })) ? l : DEFAULT_LANG;
    try { localStorage.setItem(KEY, lang); } catch (e) {}
    applyLanguage();
  }

  window.SeiunLang = {
    get: function () { return lang; },
    set: setLang,
    apply: applyLanguage,
    languages: LANGUAGES
  };

  loadLanguageFiles();
  var boot = function () {
    setTimeout(function () {
      applyLanguage();
      initAnimations();
    }, 30);
  };
  if (document.readyState !== 'loading') boot();
  window.addEventListener('DOMContentLoaded', boot);
})();
