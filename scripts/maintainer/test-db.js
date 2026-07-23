/**
 * Tes koneksi MySQL via Prisma + cek tabel dasar.
 * Usage: node test-db.js [nextjs-dir]
 */
const fs = require("fs");
const path = require("path");

function loadEnv(envPath) {
  if (!fs.existsSync(envPath)) {
    throw new Error(`.env tidak ada: ${envPath}`);
  }
  const env = {};
  for (const line of fs.readFileSync(envPath, "utf8").split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const idx = trimmed.indexOf("=");
    if (idx < 1) continue;
    const key = trimmed.slice(0, idx).trim();
    let value = trimmed.slice(idx + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    env[key] = value;
  }
  return env;
}

function maskDatabaseUrl(url) {
  return String(url || "").replace(/:([^:@/]+)@/, ":****@");
}

const nextjsDir = path.resolve(process.argv[2] || process.cwd());
const envPath = path.join(nextjsDir, ".env");
const env = loadEnv(envPath);

if (!env.DATABASE_URL) {
  console.error("FAIL: DATABASE_URL kosong di .env");
  process.exit(1);
}

process.chdir(nextjsDir);
process.env.DATABASE_URL = env.DATABASE_URL;

const prismaClientDir = path.join(nextjsDir, "node_modules", "@prisma", "client");
if (!fs.existsSync(path.join(prismaClientDir, "package.json"))) {
  console.error(`FAIL: @prisma/client tidak ada di ${prismaClientDir}`);
  console.error("HINT: Jalankan scripts\\prisma-generate.bat dulu");
  process.exit(1);
}

const { PrismaClient } = require(prismaClientDir);
const prisma = new PrismaClient();

(async () => {
  console.log("DATABASE_URL:", maskDatabaseUrl(env.DATABASE_URL));

  await prisma.$queryRaw`SELECT 1 AS ok`;
  console.log("OK: MySQL terhubung");

  const tables = await prisma.$queryRaw`
    SELECT TABLE_NAME
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
    ORDER BY TABLE_NAME
    LIMIT 20
  `;
  const names = tables.map((t) => t.TABLE_NAME || t.table_name).filter(Boolean);
  console.log(`OK: ${names.length} tabel terdeteksi (sample): ${names.slice(0, 8).join(", ")}`);

  const allTables = await prisma.$queryRaw`
    SELECT TABLE_NAME
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
  `;
  const allNames = allTables.map((t) => t.TABLE_NAME || t.table_name).filter(Boolean);

  if (!allNames.some((n) => /^users$/i.test(n))) {
    console.warn("WARN: Tabel users tidak ditemukan — dump production belum di-import?");
  } else {
    const userCount = await prisma.$queryRaw`SELECT COUNT(*) AS c FROM users`;
    const count = Number(userCount[0]?.c ?? userCount[0]?.C ?? 0);
    console.log(`OK: tabel users ada (${count} baris)`);

    const demoStudent = await prisma.$queryRaw`
      SELECT id, uniqueCode FROM users WHERE uniqueCode = '123456' LIMIT 1
    `;
    if (demoStudent.length) {
      console.log("OK: Siswa demo uniqueCode=123456 ada");
    } else {
      console.warn("WARN: Siswa uniqueCode=123456 tidak ada — pakai kode dari DB production");
    }
  }

  if (!allNames.some((n) => /^classes$/i.test(n))) {
    console.warn("WARN: Tabel classes tidak ditemukan");
  } else {
    const demoClass = await prisma.$queryRaw`
      SELECT code FROM classes WHERE code = '1A2B3C' LIMIT 1
    `;
    if (demoClass.length) {
      console.log("OK: Kelas demo code=1A2B3C ada");
    } else {
      console.warn("WARN: Kelas 1A2B3C tidak ada — cek code kelas di DB production");
      const sample = await prisma.$queryRaw`SELECT code, name FROM classes LIMIT 3`;
      if (sample.length) {
        console.log(
          "INFO: Sample kelas:",
          sample.map((r) => `${r.code} (${r.name})`).join(", "),
        );
      }
    }
  }
})()
  .catch((err) => {
    console.error("FAIL:", err.message);
    if (/P1001|P1000|ECONNREFUSED|Access denied|Unknown database/i.test(err.message)) {
      console.error("HINT: Cek MySQL XAMPP jalan, user/password benar, dan nama DB ada di .env");
    }
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
