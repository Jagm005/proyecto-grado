const express = require('express');
const helmet  = require('helmet');
const cors    = require('cors');
require('dotenv').config();

const authRouter       = require('./routes/auth');
const usersRouter      = require('./routes/users');
const assetsRouter     = require('./routes/assets');
const inventoryRouter  = require('./routes/inventory');
const maintenanceRouter= require('./routes/maintenance');
const disposalRouter   = require('./routes/disposal');
const requireAuth      = require('./middleware/auth');

const pool = require('./db');
const app  = express();
const PORT = process.env.PORT || 3000;

// Migración automática: añadir columna photo_base64 si no existe
pool.query(
  `ALTER TABLE assets ADD COLUMN IF NOT EXISTS photo_base64 TEXT`,
).catch((err) => console.error('Migration photo_base64 failed:', err.message));

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '15mb' }));
app.use(express.urlencoded({ extended: true, limit: '15mb' }));

// ---- Health check ----
app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// ---- Rutas ----
app.use('/api/auth',         authRouter);                    // rutas públicas
app.use('/api/users',        requireAuth, usersRouter);
app.use('/api/assets',       requireAuth, assetsRouter);
app.use('/api/inventory',    requireAuth, inventoryRouter);
app.use('/api/maintenance',  requireAuth, maintenanceRouter);
app.use('/api/disposal',     requireAuth, disposalRouter);

// ---- Manejo de errores global ----
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Error interno del servidor' });
});

app.listen(PORT, () => {
  console.log(`Backend corriendo en http://localhost:${PORT}`);
});
