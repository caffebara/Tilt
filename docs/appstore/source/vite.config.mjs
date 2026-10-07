const SITE = '/Users/song/Developer/web-builder/tilt';
export default {
  root: import.meta.dirname,
  publicDir: SITE + '/public',
  resolve: { alias: { '@site': SITE + '/src' } },
  // demo.js?still: the demo with its effect held off, for a screen that shows a real capture.
  plugins: [{ name: 'still', transform(code, id) {
    if (id.endsWith('demo.js?still')) return code.replace('nextEngaged(state.engaged, a)', 'false');
  } }],
  server: { port: 5287, strictPort: true, fs: { allow: [SITE, import.meta.dirname] } },
};
