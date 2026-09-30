# Yoerger Renovations - static site build
# Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1 [-Artifact] [-Force] [-Out <folder>]
#   photos\<project-folder>\project.txt + photos  ->  docs\ (deployable site)  [+ artifact\ (flat preview copy)]
param(
  [switch]$Artifact,
  [switch]$Force,
  [string]$Out
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = $PSScriptRoot
$src = Join-Path $root "src"
$photosDir = Join-Path $root "photos"
$out = if ($Out) { $Out } else { Join-Path $root "docs" }
$artOut = Join-Path $root "artifact"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$today = Get-Date -Format "yyyy-MM-dd"
$sw = [Diagnostics.Stopwatch]::StartNew()
$warnings = New-Object System.Collections.ArrayList

function Log($m) { Write-Host ("[{0,6:N1}s] {1}" -f $sw.Elapsed.TotalSeconds, $m) }
function Warn($m) { [void]$warnings.Add($m); Write-Host ("  WARNING: {0}" -f $m) -ForegroundColor Yellow }
function Read-Text($p) { return [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8) }
function Ensure-Dir($d) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force $d | Out-Null } }
function Write-Text($p, $t) { Ensure-Dir (Split-Path $p -Parent); [IO.File]::WriteAllText($p, $t, $utf8) }
function Esc($s) { return [System.Net.WebUtility]::HtmlEncode([string]$s) }
function Slug($s) { return (([string]$s).ToLowerInvariant() -replace "[^a-z0-9]+", "-").Trim("-") }
function Attr($s) { return ([string]$s).Replace("&", "&amp;").Replace('"', "&quot;").Replace("<", "&lt;") }

