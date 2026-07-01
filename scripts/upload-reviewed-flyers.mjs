import { mkdtemp, readFile, rm, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { spawn } from 'node:child_process';
import os from 'node:os';

const repoRoot = process.cwd();
const manifestPath = path.join(repoRoot, 'manifests/first-flyer-upload.json');
const defaultSourceRoot = path.resolve(repoRoot, '../celebration-atlas-app');
const sourceRoot = path.resolve(process.env.FLYER_UPLOAD_SOURCE_ROOT ?? defaultSourceRoot);
const allowedExtensions = new Set(['.webp', '.png', '.jpg', '.jpeg']);
const allowedSignatures = [
  { ext: '.webp', test: (b) => b.subarray(0, 4).toString('ascii') === 'RIFF' && b.subarray(8, 12).toString('ascii') === 'WEBP' },
  { ext: '.png', test: (b) => b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) },
  { ext: '.jpg', test: (b) => b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff },
  { ext: '.jpeg', test: (b) => b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff }
];

const apply = process.argv.includes('--apply');

function getSupabaseCredentials() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY ?? process.env.SUPABASE_SERVICE_KEY;
  return url && key ? { url: url.replace(/\/$/, ''), key } : null;
}

function requireSupabaseCredentials() {
  const env = getSupabaseCredentials();
  if (!env) throw new Error('Missing SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY/SUPABASE_SERVICE_KEY environment variables.');
  return env;
}

async function curl(args, body) {
  const tempDir = await mkdtemp(path.join(os.tmpdir(), 'flyer-upload-curl-'));
  const configPath = path.join(tempDir, 'curl.conf');
  await writeFile(configPath, body.config, { mode: 0o600 });
  try {
    return await new Promise((resolve, reject) => {
      const child = spawn('curl', ['--silent', '--show-error', '--config', configPath, ...args], { stdio: ['pipe', 'pipe', 'pipe'] });
      let stdout = '';
      let stderr = '';
      child.stdout.setEncoding('utf8');
      child.stderr.setEncoding('utf8');
      child.stdout.on('data', (chunk) => { stdout += chunk; });
      child.stderr.on('data', (chunk) => { stderr += chunk; });
      child.on('error', reject);
      child.on('close', (code) => {
        if (code !== 0) reject(new Error(stderr || `curl exited with code ${code}`));
        else resolve(stdout);
      });
      if (body.payload) child.stdin.end(body.payload);
      else child.stdin.end();
    });
  } finally {
    await rm(tempDir, { recursive: true, force: true });
  }
}


function curlHeaderConfig(headers) {
  return headers.map(([name, value]) => `header = "${name}: ${String(value).replaceAll('"', '\\"')}"`).join('\n');
}


export class SupabaseHttpError extends Error {
  constructor(message, { method, endpoint, status, data }) {
    super(message);
    this.name = 'SupabaseHttpError';
    this.method = method;
    this.endpoint = endpoint;
    this.status = status;
    this.data = data;
  }
}

function isBucketMissingResponse(data) {
  const fields = [data?.error, data?.message].filter(Boolean).map((value) => String(value).toLowerCase());
  return fields.some((value) => value.includes('bucket'));
}

export function isStorageObjectAbsentError(error) {
  if (!(error instanceof SupabaseHttpError)) return false;
  if (isBucketMissingResponse(error.data)) return false;
  if (error.status === 404) return true;
  return error.status === 400 && String(error.data?.statusCode) === '404';
}

async function supabaseRequest({ url, key }, endpoint, options = {}) {
  const method = options.method ?? 'GET';
  const args = [
    '--request', method,
    '--write-out', '\n%{http_code}',
    `${url}${endpoint}`
  ];
  const headers = [['apikey', key], ['Authorization', `Bearer ${key}`], ...Object.entries(options.headers ?? {})];
  let payload;
  if (options.body) {
    payload = options.body;
    headers.push(['Content-Type', 'application/json']);
    args.splice(-2, 0, '--data-binary', '@-');
  }
  const output = await curl(args, { config: curlHeaderConfig(headers), payload });
  const split = output.lastIndexOf('\n');
  const text = split >= 0 ? output.slice(0, split) : '';
  const status = Number(split >= 0 ? output.slice(split + 1) : '0');
  const data = text ? JSON.parse(text) : null;
  if (status < 200 || status >= 300) {
    throw new SupabaseHttpError(`${method} ${endpoint} failed with ${status}: ${JSON.stringify(data)}`, {
      method,
      endpoint,
      status,
      data
    });
  }
  return data;
}

