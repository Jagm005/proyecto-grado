-- =============================================================
-- Schema inicial: Sistema de Gestión de Inventario Institucional
-- =============================================================

CREATE TYPE user_role AS ENUM (
  'auxiliarInventario',
  'administrador',
  'responsableArea',
  'direccionAdminFin',
  'auditor',
  'soporteTI'
);

CREATE TABLE users (
  id              VARCHAR(20)   PRIMARY KEY,
  username        VARCHAR(100)  UNIQUE NOT NULL,
  full_name       VARCHAR(200)  NOT NULL,
  email           VARCHAR(200)  UNIQUE NOT NULL,
  password_hash   VARCHAR(255)  NOT NULL,
  roles           user_role[]   NOT NULL DEFAULT '{}',
  is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
  last_session    TIMESTAMPTZ,
  failed_attempts INT           NOT NULL DEFAULT 0,
  lock_until      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------

CREATE TYPE asset_state AS ENUM (
  'activo',
  'reubicado',
  'noEncontrado',
  'obsoleto',
  'enReparacion',
  'paraBaja'
);

CREATE TABLE assets (
  code                        VARCHAR(50)    PRIMARY KEY,
  name                        VARCHAR(200)   NOT NULL,
  category                    VARCHAR(100)   NOT NULL,
  subcategory                 VARCHAR(100)   NOT NULL,
  physical_location           VARCHAR(200)   NOT NULL,
  responsible                 VARCHAR(200)   NOT NULL,
  dependency                  VARCHAR(200)   NOT NULL,
  cost_center                 VARCHAR(100)   NOT NULL,
  acquisition_value           NUMERIC(15,2)  NOT NULL,
  acquisition_date            DATE           NOT NULL,
  estimated_useful_life_years INT            NOT NULL,
  state                       asset_state    NOT NULL DEFAULT 'activo',
  observations                TEXT,
  program                     VARCHAR(200)   NOT NULL,
  photo_path                  VARCHAR(500),
  created_at                  TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE TABLE asset_history (
  id           SERIAL       PRIMARY KEY,
  asset_code   VARCHAR(50)  NOT NULL REFERENCES assets(code) ON DELETE CASCADE,
  timestamp    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  action       VARCHAR(100) NOT NULL,
  detail       TEXT         NOT NULL,
  performed_by VARCHAR(200) NOT NULL
);

-- ---------------------------------------------------------------

CREATE TABLE inventory_sessions (
  id         VARCHAR(50)  PRIMARY KEY,
  name       VARCHAR(200) NOT NULL,
  site       VARCHAR(200) NOT NULL,
  building   VARCHAR(200) NOT NULL,
  floor      VARCHAR(100) NOT NULL,
  area       VARCHAR(200) NOT NULL,
  created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE inventory_session_baseline (
  session_id     VARCHAR(50) NOT NULL REFERENCES inventory_sessions(id) ON DELETE CASCADE,
  asset_code     VARCHAR(50) NOT NULL REFERENCES assets(code) ON DELETE CASCADE,
  baseline_state asset_state NOT NULL,
  PRIMARY KEY (session_id, asset_code)
);

CREATE TYPE verification_result AS ENUM (
  'encontrado',
  'reubicado',
  'noEncontrado',
  'paraBaja',
  'obsoleto',
  'enReparacion'
);

CREATE TABLE inventory_verifications (
  id          SERIAL               PRIMARY KEY,
  session_id  VARCHAR(50)          NOT NULL REFERENCES inventory_sessions(id) ON DELETE CASCADE,
  asset_code  VARCHAR(50)          NOT NULL,
  result      verification_result  NOT NULL,
  notes       TEXT,
  timestamp   TIMESTAMPTZ          NOT NULL DEFAULT NOW(),
  photo_path  VARCHAR(500)
);

-- ---------------------------------------------------------------

CREATE TYPE maintenance_type AS ENUM ('preventivo', 'correctivo');

CREATE TABLE maintenance_requests (
  id          VARCHAR(50)       PRIMARY KEY,
  asset_code  VARCHAR(50)       NOT NULL REFERENCES assets(code) ON DELETE CASCADE,
  type        maintenance_type  NOT NULL,
  description TEXT              NOT NULL,
  created_by  VARCHAR(200)      NOT NULL,
  created_at  TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  closed      BOOLEAN           NOT NULL DEFAULT FALSE
);

-- ---------------------------------------------------------------

CREATE TABLE disposal_requests (
  id                      VARCHAR(50)  PRIMARY KEY,
  asset_code              VARCHAR(50)  NOT NULL REFERENCES assets(code) ON DELETE CASCADE,
  cause                   VARCHAR(200) NOT NULL,
  justification           TEXT         NOT NULL,
  created_by              VARCHAR(200) NOT NULL,
  created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  approved_by_dependency  BOOLEAN      NOT NULL DEFAULT FALSE,
  approved_by_daf         BOOLEAN      NOT NULL DEFAULT FALSE
);

-- ---------------------------------------------------------------
-- Trigger: actualizar updated_at en assets automáticamente
-- ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER assets_updated_at
  BEFORE UPDATE ON assets
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
