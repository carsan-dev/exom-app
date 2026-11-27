package com.exommethod.exom;

import static org.junit.Assert.*;

import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.Test;

public class NativeTranscodeTaskTest {
    @Test public void fallbackFailureCannotBecomeSuccessfulCompletion() {
        AtomicInteger exits = new AtomicInteger();
        IllegalStateException failure = new IllegalStateException("sink release failed");
        NativeTranscodeTask task = new NativeTranscodeTask((Callable<Void>) () -> null, () -> {
            throw failure;
        }, exits::incrementAndGet);
        task.run();
        assertTrue(task.hasExited());
        assertEquals(1, exits.get());
        assertSame(failure, assertThrows(ExecutionException.class, task::get).getCause());
    }

    @Test public void fallbackRunsAfterNormalUpstreamReleaseWithIdempotentOwnership() throws Exception {
        AtomicInteger calls = new AtomicInteger();
        AtomicInteger releases = new AtomicInteger();
        java.util.concurrent.atomic.AtomicBoolean ownedRelease = new java.util.concurrent.atomic.AtomicBoolean();
        Runnable release = () -> {
            calls.incrementAndGet();
            if (ownedRelease.compareAndSet(false, true)) releases.incrementAndGet();
        };
        NativeTranscodeTask task = new NativeTranscodeTask((Callable<Void>) () -> {
            release.run();
            return null;
        }, release, () -> { });
        task.run();
        task.get();
        assertTrue(task.hasExited());
        assertEquals(2, calls.get());
        assertEquals(1, releases.get());
    }

    @Test public void startupFailureBeforeUpstreamCleanupStillReleasesOwnedSink() {
        AtomicInteger releases = new AtomicInteger();
        AtomicInteger exits = new AtomicInteger();
        IllegalStateException failure = new IllegalStateException("engine constructor failed");
        NativeTranscodeTask task = new NativeTranscodeTask((Callable<Void>) () -> {
            throw failure;
        }, releases::incrementAndGet, exits::incrementAndGet);
        task.run();
        assertTrue(task.engineEntered());
        assertEquals(1, releases.get());
        assertTrue(task.hasExited());
        assertEquals(1, exits.get());
        assertSame(failure, assertThrows(ExecutionException.class, task::get).getCause());
    }

    @Test public void blockingFallbackReleaseCannotPublishTaskExitEarly() throws Exception {
        CountDownLatch cleanupEntered = new CountDownLatch(1);
        CountDownLatch releaseCleanup = new CountDownLatch(1);
        AtomicInteger exits = new AtomicInteger();
        ExecutorService executor = Executors.newSingleThreadExecutor();
        NativeTranscodeTask task = new NativeTranscodeTask((Callable<Void>) () -> null, () -> {
            cleanupEntered.countDown();
            awaitIgnoringInterrupts(releaseCleanup);
        }, exits::incrementAndGet);
        try {
            task.enqueue(executor);
            assertTrue(cleanupEntered.await(3, TimeUnit.SECONDS));
            assertFalse(task.hasExited());
            assertEquals(0, exits.get());
            assertTrue(task.cancel(true));
            assertFalse(task.hasExited());
            releaseCleanup.countDown();
            executor.shutdown();
            assertTrue(executor.awaitTermination(3, TimeUnit.SECONDS));
            assertTrue(task.hasExited());
            assertEquals(1, exits.get());
        } finally {
            releaseCleanup.countDown();
            executor.shutdownNow();
        }
    }