async function validateManifest() {
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  if (!Array.isArray(manifest.entries) || manifest.entries.length !== 3) throw new Error('Manifest must contain exactly three reviewed entries.');
  const excludedNames = new Set((manifest.excluded ?? []).map((entry) => entry.name));
  for (const name of ['Romeo Peach Festival', 'Brown Trout Festival', 'Goodells Fair']) {
    if (!excludedNames.has(name)) throw new Error(`Manifest excluded list must include ${name}.`);
  }
  for (const entry of manifest.entries) {
    if (['romeo-peach-festival', 'brown-trout-festival', 'goodells-fair'].includes(entry.canonicalSlug)) {
      throw new Error(`${entry.canonicalSlug}: excluded event must not appear in reviewed upload entries.`);
    }
  }
  const seen = new Set();
  for (const entry of manifest.entries) {
    const filename = path.basename(entry.sourcePath);
    const expectedStoragePath = `events/${entry.canonicalSlug}/flyer/${filename}`;
    if (entry.sourceRepository !== 'celebration-atlas-app') throw new Error(`${entry.sourcePath}: sourceRepository must be celebration-atlas-app.`);
    if (entry.mediaRole !== 'flyer') throw new Error(`${entry.sourcePath}: mediaRole must be flyer.`);
    if (entry.targetBucket !== 'celebration-atlas-media') throw new Error(`${entry.sourcePath}: targetBucket must be celebration-atlas-media.`);
    if (entry.targetStoragePath !== expectedStoragePath) throw new Error(`${entry.sourcePath}: targetStoragePath must be ${expectedStoragePath}.`);
    if (entry.intendedRecordStatus !== 'approved') throw new Error(`${entry.sourcePath}: intendedRecordStatus must be approved.`);
    if (seen.has(entry.canonicalSlug)) throw new Error(`Duplicate canonical slug in manifest: ${entry.canonicalSlug}`);
    seen.add(entry.canonicalSlug);
  }
  return manifest;
}

async function validateSourceRoot() {
  try {
    const info = await stat(sourceRoot);
    if (!info.isDirectory()) throw new Error('not a directory');
  } catch {
    throw new Error(`Flyer source checkout unavailable at ${sourceRoot}. Check out celebration-atlas-app beside this repo or set FLYER_UPLOAD_SOURCE_ROOT.`);
  }
}

async function validateFile(entry) {
  const filePath = path.resolve(sourceRoot, entry.sourcePath);
  const relative = path.relative(sourceRoot, filePath);
  if (relative.startsWith('..') || path.isAbsolute(relative)) throw new Error(`${entry.sourcePath}: sourcePath must stay within ${sourceRoot}.`);
  let info;
  try {
    info = await stat(filePath);
  } catch {
    throw new Error(`${entry.sourceRepository}:${entry.sourcePath} is unavailable under source root ${sourceRoot}.`);
  }
  if (!info.isFile()) throw new Error(`${entry.sourceRepository}:${entry.sourcePath} is not a file under source root ${sourceRoot}.`);
  const buffer = await readFile(filePath);
  const ext = path.extname(entry.sourcePath).toLowerCase();
  if (!allowedExtensions.has(ext) || !allowedSignatures.some((sig) => sig.ext === ext && sig.test(buffer))) {
    throw new Error(`${entry.sourceRepository}:${entry.sourcePath} is not an allowed image type with a valid file signature.`);
  }
  return buffer;
}

function mediaRecord(entry, eventId) {
  return {
    event_id: eventId,
    media_role: 'flyer',
    source: 'supabase',
    storage_bucket: entry.targetBucket,
    storage_path: entry.targetStoragePath,
    public_url: null,
    title: entry.title,
    alt_text: entry.altText,
    sort_order: 0,
    status: 'approved'
  };
}

async function preflight(env, manifest) {
  const results = [];
  for (const entry of manifest.entries) {
    const fileBuffer = await validateFile(entry);
    const slug = encodeURIComponent(entry.canonicalSlug);
    const events = await supabaseRequest(env, `/rest/v1/events?slug=eq.${slug}&select=id,slug,name,city,state,status,verification_status`);
    if (events.length !== 1) throw new Error(`${entry.canonicalSlug}: expected exactly one canonical public.events row, found ${events.length}.`);
    const event = events[0];
    const media = await supabaseRequest(env, `/rest/v1/event_media?event_id=eq.${event.id}&media_role=eq.flyer&status=in.(draft,approved)&select=id,storage_bucket,storage_path,title,alt_text,status`);
    const matching = media.find((row) => row.storage_bucket === entry.targetBucket && row.storage_path === entry.targetStoragePath);
    const conflicting = media.filter((row) => row.status === 'approved' && row.id !== matching?.id);
    const action = conflicting.length ? 'blocked' : matching?.status === 'approved' ? 'already-present' : matching ? 'update' : 'create';
    results.push({ entry, event, fileBuffer, matching, conflicting, action });
  }
  const blocked = results.filter((r) => r.action === 'blocked');
  if (blocked.length) throw new Error(`Preflight blocked: approved flyer media already exists for ${blocked.map((r) => r.entry.canonicalSlug).join(', ')}.`);
  return results;
}


