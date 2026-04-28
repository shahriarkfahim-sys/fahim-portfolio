// Shrink header on scroll
window.addEventListener('scroll', function () {
  document.querySelector('header').classList.toggle('scrolled', window.scrollY > 40);
});
