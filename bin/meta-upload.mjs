// meta-upload.mjs — builds a Meta Ads Manager bulk-import sheet from a campaign's "Approved for testing" folder.
//
// Run it through bin/meta-upload.sh (it adds --use-system-ca for networks that inspect HTTPS):
//   bash bin/meta-upload.sh "<campaign folder>" --pattern "<one-ad export.xlsx>" [--skip "<text>"]... [--since YYYY-MM-DD]
//
// What it does, read-only on the Meta side (GET requests only, ads_read token):
//   1. Reads "Approved for testing/ad names.csv" and pairs each variant's sz-1100x1080 and sz-9x16 files into one ad:
//      the feed cut goes to feed/right-column placements, the vertical cut to Stories/Reels/Status. A variant with only
//      one size uses it everywhere. Files named "... - card N" are carousels and are listed for building by hand.
//   2. Finds each file's image hash or video ID in the ad account's media library. Browsers on Windows upload long
//      paths under their 8.3 short names (HOWONE~1.PNG), so those are matched too.
//   3. Copies the pattern ad's row (an ad exported from the target ad set) once per new ad: same ad set, copy, link
//      and placement groups; new name, media and status PAUSED; the pattern ad's ID and post links cleared.
//   4. Writes "meta upload <date>.xlsx" into the "Approved for testing" folder, ready for Ads Manager's
//      Import ads in bulk. Nothing is sent to Meta.
//
// Credentials: META_ACCESS_TOKEN (read-only, ads_read) and META_AD_ACCOUNT_ID, from the environment or from
// ~/.config/ugc-reel/meta.env. Never put them in this folder.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync } from 'node:child_process';

const API = 'https://graph.facebook.com/v23.0';
// Placement names that take the vertical (9x16) cut. Everything else (feeds, in-stream, right column, search) takes the feed cut.
const VERTICAL = new Set(['facebook story', 'facebook facebook_reels', 'instagram story', 'instagram reels', 'instagram ig_search',
  'messenger story', 'whatsapp status']);

// ---------- arguments and credentials ----------
const args = process.argv.slice(2);
const opt = (name) => { const i = args.indexOf(name); return i >= 0 ? args.splice(i, 2)[1] : null; };
const skips = [];
for (let s; (s = opt('--skip')); ) skips.push(s.toLowerCase());
const patternPath = opt('--pattern');
const since = opt('--since') || new Date(Date.now() - 14 * 864e5).toISOString().slice(0, 10);
const campaign = args[0];
if (!campaign || !patternPath) {
  console.error('Usage: bash bin/meta-upload.sh "<campaign folder>" --pattern "<one-ad export.xlsx>" [--skip "<text>"] [--since YYYY-MM-DD]');
  process.exit(2);
}
const dir = fs.existsSync(path.join(campaign, 'Approved for testing')) ? path.join(campaign, 'Approved for testing') : campaign;
const envFile = path.join(os.homedir(), '.config', 'ugc-reel', 'meta.env');
if (fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z_]+)\s*=\s*"?([^"]*)"?\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
  }
}
const token = process.env.META_ACCESS_TOKEN;
const account = process.env.META_AD_ACCOUNT_ID ? 'act_' + process.env.META_AD_ACCOUNT_ID.replace(/^act_/, '').trim() : '';
if (!token || !account) {
  console.error(`META_ACCESS_TOKEN and META_AD_ACCOUNT_ID are not set. Put them in ${envFile} (see README → Meta bulk upload).`);
  process.exit(2);
}

