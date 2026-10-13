import { readFileSync, readdirSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const publishers = ['changelog.yml', 'changelog-merge.yml'];
export function checkQueues(files) {
  for (const name of publishers) {
    const text = files[name];
    if (typeof text !== 'string') throw Error('Missing publisher: ' + name);
    const block = text.match(/^concurrency:\r?\n((?:[ \t]+[^\r\n]*\r?\n)+)/m)?.[1];
    if (!block || !/^  group: discord-changelog\r?$/m.test(block) || !/^  cancel-in-progress: false\r?$/m.test(block) || !/^  queue: max\r?$/m.test(block)) throw Error('Publisher must retain the shared non-cancelling max queue: ' + name);
  }
  for (const [name, text] of Object.entries(files)) {
    const queues = text.split(/\r?\n/).filter(line => /^\s*queue\s*:/.test(line));
    if (queues.length && (!publishers.includes(name) || queues.length !== 1 || queues[0] !== '  queue: max')) throw Error('Unsupported queue configuration: ' + name);
  }
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  checkQueues(Object.fromEntries(readdirSync('.github/workflows').filter(name => /\.ya?ml$/.test(name)).map(name => [name, readFileSync('.github/workflows/' + name, 'utf8')])));
}
