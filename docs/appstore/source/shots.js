import '@site/style.css';
import { createDemo } from '@site/demo.js';
const q = new URLSearchParams(location.search);
const s = Number(q.get('s') || 1);
if (q.has('social')) document.documentElement.classList.add('social');
document.querySelector(`.shot[data-s="${s}"]`).classList.add('on');
const scenes = { 1: { angle: 78, view: 1, orbit: 0 }, 2: { angle: 58, view: 1, orbit: 0 }, 3: { angle: 45, view: 1, orbit: 1 } };
const canvas = document.querySelector('#demo');
if (!scenes[s]) { canvas.remove(); document.querySelector('#hills').style.opacity = s === 4 ? .5 : .35; window.__ready = true; }
else {
  const demo = await createDemo(canvas);
  const sc = scenes[s];
  // Ease down through the threshold so the effect engages the way it does on a real lid.
  demo.view = sc.view; demo.orbit = sc.orbit; demo.target = sc.angle;
  setTimeout(() => { window.__ready = true; }, 4000);
}
