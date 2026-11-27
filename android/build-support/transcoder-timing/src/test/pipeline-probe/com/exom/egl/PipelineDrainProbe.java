package com.exom.egl;

import com.otaliastudios.transcoder.internal.pipeline.BaseStep;
import com.otaliastudios.transcoder.internal.pipeline.Channel;
import com.otaliastudios.transcoder.internal.pipeline.Pipeline;
import com.otaliastudios.transcoder.internal.pipeline.QueuedStep;
import com.otaliastudios.transcoder.internal.pipeline.State;
import com.otaliastudios.transcoder.internal.utils.Logger;
import com.otaliastudios.transcoder.internal.video.VideoPublisher;
import java.lang.reflect.Constructor;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import kotlin.Unit;

/**
 * Host-only scheduling probe run against the real Transcoder Pipeline/QueuedStep bytes of one variant
 * (original or patched). The codec is an explicit finite-credit model, not measured Android topology.
 */
public final class PipelineDrainProbe {
    private static final Channel CHANNEL = new Channel() {};

    @SuppressWarnings("unchecked")
    private static State<Object> waiting() { return State.Wait.INSTANCE; }

    static void require(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }

    static final class WouldBlock extends RuntimeException {
        private static final long serialVersionUID = 1L;
    }

    /** Credits are held from publish until the writer releases the output (models a full input surface). */
    static final class CodecModel implements VideoPublisher.Surface {
        final int capacity;
        final ArrayDeque<Integer> processing = new ArrayDeque<>();
        final ArrayDeque<Integer> ready = new ArrayDeque<>();
        int submitted, released, drainCalls;

        CodecModel(int capacity) { this.capacity = capacity; }

        @Override public void publish() {
            if (submitted - released == capacity) throw new WouldBlock();
            processing.addLast(++submitted);
        }

        void completePending() { while (!processing.isEmpty()) ready.addLast(processing.removeFirst()); }

        State<Object> drain() {
            drainCalls++;
            Integer frame = ready.pollFirst();
            return frame == null ? waiting() : new State.Ok<>(frame);
        }

        void write(Object frame) {
            require(frame instanceof Integer && ((Integer) frame) == released + 1, "Output reordered, duplicated, or lost");
            released++;
        }
    }

    static final class Reader extends BaseStep<Object, Channel, Object, Channel> {
        boolean wait;
        @Override public Channel getChannel() { return CHANNEL; }
        @Override public State<Object> step(State.Ok<Object> state, boolean fresh) {
            return wait ? waiting() : new State.Ok<>(Unit.INSTANCE);
        }
    }

    /** Same behavior as the stub VideoPublisher but a different type: the patch must ignore it. */
    static final class OtherPublisher extends BaseStep<Object, Channel, Object, Channel> {
        final CodecModel model;
        OtherPublisher(CodecModel model) { this.model = model; }
        @Override public Channel getChannel() { return CHANNEL; }
        @Override public State<Object> step(State.Ok<Object> state, boolean fresh) {
            model.publish();
            return new State.Ok<>(Unit.INSTANCE);
        }
    }

    static final class Encoder extends QueuedStep<Object, Channel, Object, Channel> {
        final CodecModel model;
        Encoder(CodecModel model) { this.model = model; }
        @Override public Channel getChannel() { return CHANNEL; }
        @Override protected void enqueue(Object input) { /* Surface input: already published. */ }
        @Override protected void enqueueEos(Object input) { throw new AssertionError("EOS is not modeled"); }
        @Override protected State<Object> drain() { return model.drain(); }
    }

    static final class Writer extends BaseStep<Object, Channel, Object, Channel> {
        final CodecModel model;
        boolean waitOnce;
        Writer(CodecModel model) { this.model = model; }
        @Override public Channel getChannel() { return CHANNEL; }
        @Override public State<Object> step(State.Ok<Object> state, boolean fresh) {
            if (waitOnce) { waitOnce = false; return waiting(); }
            model.write(state.getValue());
            return new State.Ok<>(Unit.INSTANCE);
        }
    }

    static final class Fixture {
        final CodecModel model;
        final Reader reader = new Reader();
        final Encoder encoder;
        final Writer writer;
        final Pipeline pipeline;

        Fixture(int capacity, boolean videoPublisher) throws ReflectiveOperationException {
            model = new CodecModel(capacity);
            encoder = new Encoder(model);
            writer = new Writer(model);
            Object publisher = videoPublisher ? new VideoPublisher(model) : new OtherPublisher(model);
            Constructor<Pipeline> constructor = Pipeline.class.getDeclaredConstructor(String.class, List.class);
            constructor.setAccessible(true);
            pipeline = constructor.newInstance("host-only", List.of(reader, publisher, encoder, writer));
        }

        void drainAll() {
            for (int count = 0; count <= model.capacity; count++) {
                State<Object> state = encoder.step(new State.Ok<>(Unit.INSTANCE), false);
                if (state instanceof State.Wait) return;
                model.write(((State.Ok<?>) state).getValue());
            }
            throw new AssertionError("Drain exceeded finite capacity");
        }
    }

    /** Returns one line per scenario; the caller asserts the expected original/patched outcome. */
    public static List<String> run() throws Exception {
        Logger.setLogLevel(Integer.MAX_VALUE);
        List<String> lines = new ArrayList<>();
        for (boolean video : new boolean[]{true, false}) {
            Fixture f = new Fixture(8, video);
            for (int i = 0; i < 3; i++) f.model.publish();
            f.model.completePending();
            State<?> result = f.pipeline.execute();
            lines.add("ready-before-publish video=" + video + " result=" + result.getClass().getSimpleName()
                    + " released=" + f.model.released + " readyLeft=" + f.model.ready.size()
                    + " drainCalls=" + f.model.drainCalls);
        }
        Fixture waiting = new Fixture(8, true);
        waiting.model.publish();
        waiting.model.completePending();
        waiting.reader.wait = true;
        State<?> waitResult = waiting.pipeline.execute();
        lines.add("upstream-wait result=" + waitResult.getClass().getSimpleName() + " drainCalls="
                + waiting.model.drainCalls + " readyLeft=" + waiting.model.ready.size());
        Fixture downstream = new Fixture(8, true);
        downstream.model.publish();
        downstream.model.completePending();
        downstream.writer.waitOnce = true;
        String outcome;
        try {
            outcome = "returned " + downstream.pipeline.execute().getClass().getSimpleName();
        } catch (IllegalStateException failure) {
            outcome = "IllegalStateException " + failure.getMessage();
        }
        lines.add("downstream-wait-during-catch-up " + outcome);
        for (int capacity : new int[]{3, 4, 8, 16, 31}) {
            for (int delay : new int[]{0, capacity}) {
                Fixture fixture = new Fixture(capacity, true);
                int blockedAt = 0;
                for (int step = 1; step <= 128; step++) {
                    if (step > delay) fixture.model.completePending();
                    try {
                        fixture.pipeline.execute();
                    } catch (WouldBlock blocked) {
                        blockedAt = step;
                        break;
                    }
                }
                if (blockedAt == 0) {
                    fixture.model.completePending();
                    fixture.drainAll();
                }
                lines.add("startup capacity=" + capacity + " delay=" + delay + " blockedAt=" + blockedAt
                        + " submitted=" + fixture.model.submitted + " released=" + fixture.model.released
                        + " readyLeft=" + fixture.model.ready.size());
            }
        }
        return lines;
    }
}
