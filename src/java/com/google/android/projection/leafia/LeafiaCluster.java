/*
 * Genesis G70 bridge: the cluster/HUD calls used by LeafiaAaTurns, made directly on the
 * head unit's com.hkmc.cluster.NavigationCluster. Same calls and arguments as
 * HMG-API's hmgapi.hook.Cluster (VysseCodes, AGPL-3.0), without its hook-point layer.
 * Every call is a no-op on failure: the cluster is a display and must not take GPM down.
 *
 * AGPL-3.0 (derived from HMG-API).
 */
package com.google.android.projection.leafia;

import android.content.Context;
import android.util.Log;

import com.hkmc.cluster.NavigationCluster;

final class LeafiaCluster {
    /** NavigationCluster's distance units */
    static final int UNIT_M = 0, UNIT_KM = 1, UNIT_MI = 2, UNIT_FT = 3, UNIT_YD = 4;

    private final NavigationCluster nc;

    private LeafiaCluster(NavigationCluster nc) {
        this.nc = nc;
    }

    static LeafiaCluster of(Context c) {
        try {
            return new LeafiaCluster(new NavigationCluster(c));
        } catch (Throwable t) {
            Log.w(LeafiaAa.TAG, "no NavigationCluster: " + t);
            return null;
        }
    }

    static String hex(byte[] b) {
        StringBuilder s = new StringBuilder(b.length * 2);
        for (byte x : b) {
            s.append(Character.forDigit((x >> 4) & 15, 16)).append(Character.forDigit(x & 15, 16));
        }
        return s.toString();
    }

    private static void fail(String what, Throwable t) {
        Log.w(LeafiaAa.TAG, what + " failed: " + t);
    }

    void tbtInfo(int type, int sideStreet, float direction, float distance, int distanceErr, int combiSideStreet,
            int unit, int bar, int barErr) {
        try {
            nc.updateTBTInfo(type, sideStreet, direction, distance, distanceErr, combiSideStreet, unit, bar, barErr);
        } catch (Throwable t) {
            fail("updateTBTInfo", t);
        }
    }

    void tbtSubInfo(float distance, int distanceErr, int unit, int hour, int minute, int timeType, int timeFormat,
            float direction, int directionErr, int estPoint) {
        try {
            nc.updateTBTSubInfo(distance, distanceErr, unit, hour, minute, timeType, timeFormat, direction, directionErr, estPoint);
        } catch (Throwable t) {
            fail("updateTBTSubInfo", t);
        }
    }

    void tbtSubInfo2C(int a, int b, int c, int d, int e, int f, int g, int h, int i) {
        try {
            nc.updateTBTSubInfo2C(a, b, c, d, e, f, g, h, i);
        } catch (Throwable t) {
            fail("updateTBTSubInfo2C", t);
        }
    }

    private String lastFrame;

    void turnListNew(byte[] frame) {
        try {
            // G70 diagnostic: the HUD street line isn't shown yet; log each new frame (hex)
            // to compare with the built-in navigation's (logged by the navigation app)
            String hex = hex(frame);
            if (!hex.equals(lastFrame)) {
                lastFrame = hex;
                Log.i(LeafiaAa.TAG, "Leafia: AA turn list frame " + hex);
            }
            nc.updateTPTurnListNew(frame);
        } catch (Throwable t) {
            fail("updateTPTurnListNew", t);
        }
    }

    void laneInfo(byte[] frame) {
        try {
            nc.updateLaneInfo(frame);
        } catch (Throwable t) {
            fail("updateLaneInfo", t);
        }
    }

    void destinationName(int type, String name) {
        try {
            NavigationCluster.DestinationName d = new NavigationCluster.DestinationName();
            d.type = type;
            d.name = name;
            nc.updateTPFlexibleDestinationName(d);
        } catch (Throwable t) {
            fail("updateTPFlexibleDestinationName", t);
        }
    }

    void crossroadName(String name) {
        try {
            NavigationCluster.CrossroadName c = new NavigationCluster.CrossroadName();
            c.name = name;
            nc.updateTPCrossroadName(c);
        } catch (Throwable t) {
            fail("updateTPCrossroadName", t);
        }
    }

    /** One upcoming turn for turnList (NavigationCluster.TurnList). */
    static final class Turn {
        int type, direction, traffic, no, unit;
        String name = "", exitNumber = "";
        float distance;
    }

    void turnList(Turn[] turns) {
        try {
            NavigationCluster.TurnList[] a = new NavigationCluster.TurnList[turns.length];
            for (int k = 0; k < turns.length; k++) {
                Turn t = turns[k];
                NavigationCluster.TurnList o = new NavigationCluster.TurnList();
                o.type = t.type;
                o.direction = t.direction;
                o.traffic = t.traffic;
                o.no = t.no;
                o.name = t.name;
                o.exitNumber = t.exitNumber;
                o.distance = t.distance;
                o.unit = t.unit;
                a[k] = o;
            }
            nc.updateTPTurnList(a);
        } catch (Throwable t) {
            fail("updateTPTurnList", t);
        }
    }
}
