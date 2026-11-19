/* slides-a.js — capa, problema e produto (slides 1 a 3). */
(function () {
  'use strict';
  const K = window.K, S = window.SLIDES;

  /* 1. capa: uma proposta comercial que se escreve sozinha */
  S.push({
    id: 'capa', name: 'Silver Proposals', bare: true,
    html: `
      <div class="cover">
        <div class="kicker">Pós-graduação em Engenharia de Software com foco em DevOps · UNIFOR</div>
        <h1 class="title">Silver Proposals</h1>
        <p class="sub">Plataforma de propostas comerciais com IA e esteira DevSecOps</p>
        <div class="author">Victor Kauan <span>Fortaleza-CE · 2026</span></div>
      </div>
      <svg class="fig doc" width="560" height="700" viewBox="0 0 560 700"></svg>`,
    setup(c) {
      const svg = c.$('.doc');
      K.s('rect', { x: 20, y: 20, width: 520, height: 660, rx: 22, class: 'paper' }, svg);
      K.s('text', { x: 64, y: 92, class: 'paper-k', text: 'PROPOSTA COMERCIAL' }, svg);
      const rows = [[64, 150, 360, 'h'], [64, 205, 420], [64, 240, 392], [64, 275, 300], [64, 345, 230, 'h'], [64, 400, 412], [64, 435, 380],
        [64, 470, 260], [64, 540, 190, 'h'], [64, 595, 330], [64, 630, 0, 'mark']];
      const lines = rows.map(([x, y, w, kind]) => {
        if (kind === 'mark') {
          const g = K.s('g', { class: 'paper-mark' }, svg);
          K.s('rect', { x, y: y - 22, width: 168, height: 36, rx: 8 }, g);
          K.s('text', { x: x + 84, y: y - 4, text: '[A DEFINIR]' }, g);
          return { set(p) { g.style.opacity = K.seg(p, 0, 0.4); } };
        }
        const l = K.s('path', { d: `M${x},${y} L${x + w},${y}`, class: kind === 'h' ? 'paper-h' : 'paper-l' }, svg);
        l.style.strokeDasharray = w;
        return { set(p) { l.style.strokeDashoffset = w * (1 - K.ease.out(p)); } };
      });
      return [{
        dur: 2600,
        draw(p) { lines.forEach((l, i) => l.set(K.seg(p, (i / lines.length) * 0.75, (i / lines.length) * 0.75 + 0.25))); },
      }];
    },
  });

  /* 2. problema: três números de fontes publicadas */
  const STATS = [
    { v: 70, d: 0, suf: '%', lbl: 'do tempo dos vendedores vai para tarefas que <b>não são vender</b>', src: 'Salesforce, State of Sales (2024)' },
    { v: 40, d: 0, suf: '%', pre: '−', lbl: 'de tempo em tarefas de <b>escrita profissional</b> com IA generativa, e 18% mais qualidade', src: 'Noy e Zhang, Science (2023)' },
    { v: 13, d: 0, suf: '%', lbl: 'das empresas brasileiras <b>usavam IA</b> em 2024', src: 'Cetic.br, TIC Empresas 2024 (2025)' },
  ];
  S.push({
    id: 'problema', act: 'Contexto', name: 'O problema',
    title: 'Propostas comerciais ainda são <em>escritas à mão</em>, com dados sensíveis circulando sem controle',
    html: `
      <div class="body">
        <div class="stats">${STATS.map((s, i) => `
          <div class="stat rv" data-at="${i}">
            <div class="num">${s.pre || ''}<span class="v">0</span>${s.suf}</div>
            <p class="lbl">${s.lbl}</p>
            <p class="src">${s.src}</p>
          </div>`).join('')}
        </div>
        <div class="risk rv" data-at="3">${K.icon('lock')}<span>Propostas carregam dados de clientes: precisam de <b>controle de acesso, histórico e LGPD</b>, não de anexos soltos.</span></div>
      </div>`,
    setup(c) {
      const vals = c.$$('.stat .v');
      const step = (i) => ({ dur: 1100, draw(p) { K.count(vals[i], STATS[i].v, p, STATS[i].d); } });
      return [step(0), step(1), step(2), { dur: 0, draw() {} }];
    },
  });

  /* 3. produto: o ciclo da proposta na v1 */
  S.push({
    id: 'produto', act: 'Solução', name: 'O produto e o recorte da v1',
    title: 'Do <em>briefing</em> à proposta compartilhada, com a IA escrevendo e o usuário no controle',
    html: `
      <div class="body">
        <svg class="fig flow" width="1700" height="420" viewBox="0 0 1700 420"></svg>
        <div class="scope">
          <div class="scope-row rv" data-at="4"><span class="scope-k">versão 1 · no ar</span>
            <span class="tag">cadastro e login</span><span class="tag">papéis por proposta</span><span class="tag">geração em tempo real</span>
            <span class="tag">versões e conflito</span><span class="tag">link com validade</span></div>
          <div class="scope-row rv" data-at="4" style="--d:.15s"><span class="scope-k">próximos passos</span>
            <span class="tag dim">chat sobre a proposta</span><span class="tag dim">slides gerados</span><span class="tag dim">convites</span>
            <span class="tag dim">cobrança (teste)</span><span class="tag dim">testes de carga</span></div>
        </div>
      </div>`,
    setup(c) {
      const D = K.diagram(c.$('.flow'));
      const W = 300, H = 120, y = 150;
      D.node('brief', 0, y, W, H, 'Briefing', 'cliente, contexto, escopo', 'c-app');
      D.node('ia', 466, y, W, H, 'IA gera o rascunho', 'Amazon Nova 2 Lite', 'c-cloud');
      D.node('edit', 933, y, W, H, 'Usuário revisa', 'editor, versões, [A DEFINIR]', 'c-app');
      D.node('share', 1400, y, W, H, 'Link para o cliente', 'token, validade, revogação', 'c-sec');
      D.edge('e1', [[W, y + H / 2], [466, y + H / 2]], { label: 'streaming', lx: 383, ly: y + H / 2 - 16 });
      D.edge('e2', [[766, y + H / 2], [933, y + H / 2]], { label: 'cada gravação', lx: 850, ly: y + H / 2 - 16 });
      D.edge('e3', [[1233, y + H / 2], [1400, y + H / 2]], { label: 'quando pronto', lx: 1316, ly: y + H / 2 - 16 });
      const order = [['brief'], ['e1', 'ia'], ['e2', 'edit'], ['e3', 'share']];
      return order.map((ids) => ({
        dur: 900,
        draw(p) {
          ids.forEach((id) => (D.n[id] ? D.n[id].show(p) : D.e[id].show(p)));
        },
      }));
    },
  });
})();
