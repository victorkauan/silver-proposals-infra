import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';
import exec from 'k6/execution';

// Each runner (one source IP) keeps VUS generations in flight. The API allows 10 generations per minute per IP,
// so each VU starts at most one generation per PACE_SECONDS; more load means more runners, not more VUs.
const BASE_URL = __ENV.BASE_URL || 'https://api-staging.silversoft.com.br';
const VUS = Number(__ENV.VUS || 10);
const DURATION = __ENV.DURATION || '3m';
const PACE_SECONDS = Number(__ENV.PACE_SECONDS || 60);
const RUNNER = __ENV.RUNNER || 'local';
const HOST_IP = __ENV.HOST_IP || '';

const host = BASE_URL.replace(/^https?:\/\//, '').replace(/\/.*$/, '');

export const options = {
  hosts: HOST_IP ? { [host]: HOST_IP } : {},
  scenarios: {
    generations: {
      executor: 'constant-vus',
      vus: VUS,
      duration: DURATION,
      startTime: __ENV.START_DELAY || '0s',
      gracefulStop: '120s',
    },
  },
  setupTimeout: '300s',
  teardownTimeout: '120s',
  thresholds: {
    generation_success: ['rate>0.99'],
    generation_first_byte: ['p(95)<5000'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

const success = new Rate('generation_success');
const firstByte = new Trend('generation_first_byte', true);
const total = new Trend('generation_duration', true);
const failures = new Counter('generation_failures');

const json = { 'Content-Type': 'application/json' };

function auth(token) {
  return { headers: { ...json, Authorization: `Bearer ${token}` } };
}

const BRIEFING =
  'Empresa de contabilidade com 12 funcionários em Fortaleza quer um site institucional novo, responsivo, ' +
  'com páginas de serviços, equipe, blog e formulário de contato integrado ao WhatsApp. Precisa de SEO básico ' +
  'e treinamento para a equipe publicar no blog. Orçamento estimado: R$ 18.000. Prazo desejado: 6 semanas.';

export function setup() {
  const email = `load-${RUNNER}-${Date.now()}@example.com`;
  const password = `Load-${Math.random().toString(36).slice(2)}-Aa1!`;
  const register = http.post(
    `${BASE_URL}/auth/register`,
    JSON.stringify({ email, name: 'Load Test', password, accept_privacy: true }),
    { headers: json },
  );
  if (register.status !== 201 && register.status !== 200) {
    exec.test.abort(`register failed: ${register.status} ${register.body}`);
  }
  const token = register.json('access_token');
  const proposals = [];
  for (let i = 0; i < VUS; i++) {
    const created = http.post(
      `${BASE_URL}/proposals`,
      JSON.stringify({ title: `Carga ${RUNNER}-${i + 1}`, client_name: 'Contábil Nordeste', briefing: BRIEFING }),
      auth(token),
    );
    if (created.status !== 201) {
      exec.test.abort(`proposal failed: ${created.status} ${created.body}`);
    }
    proposals.push(created.json('id'));
  }
  return { token, password, proposals };
}

export default function (data) {
  const started = Date.now();
  const proposal = data.proposals[(exec.vu.idInTest - 1) % data.proposals.length];
  const res = http.post(`${BASE_URL}/proposals/${proposal}/generate`, null, {
    ...auth(data.token),
    timeout: '180s',
    tags: { name: 'generate' },
  });
  const done = res.status === 200 && typeof res.body === 'string' && res.body.includes('event: done');
  success.add(done);
  if (done) {
    firstByte.add(res.timings.waiting);
    total.add(res.timings.duration);
  } else {
    const code = res.status === 200 ? (res.body.match(/"code":\s*"([a-z_]+)"/) || [])[1] || 'stream_error' : String(res.status);
    failures.add(1, { code });
  }
  check(res, { 'generation completed': () => done });
  const elapsed = (Date.now() - started) / 1000;
  sleep(Math.max(0, PACE_SECONDS - elapsed));
}

export function teardown(data) {
  const res = http.post(`${BASE_URL}/account/delete`, JSON.stringify({ password: data.password }), auth(data.token));
  check(res, { 'test account deleted': (r) => r.status === 204 });
}
