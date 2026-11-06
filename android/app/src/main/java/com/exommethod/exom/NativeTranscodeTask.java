package com.exommethod.exom;

import com.otaliastudios.transcoder.TranscoderOptions;
import com.otaliastudios.transcoder.internal.transcode.TranscodeEngine;
import com.otaliastudios.transcoder.internal.utils.ThreadPool;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executor;
import java.util.concurrent.FutureTask;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

/** Tracks actual engine exit; Future cancellation and listener callbacks precede native cleanup. */
final class NativeTranscodeTask extends FutureTask<Void> {
    private final CountDownLatch exited = new CountDownLatch(1);
    private final AtomicBoolean runStarted = new AtomicBoolean();
    private final AtomicBoolean exitPublished = new AtomicBoolean();
    private final AtomicBoolean engineEntered;
    private final Runnable onExit;

    NativeTranscodeTask(TranscoderOptions options, Runnable onExit) {
        // Same call and executor as pinned Transcoder 0.10.5's Transcoder$1.
        // These are internal JVM APIs, not a supported upstream extension point.
        this(() -> { TranscodeEngine.transcode(options); return null; }, options.getDataSink()::release, onExit);
    }

    NativeTranscodeTask(Callable<Void> engine, Runnable onExit) {
        this(engine, () -> { }, onExit);
    }

    NativeTranscodeTask(Callable<Void> engine, Runnable release, Runnable onExit) {
        this(engine, release, onExit, new AtomicBoolean());
    }

    private NativeTranscodeTask(Callable<Void> engine, Runnable release, Runnable onExit, AtomicBoolean engineEntered) {
        super(() -> {
            engineEntered.set(true);
            try {
                return engine.call();
            } finally {
                // Upstream startup can throw before its engine owns the already-created sink.
                release.run();
            }
        });
        this.engineEntered = engineEntered;
        this.onExit = onExit;
    }

    void enqueue() {
        enqueue(ThreadPool.getExecutor());
    }

    void enqueue(Executor executor) {
        try {
            executor.execute(this);
        } catch (RejectedExecutionException error) {
            cancel(false);
            publishExit();
            throw error;
        }
    }

    @Override public void run() {
        if (!runStarted.compareAndSet(false, true)) return;
        try {
            super.run();
        } finally {
            publishExit();
        }
    }

    private void publishExit() {
        if (exitPublished.compareAndSet(false, true)) {
            exited.countDown();
            onExit.run();
        }
    }

    boolean hasExited() { return exited.getCount() == 0; }
    boolean engineEntered() { return engineEntered.get(); }
    boolean awaitExit(long millis) throws InterruptedException {
        return exited.await(millis, TimeUnit.MILLISECONDS);
    }
}
