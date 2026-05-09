const MEDIUM_RSS_URL = 'https://medium.com/feed/@shahriar.k.fahim';

module.exports = async function handler(_req, res) {
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

    res.setHeader('Cache-Control', 'no-store, max-age=0');
    res.setHeader('Content-Type', 'application/xml; charset=utf-8');
    res.status(200).send(await response.text());
  } catch (error) {
    res.status(502).json({ error: 'Unable to load Medium feed' });
  }
};
