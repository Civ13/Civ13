const path = require('node:path');
const rspack = require('@rspack/core');
module.exports = {
  mode: 'production',
  context: __dirname,
  entry: './src/index.tsx',
  target: ['web', 'browserslist:edge >= 123'],
  devtool: false,
  output: {
    path: path.resolve(__dirname, '../UI/tgui'),
    filename: 'civ13-tgui.js',
    publicPath: '',
    clean: false,
  },
  resolve: { extensions: ['.tsx', '.ts', '.js'] },
  module: { rules: [
    { test: /\.[tj]sx?$/, use: { loader: 'builtin:swc-loader', options: {
      jsc: { parser: { syntax: 'typescript', tsx: true },
        transform: { react: { runtime: 'automatic' } } }
    } } },
    { test: /\.s?css$/, use: [rspack.CssExtractRspackPlugin.loader, 'css-loader', {
      loader: 'sass-loader', options: { implementation: require('sass'), api: 'modern' }
    }] },
    { test: /\.(svg|woff2?|ttf|png)$/, type: 'asset/inline' }
  ] },
  plugins: [new rspack.BannerPlugin({ banner: 'Civ13 tgui adaptation (AGPL-3.0); includes MIT dependencies. Copyright and license notices: THIRD_PARTY.txt (distributed with this bundle).', raw: false }), new rspack.CssExtractRspackPlugin({ filename: 'civ13-tgui.css' })],
  optimization: { splitChunks: false, runtimeChunk: false },
  performance: { hints: false },
};
