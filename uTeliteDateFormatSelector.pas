unit uTeliteDateFormatSelector;

{
  TTeliteDateFormatSelector
  --------------------------
  Componenta VCL extinsa din TPanel care permite selectia unui format de data.

  Contine:
    - Un TLabel + TComboBox pentru selectia separatorului (-, /, ., spatiu, fara)
    - Un TLabel + TComboBox pentru selectia ordinii componentelor datei
      (alimentat automat la schimbarea separatorului)

  Properties expuse in Object Inspector:
    - Align, Anchors, Color, Font, Enabled, Visible  (mostenite, re-publicate)
    - DateFormat      : TTELITE_DATE_FORMAT   (r/w)
    - Separator       : TTELITE_SEPARATOR     (r/w)
    - LabelSeparator  : string               (textul label-ului Separator)
    - LabelFormat     : string               (textul label-ului Format)
    - OnFormatChanged : TNotifyEvent

  FIX design-time crash:
    BeginUpdate/EndUpdate pe TComboBox.Items forteza crearea handle-ului
    Windows inainte ca parent-ul sa existe -> InvalidControlOperation.
    Solutie: popularea combo-urilor se face DOAR in Loaded (sau mai tarziu),
    niciodata in constructor. In constructor setam doar campuri private.
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
    FLblSeparator    : TLabel;
    FCmbSeparator    : TComboBox;
    FLblFormat       : TLabel;
    FCmbFormat       : TComboBox;
    FOnFormatChanged : TNotifyEvent;

    // Valorile "dorite" inainte ca handle-urile sa existe
    FPendingSeparator  : TTELITE_SEPARATOR;
    FPendingDateFormat : TTELITE_DATE_FORMAT;
    FPopulated         : Boolean;

    function  GetSeparatorChar: string;
    function  GetSeparator: TTELITE_SEPARATOR;
    procedure SetSeparator(const AValue: TTELITE_SEPARATOR);
    function  GetDateFormat: TTELITE_DATE_FORMAT;
    procedure SetDateFormat(const AValue: TTELITE_DATE_FORMAT);
    function  GetLabelSeparatorText: string;
    procedure SetLabelSeparatorText(const AValue: string);
    function  GetLabelFormatText: string;
    procedure SetLabelFormatText(const AValue: string);

    procedure PopulateSeparatorCombo;
    procedure PopulateFormatCombo;
    procedure RebuildLayout;

    procedure CmbSeparatorChange(Sender: TObject);
    procedure CmbFormatChange(Sender: TObject);

  protected
    procedure Loaded; override;
    procedure Resize; override;

  public
    constructor Create(AOwner: TComponent); override;

    /// <summary>
    /// Returneaza masca completa (ordine + separator).
    /// Ex: 'YYYY-MM-DD', 'DD/MM/YYYY', 'YYYYMMDD'
    /// </summary>
    function FormattedMask: string;

    property SeparatorChar: string read GetSeparatorChar;

  published
    property Separator      : TTELITE_SEPARATOR   read GetSeparator   write SetSeparator   default tsDash;
    property DateFormat     : TTELITE_DATE_FORMAT read GetDateFormat  write SetDateFormat  default edfYYYY_MM_DD;
    property LabelSeparator : string              read GetLabelSeparatorText write SetLabelSeparatorText;
    property LabelFormat    : string              read GetLabelFormatText    write SetLabelFormatText;
    property OnFormatChanged: TNotifyEvent        read FOnFormatChanged      write FOnFormatChanged;

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
    'Fara separator',
    'Linie  ( - )',
    'Slash  ( / )',
    'Punct  ( . )',
    'Spatiu (   )'
  );

  CTRL_MARGIN  = 6;
  CTRL_SPACING = 4;
  LABEL_HEIGHT = 16;
  COMBO_HEIGHT = 22;

// ---------------------------------------------------------------------------

constructor TTeliteDateFormatSelector.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  // Setam aspect panel - fara sa atingem Items ale vreunui combo
  Width       := 260;
  Height      := 2 * CTRL_MARGIN + 2 * (LABEL_HEIGHT + CTRL_SPACING + COMBO_HEIGHT) + CTRL_SPACING * 2;
  Caption     := '';
  BevelOuter  := bvNone;
  ParentColor := False;
  Color       := clBtnFace;

  // Valorile implicite retinute in campuri private
  FPendingSeparator  := tsDash;
  FPendingDateFormat := edfYYYY_MM_DD;
  FPopulated         := False;

  // --- Label Separator ---
  FLblSeparator          := TLabel.Create(Self);
  FLblSeparator.Parent   := Self;
  FLblSeparator.Caption  := 'Separator';
  FLblSeparator.AutoSize := False;

  // --- Combo Separator ---
  // NU apelam Items.Add / BeginUpdate aici - doar cream controlul
  FCmbSeparator          := TComboBox.Create(Self);
  FCmbSeparator.Parent   := Self;
  FCmbSeparator.Style    := csDropDownList;
  FCmbSeparator.OnChange := CmbSeparatorChange;

  // --- Label Format ---
  FLblFormat          := TLabel.Create(Self);
  FLblFormat.Parent   := Self;
  FLblFormat.Caption  := 'Format data';
  FLblFormat.AutoSize := False;

  // --- Combo Format ---
  FCmbFormat          := TComboBox.Create(Self);
  FCmbFormat.Parent   := Self;
  FCmbFormat.Style    := csDropDownList;
  FCmbFormat.OnChange := CmbFormatChange;

  RebuildLayout;
  // Popularea se face in Loaded, cand handle-urile exista garantat
end;

// ---------------------------------------------------------------------------
// Loaded - primul moment sigur pentru a popula combo-urile
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
// Populare combouri - apelate DOAR dupa ce handle-urile exista
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
// Layout
// ---------------------------------------------------------------------------

procedure TTeliteDateFormatSelector.RebuildLayout;
var
  LW, LTop: Integer;
begin
  LW   := ClientWidth - 2 * CTRL_MARGIN;
  LTop := CTRL_MARGIN;

  FLblSeparator.SetBounds(CTRL_MARGIN, LTop, LW, LABEL_HEIGHT);
  Inc(LTop, LABEL_HEIGHT + CTRL_SPACING);
  FCmbSeparator.SetBounds(CTRL_MARGIN, LTop, LW, COMBO_HEIGHT);
  Inc(LTop, COMBO_HEIGHT + CTRL_SPACING * 2);

  FLblFormat.SetBounds(CTRL_MARGIN, LTop, LW, LABEL_HEIGHT);
  Inc(LTop, LABEL_HEIGHT + CTRL_SPACING);
  FCmbFormat.SetBounds(CTRL_MARGIN, LTop, LW, COMBO_HEIGHT);
end;

procedure TTeliteDateFormatSelector.Resize;
begin
  inherited;
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

function TTeliteDateFormatSelector.GetLabelSeparatorText: string;
begin
  Result := FLblSeparator.Caption;
end;

procedure TTeliteDateFormatSelector.SetLabelSeparatorText(const AValue: string);
begin
  FLblSeparator.Caption := AValue;
end;

function TTeliteDateFormatSelector.GetLabelFormatText: string;
begin
  Result := FLblFormat.Caption;
end;

procedure TTeliteDateFormatSelector.SetLabelFormatText(const AValue: string);
begin
  FLblFormat.Caption := AValue;
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
