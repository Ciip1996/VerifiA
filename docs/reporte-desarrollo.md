# VerifiA: Reporte Técnico de Desarrollo
## Token Criptográfico Efímero de Presencia para Verificación de Identidad en Tiempo Real

**Autor:** Carlos Iván Ibarra Pacheco · A01646019  
**Institución:** Instituto Tecnológico y de Estudios Superiores de Monterrey  
**Área:** Ciberseguridad  
**Tipo de proyecto:** Tesina / Proyecto integrador  
**Periodo de desarrollo:** Mayo 2026 (iteraciones activas)

---

## 1. Introducción y Contexto del Proyecto

VerifiA es un sistema de verificación de presencia física basado en tokens criptográficos efímeros. Su propósito es resolver el problema de la suplantación de identidad en entornos académicos y corporativos donde se requiere confirmar que una persona específica está físicamente presente en un momento y lugar determinados.

El sistema implementa un modelo de seguridad de múltiples capas inspirado en estándares industriales de autenticación fuerte: Apple App Attest para integridad del dispositivo, detección de presencia biométrica mediante liveness detection, Passkeys (FIDO2/WebAuthn) para autenticación criptográfica sin contraseña, y tokens JWT efímeros de corta vida útil como prueba portable de presencia.

Este documento constituye un registro técnico del proceso de desarrollo, documentando las decisiones de arquitectura, los obstáculos encontrados, las soluciones implementadas y las iteraciones sucesivas que llevaron al estado actual del sistema.

---

## 2. Arquitectura del Sistema

### 2.1 Estructura del Monorepo

El proyecto adopta una arquitectura de monorepo con tres aplicaciones diferenciadas y un paquete de tipos compartidos:

| Componente | Tecnología | Responsabilidad |
|------------|-----------|----------------|
| `apps/backend` | Node.js 20, Express, Prisma, PostgreSQL | API REST: desafíos, tokens, verificación de capas |
| `apps/portal` | React 18, Vite, TypeScript | Interfaz web del verificador (QR + polling) |
| `apps/mobile` | Flutter 3.x, Dart, Swift (MethodChannels) | Aplicación iOS del portador de credencial |
| `packages/shared` | TypeScript | Tipos compartidos de API entre backend y portal |

### 2.2 Flujo de Verificación

El flujo nominal del sistema involucra los siguientes pasos secuenciales:

```
[Portal Web] → Genera desafío (nonce hex 32 bytes)
     ↓
[QR Code] → Codifica: verifia://badge?nonce=<hex64>&verifier=<id>
     ↓
[App Móvil] → Escanea QR / recibe deep link → pantalla de confirmación
     ↓
[Capa 1 - Liveness ML Kit] → Detección de giro de cabeza (yaw) con cámara frontal
     ↓
[Capa 2 - Liveness FaceTec] → Verificación 3D anti-spoofing nivel industrial
     ↓
[Capa 3 - App Attest] → Assertion del Secure Enclave de Apple
     ↓
[Capa 4 - Passkey FIDO2] → Firma criptográfica con Face ID
     ↓
[Backend] → Valida las cuatro capas → Emite JWT ES256 (TTL 5 min)
     ↓
[Portal Web] → Polling detecta token → Muestra "Presencia Verificada"
```

### 2.3 Modelo de Token

El token de presencia es un JWT firmado con ES256 (ECDSA sobre P-256), con los siguientes claims:

```json
{
  "nonce": "<hex64>",
  "device_id": "<base64url>",
  "iat": 1748572800,
  "iss": "https://api.verifia.dev",
  "sub": "<user-id>",
  "aud": "<verifier-api-key>",
  "exp": 1748573100,
  "jti": "<uuid>"
}
```

El campo `jti` es de uso único, registrado en base de datos mediante Prisma, garantizando que cada token sea consumido una sola vez (propiedad de no-repudio y revocación automática por expiración).

---

## 3. Registro de Desarrollo: Iteraciones y Decisiones

### 3.1 Iteración 1 — Despliegue Inicial en Dispositivo Físico

**Objetivo:** Ejecutar la aplicación Flutter en un iPhone físico con la UI básica funcional.

**Problemas encontrados:**

**Problema 1.1 — Pantalla en negro al inicio**  
Al ejecutar la aplicación en el dispositivo físico, la UI mostraba una pantalla completamente negra sin elementos de interfaz. El proceso LLDB arrojaba los siguientes errores:

```
(Fig) signalled err=-12710 at <>:601
<<<< FigXPCUtilities >>>> signalled err=-17281 at <>:308
<<<< FigCaptureSourceRemote >>>> Fig assert: "err == 0" at bail
```

