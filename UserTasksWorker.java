package com.embarcadero.usertasks;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

/**
 * UserTasksWorker
 * ---------------
 * Android WorkManager Worker that fires a local notification.
 * Scheduled from Delphi via JNI bridge (UserTasks.WorkManager.pas).
 *
 * Input data keys:
 *   "notif_title" - Notification title string
 *   "notif_body"  - Notification body text
 *
 * Place this file in:
 *   <ProjectDir>/java/com/embarcadero/usertasks/UserTasksWorker.java
 * and add it to the Delphi project's Android > Compiles Java Files list.
 */
public class UserTasksWorker extends Worker {

    private static final String CHANNEL_ID   = "UserTasksChannel";
    private static final String CHANNEL_NAME = "UserTasks Reminders";
    private static final int    NOTIF_ID     = 1001;

    public UserTasksWorker(@NonNull Context context,
                           @NonNull WorkerParameters params) {
        super(context, params);
    }

    @NonNull
    @Override
    public Result doWork() {
        // Read input data passed from Delphi
        String title = getInputData().getString("notif_title");
        String body  = getInputData().getString("notif_body");

        if (title == null || title.isEmpty()) title = "Start Working!";
        if (body  == null || body.isEmpty())  body  = "Time to focus — you've got this!";

        Context ctx = getApplicationContext();

        // Create notification channel (required on Android 8+)
        createNotificationChannel(ctx);

        // Build and show the notification
        showNotification(ctx, title, body);

        return Result.success();
    }

    // -----------------------------------------------------------------------

    private void createNotificationChannel(Context ctx) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            );
            channel.setDescription("Periodic work reminder notifications");
            channel.enableVibration(true);

            NotificationManager nm =
                ctx.getSystemService(NotificationManager.class);
            if (nm != null) {
                nm.createNotificationChannel(channel);
            }
        }
    }

    private void showNotification(Context ctx, String title, String body) {
        // Tap the notification to open the app
        Intent launchIntent = ctx.getPackageManager()
            .getLaunchIntentForPackage(ctx.getPackageName());

        PendingIntent pi = null;
        if (launchIntent != null) {
            pi = PendingIntent.getActivity(
                ctx,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT |
                    (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                        ? PendingIntent.FLAG_IMMUTABLE : 0)
            );
        }

        NotificationCompat.Builder builder =
            new NotificationCompat.Builder(ctx, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setVibrate(new long[]{0, 250, 100, 250});

        if (pi != null) {
            builder.setContentIntent(pi);
        }

        NotificationManagerCompat nm = NotificationManagerCompat.from(ctx);
        // POST_NOTIFICATIONS permission must be granted on Android 13+
        try {
            nm.notify(NOTIF_ID, builder.build());
        } catch (SecurityException e) {
            // Permission not granted — silently ignore
        }
    }
}
