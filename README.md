# Offline-FirstBI

## Descripción
Aplicación móvil Full Stack con enfoque Offline-First orientada a Business Intelligence para el registro y control de las operaciones comerciales de emprendimientos artísticos. La aplicación permite la gestión de productos, categorías, materiales, ventas, compras, proveedores, clientes, eventos y ubicaciones, generando reportes exportables y un panel de Business Intelligence con indicadores clave y vistas guardadas.

## Objetivo general
Diseñar y desarrollar una aplicación móvil Full Stack para el registro y control de las operaciones comerciales de emprendimientos artísticos, incorporando Business Intelligence y un enfoque Offline-First con medidas de seguridad para garantizar la integridad y confidencialidad de los datos.

## Objetivos específicos 
- Backend: Configuración inicial de las carpetas del proyecto con Clean Architecture y Riverpod. Implementación de la base de datos local con Drift y configuración de la base de datos en Supabase.
- Frontend: Implementación del inicio de sesión con credenciales, cierre de sesión y cierre automático de sesión por inactividad.
- Flujo 1: El administrador inicia sesión con sus credenciales y gestiona los usuarios de la aplicación, incluyendo la creación, edición, bloqueo y desbloqueo de usuarios.
- Flujo 2: Un usuario creado por el administrador inicia sesión con sus credenciales y es bloqueado al superar el límite de intentos fallidos. El administrador desbloquea la cuenta desde el módulo de gestión de usuarios para que el usuario pueda volver a acceder, o bien bloquea manualmente una cuenta activa impidiendo el acceso hasta que el administrador la restablezca.
- Flujo 3: El administrador define los permisos de acceso por módulo para un usuario desde el módulo de permisos de acceso y el usuario inicia sesión para verificar que el menú de navegación refleja únicamente los módulos habilitados por el administrador.

## Alcance

### Incluye
- CRUD completo de productos, categorías, materiales, ventas, compras, clientes, proveedores, eventos y ubicaciones
- Reportes exportables en PDF y Excel
- Panel de Business Intelligence con vistas guardadas
- Autenticación con 2FA opcional y soporte offline
- Gestión de usuarios y permisos individuales por módulo
- Módulo de auditoría
- Tema claro y oscuro
- Sincronización automática con la nube

### No incluye
- Notificaciones
- Procesamiento de pagos o integración con sistemas bancarios

## Stack tecnológico
- Frontend: Flutter + Dart
- Gestión del estado: Riverpod
- Base de datos local: Drift (SQLite)
- Backend: Supabase (PostgreSQL)
- Seguridad: Flutter Secure Storage + Android Keystore + Google Authenticator (TOTP)
- Control de versiones: Git + GitHub

## Arquitectura
Flutter (Android) → Drift (SQLite local) → Supabase (PostgreSQL nube)

## Módulos core (priorizados)
- Autenticación (inicio de sesión online y offline, bloqueo de cuenta, cierre de sesión)
- Gestión de usuarios (registro, edición, bloqueo, desbloqueo, restablecimiento de contraseña)
- Permisos de acceso individuales por usuario y por módulo

## Cómo ejecutar el proyecto

1. Clonar el repositorio
```bash
git clone https://github.com/01mi01/Offline-First-BI
```

2. Instalar las dependencias
```bash
flutter pub get
```

3. Crear un archivo `.env` en la raíz del proyecto con las siguientes variables de entorno:
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

4. Ejecutar la aplicación
```bash
flutter run
```

## Variables de entorno
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

## Equipo
- 01mi01: Full Stack Dev