**Causa raíz:** Conflicto entre la configuración del `UIApplicationSceneManifest` y el `UIMainStoryboardFile` en `Info.plist`. Al utilizar `SceneDelegate` para ciclo de vida de la aplicación, la presencia simultánea de una referencia a storyboard causaba que el motor de Flutter no pudiera inicializar su superficie de renderizado correctamente.

**Solución:** Eliminación de la clave `UIMainStoryboardFile` del `Info.plist` y simplificación del `AppDelegate.swift` para delegar completamente el ciclo de vida a `SceneDelegate`. Esta decisión está documentada en las guías de integración de Flutter con iOS 15+.

**Problema 1.2 — Colgado del proceso de depuración**  
El comando `flutter run` se detenía indefinidamente en la fase "The Dart VM Service was not discovered", impidiendo el despliegue interactivo.

**Causa raíz:** Incompatibilidad entre el modo de depuración de Flutter con DDS (Dart Development Service) y la versión de Xcode/LLDB en iOS 26 beta.

**Solución:** Migración a modo release con `flutter run --release`, deshabilitación de la integración LLDB mediante `flutter config` y uso de `xcrun devicectl` para instalación y lanzamiento directo sin depurador:

```bash
xcrun devicectl device install app --device <UDID> build/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device <UDID> com.verifia.verifiaMobile
```

---

### 3.2 Iteración 2 — Integración de App Attest

**Objetivo:** Implementar la primera capa de seguridad: verificación de integridad del dispositivo mediante Apple App Attest.

**Descripción técnica:** Apple App Attest permite a un servidor verificar que una solicitud proviene de una instancia legítima de una aplicación específica ejecutándose en un dispositivo Apple auténtico. El flujo involucra:

1. Generación de un par de claves en el Secure Enclave (`DCAppAttestService.generateKey`)
2. Attestation del dispositivo enviando un hash del challenge al servidor de Apple
3. Registro de la clave pública ECDSA en el backend
4. Generación de assertions firmadas por el Secure Enclave en cada solicitud posterior

**Problema 2.1 — Fallo en parsing de cadena X.509**  
El backend rechazaba las attestations con el error:

```
PEM routines::no start line
Error: error:09091064:PEM routines::no start line
```

**Causa raíz:** El certificado de attestation de Apple se envía en formato DER (Distinguished Encoding Rules), no en PEM (Privacy Enhanced Mail). El módulo `crypto` de Node.js espera certificados en PEM para su función `X509Certificate()`, y la conversión DER→PEM requería el prefijo y sufijo correctos (`-----BEGIN CERTIFICATE-----`) con el contenido codificado en base64 en bloques de 64 caracteres.

**Solución:** Implementación de funciones auxiliares `toBuffer` y `derToPem` en `app-attest.ts`:

```typescript
function derToPem(derBuffer: Buffer): string {
  const b64 = derBuffer.toString('base64');
  const lines = b64.match(/.{1,64}/g)!.join('\n');
  return `-----BEGIN CERTIFICATE-----\n${lines}\n-----END CERTIFICATE-----`;
}
```

**Problema 2.2 — Validación de cadena de certificados en entorno de desarrollo**  
La validación completa de la cadena de certificados X.509 de Apple requería verificar la firma de cada certificado con la clave pública del certificado raíz de Apple App Attest CA. El módulo `crypto` de Node.js en la versión utilizada no proveía una API suficientemente madura para la verificación de cadenas de certificados DER complejas con extensiones OID personalizadas.

**Decisión de diseño (Dev Bypass):** Para el entorno de desarrollo y demostración, se implementó un bypass condicional de la validación de cadena de certificados, manteniendo las verificaciones críticas de AAGUID y relying party ID:

```typescript
const skipCertChain = isDevEnv;
if (skipCertChain) {
  publicKeyPem = 'DEV_SKIP_CERT_CHAIN';
  console.info(`[AppAttest] Dev mode — skipping cert chain for device ${deviceId}`);
}
```

**Implicación de seguridad:** Este bypass es exclusivo del entorno de desarrollo. En producción, la cadena completa debe validarse, idealmente utilizando una librería especializada como `@peculiar/x509` con soporte completo para extensiones de certificados Apple.

---

### 3.3 Iteración 3 — Evolución de la Detección de Presencia Biométrica (Liveness Detection)

Esta iteración representa el mayor número de ciclos de desarrollo y decisiones de arquitectura del proyecto, debido a la complejidad inherente de implementar liveness detection real en iOS con las restricciones de Flutter.

#### 3.3.1 Fase A — Stub de FaceTec

**Estado inicial:** La capa de liveness estaba completamente simulada mediante un temporizador de 2 segundos que devolvía datos falsos deterministas. El backend aceptaba estos datos en modo de desarrollo.

