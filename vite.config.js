import { defineConfig } from 'vite';
import { cpSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

function copyStaticFiles() {
  return {
    name: 'copy-static-files',
    closeBundle() {
      // These files are served directly rather than imported by the Vite HTML
      // entry points, so they need to be included in the deployment output.
      const files = ['site.js', 'auth.js', 'login.html', 'uploads', 'assets/photos'];

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

      // Vercel's clean URLs cannot reliably serve the dashboard's original
      // filename because it contains a space. Publish it as a root-level HTML
      // page, matching the other pages handled by vercel.json.
      const dashboardSource = resolve('task-dashboard', 'Task Dashboard.html');
      const dashboardDestination = resolve('dist', 'dashboard.html');

      if (existsSync(dashboardSource)) {
        cpSync(dashboardSource, dashboardDestination);
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
        dashboard: 'dashboard.html',
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