# ---------------------------------------------------------------- images
$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
function Load-Image($path) {
  $bytes = [IO.File]::ReadAllBytes($path)
  $ms = New-Object IO.MemoryStream(, $bytes)
  $img = [System.Drawing.Image]::FromStream($ms, $false, $true)
  if ($img.PropertyIdList -contains 274) {
    $o = $img.GetPropertyItem(274).Value[0]
    switch ($o) {
      3 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
      6 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
      8 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
    }
  }
  return $img
}
function Save-Jpeg($bmp, $path, $q) {
  Ensure-Dir (Split-Path $path -Parent)
  $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
  $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$q)
  $bmp.Save($path, $jpegCodec, $ep)
  $ep.Dispose()
}
function New-Canvas($w, $h) {
  $b = New-Object System.Drawing.Bitmap([int]$w, [int]$h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [System.Drawing.Graphics]::FromImage($b)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  return @($b, $g)
}
function Is-Fresh($srcPath, $destPath) {
  if ($Force) { return $false }
  if (-not (Test-Path $destPath)) { return $false }
  return ((Get-Item $destPath).LastWriteTimeUtc -ge (Get-Item $srcPath).LastWriteTimeUtc)
}
function Fit-Image($srcPath, $destPath, $maxW, $q) {
  if (Is-Fresh $srcPath $destPath) { $d = Load-Image $destPath; $r = @($d.Width, $d.Height); $d.Dispose(); return $r }
  $img = Load-Image $srcPath
  $scale = [Math]::Min(1.0, $maxW / $img.Width)
  $w = [int][Math]::Round($img.Width * $scale); $h = [int][Math]::Round($img.Height * $scale)
  $c = New-Canvas $w $h
  $c[1].DrawImage($img, 0, 0, $w, $h); $c[1].Dispose()
  Save-Jpeg $c[0] $destPath $q
  $c[0].Dispose(); $img.Dispose()
  return @($w, $h)
}
function Cover-Bitmap($img, $w, $h, $anchorY) {
  $scale = [Math]::Max($w / $img.Width, $h / $img.Height)
  $sw2 = $img.Width * $scale; $sh2 = $img.Height * $scale
  $x = ($w - $sw2) / 2; $y = ($h - $sh2) * $anchorY
  $c = New-Canvas $w $h
  $c[1].DrawImage($img, [single]$x, [single]$y, [single]$sw2, [single]$sh2); $c[1].Dispose()
  return $c[0]
}
function Cover-Image($srcPath, $destPath, $w, $h, $anchorY, $q) {
  if (Is-Fresh $srcPath $destPath) { return }
  $img = Load-Image $srcPath
  $bmp = Cover-Bitmap $img $w $h $anchorY
  Save-Jpeg $bmp $destPath $q
  $bmp.Dispose(); $img.Dispose()
}
function Make-Og($srcPath, $logoPath, $destPath) {
  if ((Is-Fresh $srcPath $destPath) -and (Is-Fresh $logoPath $destPath)) { return }
  $img = Load-Image $srcPath
  $bmp = Cover-Bitmap $img 1200 630 0.5
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $shade = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 330, 1200, 300)), [System.Drawing.Color]::FromArgb(0, 14, 23, 15), [System.Drawing.Color]::FromArgb(170, 14, 23, 15), [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
  $g.FillRectangle($shade, 0, 330, 1200, 300)
  $logo = Load-Image $logoPath
  $lw = 300; $lh = [int]($logo.Height * $lw / $logo.Width)
  $px = 40; $py = 630 - 40 - $lh - 28
  $g.FillRectangle([System.Drawing.Brushes]::White, $px, $py, $lw + 40, $lh + 28)
  $g.DrawImage($logo, $px + 20, $py + 14, $lw, $lh)
  $g.Dispose(); $logo.Dispose()
  Save-Jpeg $bmp $destPath 84
  $bmp.Dispose(); $img.Dispose()
}
function Make-TransparentLogo($srcPath, $destGreen, $destCream) {
  # Keys the logo's white background to transparency, trims the empty margin, and writes two marks:
  # the original green artwork (for light backgrounds) and a cream reverse of it (for dark backgrounds).
  # Returns @(width, height) of the trimmed marks.
  if ((Is-Fresh $srcPath $destGreen) -and (Is-Fresh $srcPath $destCream)) { $d = Load-Image $destGreen; $r = @($d.Width, $d.Height); $d.Dispose(); return $r }
  $img = Load-Image $srcPath
  $w = $img.Width; $h = $img.Height
  $fmt = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
  $bmp = New-Object System.Drawing.Bitmap($w, $h, $fmt)
  $g = [System.Drawing.Graphics]::FromImage($bmp); $g.DrawImage($img, 0, 0, $w, $h); $g.Dispose()
  $bd = $bmp.LockBits((New-Object System.Drawing.Rectangle(0, 0, $w, $h)), [System.Drawing.Imaging.ImageLockMode]::ReadWrite, $fmt)
  $stride = $bd.Stride; $len = $stride * $h
  $bytes = New-Object byte[] $len
  [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $bytes, 0, $len)
  $minX = $w; $minY = $h; $maxX = -1; $maxY = -1
  for ($y = 0; $y -lt $h; $y++) {
    $row = $y * $stride
    for ($x = 0; $x -lt $w; $x++) {
      $i = $row + $x * 4
      $m = $bytes[$i]; if ($bytes[$i + 1] -lt $m) { $m = $bytes[$i + 1] }; if ($bytes[$i + 2] -lt $m) { $m = $bytes[$i + 2] }
      $a = (255 - $m) * 2; if ($a -gt 255) { $a = 255 }
      $bytes[$i + 3] = [byte]$a
      if ($a -gt 24) {
        if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
        if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
      }
    }
  }
  [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $bd.Scan0, $len)
  $bmp.UnlockBits($bd)
  if ($maxX -lt 0) { $minX = 0; $minY = 0; $maxX = $w - 1; $maxY = $h - 1 }
  $pad = 3
  $cx = [Math]::Max(0, $minX - $pad); $cy = [Math]::Max(0, $minY - $pad)
  $cw = [Math]::Min($w - $cx, $maxX - $minX + 1 + 2 * $pad); $ch = [Math]::Min($h - $cy, $maxY - $minY + 1 + 2 * $pad)
  $green = $bmp.Clone((New-Object System.Drawing.Rectangle($cx, $cy, $cw, $ch)), $fmt)
  Ensure-Dir (Split-Path $destGreen -Parent)
  $green.Save($destGreen, [System.Drawing.Imaging.ImageFormat]::Png)
  # cream reverse: gold rules stay brass, everything else in the artwork turns cream
  $cream = $green.Clone((New-Object System.Drawing.Rectangle(0, 0, $cw, $ch)), $fmt)
  $bd2 = $cream.LockBits((New-Object System.Drawing.Rectangle(0, 0, $cw, $ch)), [System.Drawing.Imaging.ImageLockMode]::ReadWrite, $fmt)
  $len2 = $bd2.Stride * $ch
  $b2 = New-Object byte[] $len2
  [System.Runtime.InteropServices.Marshal]::Copy($bd2.Scan0, $b2, 0, $len2)
  for ($i = 0; $i -lt $len2; $i += 4) {
    if ($b2[$i + 3] -eq 0) { continue }
    $bb = [int]$b2[$i]; $gg = [int]$b2[$i + 1]; $rr = [int]$b2[$i + 2]
    if (($rr -gt $gg) -and ($gg -gt $bb) -and (($rr - $bb) -gt 60)) { $b2[$i] = 90; $b2[$i + 1] = 178; $b2[$i + 2] = 214 }
    else { $b2[$i] = 236; $b2[$i + 1] = 246; $b2[$i + 2] = 244 }
  }
  [System.Runtime.InteropServices.Marshal]::Copy($b2, 0, $bd2.Scan0, $len2)
  $cream.UnlockBits($bd2)
  Ensure-Dir (Split-Path $destCream -Parent)
  $cream.Save($destCream, [System.Drawing.Imaging.ImageFormat]::Png)
  $cream.Dispose(); $green.Dispose(); $bmp.Dispose(); $img.Dispose()
  return @($cw, $ch)
}
function Make-TouchIcon($destPath) {
  if ((Test-Path $destPath) -and -not $Force) { return }
  $c = New-Canvas 180 180
  $g = $c[1]
  $g.Clear([System.Drawing.Color]::FromArgb(46, 90, 42))
  $font = New-Object System.Drawing.Font("Impact", 88, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = "Center"; $sf.LineAlignment = "Center"
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
  $g.DrawString("YR", $font, (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(244, 246, 236))), (New-Object System.Drawing.RectangleF(0, -6, 180, 170)), $sf)
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(198, 162, 74))), 44, 140, 92, 8)
  $g.Dispose()
  Ensure-Dir (Split-Path $destPath -Parent)
  $c[0].Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png); $c[0].Dispose()
}

# ---------------------------------------------------------------- config
Log "Loading config"
$cfg = Get-Content (Join-Path $src "data\site.json") -Raw -Encoding UTF8 | ConvertFrom-Json
# ConvertFrom-Json in PowerShell 5.1 hands back a JSON array as one object; unroll it
$services = @((Get-Content (Join-Path $src "data\services.json") -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ })
$svcByKey = @{}; foreach ($s in $services) { $svcByKey[$s.key] = $s }
$domain = $cfg.domain.TrimEnd("/")
$R = "{{root}}"
$customLive = [bool]$cfg.customDomainLive
$basePath = "/"
if (-not $customLive -and $cfg.repo -and ($cfg.repo -split "/").Count -eq 2) { $basePath = "/" + ($cfg.repo -split "/")[1] + "/" }

