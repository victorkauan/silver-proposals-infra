/* slides-d.js — próximos passos e encerramento (slide 10). */
(function () {
  'use strict';
  const K = window.K, S = window.SLIDES;

  const NEXT = [
    ['Verificação de e-mail', 'confirmação no cadastro e nova senha por e-mail'],
    ['Chat sobre a proposta', 'perguntas e ajustes em linguagem natural'],
    ['Slides gerados', 'a proposta vira apresentação para o cliente'],
    ['Convites com papéis', 'editores e leitores por proposta'],
    ['Cobrança em modo de teste', 'pagamento em ambiente de teste'],
    ['Testes de carga', 'limites e custo sob uso real'],
  ];
  S.push({
    id: 'fim', act: 'Próximos passos', name: 'Próximos passos e encerramento',
    title: 'Próximos passos, sobre a mesma base: <em>código, esteira e observabilidade</em>',
    html: `
      <div class="body">
        <ol class="next">${NEXT.map(([t, s], i) => `<li class="rv" data-at="0" style="--d:${i * 0.12}s"><b>${t}</b><span>${s}</span></li>`).join('')}</ol>
        <div class="thanks rv" data-at="1">
          <p class="serif">Obrigado.</p>
          <div class="links mono"><span>app.silversoft.com.br</span><span>github.com/victorkauan/silver-proposals-backend</span>
          <span>github.com/victorkauan/silver-proposals-frontend</span><span>github.com/victorkauan/silver-proposals-infra</span></div>
        </div>
      </div>`,
    setup() { return [{ dur: 0, draw() {} }, { dur: 0, draw() {} }]; },
  });
})();
