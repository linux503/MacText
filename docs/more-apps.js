/**
 * linux503 产品互链 — 「更多软件」
 * 支持两种用法：
 * 1. 静态 HTML：<details class="more-apps" data-more-apps="zipx">（推荐，无 JS 也可见）
 * 2. 占位符：<span data-more-apps="zipx"></span>（JS 动态生成）
 */
(function () {
  var APPS = [
    { id: "flare", name: "Flare", short: "Fl", accent: "#0f9f6e", desc: { zh: "截图录屏", en: "Screenshot & recording" }, url: "https://linux503.github.io/Flare/" },
    { id: "zipx", name: "ZipX", short: "Zx", accent: "#e84d32", desc: { zh: "解压压缩", en: "Compress & extract" }, url: "https://linux503.github.io/ZipX/" },
    { id: "mactext", name: "MacText", short: "Mt", accent: "#3b5bdb", desc: { zh: "文本编辑", en: "Text editor" }, url: "https://linux503.github.io/MacText/" },
    { id: "suptools", name: "SupTools", short: "St", accent: "#0d7a6c", desc: { zh: "macOS 超级工具箱", en: "macOS super toolbox" }, url: "https://linux503.github.io/suptools/" },
    { id: "macfan", name: "MacFan", short: "Mf", accent: "#0891b2", desc: { zh: "精准控制 Mac 风扇转速", en: "Precise Mac fan control" }, url: "https://linux503.github.io/MacFan/" }
  ];

  function detectLang(el) {
    var raw = (el.getAttribute("data-lang") || document.documentElement.getAttribute("lang") || "zh").toLowerCase();
    return raw.indexOf("en") === 0 ? "en" : "zh";
  }

  function panelHTML(items, lang) {
    var head = lang === "en" ? "Other tools by linux503" : "linux503 其他工具";
    var html = '<div class="more-apps-head">' + head + "</div>";
    items.forEach(function (app) {
      html +=
        '<a href="' + app.url + '" target="_blank" rel="noopener noreferrer" role="menuitem" style="--app-accent:' + app.accent + '">' +
        '<span class="more-apps-badge">' + app.short + "</span>" +
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
    var summary = details.querySelector("summary");
    if (summary && !summary.querySelector(".more-apps-label")) {
      summary.innerHTML = summaryHTML(lang);
    } else if (summary) {
      var label = summary.querySelector(".more-apps-label");
      if (label) label.textContent = lang === "en" ? "More apps" : "更多软件";
    }
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
