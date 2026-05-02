unit UserTasks.WorkManager;

{
  UserTasks.WorkManager
  ----------------------
  Delphi FMX bridge to Android WorkManager via JNI.
  Schedules a PeriodicWorkRequest that fires a notification
  every N minutes using a custom Java Worker class.

  Requirements:
    - Android API 21+
    - WorkManager dependency in build.gradle (see README)
    - UserTasksWorker.java compiled into the project (see java/ folder)
    - Notification channel registered on Android 8+
}

interface

uses
  System.SysUtils, System.Classes;

type
  TWorkManagerBridge = class
  public
    /// <summary>
    ///   Enqueues a unique periodic WorkRequest.
    ///   AIntervalMinutes minimum is 15 (Android WorkManager constraint).
    /// </summary>
    procedure SchedulePeriodicTask(
      const ATaskName       : string;
      const AIntervalMinutes: Integer;
      const ANotifTitle     : string;
      const ANotifBody      : string
    );

    /// <summary>
    ///   Cancels the unique periodic work by name.
    /// </summary>
    procedure CancelTask(const ATaskName: string);
  end;

implementation

{$IFDEF ANDROID}
uses
  Androidapi.Jni,
  Androidapi.JNI.JavaTypes,
  Androidapi.JNI.GraphicsContentViewText,
  Androidapi.Helpers,
  Androidapi.JNIBridge,
  Androidapi.JNI.App,
  FMX.Helpers.Android;

// ---------------------------------------------------------------------------
//  JNI declarations for WorkManager classes
// ---------------------------------------------------------------------------

type
  // androidx.work.PeriodicWorkRequest$Builder
  JPeriodicWorkRequest_BuilderClass = interface(JObjectClass)
    ['{A1B2C3D4-0001-0001-0001-000000000001}']
    function init(
      workerClass   : JClass;
      repeatInterval: Int64;
      timeUnit      : JObject   // java.util.concurrent.TimeUnit
    ): JObject; cdecl;
  end;

  // androidx.work.WorkManager
  JWorkManagerClass = interface(JObjectClass)
    ['{A1B2C3D4-0002-0001-0001-000000000002}']
    function getInstance(context: JObject): JObject; cdecl;
  end;

  // androidx.work.Data$Builder
  JData_BuilderClass = interface(JObjectClass)
    ['{A1B2C3D4-0003-0001-0001-000000000003}']
    function init: JObject; cdecl;
  end;

// ---------------------------------------------------------------------------

procedure CallJavaWorkManager(
  const ATaskName       : string;
  const AIntervalMinutes: Integer;
  const ANotifTitle     : string;
  const ANotifBody      : string
);
var
  Env         : PJNIEnv;
  VM          : JavaVM;
  AppCtx      : JObject;
  WMClass     : JClass;
  WMInstance  : JObject;
  WorkReqBld  : JClass;
  TimeUnitCls : JClass;
  TimeUnitMin : JObject;
  DataBldCls  : JClass;
  DataBld     : JObject;
  DataObj     : JObject;
  WorkReqObj  : JObject;
  WorkReqBldI : JObject;
  UniqueEnqM  : JMethodID;
  PutStrM     : JMethodID;
  BuildDataM  : JMethodID;
  BuildReqM   : JMethodID;
  SetInputM   : JMethodID;
  WMGetInst   : JMethodID;
  JTaskName   : JString;
  JTitle      : JString;
  JBody       : JString;
  JExistPolicy: JObject;
  ExistPolCls : JClass;
  ExistPolFld : JFieldID;
  WorkerClass : JClass;
  GetFieldM   : JMethodID;
