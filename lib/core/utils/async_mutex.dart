import 'dart:async';

/// Small FIFO mutex for read-modify-write operations on local queues.
class AsyncMutex {
  Future<void> _tail = Future<void>.value();

  Future<T> protect<T>(Future<T> Function() action) {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;

    return previous.then((_) => action()).whenComplete(() {
      if (!released.isCompleted) released.complete();
    });
  }
}
