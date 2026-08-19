# Checklist de pruebas manuales — OptimizadorMacM4

Ejecutar en Mac M4 con macOS 14+ y Xcode 15+.

## Monitor M4
- [ ] La app abre y muestra la pestaña Monitor
- [ ] CPU total, P-Cores y E-Cores muestran porcentajes entre 0–100%
- [ ] Memoria muestra Free, Active, Wired, Compressed
- [ ] Top procesos se actualiza cada ~1.5 s
- [ ] Bajo carga (ej. `yes > /dev/null &`), CPU sube coherentemente

## Gestor de procesos
- [ ] Filtro "Solo background" muestra Helpers/Renderers
- [ ] Procesos con PID < 100 no son accionables
- [ ] Procesos root muestran advertencia
- [ ] Finalizar proceso muestra diálogo de confirmación
- [ ] SIGTERM cierra un proceso de prueba controlado

## Limpiador de caché
- [ ] Dry Run muestra MB/GB recuperables sin borrar
- [ ] Rutas bajo `/System` no aparecen como permitidas
- [ ] Limpieza requiere confirmación explícita
- [ ] Log registra acciones con timestamp
- [ ] Purge muestra memoria antes/después

## Seguridad
- [ ] Ninguna acción destructiva sin confirmación
- [ ] Intentos sobre rutas SIP son rechazados
