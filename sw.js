// Service Worker — Phenix Rapports
// Stratégie :
//  - App shell (HTML/CSS/JS locaux) : cache-first → l'app s'ouvre instantanément même hors-ligne
//  - Librairies CDN (Tailwind, Alpine, Supabase, jsPDF, etc.) : cache-first avec fallback réseau
//  - Icônes / images : cache-first
//  - Appels Supabase (REST/Auth/Storage) : network-first (données toujours fraîches), pas de cache
//
// Pour mettre à jour les fichiers en cache → incrémenter CACHE_VERSION ci-dessous.

const CACHE_VERSION = "phenix-v1";
const APP_SHELL_CACHE = `app-shell-${CACHE_VERSION}`;
const CDN_CACHE = `cdn-${CACHE_VERSION}`;
const IMG_CACHE = `images-${CACHE_VERSION}`;

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

// Domaines Supabase (à NE PAS mettre en cache : toujours réseau)
const SUPABASE_HOST_PART = "supabase.co";

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(APP_SHELL_CACHE).then((cache) => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

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

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;

  const url = new URL(req.url);

  // Supabase API/Auth/Storage : toujours réseau, jamais cache
  if (url.hostname.includes(SUPABASE_HOST_PART)) {
    return;
  }

  // CDN libs : cache-first puis réseau
  if (CDN_HOSTS.includes(url.hostname)) {
    event.respondWith(cacheFirst(req, CDN_CACHE));
    return;
  }

  // App shell (même origine) : cache-first puis réseau
  if (url.origin === self.location.origin) {
    // Images locales (logo, icônes)
    if (req.destination === "image") {
      event.respondWith(cacheFirst(req, IMG_CACHE));
      return;
    }
    event.respondWith(cacheFirst(req, APP_SHELL_CACHE));
    return;
  }

  // Autres requêtes externes : réseau direct
});

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
    // Hors-ligne et pas en cache : on retourne une réponse vide propre
    return new Response("", { status: 504, statusText: "Hors-ligne" });
  }
}

// Permet à la page d'envoyer un message pour forcer skipWaiting (mise à jour immédiate)
self.addEventListener("message", (event) => {
  if (event.data && event.data.type === "SKIP_WAITING") {
    self.skipWaiting();
  }
});
