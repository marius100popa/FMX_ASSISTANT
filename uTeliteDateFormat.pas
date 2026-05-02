unit uTeliteDateFormat;

interface

type
  /// <summary>
  /// Enumerare pentru ordinea componentelor unei date calendaristice.
  /// Anul este intotdeauna reprezentat pe 4 cifre (YYYY).
  /// Separatorul dintre componente este tratat separat.
  /// </summary>
  TTELITE_DATE_FORMAT = (
    edfNone         = 0,  // Niciun format definit
    edfYYYY_MM_DD   = 1,  // An - Luna - Zi   (ex: 2025-12-31)
    edfYYYY_DD_MM   = 2,  // An - Zi   - Luna (ex: 2025-31-12)
    edfMM_DD_YYYY   = 3,  // Luna - Zi   - An (ex: 12-31-2025)
    edfMM_YYYY_DD   = 4,  // Luna - An   - Zi (ex: 12-2025-31)
    edfDD_MM_YYYY   = 5,  // Zi   - Luna - An (ex: 31-12-2025)
    edfDD_YYYY_MM   = 6   // Zi   - An   - Luna (ex: 31-2025-12)
  );

/// <summary>
/// Returneaza masca de formatare a ordinii componentelor (fara separator).
/// Exemplu: TeliteDateFormatToString(edfYYYY_MM_DD) = 'YYYY MM DD'
/// </summary>
function TeliteDateFormatToString(const AFormat: TTELITE_DATE_FORMAT): string;

/// <summary>
/// Returneaza numele enumeratiei ca string.
/// Exemplu: TeliteDateFormatToName(edfDD_MM_YYYY) = 'edfDD_MM_YYYY'
/// Util pentru serializare, debug si logare.
/// </summary>
function TeliteDateFormatToName(const AFormat: TTELITE_DATE_FORMAT): string;

/// <summary>
/// Converteste un string (masca sau nume enumeratie) inapoi la TTELITE_DATE_FORMAT.
/// Returneaza edfNone daca stringul nu este recunoscut.
/// </summary>
function StringToTeliteDateFormat(const AValue: string): TTELITE_DATE_FORMAT;

implementation

uses
  System.SysUtils;

function TeliteDateFormatToString(const AFormat: TTELITE_DATE_FORMAT): string;
begin
  case AFormat of
    edfNone       : Result := '';
    edfYYYY_MM_DD : Result := 'YYYY MM DD';
    edfYYYY_DD_MM : Result := 'YYYY DD MM';
    edfMM_DD_YYYY : Result := 'MM DD YYYY';
    edfMM_YYYY_DD : Result := 'MM YYYY DD';
    edfDD_MM_YYYY : Result := 'DD MM YYYY';
    edfDD_YYYY_MM : Result := 'DD YYYY MM';
  else
    Result := '';
  end;
end;

function TeliteDateFormatToName(const AFormat: TTELITE_DATE_FORMAT): string;
begin
  case AFormat of
    edfNone       : Result := 'edfNone';
    edfYYYY_MM_DD : Result := 'edfYYYY_MM_DD';
    edfYYYY_DD_MM : Result := 'edfYYYY_DD_MM';
    edfMM_DD_YYYY : Result := 'edfMM_DD_YYYY';
    edfMM_YYYY_DD : Result := 'edfMM_YYYY_DD';
    edfDD_MM_YYYY : Result := 'edfDD_MM_YYYY';
    edfDD_YYYY_MM : Result := 'edfDD_YYYY_MM';
  else
    Result := 'edfNone';
  end;
end;

function StringToTeliteDateFormat(const AValue: string): TTELITE_DATE_FORMAT;
var
  LUpper: string;
  LFmt: TTELITE_DATE_FORMAT;
begin
  LUpper := UpperCase(Trim(AValue));
  Result := edfNone;

  for LFmt := Low(TTELITE_DATE_FORMAT) to High(TTELITE_DATE_FORMAT) do
  begin
    if UpperCase(TeliteDateFormatToString(LFmt)) = LUpper then
      Exit(LFmt);
    if UpperCase(TeliteDateFormatToName(LFmt)) = LUpper then
      Exit(LFmt);
  end;
end;

end.
