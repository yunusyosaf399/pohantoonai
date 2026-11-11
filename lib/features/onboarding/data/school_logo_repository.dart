import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A temporary signed download URL is never stored in the school draft.
class SchoolLogoUpload {
  const SchoolLogoUpload(this.path, this.previewBytes);
  final String path;
  final Uint8List previewBytes;
}

abstract class SchoolLogoRepository {
  Future<SchoolLogoUpload?> chooseAndUpload();
  Future<String> signedUrl(String path);
}

/// Validates the image header, size and account folder before upload.
/// Only our private school-logos bucket is used (no public avatar bucket).
class SupabaseSchoolLogoRepository implements SchoolLogoRepository {
  const SupabaseSchoolLogoRepository(this.client);
  final SupabaseClient client;
  static const bucket = 'school-logos';
  static const maxBytes = 2 * 1024 * 1024;

  String get userId {
    final id = client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Sign in to upload a school logo.');
    return id;
  }

  static String? detectSupportedImage(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 &&
        bytes[2] == 0x4E && bytes[3] == 0x47 &&
        bytes[4] == 0x0D && bytes[5] == 0x0A &&
        bytes[6] == 0x1A && bytes[7] == 0x0A) return 'png';
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF && bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) return 'jpg';
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') return 'webp';
    return null;
  }

  @override
  Future<SchoolLogoUpload?> chooseAndUpload() async {
    final selected = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'School logo images',
          extensions: ['png','jpg','jpeg','webp'],
          mimeTypes: ['image/png','image/jpeg','image/webp'],
          uniformTypeIdentifiers: ['public.image'],
        ),
      ],
    );
    if (selected == null) return null;
    final bytes = await selected.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Select an image smaller than 2 MB.');
    }
    final ext = detectSupportedImage(bytes);
    if (ext == null) {
      throw const FormatException(
        'School logos must be valid PNG, JPG or WebP images.');
    }
    final contentType = ext == 'png' ? 'image/png'
        : ext == 'webp' ? 'image/webp' : 'image/jpeg';
    final path = userId + '/logos/logo-' +
      DateTime.now().microsecondsSinceEpoch.toString() + '.' + ext;
    await client.storage.from(bucket).uploadBinary(
      path, bytes,
      fileOptions: FileOptions(
        upsert: false, cacheControl: '600', contentType: contentType),
    );
    return SchoolLogoUpload(path, bytes);
  }

  @override
  Future<String> signedUrl(String path) async {
    if (!path.startsWith(userId + '/logos/')) {
      throw StateError('This school logo does not belong to this account.');
    }
    return client.storage.from(bucket).createSignedUrl(path, 600);
  }
}
