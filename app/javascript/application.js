import "@hotwired/turbo-rails"
import "controllers"
const cleanupBootstrapModalState = () => {
  document.querySelectorAll(".modal.show").forEach((modal) => {
    window.bootstrap?.Modal.getInstance(modal)?.hide();
  });

  if (document.querySelector(".modal.show")) return;

  document.querySelectorAll(".modal-backdrop").forEach((backdrop) => {
    backdrop.remove();
  });
  document.body.classList.remove("modal-open");
  document.body.style.removeProperty("overflow");
  document.body.style.removeProperty("padding-right");
};

document.addEventListener("hidden.bs.modal", cleanupBootstrapModalState);
document.addEventListener("turbo:before-cache", cleanupBootstrapModalState);
document.addEventListener("turbo:before-render", cleanupBootstrapModalState);
