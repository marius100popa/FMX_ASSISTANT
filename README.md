# UserTasks — Delphi FMX Android App
## WorkManager Periodic Notification (every 15 minutes)

---

## Project Structure

```
UserTasks/
├── UserTasks.dpr                          ← Delphi project file
├── UserTasks.MainForm.pas                 ← Main FMX form (Pascal)
├── UserTasks.MainForm.fmx                 ← FMX layout
├── UserTasks.WorkManager.pas              ← JNI bridge to WorkManager
├── AndroidManifest.additions.xml          ← Manifest snippets to merge
└── java/
    └── com/embarcadero/usertasks/
        └── UserTasksWorker.java           ← Android Worker (Java)
```

---

## Step-by-Step Setup in Delphi 12 / RAD Studio

### 1. Add the Java Worker to the project

1. Copy `java/com/embarcadero/usertasks/UserTasksWorker.java` into your project directory (keep the folder structure).
2. In the **Project Manager**, right-click **Android 64-bit → Compiles Java Files** and add `UserTasksWorker.java`.
3. Delphi will compile it to a `.class` via the Android SDK `javac`.

---

### 2. Add WorkManager to build.gradle

Open **Project > Options > Build > Android > Gradle** and add to the
*"Additional dependencies"* field (or edit `build.gradle` directly):

```gradle
dependencies {
    implementation 'androidx.work:work-runtime:2.9.0'
    implementation 'androidx.core:core:1.12.0'
}
```

> **Minimum SDK**: WorkManager requires **API 21** (Android 5.0+).  
> Set *Minimum SDK version* ≥ 21 in **Project Options → Version Info**.

---

### 3. Merge the AndroidManifest additions

Open `AndroidManifest.template.xml` (Project Options → Application → Manifest) and insert the entries from `AndroidManifest.additions.xml`:

- `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />`  
- `<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />`
- The `<provider>` block for WorkManager initializer

---

### 4. Request POST_NOTIFICATIONS at Runtime (Android 13+)

Add this to `FormCreate` or a suitable startup location:

```pascal
uses
  Androidapi.Helpers,
  FMX.Helpers.Android,
  Androidapi.JNI.JavaTypes;

// In FormCreate:
{$IFDEF ANDROID}
if TOSVersion.Major >= 13 then
  PermissionsService.RequestPermissions(
    ['android.permission.POST_NOTIFICATIONS'],
    procedure(const APermissions: TArray<string>;
              const AGrantResults: TArray<TPermissionStatus>)
    begin
      // handle grant/deny
    end);
{$ENDIF}
```

---

### 5. Build and Run

- Target: **Android 64-bit** (ARM64)
- Deploy to a real device (WorkManager periodic tasks won't fire in the emulator reliably due to Doze mode simulation)
- Press **▶ Start Reminder** in the app
- Lock the screen or close the app — notification arrives within ~15 min

---

## How It Works

```
[Delphi Button click]
        │
        ▼
TWorkManagerBridge.SchedulePeriodicTask()
        │  JNI call
        ▼
WorkManager.enqueueUniquePeriodicWork(
    "UserTasksReminder",
    ExistingPeriodicWorkPolicy.REPLACE,
    PeriodicWorkRequest(UserTasksWorker, 15, MINUTES)
)
        │  Android OS fires every 15 min
        ▼
UserTasksWorker.doWork()
        │
        ▼
NotificationManagerCompat.notify()  ──►  User sees "Start Working!" 🔔
```

---

## Notes

| Topic | Detail |
|---|---|
| Minimum interval | Android enforces **15 minutes** minimum for `PeriodicWorkRequest` |
| Battery optimisation | WorkManager respects Doze — actual firing may be slightly delayed |
| Persistence | Task survives app kill and device reboot |
| Cancel | Call `TWorkManagerBridge.CancelTask('UserTasksReminder')` to stop |
| Notification icon | Replace `android.R.drawable.ic_dialog_info` with your own drawable |
| Package name | Replace `com.embarcadero.usertasks` if you change your package |
