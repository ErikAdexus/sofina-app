# Sofina — App de citas y gestión de especialistas

Aplicación de agendamiento de citas para servicios a domicilio (belleza y bienestar), desarrollada como proyecto freelance. Compuesta por dos apps Flutter independientes sobre un backend compartido en Firebase.

## Arquitectura

- **proyectocitas1** — App Admin/Especialistas
- **proyectocitas2** — App Cliente
- Backend único en Firebase (Realtime Database, Cloud Functions, Storage, Auth, App Check)
- Ambas apps comparten el mismo proyecto Firebase y se comunican a través de la base de datos en tiempo real

## Capturas

<!-- Reemplaza estos placeholders con tus capturas reales del celular -->
| Registro de especialista (wizard) | Detalle de cita |
|---|---|
| ![Wizard de registro](docs/screenshots/wizard-registro.png) | ![Detalle de cita](docs/screenshots/detalle-cita.png) |

## Funcionalidades principales

- **Registro de especialistas en 4 pasos**: datos personales, perfil profesional, documento de identidad (DNI/Carné de Extranjería con validación cruzada contra RENIEC vía API pública) y datos bancarios
- **Disponibilidad de especialistas**: horario base semanal + excepciones puntuales
- **Sistema de calificaciones**: resumen recalculado server-side vía Cloud Functions, protegido contra manipulación desde el cliente
- **Login biométrico** con tokens de confianza de dispositivo
- **Chatbot con IA** (Gemini + function calling) para la reserva de citas, con RAG sobre el catálogo de servicios
- **Firebase App Check** para proteger el backend contra tráfico no autorizado
- **Reglas de seguridad RBAC** con validación de máquina de estados sobre el ciclo de vida de una cita, incluyendo protección contra escritura de campos privilegiados vía reglas .validate (no solo .write anidado)

## Stack técnico

Flutter · Firebase (Realtime Database, Cloud Functions Node.js 2nd gen, Storage, Auth, App Check) · Gemini API

## Configuración local

Para correr el proyecto localmente necesitas tu propio `google-services.json` / `GoogleService-Info.plist` de un proyecto Firebase (no incluidos en este repo).

La validación de documento de identidad usa la API pública de [apiperu.dev](https://apiperu.dev) (plan gratuito). Necesitas tu propio token, pasado como variable de compilación — **nunca lo escribas en el código**:

```bash
flutter run --dart-define-from-file=dart_defines.json
```

(crea tu propio `dart_defines.json` local con `{"DNI_API_TOKEN": "tu_token"}`, ya está en `.gitignore`)

## Nota

Proyecto freelance desarrollado de forma independiente. El código se comparte con fines de portafolio.
