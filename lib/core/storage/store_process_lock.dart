import 'dart:io';

// Lifetime ownership of a Hive store. Fail closed before opening any box if a
// different process owns it. The OS releases this lock on process termination.
class StoreProcessLock {
  StoreProcessLock._(this._handle);
  final RandomAccessFile _handle;
  static Future<StoreProcessLock> acquire(Directory directory) async {
    await directory.create(recursive: true);
    final handle = await File(
      '${directory.path}/exom-store.lock',
    ).open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.exclusive);
      return StoreProcessLock._(handle);
    } catch (_) {
      await handle.close();
      rethrow;
    }
  }

  Future<void> release() => _handle.close();
}
