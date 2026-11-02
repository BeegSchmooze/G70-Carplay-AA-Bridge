/*
 * Genesis G70 bridge: wireless Android Auto after the phone walked away.
 *
 * When the phone leaves with the car running, the wireless session can outlive it: no
 * goodbye ever arrives, GPM's status stays "connected", and when the phone comes back
 * and starts the Bluetooth (RFCOMM) negotiation again, WirelessExplorer.startRfcommNego
 * logs "Wireless AA connection sequence is over Start, not re-init!" and never starts a
 * session; Bluetooth reconnects but Android Auto doesn't.
 *
 * A phone only starts that negotiation when it has no session, so when the SAME phone
 * (same Bluetooth address) starts it while GPM still holds one, that session is dead:
 * end it with GPM's own teardown (GalConnectionManager.disconnectSession). The new
 * session is not started here (the old session's disconnect notices are still on their
 * way and must not land on it): the phone retries within seconds and that attempt finds
 * GPM idle. Another phone never ends a working session.
 *
 * GPL-3.0 (Genesis G70 bridge).
 */
package com.google.android.projection.service;

import android.bluetooth.BluetoothDevice;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import java.lang.reflect.Field;

public final class LeafiaAaRestart {
    static final String TAG = "LeafiaAA";

    private LeafiaAaRestart() {
    }

    /** Called by startRfcommNego when GPM's status says a session is past its start. */
    public static void staleStart(GalReceiverService s, BluetoothDevice d) {
        try {
            String phone = d == null ? null : d.getAddress();
            String held = s.getGpmBtAddress(2);
            int status = s.getGpmStatus(false);
            int mode = s.getGpmSessionConnectMode();
            if (phone == null || held == null || !phone.equalsIgnoreCase(held)) {
                Log.i(TAG, "Leafia: wireless start from another phone while a session is up (status " + status
                        + ", mode " + mode + "): left alone");
                return;
            }
            Log.w(TAG, "Leafia: the same phone started again while its wireless session is still up (status "
                    + status + ", mode " + mode + "): ending the stale session; the phone's retry starts a new one");
            Field f = GalReceiverService.class.getDeclaredField("mConnectionManager");
            f.setAccessible(true);
            final GalConnectionManager m = (GalConnectionManager) f.get(s);
            if (m == null) return;
            // GPM ends sessions on its main thread (ConnectionHandler); this runs on Bluetooth's
            new Handler(Looper.getMainLooper()).post(new Runnable() {
                @Override
                public void run() {
                    try {
                        m.disconnectSession(true, true);
                        Log.i(TAG, "Leafia: stale wireless session ended");
                    } catch (Throwable t) {
                        Log.w(TAG, "Leafia: ending the stale wireless session failed: " + t);
                    }
                }
            });
        } catch (Throwable t) {
            Log.w(TAG, "Leafia: stale wireless session check failed: " + t);
        }
    }
}
