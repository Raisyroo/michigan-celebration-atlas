import assert from 'node:assert/strict';
import test from 'node:test';
import { storageExists, SupabaseHttpError } from '../scripts/upload-reviewed-flyers.mjs';

const env = { url: 'https://example.supabase.co', key: 'test-key' };
const bucket = 'celebration-atlas-media';
const objectPath = 'events/example/flyer/example.webp';

function storageError(status, data) {
  return new SupabaseHttpError(`GET /storage/v1/object/info/${bucket}/${objectPath} failed with ${status}: ${JSON.stringify(data)}`, {
    method: 'GET',
    endpoint: `/storage/v1/object/info/${bucket}/${objectPath}`,
    status,
    data
  });
}

test('object-info wrapped 400 with statusCode 404 means storage object is absent', async () => {
  const exists = await storageExists(env, bucket, objectPath, async () => {
    throw storageError(400, { statusCode: '404', error: 'not found', message: 'Object not found' });
  });

  assert.equal(exists, false);
});

test('object-info HTTP 404 means storage object is absent', async () => {
  const exists = await storageExists(env, bucket, objectPath, async () => {
    throw storageError(404, { error: 'not found', message: 'Object not found' });
  });

  assert.equal(exists, false);
});

test('bucket-missing object-info 404 remains fatal', async () => {
  await assert.rejects(
    storageExists(env, bucket, objectPath, async () => {
      throw storageError(404, { statusCode: '404', error: 'not found', message: 'Bucket not found' });
    }),
    /Bucket not found/
  );
});

test('genuine object-info 400 remains fatal', async () => {
  await assert.rejects(
    storageExists(env, bucket, objectPath, async () => {
      throw storageError(400, { statusCode: '400', error: 'bad request', message: 'Invalid object path' });
    }),
    /Invalid object path/
  );
});

test('existing object remains reported as already present', async () => {
  const exists = await storageExists(env, bucket, objectPath, async () => ({ name: objectPath }));

  assert.equal(exists, true);
});
