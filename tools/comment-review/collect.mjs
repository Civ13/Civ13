import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync, renameSync, openSync, closeSync, unlinkSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { candidate, eligible, marker, hasReview, prepare, publish } from './review.mjs';

export const REPOSITORIES = ['Civ13/Civ13', 'Civ13/Civ14', 'Civ13/civ13.github.io',
  'Valgorithms/Civilizationbot'];
export function ghClient(repo, execute = execFileSync) {
  if (!REPOSITORIES.includes(repo)) throw new Error('Repository not in the discovered rollout list');
  return (path, options = {}) => {
    const args = ['api', 'repos/' + repo + path];
    if (options.method === 'POST') args.push('--method', 'POST', '--input', '-');
    else args.push('--paginate', '--slurp');
    let value;
    try {
      value = JSON.parse(execute('gh', args,
        { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024, timeout: 120000,
          input: options.body ? JSON.stringify(options.body) : undefined }));
    } catch (error) {
      try { if (JSON.parse(String(error.stdout)).status === '404' ||
        JSON.parse(String(error.stdout)).status === 404) return null; } catch {}
      throw new Error('GitHub CLI request failed');
    }
    if (options.method === 'POST') return value;
    return Array.isArray(value[0]) ? value.flat() : value[0];
  };
}
export async function collect(repo, state, api, now = new Date()) {
  if (!REPOSITORIES.includes(repo)) throw new Error('Repository not in rollout list');
  const since = state.checked_at ?
    new Date(new Date(state.checked_at).getTime() - 300000).toISOString() :
    new Date(now.getTime() - 86400000).toISOString();
  const issueComments = await api('/issues/comments?per_page=100&since=' + encodeURIComponent(since));
  const inline = await api('/pulls/comments?per_page=100&since=' + encodeURIComponent(since));
  const targets = await api('/issues?state=all&per_page=100&since=' + encodeURIComponent(since));
  const open = await api('/pulls?state=open&per_page=100');
  if ([issueComments, inline, targets, open].some(list => list.length > 2000)) {
    throw new Error('Collection exceeds safety bound; narrow repository workload');
  }
  const all = [];
  const add = (event, item, number) => {
    if (!Number.isSafeInteger(number) || number <= 0) throw new Error('Invalid API parent');
    all.push({ event, item, number });
  };
  const numberFrom = url => {
    const escaped = repo.replace(/[.*+?^$\{\}()|[\]\\]/g, '\\$&');
    const match = new RegExp('^https://api.github.com/repos/' + escaped + '/(?:issues|pulls)/(\\d+)$', 'i').exec(url ?? '');
    if (!match) throw new Error('Comment from another repository');
    return Number(match[1]);
  };
  issueComments.forEach(item => add('issue_comment', item, numberFrom(item.issue_url)));
  inline.forEach(item => add('pull_request_review_comment', item, numberFrom(item.pull_request_url)));
  const numbers = [...new Set([...open.map(pr => pr.number),
    ...targets.filter(issue => issue.pull_request).map(issue => issue.number),
    ...all.filter(data => data.event === 'pull_request_review_comment').map(data => data.number)])];
  if (numbers.length > 200) throw new Error('Too many active PRs for bounded review collection');
  for (const number of numbers) {
    const reviews = await api('/pulls/' + number + '/reviews?per_page=100');
    if (reviews.length > 2000) throw new Error('Too many reviews');
    reviews.forEach(item => add('pull_request_review', item, number));
  }
  const records = structuredClone(state.records ?? {});
  let added = 0;
  for (const { event, item, number } of all) {
    const key = marker(event, item);
    const id = repo + ':' + key.slice('<!-- codex-comment-review:v1:'.length, -4);
    for (const record of Object.values(records)) {
      if (record.id !== id && record.repo === repo && record.event === event &&
          record.comment_id === item.id && record.status === 'pending') record.status = 'superseded';
    }
    if (records[id]) continue;
    const action = event === 'pull_request_review' ? 'submitted' : 'created';
    const revision = candidate(event, { action, comment: item, review: item, issue: { number } });
    const priorRevision = Object.values(records).some(r => r.repo === repo && r.event === event && r.comment_id === item.id);
    // Baseline old reviews so edits to them can be detected on later scans.
    const recent = priorRevision || (item.updated_at ?? item.submitted_at ?? item.created_at ?? '') >= since;
    const ownPublished = hasReview(issueComments.filter(c => numberFrom(c.issue_url) === number), key, state.reviewer_login);
    const ownLocalReply = item.user.login === state.reviewer_login && /^Codex review of \[new information\]/.test(item.body ?? '') && /<!-- codex-comment-review:v1:/.test(item.body ?? '');
    const skip = ownLocalReply || !eligible(item, action) || item.state === 'DISMISSED' || ownPublished || !recent;
    records[id] = {
      id, repo, event, comment_id: item.id, number, key,
      status: skip ? 'ignored' : 'pending',
      discovered_at: now.toISOString(),
      revision: item.updated_at ?? item.submitted_at ?? item.created_at,
      author: item.user.login, url: item.html_url,
      // This is untrusted evidence, never a task instruction.
      body: skip ? undefined : item.body.slice(0, 24000),
      path: skip ? undefined : item.path,
      diff_hunk: skip ? undefined : item.diff_hunk?.slice(0, 16000),
      candidate: revision
    };
    if (!skip) added++;
  }
  if (Object.keys(records).length > 50000) throw new Error('State exceeds safety bound');
  return { ...state, version: 1, repo, checked_at: now.toISOString(), records, added };
}
export function acknowledge(state, ids, reviewUrl, status = 'reviewed', note) {
  if (!['reviewed', 'discarded'].includes(status)) throw new Error('Invalid receipt status');
  const next = structuredClone(state);
  for (const id of ids) {
    if (!next.records[id] || next.records[id].status !== 'pending') throw new Error('Unknown pending revision');
    next.records[id].status = status;
    next.records[id].note = note;
    next.records[id].review_url = reviewUrl;
  }
  return next;
}
function argument(name) {
  const position = process.argv.indexOf(name);
  return position < 0 ? undefined : process.argv[position + 1];
}
async function main() {
  const repo = argument('--repo');
  const limit = Number(argument('--limit') ?? 10);
  if (!Number.isSafeInteger(limit) || limit < 1 || limit > 100) throw new Error('Invalid output limit');
  const statePath = resolve(argument('--state') ?? 'data/comment-review/' + repo?.replace('/', '-') + '.json');
  if (!REPOSITORIES.includes(repo)) throw new Error('Specify --repo from discovered rollout list');
  mkdirSync(dirname(statePath), { recursive: true });
  const lockPath = statePath + '.lock';
  const lock = openSync(lockPath, 'wx');
  try {
    let state;
    try { state = JSON.parse(readFileSync(statePath, 'utf8')); }
    catch (error) { if (error.code !== 'ENOENT') throw error; state = { version: 1, records: {} }; }
    if (state.repo && state.repo !== repo) throw new Error('State belongs to another repository');
    if (state.version !== 1 || !state.records) throw new Error('Invalid state format');
    const actor = JSON.parse(execFileSync('gh', ['api', 'user'], { encoding: 'utf8', timeout: 30000 })).login;
    state.repo = repo;
    state.reviewer_login = actor;
    const respond = argument('--respond');
    if (respond) {
      const record = state.records[respond];
      if (!record || record.status !== 'pending') throw new Error('Unknown pending revision');
      const message = readFileSync(argument('--message-file'), 'utf8');
      const posted = await publish(ghClient(repo), record.candidate, repo, record.key, message, actor);
      if (!posted) {
        console.log(JSON.stringify({ id: respond, posted: false, reason: 'Revision no longer current. Collect again.' }));
        return;
      }
      state = acknowledge(state, [respond]);
      writeFileSync(statePath + '.tmp', JSON.stringify(state, null, 2) + '\n');
      renameSync(statePath + '.tmp', statePath);
      console.log(JSON.stringify({ id: respond, posted: true }));
      return;
    }
    const inspect = argument('--inspect');
    if (inspect) {
      const record = state.records[inspect];
      if (!record || record.status !== 'pending') throw new Error('Unknown pending revision');
      const current = await prepare(ghClient(repo), record.candidate, repo, actor);
      if (!current || current.key !== record.key) {
        console.log(JSON.stringify({ id: inspect, current: false, reason: 'Deleted, edited, ignored, or already reviewed. Collect again before responding.' }));
      } else {
        console.log(JSON.stringify({ id: inspect, current: true, prompt: current.prompt }));
      }
      return;
    }
    const ack = argument('--ack');
    const discard = argument('--discard');
    const result = ack || discard ? acknowledge(state, [ack ?? discard],
      argument('--review-url'), discard ? 'discarded' : 'reviewed', argument('--note')) :
      await collect(repo, state, ghClient(repo));
    const temp = statePath + '.tmp';
    writeFileSync(temp, JSON.stringify(result, null, 2) + '\n');
    renameSync(temp, statePath);
    const pending = Object.values(result.records).filter(r => r.status === 'pending')
      .sort((a, b) => (a.event === 'issue_comment') - (b.event === 'issue_comment') ||
        b.discovered_at.localeCompare(a.discovered_at));
    // Stale edits/deletions are checked against the API before a coordinator reviews
    // or posts; the local queue is an audit record, not GitHub's current truth.
    console.log(JSON.stringify({ repo, checked_at: result.checked_at, added: result.added,
      pending_count: pending.length, pending: pending.slice(0, limit).map(r => ({
        id: r.id, event: r.event, number: r.number, author: r.author, url: r.url,
        preview: r.body?.slice(0, 240), path: r.path
      })) }, null, 2));
  } finally {
    closeSync(lock);
    unlinkSync(lockPath);
  }
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(() => { console.error('Collection failed; state cursor was not advanced. Check gh authentication, API access, and state lock.'); process.exitCode = 1; });
}


