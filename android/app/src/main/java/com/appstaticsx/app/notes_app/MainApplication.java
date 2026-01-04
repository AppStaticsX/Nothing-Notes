package com.appstaticsx.app.notes_app;

import android.app.Application;
import android.os.Process;
import android.util.Log;

public class MainApplication extends Application {

    private static final String TAG = "PairIPCore";

    @Override
    public void onCreate() {
        super.onCreate();

        // PairIP Core Protection
        if (!SecurityChecker.isPairIPSecure(this)) {
            Log.e(TAG, "Security check failed - App terminated");
            
            // Immediate termination
            Process.killProcess(Process.myPid());
            System.exit(1);
        }

        Log.i(TAG, "PairIP Core: Device secure");
    }
}
