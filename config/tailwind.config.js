const defaultTheme = require("tailwindcss/defaultTheme")

module.exports = {
  darkMode: "class",
  content: [
    "./app/views/**/*.{html,erb}",
    "./app/helpers/**/*.rb",
    "./app/javascript/**/*.js",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ["Inter var", ...defaultTheme.fontFamily.sans],
        serif: ["Georgia", ...defaultTheme.fontFamily.serif],
      },
      typography: (theme) => ({
        zinc: {
          css: {
            "--tw-prose-body":        theme("colors.zinc[700]"),
            "--tw-prose-headings":    theme("colors.zinc[900]"),
            "--tw-prose-invert-body": theme("colors.zinc[300]"),
            "--tw-prose-invert-headings": theme("colors.zinc[100]"),
          },
        },
      }),
    },
  },
  plugins: [
    require("@tailwindcss/typography"),
  ],
}
