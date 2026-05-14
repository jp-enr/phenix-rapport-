// Génère les icônes PWA à partir du logo Phenix.
// Lancer : node generate-icons.js
//
// NB : sharp n'est plus en devDependencies (échouait au build Netlify).
// Pour ré-exécuter ce script localement, installer sharp à la volée :
//   npm install sharp
//   node generate-icons.js
const sharp = require("sharp");
const fs = require("fs");

const LOGO = "logo-original.png";
const BG = "#0D4484"; // bleu Phenix

async function makeIcon(size, padding, output) {
  const inner = Math.round(size - 2 * padding);
  const resized = await sharp(LOGO)
    .resize({ width: inner, height: inner, fit: "contain", background: { r: 13, g: 68, b: 132, alpha: 1 } })
    .png()
    .toBuffer();
  await sharp({
    create: {
      width: size,
      height: size,
      channels: 4,
      background: BG,
    },
  })
    .composite([{ input: resized, gravity: "center" }])
    .png()
    .toFile(output);
  console.log(`✓ ${output} (${size}x${size})`);
}

async function makeMaskable(size, output) {
  // Maskable : zone safe = 80% au centre. Plus de padding.
  const inner = Math.round(size * 0.6);
  const resized = await sharp(LOGO)
    .resize({ width: inner, height: inner, fit: "contain", background: { r: 13, g: 68, b: 132, alpha: 1 } })
    .png()
    .toBuffer();
  await sharp({
    create: { width: size, height: size, channels: 4, background: BG },
  })
    .composite([{ input: resized, gravity: "center" }])
    .png()
    .toFile(output);
  console.log(`✓ ${output} (${size}x${size}, maskable)`);
}

(async () => {
  await makeIcon(192, 24, "icon-192.png");
  await makeIcon(512, 64, "icon-512.png");
  await makeMaskable(512, "icon-maskable-512.png");
  // Apple touch icon (iOS) — sans transparence, sans coins arrondis (iOS s'en charge)
  await makeIcon(180, 22, "apple-touch-icon.png");
  // Favicon
  await makeIcon(32, 4, "favicon-32.png");
})();
