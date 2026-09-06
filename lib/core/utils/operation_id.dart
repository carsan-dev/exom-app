import 'dart:math';

/// Generated once at enqueue, then preserved across restarts and retries.
String newOperationId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
