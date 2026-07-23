-- GuruBot MySQL init — OPSIONAL (hanya instal baru dari nol)
-- Jika pakai root + dump production, skrip ini TIDAK diperlukan.
-- Contoh: mysql -u root -p < scripts\lib\mysql-init.sql

CREATE DATABASE IF NOT EXISTS gurubot
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'gurubot'@'127.0.0.1' IDENTIFIED BY 'GANTI_SANDI';
CREATE USER IF NOT EXISTS 'gurubot'@'localhost' IDENTIFIED BY 'GANTI_SANDI';

GRANT ALL PRIVILEGES ON gurubot.* TO 'gurubot'@'127.0.0.1';
GRANT ALL PRIVILEGES ON gurubot.* TO 'gurubot'@'localhost';

FLUSH PRIVILEGES;
