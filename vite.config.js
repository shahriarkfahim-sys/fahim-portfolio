import { defineConfig } from 'vite';
import { cpSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

function copyStaticFiles() {
  return {
    name: 'copy-static-files',
    closeBundle() {
      const files = ['site.js', 'uploads'];

      for (const file of files) {
        const source = resolve(file);
        const destination = resolve('dist', file);

        if (existsSync(source)) {
          cpSync(source, destination, { recursive: true });
        }
      }
    },
  };
}

export default defineConfig({
  plugins: [copyStaticFiles()],
  build: {
    rollupOptions: {
      input: {
        main: 'index.html',
        blog: 'blog.html',
        publications: 'publications.html',
        biography: 'biography.html',
        explore: 'explore.html',
        'volunteer-projects': 'volunteer-projects.html',
        'honours-awards': 'honours-awards.html',
      },
    },
  },
});
