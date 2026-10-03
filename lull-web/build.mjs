import * as esbuild from "esbuild";
await esbuild.build({
  entryPoints: ["src/entry.jsx"],
  bundle: true,
  minify: true,
  format: "iife",
  target: ["es2019", "safari13"],
  loader: { ".jsx": "jsx" },
  define: { "process.env.NODE_ENV": '"production"' },
  jsx: "automatic",
  outfile: "public/assets/lull.js",
  legalComments: "none",
});
console.log("bundled -> public/assets/lull.js");
