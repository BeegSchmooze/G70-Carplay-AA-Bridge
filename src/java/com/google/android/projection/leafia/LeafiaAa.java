/*
 * Genesis G70 bridge: entry points GPM's smali calls for Android Auto turn-by-turn.
 * NavigationStatus (the AA library's callbacks), the navigation focus and the end of a
 * connection call these static methods; each call is copied onto one HandlerThread,
 * where LeafiaAaTurns runs (the library calls in from its own threads).
 *
 * AGPL-3.0 (part of the HMG-API AaTurns port).
 */
package com.google.android.projection.leafia;

import android.content.Context;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Log;

public final class LeafiaAa {
    static final String TAG = "LeafiaAA";

    private static Handler sHandler;
    private static LeafiaAaTurns sTurns;

    private LeafiaAa() {
    }

    /** The turns manager, made on first use (null if the cluster can't be reached). */
    private static synchronized LeafiaAaTurns turns() {
        if (sTurns != null) return sTurns;
        try {
            if (sHandler == null) {
                HandlerThread t = new HandlerThread("LeafiaAaTurns");
                t.start();
                sHandler = new Handler(t.getLooper());
            }
            Context c = appContext();
            LeafiaCluster cl = LeafiaCluster.of(c);
            if (cl == null) return null;
            sTurns = new LeafiaAaTurns(c, cl, sHandler);
            Log.i(TAG, "Leafia: Android Auto turn-by-turn (HMG-API AaTurns port) ready");
        } catch (Throwable t) {
            Log.w(TAG, "turns: " + t);
        }
        return sTurns;
    }

    /** The app's context, from ActivityThread (hidden API, reached by reflection). */
    private static Context appContext() {
        try {
            Class<?> at = Class.forName("android.app.ActivityThread");
            Object app = at.getMethod("currentApplication").invoke(null);
            if (app instanceof Context) return (Context) app;
        } catch (Throwable t) {
            Log.w(TAG, "no application context: " + t);
        }
        return null;
    }

    private static void post(Runnable r) {
        LeafiaAaTurns t = turns();
        if (t == null) return;
        sHandler.post(r);
    }

    /** NavigationStatus.navigationNextTurnCallback(road, turnSide, event, image, turnAngle, turnNumber) */
    public static void nextTurn(final String road, final int side, final int event, byte[] image, final int angle,
            final int number) {
        post(new Runnable() {
            @Override
            public void run() {
                try {
                    sTurns.nextTurn(road, side, event, angle, number);
                } catch (Throwable t) {
                    Log.w(TAG, "nextTurn: " + t);
                }
            }
        });
    }

    /** NavigationStatus.navigationNextTurnDistanceCallback(meters, seconds, displayE3, unitFlags) */
    public static void distance(final int meters, final int seconds, final int e3, final int unitFlags) {
        post(new Runnable() {
            @Override
            public void run() {
                try {
                    sTurns.nextTurnDistance(meters, seconds, e3, unitFlags);
                } catch (Throwable t) {
                    Log.w(TAG, "distance: " + t);
                }
            }
        });
    }

    /** NavigationStatus.navigationStatusCallback(status): 1 active, 2 inactive, 3 rerouting */
    public static void status(final int s) {
        post(new Runnable() {
            @Override
            public void run() {
                try {
                    sTurns.status(s);
                } catch (Throwable t) {
                    Log.w(TAG, "status: " + t);
                }
            }
        });
    }

    /** The car's navigation took the navigation focus. */
    public static void focusNative() {
        post(new Runnable() {
            @Override
            public void run() {
                try {
                    sTurns.stop();
                } catch (Throwable t) {
                    Log.w(TAG, "stop: " + t);
                }
            }
        });
    }

    /** The Android Auto connection ended. */
    public static void sessionEnd() {
        if (sTurns == null) return;
        post(new Runnable() {
            @Override
            public void run() {
                try {
                    sTurns.end();
                } catch (Throwable t) {
                    Log.w(TAG, "end: " + t);
                }
            }
        });
    }

    /** The car's speed in km/h (GPM's vehicle speed listener), for the count-down. */
    public static void speed(int kmh) {
        LeafiaAaTurns.speedKmh = kmh < 0 ? 0 : kmh;
    }
}
