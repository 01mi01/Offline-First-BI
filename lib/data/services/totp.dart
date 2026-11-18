import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

const int totpDigits = 6;
const int totpPeriodSeconds = 30;
const int totpAllowedDriftSteps = 1;
const int totpSecretBytes = 20;

const String _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

String base32Encode(List<int> bytes) {
  final out = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final byte in bytes) {
    buffer = (buffer << 8) | (byte & 0xff);
    bits += 8;
    while (bits >= 5) {
      out.write(_base32Alphabet[(buffer >> (bits - 5)) & 31]);
      bits -= 5;
    }
  }
  if (bits > 0) out.write(_base32Alphabet[(buffer << (5 - bits)) & 31]);
  return out.toString();
}

Uint8List base32Decode(String input) {
  final clean = input.toUpperCase().replaceAll(RegExp(r'[\s=-]'), '');
  final out = <int>[];
  var buffer = 0;
  var bits = 0;
  for (final char in clean.split('')) {
    final value = _base32Alphabet.indexOf(char);
    if (value < 0) throw FormatException('Invalid base32 character', input);
    buffer = ((buffer << 5) | value) & 0xffff;
    bits += 5;
    if (bits >= 8) {
      out.add((buffer >> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Uint8List.fromList(out);
}

String generateTotpSecret([Random? random]) {
  final source = random ?? Random.secure();
  return base32Encode(
    List<int>.generate(totpSecretBytes, (_) => source.nextInt(256)),
  );
}

int totpStepAt(DateTime time) =>
    time.toUtc().millisecondsSinceEpoch ~/ 1000 ~/ totpPeriodSeconds;

String totpCodeForStep(String secret, int step) {
  final counter = ByteData(8)
    ..setUint32(0, step ~/ 0x100000000)
    ..setUint32(4, step % 0x100000000);
  final digest = Hmac(
    sha1,
    base32Decode(secret),
  ).convert(counter.buffer.asUint8List()).bytes;
  final offset = digest.last & 0x0f;
  final binary =
      ((digest[offset] & 0x7f) << 24) |
      ((digest[offset + 1] & 0xff) << 16) |
      ((digest[offset + 2] & 0xff) << 8) |
      (digest[offset + 3] & 0xff);
  final code = binary % pow(10, totpDigits).toInt();
  return code.toString().padLeft(totpDigits, '0');
}

String totpCodeAt(String secret, DateTime time) =>
    totpCodeForStep(secret, totpStepAt(time));

final RegExp _codeFormat = RegExp('^[0-9]{$totpDigits}\$');

bool verifyTotp(String secret, String code, DateTime time) {
  final candidate = code.replaceAll(' ', '');
  if (!_codeFormat.hasMatch(candidate)) return false;
  final step = totpStepAt(time);
  var matched = false;
  for (
    var drift = -totpAllowedDriftSteps;
    drift <= totpAllowedDriftSteps;
    drift++
  ) {
    if (_sameCode(totpCodeForStep(secret, step + drift), candidate)) {
      matched = true;
    }
  }
  return matched;
}

bool _sameCode(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

String formatSetupKey(String secret) {
  final groups = <String>[];
  for (var i = 0; i < secret.length; i += 4) {
    groups.add(secret.substring(i, min(i + 4, secret.length)));
  }
  return groups.join(' ');
}