**Limitación:** Aunque funcional para el flujo de extremo a extremo, no cumplía con la propuesta académica de verificación biométrica real y era trivialmente vulnerable a ataques de replay.

#### 3.3.2 Fase B — Liveness Nativo con Vision Framework (Primera Implementación)

**Decisión:** Implementar detección de cara real utilizando el framework `Vision` de Apple a través de un `MethodChannel` Swift nativo, para evitar el overhead de dependencias Flutter externas.

**Implementación:** Se creó `LivenessChannel.swift` que utilizaba `AVCaptureSession` con `VNDetectFaceRectanglesRequest` para detección de rostros en tiempo real.

**Problema 3.1 — Crash al presentar la pantalla de liveness**  
La aplicación colapsaba inmediatamente al intentar presentar la pantalla de verificación post-escaneo de QR. El crash ocurría en el hilo principal al intentar inicializar una segunda `AVCaptureSession` cuando el plugin `mobile_scanner` ya tenía una sesión activa.

**Causa raíz:** iOS no permite múltiples `AVCaptureSession` activas simultáneamente en la mayoría de los dispositivos. El ciclo de vida del widget `MobileScanner` mantenía la sesión activa incluso cuando la pantalla de QR no era visible.

**Problema 3.2 — Incompatibilidades con iOS 26 beta**  
El framework `Vision` en iOS 26 (primera beta pública) presentaba comportamientos no documentados con `VNDetectFaceRectanglesRequest` en el contexto de una aplicación Flutter con múltiples niveles de ventana.

**Decisión:** Abandono del enfoque nativo de Vision framework para la detección de liveness en la pantalla de QR, optando por una solución puramente Flutter.

#### 3.3.3 Fase C — Liveness Animado (Simulación Flutter)

**Implementación temporal:** Pantalla Flutter con animaciones de instrucciones y un temporizador de 3 segundos para cada "fase" del challenge, sin detección facial real.

**Resultado:** Flujo estable sin crashes. Usado como base para continuar el desarrollo de las otras capas mientras se investigaba una alternativa de liveness real.

#### 3.3.4 Fase D — Liveness Real con ML Kit (Google)

**Decisión técnica:** Uso de `google_mlkit_face_detection` como paquete Flutter nativo para procesamiento en dispositivo, sin dependencia de servicios en la nube.

**Fundamento de la elección:** El paquete provee el ángulo de Euler en el eje Y (yaw) del rostro detectado, permitiendo implementar un challenge de movimiento (girar la cabeza) que distingue a una persona real de una foto estática o un video reproducido de frente.

**Implementación del state machine:**

```
Estado 1: Center  → |yaw| < 15°  durante 45 frames (~1.5s a 30fps)
Estado 2: Turn    → |yaw| > 20°  durante 10 frames
Estado 3: Return  → |yaw| < 15°  durante 10 frames
Estado 4: Done    → Éxito → navegación a siguiente capa
```

**Problema 3.3 — Incompatibilidad de ML Kit con iOS 26 arm64**  
Las dependencias de CocoaPods de ML Kit (`GoogleMLKit`, `MLKitCommon`, `MLKitFaceDetection`, `MLKitVision`) no incluían soporte para la arquitectura `arm64` requerida por los simuladores de Apple Silicon en iOS 26. El error en la fase de linking:

```
The following target(s) do not support arm64 architecture:
  - GoogleMLKit (transitive dependency of google_mlkit_face_detection)
```

**Aclaración:** Este error solo afecta a simuladores. El dispositivo físico (iPhone con arquitectura arm64 real) compila y funciona correctamente. Para producción, el impacto es nulo.

**Problema 3.4 — Requerimiento de versión mínima de iOS**  
ML Kit requería `platform :ios, '15.5'` como mínimo, mientras que el `Podfile` del proyecto especificaba `'15.0'`.

**Solución:** Actualización de `platform :ios, '15.0'` a `platform :ios, '15.5'` en `Podfile`. Este cambio no afecta a los dispositivos objetivos del proyecto (iPhone 12 o posterior con iOS 15.5+).

**Retroalimentación adicional — Feedback sensorial en transiciones**  
Se identificó que las transiciones entre estados del challenge de liveness no generaban ningún feedback perceptible para el usuario en modo silencioso. El usuario reportó: "no se escucha ni bip ni vibración".

**Causa raíz:** Las llamadas a `HapticFeedback.vibrate()` y `SystemSound.play()` se realizaban en el hilo de procesamiento de frames de cámara, no en el hilo principal de UI.

