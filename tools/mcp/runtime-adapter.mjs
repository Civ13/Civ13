import path from 'node:path';
import { spawn } from 'node:child_process';

// Configuration is operator-owned process environment, never a tool argument.
export function createRuntimeAdapter(env, bridge, spawnProcess = spawn) {
  const enabled = env.CIV13_RUNTIME_ENABLED === '1';
  const config = ['ROOT', 'REVISION', 'SESSION', 'ROUND'].map(key => env[`CIV13_RUNTIME_${key}`]);
  const executable = env.CIV13_RUNTIME_PYTHON;
  let active = false;
  let currentStop = null;
  async function run(method, signal) {
    if (!enabled) throw Error('Runtime adapter disabled');
    if (!['recovery', 'variables'].includes(method)) throw Error('Runtime adapter method rejected');
    if (!executable || !path.isAbsolute(executable) || /^(\\\\|\/\/)/.test(executable) ||
        !config[0] || !path.isAbsolute(config[0]) || /^(\\\\|\/\/)/.test(config[0]) ||
        !/^[0-9a-f]{40}$/.test(config[1] || '') || !/^[0-9a-f]{32}$/.test(config[2] || '') ||
        !/^[A-Za-z0-9_-]{1,160}$/.test(config[3] || '')) throw Error('Runtime adapter configuration invalid');
    if (active) throw Error('Runtime adapter busy');
    if (signal?.aborted) throw Error('Cancelled');
    active = true;
    return await new Promise((resolve, reject) => {
        const childEnv = { CIV13_RUNTIME_ROOT:config[0], CIV13_RUNTIME_REVISION:config[1],
          CIV13_RUNTIME_SESSION:config[2], CIV13_RUNTIME_ROUND:config[3] };
        for (const key of ['SystemRoot', 'WINDIR']) if (env[key]) childEnv[key] = env[key];
        let child;
        try { child = spawnProcess(executable, ['-I', '-B', bridge, method], {shell:false, windowsHide:true,
          stdio:['ignore','pipe','ignore'], env:childEnv}); }
        catch { active = false; reject(Error('Runtime adapter unavailable')); return; }
        let chunks = [], bytes = 0, settled = false;
        let timer;
        const clean = () => { clearTimeout(timer); signal?.removeEventListener('abort', stop); };
        const stop = () => {
          if (!settled) { settled = true; clean(); reject(Error('Runtime adapter unavailable or cancelled')); }
          // Keep the slot occupied until close/error confirms the child is gone.
          try { child.kill(); } catch { /* Unknown child state remains busy. */ }
        };
        currentStop = stop;
        timer = setTimeout(stop, 17000);
        child.stdout.on('data', chunk => { bytes += chunk.length; if (bytes > 32768) stop(); else chunks.push(chunk); });
        child.on('error', () => { if (!settled) { settled = true; clean(); reject(Error('Runtime adapter unavailable')); } });
        child.on('close', code => {
          active = false; currentStop = null; if (settled) return; settled = true; clean();
          if (code !== 0) { reject(Error('Runtime adapter unavailable')); return; }
          try {
            const result = JSON.parse(Buffer.concat(chunks).toString('utf8'));
            if (!result || typeof result !== 'object' || Array.isArray(result) || typeof result.ok !== 'boolean') throw Error();
            resolve(result);
          } catch { reject(Error('Runtime adapter returned invalid data')); }
        });
        signal?.addEventListener('abort', stop, {once:true});
        if (signal?.aborted) stop();
      });
  }
  return { enabled, run, close: () => currentStop?.() };
}
