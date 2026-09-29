/* Yoerger Renovations - site.js (no dependencies) */
(function () {
  'use strict';
  var root = document.documentElement;
  root.classList.add('js');
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var $ = function (s, c) { return (c || document).querySelector(s); };
  var $$ = function (s, c) { return Array.prototype.slice.call((c || document).querySelectorAll(s)); };

  /* ---------- header + tape measure ---------- */
  var head = $('.site-head');
  var tape = $('.tape');
  var tapeRead = $('#tapeRead');
  var mobileCta = $('.mobile-cta');
  var ticking = false;
  function onScroll() {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(function () {
      var y = window.scrollY || window.pageYOffset;
      var max = Math.max(1, document.documentElement.scrollHeight - window.innerHeight);
      var p = Math.min(1, Math.max(0, y / max));
      if (head) head.classList.toggle('is-scrolled', y > 24);
      if (tape) {
        tape.style.setProperty('--p', (p * 100).toFixed(2) + '%');
        tape.classList.toggle('is-live', y > 40);
        if (tapeRead) {
          var inches = Math.round(p * 25 * 12);
          tapeRead.textContent = Math.floor(inches / 12) + "' " + (inches % 12) + '"';
        }
      }
      if (mobileCta) mobileCta.classList.toggle('is-on', y > 420);
      updateProcess();
      ticking = false;
    });
  }
  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', onScroll);
  onScroll();

  /* ---------- mobile menu ---------- */
  var menuBtn = $('.menu-btn');
  var mobileNav = $('#mobileNav');
  if (menuBtn && mobileNav) {
    menuBtn.addEventListener('click', function () {
      var open = menuBtn.getAttribute('aria-expanded') === 'true';
      menuBtn.setAttribute('aria-expanded', String(!open));
      mobileNav.hidden = open;
    });
    $$('a', mobileNav).forEach(function (a) {
      a.addEventListener('click', function () { menuBtn.setAttribute('aria-expanded', 'false'); mobileNav.hidden = true; });
    });
  }

  /* ---------- hero rotator ---------- */
  var rot = $('.rot');
  if (rot) {
    var words = $$('.word', rot);
    var slides = $$('.hero-slide');
    var dots = $$('.hero-dot');
    var idx = 0, timer = null, MS = 3600;
    root.style.setProperty('--rot-ms', MS + 'ms');
    function show(n) {
      var prev = idx; idx = (n + words.length) % words.length;
      words.forEach(function (w, i) {
        w.classList.toggle('is-on', i === idx);
        w.classList.toggle('is-out', i === prev && prev !== idx);
      });
      var key = words[idx].getAttribute('data-key');
      slides.forEach(function (s) {
        var on = s.getAttribute('data-key') === key;
        if (on && s.getAttribute('loading') === 'lazy') s.removeAttribute('loading');
        s.classList.toggle('is-on', on);
      });
      dots.forEach(function (d) {
        var on = d.getAttribute('data-key') === key;
        d.classList.toggle('is-on', on);
        d.setAttribute('aria-selected', String(on));
      });
    }
    function start() { stop(); if (!reduce) timer = setInterval(function () { show(idx + 1); }, MS); }
    function stop() { if (timer) { clearInterval(timer); timer = null; } }
    dots.forEach(function (d, i) { d.addEventListener('click', function () { show(i); start(); }); });
    document.addEventListener('visibilitychange', function () { document.hidden ? stop() : start(); });
    var hero = $('.hero');
    if (hero) { hero.addEventListener('mouseenter', stop); hero.addEventListener('mouseleave', start); }
    show(0); start();
  }

  /* ---------- reveal on scroll ---------- */
  var revealEls = $$('[data-reveal]');
  if ('IntersectionObserver' in window && !reduce) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
    revealEls.forEach(function (el) { io.observe(el); });
  } else {
    revealEls.forEach(function (el) { el.classList.add('in'); });
  }

  /* ---------- process line ---------- */
  var steps = $('.steps');
  var stepEls = steps ? $$('.step', steps) : [];
  function updateProcess() {
    if (!steps) return;
    var r = steps.getBoundingClientRect();
    var vh = window.innerHeight;
    var p = (vh * 0.78 - r.top) / Math.max(1, r.height);
    p = Math.min(1, Math.max(0, p));
    steps.style.setProperty('--p', p.toFixed(3));
    stepEls.forEach(function (s, i) {
      var t = (i + 0.35) / stepEls.length;
      s.classList.toggle('is-done', p >= t);
    });
  }

  /* ---------- work filters ---------- */
  $$('[data-filter-group]').forEach(function (group) {
    var target = $(group.getAttribute('data-filter-group'));
    if (!target) return;
    var chips = $$('.chip', group);
    var empty = $('.grid-empty', target.parentNode);
    chips.forEach(function (chip) {
      chip.addEventListener('click', function () {
        var cat = chip.getAttribute('data-cat');
        chips.forEach(function (c) { c.setAttribute('aria-pressed', String(c === chip)); });
        var shown = 0;
        $$('.tile', target).forEach(function (t, i) {
          var on = cat === 'all' || t.getAttribute('data-cat') === cat;
          t.classList.toggle('is-hidden', !on);
          if (on) { shown++; t.style.setProperty('--i', Math.min(i, 8)); t.classList.remove('in'); requestAnimationFrame(function () { t.classList.add('in'); }); }
        });
        if (empty) empty.hidden = shown > 0;
      });
    });
  });

  /* ---------- lightbox ---------- */
  var dataEl = $('#projectsData');
  var projects = {};
  try { projects = dataEl ? JSON.parse(dataEl.textContent) : {}; } catch (e) { projects = {}; }
  var lb = $('.lb');
  if (lb) {
    var lbImg = $('.lb-img', lb), lbCount = $('.lb-count', lb), lbCat = $('.lb-cat', lb), lbTitle = $('.lb-title', lb), lbCap = $('.lb-caption', lb);
    var cur = { id: null, i: 0 }, lastFocus = null;
    function render(fresh) {
      var p = projects[cur.id]; if (!p) return;
      var ph = p.photos[cur.i];
      if (fresh) { lbImg.classList.remove('is-new'); void lbImg.offsetWidth; lbImg.classList.add('is-new'); }
      lbImg.src = ph.src; lbImg.alt = ph.alt; lbImg.width = ph.w; lbImg.height = ph.h;
      lbCount.textContent = (cur.i + 1) + ' / ' + p.photos.length;
      lbCat.textContent = p.catName; lbTitle.textContent = p.title; lbCap.textContent = ph.alt;
      var next = p.photos[(cur.i + 1) % p.photos.length]; if (next) { var pre = new Image(); pre.src = next.src; }
    }
    function open(id, i, from) {
      if (!projects[id]) return;
      cur = { id: id, i: i || 0 }; lastFocus = from || document.activeElement;
      lb.hidden = false; document.body.classList.add('lb-open'); render(true);
      $('.lb-x', lb).focus();
    }
    function close() { lb.hidden = true; document.body.classList.remove('lb-open'); if (lastFocus && lastFocus.focus) lastFocus.focus(); }
    function step(d) { var p = projects[cur.id]; if (!p) return; cur.i = (cur.i + d + p.photos.length) % p.photos.length; render(true); }
    $$('.tile-btn').forEach(function (b) {
      b.addEventListener('click', function () {
        var t = b.closest('.tile');
        open(t.getAttribute('data-project'), parseInt(t.getAttribute('data-index') || '0', 10), b);
      });
    });
    $('.lb-x', lb).addEventListener('click', close);
    $('.lb-nav.prev', lb).addEventListener('click', function () { step(-1); });
    $('.lb-nav.next', lb).addEventListener('click', function () { step(1); });
    lb.addEventListener('click', function (e) { if (e.target === lb || e.target.classList.contains('lb-stage')) close(); });
    document.addEventListener('keydown', function (e) {
      if (lb.hidden) return;
      if (e.key === 'Escape') close();
      else if (e.key === 'ArrowRight') step(1);
      else if (e.key === 'ArrowLeft') step(-1);
    });
    var sx = 0, sy = 0;
    lb.addEventListener('touchstart', function (e) { sx = e.touches[0].clientX; sy = e.touches[0].clientY; }, { passive: true });
    lb.addEventListener('touchend', function (e) {
      var dx = e.changedTouches[0].clientX - sx, dy = e.changedTouches[0].clientY - sy;
      if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(dy)) step(dx < 0 ? 1 : -1);
      else if (dy > 90 && Math.abs(dx) < 60) close();
    }, { passive: true });
  }

  /* ---------- before / after sliders ---------- */
  $$('.ba').forEach(function (ba) {
    var r = $('input', ba);
    if (!r) return;
    var set = function () { ba.style.setProperty('--pos', r.value + '%'); };
    r.addEventListener('input', set); set();
  });

  /* ---------- copy buttons ---------- */
  function copyText(text, btn) {
    var done = function () {
      if (!btn) return;
      var old = btn.textContent; btn.textContent = 'Copied'; btn.classList.add('is-done');
      setTimeout(function () { btn.textContent = old; btn.classList.remove('is-done'); }, 1600);
    };
    var fallback = function () {
      var ta = document.createElement('textarea'); ta.value = text; ta.setAttribute('readonly', ''); ta.style.position = 'fixed'; ta.style.left = '-9999px';
      document.body.appendChild(ta); ta.select();
      try { document.execCommand('copy'); done(); } catch (e) { window.getSelection().removeAllRanges(); }
      document.body.removeChild(ta);
    };
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, fallback);
    else fallback();
  }
  $$('[data-copy]').forEach(function (b) { b.addEventListener('click', function () { copyText(b.getAttribute('data-copy'), b); }); });

  /* ---------- project planner ---------- */
  var planner = $('.planner');
  var form = $('#contactForm');
  if (planner) {
    var STEPS = [
      { key: 'type', q: 'What are we building?', opts: ['Kitchen', 'Bathroom', 'Basement', 'Deck', 'Living room', 'Something else'] },
      { key: 'stage', q: 'Where are you at with it?', opts: ['Just starting to think about it', 'I have ideas and photos saved', 'Ready to get a quote', 'Something needs fixing'] },
      { key: 'when', q: 'When would you like to start?', opts: ['As soon as possible', 'In the next 1 to 3 months', '3 to 6 months out', 'Flexible'] },
      { key: 'budget', q: 'Rough budget range?', opts: ['Under $10k', '$10k to $25k', '$25k to $50k', '$50k and up', 'Not sure yet'] }
    ];
    var answers = {}, sIdx = 0;
    var body = $('.planner-body', planner), prog = $$('.planner-prog i', planner), label = $('.planner-step', planner);
    function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }
    function brief() {
      var t = answers.type || 'home improvement';
      var lines = ['Hi Ryan, I am looking at a ' + t.toLowerCase() + ' project.'];
      if (answers.stage) lines.push('Where I am at: ' + answers.stage.charAt(0).toLowerCase() + answers.stage.slice(1) + '.');
      if (answers.when) lines.push('Timing: ' + answers.when.charAt(0).toLowerCase() + answers.when.slice(1) + '.');
      if (answers.budget) lines.push('Rough budget: ' + answers.budget.charAt(0).toLowerCase() + answers.budget.slice(1) + '.');
      lines.push('Could you reach out to set up a walkthrough and free quote?');
      return lines.join(' ');
    }
    function paint() {
      body.innerHTML = '';
      prog.forEach(function (p, i) { p.classList.toggle('is-on', i <= Math.min(sIdx, STEPS.length - 1)); });
      var screen = el('div', 'p-screen');
      if (sIdx < STEPS.length) {
        var s = STEPS[sIdx];
        label.textContent = 'Step ' + (sIdx + 1) + ' of ' + STEPS.length;
        screen.appendChild(el('h3', 'planner-q', s.q));
        var opts = el('div', 'planner-opts');
        s.opts.forEach(function (o) {
          var b = el('button', 'opt', o); b.type = 'button'; b.setAttribute('aria-pressed', String(answers[s.key] === o));
          b.addEventListener('click', function () { answers[s.key] = o; sIdx++; paint(); });
          opts.appendChild(b);
        });
        screen.appendChild(opts);
        var foot = el('div', 'planner-foot');
        var back = el('button', 'btn btn-ghost btn-sm', 'Back'); back.type = 'button'; back.disabled = sIdx === 0;
        back.addEventListener('click', function () { if (sIdx > 0) { sIdx--; paint(); } });
        var skip = el('button', 'btn btn-ghost btn-sm', 'Skip'); skip.type = 'button';
        skip.addEventListener('click', function () { sIdx++; paint(); });
        foot.appendChild(back); foot.appendChild(skip); screen.appendChild(foot);
      } else {
        label.textContent = 'Your brief';
        var res = el('div', 'planner-result');
        res.appendChild(el('h3', 'planner-q', 'Here is your project brief'));
        var text = brief();
        var pre = el('div', 'brief', text);
        res.appendChild(pre);
        var row = el('div', 'cta-row');
        var send = el('a', 'btn btn-primary', 'Send this to Ryan'); send.href = '#contact';
        send.addEventListener('click', function () {
          if (!form) return;
          var msg = $('#message', form); if (msg) msg.value = text;
          var sel = $('#service', form);
          if (sel && answers.type) { $$('option', sel).forEach(function (o) { if (o.textContent.toLowerCase().indexOf(answers.type.toLowerCase().split(' ')[0]) === 0) sel.value = o.value; }); }
          setTimeout(function () { var n = $('#name', form); if (n) n.focus({ preventScroll: true }); }, 600);
        });
        var cp = el('button', 'btn btn-ghost', 'Copy brief'); cp.type = 'button';
        cp.addEventListener('click', function () { copyText(text, null); cp.textContent = 'Copied'; setTimeout(function () { cp.textContent = 'Copy brief'; }, 1600); });
        var again = el('button', 'btn btn-ghost', 'Start over'); again.type = 'button';
        again.addEventListener('click', function () { answers = {}; sIdx = 0; paint(); });
        row.appendChild(send); row.appendChild(cp); row.appendChild(again);
        res.appendChild(row);
        screen.appendChild(res);
      }
      body.appendChild(screen);
    }
    paint();
  }

  /* ---------- contact form ---------- */
  if (form) {
    var endpoint = form.getAttribute('data-endpoint') || '';
    var phoneRaw = form.getAttribute('data-phone') || '';
    var email = form.getAttribute('data-email') || '';
    var msgBox = $('.form-msg', form.parentNode);
    function composed() {
      var v = function (id) { var e = $('#' + id, form); return e ? e.value.trim() : ''; };
      var pref = (form.querySelector('input[name="contactPref"]:checked') || {}).value || '';
      var parts = [];
      if (v('message')) parts.push(v('message'));
      var who = [v('name'), v('phone'), v('email')].filter(Boolean).join(' / ');
      if (who) parts.push('Reach me at: ' + who + (pref ? ' (prefer ' + pref.toLowerCase() + ')' : ''));
      if (v('service')) parts.push('Project type: ' + $('#service option:checked', form).textContent);
      return parts.join('\n');
    }
    function showMsg(kind, title, text, withActions) {
      if (!msgBox) return;
      msgBox.innerHTML = '';
      msgBox.classList.toggle('is-fallback', kind === 'fallback');
      var h = document.createElement('h3'); h.textContent = title; msgBox.appendChild(h);
      var p = document.createElement('p'); p.textContent = text; msgBox.appendChild(p);
      if (withActions) {
        var body = composed();
        var pre = document.createElement('div'); pre.className = 'brief'; pre.textContent = body; msgBox.appendChild(pre);
        var row = document.createElement('div'); row.className = 'cta-row';
        var cp = document.createElement('button'); cp.type = 'button'; cp.className = 'btn btn-primary'; cp.textContent = 'Copy message';
        cp.addEventListener('click', function () { copyText(body, null); cp.textContent = 'Copied'; setTimeout(function () { cp.textContent = 'Copy message'; }, 1600); });
        row.appendChild(cp);
        if (phoneRaw) { var sms = document.createElement('a'); sms.className = 'btn btn-ghost'; sms.href = 'sms:' + phoneRaw + '?body=' + encodeURIComponent(body); sms.textContent = 'Text Ryan'; row.appendChild(sms); }
        if (email) { var ml = document.createElement('a'); ml.className = 'btn btn-ghost'; ml.href = 'mailto:' + email + '?subject=' + encodeURIComponent('Project inquiry from the website') + '&body=' + encodeURIComponent(body); ml.textContent = 'Email Ryan'; row.appendChild(ml); }
        msgBox.appendChild(row);
      }
      msgBox.hidden = false;
      msgBox.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth', block: 'nearest' });
    }
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      if ($('#company', form) && $('#company', form).value) return; // honeypot
      if (!form.reportValidity()) return;
      var btn = $('button[type="submit"]', form);
      if (!endpoint) { showMsg('fallback', 'Almost there', 'This preview is not wired to an inbox yet. Copy your message and text or email it to Ryan, and he will get right back to you.', true); return; }
      btn.disabled = true; btn.textContent = 'Sending...';
      var data = {};
      $$('input, select, textarea', form).forEach(function (f) { if (f.name && f.type !== 'radio') data[f.name] = f.value; });
      data.contactPref = (form.querySelector('input[name="contactPref"]:checked') || {}).value || '';
      data._subject = 'New project inquiry from yoergerrenovations.com';
      fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' }, body: JSON.stringify(data) })
        .then(function (r) { if (!r.ok) throw new Error('bad status'); showMsg('ok', 'Thanks, it is on its way', 'Ryan will reach out to set up a walkthrough. If it is urgent, call or text ' + (form.getAttribute('data-phone-pretty') || '') + '.', false); form.reset(); })
        .catch(function () { showMsg('fallback', 'That did not go through', 'No problem. Copy your message and text or email it to Ryan directly.', true); })
        .then(function () { btn.disabled = false; btn.textContent = 'Send my request'; });
    });
  }

  /* ---------- misc ---------- */
  var y = $('#year'); if (y) y.textContent = new Date().getFullYear();
  var toTop = $('.to-top'); if (toTop) toTop.addEventListener('click', function () { window.scrollTo({ top: 0, behavior: reduce ? 'auto' : 'smooth' }); });
  // mark current nav link
  var path = location.pathname.replace(/index\.html$/, '');
  $$('.nav a, .mobile-nav a').forEach(function (a) {
    var href = a.getAttribute('href') || '';
    if (href.indexOf('#') === 0) return;
    try { var u = new URL(href, location.href); if (u.pathname.replace(/index\.html$/, '') === path) a.setAttribute('aria-current', 'page'); } catch (e) {}
  });
})();
