/*
 * Genesis G70 bridge, diagnostic: logs every cluster message the built-in navigation
 * sends (e/a.sendClusterData: type, int values, doubles, texts, raw frame) whenever a
 * type's content changes, so its HUD street line, side streets and exits can be matched
 * for Android Auto. Logging only: nothing sent changes. Tag LeafiaNAV.
 *
 * GPL-3.0 (Genesis G70 bridge).
 */
package com.mnsoft.navi;

import android.util.Log;

import java.util.Arrays;

public final class LeafiaNavLog {
    private static final String[] last = new String[256];

    private LeafiaNavLog() {
    }

    public static void logData(int type, int[] ints, double[] dbls, String[] strs, byte[] bytes) {
        try {
            StringBuilder s = new StringBuilder();
            if (ints != null) s.append(" ints=").append(Arrays.toString(ints));
            if (dbls != null) s.append(" dbls=").append(Arrays.toString(dbls));
            if (strs != null) s.append(" strs=").append(Arrays.toString(strs));
            if (bytes != null) {
                s.append(" bytes=");
                for (byte b : bytes) {
                    s.append(Character.forDigit((b >> 4) & 15, 16)).append(Character.forDigit(b & 15, 16));
                }
            }
            String v = s.toString();
            int k = type & 0xff;
            if (v.equals(last[k])) return;
            last[k] = v;
            Log.i("LeafiaNAV", "type=" + type + v);
        } catch (Throwable t) {
            // diagnostics must never disturb the navigation
        }
    }
}
