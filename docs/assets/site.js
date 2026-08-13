/* Shared MacText site interactions */
(function () {
  // Scroll reveal
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
      { threshold: 0.12, rootMargin: "0px 0px -6% 0px" }
    );
    reveals.forEach((el) => io.observe(el));
  } else {
    reveals.forEach((el) => el.classList.add("is-in"));
  }

  // Soft pointer spotlight on glass panels
  const panels = document.querySelectorAll(".side, .dl-card, .cell, .controls button");
  panels.forEach((panel) => {
    panel.addEventListener("pointermove", (e) => {
      const r = panel.getBoundingClientRect();
      const x = ((e.clientX - r.left) / r.width) * 100;
      const y = ((e.clientY - r.top) / r.height) * 100;
      panel.style.setProperty("--mx", x + "%");
      panel.style.setProperty("--my", y + "%");
      if (!panel.dataset.spot) {
        panel.dataset.spot = "1";
        panel.style.backgroundImage =
          "radial-gradient(420px circle at var(--mx) var(--my), rgba(180,224,74,0.1), transparent 45%)";
      }
    });
    panel.addEventListener("pointerleave", () => {
      panel.style.backgroundImage = "";
      delete panel.dataset.spot;
    });
  });

  // Parallax orbs follow scroll lightly
  const orbs = document.querySelectorAll(".atmosphere .orb");
  if (orbs.length) {
    let ticking = false;
    window.addEventListener(
      "scroll",
      () => {
        if (ticking) return;
        ticking = true;
        requestAnimationFrame(() => {
          const y = window.scrollY * 0.04;
          orbs.forEach((orb, i) => {
            const dir = i % 2 === 0 ? 1 : -1;
            orb.style.translate = `0 ${y * dir}px`;
          });
          ticking = false;
        });
      },
      { passive: true }
    );
  }
})();