# ---------------------------------------------------------------- photos -> projects
Log "Scanning photos"
Ensure-Dir $out
$projects = New-Object System.Collections.ArrayList
$projById = @{}
$dirs = @(Get-ChildItem $photosDir -Directory | Sort-Object Name)
foreach ($dir in $dirs) {
  $id = Slug $dir.Name
  $meta = @{ title = $dir.Name; category = ""; location = $cfg.region; summary = ""; featured = "no"; cover = ""; order = "99" }
  $metaPath = Join-Path $dir.FullName "project.txt"
  if (Test-Path $metaPath) {
    foreach ($line in (Get-Content $metaPath -Encoding UTF8)) {
      if ($line -match '^\s*([A-Za-z]+)\s*=\s*(.*)$') { $meta[$matches[1].ToLowerInvariant()] = $matches[2].Trim() }
    }
  } else { Warn "$($dir.Name): no project.txt, using folder name as the title" }
  $cat = Slug $meta.category
  if (-not $svcByKey.ContainsKey($cat)) {
    $guess = $services | Where-Object { $id.StartsWith($_.key) } | Select-Object -First 1
    if ($guess) { $cat = $guess.key } else { Warn "$($dir.Name): category '$($meta.category)' is not one of: $($services.key -join ', '). Skipping."; continue }
  }
  $all = @(Get-ChildItem $dir.FullName -File | Where-Object { $_.Extension -match '^\.(jpe?g|png|heic|heif)$' } | Sort-Object Name)
  $heic = @($all | Where-Object { $_.Extension -match '^\.(heic|heif)$' })
  if ($heic.Count -gt 0) { Warn "$($dir.Name): $($heic.Count) HEIC photo(s) skipped. Export them as JPEG first (iPhone: Settings > Camera > Formats > Most Compatible)." }
  $files = @($all | Where-Object { $_.Extension -match '^\.(jpe?g|png)$' -and $_.BaseName -notmatch '\(before\)\s*$' })
  $befores = @{}
  foreach ($b in ($all | Where-Object { $_.BaseName -match '\(before\)\s*$' })) { $befores[(($b.BaseName -replace '\(before\)\s*$', '').Trim())] = $b }
  if ($files.Count -eq 0) { Warn "$($dir.Name): no photos found. Skipping."; continue }
  $photos = New-Object System.Collections.ArrayList
  $n = 0
  foreach ($f in $files) {
    $n++
    $caption = ($f.BaseName -replace '^\s*\d+[\s._-]*', '') -replace '_', ' '
    $caption = ($caption -replace '\s+', ' ').Trim()
    if (-not $caption) { $caption = "$($meta.title), photo $n" }
    $slug = "{0:D2}-{1}" -f $n, (Slug $caption)
    $rel = "img/work/$id/$slug"
    $big = Fit-Image $f.FullName (Join-Path $out "$rel-1400.jpg") 1400 80
    $sm = Fit-Image $f.FullName (Join-Path $out "$rel-700.jpg") 700 78
    $before = $null
    if ($befores.ContainsKey($f.BaseName)) {
      $bf = $befores[$f.BaseName]
      $bb = Fit-Image $bf.FullName (Join-Path $out "$rel-before-1400.jpg") 1400 80
      $before = "$rel-before-1400.jpg"
    }
    [void]$photos.Add([pscustomobject]@{
      caption = $caption; num = $n; srcFile = $f.FullName
      src1400 = "$rel-1400.jpg"; src700 = "$rel-700.jpg"; w = $big[0]; h = $big[1]; w700 = $sm[0]; portrait = ($big[1] -gt $big[0]); before = $before
    })
  }
  $coverIdx = 0
  if ($meta.cover) { for ($i = 0; $i -lt $photos.Count; $i++) { if (("{0:D2}" -f $photos[$i].num) -eq ("{0:D2}" -f [int]($meta.cover -replace '\D', '0'))) { $coverIdx = $i } } }
  $featured = ($meta.featured -match '^(yes|true|1|y)$')
  $order = 99; [void][int]::TryParse($meta.order, [ref]$order)
  $p = [pscustomobject]@{
    id = $id; title = $meta.title; category = $cat; catName = $svcByKey[$cat].name; location = $meta.location; summary = $meta.summary
    featured = $featured; order = $order; photos = @($photos); coverIdx = $coverIdx
  }
  [void]$projects.Add($p); $projById[$id] = $p
  Log ("  {0,-36} {1,2} photos  {2}" -f $id, $photos.Count, $(if ($featured) { "featured" } else { "" }))
}
$projects = @($projects | Sort-Object @{ e = { if ($_.featured) { 0 } else { 1 } } }, @{ e = { $_.order } }, @{ e = { $_.id } })
$photoCount = ($projects | ForEach-Object { $_.photos.Count } | Measure-Object -Sum).Sum
Log "$($projects.Count) projects, $photoCount photos"

