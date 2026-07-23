import 'dart:convert';
import 'dart:typed_data';

import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

/// Reads and writes the backup file inside a user-granted Android folder
/// (Storage Access Framework). The folder grant is *persistable*, so the app
/// keeps write access across restarts; the file lives in the user's own
/// storage (e.g. a Drive/Documents folder), so it survives an uninstall or a
/// change of signing key.
class BackupService {
  static const fileName = 'baby-feed-tracker-backup.json';

  final _safUtil = SafUtil();
  final _safStream = SafStream();

  /// Prompts the user to pick a folder and returns its persistable tree URI,
  /// or null if they cancelled.
  Future<String?> pickFolder() async {
    try {
      final dir = await _safUtil.pickDirectory(
        writePermission: true,
        persistablePermission: true,
      );
      return dir?.uri;
    } catch (_) {
      return null;
    }
  }

  /// Writes (or overwrites) the backup file in [dirUri].
  Future<void> write(String dirUri, String json) async {
    await _safStream.writeFileBytes(
      dirUri,
      fileName,
      'application/json',
      Uint8List.fromList(utf8.encode(json)),
      overwrite: true,
    );
  }

  /// Returns the URI of an existing backup file in [dirUri], or null.
  Future<String?> existingBackupUri(String dirUri) async {
    try {
      final file = await _safUtil.child(dirUri, [fileName]);
      return file?.uri;
    } catch (_) {
      return null;
    }
  }

  /// Reads and decodes the backup file at [fileUri], or null on any failure.
  Future<String?> read(String fileUri) async {
    try {
      final bytes = await _safStream.readFileBytes(fileUri);
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }
}
