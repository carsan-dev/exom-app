# Compatibilidad del payload publicado — App

Fecha: 2026-10-09. Alcance R5 / REST-T3D-RECONCILE-01, P5-02/P5-03. Solo cobertura; ninguna modificación de producto. RED productivo NOT_APPLICABLE: no defecto productivo demostrado ni comportamiento esperado inventado.

La publicación `reviewed_at=2026-10-08T10:20:30.456Z` se conserva ante un borrador privado posterior (`updated_at=2026-10-09T11:00:00.000Z`, versión9). Cuatro sentinelas distintos para nota interna/resumen/cambios/objetivos privados. Feedback legacy con fecha de envío sigue permitido; nunca se usa el borrador como fallback. Null/ausencia no inventan publicación. Tests anteriores de privacidad, identidad y sesión conservados.

| Variante | Campos públicos | SHA256 JSON canónico |
| --- | --- | --- |
| full | 42 | b259648472dff52f42fbc0cc4960ab980542023d1813222b6ca70219ad1bb238 |
| partial | 42 | 1eed7dd846aded5b022cb90e654cdee9be5708bf3d361b8d40815b23841eeaea |
| null | 42 | 3789f1f9081af01410a44865040cd837667be56f8e3b7665fb1804c09bf4b6aa |
| absent legacy | 39 | 6c34850dd3feafdedd5adb4fa873c1cf052deef0bb1f2d791935ffd69ebab837 |

Comparación estructural de los tres literales PASS: extraer `publicationPayload`, interpretar claves/valores sin tipos y comparar objetos; JSON canónico UTF-8, claves ordenadas, separadores compactos, Unicode sin escape. Variantes idénticas: tres textos; resumen/NULL/objetivos; tres NULL; eliminación de las tres claves. Cada checkout incorpora su literal; los tests no leen archivos hermanos ni requieren fixture externo.

Snapshot HEAD15af3774308a9a0d080705a38e4327c9b251f2d3; rama/upstream fix/scoped-training-discard / origin/fix/scoped-training-discard. SHA256 test `741efe8f52beeb914681aeeffbe21d6d77fbaf49444333a43cbeeb0156aa2648`.

- PASS `flutter analyze --no-pub`:0 issues (31.0s); PASS `flutter test --no-pub`:544 tests,0 fallos, incluidos cuatro variantes remotas detail/list mediante adaptador HTTP simulado con envelope JSON y repositorio reales.
- Conservadas URI GET exactas, fechas UTC/ms, legacy enviado, identidad y valores históricos. Entidad mantiene exactamente tres valores publicados; hasPublishedReview=false con null/ausencia aunque exista draft privado. API demuestra exclusión del select; App ignora claves privadas adicionales sin fallback.
- PASS diff-check. SDK local flutter.version.json confirma Flutter3.41.5/Dart3.11.3. `flutter --version` quedó bloqueado y fue cancelado; no presentarlo como PASS.
- Resumen reproducible final: sesión13518, resultado terminal0, duración tests1:41,544PASS; este recibo conserva el resumen. Ejecución inicial544PASS supersedida por recuperación UTF-8/LF; todas las pruebas se repitieron sobre bytes finales.

SKIPPED: dispositivos/build Android/iOS/liveFirebase/JWT, no necesarios para test-only y no autorizados como prueba real. No cambios de dependencias/lockfiles. Revisión/CI pendientes del padre.