**Solución:** Encapsulamiento en `WidgetsBinding.instance.addPostFrameCallback`:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  _biometricsChannel.invokeMethod<bool>('playSuccess').catchError((_) {
    HapticFeedback.vibrate();
    return false;
  });
});
```

**Implementación nativa de audio (BiometricsChannel.swift):** Para superar las limitaciones del modo silencioso del iPhone en los sonidos del sistema Flutter, se implementó en Swift:

```swift
AudioServicesPlayAlertSoundWithCompletion(1109, nil) // "Glass" chime
UINotificationFeedbackGenerator().notificationOccurred(.success) // Taptic Engine
```

`AudioServicesPlayAlertSoundWithCompletion` reproduce el sonido a volumen de alerta (mayor que el de aplicación), funcionando incluso con el volumen de medios al mínimo.

---

### 3.4 Iteración 4 — Integración de FaceTec SDK

**Motivación:** El sistema Nubank y otras aplicaciones fintech de referencia utilizan sistemas de liveness detection de nivel industrial que realizan no solo verificación de movimiento sino anti-spoofing 3D mediante análisis de profundidad y textura facial. Se evaluaron las opciones disponibles:

| Solución | Acceso gratuito | Plugin Flutter oficial | Anti-spoofing |
|----------|----------------|----------------------|---------------|
| iProov | Trial 250 tx / 4 semanas | No | Illumination challenge (servidor) |
| FaceTec | Developer Account gratuita | No (bridge manual) | Depth map 3D |
| AWS Rekognition | 1,000 sesiones/mes (capa gratuita) | Sí (Amplify) | Illumination challenge (nube) |

**Decisión:** FaceTec, por ser la tecnología citada en el marco teórico de la propuesta y por proveer acceso de desarrollo gratuito e inmediato en [dev.facetec.com](https://dev.facetec.com).

#### 3.4.1 Proceso de Integración del SDK

**Paso 1 — Descarga del SDK**  
FaceTec provee dos variantes del xcframework:
- `FaceTecSDK.xcframework` — para producción (con licencia comercial)
- `FaceTecSDKForDevelopment.xcframework` — para desarrollo (incluye watermark "Developer Mode")

Se utilizó la variante de desarrollo, generada mediante el Configuration Wizard de `dev.facetec.com` que también genera el archivo `Config.swift` con las claves de inicialización específicas para la cuenta de desarrollador.

**Paso 2 — Primer intento: integración via CocoaPods**  
Se creó un `FaceTecSDK.podspec` local con `vendored_frameworks` apuntando al xcframework, y se referenció desde el `Podfile`. El resultado del `pod install` fue exitoso, pero el build de Xcode falló:

```
Error (Xcode): Framework 'FaceTecSDKForDevelopment' not found
```

**Causa raíz:** El warning de CocoaPods durante la instalación advirtió que no pudo establecer la configuración base del proyecto porque Flutter ya tiene xcconfig customizadas. Esto impidió que las rutas de búsqueda de frameworks (`FRAMEWORK_SEARCH_PATHS`) generadas por CocoaPods se aplicaran al target de compilación. El xcframework se listaba correctamente en los paths pero `PODS_XCFRAMEWORKS_BUILD_DIR` no se resolvía en el contexto del build de Flutter.

**Paso 3 — Integración directa en project.pbxproj**  
Se abandonó el enfoque de CocoaPods y se añadió el xcframework directamente al proyecto Xcode editando `project.pbxproj`:

1. **PBXFileReference** — referencia al archivo con `sourceTree = SOURCE_ROOT` (path relativo al directorio del proyecto `.xcodeproj`):
   ```
   F5060706D1CB4500515815AE /* FaceTecSDKForDevelopment.xcframework */
   ```

2. **PBXBuildFile (Link)** — para la fase de linking:
   ```
   F6071807E2DC5601626927B0 /* FaceTecSDKForDevelopment.xcframework in Frameworks */
   ```

3. **PBXBuildFile (Embed)** — para la fase de copia y firma del bundle:
   ```
   F7082908E3ED6712737A38C1 /* FaceTecSDKForDevelopment.xcframework in Embed Frameworks */
   settings = {ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }
   ```

4. **PBXFrameworksBuildPhase** — añadir la referencia al target Runner
5. **PBXCopyFilesBuildPhase** (Embed Frameworks) — para que el xcframework sea copiado firmado al bundle final
6. **PBXGroup** — añadir la referencia al grupo del proyecto para visibilidad en Xcode

**Error adicional — sourceTree incorrecto**  
El primer intento usó `sourceTree = "<group>"`, que hace la ruta relativa al grupo padre en el proyecto. Como el xcframework se añadió al grupo Runner (que está en `ios/Runner/`), Xcode buscaba el framework en `ios/Runner/FaceTecSDKForDevelopment.xcframework`, donde no existía:

```
Error (Xcode): There is no XCFramework found at
'/Users/.../apps/mobile/ios/Runner/FaceTecSDKForDevelopment.xcframework'
```

**Solución:** Cambio a `sourceTree = SOURCE_ROOT`, que hace la ruta relativa al directorio del proyecto (`ios/`), donde sí existe `FaceTecSDKForDevelopment.xcframework`.

**Paso 4 — Errores de API de Swift**  
Al compilar `FaceTecChannel.swift`, el compilador reportó cambios en la API del SDK v9.7.123:

```
Swift Compiler Error: Incorrect argument label in call (have 'with:', expected 'for:')
Swift Compiler Error: 'onFaceScanResultProceedToNextStep' has been renamed to 
                      'onFaceScanGoToNextStep(scanResultBlob:)'
