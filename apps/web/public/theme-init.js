(() => {
  let theme = "dark";
  try {
    const savedTheme = localStorage.getItem("yalisp-theme");
    theme = savedTheme === "light" || savedTheme === "dark"
      ? savedTheme
      : window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
  } catch {
    theme = window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
  }

  document.documentElement.dataset.theme = theme;
  const themeColor = document.querySelector('meta[name="theme-color"]');
  if (themeColor) themeColor.content = theme === "dark" ? "#101310" : "#f0eeea";
})();
