/**
 * Patch prisma/schema.prisma untuk deploy cross-platform (Windows PM2 + Docker Linux + Mac native).
 * Usage: node patch-prisma-schema.js [nextjs-dir]
 */
const fs = require("fs");
const path = require("path");

const nextjsDir = path.resolve(process.argv[2] || process.cwd());
const schemaPath = path.join(nextjsDir, "prisma", "schema.prisma");
if (!fs.existsSync(schemaPath)) {
  console.error("ERROR: prisma/schema.prisma tidak ada");
  process.exit(1);
}

let schema = fs.readFileSync(schemaPath, "utf8");

// Hapus BOM + perbaiki korupsi dari patch PowerShell lama (`r`n literal)
if (schema.charCodeAt(0) === 0xfeff) {
  schema = schema.slice(1);
}
schema = schema.replace(
  /provider = "prisma-client-js"`r`n\s*binaryTargets/g,
  'provider = "prisma-client-js"\n  binaryTargets',
);

const generatorBlock = `generator client {
  provider      = "prisma-client-js"
  binaryTargets = ["native", "windows", "debian-openssl-3.0.x"]
}`;

// Selalu timpa blok generator agar binaryTargets konsisten (bukan hanya saat belum ada).
schema = schema.replace(/generator client \{[^}]*\}/s, generatorBlock);

fs.writeFileSync(schemaPath, schema, "utf8");
console.log(
  "OK: prisma/schema.prisma siap (binaryTargets: native, windows, debian-openssl-3.0.x)",
);
