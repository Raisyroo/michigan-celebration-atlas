import assert from 'node:assert/strict';
import test from 'node:test';
import { storageUploadCurlArgs } from '../scripts/upload-reviewed-flyers.mjs';

test('storage upload curl args pass the full Windows-safe Storage URL as one argument', () => {
  const env = { url: 'https://example.supabase.co' };
  const bucket = 'celebration-atlas-media';
  const objectPath = 'events/black-river-tattoo-convention/flyer/black-river-tattoo-convention.webp';

  assert.deepEqual(storageUploadCurlArgs(env, bucket, objectPath), [
    '--request', 'POST',
    '--data-binary', '@-',
    '--fail-with-body',
    'https://example.supabase.co/storage/v1/object/celebration-atlas-media/events/black-river-tattoo-convention/flyer/black-river-tattoo-convention.webp'
  ]);
});
