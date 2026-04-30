unit UserTasks.MainForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Layouts, FMX.Objects,
  FMX.Effects,
  UserTasks.WorkManager;

type
  TFormMain = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FWorkManager    : TWorkManagerBridge;
    FIsScheduled    : Boolean;

    // Controls
    FLayoutRoot     : TLayout;
    FRectHeader     : TRectangle;
    FLblTitle       : TLabel;
    FLblSubtitle    : TLabel;
    FRectCard       : TRectangle;
    FLblCardTitle   : TLabel;
    FLblCardDesc    : TLabel;
    FBtnSchedule    : TButton;
    FBtnCancel      : TButton;
    FRectStatus     : TRectangle;
    FLblStatusIcon  : TLabel;
    FLblStatus      : TLabel;

    procedure BuildUI;
    procedure UpdateUI;
    procedure BtnScheduleClick(Sender: TObject);
    procedure BtnCancelClick(Sender: TObject);
  end;

var
  FormMain: TFormMain;

implementation

{$R *.fmx}

{ TFormMain }

procedure TFormMain.FormCreate(Sender: TObject);
begin
  FWorkManager := TWorkManagerBridge.Create;
  FIsScheduled := False;
  BuildUI;
  UpdateUI;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  FWorkManager.Free;
end;

procedure TFormMain.BuildUI;

  procedure SetupLabel(ALabel: TLabel; AParent: TFmxObject;
    AX, AY, AW, AH: Single; const AText: string;
    AFontSize: Single; AFontStyle: TFontStyles;
    AFontColor: TAlphaColor; AWordWrap: Boolean = False);
  begin
    ALabel.Parent := AParent;
    ALabel.Position.X := AX;
    ALabel.Position.Y := AY;
    if AW > 0 then ALabel.Width  := AW;
    if AH > 0 then ALabel.Height := AH;
    ALabel.Text := AText;
    ALabel.WordWrap := AWordWrap;
    ALabel.StyledSettings := [];
    ALabel.TextSettings.Font.Size  := AFontSize;
    ALabel.TextSettings.Font.Style := AFontStyle;
    ALabel.TextSettings.FontColor  := AFontColor;
  end;