```

**Solución:** Actualización de las llamadas a la API:
```swift
// Antes:
FaceTec.sdk.description(with: FaceTec.sdk.getStatus())
faceScanResultCallback.onFaceScanResultProceedToNextStep(blob)

// Después:
FaceTec.sdk.description(for: FaceTec.sdk.getStatus())
faceScanResultCallback.onFaceScanGoToNextStep(scanResultBlob: blob)
```

#### 3.4.2 Arquitectura del Canal FaceTec-Flutter

Se implementó el `FaceTecChannel` como una clase Swift que expone un `MethodChannel` con el identificador `verifia/facetec`:

**Flujo de una sesión de liveness FaceTec:**

1. Al registrar el canal en `AppDelegate.swift`, se inicializa el SDK en modo desarrollo con las claves del developer account.
2. Al recibir `startLiveness` desde Dart, el canal realiza un `GET` a `https://api.facetec.com/api/v3.1/biometrics/session-token` con los headers `X-Device-Key` y `User-Agent` requeridos.
3. Con el session token, se instancia un `FaceTecLivenessProcessor` que llama a `FaceTec.sdk.createSessionVC()` y presenta el ViewController de forma modal sobre el FlutterViewController raíz.
4. El SDK presenta su interfaz nativa de detección 3D (óvalo facial + anti-spoofing).
5. En `processSessionWhileFaceTecSDKWaits`, se envía el `faceScanBase64` al endpoint `/liveness-3d` del servidor de FaceTec para obtener el `scanResultBlob`.
6. Con el blob, se llama a `faceScanGoToNextStep(scanResultBlob:)` para que el SDK muestre la animación de éxito.
7. En `onFaceTecSDKCompletelyDone`, se retorna el resultado a Dart via el `FlutterResult` callback.

**Gestión de referencias (memory management):**  
La instancia de `FaceTecLivenessProcessor` necesita mantenerse viva durante toda la sesión. Se utilizó `objc_setAssociatedObject` para asociar el processor al ViewController raíz, evitando que el ARC (Automatic Reference Counting) de Swift lo libere prematuramente:

```swift
objc_setAssociatedObject(rootVC, &FaceTecChannel.processorKey, 
                         processor, .OBJC_ASSOCIATION_RETAIN)
```

---

### 3.5 Iteración 5 — Integración de Passkeys (FIDO2/WebAuthn)

**Descripción técnica:** Los Passkeys implementan el estándar FIDO2/WebAuthn usando criptografía de clave pública. La clave privada nunca abandona el Secure Enclave del dispositivo; solo se exporta una firma sobre el challenge del servidor, verificable con la clave pública registrada.

**Problema 5.1 — PASSKEY_CHALLENGE_MISMATCH**  
El backend rechazaba las assertions de passkey con el error `PASSKEY_CHALLENGE_MISMATCH`.

**Causa raíz:** El challenge se enviaba del backend como base64url con padding (`=`), pero la especificación WebAuthn requiere base64url sin padding. La biblioteca `@simplewebauthn/server` en el backend construye el challenge esperado sin padding, mientras que la implementación en Dart incluía el padding.

**Solución:** Remoción del padding en `passkey_service.dart`:

```dart
// Antes:
final challenge = base64Url.encode(utf8.encode(nonce));

// Después (sin padding):
final challenge = base64Url.encode(utf8.encode(nonce)).replaceAll('=', '');
```

**Problema 5.2 — Verificación ECDSA en modo desarrollo**  
La verificación FIDO2 completa requiere: (1) verificación de la firma ECDSA sobre `clientDataJSON + authenticatorData`, (2) verificación del `rpId` contra el dominio registrado, (3) verificación de los flags de autenticación de usuario.

Para el entorno local sin dominio HTTPS registrado, la verificación de firma ECDSA y rpId fue diferida mediante un bypass de desarrollo:

