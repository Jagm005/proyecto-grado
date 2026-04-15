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
9. [Puesta en Marcha](#9-puesta-en-marcha)
10. [Usuarios de Prueba](#10-usuarios-de-prueba)

---

## 1. Descripción General

El sistema permite a diferentes perfiles de usuarios (auxiliares, administradores, auditores, directivos) gestionar el ciclo de vida completo de los activos institucionales:

- Registro y consulta del catálogo de activos con foto y código QR/barras.
- Tomas físicas de inventario por sitio, edificio y área.
- Solicitudes de mantenimiento preventivo y correctivo.
- Solicitudes de baja con flujo de aprobación multinivel.
- Historial de auditoría inmutable por activo.
- Generación de reportes en PDF.
- Dashboard de estadísticas en tiempo real.

---

## 2. Stack Tecnológico

| Capa | Tecnología | Versión |
|---|---|---|
| **Frontend** | Flutter / Dart | 3.x / SDK ^3.8 |
| **Backend** | Node.js + Express | 18 / 4.x |
| **Base de datos** | PostgreSQL | 15-alpine |
| **Infraestructura** | Docker + Docker Compose | 3.9 |

### Dependencias Flutter destacadas

| Paquete | Uso |
|---|---|
| `http` | Cliente REST hacia el backend |
| `mobile_scanner` | Lectura de códigos QR y de barras |
| `image_picker` | Captura/selección de fotos de activos |
| `pdf` | Generación de reportes en PDF |
| `google_fonts` | Tipografía (Libre Franklin) |
| `shared_preferences` | Persistencia local de sesión |
| `intl` | Formato de fechas y números |
| `postgres` | Conexión directa opcional a PostgreSQL |

### Dependencias Node.js destacadas

| Paquete | Uso |
|---|---|
| `express` | Framework HTTP / enrutamiento |
| `pg` (node-postgres) | Pool de conexiones a PostgreSQL |
| `helmet` | Cabeceras de seguridad HTTP |
| `cors` | Control de acceso Cross-Origin |

---

## 3. Arquitectura

El proyecto sigue una **Arquitectura por Capas (N-Tier / Layered Architecture)**:

```
┌─────────────────────────────────────────────────────┐
│         CAPA DE PRESENTACIÓN (Flutter)              │
│   Widgets · AppState (ChangeNotifier) · http client │
├─────────────────────────────────────────────────────┤
│         CAPA DE API / CONTROLADORES (Express)       │
│   Routes: auth · users · assets · inventory         │
│           maintenance · disposal                    │
│   Middlewares: helmet · cors · express.json          │
├─────────────────────────────────────────────────────┤
│         CAPA DE ACCESO A DATOS (db.js)              │
│   PostgreSQL Connection Pool (node-postgres)        │
├─────────────────────────────────────────────────────┤
│         CAPA DE DATOS (PostgreSQL 15)               │
│   Tablas · ENUMs · Triggers · Transacciones         │
└─────────────────────────────────────────────────────┘
```

La comunicación es estrictamente vertical: Flutter → Express (HTTP/REST JSON) → PostgreSQL (SQL parametrizado). Para la arquitectura detallada con diagramas Mermaid, ver [ARQUITECTURA.md](ARQUITECTURA.md).

---

## 4. Estructura del Repositorio

```
proyecto-grado/
├── lib/
│   └── main.dart              # Toda la lógica de UI y estado (Flutter)
├── backend/
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│       ├── index.js           # Punto de entrada Express
│       ├── db.js              # Pool de conexiones PostgreSQL
│       └── routes/
│           ├── auth.js        # Autenticación y sesión
│           ├── users.js       # Gestión de usuarios
│           ├── assets.js      # Catálogo de activos
│           ├── inventory.js   # Sesiones de inventario
│           ├── maintenance.js # Solicitudes de mantenimiento
│           └── disposal.js    # Solicitudes de baja
├── docker/
│   └── init.sql               # DDL + datos de ejemplo iniciales
├── docker-compose.yml
├── pubspec.yaml
└── ARQUITECTURA.md            # Documentación técnica ampliada
```

---

## 5. Módulos y Funcionalidades

### 5.1 Autenticación (`LoginPage`)
- Login con usuario y contraseña (bcrypt vía `pgcrypto`).
- Bloqueo de cuenta por intentos fallidos.
- Persistencia de sesión con `SharedPreferences`.

### 5.2 Dashboard (`DashboardPage`)
- Resumen estadístico de activos por estado.
- Indicadores de mantenimientos y bajas pendientes.
- Acceso rápido a los módulos principales.

### 5.3 Gestión de Activos (`AssetsPage`)
- Listado, búsqueda y filtrado del catálogo de activos.
- Registro con: código, nombre, categoría, subcategoría, ubicación física, responsable, dependencia, centro de costo, valor de adquisición, vida útil estimada, foto y observaciones.
- Escaneo de código QR/barras para identificación rápida (`mobile_scanner`).
- Captura de foto con la cámara o galería (`image_picker`).
- Estados del activo: `activo`, `reubicado`, `noEncontrado`, `obsoleto`, `enReparacion`, `paraBaja`.
- Historial de auditoría por activo (quién, cuándo, qué cambió).

### 5.4 Inventario Físico (`InventoryPage`)
- Creación de sesiones de toma física asociadas a sitio, edificio, piso y área.
- Baseline: snapshot del estado esperado de cada activo al iniciar la sesión.
- Verificación activo a activo con resultado: `encontrado`, `reubicado`, `noEncontrado`, `paraBaja`, `obsoleto`, `enReparacion`.
- Registro de foto y notas por verificación.

### 5.5 Mantenimiento (`MaintenancePage`)
- Solicitudes de tipo **preventivo** o **correctivo** vinculadas a un activo.
- Seguimiento del estado de cada solicitud.
- Cierre de solicitudes por el responsable.

### 5.6 Bajas (`disposal`)
- Solicitud de baja con causa y justificación.
- Flujo de aprobación de dos niveles: dependencia y Dirección Administrativa y Financiera (DAF).

### 5.7 Usuarios (`UsersPage`)
- CRUD completo de usuarios (solo `administrador` y `soporteTI`).
- Asignación de uno o múltiples roles por usuario.
- Activación / desactivación de cuentas.

### 5.8 Reportes (`ReportsPage`)
- Generación de reportes en PDF con `pdf`.
- Exportación del inventario filtrado por estado, área o categoría.

### 5.9 Integraciones (`IntegrationPage`)
- Configuración de la URL del backend.
- Prueba de conectividad con el servidor (`/health`).

---

## 6. Roles de Usuario

| Rol | Descripción |
|---|---|
| `auxiliarInventario` | Registra y actualiza activos; ejecuta tomas de inventario físico. |
| `administrador` | Acceso total al sistema, gestión de usuarios. |
| `responsableArea` | Consulta activos de su área; valida solicitudes de baja. |
| `direccionAdminFin` | Aprueba solicitudes de baja; acceso a reportes ejecutivos. |
| `auditor` | Acceso de solo lectura para auditoría y trazabilidad. |
| `soporteTI` | Gestión de usuarios y configuración del sistema. |

---

## 7. Base de Datos

### Tablas principales

| Tabla | Descripción |
|---|---|
| `users` | Usuarios con control de bloqueo RBAC. |
| `assets` | Catálogo maestro de activos fijos. |
| `asset_history` | Log inmutable de cambios por activo. |
| `inventory_sessions` | Sesiones de toma física de inventario. |
| `inventory_session_baseline` | Estado esperado de activos por sesión (N:M). |
| `inventory_verifications` | Resultados reales de verificación por sesión. |
| `maintenance_requests` | Solicitudes de mantenimiento preventivo/correctivo. |
| `disposal_requests` | Solicitudes de baja con aprobación multinivel. |

### ENUMs PostgreSQL

| Tipo | Valores |
|---|---|
| `user_role` | `auxiliarInventario`, `administrador`, `responsableArea`, `direccionAdminFin`, `auditor`, `soporteTI` |
| `asset_state` | `activo`, `reubicado`, `noEncontrado`, `obsoleto`, `enReparacion`, `paraBaja` |
| `verification_result` | `encontrado`, `reubicado`, `noEncontrado`, `paraBaja`, `obsoleto`, `enReparacion` |
| `maintenance_type` | `preventivo`, `correctivo` |

El esquema completo con DDL se encuentra en [docker/init.sql](docker/init.sql).

---

## 8. API REST

Base URL: `http://localhost:3000`

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/health` | Comprobación de estado del servidor |
| `POST` | `/api/auth/login` | Inicio de sesión |
| `GET/POST/PUT/DELETE` | `/api/users` | Gestión de usuarios |
| `GET/POST/PUT/DELETE` | `/api/assets` | Gestión de activos |
| `GET/POST/PUT/DELETE` | `/api/inventory` | Sesiones y verificaciones de inventario |
| `GET/POST/PUT` | `/api/maintenance` | Solicitudes de mantenimiento |
| `GET/POST/PUT` | `/api/disposal` | Solicitudes de baja |

Todas las rutas devuelven y aceptan **JSON**. Los errores siguen el formato `{ "error": "mensaje" }`.

---

## 9. Puesta en Marcha

### Prerrequisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado y en ejecución.
- [Flutter SDK](https://docs.flutter.dev/get-started/install) ^3.8 instalado (para desarrollo frontend).

### Levantar el backend y la base de datos

```bash
docker compose up -d
```

Esto levanta dos contenedores:
- `inventario_db` — PostgreSQL 15 en el puerto `5432` (inicializado con `docker/init.sql`).
- `inventario_backend` — Express API en el puerto `3000`.

Verificar que el backend está activo:

```bash
curl http://localhost:3000/health
# {"status":"ok"}
```

### Ejecutar la app Flutter

```bash
flutter pub get
flutter run
```

Para compilar en modo release para Android:

```bash
flutter build apk --release
```

> La IP del backend debe configurarse dentro de la app desde la pantalla **Integraciones**, o apuntar a `http://10.0.2.2:3000` cuando se usa el emulador Android.

---

## 10. Usuarios de Prueba

Los siguientes usuarios se insertan automáticamente al inicializar la base de datos:

| Usuario | Contraseña | Rol | Área |
|---|---|---|---|
| `admin` | `admin123` | administrador, soporteTI | Dirección Administrativa |
| `auxiliar` | `aux123` | auxiliarInventario | Almacén e Inventarios |
| `auditor` | `audit123` | auditor | Control Interno |
| `daf` | `daf123` | direccionAdminFin | Dirección Administrativa y Financiera |
| `resp` | `resp123` | responsableArea | Facultad de Ingeniería |

---

