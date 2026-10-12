'use strict';
// Bounded, offline recovery writer. Only allowlisted non-secret source is read;
// all generated output is confined to this dated checkpoint directory.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const root = process.cwd();
const evidence = 'docs/evidence/rest-t3c-app-20261008';
const output = path.join(root, evidence, 'checkpoint', 'writer-final');
const files = [
  'lib/features/recap/domain/entities/recap_entity.dart',
  'lib/features/recap/data/models/recap_model.dart',
  'lib/features/recap/presentation/pages/recap_detail_page.dart',
  'lib/features/recap/presentation/widgets/recap_published_review_card.dart',
  'lib/features/recap/presentation/bloc/recap_bloc.dart',
  'test/features/recap/data/models/recap_model_test.dart',
  'test/features/recap/presentation/widgets/recap_published_review_card_test.dart',
  'test/features/recap/presentation/pages/recap_detail_page_test.dart',
  'test/features/recap/presentation/bloc/recap_bloc_test.dart',
  '.gitignore',
  `${evidence}/recap_ui_harness.dart`,
  `${evidence}/README.md`,
  `${evidence}/checkpoint.cjs`,
];
const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim();
const head = git('rev-parse', 'HEAD');
if (head !== 'db72c7feee2c3ba91bc71068a7918903179ca78d') throw new Error('Unexpected baseline');
if (fs.existsSync(output)) throw new Error('Checkpoint already exists; preserve it');
fs.mkdirSync(output, { recursive: true });
const hashes = {};
for (const file of files) {
  const bytes = fs.readFileSync(path.join(root, file));
  hashes[file] = crypto.createHash('sha256').update(bytes).digest('hex');
  const target = path.join(output, 'files', `${file}.snapshot`);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, bytes, { flag: 'wx' });
}
fs.writeFileSync(path.join(output, 'tracked.patch'), execFileSync('git', ['diff', '--binary', '--', ...files], { cwd: root }), { flag: 'wx' });
const manifest = {
  localOnly: true, timestamp: new Date().toISOString(), root, head,
  branch: git('branch', '--show-current'), upstream: git('rev-parse', '--abbrev-ref', '@{upstream}'),
  status: git('status', '--short'), staged: git('diff', '--cached', '--name-only'),
  files: hashes,
};
fs.writeFileSync(path.join(output, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`, { flag: 'wx' });
console.log(JSON.stringify({ checkpoint: path.relative(root, output), files: hashes }, null, 2));
