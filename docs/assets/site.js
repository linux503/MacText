/* Shared MacText site interactions v2 */
(function () {
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Stagger feature cells
  document.querySelectorAll(".matrix .cell").forEach((el, i) => {
    el.style.setProperty("--i", String(i));
  });

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
      { threshold: 0.1, rootMargin: "0px 0px -5% 0px" }
    );
    reveals.forEach((el) => io.observe(el));
  } else {
    reveals.forEach((el) => el.classList.add("is-in"));
  }

  // Pointer spotlight on glass panels
  const panels = document.querySelectorAll(".dl-card, .cell, .controls button, .split > div");
  panels.forEach((panel) => {
    panel.addEventListener("pointermove", (e) => {
      const r = panel.getBoundingClientRect();
      const x = ((e.clientX - r.left) / r.width) * 100;
      const y = ((e.clientY - r.top) / r.height) * 100;
      panel.style.setProperty("--mx", x + "%");
      panel.style.setProperty("--my", y + "%");
      panel.style.backgroundImage =
        "radial-gradient(380px circle at var(--mx) var(--my), rgba(194,240,78,0.12), transparent 48%)";
    });
    panel.addEventListener("pointerleave", () => {
      panel.style.backgroundImage = "";
    });
  });

  // Soft cursor glow
  if (!reduce && window.matchMedia("(pointer: fine)").matches) {
    const glow = document.createElement("div");
    glow.className = "cursor-glow";
    document.body.appendChild(glow);
    let x = 0, y = 0, tx = 0, ty = 0, raf = 0;
    const loop = () => {
      x += (tx - x) * 0.12;
      y += (ty - y) * 0.12;
      glow.style.transform = `translate3d(${x}px, ${y}px, 0)`;
      raf = requestAnimationFrame(loop);
    };
    window.addEventListener(
      "pointermove",
      (e) => {
        tx = e.clientX;
        ty = e.clientY;
        document.body.classList.add("is-pointer");
        if (!raf) raf = requestAnimationFrame(loop);
      },
      { passive: true }
    );
  }

  // 3D tilt on hero frame
  const visual = document.querySelector(".hero-visual");
  const frame = document.querySelector(".hero-frame");
  if (visual && frame && !reduce) {
    visual.addEventListener("pointermove", (e) => {
      const r = visual.getBoundingClientRect();
      const px = (e.clientX - r.left) / r.width - 0.5;
      const py = (e.clientY - r.top) / r.height - 0.5;
      frame.style.transform =
        `rotateY(${-6 + px * 10}deg) rotateX(${3 - py * 8}deg) scale(1.01)`;
    });
    visual.addEventListener("pointerleave", () => {
      frame.style.transform = "";
    });
  }

  // Parallax orbs
  const orbs = document.querySelectorAll(".atmosphere .orb");
  if (orbs.length && !reduce) {
    let ticking = false;
    window.addEventListener(
      "scroll",
      () => {
        if (ticking) return;
        ticking = true;
        requestAnimationFrame(() => {
          const y = window.scrollY * 0.045;
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