# ---------------------------------------------------------------- brand + hero images
Log "Brand images"
$logoSrc = Join-Path $src "img\logo.jpg"
$logoDims = Make-TransparentLogo $logoSrc (Join-Path $out "img\logo.png") (Join-Path $out "img\logo-light.png")
Log ("  logo trimmed to {0}x{1} (green + cream)" -f $logoDims[0], $logoDims[1])
Make-TouchIcon (Join-Path $out "img\apple-touch-icon.png")
Cover-Image (Join-Path $src "img\ryan-headshot.jpg") (Join-Path $out "img\ryan-headshot.jpg") 800 1000 0.12 84
$heroInfo = @{}
foreach ($s in $services) {
  $parts = $s.hero -split "/"
  $proj = $projById[$parts[0]]
  $ph = $null
  if ($proj) { $ph = $proj.photos | Where-Object { ("{0:D2}" -f $_.num) -eq $parts[1] } | Select-Object -First 1 }
  if (-not $ph) {
    $proj = $projects | Where-Object { $_.category -eq $s.key } | Select-Object -First 1
    if ($proj) { $ph = $proj.photos[$proj.coverIdx] }
  }
  if (-not $ph) { Warn "No hero photo for $($s.name)"; continue }
  $b = Fit-Image $ph.srcFile (Join-Path $out "img\hero\$($s.key)-1800.jpg") 1800 80
  $m = Fit-Image $ph.srcFile (Join-Path $out "img\hero\$($s.key)-1000.jpg") 1000 78
  Make-Og $ph.srcFile $logoSrc (Join-Path $out "img\og\$($s.slug).jpg")
  $heroInfo[$s.key] = [pscustomobject]@{ big = "img/hero/$($s.key)-1800.jpg"; small = "img/hero/$($s.key)-1000.jpg"; w = $b[0]; h = $b[1]; wSmall = $m[0]; alt = $ph.caption; project = $proj }
}
$homeOgSrc = $heroInfo["decks"]; if (-not $homeOgSrc) { $homeOgSrc = $heroInfo.Values | Select-Object -First 1 }
Make-Og $homeOgSrc.project.photos[0].srcFile $logoSrc (Join-Path $out "img\og\home.jpg")

# a hero photo in a 4:3 frame is never cropped: 4:3 shots fill it exactly, anything else (the tall bathroom
# shots) is shown whole over a blurred copy of itself. Same URL twice, so the browser downloads it once.
function Fit-Photo($hi, $sizes, $load, $alt) {
  $img = '<img class="{0}" src="{1}{2}" srcset="{1}{3} {4}w, {1}{2} {5}w" sizes="{6}" width="{5}" height="{7}" alt="{8}" {9} decoding="async">'
  $main = $img -f 'fit-img', $R, $hi.big, $hi.small, $hi.wSmall, $hi.w, $sizes, $hi.h, $alt, $load
  if ([math]::Abs($hi.w / $hi.h - 4 / 3) -le 0.05) { return @{ cls = "fit"; html = $main } }
  $fill = ($img -f 'fit-fill', $R, $hi.big, $hi.small, $hi.wSmall, $hi.w, $sizes, $hi.h, '', $load) -replace '^<img ', '<img aria-hidden="true" '
  return @{ cls = "fit is-tall"; html = $fill + $main }
}

# ---------------------------------------------------------------- templates
Log "Rendering pages"
$T = @{}
foreach ($n in "layout", "layout-artifact", "chrome", "footer", "lightbox", "contact", "home", "service", "work", "404") { $T[$n] = Read-Text (Join-Path $src "templates\$n.html") }
$css = Read-Text (Join-Path $src "css\site.css")
$js = Read-Text (Join-Path $src "js\site.js")
# Phosphor icons (regular weight, MIT), vendored in src\icons. Templates use {{icon-<name>}}.
$icons = @{}
foreach ($f in (Get-ChildItem (Join-Path $src "icons") -Filter *.svg)) {
  $svg = (Read-Text $f.FullName).Trim() -replace '^<svg ', '<svg class="ico" aria-hidden="true" focusable="false" width="20" height="20" '
  $icons["icon-" + $f.BaseName] = $svg
}
$checkSvg = $icons["icon-check"]
$arrowSvg = $icons["icon-arrow-right"]
$sizesTile = "(min-width: 1000px) 33vw, (min-width: 640px) 50vw, 100vw"

