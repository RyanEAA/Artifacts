/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,jsx}"],
  theme: {
    extend: {
      colors: {
        background: "#0f172a",   // dark slate / near-black
        surface: "#1e293b",      // card surface
        border: "#334155",       // subtle border

        navy: "#020617",         // deep navy
        navyLight: "#020617",

        textPrimary: "#ffffff",
        textSecondary: "#cbd5f5",
      },
    },
  },
  plugins: [],
};
