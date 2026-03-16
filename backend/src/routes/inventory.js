const router = require('express').Router();
const pool   = require('../db');

// ---- Sesiones de inventario ----

// GET /api/inventory/sessions
router.get('/sessions', async (_req, res, next) => {
  try {
    const { rows } = await pool.query('SELECT * FROM inventory_sessions ORDER BY created_at DESC');
    res.json(rows);
  } catch (err) { next(err); }
});

// GET /api/inventory/sessions/:id
router.get('/sessions/:id', async (req, res, next) => {
  try {
    const { rows } = await pool.query('SELECT * FROM inventory_sessions WHERE id = $1', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Sesion no encontrada' });

    const { rows: baseline } = await pool.query(
      'SELECT * FROM inventory_session_baseline WHERE session_id = $1',
      [req.params.id]
    );
    const { rows: verifications } = await pool.query(
      'SELECT * FROM inventory_verifications WHERE session_id = $1 ORDER BY timestamp',
      [req.params.id]
    );
    res.json({ ...rows[0], baseline, verifications });
  } catch (err) { next(err); }
});

// POST /api/inventory/sessions
router.post('/sessions', async (req, res, next) => {
  const { id, name, site, building, floor, area, baseline } = req.body;
  if (!id || !name || !site) {
    return res.status(400).json({ error: 'Faltan campos requeridos: id, name, site' });
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `INSERT INTO inventory_sessions (id, name, site, building, floor, area)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [id, name, site, building ?? '', floor ?? '', area ?? '']
    );
    if (Array.isArray(baseline) && baseline.length) {
      for (const b of baseline) {
        await client.query(
          `INSERT INTO inventory_session_baseline (session_id, asset_code, baseline_state)
           VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
          [id, b.asset_code, b.baseline_state]
        );
      }
    }
    await client.query('COMMIT');
    res.status(201).json(rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

// ---- Verificaciones ----

// POST /api/inventory/sessions/:id/verifications
router.post('/sessions/:id/verifications', async (req, res, next) => {
  const { asset_code, result, notes, photo_path } = req.body;
  if (!asset_code || !result) {
    return res.status(400).json({ error: 'Faltan campos: asset_code, result' });
  }
  try {
    const { rows } = await pool.query(
      `INSERT INTO inventory_verifications (session_id, asset_code, result, notes, photo_path)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [req.params.id, asset_code, result, notes ?? '', photo_path]
    );
    res.status(201).json(rows[0]);
  } catch (err) { next(err); }
});

module.exports = router;
