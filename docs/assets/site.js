/* Shared MacText site interactions — restrained */
(function () {
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

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
