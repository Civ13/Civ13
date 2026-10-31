// Use Rspack's build API; no development-server dependency or listening socket.
const { rspack } = require('@rspack/core');
const config = require('../rspack.config.cjs');
const compiler = rspack(config);
compiler.run((error, stats) => {
  if (error) { console.error(error); process.exitCode = 1; }
  else {
    console.log(stats.toString({ colors: false, modules: false, chunks: false }));
    if (stats.hasErrors()) process.exitCode = 1;
  }
  compiler.close(closeError => {
    if (closeError) { console.error(closeError); process.exitCode = 1; }
  });
});
