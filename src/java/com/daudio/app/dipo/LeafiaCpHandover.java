/*
 * Genesis G70 bridge: keep iAP2 alive when wireless CarPlay moves off Bluetooth.
 *
 * Wireless CarPlay starts with iAP2 over Bluetooth (LeafiaCpBridge). Once the CarPlay
 * session runs over Wi-Fi the iPhone sends disableBluetooth and the Bluetooth link drops;
 * the iPhone then expects iAP2 inside the CarPlay session's own channel. Without that,
 * everything that needs iAP2 after the start stops, including route guidance (the
 * turn-by-turn the cluster shows: DiPO's Iap2SvcStartRouteGuidanceUpdate failed "called
 * before the iap2 is ready").
 *
 * The handover (the same design as HMG-API's wireless CarPlay bridge, VysseCodes): when
 * the Bluetooth link drops during a wireless CarPlay session, or the iPhone's first iAP2
 * bytes arrive on the CarPlay channel, the iAP2 server starts a session on the CarPlay
 * client component (5, through the bridge's recvstart receiver);
 *   phone -> car: CarPlayService.oniAPSendMessage -> IIap2Service.Iap2SvcTransportReadDone
 *   car -> phone: iAP2 notification 0x51 (CarplayClientTransportData) -> CarPlayService.iAPSendMessage
 * and once that session is up route guidance is started on it again. DiPO's own iAP2
 * listener doesn't see that session's identification (dropNoti).
 *
 * Off switch: setprop persist.leafia.g70.cphandover 0.
 *
 * GPL-3.0 (Genesis G70 bridge).
 */
package com.daudio.app.dipo;

import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Log;

import com.daudio.app.dipo.telechips.CarPlayService;
import com.tcc.iap2.IIap2Service;
import com.tcc.iap2.Iap2NotiMsg;

import java.util.ArrayList;

public final class LeafiaCpHandover {
    static final String TAG = "LeafiaCP";
    static final int COMPONENT_BT = 4, COMPONENT_CARPLAY_CLIENT = 5;
    static final int NOTI_IDENTIFICATION_ACCEPTED = 0, NOTI_TRANSPORT_IDENTIFIER = 24;
    static final int TRANSPORT_WIRELESS = 1, MAX_PENDING = 64;

    static volatile CarPlayService sCp;
    /** a wireless CarPlay session runs; the CarPlay-channel iAP2 session was requested / is up */
    static volatile boolean sWireless, sClient, sClientUp;
    static final ArrayList<byte[]> sPending = new ArrayList<byte[]>();
    static Handler sTx;
    static int sSent, sFail;

    private LeafiaCpHandover() {
    }

    static boolean enabled() {
        try {
            Object v = Class.forName("android.os.SystemProperties").getMethod("get", String.class, String.class)
                    .invoke(null, "persist.leafia.g70.cphandover", "1");
            return !"0".equals(v);
        } catch (Throwable t) {
            return true;
        }
    }

    static Context context() throws Exception {
        return (Context) Class.forName("android.app.ActivityThread").getMethod("currentApplication").invoke(null);
    }

    static synchronized Handler tx() {
        if (sTx == null) {
            HandlerThread t = new HandlerThread("LeafiaCpHandover");
            t.start();
            sTx = new Handler(t.getLooper());
        }
        return sTx;
    }

    /** start (finish=false) or end the iAP2 server's session on a component (bridge's recvstart receiver) */
    static String sLastRecvstart;

    static void recvstart(int component, boolean finish) {
        sLastRecvstart = (finish ? "finish " : "start ") + component;
        Log.i(TAG, "Leafia: iAP2 server session " + sLastRecvstart);
        try {
            Intent i = new Intent("com.telechips.android.iap2.recvstart");
            i.setPackage("com.tcc.iap2server");
            i.putExtra("com.telechips.android.iap2.component", component);
            i.putExtra("leafia.finish", finish);
            context().sendBroadcast(i);
        } catch (Throwable t) {
            Log.w(TAG, "Leafia: recvstart " + component + " failed: " + t);
        }
    }

