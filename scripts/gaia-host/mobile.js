'use strict';
const element = id => document.getElementById(id);
const buttons = [...document.querySelectorAll('[data-action]')];
const labels = {start: 'Start', stop: 'Save and stop', restart: 'Restart'};
let pending = null;
let fetching = false;
async function api(path, body) {
    const options = {cache: 'no-store', credentials: 'same-origin', signal: AbortSignal.timeout(90000)};
    if (body) Object.assign(options, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body)});
    const response = await fetch(path, options);
    if (!response.ok) throw new Error('Request unavailable or refused. Check status and the desktop host.');
    return response.json();
}
async function refresh() {
    if (fetching || pending) return;
    fetching = true;
    buttons.forEach(button => button.disabled = true);
    try {
        const data = await api('/api/status');
        element('status').textContent = `${data.state} / ${data.players === null ? 'player count unknown' : data.players + ' players'}${data.busy ? ' / operation in progress' : ''}`;
        element('progress').textContent = `Latest host operation: ${data.operation.action} / ${data.operation.phase}${data.operation.failed ? '. See the desktop for private error details.' : ''}`;
        element('logs').replaceChildren(...data.logs.map(log => {
            const item = document.createElement('li');
            item.textContent = `${new Date(log.at * 1000).toLocaleString()}: ${labels[log.action] || log.action} / ${log.result}${log.progress ? ' / ' + log.progress.phase : ''}`;
            return item;
        }));
        buttons.forEach(button => button.disabled = data.busy);
    } catch (error) {
        element('status').textContent = 'Status unavailable. Controls are paused until a successful refresh.';
    } finally { fetching = false; }
}
buttons.forEach(button => button.addEventListener('click', async () => {
    buttons.forEach(item => item.disabled = true);
    pending = {action: button.dataset.action};
    try {
        pending = await api('/api/prepare', pending);
        element('confirm-title').textContent = labels[pending.action] + '?';
        element('confirm-text').textContent = pending.action === 'stop'
            ? 'Save the world, then stop the server? Players will be disconnected. This may take several minutes.'
            : (pending.action === 'restart' ? 'Save and stop the world, disconnecting players, then restart? ' : 'Start the server? ')
              + 'This fetches the configured branch and may compile newer source before starting. Failure leaves the server stopped.';
        element('confirm').showModal();
    } catch (error) { pending = null; element('message').textContent = error.message; await refresh(); }
}));
element('cancel').addEventListener('click', () => { element('confirm').close(); pending = null; refresh(); });
element('confirm').addEventListener('cancel', () => { pending = null; refresh(); });
element('submit').addEventListener('click', async () => {
    if (!pending) return;
    const request = pending;
    element('submit').disabled = true;
    element('confirm').close();
    try {
        const result = await api('/api/action', request);
        element('message').textContent = result.result === 'accepted'
            ? 'Accepted. The worker continues even if this phone disconnects.'
            : `${result.result}. Review the desktop before attempting another action.`;
    } catch (error) { element('message').textContent = 'Result uncertain. Refresh status and check the desktop; do not repeat the action.'; }
    finally { pending = null; element('submit').disabled = false; await refresh(); }
});
element('refresh').addEventListener('click', refresh);
document.addEventListener('visibilitychange', () => { if (!document.hidden) refresh(); });
setInterval(() => { if (!document.hidden) refresh(); }, 10000);
refresh();
