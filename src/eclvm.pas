{ The ECL script interpreter. Areas and their events are driven by scripts of ECL commands. GameLoop loads the current
  area's script and runs it, alternating with the party's movement; each opcode handler below reads its operands through
  EclMenu, does its work and leaves the instruction pointer on the next command. }
{$O+,F+,S-,R-,V-,B-,I-}
unit EclVm;

interface

{ Runs the current area: loads its script (or the default one), runs it from its fifth entry point and then enters the
  movement loop. The loop reads the player's moves, camps when asked, runs the script's second entry point while
  searching or looking and its first and second after each step, until the party is defeated or a script aborts. A
  defeated party is removed member by member. }
procedure GameLoop;

implementation

uses Types, GDConsts, GDVars, ExitDos, Vault, Temple, PostCbt, Shop, EclMenu, Combat,
  Explore, Camp, ViewChar, GameTime, FxEngine, CharHlp, MapWin, MenuCore, MapView, Portrait, View3D, MapTiles, Border,
  Blit, TextRend, GameIo, Mouse, Crt, Music, SaveLoad, CharGen, C_Ecl, C_Class, C_Ifc, C_Npc;

const
  { the ECL opcodes only this unit names }
  OP_EXIT = $00;
  SUBTRACT = $05;
  DIVIDE = $06;
  APPROACH = $0D;
  OP_RETURN = $13;
  VERTICAL_MENU = $15;
  IF_EQ = $16;
  IF_NE = $17;
  IF_LT = $18;
  IF_GT = $19;
  IF_LE = $1A;
  IF_GE = $1B;
  CLEAR_MONSTERS = $1C;
  WAIT_KEY = $1D;
  YES_NO = $22;
  OP_COMBAT = $24;
  ON_GOTO = $25;
  ON_GOSUB = $26;
  TREASURE = $27;
  HORIZONTAL_MENU = $2B;
  PRINT_RETURN = $33;
  OP_DELAY = $3A;
  CLEAR_BOX = $3D;
  REMOVE_CHARACTER = $3E;
  { GDVars.moneyPool's entries, in order }
  MONEY_PLATINUM = 0;
  MONEY_GEMS = 1;
  MONEY_JEWELRY = 2;

procedure CallEclScript(startPc: Word); forward;

procedure EclExit; forward;

procedure EclClock; forward;

{ EXIT, opcode $00: ends the script. Restores the character a LOAD CHARACTER replaced, clears the monster flags and the
  picture flag, stops the interpreter, empties the gosub stack and puts the text cursor back at the top of the message
  box. }
procedure EclExit;
var
  nxt: Pointer;
begin
  if GDVars.pendingCharSwap then begin
    GDVars.currentChar := Types.PCharRecord(GDVars.pendingChar);
    GDVars.pendingCharSwap := False;
  end;
  GameIo.ZeroFill(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags));
  GDVars.eclPicShown := False;
  GDVars.loopRunning := 1;
  Inc(GDVars.vmBand.eclIp);
  while GDVars.eclStackTop <> nil do begin
    nxt := Types.PGosubNode(GDVars.eclStackTop)^.next;
    FreeMem(GDVars.eclStackTop, SizeOf(Types.TGosubNode));
    GDVars.eclStackTop := nxt;
  end;
  GDVars.textCursorRow := 17;
  GDVars.textCursorCol := 1;
  GDVars.clearBoxDone := 0;
end;

{ GOTO, opcode $01: jumps to the address in its argument. }
procedure EclGoto;
begin
  EclMenu.LoadEclVars(1);
  GDVars.vmBand.eclIp := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
end;

{ GOSUB, opcode $02: pushes the return address and jumps to the address in its argument. }
procedure EclGosubCmd;
begin
  EclMenu.LoadEclVars(1);
  EclMenu.EclGosub(1);
end;

{ COMPARE, opcode $03: compares its two arguments, as strings when either is a string type ($80 and up), else as
  integers, and sets the comparison flags. }
procedure EclCompare;
var
  firstValue: Word;
  secondValue: Word;
begin
  EclMenu.LoadEclVars(2);
  if (GDVars.eclVarTypes[1] >= $80) or (GDVars.eclVarTypes[2] >= $80) then
    EclMenu.EclCompareStr(GDVars.eclStrings[1], GDVars.eclStrings[2])
  else begin
    firstValue := EclMenu.GetEclVar(1);
    secondValue := EclMenu.GetEclVar(2);
    EclMenu.EclCompareInt(firstValue, secondValue);
  end;
end;

{ ADD, SUBTRACT, DIVIDE and MULTIPLY ($04 to $07) <value1> <value2> <address>: stores the result in the third operand.
  SUBTRACT gives the second value minus the first; DIVIDE also leaves the remainder in divRemainder. }
procedure EclArithmetic;
var
  dest: Word;
  secondValue: Word;
  firstValue: Word;
  { Unused in this version; see the other implementations of this routine. }
  index: Byte;
  result: Word;
begin
  EclMenu.LoadEclVars(3);
  firstValue := EclMenu.GetEclVar(1);
  secondValue := EclMenu.GetEclVar(2);
  dest := EclMenu.CombineBytesToWord(GDVars.eclVarLo[3], GDVars.eclVarHi[3]);
  case GDVars.curEclOpcode of
    C_Ecl.ADD: result := firstValue + secondValue;
    EclVm.SUBTRACT: result := secondValue - firstValue;
    EclVm.DIVIDE: begin
         result := firstValue div secondValue;
         GDVars.vmBand.zone0^.divRemainder := Byte(firstValue mod secondValue);
       end;
    C_Ecl.MULTIPLY: result := firstValue * secondValue;
  end;
  EclMenu.WriteGbvm(dest, result, GDVars.eclVarTypes[3]);
end;

{ RANDOM, opcode $08: stores a random number from 0 to its first argument (0 to 254 when that is 255) at the address in
  its second. }
procedure EclRandom;
var
  lim: Byte;
  roll: Byte; dest: Word;
begin
  EclMenu.LoadEclVars(2);
  lim := Byte(EclMenu.GetEclVar(1));
  if lim < $FF then Inc(lim);
  dest := EclMenu.CombineBytesToWord(GDVars.eclVarLo[2], GDVars.eclVarHi[2]);
  roll := Trunc(Random(lim));
  EclMenu.WriteGbvm(dest, roll, GDVars.eclVarTypes[2]);
end;

{ SAVE, opcode $09: stores its first argument, a number or a string (type bit 7 set), at the address in its second. }
procedure EclSave;
var v: Word; dest: Word;
begin
  EclMenu.LoadEclVars(2);
  dest := EclMenu.CombineBytesToWord(GDVars.eclVarLo[2], GDVars.eclVarHi[2]);
  if GDVars.eclVarTypes[1] < $80 then begin
    v := EclMenu.GetEclVar(1);
    EclMenu.WriteGbvm(dest, v, GDVars.eclVarTypes[2]);
  end else
    EclMenu.WriteGbvmString(dest, GDVars.eclStrings[1]);
end;

{ LOAD CHARACTER, opcode $0A: makes the party member its argument names (low seven bits, counted from 0) the current
  character until the script ends, and sets the not-found flag when there is no such member, clearing it otherwise. }
procedure EclLoadCharacter;
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  savedIdx: Byte;
  idx: Byte;
  i: Byte;
begin
  GDVars.pendingCharSwap := True;
  EclMenu.LoadEclVars(1);
  i := 0;
  idx := Byte(EclMenu.GetEclVar(1));
  p := GDVars.creatureListHead;
  idx := idx and $7F;
  if idx > 0 then begin
    while (i < idx) and (p <> nil) do begin
      p := p^.next;
      Inc(i);
    end;
  end;
  if p <> nil then begin
    GDVars.currentChar := p;
    GDVars.loadCharFailed := 0;
  end else
    GDVars.loadCharFailed := 1;
end;

{ SETUP MONSTER, opcode $0C: takes the monster's sprite, its greatest distance, its picture and the combat direction
  flags from its four arguments, and shows the monster at the nearer of that distance and the clear distance ahead. }
procedure EclSetupMonster;
begin
  EclMenu.LoadEclVars(4);
  GDVars.monSpriteId := Byte(EclMenu.GetEclVar(1));
  GDVars.vmBand.zone0^.encounterDistLimit := Byte(EclMenu.GetEclVar(2));
  GDVars.monPicId := Byte(EclMenu.GetEclVar(3));
  GDVars.hostileDirections := Byte(EclMenu.GetEclVar(4));
  GDVars.vmBand.zone0^.encounterDist := EclMenu.MaxMonsterDist(GDVars.mapState.x, GDVars.mapState.y,
                                                               GDVars.mapState.facing);
  if GDVars.vmBand.zone0^.encounterDistLimit < GDVars.vmBand.zone0^.encounterDist then
    GDVars.vmBand.zone0^.encounterDist := GDVars.vmBand.zone0^.encounterDistLimit;
  EclMenu.DisplayMonster(GDVars.monSpriteId, GDVars.monPicId, GDVars.vmBand.zone0^.encounterDist, GDVars.monsterFlags);
