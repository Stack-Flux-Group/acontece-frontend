// Proxy de desenvolvimento do site Acontece.
//
// POR QUE ISTO EXISTE
// -------------------
// A API (acontece-api) nao envia nenhum header `Access-Control-Allow-*`. Isso
// foi verificado contra o deploy: um `OPTIONS /participantes` responde 200 com
// `allow: GET, HEAD, POST, PUT, DELETE, OPTIONS, PATCH`, mas sem um unico header
// de CORS. Entao um site chamando `https://acontece-api.onrender.com` direto do
// navegador tem TODAS as requisicoes bloqueadas.
//
// A saida, sem alterar o back-end, e nunca cruzar origem: o site pede `/api/...`
// (caminho relativo, mesma origem) e quem repassa para a API e este proxy. Como
// a requisicao do navegador nao e cross-origin, o CORS nem entra em cena.
//
// Em producao o papel deste arquivo e feito por uma regra de rewrite
// configurada no host do site, com exatamente o mesmo contrato `/api`.
//
// COMO USAR (dois terminais)
// --------------------------
//   1) node tools/dev_proxy.mjs
//   2) flutter run -d web-server --web-hostname=127.0.0.1 --web-port=5000
//
// e abrir http://localhost:8081 no navegador.
//
// PRE-VISUALIZAR O BUILD DE PRODUCAO
// ----------------------------------
//   flutter build web --release
//   node tools/dev_proxy.mjs --static
//
// Nesse modo o proxy serve build/web direto, sem o servidor do Flutter: e o
// mais proximo possivel do site publicado (mesma origem, mesmo rewrite de /api).
//
// Sem dependencias: apenas modulos nativos do Node (testado no Node 18).

import fs from 'node:fs';
import http from 'node:http';
import https from 'node:https';
import net from 'node:net';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const PORT = Number(process.env.PORT ?? 8081);
const API_PREFIX = '/api';

// A API de destino. Trocar para http://127.0.0.1:8080 aponta para um back-end
// local (que, ao contrario do deploy, tem o modulo de inscricoes).
const API_TARGET = new URL(process.env.API_TARGET ?? 'https://acontece-api.onrender.com');

// Servidor de desenvolvimento do Flutter.
const DEV_HOST = process.env.DEV_HOST ?? '127.0.0.1';
const DEV_PORT = Number(process.env.DEV_PORT ?? 5000);

// Modo estatico: serve build/web em vez de falar com o servidor do Flutter.
const STATIC = process.argv.includes('--static');
const STATIC_DIR = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  'build',
  'web',
);

// A instancia gratuita do Render hiberna; o cold start medido foi de ~146 s.
const API_TIMEOUT_MS = 185_000;

const server = http.createServer((req, res) => {
  if (req.url === API_PREFIX || req.url.startsWith(`${API_PREFIX}/`)) {
    proxyToApi(req, res);
  } else if (STATIC) {
    serveStatic(req, res);
  } else {
    proxyToFlutter(req, res);
  }
});

const TIPOS = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff2': 'font/woff2',
  '.map': 'application/json; charset=utf-8',
};

/** Serve o build de producao, com index.html como fallback de rota. */
function serveStatic(req, res) {
  const relativo = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  let arquivo = path.join(STATIC_DIR, relativo);

  // Impede sair do diretorio publicado via "../".
  if (!arquivo.startsWith(STATIC_DIR)) {
    res.writeHead(403).end('Forbidden');
    return;
  }

  if (!fs.existsSync(arquivo) || fs.statSync(arquivo).isDirectory()) {
    arquivo = path.join(STATIC_DIR, 'index.html');
  }
  if (!fs.existsSync(arquivo)) {
    res
      .writeHead(404, { 'content-type': 'text/plain; charset=utf-8' })
      .end('build/web nao encontrado. Rode: flutter build web --release');
    return;
  }

  res.writeHead(200, {
    'content-type': TIPOS[path.extname(arquivo)] ?? 'application/octet-stream',
  });
  fs.createReadStream(arquivo).pipe(res);
}

