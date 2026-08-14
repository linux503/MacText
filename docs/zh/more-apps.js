/**
 * linux503 产品互链 — 各官网导航「更多软件」
 * 用法: <span data-more-apps="flare"></span>
 * 可选: data-lang="zh" | "en"
 * 会自动排除当前产品（data-more-apps 的值）
 * 动态站点可调用 window.Linux503MoreApps.refresh()
 */
(function () {
  var APPS = [
    {
      id: "flare",
      name: "Flare",
      desc: { zh: "截图录屏", en: "Screenshot & recording" },
      url: "https://linux503.github.io/Flare/",
      github: "https://github.com/linux503/Flare"
    },
    {
      id: "zipx",
      name: "ZipX",
      desc: { zh: "解压压缩", en: "Compress & extract" },
      url: "https://linux503.github.io/ZipX/",
      github: "https://github.com/linux503/ZipX"
    },
    {
      id: "mactext",
      name: "MacText",
      desc: { zh: "文本编辑", en: "Text editor" },
      url: "https://linux503.github.io/MacText/",
      github: "https://github.com/linux503/MacText"
    },
    {
      id: "suptools",
      name: "SupTools",
      desc: { zh: "macOS 超级工具箱", en: "macOS super toolbox" },
      url: "https://linux503.github.io/suptools/",
      github: "https://github.com/linux503/suptools"
    },
    {
      id: "macfan",
      name: "MacFan",
      desc: { zh: "精准控制 Mac 风扇转速", en: "Precise Mac fan control" },
      url: "https://linux503.github.io/MacFan/",
      github: "https://github.com/linux503/MacFan"
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
    if (!el || el.getAttribute("data-more-apps-ready") === "1") {
      // allow rebuild after refresh()
    }
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
      '<span class="more-apps-ico" aria-hidden="true"></span>' +
      '<span class="more-apps-label">' +
      label +
      "</span>";
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
      a.innerHTML =
        '<span class="app-name">' +
        app.name +
        '</span><span class="app-desc">' +
        (app.desc[lang] || app.desc.zh) +
        "</span>";
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
