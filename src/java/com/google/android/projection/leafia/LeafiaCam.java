/*
 * Genesis G70 bridge: speed / red-light camera alerts on the HUD and cluster, from the owner's
 * camera list (/data/leafia/cameras.csv, see LeafiaCamDb). Runs in GPM (persistent, holds the GPS
 * permission; the car navigation has none), started from GalReceiverService.onCreate.
 *
 * GPM only decides what to show and publishes it as sys.leafia.cam = "kind,whole,tenths,unit"
 * ("0" = none); the car navigation (LeafiaNavCam, it owns the cluster's trap frames and holds its
 * speed-limit sign) puts the camera into its frames and sends the countdown. kind 1 = speed
 * camera, 2 = red-light camera; units as NavigationCluster (2 = mi, 3 = ft).
 *
 * GPL-3.0 (Genesis G70 bridge).
 */
package com.google.android.projection.leafia;

import android.content.Context;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.SystemClock;
import android.os.SystemProperties;
import android.util.Log;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;

public final class LeafiaCam implements LocationListener, Runnable {
    static final String TAG = "LeafiaCAM";
    static final String FILE = "/data/leafia/cameras.csv";
    static final String PROP = "sys.leafia.cam";
    static final double MILE = 1609.344;
    /** alert range: 0.3 mi, 0.5 mi from 45 mph; a camera already shown is followed to 0.5 mi */
    static final double RANGE = 0.3 * MILE, RANGE_FAST = 0.5 * MILE, FAST = 45 * MILE / 3600;
    static final long TICK_MS = 2000, STALE_MS = 10000;
    /** NavigationCluster distance units */
    static final int UNIT_MI = 2, UNIT_FT = 3;

    private static LeafiaCam sCam;

    private final Context ctx;
    private final Handler h;
    private LeafiaCamDb db;
    private long fileStamp = -1, fileSize = -1, lastFix;
    private double course = -1;
    private int shownIdx = -1;
    private String shown = "0";
    private final double[] d = new double[1];

    private LeafiaCam(Context c, Handler h) {
        this.ctx = c;
        this.h = h;
    }

    /** GalReceiverService.onCreate: start once; never throws into GPM. */
    public static synchronized void start(Context c) {
        if (sCam != null) return;
        try {
            HandlerThread t = new HandlerThread("LeafiaCam");
            t.start();
            Context app = c.getApplicationContext();
            final LeafiaCam cam = new LeafiaCam(app != null ? app : c, new Handler(t.getLooper()));
            sCam = cam;
            cam.h.post(new Runnable() {
                public void run() {
                    cam.begin();
                }
            });
        } catch (Throwable e) {
            Log.w(TAG, "start: " + e);
        }
    }

    private void begin() {
        publish("0");
        try {
            LocationManager lm = (LocationManager) ctx.getSystemService(Context.LOCATION_SERVICE);
            lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000, 0, this, h.getLooper());
            Log.i(TAG, "Leafia: camera alerts started (" + FILE + ")");
        } catch (Throwable e) {
            Log.w(TAG, "begin: " + e);
        }
        h.post(this);
    }

    /** every 2 s: reload a changed camera file, clear a camera when the GPS goes quiet */
    public void run() {
        try {
            File f = new File(FILE);
            boolean there = f.exists();
            long st = there ? f.lastModified() : 0, sz = there ? f.length() : 0;
            if (st != fileStamp || sz != fileSize) {
                fileStamp = st;
                fileSize = sz;
                load(f);
            }
            if (shownIdx >= 0 && SystemClock.elapsedRealtime() - lastFix > STALE_MS) {
                Log.i(TAG, "Leafia: no GPS fix, camera cleared");
                clear();
            }
        } catch (Throwable e) {
            Log.w(TAG, "tick: " + e);
        }
        h.postDelayed(this, TICK_MS);
    }

    private void load(File f) {
        if (!f.exists()) {
            if (db != null) Log.i(TAG, "Leafia: camera file removed");
            else Log.i(TAG, "Leafia: no camera file");
            db = null;
            if (shownIdx >= 0) clear();
            return;
        }
        BufferedReader r = null;
        try {
            r = new BufferedReader(new FileReader(f), 65536);
            long t0 = SystemClock.elapsedRealtime();
            db = LeafiaCamDb.read(r);
            Log.i(TAG, "Leafia: " + db.size() + " cameras loaded in " + (SystemClock.elapsedRealtime() - t0) + " ms");
        } catch (Throwable e) {
            Log.w(TAG, "load: " + e);
        } finally {
            try {
                if (r != null) r.close();
            } catch (Throwable e) {
                // ignore
            }
        }
    }

    public void onLocationChanged(Location l) {
        try {
            lastFix = SystemClock.elapsedRealtime();
            // the course only means something while moving; keep the last one when stopped
            if (l.hasBearing() && l.hasSpeed() && l.getSpeed() > 2.0f) course = l.getBearing();
            if (db == null || course < 0) return;
            double range = shownIdx >= 0 || (l.hasSpeed() && l.getSpeed() >= FAST) ? RANGE_FAST : RANGE;
            int i = db.ahead(l.getLatitude(), l.getLongitude(), course, range, d);
            if (i < 0) {
                if (shownIdx >= 0) {
                    Log.i(TAG, "Leafia: camera " + shownIdx + " passed");
                    clear();
                }
                return;
            }
            if (i != shownIdx) {
                Log.i(TAG, "Leafia: " + (db.kind[i] == LeafiaCamDb.REDLIGHT ? "red-light" : "speed") + " camera " + i
                        + " ahead, " + Math.round(d[0]) + " m");
            }
            shownIdx = i;
            publish(value(db.kind[i], d[0]));
        } catch (Throwable e) {
            Log.w(TAG, "fix: " + e);
        }
    }

    /** "kind,whole,tenths,unit": tenths of a mile, under 0.1 mi feet in tens */
    static String value(int kind, double m) {
        int t = (int) Math.round(m / MILE * 10);
        if (t >= 1) return kind + "," + (t / 10) + "," + (t % 10) + "," + UNIT_MI;
        int ft = (int) Math.round(m * 3.28084 / 10) * 10;
        return kind + "," + ft + ",0," + UNIT_FT;
    }

    private void clear() {
        shownIdx = -1;
        publish("0");
    }

    private void publish(String v) {
        if (v.equals(shown) && !"0".equals(v)) return;
        shown = v;
        try {
            SystemProperties.set(PROP, v);
        } catch (Throwable e) {
            Log.w(TAG, "prop: " + e);
        }
    }

    public void onStatusChanged(String p, int s, Bundle b) {
    }

    public void onProviderEnabled(String p) {
    }

    public void onProviderDisabled(String p) {
    }
}
