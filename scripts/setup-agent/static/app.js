(function () {
  const TOKEN_KEY = "gurubot_operator_token";
  const API = "/api/operator";

  const pinScreen = document.getElementById("pin-screen");
  const appEl = document.getElementById("app");
  const pinInput = document.getElementById("pin-input");
  const pinSubmit = document.getElementById("pin-submit");
  const pinError = document.getElementById("pin-error");

  let statusData = null;
  let wizardStep = 0;

  const WIZARD = [
    {
      title: "1. Prasyarat PC server",
      html: function () {
        return (
          "<h2>Prasyarat</h2>" +
          "<p>Pastikan sudah terpasang di laptop server:</p>" +
          "<ul>" +
          "<li>Docker Desktop (jalan)</li>" +
          "<li>MySQL 8 (service Windows)</li>" +
          "<li>Ollama + model <code>qwen3:1.7b</code></li>" +
          "<li>mkcert (<code>scripts\\setup-ssl.bat</code>)</li>" +
          "</ul>" +
          "<p>Klik <strong>Periksa ulang</strong> di Dashboard — item Docker, MySQL, Ollama, mkcert harus hijau/kuning.</p>"
        );
      },
    },
    {
      title: "2. Stack Docker",
      html: function () {
        return (
          "<h2>Container Docker</h2>" +
          "<p>Semua service (app, nginx, dns, ocr, whisper) harus <strong>Up</strong>.</p>" +
          "<p>Jika belum: jalankan <code>scripts\\docker-up.bat</code> di PC server, atau minta admin IT.</p>" +
          '<button type="button" data-action="docker-up">Jalankan docker-up (lama)</button>' +
          '<output class="action-log" id="wiz-docker-log"></output>'
        );
      },
    },
    {
      title: "3. DNS gurubot.sekolah",
      html: function () {
        const ip = statusData && statusData.lanIp ? statusData.lanIp : "(IP LAN)";
        return (
          "<h2>DNS domain untuk semua HP</h2>" +
          "<p>IP server WiFi: <strong>" + ip + "</strong></p>" +
          "<ol>" +
          "<li>Di router sekolah, set <strong>DHCP DNS</strong> = IP server di atas.</li>" +
          "<li>TP-Link: DHCP → Primary DNS · Mikrotik: DHCP Networks → DNS · IndiHome: LAN → DHCP → DNS.</li>" +
          "<li>HP: matikan <em>Private DNS</em>, reconnect WiFi.</li>" +
          "</ol>" +
          '<button type="button" data-action="setup-dns">Sinkronkan record DNS di Technitium</button>' +
          '<output class="action-log" id="wiz-dns-log"></output>' +
          "<p>Verifikasi: check <strong>DNS gurubot.sekolah</strong> di Dashboard harus hijau.</p>"
        );
      },
    },
    {
      title: "4. Firewall WiFi",
      html: function () {
        return (
          "<h2>Akses dari HP (HTTPS + DNS)</h2>" +
          "<p>Windows harus mengizinkan koneksi masuk ke port <strong>443</strong> dan <strong>53</strong>.</p>" +
          "<p>Butuh <strong>Run as Administrator</strong> sekali.</p>" +
          '<button type="button" data-action="firewall">Buka firewall LAN</button>' +
          '<output class="action-log" id="wiz-fw-log"></output>'
        );
      },
    },
    {
      title: "5. Sertifikat di tablet/HP",
      html: function () {
        return (
          "<h2>Trust CA mkcert</h2>" +
          "<p>Agar HTTPS dipercaya dan mic berfungsi:</p>" +
          "<ol>" +
          "<li>Unduh file CA di bawah.</li>" +
          "<li>Android: Settings → Security → Install certificate → CA certificate.</li>" +
          "<li>iOS: install profile → Settings → Certificate Trust Settings.</li>" +
          "</ol>" +
          '<p><a href="' +
          API +
          '/certs/root-ca" id="ca-download">Unduh gurubot-mkcert-rootCA.pem</a> (perlu login PIN)</p>'
        );
      },
    },
    {
      title: "6. Uji dari HP",
      html: function () {
        const url =
          statusData && statusData.urls && statusData.urls.welcome
            ? statusData.urls.welcome
            : "https://gurubot.sekolah/welcome";
        return (
          "<h2>Tes akhir</h2>" +
          "<ol>" +
          "<li>HP di WiFi yang sama, buka: <a href=\"" +
          url +
          "\" target=\"_blank\" rel=\"noopener\">" +
          url +
          "</a></li>" +
          "<li>Harus tampil halaman welcome tanpa error DNS.</li>" +
          "<li>Jika peringatan sertifikat, ulangi langkah 5.</li>" +
          "</ol>" +
          "<p>Selamat — GuruBot siap dipakai di kelas.</p>"
        );
      },
    },
  ];

  function token() {
    return sessionStorage.getItem(TOKEN_KEY) || "";
  }

  function setToken(t) {
    sessionStorage.setItem(TOKEN_KEY, t);
  }

  async function api(path, options) {
    const headers = Object.assign({ "Content-Type": "application/json" }, (options && options.headers) || {});
    const t = token();
    if (t) headers.Authorization = "Bearer " + t;
    const res = await fetch(API + path, Object.assign({}, options, { headers }));
    const ct = res.headers.get("content-type") || "";
    if (ct.indexOf("application/json") >= 0) return res.json();
    if (!res.ok) throw new Error("HTTP " + res.status);
    return res.blob();
  }

  async function bootstrap() {
    const boot = await fetch(API + "/bootstrap").then(function (r) {
      return r.json();
    });
    const t = token();
    if (!boot.pinRequired && t) {
      showApp();
      return refreshStatus();
    }
    if (!boot.pinRequired) {
      const auth = await fetch(API + "/auth/pin", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ pin: "" }),
      }).then(function (r) {
        return r.json();
      });
      if (auth.ok && auth.token) {
        setToken(auth.token);
        showApp();
        return refreshStatus();
      }
    }
    if (t) {
      try {
        await api("/status");
        showApp();
        return refreshStatus();
      } catch (e) {
        sessionStorage.removeItem(TOKEN_KEY);
      }
    }
    pinScreen.classList.remove("hidden");
  }

  function showApp() {
    pinScreen.classList.add("hidden");
    appEl.classList.remove("hidden");
    bindLanActions();
    bindMysqlActions();
  }

  pinSubmit.addEventListener("click", async function () {
    pinError.classList.add("hidden");
    try {
      const res = await fetch(API + "/auth/pin", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ pin: pinInput.value.trim() }),
      }).then(function (r) {
        return r.json();
      });
      if (!res.ok) {
        pinError.textContent = res.error || "Gagal masuk";
        pinError.classList.remove("hidden");
        return;
      }
      setToken(res.token);
      showApp();
      refreshStatus();
    } catch (e) {
      pinError.textContent = "Tidak bisa hubungi server setup. Pastikan setup-agent jalan.";
      pinError.classList.remove("hidden");
    }
  });

  function escHtml(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/"/g, "&quot;");
  }

  function renderLanAccess(data) {
    const el = document.getElementById("lan-access");
    if (!el) return;
    const la = data.lanAccess;
    if (!la) {
      el.classList.add("hidden");
      el.innerHTML = "";
      return;
    }
    el.classList.remove("hidden");
    const overall = la.overall || "unknown";
    const badgeClass = overall === "ok" ? "ok" : overall === "fail" ? "fail" : "warn";
    let statusHtml = "";
    (la.statusItems || []).forEach(function (item) {
      statusHtml +=
        '<div class="lan-status-item ' +
        escHtml(item.status || "warn") +
        '"><strong>' +
        escHtml(item.name) +
        "</strong><br />" +
        escHtml(item.detail || "") +
        "</div>";
    });
    let routerOl = "";
    (la.routerGuide || []).forEach(function (line) {
      routerOl += "<li>" + escHtml(line) + "</li>";
    });
    let hpOl = "";
    (la.hpChecklist || []).forEach(function (line) {
      hpOl += "<li>" + escHtml(line) + "</li>";
    });
    const rec = la.recommendedUrl || "https://gurubot.sekolah/welcome";
    const fb = la.fallbackHttpsUrl || "";
    el.innerHTML =
      "<h3>Akses dari HP / tablet (WiFi sekolah)</h3>" +
      "<p>Status siap LAN: <span class=\"badge " +
      badgeClass +
      "\">" +
      escHtml(overall) +
      "</span> · IP server untuk router DNS: <strong>" +
      escHtml(la.routerDnsTarget || la.lanIp || "?") +
      "</strong></p>" +
      '<div class="lan-url-box">' +
      "<div><strong>URL disarankan (setelah router DNS OK):</strong><br />" +
      '<a href="' +
      escHtml(rec) +
      '" target="_blank" rel="noopener">' +
      escHtml(rec) +
      "</a></div>" +
      (fb
        ? "<div style=\"margin-top:.4rem\"><strong>Fallback HTTPS (IP):</strong><br />" +
          '<a href="' +
          escHtml(fb) +
          '" target="_blank" rel="noopener">' +
          escHtml(fb) +
          "</a></div>"
        : "") +
      "</div>" +
      '<p class="muted mysql-pass-note">' +
      escHtml(la.nextAuthNote || "") +
      " NEXTAUTH_URL: <code>" +
      escHtml(la.nextAuthUrl || "") +
      "</code></p>" +
      '<div class="lan-status-grid">' +
      statusHtml +
      "</div>" +
      "<p><strong>Panduan router (manual di admin router):</strong></p>" +
      "<ol class=\"mysql-hints\">" +
      routerOl +
      "</ol>" +
      "<p><strong>Checklist di HP:</strong></p>" +
      "<ol class=\"mysql-hints\">" +
      hpOl +
      "</ol>" +
      '<div class="panel-actions">' +
      '<button type="button" data-lan-action="setup-dns">Sinkronkan DNS (Technitium)</button>' +
      '<button type="button" data-lan-action="firewall" class="btn-secondary">Firewall WiFi 443/53</button>' +
      (la.hostNginxOnWindows
        ? '<button type="button" data-lan-action="stop-host-nginx" class="btn-secondary">Stop nginx Windows</button>'
        : "") +
      "</div>" +
      '<output class="action-log" id="lan-action-log"></output>';
  }

  let lanActionsBound = false;
  function bindLanActions() {
    if (lanActionsBound) return;
    const host = document.getElementById("lan-access");
    if (!host) return;
    lanActionsBound = true;
    host.addEventListener("click", function (ev) {
      const btn = ev.target.closest("[data-lan-action]");
      if (!btn) return;
      runAction(btn.getAttribute("data-lan-action"), "lan-action-log");
    });
  }

  function renderMysqlInfo(data) {
    const el = document.getElementById("mysql-info");
    if (!el) return;
    const m = data.mysql;
    if (!m) {
      el.classList.add("hidden");
      el.innerHTML = "";
      return;
    }
    el.classList.remove("hidden");
    if (!m.configured) {
      el.innerHTML =
        "<h3>MySQL</h3>" +
        "<p class=\"muted\">DATABASE_URL belum valid di <code>.env.docker</code>.</p>" +
        '<div class="mysql-env-form">' +
        "<h4>Isi DATABASE_URL</h4>" +
        '<label class="mysql-field">User MySQL <input type="text" id="mysql-f-user" value="root" autocomplete="off" /></label>' +
        '<label class="mysql-field">Sandi MySQL <input type="password" id="mysql-f-pass" autocomplete="new-password" placeholder="Sandi saat instal MySQL" /></label>' +
        '<label class="mysql-field">Nama database <input type="text" id="mysql-f-db" value="gurubot_db" autocomplete="off" /></label>' +
        '<button type="button" id="mysql-save-env">Simpan ke .env.docker &amp; restart app</button>' +
        '<button type="button" data-mysql-action="open-env-docker" class="btn-secondary">Buka .env.docker (Notepad)</button>' +
        "</div>" +
        '<output class="action-log" id="mysql-action-log"></output>';
      return;
    }
    const conn = m.connection || {};
    const connStatus = conn.status || "unknown";
    const badgeClass = connStatus === "ok" ? "ok" : connStatus === "fail" ? "fail" : "warn";
    let hintsHtml = "";
    if (conn.hints && conn.hints.length) {
      hintsHtml =
        "<p><strong>Langkah perbaikan:</strong></p><ul class=\"mysql-hints\">" +
        conn.hints
          .map(function (h) {
            return "<li>" + escHtml(h) + "</li>";
          })
          .join("") +
        "</ul>";
    }
    const showCreateDb = connStatus !== "ok";
    const passNote = m.passwordNote || "Sandi MySQL hanya ada di .env.docker — server MySQL tidak bisa memberitahu sandi yang benar.";
    el.innerHTML =
      "<h3>MySQL <span class=\"muted heading-sub\">(dari .env.docker)</span></h3>" +
      "<p class=\"muted mysql-pass-note\">" +
      escHtml(passNote) +
      "</p>" +
      "<p class=\"mysql-conn-line\">Simulasi koneksi: <span class=\"badge " +
      badgeClass +
      "\">" +
      escHtml(connStatus) +
      "</span> " +
      escHtml(conn.message || "") +
      "</p>" +
      "<dl class=\"mysql-dl\">" +
      "<dt>Host (container Docker)</dt><dd><code>" +
      escHtml(m.host) +
      ":" +
      escHtml(m.port) +
      "</code></dd>" +
      "<dt>Host (PC server / Workbench)</dt><dd><code>" +
      escHtml(m.hostLocal || "127.0.0.1") +
      ":" +
      escHtml(m.port) +
      "</code></dd>" +
      "<dt>Database</dt><dd><code>" +
      escHtml(m.database) +
      "</code></dd>" +
      "<dt>User</dt><dd><code>" +
      escHtml(m.user) +
      "</code></dd>" +
      "<dt>Password (di .env.docker)</dt><dd><code class=\"mysql-pass\">" +
      escHtml(m.password ? m.password : "(kosong)") +
      "</code></dd>" +
      "</dl>" +
      hintsHtml +
      '<div class="mysql-env-form">' +
      "<h4>Perbarui DATABASE_URL</h4>" +
      '<label class="mysql-field">User MySQL <input type="text" id="mysql-f-user" autocomplete="off" value="' +
      escHtml(m.user) +
      '" /></label>' +
      '<label class="mysql-field">Sandi MySQL <input type="password" id="mysql-f-pass" autocomplete="new-password" placeholder="Sandi saat instal MySQL" value="' +
      escHtml(m.password || "") +
      '" /></label>' +
      '<label class="mysql-field">Nama database <input type="text" id="mysql-f-db" autocomplete="off" value="' +
      escHtml(m.database) +
      '" /></label>' +
      '<div class="mysql-actions">' +
      '<button type="button" id="mysql-save-env">Simpan ke .env.docker &amp; restart app</button>' +
      '<button type="button" data-mysql-action="open-env-docker" class="btn-secondary">Buka .env.docker (Notepad)</button>' +
      '<button type="button" data-mysql-action="test-db">Tes koneksi (Prisma)</button>' +
      (showCreateDb
        ? '<button type="button" data-mysql-action="mysql-create-db" class="btn-secondary">Buat database</button>'
        : "") +
      '<button type="button" data-mysql-action="prisma-generate" class="btn-secondary">Prisma generate</button>' +
      "</div>" +
      "</div>" +
      '<output class="action-log" id="mysql-action-log"></output>' +
      "<p class=\"muted mysql-note\">" +
      escHtml(m.note || "") +
      (m.serviceRunning === false ? " · Service MySQL Windows belum RUNNING." : "") +
      (m.portOpen === false ? " · Port 3306 tidak terbuka di localhost." : "") +
      "</p>";
  }

  async function saveMysqlEnvConfig() {
    const log = document.getElementById("mysql-action-log");
    const userEl = document.getElementById("mysql-f-user");
    const passEl = document.getElementById("mysql-f-pass");
    const dbEl = document.getElementById("mysql-f-db");
    if (!userEl || !dbEl) return;
    if (log) log.textContent = "Menyimpan .env.docker…";
    try {
      const res = await api("/mysql/config", {
        method: "POST",
        body: JSON.stringify({
          user: userEl.value.trim(),
          password: passEl ? passEl.value : "",
          database: dbEl.value.trim(),
          restartApp: true,
        }),
      });
      if (!res.ok) {
        if (log) log.textContent = res.error || "Gagal menyimpan";
        return;
      }
      let msg = "Tersimpan: " + (res.databaseUrlMasked || "DATABASE_URL") + ".";
      if (res.restartOk === false) {
        msg += " Restart container app gagal — jalankan: docker compose restart app";
      } else {
        msg += " Container app di-restart.";
      }
      await refreshStatus();
      const el = document.getElementById("mysql-action-log");
      if (el) el.textContent = msg;
    } catch (e) {
      if (log) log.textContent = String(e);
    }
  }

  let mysqlActionsBound = false;
  function bindMysqlActions() {
    if (mysqlActionsBound) return;
    const host = document.getElementById("mysql-info");
    if (!host) return;
    mysqlActionsBound = true;
    host.addEventListener("click", function (ev) {
      if (ev.target.id === "mysql-save-env") {
        saveMysqlEnvConfig();
        return;
      }
      const btn = ev.target.closest("[data-mysql-action]");
      if (!btn) return;
      runAction(btn.getAttribute("data-mysql-action"), "mysql-action-log");
    });
  }

  function renderChecks(data) {
    const summary = document.getElementById("summary");
    const grid = document.getElementById("checks");
    if (data.error) {
      summary.innerHTML =
        '<span class="badge fail">error</span> Gagal baca status: ' +
        (data.error || "") +
        (data.detail ? " — " + String(data.detail).slice(0, 200) : "");
      grid.innerHTML = "";
      renderLanAccess({});
      renderMysqlInfo({});
      return;
    }
    const overall = data.overall || "unknown";
    summary.innerHTML =
      '<span class="badge ' +
      overall +
      '">' +
      overall +
      "</span> " +
      "Server LAN <strong>" +
      (data.lanIp || "?") +
      "</strong> · Domain <strong>" +
      (data.domain || "gurubot.sekolah") +
      "</strong>";
    grid.innerHTML = "";
    (data.checks || []).forEach(function (c) {
      const div = document.createElement("div");
      div.className = "check " + c.status;
      div.innerHTML = "<h4>" + c.name + "</h4><p>" + (c.detail || c.status) + "</p>";
      grid.appendChild(div);
    });
    document.getElementById("autostart-log").textContent = data.autostartLogTail || "(kosong)";
    renderLanAccess(data);
    renderMysqlInfo(data);
  }

  async function refreshStatus() {
    try {
      statusData = await api("/status");
      renderChecks(statusData);
      renderWizard();
    } catch (e) {
      document.getElementById("summary").textContent =
        "Gagal memuat status — pastikan scripts\\ensure-setup-agent.bat sudah dijalankan.";
    }
  }

  async function runAction(name, logId) {
    const out = logId ? document.getElementById(logId) : null;
    if (out) out.textContent = "Menjalankan…";
    try {
      const res = await api("/actions/" + name, { method: "POST", body: "{}" });
      const logText = res.output || (res.ok ? "Selesai." : "Gagal.");
      await refreshStatus();
      if (logId) {
        const el = document.getElementById(logId);
        if (el) el.textContent = logText;
      }
    } catch (e) {
      if (out) out.textContent = String(e);
    }
  }

  document.getElementById("btn-refresh").addEventListener("click", refreshStatus);
  document.getElementById("btn-setup-dns").addEventListener("click", function () {
    runAction("setup-dns");
  });
  document.getElementById("btn-firewall").addEventListener("click", function () {
    runAction("firewall");
  });

  document.querySelectorAll(".topbar .nav").forEach(function (btn) {
    btn.addEventListener("click", function () {
      document.querySelectorAll(".topbar .nav").forEach(function (b) {
        b.classList.remove("active");
      });
      btn.classList.add("active");
      const view = btn.getAttribute("data-view");
      document.getElementById("view-dashboard").classList.toggle("hidden", view !== "dashboard");
      document.getElementById("view-setup").classList.toggle("hidden", view !== "setup");
      if (view === "setup") renderWizard();
    });
  });

  function renderWizard() {
    const stepsEl = document.getElementById("wizard-steps");
    const panel = document.getElementById("wizard-panel");
    stepsEl.innerHTML = "";
    WIZARD.forEach(function (s, i) {
      const li = document.createElement("li");
      li.textContent = s.title;
      if (i === wizardStep) li.classList.add("active");
      stepsEl.appendChild(li);
    });
    panel.innerHTML = WIZARD[wizardStep].html();
    const ca = document.getElementById("ca-download");
    if (ca) {
      ca.addEventListener("click", async function (ev) {
        ev.preventDefault();
        try {
          const blob = await api("/certs/root-ca");
          const a = document.createElement("a");
          a.href = URL.createObjectURL(blob);
          a.download = "gurubot-mkcert-rootCA.pem";
          a.click();
        } catch (e) {
          alert("Gagal unduh CA: " + e);
        }
      });
    }
    panel.querySelectorAll("[data-action]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        const act = btn.getAttribute("data-action");
        const logMap = { "setup-dns": "wiz-dns-log", firewall: "wiz-fw-log", "docker-up": "wiz-docker-log" };
        runAction(act, logMap[act]);
      });
    });
  }

  document.getElementById("wiz-prev").addEventListener("click", function () {
    wizardStep = Math.max(0, wizardStep - 1);
    renderWizard();
  });
  document.getElementById("wiz-next").addEventListener("click", function () {
    wizardStep = Math.min(WIZARD.length - 1, wizardStep + 1);
    renderWizard();
  });

  bootstrap();
})();
