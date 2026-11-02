import 'package:flutter/services.dart';
import 'export_storage.dart';

class ChannelExportStorage implements ExportStorage {
  static const MethodChannel _channel = MethodChannel(
    'offline_first_bi/export_storage',
  );

  const ChannelExportStorage();

  @override
  Future<StoragePermission> ensurePermission() async {
    final status = await _channel.invokeMethod<String>('ensurePermission');
    return switch (status) {
      'granted' => StoragePermission.granted,
      'permanentlyDenied' => StoragePermission.permanentlyDenied,
      _ => StoragePermission.denied,
    };
  }

  @override
  Future<bool> exists(String fileName) async {
    final found = await _channel.invokeMethod<bool>('exists', {
      'folder': exportFolderName,
      'fileName': fileName,
    });
    return found ?? false;
  }

  @override
  Future<String> save({
    required String sourcePath,
    required String fileName,
    required String mimeType,
  }) async {
    final saved = await _channel.invokeMethod<String>('save', {
      'folder': exportFolderName,
      'sourcePath': sourcePath,
      'fileName': fileName,
      'mimeType': mimeType,
    });
    return saved ?? fileName;
  }

  @override
  Future<FolderOpenStep?> openFolder() => openFolderInOrder((step) async {
    final opened = await _channel.invokeMethod<bool>('openFolder', {
      'folder': exportFolderName,
      'step': step.name,
    });
    return opened ?? false;
  });
}
