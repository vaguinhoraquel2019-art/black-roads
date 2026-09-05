const https = require('https');

const GH_USER = process.argv[2];
const GH_TOKEN = process.argv[3];
const REPO_NOME = process.argv[4];
const ACAO = process.argv[5]; // 'criar-repo' ou 'ativar-pages'

function request(options, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, res => {
      let data = '';
      res.on('data', d => data += d);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
        catch(e) { resolve({ status: res.statusCode, body: {} }); }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

const headers = {
  'Authorization': 'token ' + GH_TOKEN,
  'User-Agent': 'black-roads-deploy',
  'Accept': 'application/vnd.github+json',
  'Content-Type': 'application/json'
};

async function criarRepo() {
  const body = JSON.stringify({ name: REPO_NOME, private: false, auto_init: false });
  const res = await request({
    hostname: 'api.github.com',
    path: '/user/repos',
    method: 'POST',
    headers: { ...headers, 'Content-Length': Buffer.byteLength(body) }
  }, body);

  if (res.status === 201) {
    // Retorna o login exato como o GitHub registrou (pode diferir em maiusculas)
    console.log('OK:criado:' + res.body.owner.login + ':' + res.body.name);
  } else if (res.status === 422) {
    // Repositorio ja existe — busca o login real via /user
    const me = await request({ hostname: 'api.github.com', path: '/user', method: 'GET', headers });
    const login = (me.body && me.body.login) ? me.body.login : GH_USER;
    console.log('OK:existe:' + login + ':' + REPO_NOME);
  } else if (res.status === 401) {
    console.log('ERRO:Token invalido ou sem permissao. Gere um novo token com permissao "repo".');
  } else {
    console.log('ERRO:' + (res.body.message || 'status ' + res.status));
  }
}

async function ativarPages() {
  const body = JSON.stringify({ build_type: 'workflow', source: { branch: 'main', path: '/' } });
  const res = await request({
    hostname: 'api.github.com',
    path: '/repos/' + GH_USER + '/' + REPO_NOME + '/pages',
    method: 'POST',
    headers: { ...headers, 'Content-Length': Buffer.byteLength(body) }
  }, body);

  if (res.status === 201 || res.status === 409) {
    console.log('OK');
  } else {
    console.log('AVISO:' + (res.body.message || 'status ' + res.status));
  }
}

if (ACAO === 'criar-repo') criarRepo().catch(e => console.log('ERRO:' + e.message));
else if (ACAO === 'ativar-pages') ativarPages().catch(e => console.log('ERRO:' + e.message));
else console.log('ERRO:acao desconhecida');