// ---------- small readers ----------
function unzip(file) {
  const b = fs.readFileSync(file);
  let e = b.length - 22;
  while (e >= 0 && b.readUInt32LE(e) !== 0x06054b50) e--;
  if (e < 0) throw new Error(`${file} is not an .xlsx file`);
  const out = new Map();
  for (let p = b.readUInt32LE(e + 16), n = b.readUInt16LE(e + 10); n--; ) {
    const method = b.readUInt16LE(p + 10), size = b.readUInt32LE(p + 20);
    const nameLen = b.readUInt16LE(p + 28), extra = b.readUInt16LE(p + 30), comment = b.readUInt16LE(p + 32);
    const local = b.readUInt32LE(p + 42);
    const name = b.toString('utf8', p + 46, p + 46 + nameLen);
    const start = local + 30 + b.readUInt16LE(local + 26) + b.readUInt16LE(local + 28);
    const data = b.subarray(start, start + size);
    out.set(name, method === 8 ? zlib.inflateRawSync(data) : data);
    p += 46 + nameLen + extra + comment;
  }
  return out;
}
const unxml = (s) => s.replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(+n)).replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
  .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&amp;/g, '&');
const colIndex = (ref) => [...ref.replace(/\d+/g, '')].reduce((n, ch) => n * 26 + ch.charCodeAt(0) - 64, 0) - 1;
const colName = (i) => { let s = ''; for (i++; i; i = Math.floor((i - 1) / 26)) s = String.fromCharCode(65 + ((i - 1) % 26)) + s; return s; };

// The first sheet of an .xlsx as an array of rows (arrays of strings).
function readXlsx(file) {
  const z = unzip(file);
  const shared = [];
  const ss = z.get('xl/sharedStrings.xml');
  if (ss) for (const si of ss.toString('utf8').matchAll(/<si>([\s\S]*?)<\/si>/g)) shared.push([...si[1].matchAll(/<t[^>]*>([\s\S]*?)<\/t>/g)].map((t) => unxml(t[1])).join(''));
  const sheetName = [...z.keys()].filter((k) => /^xl\/worksheets\/sheet\d+\.xml$/.test(k)).sort()[0];
  const rows = [];
  for (const r of z.get(sheetName).toString('utf8').matchAll(/<row[^>]*>([\s\S]*?)<\/row>/g)) {
    const row = [];
    for (const c of r[1].matchAll(/<c r="([A-Z]+\d+)"([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g)) {
      const body = c[3] || '';
      let v = '';
      if (/t="inlineStr"/.test(c[2])) v = [...body.matchAll(/<t[^>]*>([\s\S]*?)<\/t>/g)].map((t) => unxml(t[1])).join('');
      else { const m = body.match(/<v>([\s\S]*?)<\/v>/); if (m) v = /t="s"/.test(c[2]) ? shared[+m[1]] : unxml(m[1]); }
      row[colIndex(c[1])] = v;
    }
    rows.push(Array.from(row, (v) => v ?? ''));
  }
  return rows;
}

// A minimal .xlsx: one sheet, every cell an inline string (so long IDs are never turned into numbers). Columns in
// `hidden` are hidden for review but still imported; the header row is frozen.
function writeXlsx(file, rows, hidden = new Set()) {
  const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/[\x00-\x08\x0b\x0c\x0e-\x1f]/g, '');
  const width = Math.max(...rows.map((r) => r.length));
  const cols = [];
  for (let i = 0; i < width; i++) {
    const last = cols.at(-1);
    if (last && last.hidden === hidden.has(i)) last.max = i + 1; else cols.push({ min: i + 1, max: i + 1, hidden: hidden.has(i) });
  }
  const sheet = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    + '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>'
    + '<cols>' + cols.map((c) => `<col min="${c.min}" max="${c.max}" width="${c.hidden ? 9 : 28}" customWidth="1"${c.hidden ? ' hidden="1"' : ''}/>`).join('') + '</cols><sheetData>'
    + rows.map((r, ri) => `<row r="${ri + 1}">` + r.map((v, ci) => v === '' ? '' : `<c r="${colName(ci)}${ri + 1}" t="inlineStr"><is><t xml:space="preserve">${esc(v)}</t></is></c>`).join('') + '</row>').join('')
    + '</sheetData></worksheet>';
  const files = [
    ['[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>'],
    ['_rels/.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>'],
    ['xl/workbook.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>'],
    ['xl/_rels/workbook.xml.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>'],
    ['xl/worksheets/sheet1.xml', sheet],
  ];
  const parts = [], central = [];
  let offset = 0;
  for (const [name, text] of files) {
    const raw = Buffer.from(text, 'utf8'), data = zlib.deflateRawSync(raw), crc = zlib.crc32(raw), n = Buffer.from(name);
    const head = Buffer.alloc(30);
    head.writeUInt32LE(0x04034b50, 0); head.writeUInt16LE(20, 4); head.writeUInt16LE(8, 8); head.writeUInt16LE(0x21, 12);
    head.writeUInt32LE(crc, 14); head.writeUInt32LE(data.length, 18); head.writeUInt32LE(raw.length, 22); head.writeUInt16LE(n.length, 26);
    const cd = Buffer.alloc(46);
    cd.writeUInt32LE(0x02014b50, 0); cd.writeUInt16LE(20, 4); cd.writeUInt16LE(20, 6); cd.writeUInt16LE(8, 10); cd.writeUInt16LE(0x21, 14);
    cd.writeUInt32LE(crc, 16); cd.writeUInt32LE(data.length, 20); cd.writeUInt32LE(raw.length, 24); cd.writeUInt16LE(n.length, 28); cd.writeUInt32LE(offset, 42);
    parts.push(head, n, data); central.push(cd, n);
    offset += 30 + n.length + data.length;
  }
  const cdBuf = Buffer.concat(central), end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0); end.writeUInt16LE(files.length, 8); end.writeUInt16LE(files.length, 10);
  end.writeUInt32LE(cdBuf.length, 12); end.writeUInt32LE(offset, 16);
  fs.writeFileSync(file, Buffer.concat([...parts, cdBuf, end]));
}

