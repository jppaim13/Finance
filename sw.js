const CACHE_NAME = 'financas-v7';

const SHELL = [
  './icon.svg',
  'https://fonts.googleapis.com/css2?family=DM+Sans:ital,wght@0,300;0,400;0,500;0,600;1,400&family=DM+Mono:wght@400;500&display=swap',
  'https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js',
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(SHELL)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const url = event.request.url;

  // Supabase: sempre rede
  if (url.includes('supabase.co') || url.includes('supabase-js')) return;

  // App shell essencial (index.html + date-utils.js): network-first — garante
  // que o app sempre carrega a versão mais recente de ambos juntos. Sem isso,
  // um date-utils.js em cache podia ficar "para trás" do index.html mais novo
  // sem erro nenhum, só com sintoma de saldo/data errados.
  // Ignora a query string: date-utils.js é pedido como date-utils.js?v=<APP_VERSION>
  // (cache-busting contra index.html novo + date-utils.js antigo — 15/10/2026).
  const caminho = url.split('?')[0];
  const isAppShell = event.request.mode === 'navigate' || caminho.endsWith('index.html') || caminho.endsWith('date-utils.js');
  // cache: 'no-cache' = sempre revalida no servidor (barato: 304 quando nada mudou). Sem isso, o
  // Cache-Control: max-age=600 do GitHub Pages deixava o navegador servir o index.html antigo por
  // até 10 min depois de cada publicação, mesmo com este network-first (achado 24/10/2026).
  if (isAppShell) {
    event.respondWith(
      fetch(event.request, { cache: 'no-cache' })
        .then(response => {
          const clone = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
          return response;
        })
        .catch(() => caches.match(event.request).then(cached => cached || caches.match('./index.html')))
    );
    return;
  }

  // Demais assets: cache-first
  event.respondWith(
    caches.match(event.request).then(cached => {
      if (cached) return cached;
      return fetch(event.request).then(response => {
        if (response && response.status === 200 && response.type !== 'opaque') {
          const clone = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
        }
        return response;
      }).catch(() => null);
    })
  );
});
