const router = require('express').Router();
const pool   = require('../db');

// GET /api/disposal
router.get('/', async (req, res, next) => {
  try {
    const { asset_code } = req.query;
    let query  = 'SELECT * FROM disposal_requests';
    const vals = [];
    if (asset_code) { query += ' WHERE asset_code = $1'; vals.push(asset_code); }
    query += ' ORDER BY created_at DESC';
    const { rows } = await pool.query(query, vals);
    res.json(rows);
  } catch (err) { next(err); }
});

// GET /api/disposal/:id
router.get('/:id', async (req, res, next) => {
  try {
    const { rows } = await pool.query('SELECT * FROM disposal_requests WHERE id = $1', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Solicitud no encontrada' });
    res.json(rows[0]);
  } catch (err) { next(err); }
});

// POST /api/disposal
router.post('/', async (req, res, next) => {
  const { id, asset_code, cause, justification, created_by } = req.body;
  if (!id || !asset_code || !cause || !justification || !created_by) {
    return res.status(400).json({ error: 'Faltan campos requeridos' });
  }
  try {
    const { rows } = await pool.query(
      `INSERT INTO disposal_requests (id, asset_code, cause, justification, created_by)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [id, asset_code, cause, justification, created_by]
    );
    res.status(201).json(rows[0]);
  } catch (err) { next(err); }
});

// PATCH /api/disposal/:id/approve
// body: { by: "dependency" | "daf" }
router.patch('/:id/approve', async (req, res, next) => {
  const { by } = req.body;
  const column = by === 'daf' ? 'approved_by_daf' : 'approved_by_dependency';
  try {
    const { rows } = await pool.query(
      `UPDATE disposal_requests SET ${column} = TRUE WHERE id = $1 RETURNING *`,
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Solicitud no encontrada' });
    res.json(rows[0]);
  } catch (err) { next(err); }
});

module.exports = router;
