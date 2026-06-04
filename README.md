# Sistema de Gestión de Inventario Institucional

Aplicación multiplataforma para la gestión, trazabilidad y control de activos fijos en entornos institucionales (universidades, entidades públicas, PYMES). Desarrollada como proyecto de grado.

---

## Tabla de Contenidos

1. [Descripción General](#1-descripción-general)
2. [Stack Tecnológico](#2-stack-tecnológico)
3. [Arquitectura](#3-arquitectura)
4. [Estructura del Repositorio](#4-estructura-del-repositorio)
5. [Módulos y Funcionalidades](#5-módulos-y-funcionalidades)
6. [Roles de Usuario](#6-roles-de-usuario)
7. [Base de Datos](#7-base-de-datos)
8. [API REST](#8-api-rest)
9. [Puesta en Marcha — Paso a Paso Completo](#9-puesta-en-marcha--paso-a-paso-completo)
10. [Usuarios de Prueba](#10-usuarios-de-prueba)
11. [Variables de Entorno](#11-variables-de-entorno)
12. [Seguridad](#12-seguridad)
13. [Flujos de Negocio Detallados](#13-flujos-de-negocio-detallados)

---

## 1. Descripción General

El sistema permite a diferentes perfiles de usuarios (auxiliares, administradores, auditores, directivos) gestionar el ciclo de vida completo de los activos institucionales:

- Registro y consulta del catálogo de activos con foto y código QR/barras.
- Tomas físicas de inventario por sitio, edificio, piso y área.
- Solicitudes de mantenimiento preventivo y correctivo con cierre de solicitud.
- Solicitudes de baja con flujo de aprobación multinivel (dependencia → DAF).
- Historial de auditoría inmutable por activo (quién, cuándo, qué cambió).
- Generación y exportación de reportes en PDF y Excel.
- Dashboard de estadísticas en tiempo real.
- Autenticación con usuario/contraseña o con Google Sign-In.
- Gestión completa de usuarios con RBAC (control de acceso basado en roles).
- Escaneo de códigos QR y de barras desde la cámara del dispositivo.

La aplicación funciona en **Android, iOS, Web, Windows, macOS y Linux** gracias a Flutter.

---

## 2. Stack Tecnológico

| Capa | Tecnología | Versión |
|---|---|---|
| **Frontend** | Flutter / Dart | SDK ^3.8.1 |
| **Backend** | Node.js + Express | Node 20-alpine / Express ^4.18.3 |
| **Base de datos** | PostgreSQL | 15-alpine |
| **Infraestructura** | Docker + Docker Compose | 3.9 |

### Dependencias Flutter (pubspec.yaml)

| Paquete | Versión | Uso |
|---|---|---|
| `http` | ^1.2.2 | Cliente REST hacia el backend |
| `mobile_scanner` | ^5.2.3 | Lectura de códigos QR y de barras con la cámara |
| `image_picker` | ^1.1.2 | Captura/selección de fotos de activos |
| `pdf` | ^3.11.1 | Generación de documentos PDF en el dispositivo |
| `printing` | ^5.13.1 | Vista previa e impresión/exportación de PDF |
| `path_provider` | ^2.1.4 | Acceso al sistema de archivos local |
| `excel` | ^4.0.6 | Exportación de datos a hojas de cálculo Excel (.xlsx) |
| `share_plus` | ^10.0.0 | Compartir archivos PDF y Excel desde la app |
| `google_fonts` | ^6.2.1 | Tipografía Libre Franklin |
| `shared_preferences` | ^2.3.3 | Persistencia local de sesión (token JWT) |
| `intl` | ^0.19.0 | Formato de fechas y números localizados |
| `postgres` | ^2.6.4 | Conexión directa opcional a PostgreSQL (no principal) |
| `google_sign_in` | ^6.2.1 | Autenticación con cuenta Google |

### Dependencias Node.js (backend/package.json)

| Paquete | Versión | Uso |
|---|---|---|
| `express` | ^4.18.3 | Framework HTTP / enrutamiento |
| `pg` (node-postgres) | ^8.11.5 | Pool de conexiones a PostgreSQL |
| `jsonwebtoken` | ^9.0.3 | Firma y verificación de tokens JWT |
| `helmet` | ^7.1.0 | Cabeceras de seguridad HTTP |
| `cors` | ^2.8.5 | Control de acceso Cross-Origin |
| `dotenv` | ^17.4.2 | Carga de variables de entorno desde `.env` |
| `nodemon` | ^3.1.0 | Reinicio automático en desarrollo (devDependency) |

---

## 3. Arquitectura

El proyecto sigue una **Arquitectura por Capas (N-Tier / Layered Architecture)**:

```
┌─────────────────────────────────────────────────────┐
│         CAPA DE PRESENTACIÓN (Flutter)              │
│   Widgets · AppState (ChangeNotifier) · http client │
│   SplashScreen · LoginPage · HomePage               │
│   Pages: Dashboard · Assets · Inventory             │
│          Maintenance · Disposal · Users · Reports   │
│          Integration                                │
├─────────────────────────────────────────────────────┤
│         CAPA DE API / CONTROLADORES (Express)       │
│   Routes: auth · users · assets · inventory         │
│           maintenance · disposal                    │
│   Middlewares: helmet · cors · express.json          │
│   Auth Middleware: JWT Bearer verification           │
│   Global error handler                              │
├─────────────────────────────────────────────────────┤
│         CAPA DE ACCESO A DATOS (db.js)              │
│   PostgreSQL Connection Pool (node-postgres)        │
│   Parámetros SQL parametrizados (sin interpolación) │
├─────────────────────────────────────────────────────┤
│         CAPA DE DATOS (PostgreSQL 15)               │
│   Tablas · ENUMs · Triggers · Transacciones         │
│   pgcrypto (bcrypt para contraseñas)                │
└─────────────────────────────────────────────────────┘
```

La comunicación es estrictamente vertical: **Flutter → Express (HTTP/REST JSON) → PostgreSQL (SQL parametrizado)**. No existe comunicación directa entre Flutter y PostgreSQL en producción.

Para la arquitectura detallada con diagramas Mermaid, ver [ARQUITECTURA.md](ARQUITECTURA.md).

---

## 4. Estructura del Repositorio

```
proyecto-grado/
├── lib/
│   └── main.dart                  # Toda la lógica de UI y estado (Flutter, ~único archivo)
├── assets/
│   └── isologo-ucp.png            # Logo de la institución (splash screen e ícono)
├── backend/
│   ├── Dockerfile                 # Imagen Node 20-alpine, expone puerto 3000
│   ├── package.json               # Dependencias y scripts npm
│   └── src/
│       ├── index.js               # Punto de entrada Express; middlewares; rutas; migración automática
│       ├── db.js                  # Pool de conexiones PostgreSQL (node-postgres)
│       ├── middleware/
│       │   └── auth.js            # Middleware JWT: verifica Bearer token en cada request protegida
│       └── routes/
│           ├── auth.js            # POST /login, POST /google-login
│           ├── users.js           # CRUD completo de usuarios + cambio de contraseña
│           ├── assets.js          # CRUD de activos + historial de auditoría
│           ├── inventory.js       # Sesiones de inventario + baseline + verificaciones
│           ├── maintenance.js     # CRUD solicitudes de mantenimiento + cierre
│           └── disposal.js        # CRUD solicitudes de baja + aprobación
├── docker/
│   └── init.sql                   # DDL completo + datos demo iniciales (ejecutado al crear el contenedor DB)
├── docker-compose.yml             # Orquesta inventario_db (PostgreSQL) e inventario_backend (Express)
├── pubspec.yaml                   # Dependencias y configuración del proyecto Flutter
├── analysis_options.yaml          # Reglas de análisis estático Dart
└── ARQUITECTURA.md                # Documentación técnica ampliada con diagramas
```

---

## 5. Módulos y Funcionalidades

### 5.1 Splash Screen (`SplashScreen`)

Al iniciar la aplicación se muestra el isologo de la institución mientras se carga el estado persistido (`SharedPreferences`). Si existe un token de sesión guardado, navega directamente a `HomePage`; de lo contrario redirige a `LoginPage`.

### 5.2 Autenticación (`LoginPage`)

**Inicio de sesión con usuario/contraseña:**
- El campo `identifier` acepta tanto el nombre de usuario como el correo electrónico.
- El backend busca el usuario por `username` o `email` (búsqueda insensible a mayúsculas).
- La contraseña se verifica usando `pgcrypto`: `crypt($password, password_hash)`.
- Si las credenciales son correctas, se emite un **JWT firmado** (`jsonwebtoken`) con expiración de 8 horas. El payload contiene `{ id, username, roles, area }`.
- El token se persiste localmente con `SharedPreferences` y se adjunta en cada request como cabecera `Authorization: Bearer <token>`.

**Bloqueo de cuenta:**
- Tras **5 intentos fallidos** consecutivos, la cuenta se bloquea por **1 minuto** (`lock_until`).
- La API responde con `{ code: "LOCK", seconds: N }` y la app muestra una cuenta regresiva.
- Con 1 a 4 intentos fallidos responde `{ code: "WARN", remaining: N }` indicando los intentos restantes.

**Google Sign-In:**
- La app usa `google_sign_in` para obtener el correo verificado por Google.
- Se envía al endpoint `POST /api/auth/google-login`. El backend verifica que exista un usuario con ese correo en la base de datos.
- No se requiere contraseña; el JWT se genera de la misma forma.
- Si el correo no está registrado, se rechaza el acceso.

**Cierre de sesión:**
- Elimina el token de `SharedPreferences` y navega a `LoginPage`.

### 5.3 Pantalla Principal (`HomePage`)

- Contiene una `NavigationBar` (Material 3) con accesos directos a todos los módulos.
- Los ítems de navegación visibles se filtran según los roles del usuario autenticado:
  - `auxiliarInventario` / `administrador` / `soporteTI`: ven todos los módulos.
  - `responsableArea`: sin acceso a Usuarios.
  - `auditor`: solo lectura en Activos, Inventario, Mantenimiento y Bajas.
  - `direccionAdminFin`: Bajas, Reportes y Dashboard.

### 5.4 Dashboard (`DashboardPage`)

- Consulta en tiempo real el conteo de activos agrupados por estado (`activo`, `reubicado`, `noEncontrado`, `obsoleto`, `enReparacion`, `paraBaja`).
- Muestra el número de solicitudes de mantenimiento abiertas y cerradas.
- Muestra el número de solicitudes de baja pendientes de aprobación por dependencia y por DAF.
- Tarjetas con valores numéricos y acceso rápido a cada módulo.

### 5.5 Gestión de Activos (`AssetsPage`)

**Listado y búsqueda:**
- Lista paginada del catálogo completo de activos.
- Filtrado por estado (`asset_state`) y por dependencia.
- Búsqueda por texto en nombre, código, categoría, subcategoría y ubicación física.

**Registro de activo:**
Cada activo tiene los siguientes campos:

| Campo | Tipo | Descripción |
|---|---|---|
| `code` | VARCHAR(50) PK | Código único del activo (ej. INV-2024-001) |
| `name` | VARCHAR(200) | Nombre descriptivo del activo |
| `category` | VARCHAR(100) | Categoría general (Mobiliario, Equipo de cómputo, etc.) |
| `subcategory` | VARCHAR(100) | Subcategoría específica |
| `physical_location` | VARCHAR(200) | Ubicación física exacta (edificio, piso, oficina) |
| `responsible` | VARCHAR(200) | Persona responsable del activo |
| `dependency` | VARCHAR(200) | Dependencia/área institucional propietaria |
| `cost_center` | VARCHAR(100) | Centro de costo contable |
| `acquisition_value` | NUMERIC(15,2) | Valor de adquisición en moneda local |
| `acquisition_date` | DATE | Fecha de adquisición |
| `estimated_useful_life_years` | INT | Vida útil estimada en años |
| `state` | asset_state ENUM | Estado actual del activo |
| `observations` | TEXT | Observaciones adicionales |
| `program` | VARCHAR(200) | Programa académico o proyecto asociado |
| `photo_base64` | TEXT | Foto del activo codificada en Base64 |

**Escaneo QR/Barras:**
- Abre `MobileScannerController` (paquete `mobile_scanner`).
- Al detectar un código, busca el activo por ese código en el catálogo.
- Si existe, abre el detalle del activo directamente.

**Captura de foto:**
- Usa `ImagePicker` para seleccionar desde galería o capturar con cámara.
- La imagen se convierte a Base64 y se envía al backend en el campo `photo_base64`.
- Se muestra como `Image.memory(base64Decode(...))` en el detalle.

**Historial de auditoría:**
- Cada cambio relevante sobre un activo se registra en `asset_history`.
- Accesible desde el detalle del activo (`GET /api/assets/:code` devuelve el array `history`).
- Cada entrada contiene: `timestamp`, `action`, `detail`, `performed_by`.

### 5.6 Inventario Físico (`InventoryPage`)

**Creación de sesión:**
- Se define: nombre de sesión, sitio, edificio, piso y área.
- Al crear la sesión, se toma un **baseline**: snapshot del estado actual de todos los activos que pertenecen al área especificada. Se guarda en `inventory_session_baseline` con `session_id`, `asset_code` y `baseline_state`.
- Todo se persiste en una transacción atómica (`BEGIN / COMMIT / ROLLBACK`).

**Verificación activo a activo:**
- Se recorre la lista de activos del baseline.
- Para cada activo se registra un resultado en `inventory_verifications`:
  - `encontrado` — el activo está en su ubicación esperada.
  - `reubicado` — el activo fue encontrado pero en una ubicación diferente.
  - `noEncontrado` — el activo no pudo localizarse.
  - `paraBaja` — el activo se identificó para solicitar baja.
  - `obsoleto` — el activo está obsoleto.
  - `enReparacion` — el activo está en proceso de reparación.
- Se puede adjuntar foto y notas textuales por cada verificación.

**Visualización:**
- Lista de sesiones existentes con fecha y área.
- Detalle de sesión con progreso de verificación (cuántos activos verificados vs. total del baseline).

### 5.7 Mantenimiento (`MaintenancePage`)

- **Tipos:** `preventivo` (mantenimiento programado) o `correctivo` (falla o daño).
- Cada solicitud se vincula a un activo existente por `asset_code`.
- Campos: descripción detallada del problema o tarea, creado por (nombre del solicitante).
- **Cierre de solicitud:** `PATCH /api/maintenance/:id/close` establece `closed = TRUE`.
- Filtrado por activo y por estado (abiertas / cerradas).

### 5.8 Bajas (`DisposalPage`)

**Solicitud de baja:**
- Se selecciona el activo a dar de baja.
- Se indica la causa (obsolescencia, pérdida, daño irreparable, etc.) y una justificación textual detallada.

**Flujo de aprobación de dos niveles:**

```
Solicitud creada
       │
       ▼
Aprobación por Dependencia  (campo: approved_by_dependency)
       │
       ▼
Aprobación por DAF          (campo: approved_by_daf)
       │
       ▼
Baja completada
```

- `PATCH /api/disposal/:id/approve` con `{ "by": "dependency" }` o `{ "by": "daf" }`.
- Solo usuarios con rol `responsableArea` aprueban a nivel dependencia.
- Solo usuarios con rol `direccionAdminFin` aprueban a nivel DAF.

### 5.9 Gestión de Usuarios (`UsersPage`)

- Solo accesible para roles `administrador` y `soporteTI`.
- **Listado:** muestra todos los usuarios con nombre, correo, roles, área y estado (activo/inactivo).
- **Creación:** campos requeridos: ID, nombre de usuario, nombre completo, correo, contraseña, roles (múltiple selección), área. La contraseña se hashea con `bcrypt` vía `pgcrypto` en el servidor.
- **Edición:** permite modificar nombre completo, correo, roles y estado activo/inactivo.
- **Cambio de contraseña:** endpoint dedicado `PATCH /api/users/:id/password`. La nueva contraseña se hashea en el servidor.
- **Eliminación:** `DELETE /api/users/:id` (elimina el registro definitivamente).
- **Activación / Desactivación:** toggle de `is_active` vía `PATCH /api/users/:id`.

### 5.10 Reportes (`ReportsPage`)

- Genera reportes en **PDF** usando el paquete `pdf` con `printing` para previsualización.
- Genera hojas de cálculo en **Excel (.xlsx)** usando el paquete `excel`.
- Los archivos se pueden compartir directamente desde la app usando `share_plus`.
- Filtros disponibles: por estado del activo, por área/dependencia, por categoría.
- Períodos: mensual, semestral, anual.
- El PDF incluye encabezado institucional, tabla de activos con todos los campos relevantes y pie de página con fecha de generación.

### 5.11 Integraciones (`IntegrationPage`)

- Formulario para configurar la **URL base del backend** (por ejemplo `http://10.0.2.2:3000` para emulador Android, o la IP real del servidor en red local).
- Botón **"Probar conexión"** que realiza un `GET /health` y muestra el resultado.
- La URL se persiste en `SharedPreferences` para que no deba reingresarse en cada inicio.
- Útil en entornos donde la IP del servidor puede variar.

---

## 6. Roles de Usuario

| Rol | Descripción | Permisos clave |
|---|---|---|
| `auxiliarInventario` | Personal de almacén/inventario | Registra y actualiza activos; ejecuta tomas de inventario físico; crea solicitudes de mantenimiento |
| `administrador` | Administrador del sistema | Acceso total a todos los módulos; gestión completa de usuarios |
| `responsableArea` | Jefe de dependencia o área | Consulta activos de su área; aprueba solicitudes de baja a nivel dependencia |
| `direccionAdminFin` | Director Administrativo y Financiero | Aprueba solicitudes de baja (segundo nivel); acceso a reportes ejecutivos |
| `auditor` | Auditor institucional | Solo lectura en activos, inventario, mantenimiento y bajas (trazabilidad) |
| `soporteTI` | Soporte tecnológico | Gestión de usuarios y configuración del sistema |

Un usuario puede tener **múltiples roles simultáneamente** (almacenados como array de ENUMs en PostgreSQL: `user_role[]`).

---

## 7. Base de Datos

### 7.1 Extensiones PostgreSQL

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- Habilita: crypt(), gen_salt() para hashing bcrypt de contraseñas
```

### 7.2 Tipos ENUM

| Tipo | Valores |
|---|---|
| `user_role` | `auxiliarInventario`, `administrador`, `responsableArea`, `direccionAdminFin`, `auditor`, `soporteTI` |
| `asset_state` | `activo`, `reubicado`, `noEncontrado`, `obsoleto`, `enReparacion`, `paraBaja` |
| `verification_result` | `encontrado`, `reubicado`, `noEncontrado`, `paraBaja`, `obsoleto`, `enReparacion` |
| `maintenance_type` | `preventivo`, `correctivo` |

### 7.3 Tablas

#### `users` — Usuarios del sistema

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | VARCHAR(20) PK | Identificador único (ej. U001) |
| `username` | VARCHAR(100) UNIQUE | Nombre de usuario para login |
| `full_name` | VARCHAR(200) | Nombre completo |
| `email` | VARCHAR(200) UNIQUE | Correo electrónico (también válido para login) |
| `password_hash` | VARCHAR(255) | Hash bcrypt de la contraseña (pgcrypto) |
| `roles` | user_role[] | Array de roles asignados |
| `area` | VARCHAR(200) | Área o dependencia del usuario |
| `is_active` | BOOLEAN | Cuenta activa o desactivada |
| `last_session` | TIMESTAMPTZ | Fecha y hora del último login exitoso |
| `failed_attempts` | INT | Intentos fallidos consecutivos |
| `lock_until` | TIMESTAMPTZ | Fecha hasta la que la cuenta está bloqueada |
| `created_at` | TIMESTAMPTZ | Fecha de creación del registro |

#### `assets` — Catálogo maestro de activos fijos

| Columna | Tipo | Descripción |
|---|---|---|
| `code` | VARCHAR(50) PK | Código único del activo |
| `name` | VARCHAR(200) | Nombre del activo |
| `category` | VARCHAR(100) | Categoría |
| `subcategory` | VARCHAR(100) | Subcategoría |
| `physical_location` | VARCHAR(200) | Ubicación física |
| `responsible` | VARCHAR(200) | Responsable custodio |
| `dependency` | VARCHAR(200) | Dependencia propietaria |
| `cost_center` | VARCHAR(100) | Centro de costo |
| `acquisition_value` | NUMERIC(15,2) | Valor de adquisición |
| `acquisition_date` | DATE | Fecha de adquisición |
| `estimated_useful_life_years` | INT | Vida útil estimada (años) |
| `state` | asset_state | Estado actual |
| `observations` | TEXT | Observaciones libres |
| `program` | VARCHAR(200) | Programa o proyecto asociado |
| `photo_path` | VARCHAR(500) | Ruta de foto (legado) |
| `photo_base64` | TEXT | Foto en Base64 (activo) |
| `created_at` | TIMESTAMPTZ | Fecha de registro |
| `updated_at` | TIMESTAMPTZ | Fecha de última actualización (gestionada por trigger) |

#### `asset_history` — Log inmutable de cambios

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | SERIAL PK | Autoincremental |
| `asset_code` | VARCHAR(50) FK → assets | Activo al que pertenece el registro |
| `timestamp` | TIMESTAMPTZ | Momento del cambio |
| `action` | VARCHAR(100) | Tipo de acción (creación, actualización de estado, etc.) |
| `detail` | TEXT | Descripción detallada del cambio |
| `performed_by` | VARCHAR(200) | Usuario que realizó el cambio |

#### `inventory_sessions` — Sesiones de toma física de inventario

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | VARCHAR(50) PK | Identificador de la sesión |
| `name` | VARCHAR(200) | Nombre descriptivo |
| `site` | VARCHAR(200) | Sede o campus |
| `building` | VARCHAR(200) | Edificio |
| `floor` | VARCHAR(100) | Piso |
| `area` | VARCHAR(200) | Área específica |
| `created_at` | TIMESTAMPTZ | Fecha de creación |

#### `inventory_session_baseline` — Estado esperado al iniciar la sesión

| Columna | Tipo | Descripción |
|---|---|---|
| `session_id` | VARCHAR(50) FK → inventory_sessions | Sesión |
| `asset_code` | VARCHAR(50) FK → assets | Activo incluido en el baseline |
| `baseline_state` | asset_state | Estado del activo en el momento de crear la sesión |
| PK compuesta | (session_id, asset_code) | — |

#### `inventory_verifications` — Resultados reales de verificación

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | SERIAL PK | Autoincremental |
| `session_id` | VARCHAR(50) FK → inventory_sessions | Sesión |
| `asset_code` | VARCHAR(50) | Código del activo verificado |
| `result` | verification_result | Resultado de la verificación |
| `notes` | TEXT | Notas adicionales |
| `timestamp` | TIMESTAMPTZ | Momento de la verificación |
| `photo_path` | VARCHAR(500) | Foto tomada durante la verificación |

#### `maintenance_requests` — Solicitudes de mantenimiento

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | VARCHAR(50) PK | Identificador de la solicitud |
| `asset_code` | VARCHAR(50) FK → assets | Activo relacionado |
| `type` | maintenance_type | `preventivo` o `correctivo` |
| `description` | TEXT | Descripción del trabajo o problema |
| `created_by` | VARCHAR(200) | Nombre del solicitante |
| `created_at` | TIMESTAMPTZ | Fecha de creación |
| `closed` | BOOLEAN | TRUE si la solicitud fue cerrada |

#### `disposal_requests` — Solicitudes de baja

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | VARCHAR(50) PK | Identificador de la solicitud |
| `asset_code` | VARCHAR(50) FK → assets | Activo a dar de baja |
| `cause` | VARCHAR(200) | Causa de la baja |
| `justification` | TEXT | Justificación detallada |
| `created_by` | VARCHAR(200) | Nombre del solicitante |
| `created_at` | TIMESTAMPTZ | Fecha de creación |
| `approved_by_dependency` | BOOLEAN | Aprobado por responsable de área |
| `approved_by_daf` | BOOLEAN | Aprobado por Dirección Administrativa y Financiera |

### 7.4 Trigger automático

```sql
-- Actualiza el campo updated_at de assets en cada UPDATE
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
```

### 7.5 Migración automática

Al iniciar el backend (`index.js`), se ejecuta automáticamente:

```sql
ALTER TABLE assets ADD COLUMN IF NOT EXISTS photo_base64 TEXT;
```

Esto garantiza compatibilidad con bases de datos existentes que no tengan la columna `photo_base64`.

---

## 8. API REST

**Base URL:** `http://localhost:3000`

Todas las rutas (excepto `/health` y `/api/auth/*`) requieren la cabecera:
```
Authorization: Bearer <JWT_TOKEN>
```

El token expira en **8 horas**. Si expira, la API responde `401` con `{ "error": "Sesión expirada...", "code": "TOKEN_EXPIRED" }`.

Todos los cuerpos de request/response son **JSON**. Los errores siguen el formato:
```json
{ "error": "Descripción del error" }
```

---

### 8.1 Health Check

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| `GET` | `/health` | No | Comprobación de estado del servidor |

**Respuesta:** `200 OK`
```json
{ "status": "ok" }
```

---

### 8.2 Autenticación (`/api/auth`)

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| `POST` | `/api/auth/login` | No | Login con usuario/contraseña |
| `POST` | `/api/auth/google-login` | No | Login con correo verificado por Google |

**POST /api/auth/login — Request:**
```json
{
  "identifier": "admin",
  "password": "admin123"
}
```
> El campo `identifier` acepta nombre de usuario o correo electrónico.

**POST /api/auth/login — Response exitosa `200`:**
```json
{
  "token": "<JWT>",
  "user": {
    "id": "U001",
    "username": "admin",
    "fullName": "Admin General",
    "email": "admin@universidad.edu",
    "roles": ["administrador", "soporteTI"],
    "area": "Direccion Administrativa",
    "isActive": true
  }
}
```

**Respuestas de error de login:**
| Código | Body | Significado |
|---|---|---|
| `401` | `{ "code": "INFO", "message": "Usuario no encontrado" }` | El identifier no existe |
| `403` | `{ "code": "INFO", "message": "Usuario desactivado..." }` | Cuenta desactivada |
| `401` | `{ "code": "WARN", "remaining": 3 }` | Contraseña incorrecta, N intentos restantes |
| `401` / `403` | `{ "code": "LOCK", "seconds": 60 }` | Cuenta bloqueada, N segundos restantes |

**POST /api/auth/google-login — Request:**
```json
{ "email": "usuario@gmail.com" }
```

---

### 8.3 Usuarios (`/api/users`)

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/users` | Lista todos los usuarios (sin `password_hash`) |
| `GET` | `/api/users/:id` | Obtiene un usuario por ID |
| `POST` | `/api/users` | Crea un nuevo usuario |
| `PATCH` | `/api/users/:id` | Actualiza `full_name`, `email`, `roles` o `is_active` |
| `PATCH` | `/api/users/:id/password` | Cambia la contraseña (se hashea en el servidor) |
| `DELETE` | `/api/users/:id` | Elimina un usuario |

**POST /api/users — Request:**
```json
{
  "id": "U006",
  "username": "nuevo_usuario",
  "full_name": "Nombre Completo",
  "email": "correo@universidad.edu",
  "password": "contraseña123",
  "roles": ["auxiliarInventario"],
  "area": "Almacen"
}
```

---

### 8.4 Activos (`/api/assets`)

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/assets` | Lista activos; filtros opcionales: `?state=activo&dependency=Facultad` |
| `GET` | `/api/assets/:code` | Detalle del activo + array `history` (auditoría) |
| `POST` | `/api/assets` | Crea un nuevo activo |
| `PATCH` | `/api/assets/:code` | Actualiza campos específicos del activo (parcial) |
| `DELETE` | `/api/assets/:code` | Elimina un activo |
| `POST` | `/api/assets/:code/history` | Agrega una entrada al historial de auditoría |

**PATCH /api/assets/:code** acepta cualquier combinación de los campos editables:
`name`, `category`, `subcategory`, `physical_location`, `responsible`, `dependency`, `cost_center`, `acquisition_value`, `acquisition_date`, `estimated_useful_life_years`, `state`, `observations`, `program`, `photo_path`, `photo_base64`.

---

### 8.5 Inventario (`/api/inventory`)

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/inventory/sessions` | Lista todas las sesiones de inventario |
| `GET` | `/api/inventory/sessions/:id` | Detalle de sesión + `baseline` + `verifications` |
| `POST` | `/api/inventory/sessions` | Crea una sesión con su baseline (transacción atómica) |
| `POST` | `/api/inventory/sessions/:id/verifications` | Registra una verificación para la sesión |

**POST /api/inventory/sessions — Request:**
```json
{
  "id": "SES-001",
  "name": "Inventario Semestral Edificio A",
  "site": "Campus Principal",
  "building": "Edificio A",
  "floor": "Piso 2",
  "area": "Laboratorio de Cómputo",
  "baseline": [
    { "asset_code": "INV-001", "baseline_state": "activo" },
    { "asset_code": "INV-002", "baseline_state": "activo" }
  ]
}
```

---

### 8.6 Mantenimiento (`/api/maintenance`)

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/maintenance` | Lista solicitudes; filtros: `?asset_code=X&closed=false` |
| `GET` | `/api/maintenance/:id` | Obtiene una solicitud por ID |
| `POST` | `/api/maintenance` | Crea una solicitud de mantenimiento |
| `PATCH` | `/api/maintenance/:id/close` | Cierra una solicitud (`closed = TRUE`) |

---

### 8.7 Bajas (`/api/disposal`)

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/disposal` | Lista solicitudes; filtro: `?asset_code=X` |
| `GET` | `/api/disposal/:id` | Obtiene una solicitud por ID |
| `POST` | `/api/disposal` | Crea una solicitud de baja |
| `PATCH` | `/api/disposal/:id/approve` | Aprueba en un nivel (`{ "by": "dependency" }` o `{ "by": "daf" }`) |

---

## 9. Puesta en Marcha — Paso a Paso Completo

### Prerrequisitos

Antes de comenzar, asegúrate de tener instalado:

| Herramienta | Versión mínima | Descarga |
|---|---|---|
| Docker Desktop | Cualquier versión reciente | https://www.docker.com/products/docker-desktop/ |
| Flutter SDK | ^3.8.1 | https://docs.flutter.dev/get-started/install |
| Git | Cualquier versión | https://git-scm.com/ |

Verifica la instalación con:
```bash
docker --version
flutter --version
git --version
```

---

### Paso 1 — Clonar el repositorio

```bash
git clone https://github.com/<tu-usuario>/proyecto-grado.git
cd proyecto-grado
```

---

### Paso 2 — Configurar la variable de entorno JWT_SECRET

El backend requiere una variable de entorno `JWT_SECRET` para firmar los tokens JWT. Sin ella, el proceso se detiene con un error fatal.

**Opción A — Variable de entorno del sistema (recomendado en producción):**

En Linux/macOS:
```bash
export JWT_SECRET=mi_secreto_super_seguro_de_al_menos_32_caracteres
```

En Windows (PowerShell):
```powershell
$env:JWT_SECRET = "mi_secreto_super_seguro_de_al_menos_32_caracteres"
```

**Opción B — Archivo `.env` en la raíz del proyecto:**

Crea un archivo `.env` en la raíz del repositorio (junto a `docker-compose.yml`):
```env
JWT_SECRET=mi_secreto_super_seguro_de_al_menos_32_caracteres
```

> Si no defines `JWT_SECRET`, Docker Compose usará el valor predeterminado `cambia_este_secreto_en_produccion`. Esto funciona para desarrollo local, pero **nunca debe usarse en producción**.

---

### Paso 3 — Levantar el backend y la base de datos con Docker

```bash
docker compose up -d
```

Este comando realiza automáticamente:
1. Descarga la imagen `postgres:15-alpine` (primera vez).
2. Crea el contenedor `inventario_db` en el puerto `5432`.
3. Ejecuta `docker/init.sql` al inicializar la base de datos por primera vez:
   - Habilita la extensión `pgcrypto`.
   - Crea todos los tipos ENUM.
   - Crea todas las tablas con sus restricciones.
   - Crea el trigger `assets_updated_at`.
   - Inserta los **5 usuarios de prueba** con contraseñas hasheadas con bcrypt.
4. Construye la imagen del backend desde `backend/Dockerfile` (Node 20-alpine).
5. Crea el contenedor `inventario_backend` en el puerto `3000`.
6. El backend espera a que la base de datos esté lista (healthcheck cada 5 s, hasta 10 reintentos) antes de arrancar.
7. Al arrancar, el backend ejecuta la migración automática de la columna `photo_base64`.

**Verificar que los contenedores están corriendo:**
```bash
docker compose ps
```

Deberías ver ambos contenedores en estado `Up` (o `healthy`):
```
NAME                  STATUS
inventario_db         Up (healthy)
inventario_backend    Up
```

**Verificar que el backend responde:**
```bash
curl http://localhost:3000/health
# Respuesta esperada: {"status":"ok"}
```

---

### Paso 4 — Verificar la base de datos (opcional)

Puedes conectarte al contenedor de PostgreSQL para verificar que las tablas se crearon correctamente:

```bash
docker exec -it inventario_db psql -U postgres -d inventario
```

Dentro del cliente `psql`:
```sql
-- Ver todas las tablas
\dt

-- Ver los usuarios de prueba
SELECT id, username, roles, area FROM users;

-- Salir
\q
```

---

### Paso 5 — Instalar dependencias de Flutter

```bash
flutter pub get
```

Este comando descarga todos los paquetes declarados en `pubspec.yaml` al directorio `.dart_tool/` y `pubspec.lock`.

---

### Paso 6 — Ejecutar la app Flutter en desarrollo

**En emulador Android (Android Studio / AVD):**
```bash
flutter run
```

La URL del backend para el emulador Android es `http://10.0.2.2:3000` (el emulador mapea esa IP a `localhost` del host).

**En dispositivo Android físico** (mismo Wi-Fi que el servidor):
- Configura la URL del backend desde la pantalla **Integraciones** dentro de la app.
- Usa la IP local del equipo donde corre Docker, por ejemplo: `http://192.168.1.100:3000`.

**En Chrome (web):**
```bash
flutter run -d chrome
```

> En la versión web, el escaneo de QR (`mobile_scanner`) y la cámara pueden no estar disponibles según el navegador y permisos del sistema.

**En Windows (desktop):**
```bash
flutter run -d windows
```

**Listar dispositivos disponibles:**
```bash
flutter devices
```

---

### Paso 7 — Compilar la app para distribución

**APK para Android (instalación directa):**
```bash
flutter build apk --release
# Resultado: build/app/outputs/flutter-apk/app-release.apk
```

**App Bundle para Google Play:**
```bash
flutter build appbundle --release
# Resultado: build/app/outputs/bundle/release/app-release.aab
```

**Web (archivos estáticos):**
```bash
flutter build web
# Resultado: build/web/
```

**Windows (ejecutable):**
```bash
flutter build windows --release
# Resultado: build/windows/x64/runner/Release/
```

---

### Paso 8 — Detener los contenedores

```bash
docker compose down
```

Para detener **y eliminar los datos de la base de datos** (volumen):
```bash
docker compose down -v
```

> ⚠️ El flag `-v` elimina el volumen `inventario_data`. Los datos de la base de datos se perderán permanentemente. No usar en producción sin backup.

---

### Paso 9 — Reiniciar solo el backend (sin tocar la BD)

```bash
docker compose restart backend
```

---

### Paso 10 — Ver logs en tiempo real

**Logs del backend:**
```bash
docker compose logs -f backend
```

**Logs de la base de datos:**
```bash
docker compose logs -f db
```

**Ambos simultáneamente:**
```bash
docker compose logs -f
```

---

### Paso 11 — Modo desarrollo del backend (con recarga automática)

Si quieres modificar el backend sin reconstruir la imagen Docker:

```bash
cd backend
npm install
npm run dev
```

> Requiere Node.js 20+ instalado localmente y que PostgreSQL esté corriendo (ya sea via Docker o instalación local). Configura las variables de entorno `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` y `JWT_SECRET` en un archivo `.env` dentro de `backend/`.

---

### Solución de problemas comunes

| Problema | Causa probable | Solución |
|---|---|---|
| `Error: JWT_SECRET env var no definida` | Falta la variable de entorno | Crear archivo `.env` con `JWT_SECRET=...` |
| `Connection refused` en la app | URL del backend incorrecta | Configurar URL en Integraciones (`/health` para probar) |
| `inventario_backend` no inicia | La BD aún no está lista | Ejecutar `docker compose up -d` de nuevo; el healthcheck lo resolverá |
| `flutter pub get` falla | Versión de Flutter SDK incompatible | Verificar con `flutter --version` que sea ^3.8.1 |
| La cámara no funciona en Android | Falta permiso de cámara | Aceptar el permiso cuando la app lo solicite |
| `already in use` en puerto 5432 o 3000 | Otro proceso usa ese puerto | `docker compose down` y verificar con `netstat -an | findstr 5432` |
| Los datos se pierden al reiniciar | `docker compose down -v` fue ejecutado | Es normal; los datos de demo se restauran automáticamente con `init.sql` |

---

## 10. Usuarios de Prueba

Los siguientes usuarios se insertan automáticamente al inicializar la base de datos (`docker/init.sql`). Las contraseñas se hashean con `bcrypt` usando `pgcrypto`:

| ID | Usuario | Contraseña | Roles | Área |
|---|---|---|---|---|
| U001 | `admin` | `admin123` | administrador, soporteTI | Dirección Administrativa |
| U002 | `auxiliar` | `aux123` | auxiliarInventario | Almacén e Inventarios |
| U003 | `auditor` | `audit123` | auditor | Control Interno |
| U004 | `daf` | `daf123` | direccionAdminFin | Dirección Administrativa y Financiera |
| U005 | `resp` | `resp123` | responsableArea | Facultad de Ingeniería |

> Estos usuarios son exclusivamente para pruebas y desarrollo. Deben ser eliminados o sus contraseñas cambiadas antes de desplegar en producción.

---

## 11. Variables de Entorno

### Backend (contenedor `inventario_backend`)

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `DB_HOST` | `db` | Hostname del servidor PostgreSQL |
| `DB_PORT` | `5432` | Puerto PostgreSQL |
| `DB_NAME` | `inventario` | Nombre de la base de datos |
| `DB_USER` | `postgres` | Usuario PostgreSQL |
| `DB_PASSWORD` | `postgres` | Contraseña PostgreSQL |
| `PORT` | `3000` | Puerto en el que escucha Express |
| `JWT_SECRET` | `cambia_este_secreto...` | **OBLIGATORIO en producción.** Secreto para firmar/verificar JWT |
| `JWT_EXPIRES_IN` | `8h` | Tiempo de expiración del token JWT |

### Base de datos (contenedor `inventario_db`)

| Variable | Valor | Descripción |
|---|---|---|
| `POSTGRES_DB` | `inventario` | Nombre de la base de datos a crear |
| `POSTGRES_USER` | `postgres` | Superusuario PostgreSQL |
| `POSTGRES_PASSWORD` | `postgres` | Contraseña del superusuario |

---

## 12. Seguridad

- **Contraseñas:** nunca se almacenan en texto plano. Se usa `bcrypt` con sal aleatoria via `pgcrypto` (`gen_salt('bf')`).
- **JWT:** tokens firmados con `HS256`. La clave secreta se requiere como variable de entorno obligatoria; el proceso falla al inicio si no está definida.
- **Cabeceras HTTP:** `helmet` establece cabeceras de seguridad estándar (`X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security`, etc.).
- **SQL parametrizado:** todas las consultas usan parámetros (`$1`, `$2`, ...) de `node-postgres`, eliminando el riesgo de inyección SQL.
- **Autenticación en todas las rutas:** excepto `/health` y `/api/auth/*`, todas las rutas requieren un JWT válido verificado por el middleware `requireAuth`.
- **Bloqueo de cuenta:** protección contra ataques de fuerza bruta con bloqueo temporal tras 5 intentos fallidos.
- **Límite de payload:** el servidor acepta cuerpos JSON de hasta `15 MB` (configurado para soportar fotos en Base64).

---

## 13. Flujos de Negocio Detallados

### Flujo: Registro de un activo nuevo

```
Auxiliar abre AssetsPage
   → Toca "Nuevo activo"
   → Rellena formulario (código, nombre, categoría, ubicación, etc.)
   → Opcionalmente escanea QR para autocompletar el código
   → Opcionalmente captura foto con la cámara
   → Toca "Guardar"
   → Flutter POST /api/assets
   → Backend valida campos requeridos (code, name, category, dependency)
   → INSERT INTO assets ...
   → Response 201 con el activo creado
   → Flutter agrega el activo a la lista local
```

### Flujo: Toma física de inventario

```
Auxiliar abre InventoryPage
   → Toca "Nueva sesión"
   → Define nombre, sitio, edificio, piso y área
   → Flutter POST /api/inventory/sessions con baseline de activos del área
   → Backend inicia transacción: INSERT inventory_sessions + INSERT inventory_session_baseline (por cada activo)
   → COMMIT
   → Auxiliar recorre físicamente el área
   → Por cada activo encontrado: selecciona resultado + agrega foto y notas
   → Flutter POST /api/inventory/sessions/:id/verifications
   → Backend INSERT inventory_verifications
   → Al finalizar, el dashboard refleja los activos "noEncontrado" o "paraBaja"
```

### Flujo: Aprobación de baja

```
Auxiliar detecta activo obsoleto durante inventario
   → Abre DisposalPage → "Nueva solicitud de baja"
   → Selecciona activo, indica causa y justificación
   → Flutter POST /api/disposal
   → Backend INSERT disposal_requests (ambas aprobaciones en FALSE)
   │
   ├─ ResponsableArea ve la solicitud en DisposalPage
   │   → Toca "Aprobar (Dependencia)"
   │   → Flutter PATCH /api/disposal/:id/approve { "by": "dependency" }
   │   → Backend UPDATE disposal_requests SET approved_by_dependency = TRUE
   │
   └─ DirectorDAF ve la solicitud con aprobación de dependencia
       → Toca "Aprobar (DAF)"
       → Flutter PATCH /api/disposal/:id/approve { "by": "daf" }
       → Backend UPDATE disposal_requests SET approved_by_daf = TRUE
       → Baja completamente aprobada
```

### Flujo: Autenticación con Google

```
Usuario toca "Iniciar sesión con Google"
   → Flutter ejecuta GoogleSignIn().signIn()
   → Google retorna credenciales con email verificado
   → Flutter POST /api/auth/google-login { "email": "usuario@gmail.com" }
   → Backend busca el email en tabla users
   → Si existe y está activo: genera JWT y responde con token + datos del usuario
   → Si no existe: responde 401 "No existe un usuario registrado con este correo"
   → Flutter persiste el token en SharedPreferences
   → Navega a HomePage
```


