# REST-T3C3B — contrato público serializado de recap

> Copia saneada para entrega: ubicaciones normalizadas; resultados, fechas y hashes conservan su significado histórico y corresponden al snapshot privado original, no a esta copia. WORKSPACE_ROOT identifica la coordinación; SDK_ROOT el SDK instalado; RUNTIME_ROOT las herramientas locales; TEST_ARTIFACT_ROOT los recursos privados retenidos, no publicados.


**Cobertura funcional PASS; candidato local sin commit/revisión. P5 continúa pendiente.** P5-02 recibe una prueba nueva del consumo App, no una certificación integral API/Admin/App. Solo test y este recibo; sin cambios runtime.

## Base y alcance

Raíz de coordinación: `${WORKSPACE_ROOT}/` (sin Git utilizable según checkpoint del padre). Seguimiento autoritativo: `odd/tasks/progress-remaining-phases.md`, reanudación REST-T3C3B ACTIVE; snapshot previo del padre: `docs/evidence/progress-remaining-20261008/checkpoint/t3c3b-resume/before.json`. No se modifica seguimiento ni espejo pendiente.

| Checkout | Rama / upstream origin homónimo | HEAD | Merge-base/upstream local |
| --- | --- | --- | --- |
| App | fix/scoped-training-discard | e8d6a6f1f0b6c3331a0255907b5190248b47f4e3 | db72c7feee2c3ba91bc71068a7918903179ca78d |
| API | feat/progreso-adherencia-p4 | 2860703d8e00dc6a096a02c0c4b37543c0cd514a | c383d47f4aa8217f727acf33e4c1900c0866b7bd |
| Admin | fix/progress-detail-and-charts | 6f5080b58383dc37b10ab490dd92e408eb79d3c2 | e14d56a8b35ca2bb18420d27549739d237653084 |

Estado inicial observado: App/Admin limpios; API solo `scripts/probe-client-deletion-lock-order.cjs` untracked original. Sin fetch, staging, commit, revisión/STATUS, remoto ni limpieza.

Test: `test/features/recap/data/datasources/recap_remote_datasource_test.dart`, 114 líneas legibles (objetivo ≤100 advisory excedido para conservar detalle/lista y seis fechas sin comprimir). Cuatro casos: tres publicaciones String completas, parciales, null y ausentes legacy. Cada uno usa ApiClient real sin auth, adapter público de Dio, HTTP200 JSON serializado con content-type JSON y envelope `{success:true,data,timestamp:ISO}`. Datasource/repositorio/modelo reales decodifican detalle y lista nested `data.data`; asserts de GET/URI prefijada/query vacía, publicaciones, seis fechas UTC con timestamps/milisegundos y campos legacy independientes.

## Verificación nueva

Todos los comandos siguientes se ejecutaron secuencialmente en foreground desde `exom-app`, Windows, runner instalado; resultados completados antes de **2026-10-08T11:30:27Z**. Sin `pub`, instalaciones ni auto-fix. Salida reproducible mediante estos comandos; sin logs locales adicionales.

| Comando exacto | Resultado observado |
| --- | --- |
| `${RUNTIME_ROOT}/flutter/bin/flutter --version` | PASS, Flutter 3.41.5 stable, framework 2c9eb20739; Dart 3.11.3, DevTools 2.54.2 |
| `${RUNTIME_ROOT}/flutter/bin/flutter test --no-pub test/features/recap/data/datasources/recap_remote_datasource_test.dart` | PASS, 4 tests; 8 GET sintéticos |
| `${RUNTIME_ROOT}/flutter/bin/flutter test --no-pub` | PASS, 540 tests, cero fallos; aviso Hive de override de adapter en timed_prescription_test, no fallo |
| `${RUNTIME_ROOT}/flutter/bin/flutter analyze --no-pub` | PASS, 0 issues, 35.5s |
| `git diff --check` | PASS, sin salida; Git no incluye archivos nuevos untracked en este check |

RED/GREEN causal: **NOT_APPLICABLE**, añadido de cobertura sin bug demostrado; primera ejecución focal PASS, no RED inventado. Triangulación: full/partial/null/absent, ambos lectores, suite completa. Build/Android/iOS/smoke: NOT_APPLICABLE, no cambio de producto/runtime; no emulador, Firebase, API live ni DB.

## Fuente vigente vs evidencia funcional histórica

Rutas relativas a la raíz de coordinación; números de línea de fuente leída, no resultados de integración:

- `exom-api/src/configure-app.ts:13,34–37`: prefix `api/v1` e interceptor global. `src/common/interceptors/transform.interceptor.ts:42–48,60`: envelope y timestamp ISO; conserva Date para serialización posterior. Sustenta fixture por lectura, **no prueba HTTP de producción**.
- `exom-api/src/modules/recaps/recaps.service.ts:34–78,435–465`: proyección pública con tres publicaciones, feedback legacy y fechas; lectores cliente paginado/detalle y propiedad. `REVIEW_SELECT:80–92` contiene draft/version privados para staff: no reutilizado en fixture App.
- `exom-api/src/modules/recaps/recap-review-publication.spec.ts:70–101`: bootstrap histórico HTTP/PG37 sin configureApp/TransformInterceptor/prefix; **no acredita envelope/fechas de producción**. Tests de publicación `:107–191` con nota privada poblada sustentan publicación explícita/última publicación durante nuevo borrador y proyección segura; resultados históricos en `exom-api/docs/evidence/rest-t3b-20261005/README.md`, no rerun aquí.
- `exom-admin/src/lib/api-utils.ts:3–7,41–43` y `src/features/recaps/api.ts:19–24,91–111`: envelope/unwrap y comandos draft/publicación con identidad. `src/features/recaps/api.test.tsx:13,22–64` usa envelope Axios simulado; no red real. Fixture staff `docs/evidence/rest-t3c-admin-20261007/browser/fixture-api.ts:29–32,74,83,138`: incluye privados y envelope/publicación, no DTO público para App.
- `lib/core/api/api_client.dart:10–38`, `lib/features/recap/data/datasources/recap_remote_datasource.dart:13–52`, `data/repositories/recap_repository_impl.dart:6–15` y `data/models/recap_model.dart:48–50,87–106`: cliente real, unwrap detalle/lista, delegación y parsing nullable/ISO. Adapter inspirado en `test/features/progress_photos/progress_photo_remote_datasource_test.dart:12–44`.
- Evidencia histórica distinta: `docs/evidence/rest-t3c-app-20261008/README.md` (focal34/full536/analyze0/APK sintético) y `exom-admin/docs/evidence/rest-t3c-admin-20261007/README.md` (browser15/PDF11). Model/widget/session/lateness son garantías diferentes; suite App nueva540 vuelve a ejercitar sus tests, sin reabrir autoridad nativa consumida ni repetir harness Admin/API.

Fixture nuevo deliberadamente solo público. No se añade una assertion vacua de ausencia de privados: la omisión en un fixture no demuestra privacidad server-side. No integración cross-repo/live/Firebase/JWT, concurrencia PG, aprobación humana ni cierre P5 inferidos.

## Identidad SHA256 de bytes observados

Test nuevo: `929294e15a7ac0b36a6c2133ff711876c87aada91d5286b38eb196189e49f0ae`.

| Fuente sin editar (ruta abreviada respecto a checkout) | SHA256 |
| --- | --- |
| App lib/core/api/api_client.dart | 6703e2bbc7b0ac810eeb9e1e5d3429f4ea4f1bd5c83e0781be92f8cbfe5e4f23 |
| App lib/features/recap/data/datasources/recap_remote_datasource.dart | cd42c38b8788c0c780000e7c08e00c087dd31c62bc78b0b3f9add6fda55da4ed |
| App lib/features/recap/data/repositories/recap_repository_impl.dart | 2688b33287da686520db194ce8386d4e33a5f60a38b2065860e7901745efe2a5 |
| App lib/features/recap/data/models/recap_model.dart | 944ec9fe55145c9a27ee52e95699ea11dd01e59fe49d188200e84464ef7b5492 |
| API src/configure-app.ts | df22a43de81a879efa8aafc5550f37f229deccec50bd6f3f6984ea0b6231a506 |
| API src/common/interceptors/transform.interceptor.ts | 0d6ee527c279ca8ac172f16b9052e546f93409d69db4c874a1a930f8c6be0a76 |
| API src/modules/recaps/recaps.service.ts | edc19b769620516e149228e39aefb276cb4780a9bf4ea324e3a9f265c8b0bc22 |
| Admin src/features/recaps/api.ts | f0b22de53416b65b066c282c036103abc65ad84dfcf1b2d208c53df2f461bb4d |
| Admin src/lib/api-utils.ts | d08ec01d2a7f3ea1d86141b73e8cd75022f361c17886534315da3f8760069a1d |
| Admin docs/evidence/rest-t3c-admin-20261007/browser/fixture-api.ts | f5f163c66677144acd719fa478cb410f86f37df7305ed2de9a48e58340019e81 |

## Límite recuperable y siguiente control

Inventario/rollback exclusivo de esta unidad: test nuevo citado y `docs/evidence/rest-t3c3b-app-20261008/README.md`. No producto alterado; retirar solo esos dos archivos mediante una decisión posterior autorizada revierte la unidad sin cambiar fuentes ni evidencia previa. Hash del recibo se entrega al padre, no autorreferenciado. Archivos nuevos sin commit; checkpoint final, revisión del candidato, seguimiento y eventual commit corresponden al padre. REST-T3D/P5/P6 permanecen fuera de esta unidad.