function Expand($text, $tokens) {
  for ($pass = 0; $pass -lt 8; $pass++) {
    $before = $text
    foreach ($k in $tokens.Keys) { $text = $text.Replace("{{" + $k + "}}", [string]$tokens[$k]) }
    if ($text -eq $before) { break }
  }
  return $text
}
function Tile($proj, $phIdx, $revealIdx, $wide, $plain = $false) {
  # $plain: masonry tile on the home page (natural shape, no text laid over the photo)
  $ph = $proj.photos[$phIdx]
  $cls = "tile"; if (-not $plain) { if ($ph.portrait) { $cls += " tall" }; if ($wide -and -not $ph.portrait) { $cls += " wide" } }
  $alt = Attr $ph.caption
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append(('<figure class="{0}" data-cat="{1}" data-project="{2}" data-index="{3}" data-reveal style="--i:{4}">' -f $cls, $proj.category, $proj.id, $phIdx, [Math]::Min($revealIdx, 8)))
  if ($ph.before) {
    [void]$sb.Append(('<div class="ba"><img src="{0}{1}" alt="{2}" width="{3}" height="{4}" loading="lazy" decoding="async"><img class="ba-before" src="{0}{5}" alt="Before: {2}" loading="lazy" decoding="async"><span class="ba-tag before">Before</span><span class="ba-tag after">After</span><span class="ba-handle" aria-hidden="true"></span><input type="range" min="0" max="100" value="50" aria-label="Slide to compare before and after"></div>' -f $R, $ph.src1400, $alt, $ph.w, $ph.h, $ph.before))
  } else {
    [void]$sb.Append(('<button class="tile-btn" type="button" aria-label="Open project: {0}"><img src="{1}{2}" srcset="{1}{2} {8}w, {1}{3} {5}w" sizes="{4}" width="{5}" height="{6}" alt="{7}" loading="lazy" decoding="async"></button>' -f (Attr $proj.title), $R, $ph.src700, $ph.src1400, $sizesTile, $ph.w, $ph.h, $alt, $ph.w700))
  }
  if ($plain) { [void]$sb.Append('</figure>') }
  else { [void]$sb.Append(('<figcaption class="tile-cap"><span class="tile-cat">{0}</span><span class="tile-title">{1}</span></figcaption></figure>' -f (Esc $proj.catName), (Esc $proj.title))) }
  return $sb.ToString()
}
function Filters($countBy) {
  $total = 0; foreach ($v in $countBy.Values) { $total += $v }
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append(('<button class="chip" type="button" aria-pressed="true" data-cat="all">All<span class="n">{0}</span></button>' -f $total))
  foreach ($s in $services) {
    $c = 0; if ($countBy.ContainsKey($s.key)) { $c = $countBy[$s.key] }
    if ($c -gt 0) { [void]$sb.Append(('<button class="chip" type="button" aria-pressed="false" data-cat="{0}">{1}<span class="n">{2}</span></button>' -f $s.key, (Esc $s.name), $c)) }
  }
  return $sb.ToString()
}
function ProjectsJson() {
  $o = [ordered]@{}
  foreach ($p in $projects) {
    $o[$p.id] = [ordered]@{
      title = $p.title; catName = $p.catName; summary = $p.summary
      photos = @($p.photos | ForEach-Object { [ordered]@{ src = "$R$($_.src1400)"; alt = $_.caption; w = $_.w; h = $_.h } })
    }
  }
  return (ConvertTo-Json $o -Depth 6 -Compress)
}
function Biz($brief) {
  $b = [ordered]@{
    "@type" = "HomeAndConstructionBusiness"; "@id" = "$domain/#business"
    name = $cfg.name; alternateName = $cfg.shortName; url = "$domain/"; telephone = $cfg.phoneRaw; email = $cfg.email
    image = "$domain/img/og/home.jpg"; logo = "$domain/img/logo.png"
  }
  if (-not $brief) {
    $b.description = "Locally owned remodeling and handyman services based in $($cfg.hub), Ohio $($cfg.zip), serving $($cfg.region): kitchens, bathrooms, basement finishing, custom decks, living rooms and small repairs. Free quotes."
    $b.founder = [ordered]@{ "@type" = "Person"; name = $cfg.owner; jobTitle = "Owner" }
    $b.address = [ordered]@{ "@type" = "PostalAddress"; addressLocality = $cfg.hub; addressRegion = $cfg.state; postalCode = $cfg.zip; addressCountry = "US" }
    $areas = New-Object System.Collections.ArrayList
    foreach ($c in $cfg.counties) { [void]$areas.Add([ordered]@{ "@type" = "AdministrativeArea"; name = "$c, Ohio" }) }
    foreach ($a in $cfg.areas) { [void]$areas.Add([ordered]@{ "@type" = "City"; name = "$a, OH" }) }
    $b.areaServed = @($areas)
    $b.sameAs = @($cfg.facebook)
    $b.priceRange = '$$'
    $b.knowsAbout = @($services | ForEach-Object { $_.serviceName })
    $b.hasOfferCatalog = [ordered]@{ "@type" = "OfferCatalog"; name = "Remodeling services"; itemListElement = @($services | ForEach-Object { [ordered]@{ "@type" = "Offer"; itemOffered = [ordered]@{ "@type" = "Service"; name = $_.serviceName; url = "$domain/$($_.slug)/" } } }) }
  }
  return $b
}
function JsonLd($graph) { return (ConvertTo-Json ([ordered]@{ "@context" = "https://schema.org"; "@graph" = @($graph) }) -Depth 12 -Compress) }

