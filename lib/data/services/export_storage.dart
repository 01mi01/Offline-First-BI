const String exportFolderName = 'Empiric';
const String exportFolderDisplay = 'Descargas/$exportFolderName';

const String pdfMimeType = 'application/pdf';
const String excelMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

enum StoragePermission { granted, denied, permanentlyDenied }

abstract class ExportStorage {
  Future<StoragePermission> ensurePermission();

  Future<bool> exists(String fileName);

  Future<String> save({
    required String sourcePath,
    required String fileName,
    required String mimeType,
  });

  Future<FolderOpenStep?> openFolder();
}

enum FolderOpenStep { directory }

Future<FolderOpenStep?> openFolderInOrder(
  Future<bool> Function(FolderOpenStep step) tryOpen,
) async {
  for (final step in FolderOpenStep.values) {
    try {
      if (await tryOpen(step)) return step;
    } catch (_) {
      continue;
    }
  }
  return null;
}

sealed class ExportOutcome {
  const ExportOutcome();
}

class ExportSaved extends ExportOutcome {
  final String fileName;
  final String folder;
  final String filePath;
  final String title;

  const ExportSaved({
    required this.fileName,
    required this.folder,
    required this.filePath,
    required this.title,
  });
}

class ExportNotSaved extends ExportOutcome {
  final bool permanentlyDenied;

  const ExportNotSaved({required this.permanentlyDenied});
}

Future<String> uniqueFileName(
  String fileName,
  Future<bool> Function(String name) exists,
) async {
  if (!await exists(fileName)) return fileName;
  final dot = fileName.lastIndexOf('.');
  final base = dot <= 0 ? fileName : fileName.substring(0, dot);
  final extension = dot <= 0 ? '' : fileName.substring(dot);
  var counter = 1;
  while (true) {
    final candidate = '$base ($counter)$extension';
    if (!await exists(candidate)) return candidate;
    counter++;
  }
}

class ExportFileSaver {
  final ExportStorage storage;

  const ExportFileSaver(this.storage);

  Future<ExportOutcome> save({
    required String title,
    required String fileName,
    required String mimeType,
    required Future<String> Function(String finalName) writeSource,
  }) async {
    final permission = await storage.ensurePermission();
    if (permission != StoragePermission.granted) {
      return ExportNotSaved(
        permanentlyDenied: permission == StoragePermission.permanentlyDenied,
      );
    }
    final name = await uniqueFileName(fileName, storage.exists);
    final sourcePath = await writeSource(name);
    final savedName = await storage.save(
      sourcePath: sourcePath,
      fileName: name,
      mimeType: mimeType,
    );
    return ExportSaved(
      fileName: savedName,
      folder: exportFolderDisplay,
      filePath: sourcePath,
      title: title,
    );
  }
}