```typescript
// Dev bypass: verify only the challenge field, skip ECDSA
if (!process.env.PASSKEY_RP_ID) {
  console.warn('[Passkeys] Dev mode — skipping FIDO2 verification');
  // Verify challenge matches nonce
  const clientData = JSON.parse(Buffer.from(payload.clientDataJSON, 'base64url').toString());
  if (clientData.challenge !== nonce) throw new AppError(400, 'PASSKEY_CHALLENGE_MISMATCH');
  return { verified: true };
}
```

---

### 3.6 Iteración 6 — Portal Web y Deep Links

#### 3.6.1 Bug: Estado "Escaneado" Prematuro

**Síntoma:** El portal mostraba el estado "QR escaneado" sin que se hubiera realizado ningún escaneo real, inmediatamente después de generar el desafío.

**Causa raíz:** La lógica de polling en `BadgeValidator.tsx` interpretaba incorrectamente la respuesta `NOT_FOUND` del endpoint de validación de tokens:

```typescript
// Lógica incorrecta:
if (res.status === 'NOT_FOUND') {
  if (status === 'waiting') setStatus('scanning'); // BUG: transición prematura
}
```

`NOT_FOUND` significa que aún no existe ningún token para ese nonce (estado esperado durante el periodo de espera). La transición a `'scanning'` debería ocurrir solo cuando el backend retorna `ISSUED`, indicando que la app móvil ya procesó el QR.

**Solución:** Eliminación de la transición prematura en el bloque `NOT_FOUND`.

#### 3.6.2 Deep Links: Apertura de App desde Safari

**Requerimiento:** El profesor debería poder enviar el link de verificación directamente al alumno (por WhatsApp, correo, etc.), y al tocarlo, la app debería abrirse y proceder directamente al flujo de verificación.

**Implementación — Registro del URL Scheme:**  
El scheme `verifia://` estaba registrado en `Info.plist` desde el inicio del proyecto via `CFBundleURLTypes`. Esto permite que iOS reconozca URLs con ese scheme y abra la aplicación correspondiente.

**Problema 6.1 — App se abre pero no procesa la URL**  
Al pegar `verifia://badge?nonce=...` en Safari y confirmar la apertura de la app, la aplicación se iniciaba en la pantalla principal del escáner QR sin navegar automáticamente al flujo de verificación.

**Causa raíz:** Aunque el URL scheme estaba registrado, la aplicación no tenía ningún código para leer la URL que la abrió (`getInitialLink`) ni para escuchar nuevas URLs mientras está activa (`uriLinkStream`).

**Solución — Paquete `app_links`:**  
Se integró el paquete `app_links` (estándar moderno para manejo de deep links en Flutter) y se refactorizó `VerifiAApp` de `StatelessWidget` a `StatefulWidget` para gestionar el ciclo de vida del listener:

```dart
Future<void> _initDeepLinks() async {
  final appLinks = AppLinks();
  
  // Cold start: app cerrada, abierta via link
  final initial = await appLinks.getInitialLink();
  if (initial != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleDeepLink(initial));
  }
  
  // Hot: app ya abierta, nuevo link recibido
  _linkSub = appLinks.uriLinkStream.listen(_handleDeepLink);
}
```

Se añadió un `GlobalKey<NavigatorState>` para permitir la navegación programática desde fuera del árbol de widgets:

```dart
void _handleDeepLink(Uri uri) {
  if (uri.scheme != 'verifia' || uri.host != 'badge') return;
  final nonce = uri.queryParameters['nonce'];
  if (nonce == null || nonce.length != 64) return;
  
  final navigator = _navigatorKey.currentState;
  navigator?.popUntil((route) => route.isFirst);
  navigator?.push(MaterialPageRoute(
    builder: (_) => PresenceChallengeScreen(nonce: nonce, verifierId: verifierId),
  ));
}
```

---

### 3.7 Iteración 7 — Capa de Identidad del Portal (Botón Copiar Link)

**Requerimiento:** El verificador (profesor) necesita una forma de compartir el link de verificación con el verificado (alumno) sin requerir que este escanee físicamente el código QR.

**Implementación:** Adición de un botón "Copiar link" en `BadgeValidator.tsx` que copia `challenge.qr_data` al portapapeles del navegador usando la API `navigator.clipboard.writeText()`.

El link copiado tiene el formato:
```
verifia://badge?nonce=<hex64>&verifier=<verifier-api-key>
```

---

## 4. Decisiones de Arquitectura y Trade-offs

### 4.1 Monorepo con Workspace de npm

**Decisión:** Estructurar el proyecto como un monorepo con un `package.json` raíz que configura workspaces de npm para `apps/backend`, `apps/portal` y `packages/shared`.

**Justificación:** Permite compartir tipos TypeScript entre el backend y el portal sin duplicación, garantizando consistencia de los contratos de API en tiempo de compilación.

