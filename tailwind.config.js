/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./index.html"],
  theme: {
    extend: {
      colors: {
        phenix: {
          blue: "#0D4484",
          "blue-dark": "#08305F",
          "blue-light": "#E5EDF6",
          yellow: "#F2AC10",
          "yellow-light": "#FDF1D6",
        },
      },
    },
  },
  plugins: [],
};
