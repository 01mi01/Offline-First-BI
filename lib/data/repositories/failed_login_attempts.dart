const int maxFailedLoginAttempts = 5;

class FailedLoginAttempts {
  final Map<String, int> _counts = {};

  int countFor(String username) => _counts[username] ?? 0;

  int registerFailure(String username) =>
      _counts[username] = countFor(username) + 1;

  void reset(String username) => _counts.remove(username);
}
