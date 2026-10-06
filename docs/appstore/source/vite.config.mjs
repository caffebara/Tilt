const SITE = '/Users/song/Developer/web-builder/tilt';
export default {
  root: import.meta.dirname,
  publicDir: SITE + '/public',
  resolve: { alias: { '@site': SITE + '/src' } },
  server: { port: 5287, strictPort: true, fs: { allow: [SITE, import.meta.dirname] } },
};
