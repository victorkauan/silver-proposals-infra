/* slides-c.js — segurança, observabilidade e resultados (slides 6 e 7). Números reais da v1. */
(function () {
  'use strict';
  const K = window.K, S = window.SLIDES;

  /* 6. segurança e observabilidade */
  const SEC = [
    ['nokey', 'Nenhuma chave estática', 'OIDC na esteira, papéis IAM na aplicação; zero chaves de acesso na conta'],
    ['check', '7 ferramentas de varredura', 'sem vulnerabilidades altas na versão integrada'],
    ['lock', 'Modelo de ameaças e LGPD', '14 ameaças mapeadas, registro de tratamento e lacunas explícitas'],
  ];
  S.push({
    id: 'operacao', act: 'Operação', name: 'Segurança e observabilidade',
    title: 'Segurança desde o pull request e <em>visibilidade</em> até a chamada ao modelo',
    html: `
      <div class="body">
        <div class="sec">${SEC.map(([ic, t, s], i) => `
          <div class="sec-i rv c-sec" data-at="0" style="--d:${i * 0.18}s">${K.icon(ic)}<div><b>${t}</b><span>${s}</span></div></div>`).join('')}
        </div>
        <div class="trace">
          <div class="trace-hd">trace de uma geração real em staging · AWS X-Ray</div>
          <div class="tr"><span class="tr-l mono">POST /proposals/{id}/generate</span><div class="tr-b"><i class="b-req"></i></div><span class="tr-v mono v-req">0,00 s</span></div>
          <div class="tr"><span class="tr-l mono">Bedrock · ConverseStream</span><div class="tr-b"><i class="b-llm"></i></div><span class="tr-v mono v-llm">0,00 s</span></div>
          <div class="trace-f rv" data-at="1"><span class="num share">90%</span><span>do tempo da requisição é o modelo: é ali que a latência e o custo do produto estão</span></div>
          <div class="alarm rv" data-at="2">${K.icon('bell')}<span><b>21 alarmes</b> por e-mail · caminho de alerta testado: ALARM → OK</span></div>
        </div>
      </div>`,
    note: 'Logs JSON com request ID e trace ID; tokens de links públicos removidos dos logs e dos traces depois de encontrados na verificação em staging.',
    setup(c) {
      const req = c.$('.b-req'), llm = c.$('.b-llm'), vr = c.$('.v-req'), vl = c.$('.v-llm');
      const TOTAL = 8.46, LLM = 7.6;
      return [
        { dur: 600, draw() {} },
        {
          dur: 2200,
          draw(p) {
            const a = K.seg(p, 0, 0.55), b = K.seg(p, 0.2, 0.9);
            req.style.width = (a * 100) + '%';
            llm.style.width = (b * LLM / TOTAL) * 100 + '%';
            vr.textContent = K.fmt(TOTAL * K.ease.out(a), 2) + ' s';
            vl.textContent = K.fmt(LLM * K.ease.out(b), 2) + ' s';
          },
        },
        { dur: 0, draw() {} },
      ];
    },
  });

  /* 7. resultados da v1 */
  const NUMS = [
    { v: 94, lbl: 'testes no backend', sub: '98,39% de cobertura', d: 0 },
    { v: 105, lbl: 'testes no frontend', sub: '94,98% das linhas · 3 e2e', d: 0 },
    { v: 39, lbl: 'pull requests integrados', sub: 'em três repositórios', d: 0 },
    { v: 148, lbl: 'execuções da esteira', sub: 'todos os workflows do GitHub', d: 0 },
  ];
  S.push({
    id: 'resultados', act: 'Operação', name: 'Resultados da v1',
    title: 'De repositórios vazios a <em>dois ambientes em produção</em>, com evidências',
    html: `
      <div class="body">
        <div class="nums">${NUMS.map((n, i) => `
          <div class="n rv" data-at="0" style="--d:${i * 0.12}s"><div class="num"><span class="v">0</span></div><p class="lbl">${n.lbl}</p><p class="src">${n.sub}</p></div>`).join('')}
        </div>
        <div class="cost rv" data-at="1">
          <div class="cost-hd">custo mensal estimado, staging e produção (preços sob demanda, us-east-1)</div>
          <div class="cb"><span class="cb-l">ambientes separados</span><div class="cb-t"><i class="cb-a"></i></div><span class="cb-v mono">US$ 106</span></div>
          <div class="cb"><span class="cb-l">balanceador e banco compartilhados</span><div class="cb-t"><i class="cb-b"></i></div><span class="cb-v mono v-b">US$ 106</span></div>
        </div>
      </div>`,
    note: 'Dados de 19/11/2026, do GitHub e das execuções de CI. A v1 está em app.silversoft.com.br; staging em app-staging.silversoft.com.br.',
    setup(c) {
      const vs = c.$$('.n .v'), b = c.$('.cb-b'), vb = c.$('.v-b'), a = c.$('.cb-a');
      a.style.width = '100%';
      return [
        { dur: 1500, draw(p) { vs.forEach((el, i) => K.count(el, NUMS[i].v, K.seg(p, i * 0.08, 0.7 + i * 0.08))); } },
        {
          dur: 1800,
          draw(p) {
            const t = K.ease.io(K.seg(p, 0.25, 1));
            b.style.width = K.lerp(100, (66 / 106) * 100, t) + '%';
            vb.textContent = 'US$ ' + Math.round(K.lerp(106, 66, t));
          },
        },
      ];
    },
  });
})();
