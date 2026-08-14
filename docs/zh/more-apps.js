/**
 * linux503 product cross-links
 * Usage: <span data-more-apps="zipx" data-lang="zh"></span>
 * Optional: data-lang="en"
 * Dynamic sites can call window.Linux503MoreApps.refresh()
 */
(function () {
  var APPS = [
    {
      id: "flare",
      name: "Flare",
      desc: { zh: "截图录屏", en: "Screenshot & recording" },
      url: "https://linux503.github.io/Flare/"
    },
    {
      id: "zipx",
      name: "ZipX",
      desc: { zh: "解压压缩", en: "Compress & extract" },
      url: "https://linux503.github.io/ZipX/"
    },
    {
      id: "mactext",
      name: "MacText",
      desc: { zh: "文本编辑", en: "Text editor" },
      url: "https://linux503.github.io/MacText/"
    },
    {
      id: "suptools",
      name: "SupTools",
      desc: { zh: "macOS 超级工具箱", en: "macOS super toolbox" },
      url: "https://linux503.github.io/suptools/"
    },
    {
      id: "macfan",
      name: "MacFan",
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
    var current = (el.getAttribute("data-more-apps") || "").toLowerCase();
    var lang = detectLang(el);
    var label = lang === "en" ? "More apps" : "更多软件";
    var items = APPS.filter(function (app) {
      return app.id !== current;
    });
    if (!items.length) return;

    var details = document.createElement("details");
    details.className = "more-apps";

    var summary = document.createElement("summary");
    summary.innerHTML = '<span class="more-apps-label">' + label + "</span>";
    details.appendChild(summary);

    var panel = document.createElement("div");
    panel.className = "more-apps-panel";
    panel.setAttribute("role", "menu");

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
  }

  function onDocClick(ev) {
    document.querySelectorAll("details.more-apps[open]").forEach(function (d) {
      if (!d.contains(ev.target)) d.open = false;
    });
  }

  function refresh() {
    document.querySelectorAll("[data-more-apps]").forEach(build);
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
