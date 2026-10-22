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
