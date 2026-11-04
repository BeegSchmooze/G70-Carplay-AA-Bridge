package com.daudio.app.dipo;

import android.util.Log;

import com.hkmc.cluster.NavigationCluster;
import com.tcc.iap2.Iap2NotiMsg;

import java.util.Arrays;

/**
 * CarPlay lane guidance on the cluster and HUD. DiPO's route guidance analyzer (e/u) receives
 * the iPhone's LaneGuidanceInformation (iAP2 0x7a) in e(Object) but only logs it; this turns it
 * into the cluster's 0xF1 lane frame, the one the car's own navigation and our Android Auto path
 * send. Ported from HMG-API's CpTurns.lanes (wireless-carplay-aa, AGPL-3.0).
 *
 * The cluster object comes from LeafiaCpTurn.updateTBTInfo (e/u's own NavigationCluster, whose
 * field name differs per firmware). A frame that arrives before it is sent with the first one.
 * clear() (e/u.nS stopTurnByTurn and e/u.disconnected) blanks the lanes.
 */
public final class LeafiaCpLane {
    static final String TAG = "LeafiaCP";
    static final byte LANES = (byte) 0xF1;
    static final int MAX = 8;

    static volatile NavigationCluster sCluster;
    static byte[] sPending, sLast;

    /** LeafiaCpTurn.updateTBTInfo: e/u's cluster */
    static void cluster(NavigationCluster nc) {
        if (nc == null || nc == sCluster) return;
        sCluster = nc;
        byte[] p;
        synchronized (LeafiaCpLane.class) {
            p = sPending;
            sPending = null;
        }
        if (p != null) send(p);
    }

    /** e/u.e(Object): the iPhone's LaneGuidanceInformation */
    public static void lanes(Object o) {
        try {
            if (!(o instanceof Iap2NotiMsg)) return;
            send(frame((Iap2NotiMsg) o));
        } catch (Throwable t) {
            Log.w(TAG, "Leafia: CarPlay lanes failed: " + t);
        }
    }

    /** e/u.nS (stopTurnByTurn) and e/u.disconnected: no lanes */
    public static void clear() {
        try {
            byte[] f = new byte[81];
            f[0] = LANES;
            send(f);
        } catch (Throwable t) {
            Log.w(TAG, "Leafia: CarPlay lanes clear failed: " + t);
        }
    }

    static void send(byte[] f) {
        synchronized (LeafiaCpLane.class) {
            if (sLast != null && Arrays.equals(sLast, f)) return;
            NavigationCluster nc = sCluster;
            if (nc == null) {
                sPending = f;
                return;
            }
            sLast = f;
            nc.updateLaneInfo(f);
        }
        Log.i(TAG, "Leafia: CarPlay lanes " + f[1] + (f[1] > 0 ? " " + describe(f) : ""));
    }

    static String describe(byte[] f) {
        StringBuilder sb = new StringBuilder();
        for (int k = 0; k < f[1]; k++) {
            if (k > 0) sb.append(' ');
            sb.append(f[k + 3] == 2 ? '*' : '-').append(f[k * 3 + 19]).append(',').append(f[k * 3 + 20]).append(',').append(f[k * 3 + 21]);
        }
        return sb.toString();
    }

    /** up to 8 lanes: f[1] count, f[3+k] status (1, or 2 = use this lane), f[19+3k..21+3k] arrows */
    public static byte[] frame(Iap2NotiMsg msg) {
        byte[] f = new byte[81];
        f[0] = LANES;
        Iap2NotiMsg.Iap2ObjGroup g = msg.getItemGroup();
        if (g == null) return f;
        Iap2NotiMsg.Iap2ObjGroup[] lanes = null;
        for (int k = 0; k < g.getItemCnt(); k++) {
            Iap2NotiMsg.Iap2ObjItem it = g.getObjItem(k);
            // LaneGuidanceLaneInformation: a group array (param type 13, item 2)
            if (it != null && it.getItemParamType() == 13 && it.getItemId() == 2) lanes = it.getItemGroupArray();
        }
        int n = 0;
        if (lanes != null) {
            for (int k = 0; k < lanes.length && n < MAX; k++) {
                int[] one = lane(lanes[k]);
                f[n + 3] = (byte) one[0];
                f[n * 3 + 19] = (byte) one[1];
                f[n * 3 + 20] = (byte) one[2];
                f[n * 3 + 21] = (byte) one[3];
                n++;
            }
        }
        f[1] = (byte) n;
        return f;
    }

    /** one lane: {status (1, or 2 highlighted), up to 3 arrows} from LaneStatus (1), LaneAngles (2), LaneAngleHighlight (3) */
    static int[] lane(Iap2NotiMsg.Iap2ObjGroup g) {
        int[] r = new int[4];
        r[0] = 1;
        if (g == null) return r;
        int[] angles = null, highlight = null;
        for (int k = 0; k < g.getItemCnt(); k++) {
            Iap2NotiMsg.Iap2ObjItem it = g.getObjItem(k);
            if (it == null) continue;
            int t = it.getItemParamType();
            if (t != 5 && t != 8) continue;
            int[] v = it.getItemIntArray();
            if (v == null || v.length == 0) continue;
            int id = it.getItemId();
            if (id == 1) {
                if (v[0] == 2) r[0] = 2;
            } else if (id == 2) {
                angles = v;
            } else if (id == 3) {
                highlight = v;
            }
        }
        if (highlight != null && highlight.length > 0) r[0] = 2;
        if (angles != null) {
            int n = 0;
            for (int k = 0; k < angles.length && n < 3; k++) {
                int icon = arrow(angles[k]);
                if (icon != 0) r[1 + n++] = icon;
            }
        }
        return r;
    }

    /** a lane angle (degrees, right positive) as the cluster's arrow: 1 straight, 2-4 right, 5 back, 6-8 left */
    public static int arrow(int a) {
        if (a > 180) a -= 360;
        else if (a < -180) a += 360;
        if (a >= 0) {
            if (a <= 22) return 1;
            if (a <= 67) return 2;
            if (a <= 112) return 3;
            return a <= 157 ? 4 : 5;
        }
        a = -a;
        if (a <= 22) return 1;
        if (a <= 67) return 8;
        if (a <= 112) return 7;
        return a <= 157 ? 6 : 5;
    }
}
