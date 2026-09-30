/**
 * Yoerger Renovations - quote form mailer (Google Apps Script web app)
 *
 * The website's contact form posts here (JSON, photos as base64) and this emails the request to
 * OWNER_EMAIL with the photos attached. Reply in Gmail and it goes straight to the customer.
 *
 * Setup (once, signed in to the Google account that should send the emails):
 *   1. script.google.com > New project. Replace the sample code with this file. Save.
 *   2. Pick testSend in the toolbar and click Run. Approve the permissions (it is your own script, so
 *      "Google hasn't verified this app" > Advanced > Go to project is expected). A test email arrives.
 *   3. Deploy > New deployment > type Web app. Execute as: Me. Who has access: Anyone. Deploy.
 *   4. Copy the Web app URL (ends in /exec) into formEndpoint in src/data/site.json, rebuild, publish.
 * After editing this script later: Deploy > Manage deployments > edit > Version: New version, so the
 * same URL keeps working.
 */

var OWNER_EMAIL = 'YoergerRenovations@gmail.com';
var MAX_FILES = 8;
var MAX_TOTAL_BYTES = 20 * 1024 * 1024;   // Gmail caps a message at 25 MB
var MAX_PER_HOUR = 40;                     // spam brake; real customers never get near it
var ALLOWED_TYPES = /^(image\/(jpeg|png|webp|gif|heic|heif)|application\/pdf)$/;

function doPost(e) {
  try {
    var d = JSON.parse((e && e.postData && e.postData.contents) || '{}');
    if (d.company) return reply_({ ok: true });            // honeypot field filled: a bot, pretend it worked
    if (!underHourlyLimit_()) return reply_({ ok: false, error: 'busy' });

    var f = {
      name: clean_(d.name, 120), phone: clean_(d.phone, 40), email: clean_(d.email, 200),
      service: clean_(d.serviceLabel || d.service, 80), pref: clean_(d.contactPref, 20),
      message: clean_(d.message, 5000), page: clean_(d.page, 300)
    };
    if (!f.name || !(f.email || f.phone)) return reply_({ ok: false, error: 'missing' });

    var files = Array.isArray(d.files) ? d.files.slice(0, MAX_FILES) : [];
    var blobs = [], skipped = 0, total = 0;
    files.forEach(function (file, i) {
      var type = String((file && file.type) || '').toLowerCase();
      if (!ALLOWED_TYPES.test(type)) { skipped++; return; }
      var bytes = Utilities.base64Decode(String(file.data || ''));
      if (total + bytes.length > MAX_TOTAL_BYTES) { skipped++; return; }
      total += bytes.length;
      blobs.push(Utilities.newBlob(bytes, type, fileName_(file.name, i, type)));
    });

    var rows = [
      ['Name', f.name], ['Phone', f.phone], ['Email', f.email],
      ['Best way to reach', f.pref], ['Project type', f.service],
      ['Photos', blobs.length ? blobs.length + ' attached' + (skipped ? ' (' + skipped + ' skipped: too large or not a photo/PDF)' : '') : 'none']
    ];
    var text = rows.map(function (r) { return r[0] + ': ' + (r[1] || '-'); }).join('\n') +
      '\n\n' + (f.message || '(no message)') + '\n\nSent from ' + (f.page || 'the website contact form');
    var html = '<div style="font:15px/1.5 Arial,sans-serif;color:#17231a">' +
      '<h2 style="margin:0 0 12px;font-size:20px">New quote request from ' + esc_(f.name) + '</h2>' +
      '<table style="border-collapse:collapse;margin-bottom:16px">' + rows.map(function (r) {
        return '<tr><td style="padding:4px 16px 4px 0;color:#56665a;white-space:nowrap">' + esc_(r[0]) + '</td>' +
          '<td style="padding:4px 0"><b>' + esc_(r[1] || '-') + '</b></td></tr>';
      }).join('') + '</table>' +
      '<div style="white-space:pre-wrap;background:#f1f4ec;border-left:3px solid #2e5a2a;padding:12px 14px">' +
      esc_(f.message || '(no message)') + '</div>' +
      '<p style="color:#56665a;font-size:13px">Reply to this email to answer ' + esc_(f.name.split(' ')[0]) +
      ' directly. Sent from ' + esc_(f.page || 'the website contact form') + '.</p></div>';

    var mail = {
      to: OWNER_EMAIL,
      subject: 'Quote request: ' + f.name + (f.service ? ' - ' + f.service : '') + (blobs.length ? ' (' + blobs.length + ' photo' + (blobs.length > 1 ? 's' : '') + ')' : ''),
      body: text, htmlBody: html, name: 'Yoerger Renovations website', attachments: blobs
    };
    if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(f.email)) mail.replyTo = f.email;
    MailApp.sendEmail(mail);
    return reply_({ ok: true, photos: blobs.length, skipped: skipped });
  } catch (err) {
    console.error(err);
    return reply_({ ok: false, error: 'server' });
  }
}

// Visiting the web app URL in a browser just confirms it is running.
function doGet() { return reply_({ ok: true, service: 'Yoerger Renovations quote mailer' }); }

// Run once from the editor to grant permission and confirm emails arrive.
function testSend() {
  var pixel = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';   // 1x1 PNG
  var res = doPost({ postData: { contents: JSON.stringify({
    name: 'Test Customer', email: OWNER_EMAIL, phone: '(330) 555-0100', service: 'kitchens', serviceLabel: 'Kitchen remodeling',
    contactPref: 'Text', message: 'This is a test from the quote mailer setup. If you can read this, the form works.',
    page: 'testSend in the Apps Script editor', files: [{ name: 'test-photo.png', type: 'image/png', data: pixel }]
  }) } });
  console.log(res.getContent());
}

function reply_(obj) { return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON); }

function clean_(v, max) { return String(v == null ? '' : v).replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '').trim().slice(0, max); }

function esc_(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }

function fileName_(name, i, type) {
  var ext = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/gif': 'gif', 'image/heic': 'heic', 'image/heif': 'heif', 'application/pdf': 'pdf' }[type] || 'bin';
  var base = String(name || '').replace(/\.[^.]+$/, '').replace(/[^\w\- ]+/g, '').trim().slice(0, 60) || 'photo-' + (i + 1);
  return base + '.' + ext;
}

function underHourlyLimit_() {
  var cache = CacheService.getScriptCache();
  var key = 'sent-' + Utilities.formatDate(new Date(), 'UTC', 'yyyyMMddHH');
  var n = Number(cache.get(key) || 0);
  if (n >= MAX_PER_HOUR) return false;
  cache.put(key, String(n + 1), 3600);
  return true;
}