/** `/api/evento/listar/` -> `<API_TARGET>/evento/listar/` */
function proxyToApi(req, res) {
  const caminho = req.url.slice(API_PREFIX.length) || '/';
  const alvo = new URL(caminho, API_TARGET);

  // O `host` precisa ser o do destino, senao o Render nao roteia o pedido.
  // `origin`/`referer` apontariam para localhost e nao servem para nada aqui.
  const headers = { ...req.headers, host: alvo.host };
  delete headers.origin;
  delete headers.referer;
  delete headers['accept-encoding']; // sem compressao, o corpo passa direto

  const transporte = alvo.protocol === 'https:' ? https : http;
  const inicio = Date.now();

  const upstream = transporte.request(
    {
      protocol: alvo.protocol,
      hostname: alvo.hostname,
      port: alvo.port || (alvo.protocol === 'https:' ? 443 : 80),
      method: req.method,
      path: alvo.pathname + alvo.search,
      headers,
      servername: alvo.hostname, // SNI correto no TLS
    },
    (upstreamRes) => {
      const ms = Date.now() - inicio;
      console.log(`${req.method} ${req.url} -> ${upstreamRes.statusCode} (${ms} ms)`);
      res.writeHead(upstreamRes.statusCode ?? 502, upstreamRes.headers);
      upstreamRes.pipe(res);
    },
  );

  upstream.setTimeout(API_TIMEOUT_MS, () => {
    upstream.destroy(new Error(`timeout apos ${API_TIMEOUT_MS} ms`));
  });

  upstream.on('error', (erro) => {
    console.error(`${req.method} ${req.url} -> falha: ${erro.message}`);
    responderJson(res, 504, {
      status: 504,
      error: 'Gateway Timeout',
      // Mesmo envelope do GlobalExceptionHandler, para o app saber ler.
      message: `O proxy nao conseguiu falar com a API (${erro.message}).`,
      path: req.url,
      fieldErrors: [],
    });
  });

  req.pipe(upstream);
}

/** Tudo que nao e `/api` vem do servidor de desenvolvimento do Flutter. */
function proxyToFlutter(req, res) {
  const upstream = http.request(
    {
      host: DEV_HOST,
      port: DEV_PORT,
      method: req.method,
      path: req.url,
      headers: req.headers,
    },
    (upstreamRes) => {
      res.writeHead(upstreamRes.statusCode ?? 502, upstreamRes.headers);
      upstreamRes.pipe(res);
    },
  );

  upstream.on('error', () => {
    responderJson(res, 502, {
      status: 502,
      error: 'Bad Gateway',
      message:
        `O servidor de desenvolvimento do Flutter nao esta respondendo em ` +
        `${DEV_HOST}:${DEV_PORT}. Rode: flutter run -d web-server ` +
        `--web-hostname=${DEV_HOST} --web-port=${DEV_PORT}`,
      path: req.url,
      fieldErrors: [],
    });
  });

  req.pipe(upstream);
}

// O hot reload do Flutter usa websocket. Sem repassar o `upgrade`, o site
// carrega mas para de recarregar sozinho a cada alteracao.
server.on('upgrade', (req, socket, head) => {
  const upstream = net.connect(DEV_PORT, DEV_HOST, () => {
    upstream.write(
      `${req.method} ${req.url} HTTP/1.1\r\n` +
        Object.entries(req.headers)
          .map(([chave, valor]) => `${chave}: ${valor}\r\n`)
          .join('') +
        '\r\n',
    );
    if (head?.length) upstream.write(head);
    upstream.pipe(socket);
    socket.pipe(upstream);
  });
  upstream.on('error', () => socket.destroy());
  socket.on('error', () => upstream.destroy());
});

function responderJson(res, status, corpo) {
  if (res.headersSent) return res.end();
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(corpo));
}

server.listen(PORT, () => {
  console.log('');
  console.log(
    STATIC
      ? '  Acontece — pre-visualizacao do build de producao'
      : '  Acontece — proxy de desenvolvimento',
  );
  console.log(`  site .......... http://localhost:${PORT}`);
  console.log(`  ${API_PREFIX}/* ........ ${API_TARGET.origin}`);
  console.log(
    STATIC
      ? `  restante ...... ${STATIC_DIR} (estatico)`
      : `  restante ...... http://${DEV_HOST}:${DEV_PORT} (flutter run -d web-server)`,
  );
  console.log('');
  console.log('  A primeira chamada a API pode levar ~2 min (a instancia gratuita hiberna).');
  console.log('');
});
