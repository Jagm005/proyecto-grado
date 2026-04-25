# Manual de Usuario — Sistema de Gestión de Inventario Institucional

> **Versión 1.0** · Abril 2026  
> Este manual explica cómo utilizar la aplicación paso a paso, organizado por perfil de usuario.

---

## Tabla de Contenidos

1. [Introducción](#1-introducción)
2. [Acceso al Sistema](#2-acceso-al-sistema)
3. [Panel Principal (Dashboard)](#3-panel-principal-dashboard)
4. [Módulo de Activos](#4-módulo-de-activos)
5. [Escaneo de Activos (QR / Código de Barras)](#5-escaneo-de-activos-qr--código-de-barras)
6. [Toma Física de Inventario](#6-toma-física-de-inventario)
7. [Solicitudes de Mantenimiento](#7-solicitudes-de-mantenimiento)
8. [Solicitudes de Baja](#8-solicitudes-de-baja)
9. [Notificaciones](#9-notificaciones)
10. [Reportes](#10-reportes)
11. [Gestión de Usuarios](#11-gestión-de-usuarios-solo-administrador)
12. [Configuración del Sistema](#12-configuración-del-sistema)
13. [Perfiles de Usuario y Permisos](#13-perfiles-de-usuario-y-permisos)
14. [Preguntas Frecuentes](#14-preguntas-frecuentes)

---

## 1. Introducción

El **Sistema de Gestión de Inventario Institucional** es una aplicación móvil y web que permite registrar, consultar, auditar y controlar el ciclo de vida de los activos fijos de la institución (equipos de cómputo, mobiliario, maquinaria, etc.).

**¿Qué puede hacer con la aplicación?**

- Registrar y actualizar activos con foto, ubicación y responsable.
- Escanear códigos QR o de barras para identificar activos en campo.
- Realizar sesiones de toma física de inventario.
- Generar reportes en PDF y Excel.
- Gestionar solicitudes de mantenimiento y baja de activos.
- Recibir notificaciones según su rol.

**Plataformas disponibles:** Android · iOS · Navegador Web

---

## 2. Acceso al Sistema

### 2.1 Pantalla de Inicio de Sesión

Al abrir la aplicación verá la pantalla de login con los campos **Usuario** y **Contraseña**.

```
┌──────────────────────────────────────┐
│        INVENTARIO INSTITUCIONAL      │
│                                      │
│   [  Usuario                      ]  │
│   [  Contraseña                   ]  │
│                                      │
│         [ INICIAR SESIÓN ]           │
│                                      │
│   ¿Olvidó su contraseña?             │
│   Modo: ○ Institucional  ○ Local     │
└──────────────────────────────────────┘
```

**Pasos:**
1. Ingrese su **nombre de usuario** (sin espacios, no distingue mayúsculas/minúsculas).
2. Ingrese su **contraseña**.
3. Presione **INICIAR SESIÓN**.

### 2.2 Modos de Autenticación

| Modo | Descripción |
|---|---|
| **Institucional** (recomendado) | Se valida contra el servidor. Requiere conexión a internet o a la red institucional. |
| **Local (Demo)** | Usa datos almacenados en el dispositivo. Solo para pruebas sin conexión. |

Para cambiar el modo, toque la opción correspondiente en la parte inferior de la pantalla de login.

### 2.3 Bloqueo de Cuenta

Por seguridad, si ingresa una contraseña incorrecta **5 veces consecutivas**, la cuenta se bloqueará automáticamente durante **1 minuto**. Verá un mensaje con la cuenta regresiva de desbloqueo.

> ⚠️ Si su cuenta permanece bloqueada o no recuerda su contraseña, contacte al Administrador del sistema.

### 2.4 Cerrar Sesión

Abra el **menú lateral** (toque el ícono de menú ☰ o deslice desde la izquierda) y seleccione **Cerrar sesión** en la parte inferior.

---

## 3. Panel Principal (Dashboard)

Después de iniciar sesión verá el **Dashboard**, que muestra un resumen del estado del inventario:

```
┌─────────────────────────────────────┐
│  Bienvenido, [Nombre de usuario]    │
├──────────────┬──────────────────────┤
│ Total Activos│  Activos en Riesgo   │
│    [número]  │     [número]         │
├──────────────┴──────────────────────┤
│  Verificados este mes: [número]     │
│  Últimas actividades recientes...   │
└─────────────────────────────────────┘
```

Desde el dashboard puede navegar a cualquier módulo usando el **menú lateral**.

---

## 4. Módulo de Activos

> Roles con acceso: **Administrador**, **Auxiliar de Inventario**

### 4.1 Consultar la Lista de Activos

1. En el menú lateral, seleccione **Activos**.
2. Verá la lista de todos los activos registrados con código, nombre y estado.
3. Use la **barra de búsqueda** (ícono de lupa) para buscar por código o nombre.
4. Use los **filtros** para acotar por categoría, estado o dependencia.

### 4.2 Ver el Detalle de un Activo

Toque cualquier activo de la lista para ver su información completa:

| Campo | Descripción |
|---|---|
| Código | Identificador único del activo (ej. `ACT-1001`) |
| Nombre | Descripción del activo |
| Categoría / Subcategoría | Tipo de bien (Cómputo, Mobiliario, etc.) |
| Ubicación física | Lugar donde está el activo actualmente |
| Responsable | Persona a cargo del activo |
| Dependencia | Área propietaria del bien |
| Centro de costo | Código contable de imputación |
| Valor de adquisición | Valor en pesos al momento de compra |
| Fecha de adquisición | Fecha de compra o ingreso al inventario |
| Vida útil estimada | Años de vida útil proyectada |
| Estado | Estado actual del activo |
| Observaciones | Notas adicionales |
| Foto | Imagen del activo (si fue cargada) |
| **Historial** | Log de todos los cambios realizados al activo |

### 4.3 Registrar un Activo Nuevo

1. En la lista de activos, toque el botón **+** (esquina inferior derecha).
2. Complete el formulario con los datos del activo. Los campos marcados con **\*** son obligatorios: código, nombre, categoría, dependencia.
3. Para agregar una **foto**, toque el área de imagen y seleccione entre:
   - Tomar foto con la cámara.
   - Seleccionar desde la galería.
4. Toque **GUARDAR**.

> ℹ️ El código del activo debe ser único en el sistema. Si ingresa un código ya existente, el sistema mostrará un error.

### 4.4 Actualizar un Activo

1. Abra el detalle del activo.
2. Toque el ícono de editar (lápiz ✏️).
3. Modifique los campos necesarios.
4. Toque **GUARDAR**. El cambio quedará registrado automáticamente en el historial del activo.

### 4.5 Estados de un Activo

| Estado | Significado |
|---|---|
| **Activo** | El bien está en uso normal. |
| **Reubicado** | Ha sido movido a una ubicación diferente a la registrada. |
| **No Encontrado** | No se pudo localizar en la última toma física. |
| **En Reparación** | Está siendo objeto de mantenimiento correctivo. |
| **Obsoleto** | Ha cumplido su vida útil y ya no se usa. |
| **Para Baja** | Está pendiente de aprobación para ser dado de baja. |

### 4.6 Historial del Activo

En la pantalla de detalle, deslice hacia abajo hasta la sección **Historial**. Verá una línea de tiempo con todas las acciones realizadas sobre el activo: creación, actualizaciones, verificaciones y solicitudes.

---

## 5. Escaneo de Activos (QR / Código de Barras)

> Roles con acceso: **Auxiliar de Inventario**, **Administrador**

Esta función permite identificar activos de forma rápida en campo apuntando la cámara al código físico del bien.

### 5.1 Cómo Escanear

1. En el menú lateral, seleccione **Escanear**.
2. La cámara se activará automáticamente.
3. Apunte la cámara al código QR o de barras del activo.
4. El sistema reconocerá el código automáticamente (sin necesidad de presionar un botón).

### 5.2 Resultados del Escaneo

| Situación | Qué hace la app |
|---|---|
| El código **existe** en el inventario | Abre directamente el detalle del activo. |
| El código **no existe** en el inventario | Ofrece dos opciones: registrar el activo nuevo o reportar la anomalía. |

### 5.3 Reporte de Activo No Encontrado

Si escanea un código y el activo no está registrado, puede generar un reporte de anomalía que llegará como notificación al **Administrador** y a la **Dirección Administrativa y Financiera**.

---

## 6. Toma Física de Inventario

> Roles con acceso: **Auxiliar de Inventario**, **Administrador**

La toma física permite verificar presencialmente que los activos de un área o edificio están en su lugar.

### 6.1 Crear una Sesión de Inventario

1. En el módulo de Activos o desde el menú, seleccione **Nueva sesión de inventario**.
2. Complete los datos de la sesión:
   - Nombre de la sesión (ej. "Inventario Bloque B - Abril 2026")
   - Sede / Edificio / Piso / Área
3. Toque **INICIAR SESIÓN**.

### 6.2 Verificar Activos en la Sesión

Durante la sesión, para cada activo del área:

1. Escanee el código del activo con la cámara **o** búsquelo manualmente.
2. Seleccione el resultado de la verificación:
   - ✅ **Encontrado** — El activo está en su ubicación registrada.
   - 🔄 **Reubicado** — Está en un lugar diferente al registrado.
   - ❌ **No Encontrado** — No está físicamente en el área.
   - 🔧 **En Reparación** — Está fuera del área por mantenimiento.
   - ⚠️ **Para Baja / Obsoleto** — Requiere gestión especial.
3. Agregue una nota si es necesario y, opcionalmente, tome una foto.
4. Pase al siguiente activo.

### 6.3 Finalizar la Sesión

Al verificar todos los activos, toque **FINALIZAR SESIÓN**. El sistema generará un resumen con el porcentaje de activos encontrados y las discrepancias detectadas.

---

## 7. Solicitudes de Mantenimiento

> Roles con acceso: todos los usuarios con acceso a activos

### 7.1 Crear una Solicitud

1. Abra el detalle del activo que requiere mantenimiento.
2. Toque **Solicitar mantenimiento**.
3. Seleccione el tipo:
   - **Preventivo** — Mantenimiento programado antes de una falla.
   - **Correctivo** — Reparación de una falla ya ocurrida.
4. Describa detalladamente el problema o el trabajo requerido.
5. Toque **ENVIAR**.

### 7.2 Consultar el Estado de una Solicitud

Las solicitudes de mantenimiento se pueden consultar desde el detalle del activo o en el módulo de Notificaciones. Una solicitud puede estar **Abierta** o **Cerrada**.

---

## 8. Solicitudes de Baja

> Creación: **Auxiliar de Inventario** · Aprobación: **DAF**

### 8.1 Solicitar la Baja de un Activo

1. Abra el detalle del activo.
2. Toque **Solicitar baja**.
3. Seleccione la **causa** (obsolescencia, daño irreparable, pérdida, etc.).
4. Escriba la **justificación** detallada.
5. Toque **ENVIAR**. La solicitud llega como notificación a la Dirección Administrativa y Financiera.

### 8.2 Aprobar o Rechazar una Baja (rol DAF)

1. Abra el módulo de **Notificaciones**.
2. Toque la notificación de solicitud de baja.
3. Revise los datos del activo y la justificación.
4. Seleccione **APROBAR** o **RECHAZAR**.
5. La decisión queda registrada y el solicitante es notificado.

---

## 9. Notificaciones

El ícono de campana 🔔 en la barra superior muestra el número de notificaciones sin leer.

### 9.1 Tipos de Notificaciones

| Tipo | Descripción | ¿Quién la recibe? |
|---|---|---|
| Activo no encontrado | Reporte de un activo cuyo código no está en el sistema | Administrador, DAF |
| Solicitud de baja | Petición de dar de baja un activo | DAF |
| Información general | Avisos del sistema | Según configuración |

### 9.2 Gestionar Notificaciones

- Toque una notificación para verla en detalle y marcarla como leída.
- Use **Marcar todas como leídas** para limpiar el contador de una vez.
- Las notificaciones con estado **Pendiente** pueden ser aprobadas o rechazadas si su rol lo permite.

---

## 10. Reportes

> Roles con acceso: **Administrador**, **Auditor**, **DAF**

### 10.1 Generar un Reporte

1. En el menú lateral, seleccione **Reportes**.
2. Configure los filtros según necesite:

| Filtro | Descripción |
|---|---|
| Sede / Área | Filtra por ubicación física |
| Dependencia | Filtra por área propietaria |
| Programa | Filtra por programa académico o administrativo |
| Responsable | Filtra por persona a cargo |
| Categoría | Filtra por tipo de bien |
| Estado | Filtra por estado del activo |
| Período | Mensual, Semestral o Anual |

3. Toque **GENERAR REPORTE**.

### 10.2 Formatos de Exportación

| Formato | Cómo exportar | Cuándo usarlo |
|---|---|---|
| **PDF** | Toque **Exportar PDF** | Impresión, informes formales, archivo digital firmable |
| **Excel (.xlsx)** | Toque **Exportar Excel** | Análisis de datos, tablas dinámicas, cruce con contabilidad |

El archivo generado se puede guardar en el dispositivo o compartir directamente por correo, WhatsApp u otras apps instaladas.

---

## 11. Gestión de Usuarios (solo Administrador)

> Rol requerido: **Administrador**

### 11.1 Ver la Lista de Usuarios

En el menú lateral, seleccione **Usuarios**. Verá todos los usuarios con su nombre, rol y estado (activo/inactivo).

### 11.2 Crear un Usuario

1. Toque el botón **+**.
2. Complete: nombre completo, nombre de usuario, correo, área, contraseña inicial y roles.
3. Toque **GUARDAR**.

> ℹ️ El nombre de usuario debe ser único y no debe contener espacios.

### 11.3 Editar un Usuario

1. Toque el usuario en la lista.
2. Modifique los campos necesarios (puede cambiar roles, área, estado activo/inactivo).
3. Toque **GUARDAR**.

### 11.4 Desactivar un Usuario

En lugar de eliminar un usuario (lo que eliminaría su historial de acciones), es recomendable **desactivarlo**:

1. Abra la edición del usuario.
2. Desactive el interruptor **Usuario activo**.
3. Guarde. El usuario no podrá iniciar sesión pero su historial se preserva.

### 11.5 Restablecer Contraseña

Si un usuario olvida su contraseña:

1. En la lista de usuarios, toque el ícono de llave 🔑 junto al usuario.
2. El sistema generará una contraseña temporal.
3. Informe la contraseña temporal al usuario. Se recomienda que la cambie en el siguiente acceso.

---

## 12. Configuración del Sistema

> Roles con acceso: **Administrador**, **Soporte TI**

En el menú lateral seleccione **Configuración**. Desde aquí puede:

| Opción | Descripción |
|---|---|
| **Modo de autenticación** | Cambiar entre autenticación institucional (backend) y modo local (demo). |
| **Intentos máximos de login** | Número de fallos consecutivos antes de bloquear una cuenta (por defecto: 3). |
| **URL del servidor** | La aplicación usa `http://18.223.120.46:3000` por defecto. Contacte a Soporte TI para cambiarla. |

---

## 13. Perfiles de Usuario y Permisos

| Función | Aux. Inventario | Administrador | Resp. Área | DAF | Auditor | Soporte TI |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Ver dashboard | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Ver activos | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| Crear / editar activos | ✅ | ✅ | — | — | — | — |
| Escanear activos | ✅ | ✅ | — | — | — | — |
| Toma física de inventario | ✅ | ✅ | — | — | — | — |
| Solicitar mantenimiento | ✅ | ✅ | ✅ | — | — | — |
| Solicitar baja de activo | ✅ | ✅ | — | — | — | — |
| Aprobar / rechazar baja | — | — | — | ✅ | — | — |
| Ver notificaciones propias | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Ver todas las notificaciones | — | ✅ | — | — | — | — |
| Generar reportes | — | ✅ | — | ✅ | ✅ | — |
| Gestionar usuarios | — | ✅ | — | — | — | — |
| Configurar el sistema | — | ✅ | — | — | — | ✅ |

---

## 14. Preguntas Frecuentes

**¿Qué hago si la aplicación muestra "No se pudo conectar al servidor"?**  
Verifique que su dispositivo tenga conexión a internet o a la red institucional. Si el problema persiste, puede activar el **Modo Local** en la pantalla de login para trabajar con los datos del dispositivo.

**¿Puedo usar la aplicación en el navegador web?**  
Sí. Abra el navegador y acceda a la URL que le indique el área de Soporte TI. La interfaz es idéntica a la versión móvil.

**¿Los cambios que hago en modo local se sincronizan con el servidor después?**  
No. El modo local es independiente. Los cambios realizados en modo local no se transfieren automáticamente al servidor institucional. Use el modo institucional siempre que sea posible.

**¿Cómo se actualiza la aplicación?**  
- **Móvil:** descargue la nueva versión del APK proporcionada por Soporte TI e instálela sobre la versión anterior.  
- **Web:** no requiere actualización; el navegador siempre carga la versión más reciente.

**¿Puedo tener más de un rol asignado?**  
Sí. Un usuario puede tener múltiples roles (ej. Administrador + Soporte TI). Sus permisos serán la unión de todos sus roles asignados.

**¿Por qué no veo la opción de "Usuarios" en el menú?**  
Esta opción solo está disponible para usuarios con rol **Administrador**. Si necesita acceder a esta función, contacte al Administrador del sistema para que ajuste sus permisos.

**¿Cómo sé si una solicitud de baja fue aprobada?**  
Recibirá una **notificación** en la aplicación con el resultado de la aprobación (aprobada o rechazada). También puede consultarlo en el historial del activo correspondiente.

---

*Para soporte técnico, contacte al área de Sistemas o Soporte TI de la institución.*  
*Versión del manual: 1.0 · Abril 2026*
