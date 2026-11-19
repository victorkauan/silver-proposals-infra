/* slides-b.js — arquitetura e esteira (slides 4 e 5). */
(function () {
  'use strict';
  const K = window.K, S = window.SLIDES;

  /* 4. arquitetura AWS, montada por camadas */
  S.push({
    id: 'arquitetura', act: 'Solução', name: 'Arquitetura na AWS',
    title: 'Na AWS, em us-east-1: tudo como código, e a IA chamada <em>sem nenhuma chave</em>',
    html: `
      <div class="body">
        <svg class="fig arch" width="1700" height="730" viewBox="0 0 1700 730"></svg>
        <div class="nokey rv" data-at="3">${K.icon('nokey')}<span><b>Sem chaves</b> · a tarefa usa um papel IAM que só pode invocar o modelo</span></div>
      </div>`,
    note: 'DNS no Cloudflare (silversoft.com.br) · certificados no ACM · 10 módulos Terraform · cerca de US$ 66/mês para staging e produção.',
    setup(c) {
      const svg = c.$('.arch'), D = K.diagram(svg);
      const vpc = D.group(560, 300, 640, 440, 'VPC · sem NAT Gateway', 'bl');
      const ecs = D.group(590, 350, 580, 190, 'ECS Fargate · staging e prod', 'br');
      D.node('user', 0, 268, 210, 104, 'Usuário', 'navegador');
      D.node('cf', 280, 60, 230, 104, 'CloudFront', 'app · TLS', 'c-app');
      D.node('s3', 620, 60, 230, 104, 'S3 privado', 'build do frontend', 'c-data');
      D.node('alb', 280, 410, 230, 104, 'Load Balancer', 'api · HTTPS', 'c-app');
      D.node('api', 620, 395, 250, 104, 'API FastAPI', 'contêiner', 'c-app');
      D.node('otel', 895, 395, 250, 104, 'Coletor OTel', 'sidecar', 'c-sec');
      D.node('rds', 680, 585, 400, 104, 'PostgreSQL 17 (RDS)', 'privado · TLS · criptografado', 'c-data');
      D.node('bedrock', 1300, 220, 380, 120, 'Amazon Bedrock', 'Nova 2 Lite · papel IAM', 'c-cloud');
      D.node('obs', 1300, 470, 380, 104, 'CloudWatch + X-Ray', 'logs · traces · 21 alarmes', 'c-sec');
      D.edge('u-cf', [[210, 300], [245, 300], [245, 112], [280, 112]]);
      D.edge('cf-s3', [[510, 112], [620, 112]], { label: 'OAC', lx: 565, ly: 98 });
      D.edge('u-alb', [[210, 340], [245, 340], [245, 462], [280, 462]]);
      D.edge('alb-api', [[510, 447], [620, 447]]);
      D.edge('api-rds', [[745, 499], [745, 585]], { label: 'SQL', lx: 778, ly: 548 });
      D.edge('api-br', [[745, 395], [745, 280], [1300, 280]], { label: 'InvokeModel (streaming)', lx: 1020, ly: 266 });
      D.edge('br-api', [[1300, 320], [790, 320], [790, 395]]);
      D.edge('otel-obs', [[1145, 447], [1222, 447], [1222, 522], [1300, 522]]);
      const tok = D.token('c-cloud');
      const show = (ids, p) => ids.forEach((id) => (D.n[id] ? D.n[id].show(p) : D.e[id].show(p)));
      return [
        { dur: 1400, draw(p) { show(['user'], K.seg(p, 0, 0.3)); show(['u-cf', 'cf'], K.seg(p, 0.2, 0.65)); show(['cf-s3', 's3'], K.seg(p, 0.5, 1)); } },
        { dur: 1400, draw(p) { vpc.show(K.seg(p, 0, 0.3)); ecs.show(K.seg(p, 0.1, 0.4)); show(['u-alb', 'alb'], K.seg(p, 0.2, 0.6)); show(['alb-api', 'api'], K.seg(p, 0.5, 1)); } },
        { dur: 900, draw(p) { show(['api-rds', 'rds'], p); } },
        { dur: 1100, draw(p) { show(['api-br', 'bedrock'], p); } },
        { dur: 1100, draw(p) { show(['otel', 'otel-obs', 'obs', 'br-api'], p); } },
        { dur: 2600, draw(p) { K.travel(tok, [D.e['u-alb'], D.e['alb-api'], D.e['api-br'], D.e['br-api']], p); } },
      ];
    },
  });

  /* 5. esteira: uma mudança atravessando os portões */
  const CI = [
    ['lint', 'lint e tipos'], ['test', 'testes'], ['sast', 'SAST'], ['sca', 'SCA'],
    ['gitleaks', 'segredos'], ['trivy', 'Trivy'], ['checkov', 'Checkov'], ['plan', 'plan'],
  ];
  const CD = [['merge', 'merge'], ['stg', 'staging'], ['ready', '/ready'], ['approve', 'aprovação'], ['prod', 'produção']];
  S.push({
    id: 'esteira', act: 'Solução', name: 'Esteira DevSecOps',
    title: 'Toda mudança atravessa <em>oito portões</em> antes do merge, e a produção exige aprovação',
    html: `
      <div class="body">
        <div class="lane-l l1">pull request · três repositórios</div>
        <div class="lane-l l2">entrega contínua</div>
        <svg class="fig pipe" width="1700" height="620" viewBox="0 0 1700 620"></svg>
        <div class="block rv" data-at="1">${K.icon('cross', 'ko')}<span><b>Na prática:</b> a esteira já barrou uma configuração insegura antes do merge; a mudança só seguiu depois de corrigida.</span></div>
      </div>`,
    note: 'Semgrep e Bandit (SAST) · pip-audit e npm audit (SCA) · gitleaks · Trivy na imagem e no Terraform · Checkov · plan comentado no PR · OIDC, sem chaves estáticas.',
    setup(c) {
      const svg = c.$('.pipe');
      const gates = {}, mk = (id, label, cx, cy) => {
        const g = K.s('g', { class: 'gate' }, svg);
        const ring = K.s('circle', { cx, cy, r: 34, class: 'gate-r' }, g);
        const mark = K.s('path', { d: `M${cx - 12},${cy + 1} l8,8 l16,-17`, class: 'gate-m' }, g);
        K.s('path', { d: `M${cx - 10},${cy - 10} l20,20 M${cx + 10},${cy - 10} l-20,20`, class: 'gate-x' }, g);
        K.s('text', { x: cx, y: cy + 66, class: 'gate-l', text: label }, g);
        return (gates[id] = { g, ring, mark, cx, cy, set(state) { g.dataset.state = state; } });
      };
      const y1 = 120, y2 = 440, x0 = 150, dx = 200;
      const pr = K.s('g', { class: 'gate pr' }, svg);
      K.s('rect', { x: 0, y: y1 - 34, width: 92, height: 68, rx: 14, class: 'gate-r' }, pr);
      K.s('text', { x: 46, y: y1 + 7, class: 'gate-pr', text: 'PR' }, pr);
      CI.forEach(([id, l], i) => mk(id, l, x0 + i * dx, y1));
      const xs = [150, 450, 750, 1050, 1350];
      CD.forEach(([id, l], i) => mk(id, l, xs[i], y2));
      const line1 = K.s('path', { d: `M92,${y1} L${x0 + (CI.length - 1) * dx},${y1}`, class: 'rail-l' }, svg);
      const drop = K.s('path', { d: K.route([[x0 + (CI.length - 1) * dx, y1 + 84], [x0 + (CI.length - 1) * dx, 280], [150, 280], [150, y2 - 34]], 26), class: 'rail-l' }, svg);
      const line2 = K.s('path', { d: `M150,${y2} L1350,${y2}`, class: 'rail-l' }, svg);
      [line1, drop, line2].forEach((l) => svg.insertBefore(l, svg.firstChild));
      const tok = K.s('circle', { r: 12, class: 'tok c-app' }, svg);
      const at = (x, y) => { tok.setAttribute('cx', x); tok.setAttribute('cy', y); tok.style.opacity = 1; };
      const len2 = drop.getTotalLength();
      const xEnd = x0 + (CI.length - 1) * dx;
      const ci = (p) => {
        const x = K.lerp(46, xEnd + 40, K.ease.io(p));
        CI.forEach(([id], i) => gates[id].set(p > 0 && x >= x0 + i * dx ? 'ok' : 'idle'));
        if (p <= 0 || p >= 1) return void (tok.style.opacity = 0);
        at(Math.min(x, xEnd), y1);
      };
      const block = (p) => {
        gates.checkov.set(p <= 0 ? 'ok' : p < 0.55 ? 'bad' : 'ok');
        gates.checkov.g.classList.toggle('pulse', p > 0 && p < 0.55);
      };
      // Desce da linha do PR, percorre a entrega e espera na aprovação antes da produção.
      const cdX = (p) => (p < 0.55 ? K.lerp(150, xs[3], K.ease.io(K.seg(p, 0.2, 0.55))) : p < 0.75 ? xs[3] : K.lerp(xs[3], xs[4], K.ease.io(K.seg(p, 0.75, 1))));
      const cd = (p) => {
        const x = cdX(p);
        CD.forEach(([id], i) => {
          const reached = p >= 0.2 && x >= xs[i] - 1;
          gates[id].set(!reached || p <= 0 ? 'idle' : id === 'approve' && p < 0.75 ? 'wait' : 'ok');
        });
        if (p <= 0 || p >= 1) return void (tok.style.opacity = 0);
        if (p < 0.2) { const pt = drop.getPointAtLength(len2 * K.ease.io(p / 0.2)); at(pt.x, pt.y); }
        else at(x, y2);
      };
      return [
        { dur: 3200, draw(p) { ci(p); } },
        { dur: 1600, draw(p) { block(p); } },
        { dur: 3200, draw(p) { cd(p); } },
      ];
    },
  });
})();
