/*
 * Genesis G70 bridge: put the wireless CarPlay iPhone in the car's projection device list.
 *
 * The car's PhoneProjection app keeps the wireless device list (Device Connections, auto
 * connection) and only fills it when the projection app reports a device:
 * PPManager.requestWLDeviceInfoAdd / requestWLDeviceConnectStatusUpdate. GPM does that for
 * Android Auto phones; this US firmware's DiPO never does it for wireless CarPlay (it was
 * shipped stubbed out), so the iPhone is never saved. Called when a wireless CarPlay
 * session starts (connected) and ends (disconnected), with the same device entry and the
 * same order GPM uses: info, ready, connecting, connected; projection type CarPlay
 * (WLD_CP), wireless, the Bluetooth address (also the serial, which the list is keyed on)
 * and name, and the car's current user profile.
 *
 * The iPhone drops Bluetooth once CarPlay runs over Wi-Fi, so the end of the Bluetooth
 * session is not the end of CarPlay: disconnected() is ignored while a wireless CarPlay
 * session runs (the session's end reports it).
 *
 * GPL-3.0 (Genesis G70 bridge).
 */
package com.daudio.app.dipo;

import android.bluetooth.BluetoothAdapter;
import android.content.Context;
import android.phoneprojection.PPManager;
import android.phoneprojection.WLDeviceInfo;
import android.util.Log;

import com.hkmc.userprofile.UserProfileManager;

public final class LeafiaCpRegister {
    static final String TAG = "LeafiaCP";
    static final int WLD_CP = 1, TRANSFER_WIRELESS = 1;
    static final int STATE_CONNECTING = 2, STATE_CONNECTED = 3, STATE_DISCONNECTED = 4;

    /** the iPhone reported connected (null when none) */
    static volatile String sConnected;

    private LeafiaCpRegister() {
    }

    static Context context() throws Exception {
        return (Context) Class.forName("android.app.ActivityThread").getMethod("currentApplication").invoke(null);
    }

    static WLDeviceInfo entry(Context c, String addr) {
        String name = null;
        try {
            name = BluetoothAdapter.getDefaultAdapter().getRemoteDevice(addr).getName();
        } catch (Throwable t) {
            // keep the address as the name
        }
        if (name == null || name.length() == 0) name = addr;
        int user = -1;
        try {
            if (com.hkmc.Feature.hasFeature("com.hkmc.software.user.profile")) user = new UserProfileManager(c).getUserType();
        } catch (Throwable t) {
            Log.w(TAG, "Leafia: no user profile: " + t);
        }
        return new WLDeviceInfo(addr, name, "", addr, user, WLD_CP, TRANSFER_WIRELESS, true, true, false);
    }

    /** connectCarPlay ran for the bridged iPhone */
    public static void connected() {
        String addr = LeafiaCpBridge.sessionDevice();
        if (addr == null) {
            Log.w(TAG, "Leafia: CarPlay connected without a bridged iPhone, not added to the device list");
            return;
        }
        connected(addr);
    }

    /** CarPlay started for this iPhone: add it to the list (or update it) and mark it connected. */
    public static synchronized void connected(String addr) {
        if (addr == null || addr.equals(sConnected)) return;
        try {
            Context c = context();
            PPManager pp = (PPManager) c.getSystemService("phoneprojection");
            if (pp == null) {
                Log.w(TAG, "Leafia: no phoneprojection service");
                return;
            }
            WLDeviceInfo d = entry(c, addr);
            pp.requestWLDeviceInfoAdd(d);
            pp.requestWLDeviceReadyStatusUpdate(d, 1);
            pp.requestWLDeviceConnectStatusUpdate(d, STATE_CONNECTING);
            pp.requestWLDeviceConnectStatusUpdate(d, STATE_CONNECTED);
            sConnected = addr;
            Log.i(TAG, "Leafia: iPhone " + d.getWLDevName() + " (" + addr + ") added to the projection device list, connected");
        } catch (Throwable t) {
            Log.w(TAG, "Leafia: adding the iPhone to the device list failed: " + t);
        }
    }

    /** The bridged iPhone's Bluetooth session ended: CarPlay over Wi-Fi may still run. */
    public static void disconnected(String addr) {
        if (LeafiaCpHandover.sWireless) return;   // wireless CarPlay runs: its end reports it
        ended(addr);
    }

    /** CarPlay (or the iPhone's only link) ended: mark it disconnected (it stays in the list). */
    public static synchronized void ended(String addr) {
        if (addr == null) addr = sConnected;
        if (addr == null) return;
        sConnected = null;
        try {
            Context c = context();
            PPManager pp = (PPManager) c.getSystemService("phoneprojection");
            if (pp == null) return;
            WLDeviceInfo d = entry(c, addr);
            pp.requestWLDeviceConnectStatusUpdate(d, STATE_DISCONNECTED);
            pp.requestWLDeviceReadyStatusUpdate(d, 0);
            Log.i(TAG, "Leafia: iPhone " + addr + " marked disconnected in the device list");
        } catch (Throwable t) {
            Log.w(TAG, "Leafia: device list disconnect update failed: " + t);
        }
    }
}
