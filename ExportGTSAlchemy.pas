{
  ExportGTSAlchemy.pas  (v3 - exact MGEF identity + source plugins)
  ------------------------------------------------------------------
  Dumps EVERY winning-override INGR across the whole load order to
  JSON, resolving each effect to its WINNING MGEF override and
  recording proper identities so recipe matching can key on the real
  magic-effect record (not display name).

  Per ingredient : name, EditorID, FormID, origin plugin, winning plugin, value
  Per effect     : name, MGEF EditorID, MGEF FormID, cost, mag, dur, flags

  HOW TO RUN:
    1. SSEEdit -> load FULL GTS order -> wait for "Background Loader: finished".
    2. Right-click ANY plugin -> Apply Script -> ExportGTSAlchemy -> OK.
       (scans every plugin itself; selection doesn't matter)
    3. Writes  <xEdit>\Edit Scripts\gts_alchemy.json  and logs a COUNT.
    4. Send me gts_alchemy.json. If count is 0 or a red error appears,
       paste me that line and stop - don't re-run blindly.
}
unit ExportGTSAlchemy;

var
  outText : TStringList;
  seen    : TStringList;
  first   : Boolean;
  nIng    : Integer;

function Num(v: Double): string;
begin
  Result := StringReplace(FloatToStr(v), ',', '.', [rfReplaceAll]);
end;

function JsonStr(s: string): string;
begin
  s := StringReplace(s, '\', '\\', [rfReplaceAll]);
  s := StringReplace(s, '"', '\"', [rfReplaceAll]);
  Result := '"' + s + '"';
end;

// clean 1/0 for a flag bit (avoids Ord(True)=-1 in xEdit)
function Bit(flags, mask: Cardinal): string;
begin
  if (flags and mask) <> 0 then Result := '1' else Result := '0';
end;

function PluginOf(e: IInterface): string;
begin
  Result := GetFileName(GetFile(e));
end;

function Initialize: Integer;
begin
  outText := TStringList.Create;
  seen := TStringList.Create;
  seen.Sorted := True;
  seen.Duplicates := dupIgnore;
  first := True;
  nIng := 0;
  outText.Add('[');
  Result := 0;
end;

function Process(e: IInterface): Integer;
begin
  Result := 0;  // real work happens in Finalize (full load-order walk)
end;

procedure DumpIngredient(e: IInterface);
var
  effects, effect, mref, mgef : IInterface;
  i, cnt                      : Integer;
  ename, eline                : string;
  bcost, mag, dur             : Double;
  flags                       : Cardinal;
begin
  ename := GetElementEditValues(e, 'FULL - Name');
  if ename = '' then Exit;

  effects := ElementByPath(e, 'Effects');
  cnt := ElementCount(effects);
  if cnt = 0 then Exit;

  eline := '';
  for i := 0 to cnt - 1 do begin
    effect := ElementByIndex(effects, i);
    mref := LinksTo(ElementByPath(effect, 'EFID'));
    if not Assigned(mref) then Continue;
    mgef := WinningOverride(mref);   // capture patched base cost/flags

    bcost := GetElementNativeValues(mgef, 'Magic Effect Data\DATA\Base Cost');
    if bcost = 0 then bcost := GetElementNativeValues(mgef, 'DATA\Base Cost');
    flags := GetElementNativeValues(mgef, 'Magic Effect Data\DATA\Flags');
    if flags = 0 then flags := GetElementNativeValues(mgef, 'DATA\Flags');

    mag := GetElementNativeValues(effect, 'EFIT\Magnitude');
    dur := GetElementNativeValues(effect, 'EFIT\Duration');

    if eline <> '' then eline := eline + ',';
    eline := eline
      + '{"n":'   + JsonStr(GetElementEditValues(mgef, 'FULL - Name'))
      + ',"med":' + JsonStr(EditorID(mgef))
      + ',"mid":' + JsonStr(IntToHex(FormID(mgef), 8))
      + ',"c":'   + Num(bcost)
      + ',"m":'   + Num(mag)
      + ',"d":'   + Num(dur)
      + ',"vm":'  + Bit(flags, $00200000)
      + ',"vd":'  + Bit(flags, $00400000)
      + ',"h":'   + Bit(flags, $00000001)
      + ',"fl":'  + IntToStr(flags)
      + '}';
  end;
  if eline = '' then Exit;

  if not first then outText.Add(',');
  first := False;
  nIng := nIng + 1;
  outText.Add('{"n":' + JsonStr(ename)
    + ',"ed":'  + JsonStr(EditorID(e))
    + ',"fid":' + JsonStr(IntToHex(FormID(e), 8))
    + ',"src":' + JsonStr(PluginOf(MasterOrSelf(e)))
    + ',"srcW":'+ JsonStr(PluginOf(e))
    + ',"g":'   + Num(GetElementNativeValues(e, 'ENIT\Value'))
    + ',"e":['  + eline + ']}');
end;

function Finalize: Integer;
var
  i, j    : Integer;
  f, grp, rec, win : IInterface;
  fid     : string;
  outPath : string;
begin
  for i := 0 to FileCount - 1 do begin
    f := FileByIndex(i);
    grp := GroupBySignature(f, 'INGR');
    if not Assigned(grp) then Continue;
    for j := 0 to ElementCount(grp) - 1 do begin
      rec := ElementByIndex(grp, j);
      if Signature(rec) <> 'INGR' then Continue;
      win := WinningOverride(rec);
      fid := IntToHex(FormID(win), 8);
      if seen.IndexOf(fid) >= 0 then Continue;
      seen.Add(fid);
      DumpIngredient(win);
    end;
  end;

  outText.Add(']');
  outPath := ProgramPath + 'Edit Scripts\gts_alchemy.json';
  outText.SaveToFile(outPath);
  AddMessage('=====================================================');
  AddMessage('DONE. Ingredients exported: ' + IntToStr(nIng));
  AddMessage('File: ' + outPath);
  AddMessage('Send me gts_alchemy.json. If count is 0, tell me.');
  AddMessage('=====================================================');
  seen.Free;
  outText.Free;
  Result := 0;
end;

end.
