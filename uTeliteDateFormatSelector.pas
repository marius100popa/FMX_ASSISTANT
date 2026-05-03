unit uTeliteDateFormatSelector;

{
  TTeliteDateFormatSelector
  --------------------------
  Componenta VCL extinsa din TPanel.

  Layout:
    [ Label (caption configurabil)           ]
    [ CmbSeparator (w=40) ] [ CmbFormat (w=110) ]

  - Labelul este deasupra celor 2 combo-uri
  - Combo-urile sunt aliniate la aceeasi inaltime
  - Distanta intre combo-uri: 5px
  - Inaltimea combo-urilor este dictata de Font
  - Width-urile implicite: separator=40, format=110
  - Popularea se face in Loaded (fix design-time crash)
}

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vcl.Graphics,
  uTeliteDateFormat;

type
  TTELITE_SEPARATOR = (
    tsNone   = 0,
    tsDash   = 1,
    tsSlash  = 2,
    tsDot    = 3,
    tsSpace  = 4
  );

  TTeliteDateFormatSelector = class(TPanel)
  private
    FLabel           : TLabel;
    FCmbSeparator    : TComboBox;
    FCmbFormat       : TComboBox;
    FOnFormatChanged : TNotifyEvent;

    FPendingSeparator  : TTELITE_SEPARATOR;
    FPendingDateFormat : TTELITE_DATE_FORMAT;
    FPopulated         : Boolean;

    FCmbSeparatorWidth : Integer;
    FCmbFormatWidth    : Integer;
    FCmbSpacing        : Integer;
    FMargin            : Integer;

    function  GetSeparatorChar: string;
    function  GetSeparator: TTELITE_SEPARATOR;
    procedure SetSeparator(const AValue: TTELITE_SEPARATOR);
    function  GetDateFormat: TTELITE_DATE_FORMAT;
    procedure SetDateFormat(const AValue: TTELITE_DATE_FORMAT);
    function  GetLabelText: string;
    procedure SetLabelText(const AValue: string);
    function  GetCmbSeparatorWidth: Integer;
    procedure SetCmbSeparatorWidth(const AValue: Integer);
    function  GetCmbFormatWidth: Integer;
    procedure SetCmbFormatWidth(const AValue: Integer);

    procedure PopulateSeparatorCombo;
    procedure PopulateFormatCombo;
    procedure RebuildLayout;

    procedure CmbSeparatorChange(Sender: TObject);
    procedure CmbFormatChange(Sender: TObject);

  protected
    procedure Loaded; override;
    procedure Resize; override;
    procedure FontChanged(Sender: TObject); override;

  public
    constructor Create(AOwner: TComponent); override;

    /// <summary>
    /// Returneaza masca completa (ordine + separator).
    /// Ex: 'YYYY-MM-DD', 'DD/MM/YYYY', 'YYYYMMDD'
    /// </summary>
    function FormattedMask: string;

    property SeparatorChar: string read GetSeparatorChar;

  published
    property Separator         : TTELITE_SEPARATOR   read GetSeparator          write SetSeparator          default tsDash;
    property DateFormat        : TTELITE_DATE_FORMAT read GetDateFormat         write SetDateFormat         default edfYYYY_MM_DD;
    property LabelCaption      : string              read GetLabelText          write SetLabelText;
    property SeparatorComboWidth : Integer           read GetCmbSeparatorWidth  write SetCmbSeparatorWidth  default 40;
    property FormatComboWidth    : Integer           read GetCmbFormatWidth     write SetCmbFormatWidth     default 110;
    property OnFormatChanged   : TNotifyEvent        read FOnFormatChanged      write FOnFormatChanged;

    // Mostenite
    property Align;
    property Anchors;
    property Color;
    property Enabled;
    property Font;
    property Height;
    property Hint;
    property ParentColor;
    property ParentFont;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property Width;
    property OnClick;
    property OnEnter;
    property OnExit;
    property OnMouseEnter;
    property OnMouseLeave;
  end;

procedure Register;

implementation

const
  SEPARATOR_CHARS: array[TTELITE_SEPARATOR] of string = (
    '',   // tsNone
    '-',  // tsDash
    '/',  // tsSlash
    '.',  // tsDot
    ' '   // tsSpace
  );

  SEPARATOR_LABELS: array[TTELITE_SEPARATOR] of string = (
    '(none)',
    ' - ',
    ' / ',
    ' . ',
    '( )'
  );

  DEFAULT_MARGIN       = 4;
  DEFAULT_CMB_SPACING  = 5;
  DEFAULT_LABEL_MARGIN = 2;  // spatiu intre label si combouri

// ---------------------------------------------------------------------------

