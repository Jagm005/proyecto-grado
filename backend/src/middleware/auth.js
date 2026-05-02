const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  console.error('FATAL: JWT_SECRET env var no definida. Defínela en .env o en las variables de entorno del servidor.');
  process.exit(1);
}

/**
 * Middleware que verifica el token JWT en el header Authorization.
 * Adjunta el payload decodificado en req.user.
 */
function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token  = header.startsWith('Bearer ') ? header.slice(7) : null;

  if (!token) {
    return res.status(401).json({ error: 'No autenticado. Token requerido.' });
  }

  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch (err) {
    const message = err.name === 'TokenExpiredError'
      ? 'Sesión expirada. Inicie sesión nuevamente.'
      : 'Token inválido.';
    return res.status(401).json({ error: message, code: 'TOKEN_EXPIRED' });
  }
}

module.exports = requireAuth;
