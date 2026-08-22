import { defineConfig } from 'vite';
import { cpSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

function copyStaticFiles() {
  return {
    name: 'copy-static-files',
    closeBundle() {
      // These files are served directly rather than imported by the Vite HTML
      // entry points. Copy them into the deployment output so Vercel can serve
      // the dashboard redirect and the dashboard page it targets.
      const files = ['site.js', 'uploads', 'dashboard', 'task-dashboard'];

      for (const file of files) {
        const source = resolve(file);
        const destination = resolve('dist', file);

        if (existsSync(source)) {
          cpSync(source, destination, {
            recursive: true,
            filter: (path) => !path.endsWith('/.git') && !path.endsWith('/.DS_Store'),
          });
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