    // ---- CarPlayService (hooks at the start of its callbacks)

    /** the bridged iPhone of the running wireless session */
    static volatile String sPhone;

    public static void sessionStarted(CarPlayService cp, int transport) {
        sCp = cp;
        final String phone = LeafiaCpBridge.sessionDevice();
        sWireless = transport == TRANSPORT_WIRELESS && phone != null;
        sPhone = sWireless ? phone : null;
        sFromPhone = 0;
        Log.i(TAG, "Leafia: CarPlay session started transport=" + transport + " wireless=" + sWireless);
        // the iPhone in the car's projection device list (the iPhone may have started this
        // session itself, without the bridge's connectCarPlay); off the native callback
        if (sWireless) {
            tx().post(new Runnable() {
                @Override
                public void run() {
                    LeafiaCpRegister.connected(phone);
                }
            });
        }
    }

    public static void sessionFinalized(int type) {
        Log.i(TAG, "Leafia: CarPlay session finalized type=" + type + " carplay-channel iAP2=" + sClient);
        boolean client = sClient;
        final String phone = sPhone;
        sWireless = false;
        sPhone = null;
        sClient = false;
        sClientUp = false;
        synchronized (sPending) {
            sPending.clear();
        }
        if (client) recvstart(COMPONENT_CARPLAY_CLIENT, true);
        if (phone != null) {
            tx().post(new Runnable() {
                @Override
                public void run() {
                    LeafiaCpRegister.ended(phone);
                }
            });
        }
    }

    /** iAP2 bytes from the iPhone on the CarPlay channel */
    public static void fromPhone(CarPlayService cp, byte[] data, int len) {
        try {
            if (cp != null) sCp = cp;
            if (data == null || len <= 0 || !enabled()) return;
            if (!sWireless && LeafiaCpBridge.sessionDevice() == null && !sClient) return;   // USB CarPlay: DiPO's own path
            if (len > data.length) len = data.length;
            sFromPhone++;
            if (sFromPhone <= 3 || sFromPhone % 200 == 0) Log.i(TAG, "Leafia: CarPlay-channel iAP2 from the iPhone " + len + " bytes (#" + sFromPhone + ")");
            byte[] b = new byte[len];
            System.arraycopy(data, 0, b, 0, len);
            if (!sClient) startClient("iAP2 data on the CarPlay channel");
            IIap2Service s = LeafiaCpBridge.iap2();
            if (sClientUp && s != null) {
                flush(s);
                s.Iap2SvcTransportReadDone(b, len);
            } else {
                synchronized (sPending) {
                    if (sPending.size() < MAX_PENDING) sPending.add(b);
                }
            }
        } catch (Throwable t) {
            Log.w(TAG, "Leafia: CarPlay-channel iAP2 in failed: " + t);
        }
    }

    // ---- the bridge

    /** The iPhone's Bluetooth link closed (the bridge already ended its Bluetooth session). */
    public static void btDropped() {
        if (sWireless && enabled()) startClient("Bluetooth dropped during wireless CarPlay");
    }

    /** A new Bluetooth session starts: forget the old CarPlay-channel session. */
    public static void reset() {
        if (sClient) recvstart(COMPONENT_CARPLAY_CLIENT, true);
        sWireless = false;
        sClient = false;
        sClientUp = false;
        synchronized (sPending) {
            sPending.clear();
        }
    }

    static void startClient(String why) {
        if (sClient) return;
        sClient = true;
        sClientUp = false;
        recvstart(COMPONENT_CARPLAY_CLIENT, false);
        Log.i(TAG, "Leafia: iAP2 handover to the CarPlay channel (" + why + ")");
    }

    // ---- the iAP2 server (bridge's listener)

    public static void iap2Connected(int component) {
        if (component != COMPONENT_CARPLAY_CLIENT || !sClient) return;
        sClientUp = true;
        Log.i(TAG, "Leafia: CarPlay-channel iAP2 session up");
        IIap2Service s = LeafiaCpBridge.iap2();
        if (s == null) return;
        flush(s);
        sRouteTries = 0;
        tx().post(sRouteStart);
    }

