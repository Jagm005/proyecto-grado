const router = require('express').Router();
const pool   = require('../db');

const MAX_FAILED_ATTEMPTS = 5;
const LOCK_MINUTES        = 1;

// POST /api/auth/login
router.post('/login', async (req, res, next) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ error: 'Faltan campos requeridos' });
  }

  try {
    const { rows } = await pool.query(
      `SELECT id, username, full_name, email, roles, is_active, area,
              failed_attempts, lock_until, last_session,
              (password_hash = crypt($2, password_hash)) AS password_ok
       FROM users
       WHERE lower(username) = lower($1)`,
      [username.trim(), password],
    );

    if (!rows.length) {
      return res.status(401).json({ code: 'INFO', message: 'Usuario no encontrado' });
    }

    const user = rows[0];

    if (!user.is_active) {
      return res.status(403).json({ code: 'INFO', message: 'Usuario desactivado. Contacte al Administrador' });
    }

    if (user.lock_until && new Date(user.lock_until) > new Date()) {
      const seconds = Math.ceil((new Date(user.lock_until) - Date.now()) / 1000);
      return res.status(403).json({ code: 'LOCK', seconds });
    }

    if (!user.password_ok) {
      const newFailed = (user.failed_attempts ?? 0) + 1;

      if (newFailed >= MAX_FAILED_ATTEMPTS) {
        const lockUntil = new Date(Date.now() + LOCK_MINUTES * 60 * 1000);
        await pool.query(
          `UPDATE users SET failed_attempts = 0, lock_until = $2
           WHERE lower(username) = lower($1)`,
          [username.trim(), lockUntil],
        );
        return res.status(401).json({ code: 'LOCK', seconds: LOCK_MINUTES * 60 });
      }

      await pool.query(
        `UPDATE users SET failed_attempts = $2 WHERE lower(username) = lower($1)`,
        [username.trim(), newFailed],
      );
      return res.status(401).json({ code: 'WARN', remaining: MAX_FAILED_ATTEMPTS - newFailed });
    }

    // Credenciales correctas: reiniciar contadores y registrar sesión
    await pool.query(
      `UPDATE users SET failed_attempts = 0, lock_until = NULL, last_session = NOW()
       WHERE lower(username) = lower($1)`,
      [username.trim()],
    );

    return res.json({
      id:        user.id,
      username:  user.username,
      fullName:  user.full_name,
      email:     user.email,
      roles:     Array.isArray(user.roles)
                   ? user.roles
                   : String(user.roles).replace(/^{|}$/g, '').split(',').filter(Boolean),
      area:      user.area ?? '',
      isActive:  user.is_active,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
