// UKT — generador de adoquinado (portado del paquete de identidad,
// ukt-identity/js/ukt-cobble.js, a un módulo TS sin dependencias del
// DOM global para usarlo desde un componente cliente de React).
//
// paintCobble(canvas, { cell, seed, joint, shadow, vignette }):
//   cell = alto de la piedra como fracción del alto del canvas.
//     0.12–0.14 paneles grandes · 0.18 iconos · 0.30 barras bajas.
//   seed fija el patrón (mismo número = mismo dibujo).

const JOINT = "#082015";
const TONES: [string, string][] = [
  ["#8CCBAA", "#3F8663"],
  ["#9ED6BA", "#4D9375"],
  ["#7CBF9C", "#317256"],
  ["#A8DCC2", "#589E80"],
  ["#6FB391", "#2A6749"],
  ["#93D0B0", "#458C6B"],
];

function rng(seed: number) {
  let a = (seed * 1664525 + 1013904223) | 0;
  return function () {
    a = (a * 1664525 + 1013904223) | 0;
    return ((a >>> 8) & 0xffffff) / 0xffffff;
  };
}

function slabPath(
  ctx: CanvasRenderingContext2D,
  rx: number,
  ry: number,
  rand: () => number
) {
  const jx = () => (rand() - 0.5) * rx * 0.26;
  const jy = () => (rand() - 0.5) * ry * 0.26;
  const c: [number, number][] = [
    [-rx + jx(), -ry + jy()],
    [rx + jx(), -ry + jy()],
    [rx + jx(), ry + jy()],
    [-rx + jx(), ry + jy()],
  ];
  const pts: [number, number][] = [];
  for (let i = 0; i < 4; i++) {
    pts.push(c[i]);
    if (rand() < 0.45) {
      const q = c[(i + 1) % 4];
      const t = 0.35 + rand() * 0.3;
      pts.push([
        c[i][0] + (q[0] - c[i][0]) * t + jx() * 0.5,
        c[i][1] + (q[1] - c[i][1]) * t + jy() * 0.5,
      ]);
    }
  }
  const n = pts.length;
  const r = Math.max(0.8, Math.min(rx, ry) * 0.1);
  const mid = (p: [number, number], q: [number, number]): [number, number] => [
    (p[0] + q[0]) / 2,
    (p[1] + q[1]) / 2,
  ];
  const s = mid(pts[n - 1], pts[0]);
  ctx.beginPath();
  ctx.moveTo(s[0], s[1]);
  for (let k = 0; k < n; k++) {
    const p = pts[k];
    const q2 = pts[(k + 1) % n];
    ctx.arcTo(p[0], p[1], q2[0], q2[1], r);
  }
  ctx.closePath();
}

function slab(
  ctx: CanvasRenderingContext2D,
  cx: number,
  cy: number,
  rx: number,
  ry: number,
  rand: () => number,
  tone: [string, string],
  shadow: string
) {
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
  const v = rand();
  if (v < 0.14) {
    ctx.fillStyle = "rgba(4,16,10,0.30)";
    ctx.fillRect(-rx, -ry, rx * 2, ry * 2);
  } else if (v > 0.78) {
    ctx.fillStyle = "rgba(214,240,224,0.13)";
    ctx.fillRect(-rx, -ry, rx * 2, ry * 2);
  }
  if (ry > 3) {
    const specks = Math.min(26, Math.round(rx * ry * 0.05));
    for (let s2 = 0; s2 < specks; s2++) {
      ctx.fillStyle = rand() < 0.5 ? "rgba(255,255,255,0.07)" : "rgba(0,0,0,0.09)";
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

export type PaintCobbleOptions = {
  cell?: number;
  seed?: number;
  joint?: string;
  shadow?: number;
  vignette?: boolean;
};

export function paintCobble(
  canvas: HTMLCanvasElement | null,
  opts: PaintCobbleOptions = {}
): boolean {
  if (!canvas) return false;
  const w = canvas.clientWidth || canvas.width;
  const h = canvas.clientHeight || canvas.height;
  if (!w || !h) return false;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = Math.round(w * dpr);
  canvas.height = Math.round(h * dpr);
  const ctx = canvas.getContext("2d");
  if (!ctx) return false;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

  const joint = opts.joint || JOINT;
  const shadow = `rgba(3,12,8,${opts.shadow ?? 0.72})`;
  const seed = (opts.seed ?? 7) + 11;
  const frac = opts.cell ?? 0.16;
  const rand = rng(seed);

  ctx.fillStyle = joint;
  ctx.fillRect(0, 0, w, h);

  const grains = Math.min(2600, Math.round((w * h) / 260));
  for (let i = 0; i < grains; i++) {
    ctx.fillStyle = rand() < 0.5 ? "rgba(214,240,224,0.06)" : "rgba(0,0,0,0.18)";
    ctx.fillRect(rand() * w, rand() * h, 1.4, 1.4);
  }

  const cell = Math.max(5, h * frac);
  const gap = Math.max(1.2, cell * 0.15);
  let y = -cell * 0.4;
  let guard = 0;
  while (y < h + cell && guard < 300) {
    const rh = cell * (0.82 + rand() * 0.36);
    let x = -cell * (0.2 + rand() * 0.6);
    let g2 = 0;
    while (x < w + cell && g2 < 500) {
      const sw = cell * (rand() < 0.22 ? 0.45 + rand() * 0.3 : 0.8 + rand() * 0.75);
      slab(
        ctx,
        x + sw * 0.5,
        y + rh * 0.5 + (rand() - 0.5) * gap * 0.5,
        Math.max(1.5, (sw - gap) * 0.5),
        Math.max(1.5, (rh - gap) * 0.5),
        rand,
        TONES[Math.floor(rand() * TONES.length)],
        shadow
      );
      x += sw;
      g2++;
    }
    y += rh;
    guard++;
  }

  if (opts.vignette !== false) {
    const g = ctx.createRadialGradient(
      w / 2,
      h * 0.62,
      Math.min(w, h) * 0.22,
      w / 2,
      h * 0.62,
      Math.max(w, h) * 0.8
    );
    g.addColorStop(0, "rgba(0,0,0,0)");
    g.addColorStop(1, "rgba(3,14,9,0.62)");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, w, h);
  }
  return true;
}
