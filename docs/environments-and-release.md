# Entornos y release

`EXOM_FLAVOR` selecciona dev/staging/prod. Debug sin define usa dev; release sin define usa prod. CI de publicación declara prod expresamente. Los valores desconocidos conservan el fallback histórico; usa solo estos valores documentados.

| Entorno | API | Firebase y distribución |
| --- | --- | --- |
| dev | `EXOM_API_BASE_URL` completo, incluido `/api/v1`. Por defecto emulador Android `10.0.2.2:3000`, Android físico `127.0.0.1:3000` con reverse, otros `localhost:3000`. | Configuración nativa del proyecto Firebase de desarrollo; nunca copiar credenciales de producción como fallback. |
| staging | `https://api-staging.exom.app/api/v1` (dirección reservada; disponibilidad no acreditada por este cambio). | Configuración nativa y cuentas de prueba del entorno staging; sin publicación a tiendas desde el helper dev. |
| prod | `https://api.exommethod.com/api/v1`. El override de desarrollo no se aplica. | Secrets de distribución Android/iOS del workflow de release existente. |

FlavorConfig separa los destinos HTTP; no crea proyectos Firebase, cambia applicationId/bundleId ni selecciona automáticamente los archivos `android/app/google-services.json` e `ios/Runner/GoogleService-Info.plist`. Estos archivos deben corresponder al entorno elegido y se suministran fuera de Git. Los proyectos externos dev/staging no se aprovisionan en esta fase. API, Admin, Firebase, almacenamiento y usuarios de prueba deben configurarse juntos; cambiar solo la URL no acredita aislamiento externo. Las colas locales ya están vinculadas a cuenta/entorno; no se migra una cola a otro destino para probar conectividad.

## Android físico

127.0.0.1 es el teléfono. El helper existente `scripts/run-android-dev.cmd` configura `adb reverse`; ahora también fija dev y propaga `-Port` a la URL. Prefiere un dispositivo físico conectado o acepta `-DeviceId` explícito:

```powershell
scripts\run-android-dev.cmd -DeviceId SERIAL -Port 3000
scripts\run-android-dev.cmd -DeviceId SERIAL -Port 4000
scripts\run-android-dev.cmd --dart-define=EXOM_API_BASE_URL=http://192.168.1.20:3000/api/v1
```

El override LAN requiere que la API escuche en una interfaz accesible y que el firewall permita ese puerto. Comprueba `adb -s SERIAL reverse --list`. Tras desconectar/reiniciar el dispositivo, repite el helper. Para retirar solo ese túnel: `adb -s SERIAL reverse --remove tcp:3000`. El helper rechaza un flavor distinto de dev. Para staging: `flutter run --dart-define=EXOM_FLAVOR=staging`; para producción usa el release validado.

## Gates de release

`ci.yml` ejecuta pub get con lockfile, analyze, todos los tests y las regresiones del validador de metadata. Los workflows de ramas y PR prueban `github.sha`. `mobile-release.yml` llama al mismo CI mediante `./.github/workflows/ci.yml`; prepare depende de quality y ambos publicadores dependen de prepare. Todos los checkout fijan ese mismo SHA. Fallo o cancelación impide publicación; no se consulta un verde de otra rama.

Tras publicar Android/iOS y metadata se conserva `release-manifest` con SHA, versión y build durante 90 días. El workflow manual de metadata recibe `release_run_id`, exige un Mobile Release exitoso para el SHA seleccionado y verifica su manifiesto. Ya no permite introducir una versión/build arbitrarios. Si el manifiesto expiró o el release falló, recupera/rerun la finalización original; no sustituyas su identidad con otra rama. No ejecuta un nuevo envío a tiendas para modificar la política de actualización.

No se han publicado workflows, artefactos ni releases desde esta tarea. La ejecución real en macOS/firma/tiendas requiere el entorno y autorización de publicación existentes.

Referencia: [reutilización de workflows del mismo commit](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows).
