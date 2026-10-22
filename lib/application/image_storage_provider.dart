import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/image_storage.dart';

final imageStorageProvider = Provider<ImageStorage>((ref) => ImageStorage());
