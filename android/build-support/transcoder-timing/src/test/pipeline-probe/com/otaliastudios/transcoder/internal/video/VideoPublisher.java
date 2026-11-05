package com.otaliastudios.transcoder.internal.video;

import com.otaliastudios.transcoder.internal.pipeline.BaseStep;
import com.otaliastudios.transcoder.internal.pipeline.Channel;
import com.otaliastudios.transcoder.internal.pipeline.State;
import kotlin.Unit;

/**
 * Host-only stand-in for the real EGL publisher (which needs Android EGL). It is placed first on the
 * isolated host class path so Pipeline's VideoPublisher type check sees it; it is never packaged.
 * publish() models eglSwapBuffers: it fails (would block forever) when the finite encoder is full.
 */
public final class VideoPublisher extends BaseStep<Object, Channel, Object, Channel> {
    public interface Surface { void publish(); }

    private static final Channel CHANNEL = new Channel() {};
    private final Surface surface;

    public VideoPublisher(Surface surface) { this.surface = surface; }

    @Override public Channel getChannel() { return CHANNEL; }

    @Override public State<Object> step(State.Ok<Object> state, boolean fresh) {
        surface.publish();
        return new State.Ok<>(Unit.INSTANCE);
    }
}