### 4.2 Uso de MethodChannels de Flutter vs. Paquetes de Flutter

**Decisión:** Implementar las integraciones nativas (App Attest, Passkeys, FaceTec, BiometricsChannel) como MethodChannels Swift en lugar de usar paquetes Flutter de terceros.

**Justificación:** 
- Los paquetes existentes para App Attest y Passkeys en pub.dev tienen soporte limitado y no cubren el flujo específico requerido
- Los MethodChannels permiten control total sobre el ciclo de vida de las sesiones nativas
- La integración con APIs privadas de Apple (Secure Enclave, AuthenticationServices) es más directa desde Swift
- FaceTec no provee un plugin Flutter oficial; el bridge nativo es la única opción soportada

**Trade-off:** Mayor complejidad de mantenimiento al tener código en dos lenguajes (Dart y Swift) que deben mantenerse sincronizados.

### 4.3 JWT firmado con ES256 vs. RS256

**Decisión:** Usar ECDSA (ES256) con curva P-256 en lugar de RSA (RS256) para firmar los tokens.

**Justificación:** ES256 produce firmas más compactas (64 bytes vs. 256+ bytes para RSA-2048), es más eficiente computacionalmente en dispositivos móviles, y es el algoritmo preferido en la especificación WebAuthn/FIDO2. Las claves se almacenan en PEM y se cargan mediante la función `loadPem()` que normaliza saltos de línea literales `\n` en el archivo `.env`.

### 4.4 Nonce como Hex64 vs. UUID

**Decisión:** Representar el nonce del desafío como 64 caracteres hexadecimales (32 bytes de entropía) en lugar de UUID (122 bits de entropía).

**Justificación:** 32 bytes de entropía (256 bits) superan significativamente el umbral de seguridad requerido para tokens de desafío de un solo uso. El formato hexadecimal facilita la inclusión en URLs (sin caracteres que requieran codificación) y la validación mediante expresión regular simple.

### 4.5 Diseño de Flujo de Liveness Dual

**Decisión:** Implementar dos capas de liveness detection: ML Kit (detección de movimiento en dispositivo) seguida de FaceTec (anti-spoofing 3D mediante servidor).

**Justificación:** Cada capa provee garantías ortogonales:
- **ML Kit:** Verifica que el usuario está presente físicamente y puede ejecutar un gesto voluntario. Completamente on-device, sin dependencias de red.
- **FaceTec:** Provee anti-spoofing de nivel industrial contra presentación de fotos, videos pregrabados y máscaras 3D. Verificación en servidor con modelo de IA especializado.

**Trade-off:** La latencia total del flujo de verificación aumenta (~3-5 segundos adicionales por la sesión FaceTec + round-trip al servidor). Esto debe evaluarse contra el KPI de latencia total < 5 segundos definido en los casos de prueba de aceptación.

---

## 5. Estado de Implementación y Brechas Identificadas

### 5.1 Capas Implementadas (Funcionales en Demo)

| Capa | Implementación | Estado en Demo |
|------|---------------|----------------|
| Challenge QR | Backend + Portal | ✅ Completo y real |
| Liveness ML Kit | Flutter + ML Kit | ✅ Real (on-device) |
| Liveness FaceTec | Swift MethodChannel + SDK v9.7.123 | ✅ Real (servidor FaceTec dev) |
| App Attest | Swift + Node.js `crypto` | ⚠️ Parcial (cert chain bypassed) |
| Passkey FIDO2 | Swift `AuthenticationServices` + `@simplewebauthn/server` | ⚠️ Parcial (ECDSA bypassed) |
| JWT ES256 | `jose` (Node.js) | ✅ Completo y real |
| Token único (JTI) | Prisma + PostgreSQL | ✅ Completo y real |
| Portal validación | React + polling | ✅ Completo y real |
| Deep links | `app_links` Flutter | ✅ Completo y real |

### 5.2 Brechas para Producción

Las siguientes brechas son conocidas y documentadas explícitamente como trabajo futuro para una implementación de producción:

1. **App Attest — Validación de cadena X.509:** Requiere librería especializada o implementación custom para verificar la cadena completa de certificados Apple App Attest CA → Intermediate → Leaf.

2. **Passkeys — Verificación ECDSA completa:** Requiere un dominio registrado con HTTPS para configurar el `rpId`, y la verificación criptográfica completa de la firma ECDSA sobre `authenticatorData`.

3. **FaceTec — Server SDK:** La validación del `faceScanBase64` actualmente se delega al servidor de desarrollo de FaceTec. En producción, el Server SDK de FaceTec (requiere acuerdo comercial) debe desplegarse en la infraestructura propia.

