const express = require('express');
const path = require('path');

const app = express();
const DEFAULT_PORT = process.env.PORT ? Number(process.env.PORT) : 3000;
const MEDIUM_RSS_URL = 'https://medium.com/feed/@shahriar.k.fahim';

app.get('/api/medium-feed', async (_req, res) => {
  try {
    const response = await fetch(`${MEDIUM_RSS_URL}?fresh=${Date.now()}`, {
      headers: {
        'User-Agent': 'Mozilla/5.0 fahim-portfolio medium-feed'
      }
    });

    if (!response.ok) {
      res.status(response.status).json({ error: 'Medium feed request failed' });
      return;
    }

    res.set('Cache-Control', 'no-store, max-age=0');
    res.type('application/xml').send(await response.text());
  } catch (error) {
    res.status(502).json({ error: 'Unable to load Medium feed' });
  }
});

app.use(express.static(path.join(__dirname)));

function startServer(port) {
  const server = app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
  });

  server.on('error', (error) => {
    if (error.code === 'EADDRINUSE') {
      console.error(`Port ${port} is already in use. Trying port ${port + 1}...`);
      startServer(port + 1);
    } else {
      throw error;
    }
  });
}

startServer(DEFAULT_PORT);