function readCsv(file) {
  const rows = [];
  let row = [], cell = '', q = false;
  const t = fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '');
  for (let i = 0; i < t.length; i++) {
    const ch = t[i];
    if (q) { if (ch === '"') { if (t[i + 1] === '"') { cell += '"'; i++; } else q = false; } else cell += ch; }
    else if (ch === '"') q = true;
    else if (ch === ',') { row.push(cell); cell = ''; }
    else if (ch === '\n' || ch === '\r') { if (ch === '\r' && t[i + 1] === '\n') i++; row.push(cell); if (row.some((c) => c !== '')) rows.push(row); row = []; cell = ''; }
    else cell += ch;
  }
  if (cell !== '' || row.length) { row.push(cell); rows.push(row); }
  return rows;
}

async function get(p, params = {}) {
  const rows = [];
  for (let next = `${API}/${p}?` + new URLSearchParams({ limit: '200', ...params }); next; ) {
    const res = await fetch(next, { headers: { Authorization: `Bearer ${token}` } });
    const body = await res.json().catch(() => ({}));
    if (body.error) throw new Error(`Meta API: ${body.error.message}`);
    if (!body.data) return body;
    rows.push(...body.data);
    next = body.paging?.next || null;
  }
  return rows;
}

// ---------- the pattern ad ----------
const patternRows = /\.csv$/i.test(patternPath) ? readCsv(patternPath) : readXlsx(patternPath);
const header = patternRows[0];
const col = (name) => header.indexOf(name);
for (const need of ['Ad Set ID', 'Ad ID', 'Ad Name', 'Ad Status', 'Creative Type', 'Image Hash', 'Video ID']) {
  if (col(need) < 0) throw new Error(`The pattern file has no "${need}" column. Export the ad with Export › Export selected (not "Export table data").`);
}
const pattern = patternRows.slice(1).find((r) => r[col('Ad Set ID')]);
if (!pattern) throw new Error('The pattern file has no ad row.');
const at = (row, name) => (col(name) >= 0 ? row[col(name)] || '' : '');
const set = (row, name, v) => { if (col(name) >= 0) row[col(name)] = v; };

