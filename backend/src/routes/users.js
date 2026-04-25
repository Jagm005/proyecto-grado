const router = require('express').Router();
const pool   = require('../db');

// GET /api/users
router.get('/', async (_req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT id, username, full_name, email, roles, is_active, last_session, created_at FROM users ORDER BY created_at'
    );
    res.json(rows);
  } catch (err) { next(err); }
});

// GET /api/users/:id
router.get('/:id', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT id, username, full_name, email, roles, is_active, last_session, created_at FROM users WHERE id = $1',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Usuario no encontrado' });
    res.json(rows[0]);
  } catch (err) { next(err); }
});

// POST /api/users
// Acepta "password" (texto plano) y lo hashea con pgcrypto en el servidor.
router.post('/', async (req, res, next) => {
  const { id, username, full_name, email, password, roles, area } = req.body;
  if (!id || !username || !full_name || !email || !password) {
    return res.status(400).json({ error: 'Faltan campos requeridos' });
  }
  try {
    const { rows } = await pool.query(
      `INSERT INTO users (id, username, full_name, email, password_hash, roles, area)
       VALUES ($1, $2, $3, $4, crypt($5, gen_salt('bf')), $6::user_role[], $7)
       RETURNING id, username, full_name, email, roles, is_active, area`,
      [id, username, full_name, email, password, roles ?? [], area ?? '']
    );
    res.status(201).json(rows[0]);
  } catch (err) { next(err); }
});

// PATCH /api/users/:id
router.patch('/:id', async (req, res, next) => {
  const allowed = ['full_name', 'email', 'roles', 'is_active'];
  const fields  = Object.keys(req.body).filter((k) => allowed.includes(k));
  if (!fields.length) return res.status(400).json({ error: 'Nada que actualizar' });

  const sets   = fields.map((f, i) => `${f} = $${i + 2}`).join(', ');
  const values = fields.map((f) => req.body[f]);

  try {
    const { rows } = await pool.query(
      `UPDATE users SET ${sets} WHERE id = $1 RETURNING id, username, full_name, email, roles, is_active`,
      [req.params.id, ...values]
    );
    if (!rows.length) return res.status(404).json({ error: 'Usuario no encontrado' });
    res.json(rows[0]);
  } catch (err) { next(err); }
});

// DELETE /api/users/:id
router.delete('/:id', async (req, res, next) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM users WHERE id = $1', [req.params.id]);
    if (!rowCount) return res.status(404).json({ error: 'Usuario no encontrado' });
    res.status(204).end();
  } catch (err) { next(err); }
});

module.exports = router;
