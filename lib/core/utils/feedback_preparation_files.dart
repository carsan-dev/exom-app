import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const feedbackPreparationAttempts = 'preparation_attempts';

/// Only this format grants authority to reclaim feedback preparation files.
/// The native plugin derives the same address; the journal stores no target path.
class FeedbackPreparationAttempt {
  const FeedbackPreparationAttempt({
    required this.owner,
    required this.environment,
    required this.operation,
    required this.attempt,
    required this.source,
    required this.kind,
    this.compressed = 'unadopted',
    this.prepared = 'unadopted',
  });

  final String owner, environment, operation, attempt, source, kind;
  final String compressed, prepared;

  static final _id = RegExp(r'^[a-f0-9]{32}$');
  static bool validId(String value) =>
      value.length == 32 && _id.hasMatch(value);

  String get preparedLeaf => kind == 'video' ? 'prepared.mp4' : 'prepared.jpg';
  static const compressedLeaf = 'compressed.mp4';

  Map<String, String> get address => {
    'scope': sha256
        .convert(utf8.encode(jsonEncode([environment, owner])))
        .toString(),
    'operation': operation,
    'attempt': attempt,
  };

  Directory directory(Directory support) => Directory(
    '${FeedbackPreparationFiles.root(support).path}/${address['scope']}/$operation/$attempt',
  );

  Map<String, Object> get record => {
    'version': 1,
    'owner_id': owner,
    'environment': environment,
    'operation_id': operation,
    'attempt_id': attempt,
    'source_path': source,
    'kind': kind,
    if (kind == 'video') 'compressed': compressed,
    'prepared': prepared,
  };

  static FeedbackPreparationAttempt? read(
    Object? raw,
    Map<String, dynamic> row, {
    required String owner,
    required String environment,
  }) {
    if (raw is! Map ||
        raw['version'] is! int ||
        raw['version'] != 1 ||
        row['format_version'] is! int ||
        row['format_version'] != 2 ||
        row['owner_id'] != owner ||
        row['environment'] != environment ||
        raw['owner_id'] != owner ||
        raw['environment'] != environment ||
        raw['operation_id'] != row['id'] ||
        raw['source_path'] != row['file_path']) {
      return null;
    }
    final operation = raw['operation_id'];
    final attempt = raw['attempt_id'];
    final source = raw['source_path'];
    final kind = raw['kind'];
    final compressed = raw['compressed'];
    final prepared = raw['prepared'];
    if (operation is! String ||
        !validId(operation) ||
        attempt is! String ||
        !validId(attempt) ||
        source is! String ||
        (kind != 'video' && kind != 'image') ||
        raw.length != (kind == 'video' ? 9 : 8) ||
        (kind == 'video'
            ? compressed != 'unadopted' && compressed != 'removed'
            : raw.containsKey('compressed')) ||
        (prepared != 'unadopted' &&
            prepared != 'adopted' &&
            prepared != 'removed')) {
      return null;
    }
    return FeedbackPreparationAttempt(
      owner: owner,
      environment: environment,
      operation: operation,
      attempt: attempt,
      source: source,
      kind: kind as String,
      compressed: compressed as String? ?? 'removed',
      prepared: prepared as String,
    );
  }
}

class FeedbackPreparationFiles {
  static const channel = MethodChannel('com.exommethod.exom/video_compression');
  static const _namespace = 'feedback_preparation_v1';
  static bool get supported =>
      Platform.isAndroid ||
      debugDefaultTargetPlatformOverride == TargetPlatform.android;

  static Directory root(Directory support) =>
      Directory('${support.path}/$_namespace');

  static String pathKey(String path) {
    final normalized = File.fromUri(
      File(path).absolute.uri.normalizePath(),
    ).path;
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  static bool _inside(String path, String root) {
    final candidate = pathKey(path);
    final boundary = pathKey(root);
    return candidate == boundary ||
        candidate.startsWith('$boundary${Platform.pathSeparator}');
  }

  static bool isPrivatePath(String path, Directory support) =>
      _inside(path, root(support).path);

  static Future<bool> isPrivateFile(String path, Directory support) async {
    if (isPrivatePath(path, support)) return true;
    final file = File(path);
    try {
      return isPrivatePath(await file.parent.resolveSymbolicLinks(), support) ||
          isPrivatePath(await file.resolveSymbolicLinks(), support);
    } on FileSystemException {
      return false;
    }
  }

  /// Reject lexical aliases and resolved aliases; this root is not a source.
  static Future<void> rejectSource(File file, {Directory? support}) async {
    if (!supported) return;
    final directory = support ?? await getApplicationSupportDirectory();
    final resolvedSupport = await directory.resolveSymbolicLinks();
    if (_inside(file.path, root(directory).path) ||
        _inside(file.path, root(Directory(resolvedSupport)).path) ||
        await isPrivateFile(file.path, Directory(resolvedSupport))) {
      throw PlatformException(code: 'compression_invalid_input');
    }
  }

  static Future<String> acquirePreparation() async {
    final token = await channel.invokeMethod<String>('acquirePreparation');
    if (token == null) throw PlatformException(code: 'compression_busy');
    return token;
  }

  static Future<String?> acquireMaintenance() =>
      channel.invokeMethod<String>('acquireMaintenance');

  static Future<void> release(String token) async {
    try {
      await channel.invokeMethod<void>('releasePreparationLease', {
        'token': token,
      });
    } on MissingPluginException {
      // Detach must not release an unacknowledged native lease by any other route.
    } on PlatformException {
      // Keep the original operation's result; native ownership remains authoritative.
    }
  }

  static Future<Directory> plan(
    String token,
    FeedbackPreparationAttempt attempt,
  ) async {
    final path = await channel.invokeMethod<String>('planPreparation', {
      'token': token,
      ...attempt.address,
      'kind': attempt.kind,
    });
    if (path == null) throw PlatformException(code: 'compression_failed');
    return Directory(path);
  }

  static Future<void> open(String token) =>
      channel.invokeMethod<void>('openPreparation', {'token': token});

  static Future<bool> remove(
    String token,
    FeedbackPreparationAttempt attempt,
    String leaf,
  ) async =>
      await channel.invokeMethod<bool>('deletePreparationFile', {
        'token': token,
        ...attempt.address,
        'leaf': leaf,
      }) ==
      true;
}
