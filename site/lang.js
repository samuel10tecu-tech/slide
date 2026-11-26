// English / French switch. Defaults to the browser language, remembers the choice.
(function () {
  var root = document.documentElement;
  var saved = null;
  try { saved = localStorage.getItem("slide.lang"); } catch (e) {}
  var browser = (navigator.language || "en").toLowerCase().indexOf("fr") === 0 ? "fr" : "en";
  var query = new URLSearchParams(location.search).get("lang");
  set(query === "fr" || query === "en" ? query : saved || browser);

  function set(lang) {
    root.setAttribute("data-lang", lang);
    root.setAttribute("lang", lang);
    var buttons = document.querySelectorAll(".lang button");
    for (var i = 0; i < buttons.length; i++) {
      buttons[i].setAttribute("aria-pressed", String(buttons[i].dataset.set === lang));
    }
    var title = document.querySelector("title[data-" + lang + "]");
    if (title) document.title = title.getAttribute("data-" + lang);
  }

  document.addEventListener("click", function (event) {
    var button = event.target.closest(".lang button");
    if (!button) return;
    set(button.dataset.set);
    try { localStorage.setItem("slide.lang", button.dataset.set); } catch (e) {}
  });

  document.addEventListener("DOMContentLoaded", function () { set(root.getAttribute("data-lang")); });
})();
