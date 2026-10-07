import '@site/style.css';
import { createDemo } from '@site/demo.js';
const q = new URLSearchParams(location.search);
const s = Number(q.get('s') || 1);
if (q.has('social')) document.documentElement.classList.add('social');
document.querySelector(`.shot[data-s="${s}"]`).classList.add('on');
const scenes = { 1: { angle: 78, view: 1, orbit: 0 }, 2: { angle: 58, view: 1, orbit: 0 }, 3: { angle: 45, view: 1, orbit: 1 }, 5: { angle: 100, view: 1, orbit: 0 } };
// Scene 5 shows a frame of the real app, from the App Review recording (1-launch-permission-effect.mov
// at 0:37, lid at 88 degrees), on the screen of an open lid: the store wants the actual app in use.
// So the demo's two drawn layers become that frame and nothing, before the demo loads them.
if (s === 5) {
  const swap = { '/screen-wall.webp': './real-screen.jpg',
    '/screen-windows.webp': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg==' };
  const d = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');
  Object.defineProperty(HTMLImageElement.prototype, 'src', { ...d,
    set(v) { d.set.call(this, swap[new URL(v, location.href).pathname] ?? v); } });
}
const canvas = document.querySelector('#demo');
if (!scenes[s]) { canvas.remove(); document.querySelector('#hills').style.opacity = s === 4 ? .5 : .35; window.__ready = true; }
else {
  const demo = await createDemo(canvas);
  const sc = scenes[s];
  // Ease down through the threshold so the effect engages the way it does on a real lid.
  demo.view = sc.view; demo.orbit = sc.orbit; demo.target = sc.angle;
  setTimeout(() => { window.__ready = true; }, 4000);
}
