import 'dart:convert';
import 'dart:typed_data';

import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart';

import '../../core/failure.dart';
import 'vault_layout.dart';

/// Thin, testable wrapper over `saf_util` + `saf_stream`.
///
/// This is the ONLY place that talks to the Storage Access Framework. It adds
/// the two things the plugins don't: **atomic writes** (temp → rename, PLAN.md
/// §3) and typed [VaultFailure]s so the UI can drive the reconnect flow.
class SafGateway {
  SafGateway({SafUtil? util, SafStream? stream})
      : _util = util ?? SafUtil(),
        _stream = stream ?? SafStream();

  final SafUtil _util;
  final SafStream _stream;

  static const String _jsonMime = 'application/json';

  /// Opens the system folder picker and takes a persistable read+write grant.
  /// Returns null if the user cancels.
  Future<SafDocumentFile?> pickVaultDirectory() async {
    try {
      return await _util.pickDirectory(
        writePermission: true,
        persistablePermission: true,
      );
    } catch (e) {
      throw VaultFailure(FailureKind.io, 'Folder picker failed', cause: e);
    }
  }

  /// True if we still hold a persisted read+write grant for [treeUri].
  Future<bool> hasWritePermission(String treeUri) async {
    try {
      return await _util.hasPersistedPermission(treeUri, checkWrite: true);
    } catch (_) {
      return false;
    }
  }

  Future<void> releasePermission(String treeUri) async {
    try {
      await _util.releasePersistedPermission(treeUri, write: true);
    } catch (_) {
      // Best-effort; nothing actionable if the grant is already gone.
    }
  }

  /// Creates [segments] under [parentUri] (recursively) and returns the leaf
  /// directory URI. No-op if it already exists.
  Future<String> ensureDir(String parentUri, List<String> segments) async {
    try {
      final dir = await _util.mkdirp(parentUri, segments);
      return dir.uri;
    } catch (e) {
      throw VaultFailure(
        FailureKind.io,
        'Could not create ${segments.join('/')}',
        cause: e,
      );
    }
  }

  Future<SafDocumentFile?> child(String uri, List<String> names) async {
    try {
      return await _util.child(uri, names);
    } catch (_) {
      return null;
    }
  }

  /// Lists immediate children of [uri]; empty on any error.
  Future<List<SafDocumentFile>> list(String uri) async {
    try {
      return await _util.list(uri);
    } catch (_) {
      return const [];
    }
  }

  Future<bool> exists(String uri, {required bool isDir}) async {
    try {
      return await _util.exists(uri, isDir);
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteByUri(String uri, {required bool isDir}) async {
    try {
      await _util.delete(uri, isDir);
    } catch (e) {
      throw VaultFailure(FailureKind.io, 'Delete failed', cause: e);
    }
  }

  /// Deletes [fileName] under [dirUri] if present. Silent when absent.
  Future<void> deleteChild(String dirUri, String fileName,
      {bool isDir = false}) async {
    final existing = await child(dirUri, [fileName]);
    if (existing != null) {
      await deleteByUri(existing.uri, isDir: isDir);
    }
  }

  /// Reads the raw bytes of [fileName] inside [dirUri], or null if it's absent.
  Future<Uint8List?> readBytes(String dirUri, String fileName) async {
    final file = await child(dirUri, [fileName]);
    if (file == null) return null;
    try {
      return await _stream.readFileBytes(file.uri);
    } catch (e) {
      throw VaultFailure(FailureKind.io, 'Read failed: $fileName', cause: e);
    }
  }

  /// Reads [fileName] as UTF-8 text, or null if absent.
  Future<String?> readString(String dirUri, String fileName) async {
    final bytes = await readBytes(dirUri, fileName);
    if (bytes == null) return null;
    try {
      return utf8.decode(bytes);
    } catch (e) {
      throw VaultFailure(
        FailureKind.vaultCorrupt,
        'Not valid UTF-8: $fileName',
        cause: e,
      );
    }
  }

  /// Directly writes [data] to [fileName] under [dirUri] (overwriting). Use for
  /// large binaries (page images) where full atomicity isn't required.
  Future<void> writeBytes(
    String dirUri,
    String fileName,
    Uint8List data, {
    String mime = 'application/octet-stream',
  }) async {
    try {
      await _stream.writeFileBytes(dirUri, fileName, mime, data,
          overwrite: true);
    } catch (e) {
      throw VaultFailure(FailureKind.io, 'Write failed: $fileName', cause: e);
    }
  }

  /// Atomically writes [data] to [fileName] under [dirUri]: write to a temp
  /// sibling, delete any existing target, then rename temp → target. A crash
  /// mid-write leaves the previous file intact (PLAN.md §3 atomic writes).
  Future<void> writeBytesAtomic(
    String dirUri,
    String fileName,
    Uint8List data, {
    String mime = 'application/octet-stream',
  }) async {
    final tmpName = '$fileName${VaultLayout.tempSuffix}';
    final String tmpUri;
    try {
      final tmp = await _stream.writeFileBytes(dirUri, tmpName, mime, data,
          overwrite: true);
      tmpUri = tmp.uri.toString();
    } catch (e) {
      throw VaultFailure(FailureKind.io, 'Temp write failed: $fileName',
          cause: e);
    }
    try {
      await deleteChild(dirUri, fileName);
      await _util.rename(tmpUri, false, fileName);
    } catch (e) {
      // Leave the .tmp behind for post-mortem; the old target is untouched.
      throw VaultFailure(FailureKind.io, 'Atomic rename failed: $fileName',
          cause: e);
    }
  }

  /// Atomically writes a UTF-8 JSON string.
  Future<void> writeStringAtomic(
    String dirUri,
    String fileName,
    String content,
  ) =>
      writeBytesAtomic(
        dirUri,
        fileName,
        Uint8List.fromList(utf8.encode(content)),
        mime: _jsonMime,
      );
}
