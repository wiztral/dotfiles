/** @type {import("prettier").Config} */
export default {
  arrowParens: "always",
  printWidth: 80,
  semi: true,
  tabWidth: 2,
  endOfLine: "auto",
  singleQuote: false,
  jsxSingleQuote: false,
  trailingComma: "all",
  tailwindConfig: "./tailwind.config.js",
  tailwindFunctions: ["cva"],
  plugins: ["prettier-plugin-tailwindcss"],
};
