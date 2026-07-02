import assert from 'node:assert/strict';
import test from 'node:test';
import { mediaPreflightAction, reconcileExistingObject, storageObjectUrl, storageUploadFetch } from '../scripts/upload-reviewed-flyers.mjs';

const env = { url: 'https://example.supabase.co/', key: 'test-key' };

function okResponse(body = '') {
  return { ok: true, status: 200, text: async () => body, arrayBuffer: async () => Buffer.from(body).buffer };
}

function orphanResult(fileBuffer = Buffer.from('matching flyer')) {
  return {
    entry: {
      canonicalSlug: 'black-river-tattoo-convention',
      targetBucket: 'celebration-atlas-media',
      targetStoragePath: 'events/black-river-tattoo-convention/flyer/black-river-tattoo-convention.webp',
      title: 'Black River Tattoo Convention flyer',
      altText: 'Flyer for Black River Tattoo Convention'
    },
    event: { id: 123 },
    fileBuffer
  };
}

test('storage URL construction encodes bucket and path segments without shell-sensitive curl parsing', () => {
  assert.equal(
    storageObjectUrl(env, 'bucket with spaces', 'events/Black River/flyer/flyer #1.webp'),
    'https://example.supabase.co/storage/v1/object/bucket%20with%20spaces/events/Black%20River/flyer/flyer%20%231.webp'
  );
});

test('storageUploadFetch posts the binary Buffer with Supabase Storage headers', async () => {
  const body = Buffer.from([0x52, 0x49, 0x46, 0x46]);
  const calls = [];
  const fetchImpl = async (...args) => {
    calls.push(args);
    return okResponse();
  };

  await storageUploadFetch(env, 'celebration-atlas-media', 'events/mackinac/flyer/mackinac.webp', body, { fetchImpl });

  assert.equal(calls.length, 1);
  const [url, request] = calls[0];
  assert.equal(url, 'https://example.supabase.co/storage/v1/object/celebration-atlas-media/events/mackinac/flyer/mackinac.webp');
  assert.equal(request.method, 'POST');
  assert.equal(request.body, body);
  assert.deepEqual(request.headers, {
    apikey: 'test-key',
    Authorization: 'Bearer test-key',
    'Content-Type': 'image/webp',
    'x-upsert': 'false'
  });
});

test('matching Black River-style orphan reconciles by inserting media without uploading', async () => {
  const result = orphanResult();
  const requests = [];

  await reconcileExistingObject(env, result, {
    download: async () => Buffer.from('matching flyer'),
    request: async (...args) => {
      requests.push(args);
      return [{ id: 456 }];
    }
  });

  assert.equal(result.finalResult, 'reconciled-existing-object');
  assert.equal(requests.length, 1);
  assert.equal(requests[0][1], '/rest/v1/event_media');
  assert.equal(JSON.parse(requests[0][2].body).storage_path, result.entry.targetStoragePath);
});

test('mismatched orphan blocks safely without inserting media', async () => {
  const result = orphanResult(Buffer.from('local flyer'));
  let insertCalled = false;

  await assert.rejects(
    reconcileExistingObject(env, result, {
      download: async () => Buffer.from('different remote flyer'),
      request: async () => { insertCalled = true; }
    }),
    /SHA-256 differs/
  );
  assert.equal(insertCalled, false);
});

test('existing approved media remains blocked when a different approved flyer exists', () => {
  const matchingDraft = { id: 1, status: 'draft' };
  const conflictingApproved = [{ id: 2, status: 'approved' }];

  assert.equal(mediaPreflightAction(matchingDraft, conflictingApproved), 'blocked');
});