end;

{ LOAD MONSTER ($0B) <monster> <count> <picture>: adds count copies of a monster to the coming fight, each with its own
  copy of the monster's items and effects, and loads their combat icon. Enemy hit points are scaled by difficulty:
  (difficulty + 1) / 4 of normal for levels 1 to 5, never below 1. Nothing is added once 48 monsters are loaded, and
  cloning stops at 63. }
procedure EclLoadMonster;
var
  monId: Byte;
  countReq: Byte;
  picId: Byte;
  i: Byte;
  p: Types.PCharRecord;
  clone: Types.PCharRecord;
  cr: Types.PCharRecord;
  savedCurChar: Types.PCharRecord;
  inv: Pointer;
  savedItems: Types.PItemRec;
  { saved item-list head; effect-list cursor }
  savedInv: Pointer;
  eff: Pointer;
  savedEffN: Types.PEffectRec;
  savedEff: Pointer;
begin
  savedCurChar := GDVars.currentChar;
  i := 1;
  EclMenu.LoadEclVars(3);
  if GDVars.addedMonsterCount < 48 then begin
    p := nil;
    clone := nil;
    monId := Byte(EclMenu.GetEclVar(1));
    EclMenu.InitCreature(monId, Pointer(cr), inv, eff);
    if cr^.side = 1 then begin
      if (GDVars.vmBand.zone0^.difficulty > 0) and (GDVars.vmBand.zone0^.difficulty < 6) then begin
        cr^.hpCur := Byte((Word(cr^.hpCur) * (GDVars.vmBand.zone0^.difficulty + 1)) div 4);
        cr^.hpMax := Byte((Word(cr^.hpMax) * (GDVars.vmBand.zone0^.difficulty + 1)) div 4);
        if (cr^.hpCur = 0) or (cr^.hpMax = 0) then begin
          cr^.hpCur := 1;
          cr^.hpMax := 1;
        end;
      end;
    end;
    if cr^.levelUndead <> 0 then Inc(GDVars.turnUndeadLimit);
    savedInv := inv;
    savedEff := eff;
    countReq := Byte(EclMenu.GetEclVar(2));
    if countReq <= 0 then countReq := 1;
    picId := Byte(EclMenu.GetEclVar(3));
    p := GDVars.creatureListHead;
    MapTiles.LoadIconAnim('CPIC', picId, GDVars.monIconSlot);
    cr^.orderNumber := GDVars.monIconSlot;
    while p^.next <> nil do p := p^.next;
    p^.next := cr;
    p := p^.next;
    p^.next := nil;
    Inc(GDVars.addedMonsterCount);
    Inc(i);
    { Each clone gets its own copies of the items and effects, built by prepending, so its lists come out in reverse
      order. }
    while (i <= countReq) and (GDVars.addedMonsterCount < 63) do begin
      GetMem(clone, SizeOf(Types.TCharRecord));
      p^.next := clone;
      p := p^.next;
      p^ := cr^;
      p^.next := nil;
      p^.effects := nil;
      p^.items := nil;
      Inc(i);
      Inc(GDVars.addedMonsterCount);
      while inv <> nil do begin
        if p^.items = nil then begin
          GetMem(p^.items, SizeOf(Types.TItemRec));
          Types.PItemRec(p^.items)^ := Types.PItemRec(inv)^;
          Types.PItemRec(p^.items)^.next := nil;
        end else begin
          savedItems := p^.items;
          GetMem(p^.items, SizeOf(Types.TItemRec));
          Types.PItemRec(p^.items)^ := Types.PItemRec(inv)^;
          Types.PItemRec(p^.items)^.next := savedItems;
        end;
        inv := Types.PItemRec(inv)^.next;
      end;
      inv := savedInv;
      while eff <> nil do begin
        if p^.effects = nil then begin
          GetMem(p^.effects, SizeOf(Types.TEffectRec));
          p^.effects^ := Types.PEffectRec(eff)^;
          p^.effects^.next := nil;
        end else begin
          savedEffN := p^.effects;
          GetMem(p^.effects, SizeOf(Types.TEffectRec));
          p^.effects^ := Types.PEffectRec(eff)^;
          p^.effects^.next := savedEffN;
        end;
        eff := Types.PEffectRec(eff)^.next;
      end;
      eff := savedEff;
    end;
    Inc(GDVars.monIconSlot);
    GDVars.monstersLoaded := 1;
    GDVars.currentChar := savedCurChar;
  end;
end;

{ APPROACH, opcode $0D: brings the monster one step nearer and redraws it, unless it is already adjacent. }
procedure EclApproach;
begin
  if GDVars.vmBand.zone0^.encounterDist > 0 then begin
    Dec(GDVars.vmBand.zone0^.encounterDist);
    EclMenu.DisplayMonster(GDVars.monSpriteId, GDVars.monPicId, GDVars.vmBand.zone0^.encounterDist,
                           GDVars.monsterFlags);
  end;
  Inc(GDVars.vmBand.eclIp);
end;

{ Shows picture pictureId. $FF takes any script picture or sprite down and redraws the view; 240 and above is a
  full-screen picture; anything else is a small picture in the view window.
  @param(pictureId The picture.) }