function Build-Site($mode) {
  $flat = ($mode -eq "art")
  $dest = if ($flat) { $artOut } else { $out }
  Ensure-Dir $dest
  $layout = if ($flat) { $T["layout-artifact"] } else { $T["layout"] }
  $workUrl = if ($flat) { "work.html" } else { "{{root}}work/" }
  $svcUrl = @{}; foreach ($s in $services) { $svcUrl[$s.key] = $(if ($flat) { "$($s.slug).html" } else { "{{root}}$($s.slug)/" }) }
  $styles = if ($flat) { "<style>`n$css`n</style>" } else { '<link rel="stylesheet" href="{{root}}css/site.css">' }
  $scripts = if ($flat) { "<script>`n$js`n</script>" } else { '<script src="{{root}}js/site.js" defer></script>' }

  $G = @{
    name = Esc $cfg.name; shortName = Esc $cfg.shortName; owner = Esc $cfg.owner; phone = Esc $cfg.phone; phoneRaw = $cfg.phoneRaw
    email = $cfg.email; facebook = $cfg.facebook; region = Esc $cfg.region; hub = Esc $cfg.hub; domain = $domain
    state = Esc $cfg.state; zip = Esc $cfg.zip; areaLine = Esc $cfg.areaLine; areasOutside = Esc $cfg.areasOutside
    handymanUrl = $(if ($svcUrl.ContainsKey("handyman")) { $svcUrl["handyman"] } else { "{{home}}#services" })
    formEndpoint = $cfg.formEndpoint; year = (Get-Date).Year; workUrl = $workUrl; styles = $styles; scripts = $scripts
    photoCount = $photoCount; projectCount = $projects.Count; logoW = $logoDims[0]; logoH = $logoDims[1]
    footerServices = (($services | ForEach-Object { '<li><a href="{0}">{1}</a></li>' -f $svcUrl[$_.key], (Esc $_.serviceName) }) -join "")
    serviceOptions = (($services | ForEach-Object { '<option value="{0}">{1}</option>' -f $_.key, (Esc $_.serviceName) }) -join "")
    areaChips = (($cfg.areas | ForEach-Object { if ($_ -eq $cfg.hub) { "<li class=""is-home"">$(Esc $_)</li>" } else { "<li>$(Esc $_)</li>" } }) -join "")
    projectsJson = (ProjectsJson)
    chrome = $T["chrome"]; footer = $T["footer"]; lightbox = $T["lightbox"]; contactSection = $T["contact"]
  }
  foreach ($k in $icons.Keys) { $G[$k] = $icons[$k] }
  if ($flat) { $G["home"] = "index.html" }

  # reviews (optional)
  $reviews = ""
  if ($cfg.reviews -and $cfg.reviews.Count -gt 0) {
    $q = ($cfg.reviews | ForEach-Object {
      $who = @($_.name, $_.place, $_.project) | Where-Object { $_ } | ForEach-Object { Esc $_ }
      '<figure class="quote" data-reveal><blockquote>{0}</blockquote><figcaption><cite>{1}</cite></figcaption></figure>' -f (Esc $_.quote), ($who -join " &middot; ")
    }) -join ""
    $reviews = '<section id="reviews" class="sec"><div class="wrap"><header class="sec-head" data-reveal><h2 class="display">What homeowners say</h2></header><div class="quotes">' + $q + '</div></div></section>'
  }

  # ---------- home
  # hero: the rotating room word, its photo and a caption under the photo stay in step
  $slides = New-Object System.Text.StringBuilder; $words = New-Object System.Text.StringBuilder
  $h = 0; $heroCaption = ""
  $heroSizes = "(min-width: 1240px) 590px, (min-width: 900px) 48vw, 100vw"
  # handyman gets a bento tile, not a hero slide; site.json heroOrder sets the sequence (the first one is what
  # a visitor lands on), anything it leaves out follows in services.json order
  $heroList = @($services | Where-Object { $_.inHero -ne $false -and $heroInfo[$_.key] })
  if ($cfg.heroOrder) {
    $ord = @($cfg.heroOrder | ForEach-Object { $_ })
    $heroList = @($ord | ForEach-Object { $k = $_; $heroList | Where-Object { $_.key -eq $k } }) + @($heroList | Where-Object { $ord -notcontains $_.key })
  }
  foreach ($s in $heroList) {
    $hi = $heroInfo[$s.key]
    $on = if ($h -eq 0) { " is-on" } else { "" }
    $ld = if ($h -eq 0) { 'fetchpriority="high"' } else { 'loading="lazy"' }
    if ($h -eq 0) { $heroCaption = Esc $hi.alt }
    $fp = Fit-Photo $hi $heroSizes $ld ''
    [void]$slides.Append(('<div class="hero-slide {0}{1}" data-key="{2}" data-caption="{3}">{4}</div>' -f $fp.cls, $on, $s.key, (Attr $hi.alt), $fp.html))
    [void]$words.Append(('<span class="word{0}" data-key="{1}">{2},</span>' -f $on, $s.key, (Esc $s.noun)))
    $h++
  }
  # services: a bento with exactly one cell per service; photos differ from the hero slides
  $areaKey = @{ "kitchens" = "k"; "bathrooms" = "b"; "basements" = "s"; "decks" = "d"; "living-rooms" = "l"; "handyman" = "h" }
  $bento = New-Object System.Text.StringBuilder; $bi = 0
  foreach ($s in $services) {
    $a = $areaKey[$s.key]; if (-not $a) { Warn "No bento cell for service '$($s.key)'"; continue }
    $ph = $null
    if ($s.card) {
      $parts = $s.card -split "/"; $pr = $projById[$parts[0]]
      if ($pr) { $ph = $pr.photos | Where-Object { ("{0:D2}" -f $_.num) -eq $parts[1] } | Select-Object -First 1 }
      if (-not $ph) { Warn "Bento photo '$($s.card)' not found for $($s.key); using the hero photo" }
    }
    if (-not $ph -and $heroInfo[$s.key]) { $hp = $heroInfo[$s.key].project; $ph = $hp.photos[$hp.coverIdx] }
    $img = ""
    if ($ph) { $img = '<div class="b-media"><img src="{0}{1}" srcset="{0}{1} {2}w, {0}{3} {4}w" sizes="(min-width: 1024px) 50vw, 100vw" width="{4}" height="{5}" alt="{6}" loading="lazy" decoding="async"></div>' -f $R, $ph.src700, $ph.w700, $ph.src1400, $ph.w, $ph.h, (Attr $ph.caption) }
    if ($s.key -eq "handyman") {
      $head = $(if ($s.tickerLabel) { $s.tickerLabel } else { $s.serviceName })
      [void]$bento.Append(('<a class="b-tile b-handy bt-{0}" href="{1}" data-reveal style="--i:{2}"><div class="b-copy"><h3>{3}</h3><p>{4}</p><span class="b-link">See handyman services {5}</span></div>{6}</a>' -f $a, $svcUrl[$s.key], $bi, (Esc $head), (Esc $s.bentoLine), $arrowSvg, $img))
    } else {
      [void]$bento.Append(('<a class="b-tile bt-{0}" href="{1}" data-reveal style="--i:{2}">{3}<div class="b-cap"><div><h3 class="b-name">{4}</h3><p class="b-short">{5}</p></div>{6}</div></a>' -f $a, $svcUrl[$s.key], $bi, $img, (Esc $s.name), (Esc $s.short), $arrowSvg))
    }
    $bi++
  }
  # work: masonry of the featured projects' second photos (the bento and hero already show the first ones)
  $homeProjects = @($projects | Select-Object -First 9)
  $grid = New-Object System.Text.StringBuilder; $countBy = @{}
  $k = 0
  foreach ($p in $homeProjects) {
    $idx = [Math]::Min(1, $p.photos.Count - 1)
    [void]$grid.Append((Tile $p $idx $k $false $true))
    if (-not $countBy.ContainsKey($p.category)) { $countBy[$p.category] = 0 }; $countBy[$p.category]++
    $k++
  }
  $homeTokens = @{
    heroSlides = $slides.ToString(); heroWords = $words.ToString(); heroCaption = $heroCaption; serviceBento = $bento.ToString()
    workFilters = (Filters $countBy); workGrid = $grid.ToString(); reviewsSection = $reviews; content = $T["home"]
    title = "$($cfg.shortName) | Remodeling and Handyman Services in $($cfg.hub), $($cfg.state)"
    description = "Locally owned remodeling and handyman services in $($cfg.hub), Ohio, serving $($cfg.region). Kitchens, bathrooms, basements, decks, living rooms and repairs by $($cfg.owner). Free written quotes."
    canonical = "$domain/"; ogImage = "$domain/img/og/home.jpg"; ogType = "website"; bodyClass = "page-home"; rootRel = ""
    preload = ('<link rel="preload" as="image" href="{0}{1}" imagesrcset="{0}{2} {3}w, {0}{1} {4}w" imagesizes="{5}">' -f $R, $heroInfo[$services[0].key].big, $heroInfo[$services[0].key].small, $heroInfo[$services[0].key].wSmall, $heroInfo[$services[0].key].w, $heroSizes)
    jsonld = (JsonLd @(
      [ordered]@{ "@type" = "WebSite"; "@id" = "$domain/#website"; url = "$domain/"; name = $cfg.shortName; publisher = [ordered]@{ "@id" = "$domain/#business" } },
      (Biz $false)
    ))
  }
  Emit $mode $layout $G $homeTokens $(if ($flat) { "index.html" } else { "index.html" })

  # ---------- service pages
  foreach ($s in $services) {
    $hi = $heroInfo[$s.key]
    $catProjects = @($projects | Where-Object { $_.category -eq $s.key })
    $gal = New-Object System.Text.StringBuilder
    if ($catProjects.Count -eq 0) {
      [void]$gal.Append(('<p class="grid-empty">Photos of recent {0} work are coming soon. Call or text {1} and Ryan will send some over.</p>' -f (Esc $s.noun), (Esc $cfg.phone)))
    }
    $ri = 0
    foreach ($p in $catProjects) {
      [void]$gal.Append(('<div class="project-block"><h3 data-reveal>{0}</h3>' -f (Esc $p.title)))
      if ($p.summary) { [void]$gal.Append(('<p class="summary" data-reveal>{0}</p>' -f (Esc $p.summary))) }
      [void]$gal.Append('<div class="grid">')
      for ($j = 0; $j -lt $p.photos.Count; $j++) { [void]$gal.Append((Tile $p $j $j ($j -eq 0 -and $p.photos.Count -gt 2))) }
      [void]$gal.Append('</div></div>')
      $ri++
    }
    $faq = (($s.faqs | ForEach-Object { '<details><summary>{0}</summary><div>{1}</div></details>' -f (Esc $_.q), (Esc $_.a) }) -join "")
    $others = (($services | Where-Object { $_.key -ne $s.key } | ForEach-Object { '<a class="other" href="{0}"><b>{1}</b><span>{2}</span></a>' -f $svcUrl[$_.key], (Esc $_.name), (Esc $_.short) }) -join "")
    $intro = (($s.intro | ForEach-Object { "<p>$(Esc $_)</p>" }) -join "")
    $hl = (($s.highlights | ForEach-Object { "<li>$checkSvg$(Esc $_)</li>" }) -join "")
    $heroImg = ""
    if ($hi) { $fp = Fit-Photo $hi '(min-width: 900px) 40vw, 100vw' 'fetchpriority="high"' (Attr $hi.alt); $heroImg = '<div class="{0}">{1}</div>' -f $fp.cls, $fp.html }
    $tokens = @{
      svcName = Esc $s.name; svcNameLower = Esc $s.name.ToLowerInvariant(); svcServiceName = Esc $s.serviceName; svcH1 = Esc $s.h1; svcShort = Esc $s.short; svcNoun = Esc $s.noun
      svcHeroImg = $heroImg; svcIntro = $intro; svcHighlights = $hl; svcGallery = $gal.ToString(); svcFaq = $faq; svcOthers = $others
      svcGalleryTitle = Esc ("$($s.name) we've finished"); content = $T["service"]
      title = $s.title; description = $s.description; canonical = "$domain/$($s.slug)/"; ogImage = "$domain/img/og/$($s.slug).jpg"; ogType = "website"
      bodyClass = "page-service page-$($s.key)"; rootRel = "../"
      preload = $(if ($hi) { '<link rel="preload" as="image" href="{0}{1}" imagesrcset="{0}{2} {3}w, {0}{1} {4}w" imagesizes="(min-width: 900px) 40vw, 100vw">' -f $R, $hi.big, $hi.small, $hi.wSmall, $hi.w } else { "" })
      jsonld = (JsonLd @(
        (Biz $true),
        [ordered]@{ "@type" = "Service"; "@id" = "$domain/$($s.slug)/#service"; name = $s.serviceName; serviceType = $s.serviceName; description = $s.description; url = "$domain/$($s.slug)/"; image = "$domain/img/og/$($s.slug).jpg"; provider = [ordered]@{ "@id" = "$domain/#business" }; areaServed = @($cfg.counties | ForEach-Object { [ordered]@{ "@type" = "AdministrativeArea"; name = "$_, Ohio" } }) },
        [ordered]@{ "@type" = "FAQPage"; mainEntity = @($s.faqs | ForEach-Object { [ordered]@{ "@type" = "Question"; name = $_.q; acceptedAnswer = [ordered]@{ "@type" = "Answer"; text = $_.a } } }) },
        [ordered]@{ "@type" = "BreadcrumbList"; itemListElement = @(
          [ordered]@{ "@type" = "ListItem"; position = 1; name = "Home"; item = "$domain/" },
          [ordered]@{ "@type" = "ListItem"; position = 2; name = $s.serviceName; item = "$domain/$($s.slug)/" }
        ) }
      ))
    }
    Emit $mode $layout $G $tokens $(if ($flat) { "$($s.slug).html" } else { "$($s.slug)\index.html" })
  }

  # ---------- work page
  $gridAll = New-Object System.Text.StringBuilder; $countAll = @{}
  $k = 0
  foreach ($p in $projects) {
    for ($j = 0; $j -lt $p.photos.Count; $j++) {
      [void]$gridAll.Append((Tile $p $j $k ($j -eq $p.coverIdx -and $p.featured -and $p.photos.Count -gt 2)))
      if (-not $countAll.ContainsKey($p.category)) { $countAll[$p.category] = 0 }; $countAll[$p.category]++
      $k++
    }
  }
  $workTokens = @{
    workFilters = (Filters $countAll); workGridAll = $gridAll.ToString(); content = $T["work"]
    title = "Our Work | Kitchens, Baths, Basements and Decks | $($cfg.shortName)"
    description = "$photoCount photos from $($projects.Count) finished remodeling projects in $($cfg.hub), Ohio and across $($cfg.region): kitchens, bathrooms, finished basements, decks and living rooms by $($cfg.shortName)."
    canonical = "$domain/work/"; ogImage = "$domain/img/og/home.jpg"; ogType = "website"; bodyClass = "page-work"; rootRel = "../"; preload = ""
    jsonld = (JsonLd @(
      (Biz $true),
      [ordered]@{ "@type" = "CollectionPage"; "@id" = "$domain/work/"; url = "$domain/work/"; name = "Our work"; about = [ordered]@{ "@id" = "$domain/#business" } },
      [ordered]@{ "@type" = "BreadcrumbList"; itemListElement = @(
        [ordered]@{ "@type" = "ListItem"; position = 1; name = "Home"; item = "$domain/" },
        [ordered]@{ "@type" = "ListItem"; position = 2; name = "Our work"; item = "$domain/work/" }
      ) }
    ))
  }
  Emit $mode $layout $G $workTokens $(if ($flat) { "work.html" } else { "work\index.html" })

  if (-not $flat) {
    $t404 = @{
      content = $T["404"]; title = "Page not found | $($cfg.shortName)"; description = "That page does not exist. Head back to $($cfg.shortName)."
      canonical = "$domain/404.html"; ogImage = "$domain/img/og/home.jpg"; ogType = "website"; bodyClass = "page-404"; rootRel = $basePath; preload = ""
      jsonld = (JsonLd @((Biz $true)))
    }
    Emit $mode $layout $G $t404 "404.html"
  }
}
function Emit($mode, $layout, $G, $tokens, $relPath) {
  $flat = ($mode -eq "art")
  $dest = if ($flat) { $artOut } else { $out }
  $all = @{}
  foreach ($k in $G.Keys) { $all[$k] = $G[$k] }
  foreach ($k in $tokens.Keys) { $all[$k] = $tokens[$k] }
  $rootRel = if ($flat) { "" } else { $tokens["rootRel"] }
  if ($flat -and $relPath -ne "index.html") { $layout = $T["layout"] }   # supporting pages need a full document
  $all["root"] = $rootRel
  if ($flat -and $relPath -eq "index.html") { $all["title"] = $cfg.shortName }   # artifact gallery name, not the SEO title
  if (-not $flat) { $all["home"] = $(if ($rootRel -eq "") { "./" } elseif ($rootRel -eq "/") { "/" } else { $rootRel }) }
  $html = Expand $layout $all
  $left = [regex]::Matches($html, "\{\{[a-zA-Z0-9_-]+\}\}") | ForEach-Object { $_.Value } | Sort-Object -Unique
  if ($left) { Warn "$relPath has unresolved tokens: $($left -join ' ')" }
  Write-Text (Join-Path $dest $relPath) $html
}

