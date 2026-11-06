package com.exommethod.exom

import java.io.File
import java.util.concurrent.CompletableFuture
import org.junit.Assert.*
import org.junit.Test

class NativeCompressionOutcomeTest {
    @Test fun cancelledCallbackRejectsNormalFutureAndNonemptyPartial() {
        val partial = File.createTempFile("exom-native-outcome-", ".mp4")
        try {
            partial.writeBytes(byteArrayOf(1, 2, 3))
            val outcome = NativeCompressionOutcome()
            outcome.onTranscodeCanceled()
            CompletableFuture.completedFuture<Void>(null).get()
            assertFalse(outcome.accepts(partial.length() > 0))
            assertTrue(outcome.cancelled)
            outcome.onTranscodeCompleted(0)
            assertFalse(outcome.accepts(true))
        } finally {
            partial.delete()
        }
    }

    @Test fun failureCannotBeOverwrittenByLateSuccess() {
        val outcome = NativeCompressionOutcome()
        outcome.onTranscodeFailed(IllegalStateException("failed"))
        outcome.onTranscodeCompleted(0)
        assertFalse(outcome.accepts(true))
        assertFalse(outcome.cancelled)
    }

    @Test fun completedReceiptAcceptedOnceOnlyWithPreparedOutput() {
        val outcome = NativeCompressionOutcome()
        assertFalse(outcome.accepts(true))
        outcome.onTranscodeCompleted(0)
        assertTrue(outcome.accepts(true))
        assertFalse(outcome.accepts(false))
        outcome.onTranscodeCanceled()
        outcome.onTranscodeFailed(IllegalStateException("late failure"))
        outcome.onTranscodeCompleted(1)
        assertTrue(outcome.accepts(true))
        assertFalse(outcome.cancelled)
    }

    @Test fun notNeededIsNotSuccessfulNormalization() {
        val outcome = NativeCompressionOutcome()
        outcome.onTranscodeCompleted(1)
        assertFalse(outcome.accepts(true))
    }
}
