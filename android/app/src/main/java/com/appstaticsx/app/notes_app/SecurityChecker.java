package com.appstaticsx.app.notes_app;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.os.Build;
import android.provider.Settings;
import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.security.MessageDigest;

public class SecurityChecker {

    // Root Detection
    public static boolean isRooted() {
        return checkRootMethod1() || checkRootMethod2() || checkRootMethod3();
    }

    private static boolean checkRootMethod1() {
        String buildTags = Build.TAGS;
        return buildTags != null && buildTags.contains("test-keys");
    }

    private static boolean checkRootMethod2() {
        String[] paths = {
                "/system/app/Superuser.apk", "/sbin/su", "/system/bin/su",
                "/system/xbin/su", "/data/local/xbin/su", "/data/local/bin/su",
                "/system/sd/xbin/su", "/system/bin/failsafe/su", "/data/local/su",
                "/su/bin/su", "/system/xbin/daemonsu", "/system/bin/.ext/.su",
                "/system/usr/we-need-root/su", "/system/app/SuperSU.apk"
        };
        for (String path : paths) {
            if (new File(path).exists())
                return true;
        }
        return false;
    }

    private static boolean checkRootMethod3() {
        Process process = null;
        try {
            process = Runtime.getRuntime().exec(new String[] { "/system/xbin/which", "su" });
            BufferedReader in = new BufferedReader(new InputStreamReader(process.getInputStream()));
            return in.readLine() != null;
        } catch (Throwable t) {
            return false;
        } finally {
            if (process != null)
                process.destroy();
        }
    }

    // Emulator Detection
    public static boolean isEmulator() {
        return Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
                || "google_sdk".equals(Build.PRODUCT)
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu");
    }

    // Debugger Detection
    public static boolean isDebuggerConnected(Context context) {
        return android.os.Debug.isDebuggerConnected() ||
                (context.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
    }

    // USB Debugging Detection
    public static boolean isUsbDebuggingEnabled(Context context) {
        return Settings.Global.getInt(context.getContentResolver(),
                Settings.Global.ADB_ENABLED, 0) == 1;
    }

    // Signature Verification
    public static boolean verifySignature(Context context) {
        try {
            PackageManager packageManager = context.getPackageManager();
            Signature[] signatures;

            // Use GET_SIGNING_CERTIFICATES for Android P (API 28) and above
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                PackageInfo packageInfo = packageManager.getPackageInfo(
                        context.getPackageName(),
                        PackageManager.GET_SIGNING_CERTIFICATES);
                signatures = packageInfo.signingInfo.getApkContentsSigners();
            } else {
                // Suppress deprecation warning for older Android versions
                // GET_SIGNATURES is deprecated but required for API < 28
                @SuppressWarnings("deprecation")
                PackageInfo packageInfo = packageManager.getPackageInfo(
                        context.getPackageName(),
                        PackageManager.GET_SIGNATURES);
                @SuppressWarnings("deprecation")
                Signature[] legacySignatures = packageInfo.signatures;
                signatures = legacySignatures;
            }

            if (signatures == null)
                return false;

            for (Signature signature : signatures) {
                MessageDigest md = MessageDigest.getInstance("SHA-256");
                md.update(signature.toByteArray());
                String currentSignature = bytesToHex(md.digest());

                // Replace with your release key SHA-256 fingerprint
                String expectedSignature = "9F7D32D7D855928B88A9B0F6A2E6EE5A04DC401D87B23FC286CBA7C17860D634";

                if (!currentSignature.equalsIgnoreCase(expectedSignature)) {
                    return false;
                }
            }
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    // Installer Verification (Play Store only)
    public static boolean verifyInstaller(Context context) {
        return true;

        /*
         * String installer = context.getPackageManager()
         * .getInstallerPackageName(context.getPackageName());
         * return installer != null && installer.equals("com.android.vending");
         */ // for Xiaomi GetApps - com.xiaomi.mipicks
    }

    // Hook Detection (Xposed, Frida)
    public static boolean isHookDetected() {
        try {
            throw new Exception("PairIPCore");
        } catch (Exception e) {
            int zygoteInitCallCount = 0;
            for (StackTraceElement stackTraceElement : e.getStackTrace()) {
                if (stackTraceElement.getClassName().contains("com.android.internal.os.ZygoteInit")) {
                    zygoteInitCallCount++;
                    if (zygoteInitCallCount == 2) {
                        return true; // Xposed detected
                    }
                }
                if (stackTraceElement.getClassName().contains("com.saurik.substrate") ||
                        stackTraceElement.getClassName().contains("de.robv.android.xposed")) {
                    return true;
                }
            }
        }
        return false;
    }

    // Master Check
    public static boolean isPairIPSecure(Context context) {
        return !isRooted()
                && !isEmulator()
                && !isDebuggerConnected(context)
                && !isUsbDebuggingEnabled(context)
                && verifySignature(context)
                && verifyInstaller(context)
                && !isHookDetected();
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte b : bytes) {
            result.append(String.format("%02X", b));
        }
        return result.toString();
    }
}
