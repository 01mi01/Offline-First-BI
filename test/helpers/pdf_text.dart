import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class PdfText {
  final List<String> runs;

  final Set<String> fontNames;

  PdfText(this.runs, this.fontNames);

  String get text => runs.join(' ');

  static PdfText extract(Uint8List bytes) {
    final raw = latin1.decode(bytes);
    final streams = <int, String>{};
    final dicts = <int, String>{};

    final objPattern = RegExp(r'(\d+) 0 obj(.*?)endobj', dotAll: true);
    for (final m in objPattern.allMatches(raw)) {
      final num = int.parse(m.group(1)!);
      final body = m.group(2)!;
      final streamAt = body.indexOf('stream');
      if (streamAt < 0) {
        dicts[num] = body;
        continue;
      }
      dicts[num] = body.substring(0, streamAt);
      var start = streamAt + 'stream'.length;
      if (body.startsWith('\r\n', start)) {
        start += 2;
      } else if (body.startsWith('\n', start)) {
        start += 1;
      }
      final end = body.lastIndexOf('endstream');
      final data = latin1.encode(body.substring(start, end < 0 ? null : end));
      try {
        streams[num] = latin1.decode(zlib.decode(data));
      } catch (_) {
        streams[num] = latin1.decode(data);
      }
    }

    final cmaps = <String, Map<int, int>>{};
    final fontNames = <String>{};
    for (final entry in dicts.entries) {
      final d = entry.value;
      if (!d.contains('/Subtype/Type0') && !d.contains('/Subtype /Type0')) {
        continue;
      }
      final resource = RegExp(r'/Name\s*/(\w+)').firstMatch(d)?.group(1);
      final base = RegExp(r'/BaseFont\s*/([\w+-]+)').firstMatch(d)?.group(1);
      if (base != null) fontNames.add(base);
      final toUnicode = RegExp(r'/ToUnicode (\d+) 0 R').firstMatch(d)?.group(1);
      if (resource == null || toUnicode == null) continue;
      cmaps[resource] = _parseCMap(streams[int.parse(toUnicode)] ?? '');
    }
    for (final d in dicts.values) {
      final m = RegExp(r'/Subtype\s*/Type1\s*/BaseFont\s*/(\w[\w-]*)').firstMatch(d) ??
          RegExp(r'/BaseFont\s*/(\w[\w-]*)\s*/Subtype\s*/Type1').firstMatch(d);
      if (m != null) fontNames.add(m.group(1)!);
    }

    final runs = <String>[];
    final op = RegExp(
      r'/(\w+)\s+[\d.]+\s+Tf|\[((?:<[0-9A-Fa-f]*>|[-\d.\s])*)\]\s*TJ',
    );
    for (final content in streams.values) {
      if (!content.contains(' Tf')) continue;
      Map<int, int>? current;
      for (final m in op.allMatches(content)) {
        if (m.group(1) != null) {
          current = cmaps[m.group(1)!];
          continue;
        }
        final buffer = StringBuffer();
        for (final hex in RegExp('<([0-9A-Fa-f]*)>').allMatches(m.group(2)!)) {
          final h = hex.group(1)!;
          for (var i = 0; i + 4 <= h.length; i += 4) {
            final glyph = int.parse(h.substring(i, i + 4), radix: 16);
            final code = current?[glyph];
            buffer.writeCharCode(code ?? 0xFFFD);
          }
        }
        runs.add(buffer.toString());
      }
    }
    return PdfText(runs, fontNames);
  }

  static Map<int, int> _parseCMap(String cmap) {
    final map = <int, int>{};
    for (final section in RegExp('beginbfchar(.*?)endbfchar', dotAll: true)
        .allMatches(cmap)) {
      for (final m in RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>')
          .allMatches(section.group(1)!)) {
        map[int.parse(m.group(1)!, radix: 16)] =
            int.parse(m.group(2)!, radix: 16);
      }
    }
    return map;
  }
}
