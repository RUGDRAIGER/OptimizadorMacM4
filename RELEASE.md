# Guía de releases

## Convención de versiones

- Archivo `VERSION` en la raíz (ej. `0.0.1`).
- Cada commit de release usa el mensaje: `OptimizadorMacM4-<versión>`.
- Tag de git: `OptimizadorMacM4-<versión>` (ej. `OptimizadorMacM4-0.0.1`).
- Artefactos generados:
  - `dist/OptimizadorMacM4-<versión>.dmg`
  - `dist/OptimizadorMacM4-<versión>.pkg`

## Publicar una nueva versión

1. Actualiza `VERSION`, `MARKETING_VERSION` en Xcode y la etiqueta en la UI.
2. Ejecuta tests: `swift test`
3. Genera instaladores: `./scripts/build-release.sh`
4. Commit: `git commit -am "OptimizadorMacM4-0.0.2"`
5. Tag: `git tag OptimizadorMacM4-0.0.2`
6. Push: `git push origin main --tags`
7. Crea release en GitHub con los artefactos DMG y PKG.
