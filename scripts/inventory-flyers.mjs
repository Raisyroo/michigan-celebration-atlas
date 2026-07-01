#!/usr/bin/env node
import { readdir, stat, writeFile, mkdir, readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';

const repoRoot = process.cwd();
const defaultVisualPath = path.resolve(repoRoot, '..', 'celebration-atlas-app');
const sourceRoot = path.resolve(process.env.FLYER_INVENTORY_SOURCE || defaultVisualPath);
const canonicalAssetRoot = repoRoot;
const manifestPath = process.env.FLYER_INVENTORY_MANIFEST ? path.resolve(process.env.FLYER_INVENTORY_MANIFEST) : null;
const reportsDir = path.join(repoRoot, 'reports');

const canonicalEvents = [
  { slug: 'romeo-peach-festival', name: 'Romeo Peach Festival', aliases: ['romeo-peach'], approvedFlyer: { bucket: 'celebration-atlas-media', path: 'events/romeo-peach-festival/flyer/romeo-peach-festival.webp' } },
  { slug: 'black-river-tattoo-convention', name: 'Black River Tattoo Convention', aliases: ['black-river-tattoo'] },
  { slug: 'mackinac-island-lilac-festival', name: 'Mackinac Island Lilac Festival', aliases: ['mackinac-lilac'] },
  { slug: 'national-cherry-festival', name: 'National Cherry Festival', aliases: ['traverse-city-cherry'] },
  { slug: 'tulip-time-festival', name: 'Tulip Time Festival', aliases: ['holland-tulip-time'] },
  { slug: 'upper-peninsula-state-fair', name: 'Upper Peninsula State Fair', aliases: [] }
];

const imageExts = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif']);
const videoExts = new Set(['.mp4', '.mov', '.webm', '.m4v']);
const ignoredDirs = new Set(['.git', 'node_modules', '.next', 'dist', 'build']);

const slugify = (value) => value.toLowerCase().replace(/&/g, ' and ').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const normalize = (value) => slugify(value).replace(/\b(festival|fest|fair|convention|county|state|island)\b/g, '').replace(/--+/g, '-').replace(/^-|-$/g, '');

function classify(file) {
  const ext = path.extname(file).toLowerCase();
  const lower = file.toLowerCase();
  if (videoExts.has(ext)) return 'video_only';
  if (!imageExts.has(ext)) return 'unknown';
  if (lower.includes('thumb') || lower.includes('thumbnail') || lower.includes('/generated/')) return 'thumbnail_only';
  if (lower.includes('poster') || lower.includes('artwork') || lower.includes('/posters/')) return 'poster_or_artwork';
  if (lower.includes('flyer') || lower.includes('/flyers/')) return 'flyer_candidate';
  return 'unknown';
}

async function walk(dir) {
  const out = [];
  if (!existsSync(dir)) return out;
  for (const ent of await readdir(dir, { withFileTypes: true })) {
    if (ignoredDirs.has(ent.name)) continue;
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) out.push(...await walk(full));
    else if (ent.isFile()) {
      const ext = path.extname(ent.name).toLowerCase();
      if (imageExts.has(ext) || videoExts.has(ext)) out.push(full);
    }
  }
  return out;
}

async function manifestFiles(file) {
  if (!file) return [];
  const parsed = JSON.parse(await readFile(file, 'utf8'));
  return (Array.isArray(parsed) ? parsed : parsed.files || []).map((entry) => path.resolve(path.dirname(file), typeof entry === 'string' ? entry : entry.path));
}

function matchEvent(relativePath) {
  const base = slugify(path.basename(relativePath, path.extname(relativePath)));
  const parts = slugify(relativePath);
  const exact = canonicalEvents.find((event) => base === event.slug || slugify(event.name) === base);
  if (exact) return { event: exact, status: exact.approvedFlyer ? 'already_has_approved_flyer' : 'matched', confidence: exact.approvedFlyer ? 1 : 0.98, reason: 'Exact canonical slug or name match.' };
  const alias = canonicalEvents.filter((event) => event.aliases.some((a) => base === a || parts.includes(a)));
  if (alias.length === 1) return { event: alias[0], status: 'needs_manual_review', confidence: 0.72, reason: 'Alias/app-id match; filename-only guesses are not auto-approved.' };
  const fuzzy = canonicalEvents.filter((event) => normalize(base).includes(normalize(event.name)) || normalize(event.name).includes(normalize(base)) || parts.includes(event.slug));
  if (fuzzy.length === 1) return { event: fuzzy[0], status: 'needs_manual_review', confidence: 0.55, reason: 'Filename/path fuzzy match; requires human review.' };
  if (fuzzy.length > 1 || alias.length > 1) return { event: null, status: 'ambiguous', confidence: 0.35, reason: 'Multiple plausible canonical events.' };
  return { event: null, status: 'no_canonical_event', confidence: 0, reason: 'No canonical slug, exact name, or configured alias matched.' };
}

