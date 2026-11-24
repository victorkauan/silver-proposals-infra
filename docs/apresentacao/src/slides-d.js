/* slides-d.js: uso de assistentes de IA, próximos passos e encerramento. */
(function () {
  'use strict';
  const K = window.K, S = window.SLIDES;

  const NEXT = [
    ['Verificação de e-mail', 'confirmação no cadastro e nova senha por e-mail · dez./2026'],
    ['Escalonamento automático', 'duas tarefas ou mais, limites compartilhados e cota maior · dez./2026'],
    ['Convites e cobrança', 'editores e leitores por proposta; assinatura em modo de teste · dez./2026'],
    ['Chat e slides', 'conversa sobre a proposta e apresentação gerada · dez./2026'],
    ['Validação com vendedores', 'tempo medido com e sem o produto; preço e cliente-alvo · jan./2027'],
    ['Privacidade e operação', 'região de São Paulo, passkeys e registro de incidentes · fev. e mar./2027'],
  ];
  const AI_DID = [
    ['Revisão', 'leitura de código, de configurações e do texto, apontando falhas e inconsistências'],
    ['Pesquisa', 'busca de referências e de dados de mercado, sempre conferidos na fonte'],
    ['Implementação', 'código, testes e documentação de cada issue, dentro dos critérios de aceite'],
  ];
  const AUTHOR = [
    ['Escopo e arquitetura', 'o que construir e como, registrado em ADRs'],
    ['Revisão antes do commit', 'cada mudança lida e aprovada pelo autor'],
    ['Aprovação da produção', 'nenhuma implantação sem aprovação explícita'],
  ];
  S.push({
    id: 'ia-uso', act: 'Método', name: 'Uso de assistentes de IA',
    title: 'Assistentes de IA como <em>apoio sob direção</em>, com as mesmas verificações',
    html: `
      <div class="body">
        <div class="cols2">
          <div class="col rv" data-at="0"><div class="cost-hd">Claude Code e Codex apoiaram</div>${AI_DID.map(([t, s]) => `<div class="sec-i">${K.icon('check')}<div><b>${t}</b><span>${s}</span></div></div>`).join('')}</div>
          <div class="col rv" data-at="1"><div class="cost-hd">ficou com o autor</div>${AUTHOR.map(([t, s]) => `<div class="sec-i">${K.icon('user')}<div><b>${t}</b><span>${s}</span></div></div>`).join('')}</div>
        </div>
        <div class="finding rv" data-at="2">${K.icon('lock')}<span><b>A esteira não distingue a origem do código:</b> tudo passa por pull request, testes, sete varreduras de segurança, staging e aprovação para produção.</span></div>
      </div>`,
    note: 'Seções 1.4 e 3.9 do relatório.',
    setup() { return [{ dur: 0, draw() {} }, { dur: 0, draw() {} }, { dur: 0, draw() {} }]; },
  });

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