// Media slots: the default one plus "Additional ... N" for N = 1..9.
const imageSlots = [{ media: 'Image Hash', place: 'Image Placement', extra: ['Image Crops', 'Image Customization', 'Image File Name'] }];
const videoSlots = [{ media: 'Video ID', place: 'Video Placement', thumb: 'Video Thumbnail URL', extra: ['Video Customization', 'Video File Name'] }];
for (let n = 1; n <= 9; n++) {
  imageSlots.push({ media: `Additional Image ${n} Hash`, place: `Additional Image ${n} Placement`, extra: [`Additional Image ${n} Crops`, `Additional Image ${n} Customization`] });
  videoSlots.push({ media: `Additional Video ${n} ID`, place: `Additional Video ${n} Placement`, thumb: `Additional Video ${n} Thumbnail URL`, extra: [`Additional Video ${n} Customization`] });
}
// The pattern's placement groups, one per filled slot, from whichever media type has more of them. A video pattern
// ad also carries one leftover image hash, so its video slots win.
const filled = (slots) => slots.filter((s) => at(pattern, s.media)).map((s) => at(pattern, s.place));
const imageGroups = filled(imageSlots), videoGroups = filled(videoSlots);
let groups = videoGroups.length > imageGroups.length ? videoGroups : imageGroups;
if (!groups.length) groups = [''];
const isVertical = (place) => place.split(/,\s*/).some((p) => VERTICAL.has(p.trim().toLowerCase()));
// WhatsApp always gets the 9x16 cut (house rule since 2026-10-30): a group that mixes WhatsApp with feed
// placements is split so WhatsApp gets its own slot.
groups = groups.flatMap((place) => {
  const parts = place.split(/,\s*/).filter(Boolean);
  const wa = parts.filter((p) => /^whatsapp /i.test(p.trim()));
  const rest = parts.filter((p) => !/^whatsapp /i.test(p.trim()));
  return wa.length && rest.length && !isVertical(rest.join(', ')) ? [rest.join(', '), wa.join(', ')] : [place];
});
// Every placement the ad's text runs in needs media too. A video pattern ad can leave one out (Messenger Stories),
// and Meta then fills that placement's rule with the videos' thumbnails and rejects the import ("Invalid Asset Count
// ... rule #5", seen 2026-10-30). Uncovered placements get their own slot: vertical ones the 9x16 cut, others the feed cut.
const covered = new Set(groups.flatMap((g) => g.split(/,\s*/)).map((p) => p.trim().toLowerCase()));
const textPlaces = new Set(['Title Placement', 'Body Placement', 'Link Placement'].flatMap((c) => at(pattern, c).split(/,\s*/)).map((p) => p.trim()).filter((p) => p && !/^default$/i.test(p)));
const uncovered = [...textPlaces].filter((p) => !covered.has(p.toLowerCase()));
const vUncovered = uncovered.filter((p) => isVertical(p)), fUncovered = uncovered.filter((p) => !isVertical(p));
if (vUncovered.length) groups.push(vUncovered.join(', '));
if (fUncovered.length) groups.push(fUncovered.join(', '));
const hashPrefix = (at(pattern, 'Image Hash').match(/^(\d+):/) || [])[1] || account.replace('act_', '');
// Meta's exports write video IDs as "v:<id>"; use the same form when the pattern does.
const videoPrefix = videoSlots.map((s) => at(pattern, s.media)).find(Boolean)?.startsWith('v:') ? 'v:' : '';

