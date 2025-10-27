/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        hyundai: {
          blue: '#002C5F',
          lightblue: '#00AAD2',
          gray: '#58595B',
        },
      },
    },
  },
  plugins: [],
}
