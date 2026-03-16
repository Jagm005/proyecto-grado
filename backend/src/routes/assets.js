const router = require('express').Router();
const pool   = require('../db');

// GET /api/assets
router.get('/', async (req, res, next) => {
  try {
    const { state, dependency } = req.query;
    let query  = 'SELECT * FROM assets';
    const cond = [];
    const vals = [];
    if (state)      { cond.push(`state = $${vals.length + 1}`);      vals.push(state); }
    if (dependency) { cond.push(`dependency = $${vals.length + 1}`); vals.push(dependency); }
    if (cond.length) query += ' WHERE ' + cond.join(' AND ');
    query += ' ORDER BY code';
    const { rows } = await pool.query(query, vals);
    res.json(rows);
  } catch (err) { next(err); }
});

// GET /api/assets/:code
router.get('/:code', async (req, res, next) => {
  try {
    const { rows } = await pool.query('SELECT * FROM assets WHERE code = $1', [req.params.code]);
    if (!rows.length) return res.status(404).json({ error: 'Activo no encontrado' });

    const { rows: history } = await pool.query(
      'SELECT * FROM asset_history WHERE asset_code = $1 ORDER BY timestamp DESC',
      [req.params.code]
    );
    res.json({ ...rows[0], history });
  } catch (err) { next(err); }
});

// POST /api/assets
router.post('/', async (req, res, next) => {
  const {
    code, name, category, subcategory, physical_location, responsible,
    dependency, cost_center, acquisition_value, acquisition_date,
    estimated_useful_life_years, state, observations, program, photo_path,
  } = req.body;

  if (!code || !name || !category || !dependency) {
    return res.status(400).json({ error: 'Faltan campos requeridos' });
  }

  try {
    const { rows } = await pool.query(
      `INSERT INTO assets
         (code, name, category, subcategory, physical_location, responsible,
          dependency, cost_center, acquisition_value, acquisition_date,
          estimated_useful_life_years, state, observations, program, photo_path)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
       RETURNING *`,
      [
        code, name, category, subcategory ?? '', physical_location ?? '', responsible ?? '',
        dependency, cost_center ?? '', acquisition_value ?? 0, acquisition_date ?? new Date(),
        estimated_useful_life_years ?? 5, state ?? 'activo', observations ?? '', program ?? '', photo_path,
      ]
    );
    res.status(201).json(rows[0]);
  } catch (err) { next(err); }
});

// PATCH /api/assets/:code
router.patch('/:code', async (req, res, next) => {
  const allowed = [
    'name', 'category', 'subcategory', 'physical_location', 'responsible',
    'dependency', 'cost_center', 'acquisition_value', 'acquisition_date',
    'estimated_useful_life_years', 'state', 'observations', 'program', 'photo_path',
  ];
  const fields = Object.keys(req.body).filter((k) => allowed.includes(k));
  if (!fields.length) return res.status(400).json({ error: 'Nada que actualizar' });

  const sets   = fields.map((f, i) => `${f} = $${i + 2}`).join(', ');
  const values = fields.map((f) => req.body[f]);

  try {
    const { rows } = await pool.query(
      `UPDATE assets SET ${sets} WHERE code = $1 RETURNING *`,
      [req.params.code, ...values]
    );
    if (!rows.length) return res.status(404).json({ error: 'Activo no encontrado' });
    res.json(rows[0]);
  } catch (err) { next(err); }
});

// DELETE /api/assets/:code
router.delete('/:code', async (req, res, next) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM assets WHERE code = $1', [req.params.code]);
    if (!rowCount) return res.status(404).json({ error: 'Activo no encontrado' });
    res.status(204).end();
  } catch (err) { next(err); }
});

// POST /api/assets/:code/history
router.post('/:code/history', async (req, res, next) => {
  const { action, detail, performed_by } = req.body;
  if (!action || !detail || !performed_by) {
    return res.status(400).json({ error: 'Faltan campos: action, detail, performed_by' });
  }
  try {
    const { rows } = await pool.query(
      `INSERT INTO asset_history (asset_code, action, detail, performed_by)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [req.params.code, action, detail, performed_by]
    );
    res.status(201).json(rows[0]);
  } catch (err) { next(err); }
});

module.exports = router;
