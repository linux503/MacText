/**
 * linux503 产品互链 — 各官网导航「更多软件」
 * 用法: <span data-more-apps="flare"></span>
 * 可选: data-lang="zh" | "en"
 */
(function () {
  var APPS = [
    {
      id: "flare",
      name: "Flare",
      short: "Fl",
      accent: "#0f9f6e",
      desc: { zh: "截图录屏", en: "Screenshot & recording" },
      url: "https://linux503.github.io/Flare/"
    },
    {
      id: "zipx",
      name: "ZipX",
      short: "Zx",
      accent: "#e84d32",
      desc: { zh: "解压压缩", en: "Compress & extract" },
      url: "https://linux503.github.io/ZipX/"
    },
    {
      id: "mactext",
      name: "MacText",
      short: "Mt",
      accent: "#3b5bdb",
      desc: { zh: "文本编辑", en: "Text editor" },
      url: "https://linux503.github.io/MacText/"
    },
    {
      id: "suptools",
      name: "SupTools",
      short: "St",
      accent: "#0d7a6c",
      desc: { zh: "macOS 超级工具箱", en: "macOS super toolbox" },
      url: "https://linux503.github.io/suptools/"
    },
    {
      id: "macfan",
      name: "MacFan",
      short: "Mf",
      accent: "#0891b2",
      desc: { zh: "精准控制 Mac 风扇转速", en: "Precise Mac fan control" },
      url: "https://linux503.github.io/MacFan/"
    }
  ];

  function detectLang(el) {
    var raw = (
      el.getAttribute("data-lang") ||
      document.documentElement.getAttribute("lang") ||
      "zh"
    ).toLowerCase();
    return raw.indexOf("en") === 0 ? "en" : "zh";
  }

  function build(el) {
    var current = (el.getAttribute("data-more-apps") || "").toLowerCase().trim();
    var lang = detectLang(el);
    var label = lang === "en" ? "More apps" : "更多软件";
    var items = APPS.filter(function (app) {
      return app.id !== current;
    });
    if (!items.length) return;

    var details = document.createElement("details");
    details.className = "more-apps";

    var summary = document.createElement("summary");
    summary.innerHTML =
      '<span class="more-apps-ico" aria-hidden="true">' +
      "<i></i><i></i><i></i><i></i>" +
      "</span>" +
      '<span class="more-apps-label">' +
      label +
      "</span>" +
      '<span class="more-apps-chevron" aria-hidden="true"></span>';
    details.appendChild(summary);

    var panel = document.createElement("div");
    panel.className = "more-apps-panel";
    panel.setAttribute("role", "menu");

    var head = document.createElement("div");
    head.className = "more-apps-head";
    head.textContent = lang === "en" ? "Other tools by linux503" : "linux503 其他工具";
    panel.appendChild(head);

    items.forEach(function (app) {
      var a = document.createElement("a");
      a.href = app.url;
      a.target = "_blank";
      a.rel = "noopener noreferrer";
      a.setAttribute("role", "menuitem");
      a.style.setProperty("--app-accent", app.accent);
      a.innerHTML =
        '<span class="more-apps-badge">' +
        app.short +
        "</span>" +
        '<span class="app-name">' +
        app.name +
        "</span>" +
        '<span class="app-desc">' +
        (app.desc[lang] || app.desc.zh) +
        "</span>" +
        '<span class="more-apps-arrow" aria-hidden="true">↗</span>";
      panel.appendChild(a);
    });

    details.appendChild(panel);
    el.innerHTML = "";
    el.appendChild(details);
    el.setAttribute("data-more-apps-ready", "1");
  }

  function onDocClick(ev) {
    document.querySelectorAll("details.more-apps[open]").forEach(function (d) {
      if (!d.contains(ev.target)) d.open = false;
    });
  }

  function refresh() {
    document.querySelectorAll("[data-more-apps]").forEach(function (el) {
      el.removeAttribute("data-more-apps-ready");
      build(el);
    });
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