Build-Site "site"

# static files
Copy-Item (Join-Path $src "static\*") $out -Force
Ensure-Dir (Join-Path $out "fonts")
Copy-Item (Join-Path $src "fonts\*") (Join-Path $out "fonts") -Force
Write-Text (Join-Path $out "css\site.css") $css
Write-Text (Join-Path $out "js\site.js") $js
$cnamePath = Join-Path $out "CNAME"
if ($customLive) { Write-Text $cnamePath ($domain -replace '^https?://', '') }
elseif (Test-Path $cnamePath) { [IO.File]::Delete($cnamePath) }
Log $(if ($customLive) { "Custom domain ON: CNAME written, root paths" } else { "Custom domain OFF: previewing under $basePath (set customDomainLive=true in site.json on cutover day)" })
Write-Text (Join-Path $out ".nojekyll") ""
$urls = @("$domain/", "$domain/work/") + @($services | ForEach-Object { "$domain/$($_.slug)/" })
$sm = New-Object System.Text.StringBuilder
[void]$sm.Append('<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
foreach ($u in $urls) { [void]$sm.Append("<url><loc>$u</loc><lastmod>$today</lastmod></url>") }
[void]$sm.Append('</urlset>')
Write-Text (Join-Path $out "sitemap.xml") $sm.ToString()
Log "Site written to $out"

if ($Artifact) {
  Build-Site "art"
  Ensure-Dir (Join-Path $artOut "img")
  & robocopy (Join-Path $out "img") (Join-Path $artOut "img") /E /NJH /NJS /NDL /NFL /NC /NS /NP | Out-Null
  Copy-Item (Join-Path $out "favicon.svg") $artOut -Force
  Ensure-Dir (Join-Path $artOut "fonts")
  Copy-Item (Join-Path $src "fonts\*") (Join-Path $artOut "fonts") -Force
  Log "Artifact copy written to $artOut"
}

$size = (Get-ChildItem $out -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
Log ("Done. {0:N1} MB in {1}. {2} warning(s)." -f $size, (Split-Path $out -Leaf), $warnings.Count)
if ($warnings.Count -gt 0) { $warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow } }
