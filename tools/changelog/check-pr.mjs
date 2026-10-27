import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { changelogLine } from './publish.mjs';

export function checkPR(event) {
  if (!event?.pull_request || !Object.hasOwn(event.pull_request, 'body')) {
    throw Error('PR event with a description is required');
  }
  return changelogLine(event.pull_request.body);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const entry = checkPR(JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8')));
    console.log(entry === null ? 'No changelog entry requested.' : 'Changelog entry validated.');
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