function summarize(entries) {
  const by = (key) => entries.reduce((acc, e) => ({ ...acc, [e[key]]: (acc[e[key]] || 0) + 1 }), {});
  return { total: entries.length, byCategory: by('classification'), byMatchStatus: by('canonicalEventMatchStatus') };
}

const visualFiles = await walk(sourceRoot);
const canonicalFiles = await walk(path.join(canonicalAssetRoot, 'images'));
const rawFiles = [...visualFiles, ...canonicalFiles, ...await manifestFiles(manifestPath)];
const uniqueFiles = [...new Set(rawFiles)].sort((a, b) => a.localeCompare(b));
const sourceAvailable = existsSync(sourceRoot);
const entries = [];
for (const file of uniqueFiles) {
  const st = await stat(file).catch(() => null);
  const inVisual = file.startsWith(`${sourceRoot}${path.sep}`);
  const rel = (inVisual ? path.relative(sourceRoot, file) : path.relative(repoRoot, file)).split(path.sep).join('/');
  const classification = classify(rel);
  const match = classification === 'flyer_candidate' ? matchEvent(rel) : { event: null, status: 'not_a_flyer', confidence: 0, reason: `Classified as ${classification}, not a flyer candidate.` };
  entries.push({
    sourceFilePath: rel,
    absoluteSourceFilePath: file,
    fileType: path.extname(file).slice(1).toLowerCase() || 'unknown',
    fileSizeBytes: st?.size ?? null,
    classification,
    proposedEventName: match.event?.name ?? null,
    proposedCanonicalSlug: match.event?.slug ?? null,
    canonicalEventMatchStatus: match.status,
    matchConfidence: match.confidence,
    existingApprovedFlyerStatus: match.event?.approvedFlyer ? `approved Supabase flyer at ${match.event.approvedFlyer.bucket}/${match.event.approvedFlyer.path}` : 'none_found_in_repository_metadata',
    recommendedNextAction: match.status === 'already_has_approved_flyer' ? 'Do not upload or overwrite; keep approved Supabase media authoritative.' : match.status === 'matched' ? 'Review for future upload manifest.' : match.status === 'not_a_flyer' ? 'No flyer upload action.' : 'Manual review before any upload decision.',
    reasoning: match.reason
  });
}
entries.sort((a, b) => a.classification.localeCompare(b.classification) || a.sourceFilePath.localeCompare(b.sourceFilePath));
const report = { generatedAt: new Date().toISOString(), dryRunOnly: true, sourceRepositoryAvailable: sourceAvailable, sourceRoot, scannedCanonicalImages: true, manifestPath, canonicalBasis: 'Repository docs/sql only; no Supabase writes or network scraping.', summary: summarize(entries), entries };
await mkdir(reportsDir, { recursive: true });
await writeFile(path.join(reportsDir, 'flyer-inventory.json'), `${JSON.stringify(report, null, 2)}\n`);
const rows = entries.map((e) => `| ${e.classification} | ${e.canonicalEventMatchStatus} | ${e.sourceFilePath} | ${e.proposedCanonicalSlug ?? '—'} | ${e.matchConfidence} | ${e.recommendedNextAction} |`);
const md = `# Flyer Inventory Dry Run\n\nGenerated: ${report.generatedAt}\n\nDry run only: **yes**. No uploads, Supabase writes, schema changes, or media edits are performed.\n\nVisual app source root: \`${sourceRoot}\` (${sourceAvailable ? 'available' : 'unavailable'})\n\nCanonical repo image scan: \`images/\`\n\n## Summary\n\n\`\`\`json\n${JSON.stringify(report.summary, null, 2)}\n\`\`\`\n\n## Romeo status\n\nRomeo Peach Festival is treated as already having approved flyer media at \`celebration-atlas-media/events/romeo-peach-festival/flyer/romeo-peach-festival.webp\`; local duplicates should not overwrite it.\n\n## Candidates\n\n| Category | Match status | Source file | Proposed slug | Confidence | Recommended next action |\n| --- | --- | --- | --- | ---: | --- |\n${rows.join('\n') || '| — | — | No media files found. | — | — | Configure `FLYER_INVENTORY_SOURCE` or `FLYER_INVENTORY_MANIFEST`. |'}\n`;
await writeFile(path.join(reportsDir, 'flyer-inventory.md'), md);
console.log(`Wrote ${entries.length} inventory entries to reports/flyer-inventory.json and reports/flyer-inventory.md`);
