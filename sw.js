// Service Worker — Phenix Rapports
// =====================================
// Stratégies de cache :
//
//  1. App shell (HTML/CSS/JS locaux)        → cache-first  → ouvre instantanément hors-ligne
//  2. Librairies CDN (jsDelivr, cdnjs)      → cache-first  → pas de re-download à chaque fois
//  3. Icônes / images locales               → cache-first
//  4. Supabase REST GET (lecture de données)→ stale-while-revalidate → consultation hors-ligne
//  5. Supabase Auth & mutations (POST/PATCH/DELETE) → NETWORK only (jamais cache)
//  6. Supabase Storage (photos)             → cache-first  → photos visibles hors-ligne
//
// IMPORTANT — sécurité :
//  - À la déconnexion, l'app envoie un message CLEAR_SUPABASE_CACHE qui vide tout
//    le cache Supabase pour éviter qu'un autre utilisateur voie les données du précédent.
//  - Le cache d'auth (/auth/) n'est JAMAIS conservé.
//
// Pour forcer un recache complet → incrémenter CACHE_VERSION ci-dessous.

const CACHE_VERSION = "phenix-v2";
const APP_SHELL_CACHE = `app-shell-${CACHE_VERSION}`;
const CDN_CACHE = `cdn-${CACHE_VERSION}`;
const IMG_CACHE = `images-${CACHE_VERSION}`;
const SUPABASE_DATA_CACHE = `supabase-data-${CACHE_VERSION}`;  // données REST (GET uniquement)
const SUPABASE_STORAGE_CACHE = `supabase-storage-${CACHE_VERSION}`; // photos

// Fichiers locaux à pré-charger dès l'installation
const APP_SHELL = [
  "./",
  "./index.html",
  "./styles.css",
  "./manifest.webmanifest",
  "./icon-192.png",
  "./icon-512.png",
  "./icon-maskable-512.png",
  "./apple-touch-icon.png",
  "./favicon-32.png",
];

// Domaines CDN à mettre en cache
const CDN_HOSTS = [
  "cdn.jsdelivr.net",
  "cdnjs.cloudflare.com",
];

// Domaine Supabase
const SUPABASE_HOST_PART = "supabase.co";

// ===== INSTALL =====
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(APP_SHELL_CACHE).then((cache) => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

// ===== ACTIVATE — nettoyage des vieilles versions de cache =====
self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(
        keys
          .filter((k) => !k.endsWith(CACHE_VERSION))
          .map((k) => caches.delete(k))
      );
      await self.clients.claim();
    })()
  );
});

// ===== FETCH — routage selon le type de requête =====
self.addEventListener("fetch", (event) => {
  const req = event.request;
  const url = new URL(req.url);

  // === Supabase ===
  if (url.hostname.includes(SUPABASE_HOST_PART)) {
    // Auth → JAMAIS de cache (sécurité)
    if (url.pathname.startsWith("/auth/")) {
      return; // réseau direct, pas d'interception
    }

    // Storage (photos) → cache-first
    // URL typique : /storage/v1/object/public/rapports%20Photos/...
    if (url.pathname.startsWith("/storage/")) {
      if (req.method === "GET") {
        event.respondWith(cacheFirst(req, SUPABASE_STORAGE_CACHE));
      }
      return;
    }

    // REST GET → stale-while-revalidate (lecture hors-ligne possible)
    // URL typique : /rest/v1/chantiers?...
    if (url.pathname.startsWith("/rest/") && req.method === "GET") {
      event.respondWith(staleWhileRevalidate(req, SUPABASE_DATA_CACHE));
      return;
    }

    // REST mutations (POST/PATCH/DELETE) ou autres → réseau direct, jamais cache
    return;
  }

  // === Hors Supabase ===
  if (req.method !== "GET") return; // sécurité : on ne cache que des GET

  // CDN libs : cache-first
  if (CDN_HOSTS.includes(url.hostname)) {
    event.respondWith(cacheFirst(req, CDN_CACHE));
    return;
  }

  // Same-origin (app shell + images locales)
  if (url.origin === self.location.origin) {
    if (req.destination === "image") {
      event.respondWith(cacheFirst(req, IMG_CACHE));
      return;
    }
    event.respondWith(cacheFirst(req, APP_SHELL_CACHE));
    return;
  }
});

// ===== STRATÉGIES =====

// Cache-first : si en cache → retourne (et rafraîchit en bg). Sinon → réseau + cache.
async function cacheFirst(request, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request);
  if (cached) {
    // Rafraîchit en arrière-plan (stale-while-revalidate light)
    fetch(request).then((res) => {
      if (res && res.ok) cache.put(request, res.clone());
    }).catch(() => {});
    return cached;
  }
  try {
    const response = await fetch(request);
    if (response && response.ok) cache.put(request, response.clone());
    return response;
  } catch (err) {
    return new Response("", { status: 504, statusText: "Hors-ligne" });
  }
}

// Stale-while-revalidate : retourne le cache immédiatement (rapide), rafraîchit en bg.
// Si rien en cache, attend le réseau ; si pas de réseau, renvoie une 504.
// Adapté aux données Supabase : l'utilisateur voit ses dernières données, qui se mettent
// à jour silencieusement quand le réseau est dispo.
async function staleWhileRevalidate(request, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request);

  // Promesse réseau (lancée systématiquement)
  const networkPromise = fetch(request).then((res) => {
    if (res && res.ok) {
      // Cloner avant de stocker (un body ne peut être lu qu'une fois)
      cache.put(request, res.clone()).catch(() => {});
    }
    return res;
  }).catch(() => null);

  // Si on a un cache : on le retourne tout de suite (UX rapide)
  if (cached) return cached;

  // Sinon on attend le réseau ; s'il échoue → 504
  const network = await networkPromise;
  if (network) return network;
  return new Response(JSON.stringify({ error: "Offline - no cached data" }), {
    status: 504,
    statusText: "Hors-ligne",
    headers: { "Content-Type": "application/json" },
  });
}

// ===== MESSAGES depuis l'app =====
self.addEventListener("message", (event) => {
  if (!event.data) return;

  // 1) Forcer skipWaiting (mise à jour immédiate après nouveau SW)
  if (event.data.type === "SKIP_WAITING") {
    self.skipWaiting();
    return;
  }

  // 2) Vider le cache Supabase (à la déconnexion d'un utilisateur)
  //    Sécurité : empêche un autre utilisateur de voir les données du précédent
  if (event.data.type === "CLEAR_SUPABASE_CACHE") {
    event.waitUntil(
      Promise.all([
        caches.delete(SUPABASE_DATA_CACHE),
        caches.delete(SUPABASE_STORAGE_CACHE),
      ])
    );
    return;
  }
});
