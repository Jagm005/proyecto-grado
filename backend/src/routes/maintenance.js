const router = require('express').Router();
const pool   = require('../db');

// GET /api/maintenance
router.get('/', async (req, res, next) => {
  try {
    const { asset_code, closed } = req.query;
    let query  = 'SELECT * FROM maintenance_requests';
    const cond = [];
    const vals = [];
    if (asset_code !== undefined) { cond.push(`asset_code = $${vals.length + 1}`); vals.push(asset_code); }
    if (closed    !== undefined) { cond.push(`closed = $${vals.length + 1}`);      vals.push(closed === 'true'); }
    if (cond.length) query += ' WHERE ' + cond.join(' AND ');
    query += ' ORDER BY created_at DESC';
    const { rows } = await pool.query(query, vals);
    res.json(rows);
  } catch (err) { next(err); }
});

// GET /api/maintenance/:id
router.get('/:id', async (req, res, next) => {
  try {
    const { rows } = await pool.query('SELECT * FROM maintenance_requests WHERE id = $1', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Solicitud no encontrada' });
    res.json(rows[0]);
  } catch (err) { next(err); }
});

// POST /api/maintenance
router.post('/', async (req, res, next) => {
  const { id, asset_code, type, description, created_by } = req.body;
  if (!id || !asset_code || !type || !description || !created_by) {
    return res.status(400).json({ error: 'Faltan campos requeridos' });
  }
  try {
    const { rows } = await pool.query(
      `INSERT INTO maintenance_requests (id, asset_code, type, description, created_by)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [id, asset_code, type, description, created_by]
    );
    res.status(201).json(rows[0]);
  } catch (err) { next(err); }
});

// PATCH /api/maintenance/:id/close
router.patch('/:id/close', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'UPDATE maintenance_requests SET closed = TRUE WHERE id = $1 RETURNING *',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Solicitud no encontrada' });
    res.json(rows[0]);
  } catch (err) { next(err); }
});

module.exports = router;
