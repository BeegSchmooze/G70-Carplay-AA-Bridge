/*
 * Genesis G70 bridge: the car navigation's side of the camera alerts. GPM (LeafiaCam) finds the
 * camera ahead and publishes sys.leafia.cam = "kind,whole,tenths,unit" ("0" = none); the
 * navigation owns the cluster's trap frames (they carry its speed-limit sign), so it shows the
 * camera here: called first in e/a.sendClusterData, it keeps the navigation's last trap frame
 * (type 1), puts the camera into it while one is ahead, and holds back the navigation's own camera
 * distance (type 4) meanwhile. A thread follows the property and resends the frame and the
 * countdown through sendClusterData itself.
 *
 * HUD tests 4 and 5: only the trap frame's nonSpeed code draws a camera; nonSpeed 1 with
 * overSpeedAlarm 3 is the red-light camera (kind 2), with overSpeedAlarm 1 the speed camera
 * (kind 1). Raw frame: [0] fixed [1] mobile [2] overSpeedAlarm [3] redline [4] nonSpeed ...
 * [8] speed limit ... [20] country.
 *
 * GPL-3.0 (Genesis G70 bridge).
 */
package com.mnsoft.navi;

import android.os.SystemProperties;
import android.util.Log;

import java.lang.reflect.Method;

public final class LeafiaNavCam implements Runnable {
    static final String TAG = "LeafiaCAM";
    static final String PROP = "sys.leafia.cam";
    static final int TYPE_TRAP = 1, TYPE_DIST = 4;
    static final long POLL_MS = 500, REASSERT_MS = 5000;
    /** the navigation's frame while driving without a speed limit (logged) */
    static final int[] BASE = {0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0};

    private static Thread sThread;
    private static int[] sLast;
    /** the camera now shown: kind (0 = none), whole, tenths, unit */
    private static volatile int[] sCam = {0, 0, 0, 0};
    /** set while this class sends through sendClusterData itself */
    private static final ThreadLocal<Boolean> sSelf = new ThreadLocal<Boolean>();
    private static Method sSend;

    private LeafiaNavCam() {
    }

    /** e/a.sendClusterData, first thing: true = drop this message. Never throws. */
    public static boolean frame(int type, int[] a) {
        try {
            if (sThread == null) startThread();
            boolean self = sSelf.get() != null;
            int kind = sCam[0];
            if (type == TYPE_TRAP && a != null && a.length >= 20) {
                if (!self) {
                    synchronized (LeafiaNavCam.class) {
                        sLast = a.clone();
                    }
                }
                overlay(a, kind);
            } else if (type == TYPE_DIST && kind != 0 && !self) {
                return true;
            }
        } catch (Throwable e) {
            Log.w(TAG, "frame: " + e);
        }
        return false;
    }

    static int[] overlay(int[] a, int kind) {
        if (kind == 0) return a;
        a[4] = 1;
        a[2] = kind == 1 ? 1 : 3;
        return a;
    }

    /** "kind,whole,tenths,unit" -> ints; anything else is "none" */
    static int[] parse(String v) {
        int[] c = {0, 0, 0, 0};
        if (v == null) return c;
        String[] f = v.split(",");
        if (f.length < 4) return c;
        try {
            for (int i = 0; i < 4; i++) c[i] = Integer.parseInt(f[i].trim());
        } catch (NumberFormatException e) {
            return new int[] {0, 0, 0, 0};
        }
        if (c[0] != 1 && c[0] != 2) c[0] = 0;
        return c;
    }

    private static synchronized void startThread() {
        if (sThread != null) return;
        sThread = new Thread(new LeafiaNavCam(), "LeafiaNavCam");
        sThread.setDaemon(true);
        sThread.start();
        Log.i(TAG, "Leafia: navigation camera display ready");
    }

    public void run() {
        String last = "0";
        long sent = 0;
        while (true) {
            try {
                Thread.sleep(POLL_MS);
                String v = SystemProperties.get(PROP, "0");
                long now = System.currentTimeMillis();
                if (v.equals(last) && !(sCam[0] != 0 && now - sent > REASSERT_MS)) continue;
                int[] was = sCam, c = parse(v);
                sCam = c;
                if (c[0] != was[0] || now - sent > REASSERT_MS) {
                    // the navigation's own frame with the camera in it (or back without it)
                    int[] f;
                    synchronized (LeafiaNavCam.class) {
                        f = sLast != null ? sLast.clone() : BASE.clone();
                    }
                    send(TYPE_TRAP, f);
                    sent = now;
                }
                if (c[0] != 0) {
                    // NavigationCluster.updateNaviWarnDist(whole, tenths, unit) via e/a.g: [whole, unit, tenths]
                    if (!v.equals(last)) send(TYPE_DIST, new int[] {c[1], c[3], c[2]});
                } else if (was[0] != 0) {
                    send(TYPE_DIST, new int[] {0, 0, 0});
                }
                if (!v.equals(last)) Log.i(TAG, "Leafia: camera display " + v);
                last = v;
            } catch (InterruptedException e) {
                return;
            } catch (Throwable e) {
                Log.w(TAG, "poll: " + e);
            }
        }
    }

    private static void send(int type, int[] a) {
        sSelf.set(Boolean.TRUE);
        try {
            if (sSend == null) {
                sSend = Class.forName("com.mnsoft.navi.e.a").getMethod("sendClusterData", int.class, int[].class,
                        double[].class, String[].class, byte[].class);
            }
            sSend.invoke(null, type, a, null, null, null);
        } catch (Throwable e) {
            Log.w(TAG, "send " + type + ": " + e);
        } finally {
            sSelf.remove();
        }
    }
}
