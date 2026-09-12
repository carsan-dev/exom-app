import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateRelease } from './verify-release.mjs';
const sha = 'a'.repeat(40);
const run = { path: '.github/workflows/mobile-release.yml', status: 'completed', conclusion: 'success', head_sha: sha };
const manifest = { sha, version: '1.2.3', build: 42 };
test('accepts only the published version of the checked source', () => {
  assert.deepEqual(validateRelease(run, manifest, sha), { version:'1.2.3', build:42 });
});
for (const [name, patch] of Object.entries({ failed:{conclusion:'failure'}, pending:{status:'in_progress'}, anotherSource:{head_sha:'b'.repeat(40)}, anotherWorkflow:{path:'.github/workflows/ci.yml'} })) {
  test(`rejects ${name}`, () => assert.throws(() => validateRelease({...run,...patch},manifest,sha)));
}
test('rejects a mismatching manifest', () => assert.throws(() => validateRelease(run,{...manifest,sha:'b'.repeat(40)},sha)));
test('rejects invalid version/build fields', () => {
  assert.throws(() => validateRelease(run,{...manifest,version:'1.2.3\nINJECTED=x'},sha));
  assert.throws(() => validateRelease(run,{...manifest,build:0},sha));
});
