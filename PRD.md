# PRD: macOS M4 Performance & Cache Optimizer

## 1. Visión del Producto
Aplicación nativa para macOS (Apple Silicon M4) orientada a monitorear recursos en tiempo real, limpiar cachés del sistema/usuario, gestionar procesos en segundo plano y liberar memoria unificada de forma segura.

## 2. Especificación Técnica por Módulos

### Módulo 1: Monitor de Recursos M4
- **Entradas**: APIs de sistema (`host_statistics64`, `sysctlbyname`).
- **Métricas**:
  - Uso de CPU dividida (P-Cores y E-Cores de la arquitectura M4).
  - Presión de Memoria Unificada (Free, Active, Wired, Compressed).
  - Listado de procesos ordenados por `%CPU` y `RAM (MB)`.

### Módulo 2: Gestor de Procesos en Segundo Plano
- **Mapeo**: Lectura de PIDs mediante `libproc`.
- **Acciones**:
  - Filtro automático de procesos no esenciales (ej. Helpers, Renderers en segundo plano).
  - Finalización segura (`SIGTERM` previo a `SIGKILL`).
  - Asignación de prioridad (`nice` level) para proteger tareas de desarrollo/IA.

### Módulo 3: Limpiador de Sistema y Caché
- **Ubicaciones objetivo**:
  - `~/Library/Caches/*`
  - `/Library/Caches/*`
  - `~/Library/Developer/Xcode/DerivedData` (Limpieza específica para desarrollo)
  - Liberación de memoria purgable mediante llamada de sistema `purge`.
- **Modo Seguro**: Simulación previa ("Dry Run") mostrando el espacio recuperable exacto en MB/GB antes de eliminar.

## 3. Límites de Seguridad
- No tocar rutas de sistema protegidas por SIP (System Integrity Protection).
- Alertar si un proceso a finalizar pertenece a root (`UID 0`).