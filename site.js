// Shrink header on scroll
window.addEventListener('scroll', function () {
  document.querySelector('header').classList.toggle('scrolled', window.scrollY > 40);
});

const storyPhotos = document.querySelectorAll('.story-photo');

if (storyPhotos.length) {
  if ('IntersectionObserver' in window) {
    const photoObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          photoObserver.unobserve(entry.target);
        }
      });
    }, { threshold: 0.28, rootMargin: '0px 0px -8% 0px' });

    storyPhotos.forEach(function (photo, index) {
      photo.style.transitionDelay = `${Math.min(index * 90, 360)}ms`;
      photoObserver.observe(photo);
    });
  } else {
    storyPhotos.forEach(function (photo) {
      photo.classList.add('is-visible');
    });
  }
}