begin
  ClientWidth  := 390;
  ClientHeight := 680;
  Caption      := 'UserTasks';
  Fill.Color   := $FF1A1A2E;

  // ── Root Layout ──────────────────────────────────────────────
  FLayoutRoot        := TLayout.Create(Self);
  FLayoutRoot.Parent := Self;
  FLayoutRoot.Align  := TAlignLayout.Client;

  // ── Header ───────────────────────────────────────────────────
  FRectHeader             := TRectangle.Create(Self);
  FRectHeader.Parent      := FLayoutRoot;
  FRectHeader.Align       := TAlignLayout.Top;
  FRectHeader.Height      := 140;
  FRectHeader.Fill.Color  := $FF3F51B5;
  FRectHeader.Stroke.Kind := TBrushKind.None;

  FLblTitle := TLabel.Create(Self);
  SetupLabel(FLblTitle, FRectHeader, 20, 38, 0, 0,
    'UserTasks', 28, [TFontStyle.fsBold], claWhite);

  FLblSubtitle := TLabel.Create(Self);
  SetupLabel(FLblSubtitle, FRectHeader, 20, 84, 300, 0,
    'Work reminder, every 15 minutes', 13, [], $CCFFFFFF);

  // ── Card ─────────────────────────────────────────────────────
  FRectCard             := TRectangle.Create(Self);
  FRectCard.Parent      := FLayoutRoot;
  FRectCard.Position.X  := 20;
  FRectCard.Position.Y  := 158;
  FRectCard.Width       := 350;
  FRectCard.Height      := 230;
  FRectCard.Fill.Color  := $FF263238;
  FRectCard.Stroke.Kind := TBrushKind.None;
  FRectCard.XRadius     := 14;
  FRectCard.YRadius     := 14;

  var ShadowEffect       := TShadowEffect.Create(Self);
  ShadowEffect.Parent    := FRectCard;
  ShadowEffect.Enabled   := True;
  ShadowEffect.Direction := 90;
  ShadowEffect.Distance  := 6;
  ShadowEffect.Opacity   := 0.4;
  ShadowEffect.SoftMargin := 8;
  ShadowEffect.Color     := claBlack;

  FLblCardTitle := TLabel.Create(Self);
  SetupLabel(FLblCardTitle, FRectCard, 20, 20, 300, 0,
    'Periodic Reminder', 16, [TFontStyle.fsBold], claWhite);

  FLblCardDesc := TLabel.Create(Self);
  SetupLabel(FLblCardDesc, FRectCard, 20, 54, 310, 64,
    'Schedules an Android WorkManager task that sends you a ' +
    'Start Working notification every 15 minutes, ' +
    'even when the app is closed.',
    12, [], $FFAAAAAA, True);

  FBtnSchedule           := TButton.Create(Self);
  FBtnSchedule.Parent    := FRectCard;
  FBtnSchedule.Position.X := 20;
  FBtnSchedule.Position.Y := 166;
  FBtnSchedule.Width     := 148;
  FBtnSchedule.Height    := 46;
  FBtnSchedule.Text      := 'Start Reminder';
  FBtnSchedule.OnClick   := BtnScheduleClick;

  FBtnCancel             := TButton.Create(Self);
  FBtnCancel.Parent      := FRectCard;
  FBtnCancel.Position.X  := 182;
  FBtnCancel.Position.Y  := 166;
  FBtnCancel.Width       := 148;
  FBtnCancel.Height      := 46;
  FBtnCancel.Text        := 'Stop';
  FBtnCancel.OnClick     := BtnCancelClick;

  // ── Status bar ───────────────────────────────────────────────
  FRectStatus             := TRectangle.Create(Self);
  FRectStatus.Parent      := FLayoutRoot;
  FRectStatus.Position.X  := 20;
  FRectStatus.Position.Y  := 408;
  FRectStatus.Width       := 350;
  FRectStatus.Height      := 60;
  FRectStatus.Fill.Color  := $FF37474F;
  FRectStatus.Stroke.Kind := TBrushKind.None;
  FRectStatus.XRadius     := 10;
  FRectStatus.YRadius     := 10;

  FLblStatusIcon := TLabel.Create(Self);
  SetupLabel(FLblStatusIcon, FRectStatus, 16, 14, 36, 32,
    'OFF', 10, [TFontStyle.fsBold], $FFAAAAAA);

  FLblStatus := TLabel.Create(Self);
  SetupLabel(FLblStatus, FRectStatus, 62, 20, 270, 0,
    'No reminder scheduled', 13, [], $FFEAEAEA);
end;

procedure TFormMain.UpdateUI;
begin
  if FIsScheduled then
  begin
    FBtnSchedule.Enabled   := False;
    FBtnCancel.Enabled     := True;
    FLblStatus.Text        := 'Reminder active — every 15 minutes';
    FLblStatusIcon.Text    := 'ON';
    FLblStatusIcon.TextSettings.FontColor := $FF66BB6A;
    FRectStatus.Fill.Color := $FF1B5E20;
  end
  else
  begin
    FBtnSchedule.Enabled   := True;
    FBtnCancel.Enabled     := False;
    FLblStatus.Text        := 'No reminder scheduled';
    FLblStatusIcon.Text    := 'OFF';
    FLblStatusIcon.TextSettings.FontColor := $FFAAAAAA;
    FRectStatus.Fill.Color := $FF37474F;
  end;
end;

procedure TFormMain.BtnScheduleClick(Sender: TObject);
begin
  try
    FWorkManager.SchedulePeriodicTask(
      'UserTasksReminder',
      15,
      'Start Working!',
      'Time to focus and get things done. You''ve got this!'
    );
    FIsScheduled := True;
    UpdateUI;
    ShowMessage('Task scheduled! You will receive a notification every 15 minutes.');
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
    ShowMessage('Scheduled task has been cancelled.');
  except
    on E: Exception do
      ShowMessage('Error cancelling task: ' + E.Message);
  end;
end;

end.
