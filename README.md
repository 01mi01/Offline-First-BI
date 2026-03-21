# Offline-FirstBI 

## Descripción 
Aplicación móvil Full Stack con enfoque Offline-First orientada a Business Intelligence para el registro y control de las operaciones comerciales de emprendimientos artísticos. La aplicación permite la gestión de productos, categorías, materiales, ventas, compras, proveedores, clientes, eventos y ubicaciones, generando reportes exportables y un panel de Business Intelligence con indicadores clave y vistas guardadas. 

## Objetivo general 
Diseñar y desarrollar una aplicación móvil Full Stack para el registro y control de las operaciones comerciales de emprendimientos artísticos, incorporando Business Intelligence y un enfoque Offline-First con medidas de seguridad para garantizar la integridad y confidencialidad de los datos. 

## Objetivos específicos 
- Backend: Configuración inicial del proyecto con Clean Architecture y Riverpod. Implementación de la base de datos local utilizando Drift (SQLite). 
- Base de datos: Implementación de la base de datos local con las tablas users, roles, categories, products, materials, product_materials, sales, sale_items, purchases, purchase_items, suppliers, clients, events y locations, garantizando almacenamiento, recuperación y actualización correcta de los datos desde la aplicación. 
- Flujo 1: Registro de productos desde la aplicación móvil y verificación de que los datos se almacenan correctamente en la base de datos local. 
- Flujo 2: Registro de ventas seleccionando productos del inventario, cálculo automático del total y actualización automática del stock. 
- Flujo 3: Generación de reportes filtrados por fecha o producto a partir de la información almacenada en la base de datos local. 

## Alcance 

### Incluye 
- Base de datos local con SQLite mediante Drift 
- CRUD completo de productos, categorías, materiales, ventas, compras, clientes, proveedores, eventos y ubicaciones 
- Reportes exportables en PDF y Excel 

### No incluye (por ahora) 
- Panel de Business Intelligence con vistas guardadas 
- Autenticación con 2FA
- Gestión de usuarios y permisos individuales por módulo 
- Módulo de auditoría 
- Tema claro y oscuro 
- Sincronización automática con la nube 

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
- Gestión de inventario (registro, edición, desactivación, control de stock)
- Gestión de materiales (registro, edición y control de stock)
- Registro de ventas (selección de productos, cantidades, cálculo de total, actualización automática de stock)
- Registro de compras (registro de materiales, gastos y proveedores)
- Gestión de clientes, proveedores, eventos y ubicaciones
- Reportes filtrados por fecha, producto o evento con exportación en PDF o Excel

## Cómo ejecutar el proyecto

1. Clonar el repositorio

```bash
git clone https://github.com/01mi01/Offline-First-BI
```

2. Instalar las dependencias

```bash
flutter pub get
```

3. Generar archivos necesarios (.g.dart)

```bash
dart run build_runner build --delete-conflicting-outputs
```

4. Ejecutar la aplicación

```bash
flutter run
```

## Equipo 
- 01mi01: Full Stack Dev