procedure ShowPicture(pictureId: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  loadedPicture: LongInt;
begin
  if pictureId <> $FF then begin
    GDVars.mainPalReload := True;
    GDVars.monsterFlags[1] := True;
    GDVars.eclPicShown := True;
    if pictureId >= 240 then begin
      if (GDVars.vmBand.zone0^.mapPaneEnabled = 1) and (GDVars.vmBand.zone0^.inDungeon = 0) then begin
        Blit.FreePic(GDVars.skyPicture);
        Blit.FreePic(GDVars.backdropPicture);
        GameIo.ZeroFill(GDVars.backdropPicture, SizeOf(GDVars.backdropPicture) + SizeOf(GDVars.skyPicture));
        GDVars.curSkyId := 0;
      end;
      Portrait.LoadBigPic(pictureId);
      Portrait.DisplayBigPic;
      GDVars.mainPalReload := True;
      if GDVars.interfaceState = C_Ifc.AREA_MAP then
        MapWin.OpenWindow
      else
        GDVars.partyPanelHidden := 1;
      GDVars.mapRedrawPending := 0;
    end else begin
      Portrait.LoadAnimation('PIC', pictureId, 0);
      Portrait.DisplayImageBuf(3, 3, True, 0);
      GDVars.mainPalReload := True;
    end;
  end else begin
    if (GDVars.savedInterfaceState <> C_Ifc.DUNGEON) or (GDVars.interfaceState = C_Ifc.DUNGEON) then begin
      if GDVars.eclPicShown or (GDVars.monSpriteShown <> 0) then begin
        GDVars.palettePresetOn := 0;
        GDVars.mainPalReload := True;
        GDVars.mapRedrawPending := 1;
        MapView.DisplayMapView;
        GDVars.eclPicShown := False;
        GDVars.monSpriteShown := 0;
      end;
    end;
    GDVars.monsterFlags[0] := False;
    GDVars.monsterFlags[1] := False;
  end;
end;

{ PICTURE, opcode $0E: shows the picture its argument names. }
procedure EclPicture;
begin
  EclMenu.LoadEclVars(1);
  EclVm.ShowPicture(Byte(EclMenu.GetEclVar(1)));
end;

{ Opcode $0F, INPUT NUMBER: prompts in light green for a number, limited by its first operand, and stores it at the
  operand address. }
procedure EclInputNumber;
var result: Word; dest: Word; maxDigits: Word;
begin
  EclMenu.LoadEclVars(2);
  maxDigits := EclMenu.GetEclVar(1);
  dest := EclMenu.CombineBytesToWord(GDVars.eclVarLo[2], GDVars.eclVarHi[2]);
  result := TextRend.ReadNumber('', 10, 0, maxDigits);
  EclMenu.WriteGbvm(dest, result, GDVars.eclVarTypes[2]);
end;

{ INPUT STRING, opcode $10: reads a line from the player, up to the length in its first argument, into the address in
  its second; an empty line is stored as a single space. }
procedure EclInputString;
var dest: Word; s: String[40]; maxLen: Word;
begin
  EclMenu.LoadEclVars(2);
  maxLen := EclMenu.GetEclVar(1);
  dest := EclMenu.CombineBytesToWord(GDVars.eclVarLo[2], GDVars.eclVarHi[2]);
  s := TextRend.ReadString('', 10, 0, maxLen);
  if s = '' then s := ' ';
  EclMenu.WriteGbvmString(dest, s);
end;

{ PRINT and PRINT CLEAR, opcodes $11 and $12: prints its argument, a string or a number, in the message box in the
  area's print color; PRINT CLEAR first clears the box and starts at its top. }
procedure EclPrint;
var idx: Byte;
begin
  idx := GDVars.vmBand.zone0^.printColor;
  if (idx > 15) or (idx = 0) then idx := 10;
  EclMenu.LoadEclVars(1);
  GDVars.viewBoxDrawn := 0;
  GDVars.msgDelayFlag := True;
  if GDVars.eclVarTypes[1] < $80 then
    GDVars.eclStrings[1] := CharHlp.Uint16Str(EclMenu.GetEclVar(1));
  if GDVars.curEclOpcode = C_Ecl.PRINT then
    TextRend.DisplayMessageWindow(1, 17, 38, 22, idx, 0, False, GDVars.eclStrings[1])
  else begin
    GDVars.textCursorRow := 17;
    GDVars.textCursorCol := 1;
    TextRend.DisplayMessageWindow(1, 17, 38, 22, idx, 0, True, GDVars.eclStrings[1]);
  end;
  GDVars.msgDelayFlag := False;
end;

{ RETURN, opcode $13: pops the gosub stack and returns to its address, or ends the script like EXIT when the stack is
  empty. }
procedure EclReturn;
var nxt: Pointer;
begin
  Inc(GDVars.vmBand.eclIp);
  if GDVars.eclStackTop <> nil then begin
    GDVars.vmBand.eclIp := Types.PGosubNode(GDVars.eclStackTop)^.ip;
    nxt := Types.PGosubNode(GDVars.eclStackTop)^.next;
    FreeMem(GDVars.eclStackTop, SizeOf(Types.TGosubNode));
    GDVars.eclStackTop := nxt;
  end else
    EclVm.EclExit;
end;

{ COMPARE AND ($14) <value1> <value2> <value3> <value4>: sets the equal flag when the first value equals the second and
  the third equals the fourth, and the not-equal flag otherwise. }
procedure EclCompareAnd;
var
  eq1: Boolean;
  eq2: Boolean;
begin
  GameIo.ZeroFill(GDVars.eclCmpFlags, SizeOf(GDVars.eclCmpFlags));
  EclMenu.LoadEclVars(4);
  if GDVars.eclVarTypes[1] >= $80 then begin
    eq1 := (GDVars.eclStrings[1] = GDVars.eclStrings[2]);
    if GDVars.eclVarTypes[3] >= $80 then
      eq2 := (GDVars.eclStrings[3] = GDVars.eclStrings[4])
    else
      eq2 := (EclMenu.GetEclVar(3) = EclMenu.GetEclVar(4));
  end else begin
    eq1 := (EclMenu.GetEclVar(1) = EclMenu.GetEclVar(2));
    if GDVars.eclVarTypes[3] >= $80 then
      { Note: this compares the first pair of strings again, not the second. }
      eq2 := (GDVars.eclStrings[1] = GDVars.eclStrings[2])
    else
      eq2 := (EclMenu.GetEclVar(3) = EclMenu.GetEclVar(4));
  end;
  if eq1 and eq2 then
    GDVars.eclCmpFlags[1] := 1
  else
    GDVars.eclCmpFlags[2] := 1;
end;

{ The six IF opcodes ($16 to $1B): skip the next command unless the comparison flag for this test is set. }
procedure EclIf;
begin
  Inc(GDVars.vmBand.eclIp);
  if GDVars.eclCmpFlags[GDVars.curEclOpcode - $15] = 0 then
    EclMenu.SkipEclCmd;
end;

{ NEW ECL, opcode $20: loads the script its argument names, remembering the current one in the zone, and stops the
  interpreter so the game loop starts the new script. }
procedure EclNewEcl;
var newId: Byte;
begin
  EclMenu.LoadEclVars(1);
  GDVars.vmBand.zone0^.areaScriptId := GDVars.eclScriptId;
  newId := Byte(EclMenu.GetEclVar(1));
  GDVars.eclScriptId := newId;
  EclMenu.LoadEclScript(newId);
  EclMenu.EclInit;
  GDVars.loopRunning := 1;
  GDVars.areaExitFlag := True;
  GameIo.ZeroFill(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags));
end;

{ LOAD FILES ($21) <map> <wall set>: loads a dungeon map (below $7F, indoors only) and a wall set ($FF keeps the current
  one), then restores the screen frame if a box was left over it. }
procedure EclLoadFiles;
var
  mapId: Byte;
  suppress: Byte;
  { Unused in this version; see the other implementations of this routine. }
  thirdOperand: Byte;
begin
  EclMenu.LoadEclVars(2);
  mapId := Byte(EclMenu.GetEclVar(1));
  suppress := Byte(EclMenu.GetEclVar(2));
  if (mapId < $7F) and (GDVars.vmBand.zone0^.inDungeon <> 0) then begin
    GDVars.vmBand.zone0^.mapId := mapId;
    View3D.Load3DMap(mapId);
    GDVars.vmBand.zone0^.movementState := 0;
  end;
  if (suppress <> $FF) and (suppress <> GDVars.loadedWallSet.id) then begin
    Blit.FreePic(GDVars.bigPicImage);
    GDVars.bigPicId := 0;
    View3D.LoadWallSet(suppress, 0);
  end;
  if (GDVars.savedInterfaceState = C_Ifc.AREA_MAP) and (GDVars.interfaceState <> C_Ifc.AREA_MAP) and
      (GDVars.panelRestorePending <> 0) then begin
    Border.DrawExploreFrame;
    CharHlp.DisplayParty(GDVars.currentChar);
    CharHlp.PrintMiscInfo;
    GDVars.panelRestorePending := 0;
  end;
end;

{ AND and OR, opcodes $2F and $30: combines its first two arguments bitwise, truncates the result to a byte, sets the
  comparison flags as for COMPARE of 0 with the result, and stores it at the address in its third. }
procedure EclAndOr;
var
  dest: Word;
  secondValue: Word;
  firstValue: Word; result: Byte;
begin
  EclMenu.LoadEclVars(3);
  firstValue := EclMenu.GetEclVar(1);
  secondValue := EclMenu.GetEclVar(2);
  dest := EclMenu.CombineBytesToWord(GDVars.eclVarLo[3], GDVars.eclVarHi[3]);
  if GDVars.curEclOpcode = C_Ecl.OP_AND then
    result := Byte(firstValue and secondValue)
  else
    result := Byte(firstValue or secondValue);
  EclMenu.EclCompareInt(0, result);
  EclMenu.WriteGbvm(dest, result, GDVars.eclVarTypes[3]);
end;

{ GET TABLE, opcode $2A: reads the GBVM entry at its first argument's address plus its second and stores it at the
  address in its third. }
procedure EclGetTable;
var
  base: Word;
  dest: Word;
  vmAddr: Word;
  v: Word; idx: Byte;
begin
  EclMenu.LoadEclVars(3);
  base := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  idx := Byte(EclMenu.GetEclVar(2));
  dest := EclMenu.CombineBytesToWord(GDVars.eclVarLo[3], GDVars.eclVarHi[3]);
  vmAddr := base + idx;
  v := EclMenu.ReadGbvm(vmAddr, GDVars.eclVarTypes[3]);
  EclMenu.WriteGbvm(dest, v, GDVars.eclVarTypes[3]);
end;

{ SAVE TABLE, opcode $35: stores its first argument at the GBVM entry at its second argument's address plus its third. }
procedure EclSaveTable;
var
  idx: Word;
  base: Word;
  value: Word;
  vmAddr: Word;
begin
  EclMenu.LoadEclVars(3);
  value := EclMenu.GetEclVar(1);
  base := EclMenu.CombineBytesToWord(GDVars.eclVarLo[2], GDVars.eclVarHi[2]);
  idx := EclMenu.GetEclVar(3);
  vmAddr := base + idx;
  EclMenu.WriteGbvm(vmAddr, value, GDVars.eclVarTypes[1]);
end;

{ VERTICAL MENU, opcode $15: shows its message, then a vertical menu of as many strings as its third argument says, and
  stores the choice at the GBVM address in its first. }
procedure EclVMenu;
var
  count: Byte;
  idx: Byte;
  query: String;
  list: Types.PMenuLine;
  savedList: Types.PMenuLine;
  outIdx: Integer;
  redraw: Boolean;
  dest: Word; kind: Byte;
begin
  GDVars.horizMenuChoice := 1;
  GDVars.viewBoxDrawn := 0;
  redraw := True;
  idx := 1;
  EclMenu.LoadEclVars(3);
  dest := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  kind := GDVars.eclVarTypes[1];
  query := GDVars.eclStrings[1];
  count := Byte(EclMenu.GetEclVar(3));
  Dec(GDVars.vmBand.eclIp);
  EclMenu.LoadEclVars(count);
  MenuCore.AllocStringList(count, list);
  savedList := list;
  GDVars.textCursorCol := 1;
  GDVars.textCursorRow := 17;
  TextRend.DisplayMessageWindow(1, 17, 38, 22, 10, 0, True, query);
  while list <> nil do begin
    list^.name := GDVars.eclStrings[idx];
    list^.inUse := 0;
    list := list^.next;
    Inc(idx);
  end;
  list := savedList;
  outIdx := 0;
  { Note: the list pointer's own two words are also passed as ulRow and lrRow. }
  EclMenu.EclVerticalMenu('', '', 1, GDVars.textCursorRow + 1, 38, 22, Types.TPtrRec(list).seg, Types.TPtrRec(list).ofs,
                          0, redraw, outIdx, Pointer(list));
  EclMenu.WriteGbvm(dest, Word(outIdx), kind);
  MenuCore.FreeStringList(list);
  TextRend.ClearRect(1, 17, 38, 22);
end;

{ HORIZONTAL MENU, opcode $2B, and opcode $31: offers the options that follow across the bottom line and stores the
  chosen index at the address operand.
  @param(showMenu True for opcode $31, which first asks 'what do you do?'.) }
procedure EclHMenu(showMenu: Boolean);
var
  count: Byte;
  result: Byte;
  i: Byte;
  opts: String[80];
  dest: Word;
  kind: Byte;
begin
  if showMenu then
    TextRend.DisplayMessageWindow(1, 17, 38, 22, 10, 0, False, 'what do you do?');
  GDVars.horizMenuChoice := 1;
  opts := '';
  EclMenu.LoadEclVars(2);
  dest := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  kind := GDVars.eclVarTypes[1];
  count := Byte(EclMenu.GetEclVar(2));
  Dec(GDVars.vmBand.eclIp);
  EclMenu.LoadEclVars(count);
  opts := '';
  for i := 1 to count - 1 do
    opts := opts + '~' + GDVars.eclStrings[i] + ' ';
  opts := opts + '~' + GDVars.eclStrings[count];
  result := EclMenu.MenuHorizontalCharacterSelect('', opts, False, GDVars.eclPicShown);
  EclMenu.WriteGbvm(dest, result, kind);
  TextRend.ClearRect(0, 24, 39, 24);
end;

{ CLEAR MONSTERS ($1C): clears the encounter. }
procedure EclClearMonsters;
begin
  Inc(GDVars.vmBand.eclIp);
  CharHlp.ClearEncounterState;
end;

{ CHECK PARTY ($1E): reads its six operands and does nothing with them; the check is not used in this game. }
procedure EclCheckParty;
var
  { Unused in this version; see the other implementations of this routine. }
  v: Word;
  { Unused in this version; see the other implementations of this routine. }
  sum: Word;
  { Unused in this version; see the other implementations of this routine. }
  effectId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  found: Byte;
  { Unused in this version; see the other implementations of this routine. }
  partyTotals: array[0..4] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  maxValue: Byte;
  { Unused in this version; see the other implementations of this routine. }
  minValue: Byte;
  { Unused in this version; see the other implementations of this routine. }
  addr1: Word;
  { Unused in this version; see the other implementations of this routine. }
  addr2: Word;
  { Unused in this version; see the other implementations of this routine. }
  addr3: Word;
  { Unused in this version; see the other implementations of this routine. }
  addr4: Word;
  { Unused in this version; see the other implementations of this routine. }
  count: Byte;
  { Unused in this version; see the other implementations of this routine. }
  fourthAddress: Word;
begin
  EclMenu.LoadEclVars(6);
  p := GDVars.creatureListHead;
  found := 0;
  if GDVars.eclVarTypes[1] = 1 then
    v := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1])
  else
    v := Word(EclMenu.GetEclVar(1));
  effectId := Byte(EclMenu.GetEclVar(2));
  addr1 := EclMenu.CombineBytesToWord(GDVars.eclVarLo[3], GDVars.eclVarHi[3]);
  addr2 := EclMenu.CombineBytesToWord(GDVars.eclVarLo[4], GDVars.eclVarHi[4]);
  addr3 := EclMenu.CombineBytesToWord(GDVars.eclVarLo[5], GDVars.eclVarHi[5]);
  addr4 := EclMenu.CombineBytesToWord(GDVars.eclVarLo[6], GDVars.eclVarHi[6]);
  sum := 0;
  count := 0;
  minValue := $FF;
  maxValue := 0;
end;

{ COMBAT ($24): with no monsters loaded, opens a pending vault or healer, or else the after-combat screen. Otherwise the
  fight is run, with the monsters no farther than the view allows, followed by the after-combat screen. The normal
  interface is then put back. }
procedure EclCombat;
var maxDist: Word; launch: Boolean; savedSave: Byte;
begin
  GDVars.partyPanelHidden := 0;
  savedSave := GDVars.clickInputMode;
  GDVars.clickInputMode := 0;
  Inc(GDVars.vmBand.eclIp);
  launch := True;
  GDVars.mainPalReload := True;
  if GDVars.monstersLoaded = 0 then begin
    if GDVars.vmBand.zone0^.vaultRequest = 1 then begin
      GDVars.vmBand.zone0^.vaultRequest := 0;
      Vault.PoolVault;
    end else if GDVars.vmBand.zone0^.healerRequest = 1 then begin
      Temple.TempleMainMenu;
      GDVars.vmBand.zone0^.healerRequest := 0;
      if GDVars.vmBand.zone0^.inDungeon = 0 then launch := False;
    end else
      PostCbt.PostCombat;
  end else begin
    Portrait.FreeAnimation;
    EclMenu.CharFightsAlone;
    maxDist := EclMenu.MaxMonsterDist(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
    if GDVars.vmBand.zone0^.encounterDist > maxDist then GDVars.vmBand.zone0^.encounterDist := maxDist;
    Combat.CombatMain;
    PostCbt.PostCombat;
    if GDVars.vmBand.zone0^.inDungeon = 0 then
      Portrait.LoadBigPic(GDConsts.areaPictureIds[GDVars.vmBand.zone0^.tileSet]);
  end;
  if GDVars.vmBand.zone0^.inDungeon = 0 then
    GDVars.interfaceState := C_Ifc.AREA_MAP
  else
    GDVars.interfaceState := C_Ifc.DUNGEON;
  GDVars.vmBand.zone0^.travelFlags := GDVars.vmBand.zone0^.travelFlags and 1;
  GameIo.ZeroFill(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags));
  GDVars.eclPicShown := False;
  if launch then begin
    CharHlp.DisplayNoncombatInterface;
    if (GDVars.vmBand.zone0^.inDungeon = 0) and (not GDVars.partyDefeatedFlag) and
        (GDVars.vmBand.zone0^.mapPaneEnabled = 1) then
      MapWin.OpenWindow;
  end;
  GDVars.clickInputMode := savedSave;
end;

{ ON GOTO and ON GOSUB, opcodes $25 and $26: jumps to, or calls, the address its first argument picks from the list
  whose length its second gives; an index past the list does nothing. }
procedure EclOnGoto;
var
  { the position picked from the address list }
  selector: Byte;
  count: Byte;
  { Unused in this version; see the other implementations of this routine. }
  target: Byte;
  i: Byte;
  matched: Boolean;
begin
  matched := False;
  EclMenu.LoadEclVars(2);
  selector := Byte(EclMenu.GetEclVar(1));
  count := Byte(EclMenu.GetEclVar(2));
  Dec(GDVars.vmBand.eclIp);
  EclMenu.LoadEclVars(count);
  i := 0;
  while (i < count) and (not matched) do begin
    if selector = i then begin
      if GDVars.curEclOpcode = EclVm.ON_GOTO then
        GDVars.vmBand.eclIp := EclMenu.CombineBytesToWord(GDVars.eclVarLo[i + 1], GDVars.eclVarHi[i + 1])
      else
        EclMenu.EclGosub(i + 1);
      matched := True;
    end else
      Inc(i);
  end;
end;

{ TREASURE ($27) <platinum> <gems> <jewelry> <count> <items...>: adds money and items to the treasure handed out after
  the encounter. Item $FF is a randomly made scroll; an item whose definition is empty is skipped. }
procedure EclTreasure;
var
  treasureId: Byte;
  i: Byte;
  itemId: Byte;
  rawBuf: Types.TItemDef;
  node: Types.TItemRec;
  savedHead: Pointer;
begin
  EclMenu.LoadEclVars(4);
  Inc(GDVars.moneyPool[EclVm.MONEY_PLATINUM], EclMenu.GetEclVar(1));
  Inc(GDVars.moneyPool[EclVm.MONEY_GEMS], EclMenu.GetEclVar(2));
  Inc(GDVars.moneyPool[EclVm.MONEY_JEWELRY], EclMenu.GetEclVar(3));
  treasureId := Byte(EclMenu.GetEclVar(4));
  Dec(GDVars.vmBand.eclIp);
  EclMenu.LoadEclVars(treasureId);
  for i := 1 to treasureId do begin
    itemId := Byte(EclMenu.GetEclVar(i));
    if (itemId = $FF) or (GDVars.itemDefBlock^[itemId].itemType <> $FF) then begin
      if itemId = $FF then begin
        EclMenu.EclBuildRandomScroll(rawBuf);
        Move(rawBuf, node.definition, SizeOf(rawBuf));
      end else
        Move(GDVars.itemDefBlock^[itemId], node.definition, SizeOf(node.definition));
      node.next := nil;
      node.inUse := 0;
      if GDVars.treasureList = nil then begin
        GetMem(GDVars.treasureList, SizeOf(Types.TItemRec));
        GDVars.treasureList^ := node;
      end else begin
        savedHead := GDVars.treasureList;
        GetMem(GDVars.treasureList, SizeOf(Types.TItemRec));
        GDVars.treasureList^ := node;
        GDVars.treasureList^.next := savedHead;
      end;
    end;
  end;
end;

{ ROB, opcode $28: takes the percentage of money in its second argument and, with the chance in its third, items from
  the current character, or from every member when its first is non-zero. }
procedure EclRob;
var
  whole: Byte;
  pct: Byte;
  chance: Byte;
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  deadItems: Pointer;
  fraction: Real;
begin
  EclMenu.LoadEclVars(3);
  whole := Byte(EclMenu.GetEclVar(1));
  pct := Byte(EclMenu.GetEclVar(2));
  fraction := (100 - pct) / 100;
  chance := Byte(EclMenu.GetEclVar(3));
  if whole = 0 then begin
    EclMenu.RobMoney(fraction, GDVars.currentChar);
    EclMenu.RobItems(chance, GDVars.currentChar);
  end else begin
    p := GDVars.creatureListHead;
    while p <> nil do begin
      deadItems := p^.items;
      EclMenu.RobMoney(fraction, p);
      EclMenu.RobItems(chance, p);
      p := p^.next;
    end;
  end;
end;

{ Offers the continue menu and waits. }
procedure EclContinuePrompt;
var
  { Unused in this version; see the other implementations of this routine. }
  result: Byte;
begin
  Inc(GDVars.vmBand.eclIp);
  result := EclMenu.MenuHorizontalCharacterSelect('', GDConsts.tildePressButtonPrompt, True, GDVars.eclPicShown);
  MenuCore.ClearBottomLine;
end;

{ Opcode $22: asks a yes or no question; yes sets the equal flag, no the not-equal flag. }
procedure EclYesNo;
var
  { Unused in this version; see the other implementations of this routine. }
  answer: Word;
begin
  Inc(GDVars.vmBand.eclIp);
  GameIo.ZeroFill(GDVars.eclCmpFlags, SizeOf(GDVars.eclCmpFlags));
  if MenuCore.YesNoMenu(GDConsts.emptyQuery, GDConsts.yesChoice) = GDConsts.yesChoice then
    GDVars.eclCmpFlags[1] := 1
  else
    GDVars.eclCmpFlags[2] := 1;
  MenuCore.ClearBottomLine;
end;

{ FIND ITEM ($32) <item type>: sets the equal flag if anyone in the party carries an item of that type, and the
  not-equal flag otherwise. }
procedure EclFindItem;
var
  { the item type looked for }
  itemId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  itemCount: Byte;
  p: Types.PCharRecord;
  it: Types.PItemRec;
  found: Boolean;
begin
  EclMenu.LoadEclVars(1);
  found := False;
  itemId := Byte(EclMenu.GetEclVar(1));
  GameIo.ZeroFill(GDVars.eclCmpFlags, SizeOf(GDVars.eclCmpFlags));
  GDVars.eclCmpFlags[2] := 1;
  p := GDVars.creatureListHead;
  while (p <> nil) and (not found) do begin
    it := Types.PItemRec(p^.items);
    while (it <> nil) and (not found) do begin
      if itemId = it^.definition.itemType then begin
        GDVars.eclCmpFlags[1] := 1;
        GDVars.eclCmpFlags[2] := 0;
        found := True;
      end;
      it := it^.next;
    end;
    p := p^.next;
  end;
end;

{ DELAY, opcode $3A: waits 600 milliseconds. }
procedure EclDelay;
begin
  Inc(GDVars.vmBand.eclIp);
  Delay(600);
end;

{ DAMAGE ($2E) <attack> <dice> <sides> <bonus> <value>: rolls dice x sides + bonus of damage. With attack bit $80 set,
  the low four bits of attack are the saving-throw modifier and the low three bits of value the save type: bit $40 hits
  the whole party (bit $20 with no save), otherwise one target, the current character when value bit $80 is set (save
  type value - 1, none at 0) or else a random member. A made save halves the damage when attack bit $10 is set and
  cancels it when it is not. With bit $80 clear, attack is a number of separate attacks on random members, each rolled
  to hit against value and each with fresh damage. If that leaves the whole party out of play, the party is lost. }
procedure EclDamage;
var
  attack: Byte;
  dice: Byte;
  sides: Byte;
  i: Byte;
  thac0Arg: Byte;
  varIdx: Byte;
  bonus: Byte;
  rollResult: Byte;
  saveArg: Byte;
  j: Byte;
  dmg: Word;
  p: Types.PCharRecord;
  scanCursor: Types.PCharRecord;
  savedChar: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  damageType: Byte;
  flag1a: Boolean;
  flagA: Byte;
begin
  savedChar := GDVars.currentChar;
  damageType := 0;
  flag1a := False;
  p := GDVars.creatureListHead;
  EclMenu.LoadEclVars(5);
  attack := Byte(EclMenu.GetEclVar(1));
  dice := Byte(EclMenu.GetEclVar(2));
  sides := Byte(EclMenu.GetEclVar(3));
  bonus := Byte(EclMenu.GetEclVar(4));
  varIdx := Byte(EclMenu.GetEclVar(5));
  dmg := Word(FxEngine.RollDice(dice, sides)) + bonus;
  flagA := attack and $10;
  if (attack and $40) <> 0 then
    flag1a := True
  else
    rollResult := FxEngine.RollDice(1, GDVars.vmBand.zone0^.partySize);
  if (attack and $80) <> 0 then begin
    thac0Arg := attack and $F;
    saveArg := varIdx and $7;
    if flag1a then begin
      while p <> nil do begin
        if (attack and $20) <> 0 then
          EclMenu.EclInflictDamage(dmg, p)
        else begin
          if not FxEngine.RollSavingThrow(p, saveArg, thac0Arg) then
            EclMenu.EclInflictDamage(dmg, p)
          else if flagA <> 0 then
            EclMenu.EclInflictDamage(dmg div 2, p);
        end;
        p := p^.next;
      end;
    end else begin
      if (varIdx and $80) <> 0 then begin
        if (saveArg = 0) or (not FxEngine.RollSavingThrow(GDVars.currentChar, saveArg - 1, thac0Arg)) then
          EclMenu.EclInflictDamage(dmg, GDVars.currentChar)
        else if flagA <> 0 then
          EclMenu.EclInflictDamage(dmg div 2, GDVars.currentChar);
      end else begin
        for i := 2 to rollResult do
          p := p^.next;
        if not FxEngine.RollSavingThrow(p, saveArg, thac0Arg) then
          EclMenu.EclInflictDamage(dmg, p)
        else if flagA <> 0 then
          EclMenu.EclInflictDamage(dmg div 2, p);
      end;
    end;
  end else begin
    for i := 1 to attack do begin
        p := GDVars.creatureListHead;
        rollResult := FxEngine.RollDice(1, GDVars.vmBand.zone0^.partySize);
        j := 1;
        while j < rollResult do begin
          p := p^.next;
          Inc(j);
        end;
        if FxEngine.AttackRollNoAttacker(p, varIdx) then
          EclMenu.EclInflictDamage(dmg, p);
        dmg := Word(FxEngine.RollDice(dice, sides)) + bonus;
    end;
  end;
  scanCursor := GDVars.creatureListHead;
  GDVars.partyDefeatedFlag := True;
  while scanCursor <> nil do begin
    if scanCursor^.inPlay <> 0 then GDVars.partyDefeatedFlag := False;
    scanCursor := scanCursor^.next;
  end;
  if GDVars.partyDefeatedFlag then begin
    Border.DrawWindowFrame(0);
    GDVars.textCursorCol := 2;
    GDVars.textCursorRow := 2;
    TextRend.DisplayMessageWindow(1, 1, 38, 22, 10, 0, True, 'The entire party is killed!');
    Delay(3000);
  end;
  GDVars.currentChar := savedChar;
  TextRend.DisplayAndPause(15, 0, 'press <enter>/<return> to continue');
end;

{ CLOCK, opcode $34: advances the clock by its first argument in the unit its second names. }
procedure EclClock;
var
  amount: Byte;
  timeUnit: Byte;
begin
  EclMenu.LoadEclVars(2);
  amount := Byte(EclMenu.GetEclVar(1));
  timeUnit := Byte(EclMenu.GetEclVar(2));
  GameTime.AdvanceTime(amount, timeUnit);
end;

{ Opcode $33, PRINT RETURN: moves the text cursor to column 1 of the next line and clears the pending-return flag. }
procedure EclPrintReturn;
begin
  Inc(GDVars.vmBand.eclIp);
  if GDVars.protNewLine <> 0 then begin
    GDVars.textCursorCol := 1;
    Inc(GDVars.textCursorRow);
    GDVars.protNewLine := 0;
  end else begin
    GDVars.textCursorCol := 1;
    Inc(GDVars.textCursorRow);
  end;
end;

{ CLEAR BOX ($3D): redraws the screen frame, the party list and the status line. }
procedure EclClearBox;
begin
  Inc(GDVars.vmBand.eclIp);
  GDVars.partyPanelHidden := 0;
  Border.DrawExploreFrame;
  CharHlp.DisplayParty(GDVars.currentChar);
  CharHlp.PrintMiscInfo;
  CharHlp.PrintMiscInfo;
  GDVars.panelRestorePending := 0;
  GDVars.clearBoxDone := 1;
end;

{ WHO, opcode $39: asks the player to pick a party member, with its argument as the prompt, and makes that member
  current. }
procedure EclWho;
var query: String; saved: Byte;
begin
  saved := GDVars.clickInputMode;
  GDVars.clickInputMode := 0;
  GDVars.loadCharFailed := 0;
  EclMenu.LoadEclVars(1);
  TextRend.ClearRect(1, 17, 38, 22);
  query := GDVars.eclStrings[1];
  CharHlp.SelectChar(query, False, 0, Pointer(GDVars.currentChar));
  GDVars.clickInputMode := saved;
end;

{ ADD NPC, opcode $36: adds the monster its first argument names to the party as a non-player character whose morale is
  half its second argument. }
procedure EclAddNpc;
var
  { Unused in this version; see the other implementations of this routine. }
  npc: LongInt;
  monId: Byte;
  morale: Byte;
begin
  EclMenu.LoadEclVars(2);
  monId := Byte(EclMenu.GetEclVar(1));
  SaveLoad.AddCreatureToParty(monId);
  morale := Byte(EclMenu.GetEclVar(2));
  morale := morale shr 1;
  morale := morale or C_Npc.NON_PLAYER;
  GDVars.currentChar^.npc := morale;
  CharHlp.RecalcStats(GDVars.currentChar);
  CharHlp.DisplayParty(GDVars.currentChar);
end;

{ Opcode $37 <name> <address>: looks for the party NPC with the given name and stores its place in the party (counted
  from 0, plus $80 if it is out of play), or $FF if there is none. }
procedure EclFindNpc;
var
  tempName: String[40];
  p: Types.PCharRecord;
  wsSlot: Word;
  found: Boolean;
  slot: Byte;
begin
  EclMenu.LoadEclVars(2);
  tempName := GDVars.eclStrings[1];
  wsSlot := EclMenu.CombineBytesToWord(GDVars.eclVarLo[2], GDVars.eclVarHi[2]);
  p := GDVars.creatureListHead;
  found := False;
  slot := 0;
  while (p <> nil) and (not found) do begin
    if (p^.name = tempName) and (p^.npc > $7F) then
      found := True
    else begin
      p := p^.next;
      Inc(slot);
    end;
  end;
  if not found then
    slot := $FF
  else if (p^.inPlay = 0) then
    slot := slot or $80;
  { Note: the result is stored with the first operand's type. }
  EclMenu.WriteGbvm(wsSlot, slot, GDVars.eclVarTypes[1]);
end;

{ SPELL ($3B) <spell> <address1> <address2>: finds the first party member in play who has the spell memorized. Stores
  its position in that member's spell list, or $FF if nobody has it, and the member's place in the party. }
procedure EclSpell;
var
  spellId: Byte;
  idx: Byte;
  idx2: Byte;
  p: Types.PCharRecord;
  doneFlag: Boolean;
  exhausted: Boolean;
  firstAddress: Word;
  secondAddress: Word;
begin
  exhausted := False;
  doneFlag := False;
  EclMenu.LoadEclVars(3);
  spellId := Byte(EclMenu.GetEclVar(1));
  firstAddress := EclMenu.CombineBytesToWord(GDVars.eclVarLo[2], GDVars.eclVarHi[2]);
  secondAddress := EclMenu.CombineBytesToWord(GDVars.eclVarLo[3], GDVars.eclVarHi[3]);
  idx := 1;
  idx2 := 0;
  p := GDVars.creatureListHead;
  while (p <> nil) and (not doneFlag) do begin
    idx := 0;
    if p^.inPlay <> 0 then begin
      repeat
        if p^.spells[idx] = spellId then
          doneFlag := True
        else begin
          if idx < 140 then
            Inc(idx)
          else
            exhausted := True;
        end;
      until exhausted or doneFlag;
    end;
    exhausted := False;
    p := p^.next;
    if (p <> nil) and (not doneFlag) then
      Inc(idx2);
  end;
  if not doneFlag then
    idx := $FF;
  EclMenu.WriteGbvm(firstAddress, idx, GDVars.eclVarTypes[2]);
  EclMenu.WriteGbvm(secondAddress, idx2, GDVars.eclVarTypes[3]);
end;

{ CALL ($2D) <routine>: runs a built-in routine: 1 refreshes the event and the view, 2 moves the party one square
  forward, 3 shows the next frame of the current picture. }
procedure EclCall;
var vmAddr: Word;
begin
  EclMenu.LoadEclVars(1);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  case vmAddr of
    1: EclMenu.UpdateEclDisplay;
    2: EclMenu.EclMoveForward;
    3: begin
         Mouse.HideMouse;
         Portrait.DisplayImageBuf(3, 3, True, GDVars.animCurFrame);
         Mouse.ShowMouse;
         Inc(GDVars.animCurFrame);
         if GDVars.animCurFrame > GDVars.animLastFrame then
           GDVars.animCurFrame := GDVars.animFirstFrame;
         TextRend.PauseOnly;
       end;
  end;
end;

{ Runs the before-camp script entry (entry point 3) and the camp menu; if the rest was interrupted, repaints the
  non-combat interface and runs the camp-interrupted entry (entry point 4). Then requests a map redraw, redraws the map
  view, clears the recently-saved flag, and, when not in a dungeon and the map pane is on, draws the map cursor. }
procedure EnterCamp;
var interrupted: Boolean;
begin
  interrupted := False;
  EclVm.CallEclScript(GDVars.vmBand.vmRun[3]);
  Camp.CampMainMenu(interrupted);
  if interrupted then begin
    CharHlp.DisplayNoncombatInterface;
    EclVm.CallEclScript(GDVars.vmBand.vmRun[4]);
  end;
  GDVars.mapRedrawPending := 1;
  MapView.DisplayMapView;
  GDVars.justSaved := 0;
  if (GDVars.vmBand.zone0^.inDungeon = 0) and (GDVars.vmBand.zone0^.mapPaneEnabled = 1) then
    MapWin.OpenWindow;
end;

{ PROGRAM ($38) <program>: 0 opens the party creation and training menu, 1 saves and quits to DOS, 2 quits at once, 9
  camps. }
procedure EclProgram;
var
  prog: Byte;
  saved: Word;
  { Unused in this version; see the other implementations of this routine. }
  key: array[0..4] of Byte;
  savedFlag: Byte;
begin
  savedFlag := GDVars.clickInputMode;
  GDVars.clickInputMode := 0;
  if GDVars.pendingCharSwap then begin
    GDVars.currentChar := Types.PCharRecord(GDVars.pendingChar);
    GDVars.pendingCharSwap := False;
  end;
  EclMenu.LoadEclVars(1);
  prog := Byte(EclMenu.GetEclVar(1));
  case prog of
    0: begin
         CharGen.MainMenu;
         if (GDVars.picArcId <> 9) and (GDVars.vmBand.zone0^.inDungeon = 0) and
             (GDVars.vmBand.zone0^.mapPaneEnabled = 1) and (GDVars.scriptAbort = 0) then begin
           CharHlp.DisplayNoncombatInterface;
           MapWin.OpenWindow;
         end;
       end;
    1: ExitDos.ExitToDos;
    2: begin
         GameIo.ExitGame(0);
         Halt(0);
       end;
    9: begin
         saved := GDVars.vmBand.eclIp;
         EclVm.EnterCamp;
         GDVars.vmBand.eclIp := saved;
         if GDVars.vmBand.zone0^.mapPaneEnabled = 1 then
           EclVm.EclExit;
       end;
  end;
  GDVars.clickInputMode := savedFlag;
end;

{ REMOVE CHARACTER, opcode $3E: removes the current character from the party, keeps the character that becomes current
  as the saved character to restore, and redraws the party. }
procedure EclDump;
begin
  Inc(GDVars.vmBand.eclIp);
  CharGen.RemoveCreature(False, True);
  GDVars.pendingChar := GDVars.currentChar;
  CharHlp.DisplayParty(GDVars.currentChar);
end;

{ HAS EFFECT, opcode $3F: clears the compare flags, then sets the equal flag when the current character has the effect
  in its argument, the not-equal flag otherwise. }
procedure EclFindSpecial;
var eff: Pointer; idx: Byte;
begin
  GameIo.ZeroFill(GDVars.eclCmpFlags, SizeOf(GDVars.eclCmpFlags));
  EclMenu.LoadEclVars(1);
  idx := Byte(EclMenu.GetEclVar(1));
  if CharHlp.HasEffect(GDVars.currentChar, idx, eff) then
    GDVars.eclCmpFlags[1] := 1
  else
    GDVars.eclCmpFlags[2] := 1;
end;

{ Opcode $40 <item type>: takes every item of that type away from the whole party, unreadying it first. With bit $80 set
  only magical items are taken. }
procedure EclDestroyItems;
var
  idx: Byte;
  p: Types.PCharRecord;
  savedChar: Types.PCharRecord;
  it: Types.PItemRec;
  nextIt: Types.PItemRec;
  flag80: Byte;
begin
  EclMenu.LoadEclVars(1);
  idx := Byte(EclMenu.GetEclVar(1));
  flag80 := idx and $80;
  idx := idx and $7F;
  savedChar := GDVars.currentChar;
  p := GDVars.creatureListHead;
  while p <> nil do begin
    it := Types.PItemRec(p^.items);
    while it <> nil do begin
      nextIt := it^.next;
      if idx = it^.definition.itemType then begin
        if (flag80 = 0) or (it^.definition.plus <> 0) then begin
          GDVars.currentChar := p;
          if it^.definition.equipped <> 0 then
            ViewChar.ToggleReadyItem(it);
          CharHlp.RemoveItem(p, it);
        end;
      end;
      it := nextIt;
    end;
    CharHlp.RecalcStats(p);
    p := p^.next;
  end;
  GDVars.currentChar := savedChar;
end;

{ Runs the award-experience command, whose operands are a whole-party flag and an amount: awards the amount x 100
  experience points, divided by the member's number of non-zero class levels (cleric to thief), to every party member in
  play when the flag is non-zero, otherwise to the current character if it is in play. It announces the award and marks
  whether each recipient can now level up, and after a party award redraws the party. }
procedure EclAwardExperience;
var
  xpRaw: LongInt; share: LongInt; scaledPct: LongInt; ask: Byte;
  p: Types.PCharRecord; i: ShortInt; eligibleCount: Byte;
begin
  EclMenu.LoadEclVars(2);
  xpRaw := EclMenu.GetEclVar(2);
  scaledPct := xpRaw * 100;
  ask := Byte(EclMenu.GetEclVar(1));
  GDVars.textCursorRow := 17;
  GDVars.textCursorCol := 1;
  if ask <> 0 then begin
    TextRend.DisplayMessageWindow(1, 17, 38, 22, 10, 0, True, 'Congratulations the party gains experience!');
    TextRend.PauseOnly;
    p := GDVars.creatureListHead;
    while p <> nil do begin
      if p^.inPlay <> 0 then begin
        eligibleCount := 0;
        for i := C_Class.CLERIC to C_Class.THIEF do
          if p^.classLevels[i] > 0 then Inc(eligibleCount);
        { Note: a character with no class levels divides by zero here. }
        share := scaledPct div eligibleCount;
        p^.experience := p^.experience + share;
        p^.levelCapped := Byte(CharHlp.CanLevelUp(p));
      end;
      p := p^.next;
    end;
    CharHlp.DisplayParty(GDVars.currentChar);
  end else begin
    p := GDVars.currentChar;
    if p^.inPlay <> 0 then begin
      TextRend.DisplayMessageWindow(1, 17, 38, 22, 10, 0, True, 'Congratulations ' + p^.name + ' gains experience!');
      TextRend.PauseOnly;
      eligibleCount := 0;
      for i := C_Class.CLERIC to C_Class.THIEF do
        if p^.classLevels[i] > 0 then Inc(eligibleCount);
      share := scaledPct div eligibleCount;
      p^.experience := p^.experience + share;
      p^.levelCapped := Byte(CharHlp.CanLevelUp(p));
    end;
  end;
end;

{ Opcode $1F <number>: tells the party which journal entry to read, then waits for a key or button. }
procedure EclJournalEntry;
var
  s: String;
  { Unused in this version; see the other implementations of this routine. }
  result: Byte;
  v: Word;
begin
  EclMenu.LoadEclVars(1);
  v := EclMenu.GetEclVar(1);
  GDVars.textCursorRow := 17;
  GDVars.textCursorCol := 1;
  s := 'This is recorded as journal entry ' + CharHlp.Uint8Str(Byte(v)) + '.';
  TextRend.DisplayMessageWindow(1, 17, 38, 22, 10, 0, True, s);
  result := EclMenu.MenuHorizontalCharacterSelect('', GDConsts.tildePressButtonPrompt, True, GDVars.eclPicShown);
  MenuCore.ClearBottomLine;
end;

{ Opcode $23: clears the message window, updates the display and ends the script. }
procedure EclRedrawExit;
begin
  TextRend.ClearRect(1, 17, 38, 22);
  EclMenu.UpdateEclDisplay;
  EclVm.EclExit;
end;

{ PLAY SOUND ($2C) <value>: bit $80 set switches the music to piece (value and $7F); 2 to 14 plays that sound. }
procedure EclPlaySound;
var soundCode: Byte;
begin
  EclMenu.LoadEclVars(1);
  soundCode := Byte(EclMenu.GetEclVar(1));
  if soundCode > $7F then
    Music.StartMusic(soundCode and $7F)
  else if (soundCode < 15) and (soundCode > 1) then
    Music.SendSoundCommand(soundCode);
end;

{ Opcode $29: not used in this game; skipped. }
procedure EclEncounter;
begin
  Inc(GDVars.vmBand.eclIp);
end;

{ STORE ($3C) <category>: opens a store stocked with the items listed for category 1 to 11 (out-of-range values use 1);
  a listed item of $FF is a scroll made at random. The stock goes on the same list TREASURE fills. }
procedure EclShop;
var
  { the item being added }
  rawBuf: Types.TItemDef;
  idx: Byte;
  itemIdx: Byte;
  node: Types.TItemRec;
  savedHead: Pointer;
  loBound: Word;
  hiBoundW: Word;
  k: Byte;
begin
  EclMenu.LoadEclVars(1);
  CharHlp.ClearEncounterState;
  idx := Byte(EclMenu.GetEclVar(1));
  if (idx > 11) or (idx < 1) then idx := 1;
  loBound := GDConsts.storeFirstSlot[idx];
  hiBoundW := GDConsts.storeLastSlot[idx];
  for k := Byte(loBound) to Byte(hiBoundW) do begin
      itemIdx := GDConsts.storeSlotItems[k];
      if itemIdx = $FF then
        EclMenu.EclBuildRandomScroll(rawBuf)
      else
        rawBuf := GDVars.itemDefBlock^[itemIdx];
      if rawBuf.itemType <> $FF then begin
        Move(rawBuf, node.definition, SizeOf(rawBuf));
        node.definition.unidMask := node.definition.unidMask and $F8;
        node.next := nil;
        node.inUse := 0;
        if GDVars.treasureList = nil then begin
          GetMem(GDVars.treasureList, SizeOf(Types.TItemRec));
          GDVars.treasureList^ := node;
        end else begin
          savedHead := GDVars.treasureList;
          GetMem(GDVars.treasureList, SizeOf(Types.TItemRec));
          GDVars.treasureList^ := node;
          GDVars.treasureList^.next := savedHead;
        end;
      end;
  end;
  Shop.ShopMainMenu;
  CharHlp.ClearEncounterState;
end;

{ Runs the handler for the current opcode. }
procedure DispatchEclCommand;
begin
  case GDVars.curEclOpcode of
    EclVm.OP_EXIT: EclVm.EclExit;
    C_Ecl.OP_GOTO: EclVm.EclGoto;
    C_Ecl.GOSUB: EclVm.EclGosubCmd;
    C_Ecl.COMPARE: EclVm.EclCompare;
    C_Ecl.ADD, EclVm.SUBTRACT, EclVm.DIVIDE, C_Ecl.MULTIPLY: EclVm.EclArithmetic;
    C_Ecl.OP_RANDOM: EclVm.EclRandom;
    C_Ecl.SAVE: EclVm.EclSave;
    C_Ecl.LOAD_CHARACTER: EclVm.EclLoadCharacter;
    C_Ecl.LOAD_MONSTER: EclVm.EclLoadMonster;
    C_Ecl.SETUP_MONSTER: EclVm.EclSetupMonster;
    EclVm.APPROACH: EclVm.EclApproach;
    C_Ecl.PICTURE: EclVm.EclPicture;
    C_Ecl.INPUT_NUMBER: EclVm.EclInputNumber;
    C_Ecl.INPUT_STRING: EclVm.EclInputString;
    C_Ecl.PRINT, C_Ecl.PRINT_CLEAR: EclVm.EclPrint;
    EclVm.OP_RETURN: EclVm.EclReturn;
    C_Ecl.COMPARE_AND: EclVm.EclCompareAnd;
    EclVm.VERTICAL_MENU: EclVm.EclVMenu;
    EclVm.IF_EQ, EclVm.IF_NE, EclVm.IF_LT, EclVm.IF_GT, EclVm.IF_LE, EclVm.IF_GE: EclVm.EclIf;
    EclVm.CLEAR_MONSTERS: EclVm.EclClearMonsters;
    EclVm.WAIT_KEY: EclVm.EclContinuePrompt;
    $1E: EclVm.EclCheckParty;
    C_Ecl.JOURNAL_ENTRY: EclVm.EclJournalEntry;
    C_Ecl.NEW_ECL: EclVm.EclNewEcl;
    C_Ecl.LOAD_FILES: EclVm.EclLoadFiles;
    EclVm.YES_NO: EclVm.EclYesNo;
    $23: EclVm.EclRedrawExit;
    EclVm.OP_COMBAT: EclVm.EclCombat;
    EclVm.ON_GOTO, EclVm.ON_GOSUB: EclVm.EclOnGoto;
    EclVm.TREASURE: EclVm.EclTreasure;
    C_Ecl.ROB: EclVm.EclRob;
    $29: EclVm.EclEncounter;
    C_Ecl.GET_TABLE: EclVm.EclGetTable;
    EclVm.HORIZONTAL_MENU: EclVm.EclHMenu(False);
    C_Ecl.PLAY_SOUND: EclVm.EclPlaySound;
    C_Ecl.CALL: EclVm.EclCall;
    C_Ecl.DAMAGE: EclVm.EclDamage;
    C_Ecl.OP_AND, C_Ecl.OP_OR: EclVm.EclAndOr;
    $31: EclVm.EclHMenu(True);
    C_Ecl.FIND_ITEM: EclVm.EclFindItem;
    EclVm.PRINT_RETURN: EclVm.EclPrintReturn;
    C_Ecl.CLOCK: EclVm.EclClock;
    C_Ecl.SAVE_TABLE: EclVm.EclSaveTable;
    C_Ecl.ADD_NPC: EclVm.EclAddNpc;
    C_Ecl.FIND_NPC: EclVm.EclFindNpc;
    C_Ecl.OP_PROGRAM: EclVm.EclProgram;
    C_Ecl.WHO: EclVm.EclWho;
    EclVm.OP_DELAY: EclVm.EclDelay;
    C_Ecl.SPELL: EclVm.EclSpell;
    C_Ecl.STORE: EclVm.EclShop;
    EclVm.CLEAR_BOX: EclVm.EclClearBox;
    EclVm.REMOVE_CHARACTER: EclVm.EclDump;
    C_Ecl.HAS_EFFECT: EclVm.EclFindSpecial;
    C_Ecl.TAKE_ITEMS: EclVm.EclDestroyItems;
    C_Ecl.AWARD_EXPERIENCE: EclVm.EclAwardExperience;
  end;
end;

{ Runs the loaded script until a command stops it, the party is defeated or the script is aborted.
  @param(startPc The address to start at.) }
procedure CallEclScript(startPc: Word);
var
  { Unused in this version; see the other implementations of this routine. }
  savedIp: Word;
begin
  GDVars.scratchIndex := 1;
  GDVars.vmBand.eclIp := startPc;
  GDVars.loopRunning := 0;
  while (GDVars.loopRunning = 0) and (not GDVars.partyDefeatedFlag) and (GDVars.scriptAbort = 0) do begin
    GDVars.prevEclOpcode := GDVars.curEclOpcode;
    GDVars.curEclOpcode := GDVars.vmBand.zone3^[GDVars.vmBand.eclIp];
    EclVm.DispatchEclCommand;
  end;
  GDVars.loopRunning := 0;
end;

{ Runs the script for the party's new position: from its fifth entry point, then (unless that moved the party again) its
  first and second, repeating as long as a script moves the party on. }
procedure NewEclDone;
begin
  repeat
    Portrait.FreeAnimation;
    GDVars.savedResourceName[0] := #0;
    GDVars.savedResourceId := $FF;
    GDVars.areaExitFlag := False;
    GDVars.mapState.event := View3D.GetMapEvent(GDVars.mapState.x, GDVars.mapState.y);
    GDVars.vmBand.zone0^.edgeClamp := 0;
    GDVars.pendingChar := GDVars.currentChar;
    EclVm.CallEclScript(GDVars.vmBand.vmRun[5]);
    if not GDVars.areaExitFlag then
      GDVars.vmBand.zone0^.areaScriptId := GDVars.eclScriptId;
    if not GDVars.areaExitFlag then begin
      if (GDVars.savedInterfaceState <> C_Ifc.DUNGEON) or (GDVars.interfaceState = C_Ifc.DUNGEON) or
          ((GDVars.savedInterfaceState = C_Ifc.DUNGEON) and (GDVars.interfaceState = C_Ifc.DUNGEON)) then
        MapView.DisplayMapView;
      GDVars.areaExitFlag := False;
      EclVm.CallEclScript(GDVars.vmBand.vmRun[1]);
      if not GDVars.areaExitFlag then begin
        EclVm.CallEclScript(GDVars.vmBand.vmRun[2]);
        if not GDVars.areaExitFlag then begin
          GDVars.currentChar := GDVars.pendingChar;
          CharHlp.DisplayParty(GDVars.currentChar);
        end;
      end;
    end;
  until not GDVars.areaExitFlag;
  GDVars.savedInterfaceState := GDVars.interfaceState;
end;

procedure GameLoop;
var
  moveResult: Byte;
  p: Types.PCharRecord;
  savedFlag: Byte;
begin
  repeat
    GDVars.scriptAbort := 0;
    GDVars.pendingChar := GDVars.currentChar;
    GDVars.mapRedrawPending := 1;
    GDVars.pendingCharSwap := False;
    GDVars.interfaceState := C_Ifc.DUNGEON;
    GDVars.areaExitFlag := False;
    if GDVars.vmBand.zone0^.areaScriptId = 0 then begin
      if GDVars.demoMode then
        GDVars.eclScriptId := 4
      else begin
        GDVars.eclScriptId := 16;
        CharHlp.DisplayParty(GDVars.currentChar);
      end;
    end else
      GDVars.eclScriptId := GDVars.vmBand.zone0^.areaScriptId;
    if GDVars.vmBand.zone0^.inDungeon = 0 then
      GDVars.interfaceState := C_Ifc.AREA_MAP;
    EclMenu.LoadEclScript(GDVars.eclScriptId);
    EclMenu.EclInit;
    EclVm.CallEclScript(GDVars.vmBand.vmRun[5]);
    if GDVars.demoMode then begin
      p := GDVars.creatureListHead;
      while p <> nil do begin
        GDVars.currentChar := p;
        p := p^.next;
        CharGen.RemoveCreature(True, True);
      end;
      Exit;
    end;
    if not GDVars.areaExitFlag then
      GDVars.vmBand.zone0^.areaScriptId := GDVars.eclScriptId
    else
      EclVm.NewEclDone;
    if (GDVars.interfaceState <> C_Ifc.AREA_MAP) and (GDVars.savedGameLoaded <> 0) then begin
      if GDVars.panelRestorePending = 1 then
        CharHlp.DisplayNoncombatInterface;
      GDVars.mapRedrawPending := 1;
      MapView.DisplayMapView;
    end;
    GDVars.savedGameLoaded := 0;
    GDVars.clickInputMode := 0;
    savedFlag := 1;
    repeat
      GDVars.horizMenuChoice := savedFlag;
      moveResult := Explore.MapMainMenu;
      savedFlag := GDVars.horizMenuChoice;
      GDVars.pendingChar := GDVars.currentChar;
      if not GDVars.areaExitFlag then
        GDVars.vmBand.zone0^.areaScriptId := GDVars.eclScriptId;
      while ((GDVars.vmBand.zone0^.travelFlags > 1) or (moveResult = 4)) and (not GDVars.partyDefeatedFlag) and
          (GDVars.scriptAbort = 0) do begin
        if moveResult = 4 then
          EclVm.EnterCamp
        else begin
          GDVars.savedSearching := GDVars.vmBand.zone0^.travelFlags and 1;
          GDVars.vmBand.zone0^.travelFlags := 1;
          GDVars.mapRedrawPending := 1;
          MapView.DisplayMapView;
          EclVm.CallEclScript(GDVars.vmBand.vmRun[2]);
          if GDVars.areaExitFlag then
            EclVm.NewEclDone;
          GDVars.vmBand.zone0^.travelFlags := GDVars.savedSearching;
        end;
        if (not GDVars.partyDefeatedFlag) and (GDVars.scriptAbort = 0) then begin
          GDVars.horizMenuChoice := savedFlag;
          moveResult := Explore.MapMainMenu;
          savedFlag := GDVars.horizMenuChoice;
          GDVars.pendingChar := GDVars.currentChar;
        end;
      end;
      if (not GDVars.partyDefeatedFlag) and (GDVars.scriptAbort = 0) then
        EclVm.CallEclScript(GDVars.vmBand.vmRun[1]);
      if GDVars.areaExitFlag then
        EclVm.NewEclDone
      else if (not GDVars.partyDefeatedFlag) and (GDVars.scriptAbort = 0) then begin
        GDVars.vmBand.zone0^.prevX := GDVars.mapState.x;
        GDVars.vmBand.zone0^.prevY := GDVars.mapState.y;
        Explore.ResolveMovement;
        MapView.DisplayMapView;
        GDVars.eclPicShown := False;
        EclVm.CallEclScript(GDVars.vmBand.vmRun[2]);
        if GDVars.areaExitFlag then
          EclVm.NewEclDone;
      end;
    until GDVars.partyDefeatedFlag or (GDVars.scriptAbort <> 0);
  until GDVars.partyDefeatedFlag;
  GDVars.partyDefeatedFlag := False;
  p := GDVars.creatureListHead;
  while p <> nil do begin
    GDVars.currentChar := p;
    p := p^.next;
    CharGen.RemoveCreature(False, True);
  end;
end;

begin
end.
