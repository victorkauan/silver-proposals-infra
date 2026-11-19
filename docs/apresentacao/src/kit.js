/* kit.js — utilidades de desenho e animação, sem dependências.
   Toda animação é uma função pura do progresso p ∈ [0, 1]: o motor pode tocar, concluir ou
   desfazer qualquer passo sem estado escondido. */
(function () {
  'use strict';
  const NS = 'http://www.w3.org/2000/svg';
  const K = (window.K = {});
  window.SLIDES = [];

  K.clamp = (x, a = 0, b = 1) => (x < a ? a : x > b ? b : x);
  K.lerp = (a, b, t) => a + (b - a) * t;
  K.seg = (p, a, b) => K.clamp((p - a) / (b - a));
  K.ease = {
    out: (t) => 1 - Math.pow(1 - t, 3),
    io: (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
    back: (t) => 1 + 2.70158 * Math.pow(t - 1, 3) + 1.70158 * Math.pow(t - 1, 2),
  };
  K.fmt = (n, d = 0) => n.toLocaleString('pt-BR', { minimumFractionDigits: d, maximumFractionDigits: d });

  K.h = (html) => {
    const t = document.createElement('template');
    t.innerHTML = html.trim();
    return t.content.firstElementChild;
  };
  K.s = (tag, attrs, parent) => {
    const e = document.createElementNS(NS, tag);
    if (attrs) for (const k in attrs) k === 'text' ? (e.textContent = attrs[k]) : e.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(e);
    return e;
  };

  const ICONS = {
    check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    cross: '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>',
    lock: '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 018 0v3"/>',
    key: '<circle cx="8" cy="15" r="4"/><path d="M11 12l8-8M16 7l3 3"/>',
    nokey: '<circle cx="8" cy="15" r="4"/><path d="M11 12l8-8M16 7l3 3M3 3l18 18"/>',
    user: '<circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6"/>',
    eye: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    bell: '<path d="M6 16V11a6 6 0 0112 0v5l2 2H4z"/><path d="M10 21h4"/>',
    doc: '<path d="M7 3h7l4 4v14H7z"/><path d="M14 3v4h4M10 12h5M10 16h5"/>',
  };
  K.icon = (name, cls = '') => `<svg class="ic ${cls}" viewBox="0 0 24 24" aria-hidden="true">${ICONS[name]}</svg>`;

  // Rota ortogonal com cantos arredondados.
  K.route = (pts, r = 16) => {
    let d = `M${pts[0][0]},${pts[0][1]}`;
    for (let i = 1; i < pts.length - 1; i++) {
      const [x0, y0] = pts[i - 1], [x1, y1] = pts[i], [x2, y2] = pts[i + 1];
      const d1 = Math.hypot(x1 - x0, y1 - y0), d2 = Math.hypot(x2 - x1, y2 - y1);
      const rr = Math.min(r, d1 / 2, d2 / 2);
      d += ` L${x1 - ((x1 - x0) / d1) * rr},${y1 - ((y1 - y0) / d1) * rr} Q${x1},${y1} ${x1 + ((x2 - x1) / d2) * rr},${y1 + ((y2 - y1) / d2) * rr}`;
    }
    const z = pts[pts.length - 1];
    return d + ` L${z[0]},${z[1]}`;
  };

  // Diagrama de caixas e arestas que se desenham com o progresso.
  K.diagram = (svg) => {
    const gE = K.s('g', {}, svg), gN = K.s('g', {}, svg), gT = K.s('g', {}, svg);
    const api = { n: {}, e: {} };
    // pos: 'tl' (padrão), 'bl' ou 'br' — canto do rótulo, para não cruzar arestas.
    api.group = (x, y, w, h, label, pos = 'tl') => {
      const g = K.s('g', {}, gE);
      K.s('rect', { x, y, width: w, height: h, rx: 18, class: 'grp' }, g);
      const right = pos === 'br';
      K.s('text', { x: right ? x + w - 18 : x + 18, y: pos === 'tl' ? y + 28 : y + h - 16, class: 'grp-l', 'text-anchor': right ? 'end' : 'start', text: label }, g);
      return { g, show(p) { g.style.opacity = K.clamp(p * 1.6); } };
    };
    api.node = (id, x, y, w, h, title, sub, cls = '') => {
      const g = K.s('g', { class: 'nd ' + cls }, gN);
      K.s('rect', { x, y, width: w, height: h, rx: 14 }, g);
      K.s('rect', { x, y: y + 14, width: 5, height: h - 28, rx: 2.5, class: 'bar' }, g);
      K.s('text', { x: x + w / 2, y: y + h / 2 - (sub ? 13 : 0), class: 't', text: title }, g);
      if (sub) K.s('text', { x: x + w / 2, y: y + h / 2 + 17, class: 'u', text: sub }, g);
      const o = {
        g, x, y, w, h, cx: x + w / 2, cy: y + h / 2,
        show(p) {
          p = K.clamp(p);
          const s = 0.86 + 0.14 * K.ease.back(p);
          g.setAttribute('transform', `translate(${o.cx},${o.cy}) scale(${s}) translate(${-o.cx},${-o.cy})`);
          g.style.opacity = K.clamp(p * 2);
        },
      };
      o.show(1);
      return (api.n[id] = o);
    };
    api.edge = (id, pts, o = {}) => {
      const g = K.s('g', {}, gE);
      const path = K.s('path', { d: K.route(pts, o.r || 16), class: 'edge' }, g);
      const head = K.s('path', { d: 'M1,0 L-12,-6 L-12,6 Z', class: 'head' }, g);
      const lab = o.label ? K.s('text', { x: o.lx, y: o.ly, class: 'edge-l', text: o.label }, g) : null;
      const len = path.getTotalLength();
      const a = path.getPointAtLength(len), b = path.getPointAtLength(Math.max(0, len - 3));
      head.setAttribute('transform', `translate(${a.x},${a.y}) rotate(${(Math.atan2(a.y - b.y, a.x - b.x) * 180) / Math.PI})`);
      path.style.strokeDasharray = `${len} ${len}`;
      const e = {
        g, path, len,
        show(p) {
          p = K.clamp(p);
          path.style.strokeDashoffset = len * (1 - K.ease.io(p));
          head.style.opacity = K.seg(p, 0.85, 1);
          g.style.opacity = p > 0 ? 1 : 0;
          if (lab) lab.style.opacity = K.seg(p, 0.4, 0.8);
        },
        at: (t) => path.getPointAtLength(len * K.clamp(t)),
      };
      e.show(1);
      return (api.e[id] = e);
    };
    api.token = (cls = '') => {
      const c = K.s('circle', { r: 11, class: 'tok ' + cls }, gT);
      c.style.opacity = 0;
      return { el: c, to(pt, op = 1) { c.setAttribute('cx', pt.x); c.setAttribute('cy', pt.y); c.style.opacity = op; }, hide() { c.style.opacity = 0; } };
    };
    return api;
  };

  // Passa um token por uma sequência de arestas, cada uma ocupando a mesma fração de p.
  K.travel = (tok, edges, p) => {
    if (p <= 0 || p >= 1) return tok.hide();
    const n = edges.length, i = Math.min(n - 1, Math.floor(p * n));
    tok.to(edges[i].at(K.ease.io(p * n - i)));
  };

  // Número que conta de 0 até o valor final com o progresso.
  K.count = (el, value, p, d = 0, suffix = '') => {
    el.textContent = K.fmt(value * K.ease.out(K.clamp(p)), d) + suffix;
  };
})();
