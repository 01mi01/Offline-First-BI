import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'application/auth_provider.dart';
import 'theme/app_theme.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
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
      home: authState.isLoading
          // Pantalla de carga mientras se verifica la sesión
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : authState.user != null
              ? const HomePage()
              : const LoginPage(),
    );
  }
}