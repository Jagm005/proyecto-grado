const router = require('express').Router();
const jwt    = require('jsonwebtoken');
const pool   = require('../db');

const JWT_SECRET  = process.env.JWT_SECRET;
const JWT_EXPIRES = process.env.JWT_EXPIRES_IN || '8h';

const MAX_FAILED_ATTEMPTS = 5;
const LOCK_MINUTES        = 1;

// POST /api/auth/login — acepta username O correo en el campo "identifier"
router.post('/login', async (req, res, next) => {
  // Compatibilidad: el campo puede venir como "identifier" o "username"
  const identifier = ((req.body.identifier || req.body.username) ?? '').trim();
  const { password } = req.body;
  if (!identifier || !password) {
    return res.status(400).json({ error: 'Faltan campos requeridos' });
  }

  try {
    const { rows } = await pool.query(
      `SELECT id, username, full_name, email, roles, is_active, area,
              failed_attempts, lock_until, last_session,
              (password_hash = crypt($2, password_hash)) AS password_ok
       FROM users
       WHERE lower(username) = lower($1) OR lower(email) = lower($1)`,
      [identifier, password],
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
          `UPDATE users SET failed_attempts = 0, lock_until = $2 WHERE id = $1`,
          [user.id, lockUntil],
        );
        return res.status(401).json({ code: 'LOCK', seconds: LOCK_MINUTES * 60 });
      }

      await pool.query(
        `UPDATE users SET failed_attempts = $2 WHERE id = $1`,
        [user.id, newFailed],
      );
      return res.status(401).json({ code: 'WARN', remaining: MAX_FAILED_ATTEMPTS - newFailed });
    }

    // Credenciales correctas: reiniciar contadores y registrar sesión
    await pool.query(
      `UPDATE users SET failed_attempts = 0, lock_until = NULL, last_session = NOW() WHERE id = $1`,
      [user.id],
    );

    const roles = Array.isArray(user.roles)
      ? user.roles
      : String(user.roles).replace(/^{|}$/g, '').split(',').filter(Boolean);

    const payload = {
      id:       user.id,
      username: user.username,
      roles,
      area:     user.area ?? '',
    };

    const token = jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES });

    return res.json({
      token,
      user: {
        id:       user.id,
        username: user.username,
        fullName: user.full_name,
        email:    user.email,
        roles,
        area:     user.area ?? '',
        isActive: user.is_active,
      },
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/auth/google-login
// Recibe el correo verificado por Google; si existe en la BD deja pasar sin contraseña.
router.post('/google-login', async (req, res, next) => {
  const email = (req.body.email ?? '').trim();
  if (!email) {
    return res.status(400).json({ error: 'Falta el correo' });
  }

  try {
    const { rows } = await pool.query(
      `SELECT id, username, full_name, email, roles, is_active, area
       FROM users
       WHERE lower(email) = lower($1)`,
      [email],
    );

    if (!rows.length) {
      return res.status(401).json({
        code: 'INFO',
        message: 'No existe un usuario registrado con este correo de Google. Contacte al Administrador.',
      });
    }

    const user = rows[0];

    if (!user.is_active) {
      return res.status(403).json({ code: 'INFO', message: 'Usuario desactivado. Contacte al Administrador' });
    }

    await pool.query(
      `UPDATE users SET last_session = NOW() WHERE id = $1`,
      [user.id],
    );

    const roles = Array.isArray(user.roles)
      ? user.roles
      : String(user.roles).replace(/^{|}$/g, '').split(',').filter(Boolean);

    const payload = {
      id:       user.id,
      username: user.username,
      roles,
      area:     user.area ?? '',
    };

    const token = jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES });

    return res.json({
      token,
      user: {
        id:       user.id,
        username: user.username,
        fullName: user.full_name,
        email:    user.email,
        roles,
        area:     user.area ?? '',
        isActive: user.is_active,
      },
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