4. **Almacenamiento de identidad:** No existe actualmente un perfil de usuario persistente asociado al `device_id`. La identidad mostrada en el portal es genérica.

---

## 6. Métricas del Sistema

### 6.1 Volumen de Código (líneas de código)

| Archivo / Módulo | LOC |
|-----------------|-----|
| `presence_challenge_screen.dart` | 609 |
| `liveness_screen.dart` (ML Kit) | 495 |
| `LivenessChannel.swift` | 436 |
| `PasskeyChannel.swift` | 281 |
| `app-attest.ts` (backend service) | 331 |
| `tokens.ts` (backend route) | 251 |
| `FaceTecChannel.swift` | 263 |
| `passkeys.ts` (backend service) | 182 |
| **Total (archivos clave)** | **~5,600** |

### 6.2 Dependencias Principales

**Backend:**
- `express`, `prisma`, `@prisma/client` — servidor HTTP y ORM
- `jose` — firma y verificación de JWT ES256
- `cbor2` — parsing de datos CBOR (App Attest attestation)
- `@simplewebauthn/server` — validación WebAuthn/FIDO2
- `zod` — validación de esquemas de entrada

**Portal:**
- `react`, `vite`, `typescript` — framework y tooling
- `qrcode.react` — generación de QR

**Mobile:**
- `camera` — acceso a cámara frontal para ML Kit
- `google_mlkit_face_detection` — detección facial on-device
- `flutter_secure_storage` — almacenamiento de claves en Keychain
- `app_links` — manejo de deep links
- `FaceTecSDKForDevelopment.xcframework` — liveness 3D (nativo)

---

## 7. Casos de Uso Documentados

### CU-01: Verificación de Asistencia Académica

**Actor:** Profesor (verificador) + Alumno (portador)  
**Precondición:** Alumno tiene la app VerifiA instalada y dispositivo registrado  
**Flujo:**
1. Profesor accede al portal y genera un desafío
2. El portal muestra el código QR y habilita la opción "Copiar link"
3. Profesor comparte el link por WhatsApp/correo al alumno, O el alumno escanea el QR directamente
4. Alumno abre el link → app abre en pantalla de confirmación mostrando el nombre del verificador
5. Alumno toca "Verificar mi presencia" → pasa por Liveness ML Kit + FaceTec 3D + Face ID
6. Backend emite JWT → portal muestra "Presencia Verificada" con timestamp
7. El JWT expira en 5 minutos y no puede reutilizarse (JTI único)

### CU-02: Detección de Suplantación

**Escenario de ataque:** Alumno A intenta verificar la presencia del alumno B usando su sesión abierta  
**Mitigación 1 (App Attest):** El assertion está vinculado al device_id del dispositivo registrado de B. Ejecutarlo desde el dispositivo de A fallaría la validación del Secure Enclave  
**Mitigación 2 (Liveness):** ML Kit y FaceTec verifican presencia física de quien sostiene el teléfono  
**Mitigación 3 (Passkey):** Face ID/Touch ID solo puede ser autorizado por el dueño biométrico del dispositivo  
**Mitigación 4 (Nonce):** El QR/link es de un solo uso; intentar reutilizarlo retorna `NONCE_USED`

---

## 8. Conclusiones del Proceso de Desarrollo

El desarrollo de VerifiA ha evidenciado la complejidad inherente de integrar múltiples capas de seguridad criptográfica en un sistema móvil multiplataforma. Los principales aprendizajes técnicos son:

1. **La brecha entre teoría y API real:** Las especificaciones FIDO2 y Apple App Attest son complejas y sus implementaciones de referencia en ecosistemas no-nativos (Node.js) requieren un entendimiento profundo de formatos binarios (DER, CBOR, ASN.1) que no son evidentes en la documentación de alto nivel.

2. **Flutter/iOS: el costo de la abstracción:** El motor de Flutter introduce restricciones no documentadas en el uso de APIs nativas de iOS (AVCaptureSession, Vision framework) que solo se manifiestan en dispositivos físicos. El debugging requiere un entendimiento profundo de ambos mundos.

3. **El entorno de desarrollo como primera-ciudadano:** Diseñar bypasses de seguridad explícitos y rastreables para entornos de desarrollo (en lugar de comentar código) resulta en un sistema más mantenible y menos propenso a llevar configuraciones inseguras a producción accidentalmente.

4. **Iteración como metodología:** El estado final del sistema es significativamente más robusto y complejo que el diseño inicial. Cada iteración reveló casos borde y restricciones que no eran anticipables sin implementación real.

---

*Documento en desarrollo — se actualiza conforme avanzan las iteraciones del proyecto.*  
*Última actualización: Mayo 2026*
