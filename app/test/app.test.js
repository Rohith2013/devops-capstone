const { test, before, after } = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const app = require('../server');

function get(port, path) {
  return new Promise((resolve, reject) => {
    http
      .get({ host: '127.0.0.1', port, path }, (res) => {
        let body = '';
        res.on('data', (chunk) => (body += chunk));
        res.on('end', () => resolve({ status: res.statusCode, body }));
      })
      .on('error', reject);
  });
}

let server;
let port;

before(
  () =>
    new Promise((resolve) => {
      server = app.listen(0, '127.0.0.1', () => {
        port = server.address().port;
        resolve();
      });
    })
);

after(() => new Promise((resolve) => server.close(resolve)));

test('GET /health returns status ok', async () => {
  const res = await get(port, '/health');
  assert.strictEqual(res.status, 200);
  assert.deepStrictEqual(JSON.parse(res.body), { status: 'ok' });
});

test('GET / returns the home page', async () => {
  const res = await get(port, '/');
  assert.strictEqual(res.status, 200);
  assert.match(res.body, /DevOps Capstone Project/);
});
