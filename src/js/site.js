/* Yoerger Renovations - site.js (no dependencies, no scroll listeners: IntersectionObserver + CSS scroll timelines) */
(function () {
  'use strict';
  var root = document.documentElement;
  root.classList.add('js');
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var hasIO = 'IntersectionObserver' in window;
  var $ = function (s, c) { return (c || document).querySelector(s); };
  var $$ = function (s, c) { return Array.prototype.slice.call((c || document).querySelectorAll(s)); };

  /* ---------- header shadow + mobile call bar: observe the top of the page and the hero ---------- */
  var head = $('.site-head');
  var mobileCta = $('.mobile-cta');
  if (hasIO) {
    var sentinel = document.createElement('div');
    sentinel.setAttribute('aria-hidden', 'true');
    sentinel.style.cssText = 'position:absolute;top:0;left:0;width:1px;height:24px;pointer-events:none;';
    document.body.insertBefore(sentinel, document.body.firstChild);
    new IntersectionObserver(function (es) { if (head) head.classList.toggle('is-scrolled', !es[0].isIntersecting); }).observe(sentinel);
    var heroEl = $('.hero') || $('.page-hero');
    if (mobileCta && heroEl) {
      new IntersectionObserver(function (es) { mobileCta.classList.toggle('is-on', !es[0].isIntersecting); }, { rootMargin: '0px 0px -35% 0px' }).observe(heroEl);
    } else if (mobileCta) mobileCta.classList.add('is-on');
  } else if (mobileCta) mobileCta.classList.add('is-on');

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

  /* ---------- hero: the room word, the photo and its caption change together ---------- */
  var rot = $('.rot');
  if (rot) {
    var words = $$('.word', rot);
    var slides = $$('.hero-slide');
    var cap = $('#heroCap');
    var idx = 0, timer = null, MS = 4200;
    var show = function (n) {
      var prev = idx; idx = (n + words.length) % words.length;
      words.forEach(function (w, i) {
        w.classList.toggle('is-on', i === idx);
        w.classList.toggle('is-out', i === prev && prev !== idx);
      });
      var key = words[idx].getAttribute('data-key'), text = '';
      slides.forEach(function (s) {
        var on = s.getAttribute('data-key') === key;
        if (on) { if (s.getAttribute('loading') === 'lazy') s.removeAttribute('loading'); text = s.getAttribute('data-caption') || ''; }
        s.classList.toggle('is-on', on);
      });
      if (cap && prev !== idx) {
        cap.classList.add('is-swapping');
        setTimeout(function () { cap.textContent = text; cap.classList.remove('is-swapping'); }, 350);
      }
    };
    var stop = function () { if (timer) { clearInterval(timer); timer = null; } };
    var start = function () { stop(); if (!reduce) timer = setInterval(function () { show(idx + 1); }, MS); };
    document.addEventListener('visibilitychange', function () { if (document.hidden) stop(); else start(); });
    var heroBox = $('.hero-media');
    if (heroBox) { heroBox.addEventListener('mouseenter', stop); heroBox.addEventListener('mouseleave', start); }
    show(0); start();
  }

  /* ---------- reveal on scroll ---------- */
  var revealEls = $$('[data-reveal]');
  if (hasIO && !reduce) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
    revealEls.forEach(function (el) { io.observe(el); });
  } else {
    revealEls.forEach(function (el) { el.classList.add('in'); });
  }

  /* ---------- process: a step fills once it passes the upper two-thirds of the screen ---------- */
  var stepEls = $$('.steps .step');
  if (hasIO && !reduce && stepEls.length) {
    var so = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { e.target.classList.toggle('is-done', e.isIntersecting || e.boundingClientRect.top < 0); });
    }, { rootMargin: '0px 0px -35% 0px' });
    stepEls.forEach(function (s) { so.observe(s); });
  } else {
    stepEls.forEach(function (s) { s.classList.add('is-done'); });
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
    var render = function (fresh) {
      var p = projects[cur.id]; if (!p) return;
      var ph = p.photos[cur.i];
      if (fresh) { lbImg.classList.remove('is-new'); void lbImg.offsetWidth; lbImg.classList.add('is-new'); }
      lbImg.src = ph.src; lbImg.alt = ph.alt; lbImg.width = ph.w; lbImg.height = ph.h;
      lbCount.textContent = (cur.i + 1) + ' / ' + p.photos.length;
      lbCat.textContent = p.catName; lbTitle.textContent = p.title; lbCap.textContent = ph.alt;
      var next = p.photos[(cur.i + 1) % p.photos.length]; if (next) { var pre = new Image(); pre.src = next.src; }
    };
    var open = function (id, i, from) {
      if (!projects[id]) return;
      cur = { id: id, i: i || 0 }; lastFocus = from || document.activeElement;
      lb.hidden = false; document.body.classList.add('lb-open'); render(true);
      $('.lb-x', lb).focus();
    };
    var close = function () { lb.hidden = true; document.body.classList.remove('lb-open'); if (lastFocus && lastFocus.focus) lastFocus.focus(); };
    var step = function (d) { var p = projects[cur.id]; if (!p) return; cur.i = (cur.i + d + p.photos.length) % p.photos.length; render(true); };
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
      { key: 'type', q: 'What are we building?', opts: ['Kitchen', 'Bathroom', 'Basement', 'Deck', 'Living room', 'Handyman job', 'Something else'] },
      { key: 'stage', q: 'Where are you at with it?', opts: ['Just starting to think about it', 'I have ideas and photos saved', 'Ready to get a quote', 'Something needs fixing'] },
      { key: 'when', q: 'When would you like to start?', opts: ['As soon as possible', 'In the next 1 to 3 months', '3 to 6 months out', 'Flexible'] },
      { key: 'budget', q: 'Rough budget range?', opts: ['Under $10k', '$10k to $25k', '$25k to $50k', '$50k and up', 'Not sure yet'] }
    ];
    var answers = {}, sIdx = 0;
    var body = $('.planner-body', planner), prog = $$('.planner-prog i', planner), label = $('.planner-step', planner);
    var el = function (tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };
    var brief = function () {
      var t = answers.type || 'home improvement';
      var lines = ['Hi Ryan, I am looking at a ' + t.toLowerCase() + ' project.'];
      if (answers.stage) lines.push('Where I am at: ' + answers.stage.charAt(0).toLowerCase() + answers.stage.slice(1) + '.');
      if (answers.when) lines.push('Timing: ' + answers.when.charAt(0).toLowerCase() + answers.when.slice(1) + '.');
      if (answers.budget) lines.push('Rough budget: ' + answers.budget.charAt(0).toLowerCase() + answers.budget.slice(1) + '.');
      lines.push('Could you reach out to set up a walkthrough and free quote?');
      return lines.join(' ');
    };
    var paint = function () {
      body.innerHTML = '';
      prog.forEach(function (p, i) { p.classList.toggle('is-on', i <= Math.min(sIdx, STEPS.length - 1)); });
      var screen = el('div', 'p-screen');
      if (sIdx < STEPS.length) {
        var s = STEPS[sIdx];
        label.textContent = 'Question ' + (sIdx + 1) + ' of ' + STEPS.length;
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
        res.appendChild(el('div', 'brief', text));
        var row = el('div', 'cta-row');
        var send = el('a', 'btn btn-primary', 'Get a free quote'); send.href = '#contact';
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
    };
    paint();
  }

  /* ---------- contact form ---------- */
  if (form) {
    var endpoint = form.getAttribute('data-endpoint') || '';
    var phoneRaw = form.getAttribute('data-phone') || '';
    var email = form.getAttribute('data-email') || '';
    var msgBox = $('.form-msg', form.parentNode);
    var submitBtn = $('button[type="submit"]', form);
    var submitHTML = submitBtn ? submitBtn.innerHTML : '';
    var composed = function () {
      var v = function (id) { var e = $('#' + id, form); return e ? e.value.trim() : ''; };
      var pref = (form.querySelector('input[name="contactPref"]:checked') || {}).value || '';
      var parts = [];
      if (v('message')) parts.push(v('message'));
      var who = [v('name'), v('phone'), v('email')].filter(Boolean).join(' / ');
      if (who) parts.push('Reach me at: ' + who + (pref ? ' (prefer ' + pref.toLowerCase() + ')' : ''));
      if (v('service')) parts.push('Project type: ' + $('#service option:checked', form).textContent);
      return parts.join('\n');
    };
    var showMsg = function (kind, title, text, withActions) {
      if (!msgBox) return;
      msgBox.innerHTML = '';
      msgBox.classList.toggle('is-fallback', kind === 'fallback');
      var h = document.createElement('h3'); h.textContent = title; msgBox.appendChild(h);
      var p = document.createElement('p'); p.textContent = text; msgBox.appendChild(p);
      if (withActions) {
        var bodyText = composed();
        var pre = document.createElement('div'); pre.className = 'brief'; pre.textContent = bodyText; msgBox.appendChild(pre);
        var row = document.createElement('div'); row.className = 'cta-row';
        var cp = document.createElement('button'); cp.type = 'button'; cp.className = 'btn btn-primary'; cp.textContent = 'Copy message';
        cp.addEventListener('click', function () { copyText(bodyText, null); cp.textContent = 'Copied'; setTimeout(function () { cp.textContent = 'Copy message'; }, 1600); });
        row.appendChild(cp);
        if (phoneRaw) { var sms = document.createElement('a'); sms.className = 'btn btn-ghost'; sms.href = 'sms:' + phoneRaw + '?body=' + encodeURIComponent(bodyText); sms.textContent = 'Text Ryan'; row.appendChild(sms); }
        if (email) { var ml = document.createElement('a'); ml.className = 'btn btn-ghost'; ml.href = 'mailto:' + email + '?subject=' + encodeURIComponent('Project inquiry from the website') + '&body=' + encodeURIComponent(bodyText); ml.textContent = 'Email Ryan'; row.appendChild(ml); }
        msgBox.appendChild(row);
      }
      msgBox.hidden = false;
      msgBox.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth', block: 'nearest' });
    };
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      if ($('#company', form) && $('#company', form).value) return; // honeypot
      if (!form.reportValidity()) return;
      if (!endpoint) { showMsg('fallback', 'Almost there', 'This preview is not wired to an inbox yet. Copy your message and text or email it to Ryan, and he will get right back to you.', true); return; }
      submitBtn.disabled = true; submitBtn.textContent = 'Sending...';
      var data = {};
      $$('input, select, textarea', form).forEach(function (f) { if (f.name && f.type !== 'radio') data[f.name] = f.value; });
      data.contactPref = (form.querySelector('input[name="contactPref"]:checked') || {}).value || '';
      data._subject = 'New project inquiry from yoergerrenovations.com';
      fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' }, body: JSON.stringify(data) })
        .then(function (r) { if (!r.ok) throw new Error('bad status'); showMsg('ok', 'Thanks, it is on its way', 'Ryan will reach out to set up a walkthrough. If it is urgent, call or text ' + (form.getAttribute('data-phone-pretty') || '') + '.', false); form.reset(); })
        .catch(function () { showMsg('fallback', 'That did not go through', 'No problem. Copy your message and text or email it to Ryan directly.', true); })
        .then(function () { submitBtn.disabled = false; submitBtn.innerHTML = submitHTML; });
    });
  }

  /* ---------- misc ---------- */
  var y = $('#year'); if (y) y.textContent = new Date().getFullYear();
  var toTop = $('.to-top'); if (toTop) toTop.addEventListener('click', function () { window.scrollTo({ top: 0, behavior: reduce ? 'auto' : 'smooth' }); });

  /* ---------- nav highlight: the section crossing a line 38% down the screen, or the page you are on ---------- */
  var path = location.pathname.replace(/index\.html$/, '');
  var spy = [];
  $$('.nav a, .mobile-nav a').forEach(function (a) {
    var href = a.getAttribute('href') || '';
    var u; try { u = new URL(href, location.href); } catch (e) { return; }
    var samePage = u.pathname.replace(/index\.html$/, '') === path;
    if (samePage && u.hash) { spy.push({ el: a, id: u.hash.slice(1) }); return; }
    if (!u.hash && /work/.test(u.pathname) && !samePage && document.getElementById('work')) { spy.push({ el: a, id: 'work' }); return; }
    if (samePage && !u.hash) a.setAttribute('aria-current', 'page');
    if (!samePage && $('.page-service') && /#services$/.test(href)) a.classList.add('is-active');
  });
  if (spy.length && hasIO) {
    var current = null;
    var setActive = function (id) { current = id; spy.forEach(function (s) { s.el.classList.toggle('is-active', s.id === id); }); };
    var spyIO = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) setActive(e.target.id);
        else if (e.target.id === current) setActive(null);   // left the line and nothing else has claimed it
      });
    }, { rootMargin: '-38% 0px -61% 0px' });
    var seen = {};
    spy.forEach(function (s) { var t = document.getElementById(s.id); if (t && !seen[s.id]) { seen[s.id] = 1; spyIO.observe(t); } });
  }
})();