constructor TTeliteDateFormatSelector.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Caption     := '';
  BevelOuter  := bvNone;
  ParentColor := False;
  Color       := clBtnFace;

  FPendingSeparator  := tsDash;
  FPendingDateFormat := edfYYYY_MM_DD;
  FPopulated         := False;
  FCmbSeparatorWidth := 40;
  FCmbFormatWidth    := 110;
  FCmbSpacing        := DEFAULT_CMB_SPACING;
  FMargin            := DEFAULT_MARGIN;

  // Label
  FLabel          := TLabel.Create(Self);
  FLabel.Parent   := Self;
  FLabel.AutoSize := False;
  FLabel.Caption  := 'Separator si format data';

  // Combo Separator
  FCmbSeparator          := TComboBox.Create(Self);
  FCmbSeparator.Parent   := Self;
  FCmbSeparator.Style    := csDropDownList;
  FCmbSeparator.OnChange := CmbSeparatorChange;

  // Combo Format
  FCmbFormat          := TComboBox.Create(Self);
  FCmbFormat.Parent   := Self;
  FCmbFormat.Style    := csDropDownList;
  FCmbFormat.OnChange := CmbFormatChange;

  // Dimensiune implicita panel: suficienta cat sa incapa label + combo
  Width  := FMargin + FCmbSeparatorWidth + FCmbSpacing + FCmbFormatWidth + FMargin;
  Height := FMargin + 16 + DEFAULT_LABEL_MARGIN + 22 + FMargin;
end;

// ---------------------------------------------------------------------------
// Loaded
// ---------------------------------------------------------------------------

procedure TTeliteDateFormatSelector.Loaded;
begin
  inherited;
  if not FPopulated then
  begin
    PopulateSeparatorCombo;
    FCmbSeparator.ItemIndex := Ord(FPendingSeparator);
    PopulateFormatCombo;
    SetDateFormat(FPendingDateFormat);
    FPopulated := True;
  end;
  RebuildLayout;
end;

// ---------------------------------------------------------------------------
// Populare
// ---------------------------------------------------------------------------

procedure TTeliteDateFormatSelector.PopulateSeparatorCombo;
var
  LSep: TTELITE_SEPARATOR;
begin
  FCmbSeparator.Items.Clear;
  for LSep := Low(TTELITE_SEPARATOR) to High(TTELITE_SEPARATOR) do
    FCmbSeparator.Items.Add(SEPARATOR_LABELS[LSep]);
end;

procedure TTeliteDateFormatSelector.PopulateFormatCombo;
var
  LFmt     : TTELITE_DATE_FORMAT;
  LSepChar : string;
  LMask    : string;
  LPrevSel : TTELITE_DATE_FORMAT;
begin
  LPrevSel := GetDateFormat;
  LSepChar := GetSeparatorChar;

  FCmbFormat.Items.Clear;
  for LFmt := Succ(Low(TTELITE_DATE_FORMAT)) to High(TTELITE_DATE_FORMAT) do
  begin
    LMask := StringReplace(
               TeliteDateFormatToString(LFmt),
               ' ', LSepChar,
               [rfReplaceAll]
             );
    FCmbFormat.Items.AddObject(LMask, TObject(LFmt));
  end;

  SetDateFormat(LPrevSel);
end;

// ---------------------------------------------------------------------------
// Layout - calculat pe baza fontului si a width-urilor configurate
// ---------------------------------------------------------------------------

procedure TTeliteDateFormatSelector.RebuildLayout;
var
  LCmbHeight : Integer;
  LLblHeight : Integer;
  LCmbTop    : Integer;
  LLblTop    : Integer;
  LTotalW    : Integer;
begin
  // Inaltimea combo-ului este determinata de font (combo calculeaza singur
  // in csDropDownList, dar putem lua ItemHeight ca referinta)
  LCmbHeight := FCmbSeparator.Height;  // VCL ajusteaza automat dupa font
  LLblHeight := FLabel.Canvas.TextHeight('Wg') + 2;

  LLblTop := FMargin;
  LCmbTop := LLblTop + LLblHeight + DEFAULT_LABEL_MARGIN;

  LTotalW := FMargin + FCmbSeparatorWidth + FCmbSpacing + FCmbFormatWidth + FMargin;

  // Label - se intinde pe toata latimea
  FLabel.SetBounds(FMargin, LLblTop, LTotalW - 2 * FMargin, LLblHeight);

  // Combo Separator
  FCmbSeparator.SetBounds(FMargin, LCmbTop, FCmbSeparatorWidth, LCmbHeight);

  // Combo Format - imediat dupa separator + spacing, la aceeasi inaltime
  FCmbFormat.SetBounds(FMargin + FCmbSeparatorWidth + FCmbSpacing, LCmbTop,
                       FCmbFormatWidth, LCmbHeight);
end;

procedure TTeliteDateFormatSelector.Resize;
begin
  inherited;
  if FPopulated then
    RebuildLayout;
