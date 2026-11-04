/*
 * Genesis G70 bridge: the owner's speed / red-light camera list and the "camera ahead" match.
 * The list is a CSV the owner copies to the head unit (lat,lon,type,speed,heading,f2,category,
 * the Uniden R-series database layout); the bridge ships no camera data. Matching follows the
 * Uniden matcher: f2 1 = alert only within 30 degrees of the camera's approach heading, f2 2 =
 * that heading or its reverse, heading 360 = any direction. Plain Java (no Android) so it can be
 * tested on a PC.
 *
 * GPL-3.0 (Genesis G70 bridge).
 */
package com.google.android.projection.leafia;

import java.io.BufferedReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;

public final class LeafiaCamDb {
    public static final int NONE = 0, SPEED = 1, REDLIGHT = 2;
    static final double EARTH_M = 6371000.0;
    /** grid cell size in degrees (about 1.1 km north-south) */
    static final double CELL = 0.01;
    /** heading tolerance, as the Uniden matcher */
    static final double HEADING_TOL = 30.0;

    final double[] lat, lon;
    final int[] kind, heading, mode;
    private final HashMap<Long, int[]> grid = new HashMap<Long, int[]>();

    private LeafiaCamDb(ArrayList<double[]> rows) {
        int n = rows.size();
        lat = new double[n];
        lon = new double[n];
        kind = new int[n];
        heading = new int[n];
        mode = new int[n];
        HashMap<Long, ArrayList<Integer>> cells = new HashMap<Long, ArrayList<Integer>>();
        for (int i = 0; i < n; i++) {
            double[] r = rows.get(i);
            lat[i] = r[0];
            lon[i] = r[1];
            kind[i] = (int) r[2];
            heading[i] = (int) r[3];
            mode[i] = (int) r[4];
            Long k = key(cell(lat[i]), cell(lon[i]));
            ArrayList<Integer> l = cells.get(k);
            if (l == null) cells.put(k, l = new ArrayList<Integer>());
            l.add(i);
        }
        for (java.util.Map.Entry<Long, ArrayList<Integer>> e : cells.entrySet()) {
            ArrayList<Integer> l = e.getValue();
            int[] a = new int[l.size()];
            for (int i = 0; i < a.length; i++) a[i] = l.get(i);
            grid.put(e.getKey(), a);
        }
    }

    public int size() {
        return lat.length;
    }

    static int cell(double deg) {
        return (int) Math.floor(deg / CELL);
    }

    static Long key(int a, int b) {
        return Long.valueOf(((long) a << 32) ^ (b & 0xffffffffL));
    }

    /** Reads the CSV; lines that don't parse (the header, blanks) are skipped. */
    public static LeafiaCamDb read(BufferedReader r) throws IOException {
        ArrayList<double[]> rows = new ArrayList<double[]>();
        String line;
        while ((line = r.readLine()) != null) {
            String[] f = line.trim().split(",");
            if (f.length < 3) continue;
            try {
                double la = Double.parseDouble(f[0].trim()), lo = Double.parseDouble(f[1].trim());
                if (la < -90 || la > 90 || lo < -180 || lo > 180) continue;
                String t = f[2].trim().toLowerCase();
                // every ticket camera alerts; only red-light ones get the red-light pattern
                int k = t.startsWith("red") ? REDLIGHT : SPEED;
                int h = f.length > 4 ? Integer.parseInt(f[4].trim()) : 360;
                int m = f.length > 5 ? Integer.parseInt(f[5].trim()) : 2;
                if (h <= 0 || h > 360) h = 360;
                rows.add(new double[] {la, lo, k, h, m});
            } catch (NumberFormatException e) {
                // header or a bad line
            }
        }
        return new LeafiaCamDb(rows);
    }

    /** great-circle distance in metres */
    static double dist(double la1, double lo1, double la2, double lo2) {
        double p1 = Math.toRadians(la1), p2 = Math.toRadians(la2);
        double dp = p2 - p1, dl = Math.toRadians(lo2 - lo1);
        double a = Math.sin(dp / 2) * Math.sin(dp / 2) + Math.cos(p1) * Math.cos(p2) * Math.sin(dl / 2) * Math.sin(dl / 2);
        return 2 * EARTH_M * Math.asin(Math.min(1.0, Math.sqrt(a)));
    }

    /** initial bearing from point 1 to point 2, 0..360 */
    static double bearing(double la1, double lo1, double la2, double lo2) {
        double p1 = Math.toRadians(la1), p2 = Math.toRadians(la2), dl = Math.toRadians(lo2 - lo1);
        double y = Math.sin(dl) * Math.cos(p2);
        double x = Math.cos(p1) * Math.sin(p2) - Math.sin(p1) * Math.cos(p2) * Math.cos(dl);
        return (Math.toDegrees(Math.atan2(y, x)) + 360) % 360;
    }

    /** smallest angle between two bearings, 0..180 */
    static double diff(double a, double b) {
        double d = Math.abs(a - b) % 360;
        return d > 180 ? 360 - d : d;
    }

    boolean headingMatches(int i, double course) {
        int h = heading[i];
        if (h == 360) return true;
        if (diff(course, h) <= HEADING_TOL) return true;
        return mode[i] == 2 && diff(course, h + 180) <= HEADING_TOL;
    }

    /**
     * The nearest camera ahead within range metres for a car at (la, lo) travelling on course
     * (degrees), or -1. Ahead = the camera's bearing from the car within 30 degrees of the course
     * (within 90 degrees once closer than 40 m, where GPS noise swings the bearing). A red-light
     * camera wins over a speed camera at the same spot (combined installations are two records).
     */
    public int ahead(double la, double lo, double course, double range, double[] distOut) {
        int ca = cell(la), co = cell(lo);
        int span = (int) Math.ceil(range / 1000.0) + 1;
        int best = -1;
        double bestD = Double.MAX_VALUE;
        for (int a = ca - span; a <= ca + span; a++) {
            for (int b = co - span; b <= co + span; b++) {
                int[] l = grid.get(key(a, b));
                if (l == null) continue;
                for (int i : l) {
                    double d = dist(la, lo, lat[i], lon[i]);
                    if (d > range) continue;
                    double off = diff(bearing(la, lo, lat[i], lon[i]), course);
                    if (off > (d < 40 ? 90 : HEADING_TOL)) continue;
                    if (!headingMatches(i, course)) continue;
                    boolean same = best >= 0 && Math.abs(d - bestD) < 1.0;
                    if (d < bestD - 1.0 || (same && kind[i] == REDLIGHT)) {
                        best = i;
                        bestD = Math.min(d, bestD);
                    }
                }
            }
        }
        if (best >= 0 && distOut != null) distOut[0] = bestD;
        return best;
    }
}
