/* UKT — generador de adoquinado (vanilla JS, sin dependencias)
 *
 * Uso rápido:
 *   <canvas data-ukt-cobble data-cell="0.14" data-seed="7"></canvas>
 *   <script src="ukt-cobble.js"></script>
 * El script pinta todos los canvas con [data-ukt-cobble] y los repinta al
 * redimensionar o cuando aparecen nuevos en el DOM (SPA / React).
 *
 * En React:
 *   import { paintCobble } from './ukt-cobble.js';
 *   useEffect(() => { paintCobble(ref.current, { cell: 0.14, seed: 7 }); }, []);
 *
 * data-cell / cell: alto de la piedra como fracción del alto del canvas.
 *   0.12–0.14 paneles grandes · 0.18 iconos · 0.30 barras bajas
 */
(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.UKTCobble = api;
})(typeof self !== 'undefined' ? self : this, function () {
  var JOINT = '#082015';
  var TONES = [
    ['#8CCBAA', '#3F8663'], ['#9ED6BA', '#4D9375'], ['#7CBF9C', '#317256'],
    ['#A8DCC2', '#589E80'], ['#6FB391', '#2A6749'], ['#93D0B0', '#458C6B']
  ];

  function rng(seed) {
    var a = (seed * 1664525 + 1013904223) | 0;
    return function () {
      a = (a * 1664525 + 1013904223) | 0;
      return ((a >>> 8) & 0xffffff) / 0xffffff;
    };
  }

  function slabPath(ctx, rx, ry, rand) {
    var jx = function () { return (rand() - 0.5) * rx * 0.26; };
    var jy = function () { return (rand() - 0.5) * ry * 0.26; };
    var c = [
      [-rx + jx(), -ry + jy()], [rx + jx(), -ry + jy()],
      [rx + jx(), ry + jy()], [-rx + jx(), ry + jy()]
    ];
    var pts = [];
    for (var i = 0; i < 4; i++) {
      pts.push(c[i]);
      if (rand() < 0.45) {
        var q = c[(i + 1) % 4], t = 0.35 + rand() * 0.3;
        pts.push([
          c[i][0] + (q[0] - c[i][0]) * t + jx() * 0.5,
          c[i][1] + (q[1] - c[i][1]) * t + jy() * 0.5
        ]);
      }
    }
    var n = pts.length;
    var r = Math.max(0.8, Math.min(rx, ry) * 0.1);
    var mid = function (p, q) { return [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2]; };
    var s = mid(pts[n - 1], pts[0]);
    ctx.beginPath();
    ctx.moveTo(s[0], s[1]);
    for (var k = 0; k < n; k++) {
      var p = pts[k], q2 = pts[(k + 1) % n];
      ctx.arcTo(p[0], p[1], q2[0], q2[1], r);
    }
    ctx.closePath();
  }

  function slab(ctx, cx, cy, rx, ry, rand, tone, shadow) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate((rand() - 0.5) * 0.16);
    slabPath(ctx, rx, ry, rand);
    ctx.strokeStyle = shadow;
    ctx.lineWidth = Math.max(1, Math.min(rx, ry) * 0.12);
    ctx.stroke();
    ctx.fillStyle = tone[1];
    ctx.fill();
    ctx.save();
    ctx.clip();
    var v = rand();
    if (v < 0.14) { ctx.fillStyle = 'rgba(4,16,10,0.30)'; ctx.fillRect(-rx, -ry, rx * 2, ry * 2); }
    else if (v > 0.78) { ctx.fillStyle = 'rgba(214,240,224,0.13)'; ctx.fillRect(-rx, -ry, rx * 2, ry * 2); }
    if (ry > 3) {
      var specks = Math.min(26, Math.round(rx * ry * 0.05));
      for (var s2 = 0; s2 < specks; s2++) {
        ctx.fillStyle = rand() < 0.5 ? 'rgba(255,255,255,0.07)' : 'rgba(0,0,0,0.09)';
        ctx.fillRect(-rx + rand() * rx * 2, -ry + rand() * ry * 2, 1.6, 1.6);
      }
    }
    if (ry > 4) {
      ctx.lineWidth = 1;
      ctx.strokeStyle = tone[0];
      ctx.globalAlpha = 0.5;
      ctx.beginPath();
      ctx.moveTo(-rx, -ry + 0.7);
      ctx.lineTo(rx, -ry + 0.7);
      ctx.stroke();
      ctx.globalAlpha = 1;
    }
    ctx.restore();
    ctx.restore();
  }

  function paintCobble(canvas, opts) {
    if (!canvas) return;
    opts = opts || {};
    var w = canvas.clientWidth || canvas.width;
    var h = canvas.clientHeight || canvas.height;
    if (!w || !h) return false;
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
    var ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    var joint = opts.joint || canvas.dataset.joint || JOINT;
    var shadow = 'rgba(3,12,8,' + (opts.shadow || 0.72) + ')';
    var seed = +(opts.seed || canvas.dataset.seed || 7) + 11;
    var frac = +(opts.cell || canvas.dataset.cell || 0.16);
    var rand = rng(seed);

    ctx.fillStyle = joint;
    ctx.fillRect(0, 0, w, h);

    var grains = Math.min(2600, Math.round((w * h) / 260));
    for (var i = 0; i < grains; i++) {
      ctx.fillStyle = rand() < 0.5 ? 'rgba(214,240,224,0.06)' : 'rgba(0,0,0,0.18)';
      ctx.fillRect(rand() * w, rand() * h, 1.4, 1.4);
    }

    var cell = Math.max(5, h * frac);
    var gap = Math.max(1.2, cell * 0.15);
    var y = -cell * 0.4, guard = 0;
    while (y < h + cell && guard < 300) {
      var rh = cell * (0.82 + rand() * 0.36);
      var x = -cell * (0.2 + rand() * 0.6), g2 = 0;
      while (x < w + cell && g2 < 500) {
        var sw = cell * (rand() < 0.22 ? 0.45 + rand() * 0.3 : 0.8 + rand() * 0.75);
        slab(ctx, x + sw * 0.5, y + rh * 0.5 + (rand() - 0.5) * gap * 0.5,
          Math.max(1.5, (sw - gap) * 0.5), Math.max(1.5, (rh - gap) * 0.5),
          rand, TONES[Math.floor(rand() * TONES.length)], shadow);
        x += sw;
        g2++;
      }
      y += rh;
      guard++;
    }

    if (opts.vignette !== false) {
      var g = ctx.createRadialGradient(w / 2, h * 0.62, Math.min(w, h) * 0.22,
        w / 2, h * 0.62, Math.max(w, h) * 0.8);
      g.addColorStop(0, 'rgba(0,0,0,0)');
      g.addColorStop(1, 'rgba(3,14,9,0.62)');
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, w, h);
    }
    return true;
  }

  function sweep() {
    var list = document.querySelectorAll('canvas[data-ukt-cobble]');
    for (var i = 0; i < list.length; i++) {
      var c = list[i];
      var want = Math.round(c.clientWidth * Math.min(window.devicePixelRatio || 1, 2));
      if (want > 0 && c.width !== want) paintCobble(c);
    }
  }

  function autoInit() {
    if (typeof document === 'undefined') return;
    sweep();
    if (typeof MutationObserver === 'function') {
      new MutationObserver(sweep).observe(document.documentElement, { childList: true, subtree: true });
    }
    window.addEventListener('resize', function () {
      var list = document.querySelectorAll('canvas[data-ukt-cobble]');
      for (var i = 0; i < list.length; i++) paintCobble(list[i]);
    });
  }

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', autoInit);
    else autoInit();
  }

  return { paintCobble: paintCobble, sweep: sweep, TONES: TONES, JOINT: JOINT };
});
