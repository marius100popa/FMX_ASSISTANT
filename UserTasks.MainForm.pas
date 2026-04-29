unit UserTasks.MainForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Layouts, FMX.Objects,
  FMX.Ani, FMX.Effects,
  UserTasks.WorkManager;

type
  TFormMain = class(TForm)
    LayoutRoot: TLayout;
    RectHeader: TRectangle;
    LabelTitle: TLabel;
    LabelSubtitle: TLabel;
    RectCard: TRectangle;
    LabelCardTitle: TLabel;
    LabelCardDesc: TLabel;
    BtnSchedule: TButton;
    BtnCancel: TButton;
    RectStatus: TRectangle;
    LabelStatus: TLabel;
    LabelStatusIcon: TLabel;
    ShadowEffect1: TShadowEffect;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BtnScheduleClick(Sender: TObject);
    procedure BtnCancelClick(Sender: TObject);
  private
    FWorkManager: TWorkManagerBridge;
    FIsScheduled: Boolean;
    procedure UpdateUI;
  public
    { Public declarations }
  end;

var
  FormMain: TFormMain;

implementation

{$R *.fmx}

procedure TFormMain.FormCreate(Sender: TObject);
begin
  FWorkManager := TWorkManagerBridge.Create;
  FIsScheduled := False;
  UpdateUI;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  FWorkManager.Free;
end;

procedure TFormMain.BtnScheduleClick(Sender: TObject);
begin
  try
    FWorkManager.SchedulePeriodicTask(
      'UserTasksReminder',   // Unique task name
      15,                    // Repeat interval in minutes
      'Start Working!',      // Notification title
      'Time to focus and get things done. You''ve got this!' // Notification body
    );
    FIsScheduled := True;
    UpdateUI;
    ShowMessage('✅ Task scheduled! You will receive a notification every 15 minutes.');
  except
    on E: Exception do
      ShowMessage('Error scheduling task: ' + E.Message);
  end;
end;

procedure TFormMain.BtnCancelClick(Sender: TObject);
begin
  try
    FWorkManager.CancelTask('UserTasksReminder');
    FIsScheduled := False;
    UpdateUI;
    ShowMessage('🛑 Scheduled task has been cancelled.');
  except
    on E: Exception do
      ShowMessage('Error cancelling task: ' + E.Message);
  end;
end;

procedure TFormMain.UpdateUI;
begin
  if FIsScheduled then
  begin
    BtnSchedule.Enabled := False;
    BtnCancel.Enabled   := True;
    LabelStatus.Text    := 'Reminder is ACTIVE — every 15 minutes';
    LabelStatusIcon.Text := '🟢';
    RectStatus.Fill.Color := $FF1B5E20;
  end
  else
  begin
    BtnSchedule.Enabled := True;
    BtnCancel.Enabled   := False;
    LabelStatus.Text    := 'No reminder scheduled';
    LabelStatusIcon.Text := '⚪';
    RectStatus.Fill.Color := $FF37474F;
  end;
end;

end.
