program UserTasks;

uses
  System.StartUpCopy,
  FMX.Forms,
  UserTasks.MainForm in 'UserTasks.MainForm.pas' {FormMain},
  UserTasks.WorkManager in 'UserTasks.WorkManager.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
