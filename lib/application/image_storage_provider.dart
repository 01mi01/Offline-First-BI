import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/image_storage.dart';

// Almacenamiento permanente de imágenes (ver image_storage.dart).
final imageStorageProvider = Provider<ImageStorage>((ref) => ImageStorage());