    static final int ROUTE_TRIES = 30;
    static final long ROUTE_RETRY_MS = 1000;
    static int sRouteTries, sFromPhone;

    /**
     * DiPO's own route guidance start (e/b.M) ran while iAP2 was down; its listener gets the
     * updates once it is started again. The server refuses it ("called before the iap2 is
     * ready") until the iPhone has identified on the new session, which takes a moment after
     * the session is up: try once a second until it is accepted.
     */
    static final Runnable sRouteStart = new Runnable() {
        @Override
        public void run() {
            if (!sClientUp) return;
            IIap2Service s = LeafiaCpBridge.iap2();
            boolean ok = false;
            try {
                if (s != null) ok = s.Iap2SvcStartRouteGuidanceUpdate(new String[] { "RouteGuidanceComponent0" }, true, true);
            } catch (Throwable t) {
                Log.w(TAG, "Leafia: route guidance restart failed: " + t);
            }
            sRouteTries++;
            if (ok || sRouteTries >= ROUTE_TRIES) {
                Log.i(TAG, "Leafia: route guidance restarted on the CarPlay channel: " + ok + " (try " + sRouteTries + ")");
            } else {
                tx().postDelayed(this, ROUTE_RETRY_MS);
            }
        }
    };

    public static void iap2Disconnected(int component) {
        if (component == COMPONENT_CARPLAY_CLIENT && sClientUp) {
            sClientUp = false;
            Log.i(TAG, "Leafia: CarPlay-channel iAP2 session down");
        }
    }

    /** iAP2 bytes from the server for the CarPlay channel (notification 0x51): out to the iPhone */
    public static void toPhone(byte[] data) {
        final CarPlayService cp = sCp;
        if (cp == null || data == null || data.length == 0 || !sClient) return;
        final byte[] b = data.clone();
        tx().post(new Runnable() {
            @Override
            public void run() {
                try {
                    Object r = cp.iAPSendMessage(b, b.length);
                    sSent++;
                    if (sSent <= 3 || sSent % 200 == 0) Log.i(TAG, "Leafia: CarPlay-channel iAP2 sent " + b.length + " bytes (#" + sSent + ", " + r + ")");
                } catch (Throwable t) {
                    sFail++;
                    if (sFail <= 5 || sFail % 50 == 0) Log.w(TAG, "Leafia: CarPlay-channel iAP2 send failed: " + t);
                }
            }
        });
    }

    /** The bridge's iAP2 listener: notification 0x51 (CarplayClientTransportData) */
    public static void notify51(Iap2NotiMsg m) {
        try {
            if (m == null || !sClient) return;
            Iap2NotiMsg.Iap2ObjGroup g = m.getItemGroup();
            if (g == null) return;
            int n = g.getItemCnt();
            for (int i = 0; i < n; i++) {
                Iap2NotiMsg.Iap2ObjItem it = g.getObjItem(i);
                byte[] b = it == null ? null : it.getItemByteArray();
                if (b != null && b.length > 0) toPhone(b);
            }
        } catch (Throwable t) {
            Log.w(TAG, "Leafia: CarplayClientTransportData failed: " + t);
        }
    }

    /** DiPO's iAP2 listener: the CarPlay-channel session's identification isn't a new phone */
    public static boolean dropNoti(int what) {
        return sClient && (what == NOTI_IDENTIFICATION_ACCEPTED || what == NOTI_TRANSPORT_IDENTIFIER);
    }

    static void flush(IIap2Service s) {
        ArrayList<byte[]> all;
        synchronized (sPending) {
            if (sPending.isEmpty()) return;
            all = new ArrayList<byte[]>(sPending);
            sPending.clear();
        }
        for (byte[] b : all) {
            try {
                s.Iap2SvcTransportReadDone(b, b.length);
            } catch (Throwable t) {
                Log.w(TAG, "Leafia: buffered CarPlay-channel iAP2 failed: " + t);
            }
        }
        Log.i(TAG, "Leafia: flushed " + all.size() + " buffered CarPlay-channel packets");
    }
}