// ---------- the approved files, paired into ads ----------
const namesFile = path.join(dir, 'ad names.csv');
if (!fs.existsSync(namesFile)) throw new Error(`No "ad names.csv" in ${dir}.`);
const ads = new Map();
const carousels = new Map(); // key -> { feed: [cards], vertical: [cards] }, cards in "card N" order
for (const [file, adName] of readCsv(namesFile).slice(1)) {
  if (!file || !adName) continue;
  const key = adName.replace(/ - sz-[^-]+$/i, '').trim();
  const size = (adName.match(/ - sz-([^-]+)$/i) || [])[1]?.trim().toLowerCase() || '';
  const card = file.match(/ - card (\d+)\.\w+$/i);
  if (card) {
    if (!carousels.has(key)) carousels.set(key, { key, feed: [], vertical: [] });
    carousels.get(key)[size === '9x16' ? 'vertical' : 'feed'].push({ n: +card[1], file, adName, video: /\.(mp4|mov)$/i.test(file) });
    continue;
  }
  if (!ads.has(key)) ads.set(key, { key, files: {} });
  ads.get(key).files[size === '9x16' ? 'vertical' : 'feed'] = { file, adName, video: /\.(mp4|mov)$/i.test(file) };
}

// Windows 8.3 short names, which browsers send for long paths.
const shortName = new Map();
if (process.platform === 'win32') {
  try {
    for (const line of execFileSync('cmd', ['/c', 'dir', '/x', path.resolve(dir)], { encoding: 'utf8' }).split(/\r?\n/)) {
      const m = line.match(/\s(\S+~\d+\.\S+)\s+(.+)$/);
      if (m) shortName.set(m[2].trim(), m[1].toUpperCase());
    }
  } catch { /* short names are a fallback only */ }
}

const adSetId = at(pattern, 'Ad Set ID').replace(/^c:/, '');
const [images, videos, existing] = await Promise.all([
  get(`${account}/adimages`, { fields: 'name,hash,created_time,account_id' }),
  get(`${account}/advideos`, { fields: 'title,id,created_time,status,thumbnails{uri,is_preferred}' }).then((v) => v.filter((x) => x.created_time >= since)),
  get(`${adSetId}/ads`, { fields: 'name' }).catch(() => []),
]);
const existingNames = new Set(existing.map((a) => a.name));
const businessOnly = new Set(); // images found only in the Business media library
const newest = (list) => list.sort((a, b) => b.created_time.localeCompare(a.created_time))[0];
const namesFor = (f) => [f.toUpperCase(), shortName.get(f)].filter(Boolean);
function findMedia(entry) {
  const want = namesFor(entry.file);
  if (entry.video) {
    const v = newest(videos.filter((x) => want.includes((x.title || '').toUpperCase())));
    if (!v) return null;
    const th = v.thumbnails?.data || [];
    return { id: videoPrefix + v.id, thumb: (th.find((t) => t.is_preferred) || th[0])?.uri || '', ready: v.status?.video_status === 'ready' };
  }
  // Only images the ad account itself owns can go in an import. The ad account also lists images held in the
  // Business media library, and those fail with "The image you selected is not available" (#2446386, seen 2026-10-30).
  const named = images.filter((x) => want.includes((x.name || '').toUpperCase()));
  const i = newest(named.filter((x) => x.account_id === account.replace('act_', '')));
  if (!i && named.length) businessOnly.add(entry.file);
  return i ? { id: `${hashPrefix}:${i.hash}`, ready: true } : null;
}

// ---------- build the rows ----------
const clear = ['Ad ID', 'Preview Link', 'Instagram Preview Link', 'Permalink', 'Story ID',
  ...imageSlots.flatMap((s) => [s.media, s.place, ...s.extra]), ...videoSlots.flatMap((s) => [s.media, s.place, s.thumb, ...s.extra])];
