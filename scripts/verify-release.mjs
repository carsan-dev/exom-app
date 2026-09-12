import { readFileSync, appendFileSync, mkdtempSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

export function validateRelease(run, manifest, sha) {
  if (run.path !== '.github/workflows/mobile-release.yml' ||
      run.status !== 'completed' || run.conclusion !== 'success' ||
      run.head_sha !== sha || manifest.sha !== sha ||
      !/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(manifest.version) ||
      !Number.isSafeInteger(manifest.build) || manifest.build < 1) {
    throw Error('Metadata requires a successful Mobile Release and manifest for this exact commit');
  }
  return { version: manifest.version, build: manifest.build };
}

async function main() {
  const { RELEASE_RUN_ID: id, GITHUB_REPOSITORY: repo, GITHUB_SHA: sha, GH_TOKEN: token } = process.env;
  if (!/^\d+$/.test(id ?? '') || !/^[\w.-]+\/[\w.-]+$/.test(repo ?? '') || !/^[a-f0-9]{40}$/.test(sha ?? '')) throw Error('Invalid release identity');
  const response = await fetch(`https://api.github.com/repos/${repo}/actions/runs/${id}`, {
    headers: { Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28' },
  });
  if (!response.ok) throw Error(`Cannot verify release run (${response.status})`);
  const run = await response.json();
  const directory = mkdtempSync(join(tmpdir(), 'exom-release-'));
  const result = spawnSync('gh', ['run','download',id,'--repo',repo,'--name','release-manifest','--dir',directory], { encoding: 'utf8', windowsHide: true });
  if (result.status !== 0) throw Error('Published release manifest missing or expired; rerun the original release finalization');
  const manifest = JSON.parse(readFileSync(join(directory,'release-manifest.json'),'utf8'));
  const release = validateRelease(run, manifest, sha);
  appendFileSync(process.env.GITHUB_ENV, `BUILD_NAME=${release.version}\nBUILD_NUMBER=${release.build}\n`);
  console.log(`Verified Mobile Release ${id}, source ${sha}, version ${release.version} (${release.build})`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  let complete = false;
  process.on('beforeExit', () => {
    if (!complete) { console.error('Release verification did not complete'); process.exitCode = 1; }
  });
  main().then(() => { complete = true; }).catch(error => { console.error(error.message); process.exitCode = 1; });
}
