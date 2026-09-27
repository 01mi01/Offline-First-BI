// Valores inyectados en tiempo de compilación vía --dart-define-from-file.
// Ver config/dev.json (local) y config/prod.json.example (plantilla de producción).
class AppConfig {
  static const String seedUsername = String.fromEnvironment(
    'SEED_USER_USERNAME',
  );
  static const String seedUserEmail = String.fromEnvironment(
    'SEED_USER_EMAIL',
  );
  static const String seedUserPassword = String.fromEnvironment(
    'SEED_USER_PASSWORD',
  );
}