const out = [header];
const report = { built: [], skipped: [], missing: [] };
for (const ad of ads.values()) {
  const feed = ad.files.feed || ad.files.vertical, vertical = ad.files.vertical || ad.files.feed;
  const name = feed.adName;
  if (existingNames.has(name) || skips.some((s) => name.toLowerCase().includes(s))) { report.skipped.push(name); continue; }
  if (feed.video !== vertical.video) { report.missing.push(`${ad.key}: one size is a video and the other an image`); continue; }
  const m = { feed: findMedia(feed), vertical: findMedia(vertical) };
  const lost = [['feed', feed], ['vertical', vertical]].filter(([k]) => !m[k]).map(([, e]) => e.file);
  if (lost.length) { report.missing.push(...new Set(lost)); continue; }
  const row = [...pattern];
  for (const c of clear) set(row, c, '');
  set(row, 'Ad Name', name);
  set(row, 'Ad Status', 'PAUSED');
  const slots = feed.video ? videoSlots : imageSlots;
  set(row, 'Creative Type', feed.video ? 'Video Page Post Ad' : 'Link Page Post Ad');
  // Every ad needs a slot for Meta's default placement rule ("Default, Default"): a video pattern keeps it on its
  // image slot, so it isn't among the video groups. It goes first and takes the feed cut. Without it, Meta fills the
  // default rule with the videos' thumbnails and rejects the import ("Invalid Asset Count in Dynamic Creative Target
  // Rule ... rule #4", seen 2026-10-30).
  const defaultGroup = imageGroups.find((g) => /^Default\b/i.test(g));
  const rowGroups = defaultGroup && !groups.includes(defaultGroup) ? [defaultGroup, ...groups] : groups;
  // One slot per group. Images can't repeat across slots ("Duplicate of ad asset values are not allowed", seen
  // 2026-10-30), so an image ad merges the groups that share an image into one slot, default first. Videos may repeat.
  let slotList = rowGroups.map((place) => ({ place, media: isVertical(place) ? m.vertical : m.feed }));
  if (!feed.video) {
    const merged = new Map();
    for (const s of slotList) {
      if (merged.has(s.media.id)) merged.get(s.media.id).place += `, ${s.place}`;
      else merged.set(s.media.id, { ...s });
    }
    slotList = [...merged.values()];
  }
  slotList.forEach(({ place, media }, i) => {
    set(row, slots[i].media, media.id);
    set(row, slots[i].place, place);
    if (slots[i].thumb) set(row, slots[i].thumb, media.thumb);
  });
  out.push(row);
  report.built.push(`${name}${m.feed.ready && m.vertical.ready ? '' : '   (video still processing — wait before importing)'}`);
}

// Carousels: one ad per variant from its feed-size cards (a 1:1-ish card suits every carousel placement; the 9x16
// cards are only used when there are no feed cards). Each card links to the pattern's landing page and carries its
// headline. A carousel is a plain (not flexible-format) ad, so everything that makes the pattern a flexible ad is
// cleared: its format, its per-placement text rules and alternative texts. Left in, Meta reads the cards as one
// placement rule holding several images and rejects the import ("Invalid Asset Count in Dynamic Creative Target
// Rule", seen 2026-10-30). Carousels go in their own file, so a carousel problem never blocks the other ads.
const FLEXIBLE = /^(Dynamic Creative Ad Format|Dynamic Creative Call to Action|Additional Dynamic Creative Call To Action Type \d+|Optimize text per person|Degrees of Freedom Type|(Title|Body|Link) Placement|Additional (Title|Body|Link|Display Link|Link Description) \d+( Placement)?)$/;
const carouselOut = [header];
const carouselNotes = [];
for (const c of carousels.values()) {
  const cards = (c.feed.length ? c.feed : c.vertical).sort((a, b) => a.n - b.n);
  const name = cards[0].adName;
  if (existingNames.has(name) || skips.some((s) => name.toLowerCase().includes(s))) { report.skipped.push(name); continue; }
  if (cards.length > 10) { report.missing.push(`${c.key}: ${cards.length} cards (Meta allows 10)`); continue; }
  const media = cards.map(findMedia);
  const lost = cards.filter((_, i) => !media[i]).map((k) => k.file);
  if (lost.length) { report.missing.push(...lost); continue; }
  const row = [...pattern];
  for (const field of clear) set(row, field, '');
  set(row, 'Ad Name', name);
  set(row, 'Ad Status', 'PAUSED');
  set(row, 'Creative Type', 'Link Page Post Ad');
  header.forEach((h, i) => { if (FLEXIBLE.test(h)) row[i] = ''; });
  cards.forEach((k, i) => {
    const p = `Product ${i + 1} - `;
    set(row, p + 'Link', at(pattern, 'Link'));
    set(row, p + 'Name', at(pattern, 'Title'));
    // Card columns take the bare hash / ID. The "<account>:" and "v:" prefixes of the main media columns make the
    // import report the card image as unavailable (#2446386, seen 2026-10-30).
    set(row, p + (k.video ? 'Video ID' : 'Image Hash'), media[i].id.replace(/^(\d+|v):/, ''));
  });
  carouselOut.push(row);
  report.built.push(`${name}   (carousel, ${cards.length} cards, in the carousels file)`);
  if (c.feed.length && c.vertical.length) carouselNotes.push(`${c.key}: used the 1100x1080 cards; the 9x16 cards are not in the sheet`);
}

