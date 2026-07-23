/**
 * PM2 ecosystem — Windows GuruBot local deploy (LEGACY)
 * Jalur utama deploy: Docker Compose (lihat docker-compose.yml).
 * Set BUNDLE_ROOT sebelum pm2 start, atau edit default di bawah.
 */
const path = require("path");

const bundleRoot =
  process.env.BUNDLE_ROOT || path.resolve(__dirname, "..");

const nextjs = path.join(bundleRoot, "artifacts", "nextjs");
const ocrDir = path.join(nextjs, "ml-training");
const whisperApp = path.join(bundleRoot, "artifacts", "whisper", "app");
const ocrVenvPython = path.join(ocrDir, "venv", "Scripts", "python.exe");

module.exports = {
  apps: [
    {
      name: "gurubot-app",
      script: "server.js",
      cwd: nextjs,
      env: {
        NODE_ENV: "production",
        PORT: "2050",
        HOSTNAME: "127.0.0.1",
        SENTRY_DSN: "",
        OTEL_SDK_DISABLED: "true",
      },
      max_restarts: 10,
      min_uptime: "10s",
    },
    {
      name: "gurubot-ocr",
      script: "ocr_server.py",
      cwd: ocrDir,
      interpreter: ocrVenvPython,
      env: {
        PYTHONUNBUFFERED: "1",
      },
      max_restarts: 10,
      min_uptime: "10s",
    },
    {
      name: "gurubot-whisper",
      script: path.join(
        bundleRoot,
        "artifacts",
        "whisper",
        "venv",
        "Scripts",
        "python.exe"
      ),
      args: "-m uvicorn main:app --host 127.0.0.1 --port 2063 --workers 1",
      cwd: whisperApp,
      env: {
        PYTHONUNBUFFERED: "1",
      },
      max_restarts: 10,
      min_uptime: "30s",
    },
  ],
};
