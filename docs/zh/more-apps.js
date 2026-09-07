/**
 * linux503 产品互链 — 各官网导航「更多软件」
 * 用法: <details class="more-apps" data-more-apps="mactext"> 或 <span data-more-apps="flare"></span>
 */
(function () {
  var APPS = [
    { id: "flare", name: "Flare", accent: "#111111", desc: { zh: "截图、录屏，一键新建 TXT/Word/PPT", en: "Screenshot, recording, new TXT/Word/PPT" }, url: "https://linux503.github.io/Flare/" },
    { id: "zipx", name: "ZipX", accent: "#e84d32", desc: { zh: "解压压缩", en: "Compress & extract" }, url: "https://linux503.github.io/ZipX/" },
    { id: "mactext", name: "MacText", accent: "#111111", desc: { zh: "文本编辑", en: "Text editor" }, url: "https://linux503.github.io/MacText/" },
    { id: "suptools", name: "SupTools", accent: "#0d7a6c", desc: { zh: "macOS 超级工具箱", en: "macOS super toolbox" }, url: "https://linux503.github.io/suptools/" },
    { id: "macfan", name: "MacFan", accent: "#0891b2", desc: { zh: "精准控制 Mac 风扇转速", en: "Precise Mac fan control" }, url: "https://linux503.github.io/MacFan/" },
    { id: "filesdesk", name: "FilesDesk", accent: "#2563eb", desc: { zh: "Mac 智能批量重命名", en: "Smart batch rename" }, url: "https://linux503.github.io/FilesDesk/" },
    { id: "locadesk", name: "LocaDesk", accent: "#7c3aed", desc: { zh: "把 iPhone 定位模拟", en: "Simulate iPhone location" }, url: "https://linux503.github.io/LocaDesk/" },
    { id: "battybar", name: "BattyBar", accent: "#16a34a", desc: { zh: "掌控你的 MacBook 电池", en: "MacBook battery control" }, url: "https://linux503.github.io/BattyBar/" },
    { id: "remotex", name: "RemoteX", accent: "#e11d48", desc: { zh: "远程桌面，随时随地安全连接", en: "Remote desktop, connect anywhere" }, url: "https://linux503.github.io/RemoteX/" }
  ];

  function detectLang(el) {
    var raw = (
      el.getAttribute("data-lang") ||
      document.documentElement.getAttribute("lang") ||
      "zh"
    ).toLowerCase();
    return raw.indexOf("en") === 0 ? "en" : "zh";
  }

  function iconBase() {
    var path = (document.location.pathname || "").toLowerCase();
    return path.indexOf("/zh/") !== -1 || path.endsWith("/zh") ? "../assets/apps/" : "assets/apps/";
  }

  function panelHTML(items, lang) {
    var head = lang === "en" ? "Other tools by linux503" : "linux503 其他工具";
    var base = iconBase();
    var html = '<div class="more-apps-head">' + head + "</div>";
    items.forEach(function (app) {
      html +=
        '<a href="' + app.url + '" target="_blank" rel="noopener noreferrer" role="menuitem" style="--app-accent:' + app.accent + '">' +
        '<img class="more-apps-logo" src="' + base + app.id + '.png" alt="" width="32" height="32" />' +
        '<span class="app-name">' + app.name + "</span>" +
        '<span class="app-desc">' + (app.desc[lang] || app.desc.zh) + "</span>" +
        '<span class="more-apps-arrow" aria-hidden="true">↗</span></a>';
    });
    return html;
  }

  function summaryHTML(lang) {
    var label = lang === "en" ? "More apps" : "更多软件";
    return (
      '<span class="more-apps-ico" aria-hidden="true"><i></i><i></i><i></i><i></i></span>' +
      '<span class="more-apps-label">' + label + "</span>" +
      '<span class="more-apps-chevron" aria-hidden="true"></span>'
    );
  }

  function mountStatic(details) {
    var current = (details.getAttribute("data-more-apps") || "").toLowerCase().trim();
    var lang = detectLang(details);
    var items = APPS.filter(function (app) { return app.id !== current; });
    var panel = details.querySelector(".more-apps-panel");
    if (panel) panel.innerHTML = panelHTML(items, lang);
  }

  function buildPlaceholder(el) {
    var current = (el.getAttribute("data-more-apps") || "").toLowerCase().trim();
    var lang = detectLang(el);
    var items = APPS.filter(function (app) { return app.id !== current; });
    if (!items.length) return;

    var details = document.createElement("details");
    details.className = "more-apps";
    details.setAttribute("data-more-apps", current);

    var summary = document.createElement("summary");
    summary.innerHTML = summaryHTML(lang);
    details.appendChild(summary);

    var panel = document.createElement("div");
    panel.className = "more-apps-panel";
    panel.setAttribute("role", "menu");
    panel.innerHTML = panelHTML(items, lang);
    details.appendChild(panel);

    el.replaceWith(details);
  }

  function onDocClick(ev) {
    document.querySelectorAll("details.more-apps[open]").forEach(function (d) {
      if (!d.contains(ev.target)) d.open = false;
    });
  }

  function refresh() {
    document.querySelectorAll("details.more-apps[data-more-apps]").forEach(mountStatic);
    document.querySelectorAll("[data-more-apps]:not(details)").forEach(buildPlaceholder);
  }

  function boot() {
    refresh();
    document.addEventListener("click", onDocClick);
  }

  window.Linux503MoreApps = { refresh: refresh, apps: APPS };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
