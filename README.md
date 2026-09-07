# OptimizadorMacM4

Aplicación nativa para macOS (Apple Silicon M4) que monitoriza recursos en tiempo real, gestiona procesos en segundo plano y limpia cachés del sistema de forma segura.

**Versión actual:** `OptimizadorMacM4-0.0.1`

## Descarga

- **Página de descarga:** https://rugdraiger.github.io/OptimizadorMacM4/
- **Releases:** https://github.com/RUGDRAIGER/OptimizadorMacM4/releases

Formatos disponibles:
- **DMG** — arrastra la app a Aplicaciones (recomendado para probar)
- **PKG** — instalador con comprobación de macOS 14+

## Requisitos

- macOS 14.0 o superior
- Mac con Apple Silicon (M4 recomendado)
- Xcode 15+

## Compilar y ejecutar

1. Abre `OptimizadorMacM4.xcodeproj` en Xcode.
2. Selecciona el esquema **OptimizadorMacM4**.
3. Pulsa **Run** (⌘R).

Desde terminal:

```bash
cd OptimizadorMacM4
xcodebuild -scheme OptimizadorMacM4 -configuration Debug build
open build/Debug/OptimizadorMacM4.app
```

## Módulos

### Monitor M4
- CPU separada por P-Cores y E-Cores (`host_statistics64`, `sysctlbyname`)
- Memoria unificada: Free, Active, Wired, Compressed
- Top procesos por CPU y RAM (`libproc`)

### Gestor de procesos
- Filtro de Helpers/Renderers en background
- Finalización segura: SIGTERM → SIGKILL
- Ajuste de prioridad (`nice`)

### Limpiador de caché
- Escaneo de `~/Library/Caches`, `/Library/Caches`, `DerivedData`
- **Dry Run** obligatorio antes de eliminar
- Purge de memoria purgable (`/usr/sbin/purge`)

## Permisos y seguridad

- La app **no usa App Sandbox** para acceder a procesos y cachés del usuario.
- **No modifica** rutas bajo `/System` (SIP).
- **Alerta** antes de actuar sobre procesos root (UID 0).
- **Confirma** todas las acciones destructivas (kill, delete, purge).

## Advertencias

- Finalizar procesos puede cerrar aplicaciones abiertas.
- La limpieza de cachés puede hacer que apps reconstruyan datos temporales.
- `purge` puede requerir permisos adicionales según la configuración del sistema.

## Estructura

```
OptimizadorMacM4/
├── Core/Monitoring/    # host_statistics64, sysctl, libproc
├── Core/Processes/     # filtros, SIGTERM/SIGKILL, nice
├── Core/Cache/         # scanner, dry run, purge
├── Shared/Models/      # modelos de datos
├── Shared/Security/    # validaciones SIP, root, rutas
└── UI/                 # SwiftUI views
```

## Tests

```bash
xcodebuild test -scheme OptimizadorMacM4 -destination 'platform=macOS'
```
