/* Shared MacText site interactions — restrained */
(function () {
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Changelog page: render from changelog.json
  const clRoot = document.getElementById("changelog-list");
  if (clRoot) {
    const lang = clRoot.getAttribute("data-lang") === "zh" ? "zh" : "en";
    const src = clRoot.getAttribute("data-src") || "changelog.json";
    const labels = {
      en: { beta: "Beta", stable: "Stable", release: "Release", more: "GitHub release →", empty: "No entries yet.", fail: "Could not load changelog." },
      zh: { beta: "体验版", stable: "稳定版", release: "正式版", more: "GitHub 发布页 →", empty: "暂无记录。", fail: "无法加载更新记录。" }
    }[lang];

    fetch(src + (src.indexOf("?") >= 0 ? "&" : "?") + "ts=" + Date.now(), { cache: "no-store" })
      .then((r) => {
        if (!r.ok) throw new Error(String(r.status));
        return r.json();
      })
      .then((data) => {
        const entries = (data && data.entries) || [];
        if (!entries.length) {
          clRoot.innerHTML = '<p class="cl-empty">' + labels.empty + "</p>";
          return;
        }
        clRoot.innerHTML = entries
          .map((e) => {
            const loc = (e && e[lang]) || e.en || {};
            const channel = (e.channel || "release").toLowerCase();
            const badgeClass =
              channel === "beta" ? "is-beta" : channel === "stable" ? "is-stable" : "";
            const badgeText =
              channel === "beta" ? labels.beta : channel === "stable" ? labels.stable : labels.release;
            const items = (loc.highlights || [])
              .map((h) => "<li>" + String(h).replace(/</g, "&lt;") + "</li>")
              .join("");
            const tag = e.tag || ("v" + e.version);
            const href = "https://github.com/linux503/MacText/releases/tag/" + encodeURIComponent(tag);
            return (
              '<article class="cl-item">' +
              '<div class="cl-top">' +
              '<span class="cl-ver">v' + String(e.version || "").replace(/</g, "&lt;") + "</span>" +
              '<span class="cl-badge ' + badgeClass + '">' + badgeText + "</span>" +
              '<span class="cl-date">' + String(e.date || "").replace(/</g, "&lt;") + "</span>" +
              "</div>" +
              "<h2 class=\"cl-title\">" + String(loc.title || "").replace(/</g, "&lt;") + "</h2>" +
              (items ? "<ul>" + items + "</ul>" : "") +
              '<a class="cl-more" href="' + href + '" rel="noopener">' + labels.more + "</a>" +
              "</article>"
            );
          })
          .join("");
        clRoot.classList.add("is-in");
      })
      .catch(() => {
        clRoot.innerHTML = '<p class="cl-empty">' + labels.fail + "</p>";
      });
  }

  document.querySelectorAll(".matrix .cell").forEach((el, i) => {
    el.style.setProperty("--i", String(i));
  });

  const reveals = document.querySelectorAll(".reveal");
  if (reveals.length && "IntersectionObserver" in window) {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) {
            e.target.classList.add("is-in");
            io.unobserve(e.target);
          }
        });
      },
      { threshold: 0.1, rootMargin: "0px 0px -4% 0px" }
    );
    reveals.forEach((el) => io.observe(el));
  } else {
    reveals.forEach((el) => el.classList.add("is-in"));
  }

  // Soft highlight on glass panels — no green cursor blob
  if (!reduce) {
    document.querySelectorAll(".dl-card, .cell, .controls button, .split > div").forEach((panel) => {
      panel.addEventListener("pointermove", (e) => {
        const r = panel.getBoundingClientRect();
        const x = ((e.clientX - r.left) / r.width) * 100;
        const y = ((e.clientY - r.top) / r.height) * 100;
        panel.style.backgroundImage =
          "radial-gradient(320px circle at " + x + "% " + y + "%, rgba(255,255,255,0.07), transparent 50%)";
      });
      panel.addEventListener("pointerleave", () => {
        panel.style.backgroundImage = "";
      });
    });
  }

  // Gentle scroll parallax on orbs only
  const orbs = document.querySelectorAll(".atmosphere .orb");
  if (orbs.length && !reduce) {
    let ticking = false;
    window.addEventListener(
      "scroll",
      () => {
        if (ticking) return;
        ticking = true;
        requestAnimationFrame(() => {
          const y = window.scrollY * 0.03;
          orbs.forEach((orb, i) => {
            orb.style.translate = "0 " + y * (i % 2 === 0 ? 1 : -1) + "px";
          });
          ticking = false;
        });
      },
      { passive: true }
    );
  }
})();
