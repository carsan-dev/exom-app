package com.exom.build;

import java.lang.reflect.*;
import java.net.*;
import java.nio.file.*;
import java.util.*;
public final class PatchSelfCheck {
  record Factory(URLClassLoader loader, Constructor<?> ctor, Method input, Method output) implements AutoCloseable {
    static Factory load(String jar, String stdlib) throws Exception {
      var cl = new URLClassLoader(new URL[]{Path.of(jar).toUri().toURL(), Path.of(stdlib).toUri().toURL()}, null);
      cl.loadClass("com.otaliastudios.transcoder.internal.utils.Logger").getMethod("setLogLevel", int.class).invoke(null, Integer.MAX_VALUE);
      var c = cl.loadClass("com.otaliastudios.transcoder.internal.codec.DecoderDropper");
      return new Factory(cl, c.getConstructor(boolean.class), c.getMethod("input", long.class, boolean.class), c.getMethod("output", long.class));
    }
    public void close() throws Exception { loader.close(); }
  }
  static void equal(Object expected, Object actual, String label) {
    if (!Objects.equals(expected, actual)) throw new AssertionError(label + " expected=" + expected + " actual=" + actual);
  }
  static List<String> api(Factory factory) {
    Class<?> type = factory.ctor.getDeclaringClass();
    List<String> members = new ArrayList<>();
    for (var member : type.getDeclaredConstructors()) members.add(member.toGenericString());
    for (var member : type.getDeclaredMethods()) members.add(member.toGenericString());
    for (var member : type.getDeclaredFields()) members.add(member.toGenericString());
    Collections.sort(members);
    return members;
  }
  static List<Long> fixture(Factory f, long[] pts, boolean early, boolean continuous) throws Exception {
    Object d = f.ctor.newInstance(continuous); long[] sorted = Arrays.stream(pts).sorted().toArray();
    Set<Long> seen = new HashSet<>(); List<Long> outputs = new ArrayList<>(); int next = 0;
    for (long t : pts) {
      f.input.invoke(d, t, true); seen.add(t);
      if (early) while (next < sorted.length && seen.contains(sorted[next])) outputs.add((Long) f.output.invoke(d, sorted[next++]));
    }
    while (next < sorted.length) outputs.add((Long) f.output.invoke(d, sorted[next++]));
    return outputs;
  }
  static List<Long> contract(Factory f, int mask, boolean early, boolean continuous, long offset) throws Exception {
    Object d = f.ctor.newInstance(continuous); List<Long> outputs = new ArrayList<>();
    for (int i=0; i<8; i++) {
      f.input.invoke(d, offset + i*100L, (mask & (1<<i)) != 0);
      if (early) outputs.add((Long) f.output.invoke(d, 5000L + i*100L));
    }
    if (!early) for (int i=0; i<8; i++) outputs.add((Long) f.output.invoke(d, 5000L + i*100L));
    outputs.add((Long) f.output.invoke(d, 5800L));
    return outputs;
  }
  public static void main(String[] args) throws Exception {
    try (Factory original=Factory.load(args[0],args[3]); Factory recompiled=Factory.load(args[1],args[3]); Factory patched=Factory.load(args[2],args[3])) {
      equal(api(original), api(patched), "public/private API compatibility");
      equal(Arrays.toString(original.ctor.getDeclaringClass().getDeclaredAnnotations()),
            Arrays.toString(patched.ctor.getDeclaringClass().getDeclaredAnnotations()), "Kotlin metadata compatibility");
      int cases=0, differential=0;
      String[] ids={"mp4_hevc","mov_hevc","vfr","small_avc","source30"}; int[] oldCounts={22,22,39,47,720};
      for(int i=0;i<ids.length;i++) {
        long[] pts=Files.lines(Path.of(args[4],ids[i]+".pts")).mapToLong(Long::parseLong).toArray();
        for(boolean early:new boolean[]{false,true}) for(boolean continuous:new boolean[]{false,true}) {
          var before=fixture(original,pts,early,continuous); equal(before,fixture(recompiled,pts,early,continuous),ids[i]+" baseline source fidelity");
          var after=fixture(patched,pts,early,continuous); equal(Arrays.stream(pts).sorted().boxed().toList(),after,ids[i]+" all PTS preserved");
          long retained=before.stream().filter(Objects::nonNull).count();
          if(!early)equal((long)oldCounts[i],retained,ids[i]+" historical failure");
          System.out.println("PASS "+ids[i]+" early="+early+" continuous="+continuous+" original="+retained+" patched="+after.size()+"/"+pts.length); cases++;
        }
      }
      for(int mask=0;mask<256;mask++) for(boolean early:new boolean[]{false,true}) for(boolean continuous:new boolean[]{false,true}) for(long offset:new long[]{-23219,0,1000000}) {
        var before=contract(original,mask,early,continuous,offset);
        equal(before,contract(recompiled,mask,early,continuous,offset),"unmodified source contract mask="+mask);
        equal(before,contract(patched,mask,early,continuous,offset),"patched monotonic contract mask="+mask);
        differential++;
      }
      Object singleton=patched.ctor.newInstance(false); patched.input.invoke(singleton,100L,true);
      equal(100L,patched.output.invoke(singleton,100L),"singleton accepted");
      equal(101L,patched.output.invoke(singleton,101L),"initial sentinel behavior retained");
      patched.input.invoke(singleton,200L,true); equal(null,patched.output.invoke(singleton,201L),"second sample closes sentinel");
      patched.input.invoke(singleton,150L,true); equal(200L,patched.output.invoke(singleton,200L),"reordering cannot shrink range");
      patched.input.invoke(singleton,300L,false); equal(null,patched.output.invoke(singleton,300L),"false transition closes current range");
      System.out.println("PASS fixture schedules="+cases+"; unchanged monotonic/render-mask/offset schedules="+differential+"; explicit sentinel assertions=5");
    }
  }
}
