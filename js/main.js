/* Tiny Bird, Big Dreams — Main JS */

// ── Dark mode ──
(function () {
  const stored = localStorage.getItem('theme');
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  const theme = stored || (prefersDark ? 'dark' : 'light');
  document.documentElement.setAttribute('data-theme', theme);

  document.addEventListener('DOMContentLoaded', () => {
    const toggle = document.getElementById('themeToggle');
    if (!toggle) return;
    toggle.addEventListener('click', () => {
      const next = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
      localStorage.setItem('theme', next);
    });
  });
})();

// ── Nav scroll shadow ──
const nav = document.getElementById('nav');
if (nav) {
  window.addEventListener('scroll', () => {
    nav.classList.toggle('scrolled', window.scrollY > 10);
  }, { passive: true });
}

// ── Mobile nav burger ──
const burger = document.getElementById('navBurger');
const navLinks = document.getElementById('navLinks');
if (burger && navLinks) {
  burger.addEventListener('click', () => {
    const isOpen = navLinks.classList.toggle('open');
    burger.setAttribute('aria-expanded', isOpen);
  });
  navLinks.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => {
      navLinks.classList.remove('open');
      burger.setAttribute('aria-expanded', false);
    });
  });
}

// ── Email sign-up (demo) ──
const emailForm = document.getElementById('emailForm');
const emailSuccess = document.getElementById('emailSuccess');
if (emailForm && emailSuccess) {
  emailForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const input = document.getElementById('emailInput');
    if (!input.value || !input.checkValidity()) {
      input.focus();
      return;
    }
    emailForm.querySelector('.email-form__group').style.display = 'none';
    emailForm.querySelector('.email-form__note').style.display = 'none';
    emailSuccess.hidden = false;
  });
}

// ── Scroll-reveal (lightweight, no dependencies) ──
const revealElements = document.querySelectorAll(
  '.product-card, .step, .transparency-card, .community-card'
);
if ('IntersectionObserver' in window && revealElements.length) {
  revealElements.forEach(el => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(24px)';
    el.style.transition = 'opacity .5s ease, transform .5s ease';
  });

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.style.opacity = '1';
        entry.target.style.transform = 'translateY(0)';
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12 });

  revealElements.forEach(el => observer.observe(el));
}