async function localDryRunPreflight(manifest) {
  const results = [];
  for (const entry of manifest.entries) {
    const fileBuffer = await validateFile(entry);
    results.push({
      entry,
      event: { id: '<requires-supabase-preflight>', slug: entry.canonicalSlug, name: entry.title.replace(/ flyer$/, '') },
      fileBuffer,
      matching: null,
      conflicting: [],
      action: 'create'
    });
  }
  return results;
}

export async function storageExists(env, bucket, objectPath, request = supabaseRequest) {
  try {
    await request(env, `/storage/v1/object/info/${bucket}/${objectPath}`);
    return true;
  } catch (error) {
    if (isStorageObjectAbsentError(error)) return false;
    throw error;
  }
}

async function applyBatch(env, results) {
  for (const result of results) {
    if (result.action === 'already-present') continue;
    const exists = await storageExists(env, result.entry.targetBucket, result.entry.targetStoragePath);
    if (exists) {
      throw new Error(`${result.entry.canonicalSlug}: storage object already exists at ${result.entry.targetBucket}/${result.entry.targetStoragePath}; refusing to overwrite or attach a new approved flyer record.`);
    }
    await curl([
        '--request', 'POST',
        '--data-binary', '@-',
        '--fail-with-body',
        `${env.url}/storage/v1/object/${result.entry.targetBucket}/${result.entry.targetStoragePath}`
      ], {
        config: curlHeaderConfig([['apikey', env.key], ['Authorization', `Bearer ${env.key}`], ['Content-Type', 'image/webp'], ['x-upsert', 'false']]),
        payload: result.fileBuffer
      });
    const record = mediaRecord(result.entry, result.event.id);
    if (result.action === 'update') {
      await supabaseRequest(env, `/rest/v1/event_media?id=eq.${result.matching.id}`, {
        method: 'PATCH',
        headers: { Prefer: 'return=representation' },
        body: JSON.stringify(record)
      });
    } else {
      await supabaseRequest(env, '/rest/v1/event_media', {
        method: 'POST',
        headers: { Prefer: 'return=representation' },
        body: JSON.stringify(record)
      });
    }
    result.storageAction = exists ? 'already-present' : 'create';
  }
}

function modeLabel() {
  return apply ? 'APPLY' : 'DRY RUN';
}

function summarizeResults(results) {
  return {
    created: results.filter((r) => r.action === 'create' || r.action === 'update').length,
    alreadyPresent: results.filter((r) => r.action === 'already-present').length,
    blocked: results.filter((r) => r.action === 'blocked').length,
    failed: 0
  };
}

function printFinalSummary(results) {
  const summary = summarizeResults(results);
  console.log('\nFLYER UPLOAD SUMMARY');
  console.log(`Mode: ${modeLabel()}`);
  console.log(`Created: ${summary.created}`);
  console.log(`Already present: ${summary.alreadyPresent}`);
  console.log(`Blocked: ${summary.blocked}`);
  console.log(`Failed: ${summary.failed}`);
}

function printReport(results, { skippedDatabaseChecks = false } = {}) {
  console.log(`Reviewed flyer upload batch (${modeLabel()}): ${results.length} entries`);
  if (skippedDatabaseChecks) {
    console.log('Skipped: canonical event and existing approved-flyer verification requires Supabase credentials.');
  }
  for (const result of results) {
    const record = mediaRecord(result.entry, result.event.id);
    console.log('\n---');
    console.log(`matched canonical event: ${result.event.name} (${result.event.slug})`);
    console.log(`source repository: ${result.entry.sourceRepository}`);
    console.log(`source root: ${sourceRoot}`);
    console.log(`source path: ${result.entry.sourcePath}`);
    console.log(`storage path: ${result.entry.targetBucket}/${result.entry.targetStoragePath}`);
    console.log(`media-record action: ${result.action}`);
    console.log(`intended event_media record: ${JSON.stringify(record)}`);
    console.log(`final result: ${result.action === 'blocked' ? 'blocked' : apply ? 'applied/reconciled' : 'dry-run only; no writes'}`);
  }
}

async function main() {
  console.log(`Flyer uploader starting: ${modeLabel()}`);
  try {
    const env = apply ? requireSupabaseCredentials() : getSupabaseCredentials();
    const manifest = await validateManifest();
    await validateSourceRoot();
    const skippedDatabaseChecks = !env;
    const results = env ? await preflight(env, manifest) : await localDryRunPreflight(manifest);
    if (apply) await applyBatch(env, results);
    printReport(results, { skippedDatabaseChecks });
    printFinalSummary(results);
  } catch (error) {
    console.error(`Flyer upload batch failed safely: ${error.message}`);
    process.exitCode = 1;
  }
}

export function isMainModule(moduleUrl, scriptPath = process.argv[1], options = {}) {
  if (!scriptPath) return false;
  const windows = options.windows ?? process.platform === 'win32';
  return moduleUrl === pathToFileURL(scriptPath, { windows }).href;
}

if (isMainModule(import.meta.url)) {
  await main();
}
