const express = require('express');
const helmet  = require('helmet');
const cors    = require('cors');

const usersRouter      = require('./routes/users');
const assetsRouter     = require('./routes/assets');
const inventoryRouter  = require('./routes/inventory');
const maintenanceRouter= require('./routes/maintenance');
const disposalRouter   = require('./routes/disposal');

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(helmet());
app.use(cors());
app.use(express.json());

// ---- Health check ----
app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// ---- Rutas ----
app.use('/api/users',        usersRouter);
app.use('/api/assets',       assetsRouter);
app.use('/api/inventory',    inventoryRouter);
app.use('/api/maintenance',  maintenanceRouter);
app.use('/api/disposal',     disposalRouter);

// ---- Manejo de errores global ----
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Error interno del servidor' });
});

app.listen(PORT, () => {
  console.log(`Backend corriendo en http://localhost:${PORT}`);
});