    @Test public void canceledFutureDoesNotMeanNativeCleanupExited() throws Exception {
        CountDownLatch started = new CountDownLatch(1);
        CountDownLatch terminalCallback = new CountDownLatch(1);
        CountDownLatch releaseCleanup = new CountDownLatch(1);
        AtomicInteger exits = new AtomicInteger();
        ExecutorService executor = Executors.newSingleThreadExecutor();
        NativeTranscodeTask task = new NativeTranscodeTask((Callable<Void>) () -> {
            started.countDown();
            try {
                new CountDownLatch(1).await();
            } catch (InterruptedException expected) {
                terminalCallback.countDown();
            }
            awaitIgnoringInterrupts(releaseCleanup);
            return null;
        }, exits::incrementAndGet);
        try {
            task.enqueue(executor);
            assertTrue(started.await(3, TimeUnit.SECONDS));
            assertTrue(task.cancel(true));
            assertTrue(terminalCallback.await(3, TimeUnit.SECONDS));
            assertTrue(task.isDone());
            assertTrue(task.isCancelled());
            assertTrue(task.engineEntered());
            assertFalse(task.hasExited());
            assertFalse(task.awaitExit(1));
            assertEquals(0, exits.get());
            releaseCleanup.countDown();
            executor.shutdown();
            assertTrue(executor.awaitTermination(3, TimeUnit.SECONDS));
            assertTrue(task.hasExited());
            assertEquals(1, exits.get());
        } finally {
            releaseCleanup.countDown();
            executor.shutdownNow();
        }
    }

    @Test public void canceledBeforeRunNeverEntersEngineAndPublishesExitOnce() {
        AtomicInteger entered = new AtomicInteger();
        AtomicInteger exits = new AtomicInteger();
        NativeTranscodeTask task = new NativeTranscodeTask((Callable<Void>) () -> {
            entered.incrementAndGet();
            return null;
        }, exits::incrementAndGet);
        assertTrue(task.cancel(true));
        assertFalse(task.hasExited());
        task.run();
        task.run();
        assertTrue(task.hasExited());
        assertFalse(task.engineEntered());
        assertEquals(0, entered.get());
        assertEquals(1, exits.get());
    }

    @Test public void rejectedEnqueueCannotLeaveAnUnstartedEngineQuarantined() {
        AtomicInteger entered = new AtomicInteger();
        AtomicInteger exits = new AtomicInteger();
        NativeTranscodeTask task = new NativeTranscodeTask((Callable<Void>) () -> {
            entered.incrementAndGet();
            return null;
        }, exits::incrementAndGet);
        assertThrows(RejectedExecutionException.class, () -> task.enqueue(command -> {
            throw new RejectedExecutionException("isolated rejection");
        }));
        assertTrue(task.hasExited());
        assertFalse(task.engineEntered());
        task.run();
        assertEquals(0, entered.get());
        assertEquals(1, exits.get());
    }

    @Test public void exceptionUnwindsBeforeExitAndPreservesFailure() {
        AtomicInteger exits = new AtomicInteger();
        IllegalStateException failure = new IllegalStateException("isolated failure");
        NativeTranscodeTask task = new NativeTranscodeTask((Callable<Void>) () -> {
            throw failure;
        }, exits::incrementAndGet);
        task.run();
        assertTrue(task.hasExited());
        assertTrue(task.engineEntered());
        assertSame(failure, assertThrows(ExecutionException.class, task::get).getCause());
        assertFalse(task.cancel(true));
        task.run();
        assertEquals(1, exits.get());
    }

    @Test public void duplicateConcurrentRunCannotPublishExitWhileEngineStillRuns() throws Exception {
        CountDownLatch started = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);
        AtomicInteger exits = new AtomicInteger();
        NativeTranscodeTask task = new NativeTranscodeTask((Callable<Void>) () -> {
            started.countDown();
            release.await();
            return null;
        }, exits::incrementAndGet);
        ExecutorService executor = Executors.newSingleThreadExecutor();
        try {
            task.enqueue(executor);
            assertTrue(started.await(3, TimeUnit.SECONDS));
            task.run();
            assertFalse(task.hasExited());
            assertEquals(0, exits.get());
            release.countDown();
            executor.shutdown();
            assertTrue(executor.awaitTermination(3, TimeUnit.SECONDS));
            assertTrue(task.hasExited());
            assertEquals(1, exits.get());
        } finally {
            release.countDown();
            executor.shutdownNow();
        }
    }

    private static void awaitIgnoringInterrupts(CountDownLatch latch) {
        while (true) {
            try { latch.await(); return; } catch (InterruptedException ignored) { }
        }
    }
}
