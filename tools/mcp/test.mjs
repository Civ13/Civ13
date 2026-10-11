import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import path from 'node:path';

test('real stdio handshake, discovery, bounded calls and error isolation', async () => {
 const transport = new StdioClientTransport({command:process.execPath,args:[path.join(import.meta.dirname,'server.mjs')],env:{...process.env}});
 const client = new Client({name:'civ13-test',version:'1.0.0'});
 try {
  await client.connect(transport);
  const tools = await client.listTools(); assert.equal(tools.tools.length,5);
  const call = (name,args={}) => client.callTool({name,arguments:args});
  const read = await call('source_read',{path:'README.md',lines:2}); assert.equal(read.isError,undefined);
  assert.equal((await call('source_read',{path:'../config.txt'})).isError,true);
  assert.equal((await call('source_read',{path:'data/player_saves.dm'})).isError,true);
  assert.equal((await call('source_read',{path:'README.md',lines:201})).isError,true);
  const search = await call('source_search',{query:'/mob',limit:2}); assert.equal(search.structuredContent.matches.length,2);
  assert.equal((await call('project_diagnostics')).isError,undefined);
  assert.equal((await client.readResource({uri:'civ13://guide'})).contents.length,1);
  assert.equal((await client.readResource({uri:'civ13://api-guide'})).contents.length,1);
  assert.equal((await client.readResource({uri:'civ13://api-index'})).contents.length,1);
  if(process.env.CIV13_DM_COMPILER) {
   const smoke = await call('compiler_smoke'); assert.equal(smoke.structuredContent.exitCode,0); assert.match(smoke.structuredContent.output,/0 errors/);
   const info = await call('compiler_info'); assert.match(info.structuredContent.output,/Dream Maker|DM compiler|BYOND/i);
  } else assert.equal((await call('compiler_smoke')).isError,true);
  await client.ping();
 } finally { await client.close(); }
});

test('cancellation stops owned compiler and removes temporary state', async () => {
 const fs = await import('node:fs/promises'); const os = await import('node:os');
 const hold = path.join(os.tmpdir(),'civ13-mcp-hold-' + process.pid + '.cjs');
 await fs.writeFile(hold,'setInterval(() => {}, 1000);');
 const before = new Set((await fs.readdir(os.tmpdir())).filter(n=>n.startsWith('civ13-mcp-info-')));
 const transport = new StdioClientTransport({command:process.execPath,args:[path.join(import.meta.dirname,'server.mjs')],env:{...process.env,CIV13_DM_COMPILER:process.execPath,NODE_OPTIONS:`--require="${hold.replaceAll(path.sep,"/")}"`}});
 const client = new Client({name:'cancel-test',version:'1.0.0'});
 try {
  await client.connect(transport);
  const controller = new AbortController();
  const pending = client.callTool({name:'compiler_info',arguments:{}},undefined,{signal:controller.signal});
  await new Promise(r=>setTimeout(r,150)); controller.abort();
  await assert.rejects(pending);
  await new Promise(r=>setTimeout(r,300));
  const after = (await fs.readdir(os.tmpdir())).filter(n=>n.startsWith('civ13-mcp-info-') && !before.has(n));
  assert.deepEqual(after,[]); await client.ping();
 } finally { await client.close(); await fs.rm(hold,{force:true}); }
});



test('realpath rejects directory links escaping configured root', async () => {
 const fs = await import('node:fs/promises'); const os = await import('node:os');
 const dir = await fs.mkdtemp(path.join(os.tmpdir(),'civ13-mcp-paths-'));
 const repo = path.join(dir,'repo'), outside = path.join(dir,'outside');
 await fs.mkdir(repo); await fs.mkdir(outside);
 await fs.writeFile(path.join(outside,'escape.dm'),'private fixture');
 await fs.symlink(outside,path.join(repo,'code'),process.platform==='win32'?'junction':'dir');
 const transport = new StdioClientTransport({command:process.execPath,args:[path.join(import.meta.dirname,'server.mjs'),repo]});
 const client = new Client({name:'path-test',version:'1.0.0'});
 try {
  await client.connect(transport);
  const response = await client.callTool({name:'source_read',arguments:{path:'code/escape.dm'}});
  assert.equal(response.isError,true); assert.match(response.content[0].text,/escapes repository/);
 } finally { await client.close(); await fs.rm(dir,{recursive:true,force:true}); }
});
