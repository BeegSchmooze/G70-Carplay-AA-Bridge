package com.daudio.app.dipo;

import android.bluetooth.BluetoothDevice;
import android.content.Context;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Log;

import com.broadcom.bt.hfdevice.hfbtcm.HfDeviceBTCMManager;

/**
 * Wireless CarPlay coming back by itself after a drop.
 *
 * 1. report: tells the car's Bluetooth connection manager (BTCM) which iPhone the wireless
 *    CarPlay session belongs to. BTCM leaves the CarPlay iPhone out of its normal hands-free
 *    auto-connect and reconnects it through its wireless CarPlay path instead, which only knows
 *    a device once the CarPlay side reports a successful wireless connection:
 *    btcmSetWPPConectionResult(address, 1, 0) -> BTCMSM_SET_SPP_AUTO_CONNECTION_SUCCESS ->
 *    mAutoConnectedWCPDevAddr. Units built with wireless CarPlay report it; the US G70 never
 *    did, and our bridge starts CarPlay its own way. Enough for engine off and on (BTCM runs its
 *    auto-connect on wake). Called for every wireless session.
 * 2. retry: walking away only drops the Wi-Fi session (the car itself disconnects the iPhone's
 *    Bluetooth once CarPlay is on Wi-Fi), so BTCM sees no lost link and never starts its
 *    auto-connect. When a wireless session ends, ask for it (btcmDoDriveAutoConnection, the
 *    start-up auto-connect) every RETRY_MS for up to TRIES times, until the iPhone is connected
 *    again, a CarPlay session starts, or BTCM is busy paging (that round is skipped).
 *
 * persist.leafia.g70.cpreconnect=0 turns both off.
 */
public final class LeafiaCpReconnect {
    static final String TAG = "LeafiaCP";
    static final int CONN_SUCCESS = 1, REASON_NONE = 0;
    static long RETRY_MS = 30000;
    static int TRIES = 20;

    static Handler sHandler;
    /** bumped by every session start / end: a pending retry of an older one stops */
    static volatile int sGeneration;

    private LeafiaCpReconnect() {
    }

    static boolean enabled() {
        try {
            Object v = Class.forName("android.os.SystemProperties").getMethod("get", String.class, String.class)
                    .invoke(null, "persist.leafia.g70.cpreconnect", "1");
            return !"0".equals(v);
        } catch (Throwable t) {
            return true;
        }
    }

    static synchronized Handler handler() {
        if (sHandler == null) {
            HandlerThread t = new HandlerThread("LeafiaCpReconnect");
            t.start();
            sHandler = new Handler(t.getLooper());
        }
        return sHandler;
    }

    /** a wireless CarPlay session with this iPhone (its Bluetooth address) is up */
    public static void report(Context c, String phone) {
        sGeneration++;
        if (phone == null || phone.length() == 0) return;
        if (!enabled()) {
            Log.i(TAG, "Leafia: CarPlay reconnect report off (persist.leafia.g70.cpreconnect=0)");
            return;
        }
        try {
            HfDeviceBTCMManager m = HfDeviceBTCMManager.getLocalBTCMManager(c);
            if (m == null) {
                Log.w(TAG, "Leafia: CarPlay reconnect: no Bluetooth connection manager");
                return;
            }
            boolean ok = m.IbtcmSetWPPConectionResult(phone, CONN_SUCCESS, REASON_NONE);
            Log.i(TAG, "Leafia: CarPlay reconnect: told the Bluetooth manager " + phone + " is the wireless CarPlay iPhone, accepted=" + ok);
        } catch (Throwable t) {
            Log.w(TAG, "Leafia: CarPlay reconnect report failed: " + t);
        }
    }

    /** the wireless CarPlay session with this iPhone ended: have BTCM look for it again */
    public static void sessionEnded(final Context c, final String phone) {
        final int gen = ++sGeneration;
        if (phone == null || phone.length() == 0 || !enabled()) return;
        Log.i(TAG, "Leafia: CarPlay reconnect: session ended, asking the Bluetooth manager to look for " + phone
                + " every " + RETRY_MS / 1000 + " s (up to " + TRIES + " times)");
        handler().postDelayed(new Runnable() {
            int n;

            @Override
            public void run() {
                if (gen != sGeneration) return;   // a session started (or ended again) since
                n++;
                if (tick(c, phone, n) && n < TRIES) handler().postDelayed(this, RETRY_MS);
            }
        }, RETRY_MS);
    }

    /** one retry; false when done (iPhone back, no manager) */
    static boolean tick(Context c, String phone, int n) {
        try {
            HfDeviceBTCMManager m = HfDeviceBTCMManager.getLocalBTCMManager(c);
            if (m == null) {
                Log.w(TAG, "Leafia: CarPlay reconnect: no Bluetooth connection manager, stopping");
                return false;
            }
            if (connected(m, phone)) {
                Log.i(TAG, "Leafia: CarPlay reconnect: " + phone + " is connected again, stopping");
                return false;
            }
            if (m.IbtcmGetPagingStatus() != 0) {
                Log.i(TAG, "Leafia: CarPlay reconnect: Bluetooth manager busy paging, try " + n + " skipped");
                return true;
            }
            boolean ok = m.IbtcmDoDriveAutoConnection();
            Log.i(TAG, "Leafia: CarPlay reconnect: try " + n + ", auto-connect started=" + ok);
        } catch (Throwable t) {
            Log.w(TAG, "Leafia: CarPlay reconnect try failed: " + t);
        }
        return true;
    }

    static boolean connected(HfDeviceBTCMManager m, String phone) {
        return same(m.IbtcmGetConnectedDevice1(), phone) || same(m.IbtcmGetConnectedDevice2(), phone);
    }

    static boolean same(BluetoothDevice d, String phone) {
        return d != null && phone.equalsIgnoreCase(d.getAddress());
    }
}
