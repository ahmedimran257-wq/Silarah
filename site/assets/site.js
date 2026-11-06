const menuButton = document.querySelector('.menu-toggle');
const menu = document.querySelector('.site-menu');
const header = document.querySelector('.site-header');

if (header) {
  const progress = document.createElement('span');
  progress.className = 'site-progress';
  progress.setAttribute('aria-hidden', 'true');
  header.append(progress);

  const updateHeader = () => {
    const scrollable = Math.max(1, document.documentElement.scrollHeight - innerHeight);
    header.classList.toggle('scrolled', scrollY > 24);
    progress.style.transform = `scaleX(${Math.min(1, scrollY / scrollable)})`;
  };

  let frame = 0;
  const scheduleHeader = () => {
    if (frame) return;
    frame = requestAnimationFrame(() => { frame = 0; updateHeader(); });
  };
  updateHeader();
  addEventListener('scroll', scheduleHeader, { passive: true });
  addEventListener('resize', scheduleHeader, { passive: true });
}

menuButton?.addEventListener('click', () => {
  const willOpen = menuButton.getAttribute('aria-expanded') !== 'true';
  menuButton.setAttribute('aria-expanded', String(willOpen));
  menu?.classList.toggle('open', willOpen);
});

menu?.querySelectorAll('a').forEach((link) => {
  link.addEventListener('click', () => {
    menuButton?.setAttribute('aria-expanded', 'false');
    menu.classList.remove('open');
  });
});

document.addEventListener('keydown', (event) => {
  if (event.key !== 'Escape' || menuButton?.getAttribute('aria-expanded') !== 'true') return;
  menuButton?.setAttribute('aria-expanded', 'false');
  menu?.classList.remove('open');
  menuButton?.focus();
});

const motionPreference = matchMedia('(prefers-reduced-motion: reduce)');
let revealObserver;
function configureMotion() {
  revealObserver?.disconnect();
  document.documentElement.classList.remove('motion-ready');
  if (motionPreference.matches || !('IntersectionObserver' in window)) return;
  document.documentElement.classList.add('motion-ready');
  const revealTargets = document.querySelectorAll(
    '.section-heading,.feature-card,.screen-card,.journey-grid article,.media-layout > *,.trust-card-grid article,.platform-card,.safety-link-grid > a,.knowledge-grid > a,.india-editorial,.india-map-card',
  );
  revealObserver = new IntersectionObserver((entries, observer) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('in-view');
      observer.unobserve(entry.target);
    });
  }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
  revealTargets.forEach((target) => {
    if (!target.classList.contains('in-view')) revealObserver.observe(target);
  });
}
configureMotion();
motionPreference.addEventListener('change', configureMotion);