begin
  // Obtain JNI env from the Android application
  Env := TAndroidHelper.JNIEnv;
  AppCtx := TAndroidHelper.Context;

  // ---- Load WorkManager class ----
  WMClass := Env^.FindClass(Env,
    'androidx/work/WorkManager');
  if WMClass = nil then
    raise Exception.Create('WorkManager class not found. ' +
      'Add androidx.work:work-runtime to build.gradle');

  // ---- Get WorkManager singleton instance ----
  WMGetInst := Env^.GetStaticMethodID(Env, WMClass,
    'getInstance', '(Landroid/content/Context;)Landroidx/work/WorkManager;');
  WMInstance := Env^.CallStaticObjectMethod(Env, WMClass, WMGetInst, AppCtx);

  // ---- Load our custom Worker class ----
  WorkerClass := Env^.FindClass(Env,
    'com/embarcadero/usertasks/UserTasksWorker');
  if WorkerClass = nil then
    raise Exception.Create('UserTasksWorker class not found in APK.');

  // ---- TimeUnit.MINUTES ----
  TimeUnitCls := Env^.FindClass(Env,
    'java/util/concurrent/TimeUnit');
  GetFieldM := Env^.GetStaticFieldID(Env, TimeUnitCls,
    'MINUTES', 'Ljava/util/concurrent/TimeUnit;');
  TimeUnitMin := Env^.GetStaticObjectField(Env, TimeUnitCls, GetFieldM);

  // ---- Build input Data with notification strings ----
  DataBldCls := Env^.FindClass(Env, 'androidx/work/Data$Builder');
  DataBld    := Env^.NewObject(Env, DataBldCls,
    Env^.GetMethodID(Env, DataBldCls, '<init>', '()V'));
  PutStrM    := Env^.GetMethodID(Env, DataBldCls,
    'putString',
    '(Ljava/lang/String;Ljava/lang/String;)Landroidx/work/Data$Builder;');

  JTitle := Env^.NewStringUTF(Env, MarshaledAString(UTF8String(ANotifTitle)));
  JBody  := Env^.NewStringUTF(Env, MarshaledAString(UTF8String(ANotifBody)));

  Env^.CallObjectMethod(Env, DataBld, PutStrM,
    Env^.NewStringUTF(Env, 'notif_title'), JTitle);
  Env^.CallObjectMethod(Env, DataBld, PutStrM,
    Env^.NewStringUTF(Env, 'notif_body'),  JBody);

  BuildDataM := Env^.GetMethodID(Env, DataBldCls,
    'build', '()Landroidx/work/Data;');
  DataObj := Env^.CallObjectMethod(Env, DataBld, BuildDataM);

  // ---- Build PeriodicWorkRequest ----
  WorkReqBld := Env^.FindClass(Env,
    'androidx/work/PeriodicWorkRequest$Builder');
  WorkReqBldI := Env^.NewObject(Env, WorkReqBld,
    Env^.GetMethodID(Env, WorkReqBld, '<init>',
      '(Ljava/lang/Class;JLjava/util/concurrent/TimeUnit;)V'),
    WorkerClass,
    Int64(AIntervalMinutes),
    TimeUnitMin);

  // Set input data on builder
  SetInputM := Env^.GetMethodID(Env, WorkReqBld,
    'setInputData',
    '(Landroidx/work/Data;)Landroidx/work/PeriodicWorkRequest$Builder;');
  Env^.CallObjectMethod(Env, WorkReqBldI, SetInputM, DataObj);

  BuildReqM := Env^.GetMethodID(Env, WorkReqBld,
    'build', '()Landroidx/work/PeriodicWorkRequest;');
  WorkReqObj := Env^.CallObjectMethod(Env, WorkReqBldI, BuildReqM);

  // ---- ExistingPeriodicWorkPolicy.REPLACE ----
  ExistPolCls := Env^.FindClass(Env,
    'androidx/work/ExistingPeriodicWorkPolicy');
  ExistPolFld := Env^.GetStaticFieldID(Env, ExistPolCls,
    'REPLACE', 'Landroidx/work/ExistingPeriodicWorkPolicy;');
  JExistPolicy := Env^.GetStaticObjectField(Env, ExistPolCls, ExistPolFld);

  // ---- Enqueue unique periodic work ----
  JTaskName    := Env^.NewStringUTF(Env,
    MarshaledAString(UTF8String(ATaskName)));
  UniqueEnqM   := Env^.GetMethodID(Env,
    Env^.GetObjectClass(Env, WMInstance),
    'enqueueUniquePeriodicWork',
    '(Ljava/lang/String;' +
    'Landroidx/work/ExistingPeriodicWorkPolicy;' +
    'Landroidx/work/PeriodicWorkRequest;)' +
    'Landroidx/work/Operation;');

  Env^.CallObjectMethod(Env, WMInstance, UniqueEnqM,
    JTaskName, JExistPolicy, WorkReqObj);
end;

procedure CallJavaCancelWork(const ATaskName: string);
var
  Env        : PJNIEnv;
  AppCtx     : JObject;
  WMClass    : JClass;
  WMInstance : JObject;
  WMGetInst  : JMethodID;
  CancelM    : JMethodID;
  JTaskName  : JString;
begin
  Env    := TAndroidHelper.JNIEnv;
  AppCtx := TAndroidHelper.Context;

  WMClass := Env^.FindClass(Env, 'androidx/work/WorkManager');
  WMGetInst := Env^.GetStaticMethodID(Env, WMClass,
    'getInstance', '(Landroid/content/Context;)Landroidx/work/WorkManager;');
  WMInstance := Env^.CallStaticObjectMethod(Env, WMClass, WMGetInst, AppCtx);

  JTaskName := Env^.NewStringUTF(Env,
    MarshaledAString(UTF8String(ATaskName)));
  CancelM := Env^.GetMethodID(Env,
    Env^.GetObjectClass(Env, WMInstance),
    'cancelUniqueWork',
    '(Ljava/lang/String;)Landroidx/work/Operation;');
  Env^.CallObjectMethod(Env, WMInstance, CancelM, JTaskName);
end;

{$ENDIF ANDROID}

// ---------------------------------------------------------------------------
//  TWorkManagerBridge
// ---------------------------------------------------------------------------

procedure TWorkManagerBridge.SchedulePeriodicTask(
  const ATaskName       : string;
  const AIntervalMinutes: Integer;
  const ANotifTitle     : string;
  const ANotifBody      : string
);
var
  Interval: Integer;
begin
  Interval := AIntervalMinutes;
  if Interval < 15 then
    Interval := 15; // Android enforces minimum 15-minute periodic interval

{$IFDEF ANDROID}
  CallJavaWorkManager(ATaskName, Interval, ANotifTitle, ANotifBody);
{$ELSE}
  raise EPlatformNotSupported.Create('WorkManager is only available on Android.');
{$ENDIF}
end;

procedure TWorkManagerBridge.CancelTask(const ATaskName: string);
begin
{$IFDEF ANDROID}
  CallJavaCancelWork(ATaskName);
{$ELSE}
  raise EPlatformNotSupported.Create('WorkManager is only available on Android.');
{$ENDIF}
end;

end.
