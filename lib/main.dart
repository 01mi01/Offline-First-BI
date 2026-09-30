import 'package:flutter/material.dart';
import 'config/app_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'application/auth_provider.dart';
import 'application/database_provider.dart';
import 'application/image_storage_provider.dart';
import 'theme/app_theme.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/navigation/main_navigation_page.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);

  final container = ProviderContainer();
  // Las imágenes que versiones anteriores dejaron en la caché (que Android
  // puede vaciar) pasan a la carpeta permanente. Un fallo aquí nunca debe
  // impedir que la aplicación abra.
  try {
    await container
        .read(imageStorageProvider)
        .migrateLegacyImages(container.read(databaseProvider));
  } catch (_) {}
  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Sistema de gestión para emprendimientos artísticos',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      // Textos propios de Material (selectores de fecha, botones, etc.) en
      // español, sin importar el idioma del dispositivo.
      locale: appLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      home: authState.isLoading
          // Pantalla de carga mientras se verifica la sesión
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : authState.user != null
              ? const MainNavigationPage()
              : const LoginPage(),
    );
  }
}