// ---------- write and report ----------
const date = new Date().toISOString().slice(0, 10);
const outFile = path.join(dir, `meta upload ${date}.xlsx`);
const carouselFile = path.join(dir, `meta upload ${date} - carousels.xlsx`);
// For review, show only the columns a person checks: the ad's copy and destination, plus the ones this script filled
// in per ad (media IDs). Columns copied unchanged from the pattern, left empty in every row, or derived from the
// pattern (placements, thumbnails, carousel card links and headlines) are hidden.
const REVIEW = ['Ad Set Name', 'Ad Name', 'Ad Status', 'Creative Type', 'Dynamic Creative Ad Format', 'Title', 'Body', 'Link', 'Call to Action'];
const DERIVED = /Placement$|Thumbnail URL$|^Product \d+ - (Link|Name)$/;
const hiddenFor = (rowsOut) => new Set(header.map((h, i) => i).filter((i) => !REVIEW.includes(header[i]) && (DERIVED.test(header[i])
  || rowsOut.every((r) => (r[i] || '') === (pattern[i] || '')) || rowsOut.every((r) => !r[i]))));
const written = [];
for (const [file, rows] of [[outFile, out], [carouselFile, carouselOut]]) {
  if (fs.existsSync(file)) fs.rmSync(file); // a stale file from an earlier run must not be imported by mistake
  if (rows.length > 1) { writeXlsx(file, rows, hiddenFor(rows.slice(1))); written.push(`${file}  (${rows.length - 1} ad${rows.length > 2 ? 's' : ''})`); }
}
const hidden = hiddenFor(out.length > 1 ? out.slice(1) : carouselOut.slice(1));
const list = (title, items) => items.length && console.log(`\n${title} (${items.length}):\n` + items.map((s) => `  - ${s}`).join('\n'));
console.log(`Pattern ad: "${at(pattern, 'Ad Name')}" in ad set "${at(pattern, 'Ad Set Name')}" (${groups.length} placement group${groups.length > 1 ? 's' : ''}).`);
list('Ads in the sheet', report.built);
list('Skipped (already in the ad set, or --skip)', report.skipped);
list('Not found in the ad account media library — upload these, then run again', report.missing.filter((f) => !businessOnly.has(f)));
list('Only in the Business media library, which imports can\'t use — upload these again from inside an ad (Ads Manager › an ad › Media › Add media › Upload), then run again', [...businessOnly]);
list('Carousel notes', carouselNotes);
if (carousels.size) console.log('\nCarousels: after the import, check each one\'s card order and turn off "Show the best-performing cards first" if the cards tell a story in order.');
console.log(`\n${header.length - hidden.size} of ${header.length} columns are visible for review; the hidden ones are copied from the pattern ad and still import.`);
console.log(written.length ? `\nWrote:\n${written.map((w) => `  ${w}`).join('\n')}` : '\nNo sheet written: there are no ads to import.');
if (written.length) console.log('Next: Ads Manager › Export/Import › Import ads in bulk, one file at a time (the carousels file separately). Then publish the drafts, and in the new ads turn off any creative enhancements you don\'t want (Products is on by default after an import).');