end;

procedure TTeliteDateFormatSelector.FontChanged(Sender: TObject);
begin
  inherited;
  if FPopulated then
    RebuildLayout;
end;

// ---------------------------------------------------------------------------
// Handlere interne
// ---------------------------------------------------------------------------

procedure TTeliteDateFormatSelector.CmbSeparatorChange(Sender: TObject);
begin
  if FPopulated then
  begin
    PopulateFormatCombo;
    if Assigned(FOnFormatChanged) then
      FOnFormatChanged(Self);
  end;
end;

procedure TTeliteDateFormatSelector.CmbFormatChange(Sender: TObject);
begin
  if FPopulated and Assigned(FOnFormatChanged) then
    FOnFormatChanged(Self);
end;

// ---------------------------------------------------------------------------
// Getters / Setters
// ---------------------------------------------------------------------------

function TTeliteDateFormatSelector.GetSeparatorChar: string;
begin
  Result := SEPARATOR_CHARS[GetSeparator];
end;

function TTeliteDateFormatSelector.GetSeparator: TTELITE_SEPARATOR;
var
  LIdx: Integer;
begin
  if not FPopulated then
    Exit(FPendingSeparator);
  LIdx := FCmbSeparator.ItemIndex;
  if (LIdx >= Ord(Low(TTELITE_SEPARATOR))) and
     (LIdx <= Ord(High(TTELITE_SEPARATOR))) then
    Result := TTELITE_SEPARATOR(LIdx)
  else
    Result := tsDash;
end;

procedure TTeliteDateFormatSelector.SetSeparator(const AValue: TTELITE_SEPARATOR);
begin
  FPendingSeparator := AValue;
  if not FPopulated then Exit;
  if FCmbSeparator.ItemIndex <> Ord(AValue) then
  begin
    FCmbSeparator.ItemIndex := Ord(AValue);
    PopulateFormatCombo;
  end;
end;

function TTeliteDateFormatSelector.GetDateFormat: TTELITE_DATE_FORMAT;
var
  LIdx: Integer;
begin
  if not FPopulated then
    Exit(FPendingDateFormat);
  LIdx := FCmbFormat.ItemIndex;
  if LIdx >= 0 then
    Result := TTELITE_DATE_FORMAT(FCmbFormat.Items.Objects[LIdx])
  else
    Result := edfNone;
end;

procedure TTeliteDateFormatSelector.SetDateFormat(const AValue: TTELITE_DATE_FORMAT);
var
  I: Integer;
begin
  FPendingDateFormat := AValue;
  if not FPopulated then Exit;
  if AValue = edfNone then
  begin
    FCmbFormat.ItemIndex := -1;
    Exit;
  end;
  for I := 0 to FCmbFormat.Items.Count - 1 do
    if TTELITE_DATE_FORMAT(FCmbFormat.Items.Objects[I]) = AValue then
    begin
      FCmbFormat.ItemIndex := I;
      Exit;
    end;
  FCmbFormat.ItemIndex := -1;
end;

function TTeliteDateFormatSelector.GetLabelText: string;
begin
  Result := FLabel.Caption;
end;

procedure TTeliteDateFormatSelector.SetLabelText(const AValue: string);
begin
  FLabel.Caption := AValue;
end;

function TTeliteDateFormatSelector.GetCmbSeparatorWidth: Integer;
begin
  Result := FCmbSeparatorWidth;
end;

procedure TTeliteDateFormatSelector.SetCmbSeparatorWidth(const AValue: Integer);
begin
  if FCmbSeparatorWidth <> AValue then
  begin
    FCmbSeparatorWidth := AValue;
    if FPopulated then RebuildLayout;
  end;
end;

function TTeliteDateFormatSelector.GetCmbFormatWidth: Integer;
begin
  Result := FCmbFormatWidth;
end;

procedure TTeliteDateFormatSelector.SetCmbFormatWidth(const AValue: Integer);
begin
  if FCmbFormatWidth <> AValue then
  begin
    FCmbFormatWidth := AValue;
    if FPopulated then RebuildLayout;
  end;
end;

// ---------------------------------------------------------------------------

function TTeliteDateFormatSelector.FormattedMask: string;
var
  LFmt     : TTELITE_DATE_FORMAT;
  LSepChar : string;
begin
  LFmt     := GetDateFormat;
  LSepChar := GetSeparatorChar;
  if LFmt = edfNone then
    Exit('');
  Result := StringReplace(
              TeliteDateFormatToString(LFmt),
              ' ', LSepChar,
              [rfReplaceAll]
            );
end;

// ---------------------------------------------------------------------------

procedure Register;
begin
  RegisterComponents('Telite', [TTeliteDateFormatSelector]);
end;

end.
