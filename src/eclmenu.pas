{ ECL script support: loading a script and its command operands, reading and writing script variables in the three
  address zones (game state, the current character, script memory), packed strings, the comparison flags, gosub, and the
  commands' helpers for menus, encounters, robbery, damage and treasure. }
{$O+,F+}
unit EclMenu;

interface

uses Types, GDConsts, GDVars, ZeroFree, GameIo, DaxIo, TextRend, Blit, SaveLoad,
  ViewChar, FxEngine, CharHlp, MenuCore, MapView, Portrait, View3D, MapTiles, Sym8x8, C_Ecl, C_Effect, C_Dir, C_Ifc,
  C_Keys, C_Spell, C_Status;

{ Returns the value of an operand: a literal byte (type 0), the GBVM value at its address (1, 3, $80), or its two bytes
  as a word (2, $81).
  @param(idx Operand number, from 1.)
  @returns(The operand's value.) }
function GetEclVar(idx: ShortInt): Word;

{ Decodes the arguments of the current script command: each has a type byte and a low byte, and types 1..3 add a high
  byte. Type $80 is an inline packed string of that length and $81 the address of a string; both go to the next script
  string. Leaves the instruction pointer on the next command.
  @param(count The number of arguments.) }
procedure LoadEclVars(count: Byte);

{ Resets the interpreter for a newly loaded script and reads the five entry addresses at its head. The area state is
  cleared too, unless a saved game has just been restored. }
procedure EclInit;

{ Loads a script block from ECL1.DAX into script memory, retrying until it reads, and drops the block's two-byte header.
  @param(scriptId The block.) }
procedure LoadEclScript(scriptId: Byte);

{ Allocates and loads a monster.
  @param(id The monster's record.)
  @param(cr Receives the monster.)
  @param(inv Receives the head of its item list.)
  @param(eff Receives the head of its effect list.) }
procedure InitCreature(id: Byte; var cr, inv, eff: Pointer);

{ Works out how far ahead a monster can appear. Outside the 3D view it is 2, also stored as the zone's monster distance;
  in it, the number of open cells (at most 2) walking from the position in the facing before a wall.
  @param(x The starting column.)
  @param(y The starting row.)
  @param(facing The direction, 0, 2, 4 or 6.)
  @returns(The distance in cells, 0..2.) }
function MaxMonsterDist(x, y, facing: Byte): Byte;

{ Shows an encounter: the monster's 3D sprite in a dungeon, closing the automap first, and its picture once it is
  adjacent or has no sprite.
  @param(sprId The sprite, $FF for none.)
  @param(picId The picture, $FF for none.)
  @param(dist The monster's distance.)
  @param(flags Records what is already shown.) }
procedure DisplayMonster(sprId, picId, dist: Byte; var flags: Types.TMonFlags);

{ Joins two bytes into a word.
  @param(lower The low byte.)
  @param(upper The high byte.)
  @returns(The word.) }
function CombineBytesToWord(lower, upper: Byte): Word;

{ Writes a script variable. Game-state writes that move the party, change its facing, switch between dungeon and
  wilderness, change the tile set or close the automap take effect at once. Note: a word written at $0400 stores one
  byte past the end of the game-state area.
  @param(vmAddr The script address.)
  @param(value The value.)
  @param(kind The width: below 2 one byte, 2 and up two.) }
procedure WriteGbvm(vmAddr, value: Word; kind: Byte);

{ Reads a script variable. A few game-state addresses are computed: whether anyone in the party is detecting magic, the
  party's position and facing, and the wall and event ahead.
  @param(vmAddr The script address.)
  @param(kind The width: below 2 one byte, 2 and up two.)
  @returns(The value.) }
function ReadGbvm(vmAddr: Word; kind: Byte): Word;

{ Stores a string at a script address: zero-terminated in game state, or as the current character's name.
  @param(vmAddr The script address.)
  @param(s The string.) }
procedure WriteGbvmString(vmAddr: Word; s: String);

{ Runs a script's horizontal menu. In a dungeon an extended key switches the current character without leaving the menu.
  @param(query The text before the menu.)
  @param(menu The script menu string, prepared by MenuToOptions.)
  @param(enterOk True lets Escape end the menu.)
  @param(animate Passed to MenuCore.MenuHorizontal as its animate flag.)
  @returns(The chosen option, from 0, or 0 on Escape.) }
function MenuHorizontalCharacterSelect(query: Types.TStr40; menu: String; enterOk: Boolean; animate: Boolean): Byte;

{ A script's vertical list menu, through MenuCore.MenuVertical. ulRow and lrRow together carry the far pointer to the
  list, which listArg reads as one.
  @param(query The text before the menu.)
  @param(menu The script menu string, prepared by MenuToOptions.)
  @param(qCol The window's left column.)
  @param(mCol Its top row.)
  @param(hlCol Its right column.)
  @param(ulCol Its bottom row.)
  @param(ulRow Unused by name: it is the list pointer's segment.)
  @param(lrRow The list pointer's offset.)
  @param(lrCol Nonzero adds Exit to the menu.)
  @param(redraw As MenuVertical's.)
  @param(idx As MenuVertical's selectionIndex.)
  @param(sel Receives the chosen line.) }
procedure EclVerticalMenu(query: Types.TStr40; menu: String; qCol, mCol, hlCol, ulCol: Byte; ulRow, lrRow: Word;
                          lrCol: Byte; var redraw: Boolean; var idx: Integer; var sel: Pointer);

{ Sets the six comparison flags from two strings: equal, not equal, less, greater, less or equal, greater or equal.
  @param(leftOperand The left side.)
  @param(rightOperand The right side.) }
procedure EclCompareStr(leftOperand, rightOperand: String);

{ Sets the six comparison flags from two numbers: equal, not equal, less, greater, less or equal, greater or equal.
  @param(leftOperand The left side.)
  @param(rightOperand The right side.) }
procedure EclCompareInt(leftOperand, rightOperand: Word);

{ Pushes the instruction pointer on the script return stack and jumps to the address in a loaded argument.
  @param(varIdx The argument holding the address.) }
procedure EclGosub(varIdx: Byte);

{ Moves the party one square forward, wrapping around the 16x16 map, and refreshes the event and the wall ahead. }
procedure EclMoveForward;

{ Leaves a character with a fraction of each kind of coin.
  @param(fraction The fraction kept.)
  @param(cr The character.) }
procedure RobMoney(fraction: Real; cr: Pointer);

{ Steals each of a character's items on a 1d100 roll within the chance, unreadying a readied item before removing it; an
  item heavier than 255 takes 90 off the chance and one heavier than 24 takes 50. Note: the reductions come off the
  chance itself, so they lower the chance for each item after it too.
  @param(chance The chance, in percent.)
  @param(cr The character.) }
procedure RobItems(chance: Byte; cr: Pointer);

{ Steps eclIp over the current command, reading as many operands as it takes. }
procedure SkipEclCmd;

{ Deals script damage to a creature with a message, then redraws the party panel; a creature out of play is skipped. The
  message says it dies when the damage is more than 10 above its hit points; otherwise it gives the damage, at most
  three digits. When the message window is full it waits for a key first.
  @param(dmg The damage.)
  @param(cr The character.) }
procedure EclInflictDamage(dmg: Word; cr: Pointer);

{ Refreshes the event under the party and, if a script picture or sprite was shown, clears it and redraws the view. }
procedure UpdateEclDisplay;

{ Before a fight, adds a reserve of the current area's summonable monster to the end of the combatant list: ten copies
  while room remains, each out of play (status 9) with its own copies of the monster's items and effects, waiting for a
  summoning to gate them in. }
procedure CharFightsAlone;

{ Builds a random-treasure item record carrying three spells, each rolled until it hits a magic-user spell.
  @param(item Receives the record.) }
procedure EclBuildRandomScroll(var item: Types.TItemDef);

implementation

type
  TReadBuf = array[0..599] of Byte;

procedure ConvGbString(len, strIdx: Byte); forward;

procedure DerefGbString(strIdx: Byte; vmAddr: Word); forward;

function DecodeGameCharacter(c: Byte): Char; forward;

function GbvmZone(vmAddr: Word): Byte; forward;

function SpecialReadZ1(vmAddr: Word; kind: Byte): Word; forward;

procedure SpecialWriteZ1(vmAddr, value: Word); forward;

procedure MenuToOptions(var menu: String; var opts: Types.TStr40; var cnt: Byte); forward;

procedure LoadEclVars(count: Byte);
var
  i: Byte;
  strIdx: Byte;
  v: Word;
  len: Word;
begin
  strIdx := 0;
  for i := 1 to count do begin
    GDVars.eclVarTypes[i] := GDVars.vmBand.zone3^[GDVars.vmBand.eclIp + 1];
    GDVars.eclVarLo[i] := GDVars.vmBand.zone3^[GDVars.vmBand.eclIp + 2];
    GDVars.vmBand.eclIp := GDVars.vmBand.eclIp + 2;
    case GDVars.eclVarTypes[i] of
      1, 2, 3: begin
        Inc(GDVars.vmBand.eclIp);
        GDVars.eclVarHi[i] := GDVars.vmBand.zone3^[GDVars.vmBand.eclIp];
      end;
      $80: begin
        Inc(strIdx);
        len := GDVars.eclVarLo[i];
        if len > 0 then
          EclMenu.ConvGbString(len, strIdx)
        else
          GDVars.eclStrings[strIdx] := '';
      end;
      $81: begin
        Inc(strIdx);
        Inc(GDVars.vmBand.eclIp);
        GDVars.eclVarHi[i] := GDVars.vmBand.zone3^[GDVars.vmBand.eclIp];
        v := EclMenu.CombineBytesToWord(GDVars.eclVarLo[i], GDVars.eclVarHi[i]);
        EclMenu.DerefGbString(strIdx, v);
      end;
    end;
  end;
  Inc(GDVars.vmBand.eclIp);
end;

function GetEclVar(idx: ShortInt): Word;
var
  { Unused in this version; see the other implementations of this routine. }
  address: Word;
  { Unused in this version; see the other implementations of this routine. }
  value: Word;
  { Unused in this version; see the other implementations of this routine. }
  kind: Word;
  vHi: Byte;
  vLo: Byte;
begin
  vHi := GDVars.eclVarLo[idx];
  vLo := GDVars.eclVarHi[idx];
  case GDVars.eclVarTypes[idx] of
    0: GetEclVar := vHi;
    1, 3, $80: GetEclVar := EclMenu.ReadGbvm(vLo * 256 + vHi, GDVars.eclVarTypes[idx]);
    2, $81: GetEclVar := EclMenu.CombineBytesToWord(vHi, vLo);
  end;
end;

procedure EclInit;
begin
  GDVars.eclPicShown := False;
  GDVars.eclPicState.width := 1;
  GameIo.ZeroFill(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags));
  GDVars.monIconSlot := 8;
  GDVars.vmBand.eclIp := $8000;
  GDVars.scratchFlag := False;
  GDVars.eclStackTop := nil;
  GameIo.ZeroFill(GDVars.eclCmpFlags, SizeOf(GDVars.eclCmpFlags));
  GDVars.vmBand.zone0^.restPeriod := 0;
  GDVars.vmBand.zone0^.interruptPct := 0;
  EclMenu.LoadEclVars(1);
  GDVars.vmBand.vmRun[1] := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.vmBand.vmRun[2] := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.vmBand.vmRun[3] := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.vmBand.vmRun[4] := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.vmBand.vmRun[5] := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  if GDVars.savedGameLoaded = 0 then
    GameIo.ZeroFill(GDVars.vmBand.zone0^.areaState, SizeOf(Types.TAreaState));
end;

procedure LoadEclScript(scriptId: Byte);
var
  sizeRead: Word;
  data: Types.PBytes;
begin
  GameIo.ZeroFill(GDVars.vmBand.zone3^, SizeOf(Types.TZone3));
  GDVars.suppressDiskPrompt := 0;
  repeat
    MenuCore.ClearBottomLine;
    TextRend.DisplayString(0, 24, 10, 0, 'Loading...Please Wait');
    DaxIo.LoadDax('ECL1', '.dax', scriptId, sizeRead, data);
  until sizeRead >= 2;
  Move(data^[2], GDVars.vmBand.zone3^, sizeRead - 2);
  ZeroFree.PrefixFree(data, sizeRead);
  MenuCore.ClearBottomLine;
end;

procedure InitCreature(id: Byte; var cr, inv, eff: Pointer);
begin
  cr := nil;
  GetMem(cr, SizeOf(Types.TCharRecord));
  SaveLoad.LoadCreatureData(id, False, cr);
  inv := Types.PCharRecord(cr)^.items;
  eff := Types.PCharRecord(cr)^.effects;
end;

function MaxMonsterDist(x, y, facing: Byte): Byte;
var
  blocked: Boolean;
  dist: Byte;
begin
  dist := 0;
  blocked := False;
  MaxMonsterDist := 0;
  if GDVars.vmBand.zone0^.inDungeon = 0 then begin
    MaxMonsterDist := 2;
    GDVars.vmBand.zone0^.encounterDistLimit := 2;
  end else
    while (dist < 2) and (not blocked) do begin
      if View3D.GetWallType(x, y, facing) = 0 then begin
        Inc(dist);
        MaxMonsterDist := dist;
        case facing of
          C_Dir.NORTH: Dec(y);
          C_Dir.EAST: Inc(x);
          C_Dir.SOUTH: Inc(y);
          C_Dir.WEST: Dec(x);
        end;
      end else
        blocked := True;
    end;
end;

procedure DisplayMonster(sprId, picId, dist: Byte; var flags: Types.TMonFlags);
var
  { Unused in this version; see the other implementations of this routine. }
  headPic: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  bodyPic: Pointer;
  spriteDist: Byte;
begin
  spriteDist := dist + 1;
  if (not flags[1]) and (sprId <> $FF) then begin
    if not flags[0] then begin
      if GDVars.automapShown <> 0 then begin
        GDVars.automapShown := 0;
        GDVars.mapRedrawPending := 1;
        GDVars.mainPalReload := True;
        MapView.DisplayMapView;
      end;
      if GDVars.vmBand.zone0^.inDungeon <> 0 then begin
        Portrait.LoadAnimation('SPRIT', sprId, 1);
        flags[0] := True;
        GDVars.monSpriteShown := 1;
      end;
    end else begin
      GDVars.mapRedrawPending := 1;
      MapView.DisplayMapView;
    end;
    if GDVars.interfaceState = C_Ifc.DUNGEON then
      Portrait.Show3DSprite(spriteDist);
  end;
  if (not flags[1]) and (picId <> $FF) and ((dist = 0) or (sprId = $FF)) and
      (GDVars.interfaceState = C_Ifc.DUNGEON) then begin
    GDVars.eclPicShown := True;
    Portrait.LoadAnimation('PIC', picId, 0);
    flags[1] := True;
    Portrait.DisplayImageBuf(3, 3, True, 0);
    GDVars.mainPalReload := True;
  end;
end;

function CombineBytesToWord(lower, upper: Byte): Word;
begin CombineBytesToWord := Word(upper) * 256 + lower end;

{ Turns a 6-bit game character into ASCII: 0 to 31 become @ to _, higher codes stay as they are.
  @param(c The game character.)
  @returns(The ASCII character.) }
function DecodeGameCharacter(c: Byte): Char;
begin
  if c > 31 then
    DecodeGameCharacter := Chr(c)
  else
    DecodeGameCharacter := Chr(c + 64);
end;

{ Which zone a script address falls in: 0 = game state ($0001..$0400), 1 = the current character ($0401..$0800), 2 =
  script memory ($8000..$9DFF), 4 = none.
  @param(vmAddr The script address.)
  @returns(The zone.) }
function GbvmZone(vmAddr: Word): Byte;
begin
  GbvmZone := 4;
  if (vmAddr >= 1) and (vmAddr <= $400) then
    GbvmZone := 0
  else if (vmAddr >= $401) and (vmAddr <= $800) then
    GbvmZone := 1
  else if (vmAddr >= $8000) and (vmAddr <= $9DFF) then
    GbvmZone := 2;
end;

{ Reads the current character's record at its zone 1 address.
  @param(vmAddr The script address.)
  @param(kind The width in bytes.)
  @returns(The value.) }
function SpecialReadZ1(vmAddr: Word; kind: Byte): Word;
var
  buf: TReadBuf;
  v: Word;
begin
  v := 0;
  vmAddr := vmAddr - $401;
  Move(GDVars.currentChar^, buf, SizeOf(Types.TCharRecord));
  Move(buf[vmAddr], v, kind);
  SpecialReadZ1 := v;
end;

{ Writes the current character's record at its zone 1 address. Only the fields a script may change are written:
  memorized spells, age, base movement, coins, alignment, base armor class, magic resistance, status, side and hit
  points.
  @param(vmAddr The script address.)
  @param(value The value.) }
procedure SpecialWriteZ1(vmAddr, value: Word);
var
  i: ShortInt;
begin
  vmAddr := vmAddr - $401;
  with GDVars.currentChar^ do
    case vmAddr of
      $1E..$AA: spells[vmAddr - $1E] := Byte(value);
      $B0: age := value;
      $137: movementBase := Byte(value);
      $14B..$150: begin
        i := (vmAddr - $14B) div 2;
        coins[i] := value;
      end;
      $167: alignment := Byte(value);
      $170: acBase := Byte(value);
      $1EB: spellResistance := Byte(value);
      $1ED: begin
        status := Byte(value);
        inPlay := Byte(status = C_Status.OKAY);
      end;
      $1EF: side := Byte(value);
      $1FC: hpCur := Byte(value);
    end;
end;

procedure WriteGbvm(vmAddr, value: Word; kind: Byte);
var
  zone: Byte;
  ok: Boolean;
  width: Byte;
begin
  if kind > 1 then width := 2 else width := 1;
  zone := EclMenu.GbvmZone(vmAddr);
  case zone of
    0: begin
      case vmAddr - 1 of
        $19:
          if (GDVars.automapShown <> 0) and (value <> 0) then begin
            GDVars.automapShown := 0;
            MapView.DisplayMapView
          end;
        $33: begin GDVars.mapState.x := value; GDVars.eclPicState.dirty := 1 end;
        $34: begin GDVars.mapState.y := value; GDVars.eclPicState.dirty := 1 end;
        $10: begin
          repeat
            ok := True;
            case value of
              0: GDVars.mapState.facing := C_Dir.NORTH;
              1: GDVars.mapState.facing := C_Dir.EAST;
              2: GDVars.mapState.facing := C_Dir.SOUTH;
              3: GDVars.mapState.facing := C_Dir.WEST
            else
              ok := False;
              Dec(value, 4)
            end
          until ok = True;
          GDVars.eclPicState.dirty := 1
        end;
        $21:
          if GDVars.vmBand.zone0^.inDungeon <> value then begin
            GDVars.automapShown := 0;
            GDVars.savedInterfaceState := GDVars.interfaceState;
            if value = 0 then begin
              GDVars.interfaceState := C_Ifc.AREA_MAP;
              GDVars.loadedWallSet.id := 0
            end else
              GDVars.interfaceState := C_Ifc.DUNGEON
          end;
        $39:
          if (GDVars.vmBand.zone0^.tileSet <> value) and (value < 5) then begin
            if value = 4 then
              Sym8x8.Load8x8Set(0, 2)
            else
              Sym8x8.Load8x8Set(Byte(value), 2);
            Blit.ShadowPaletteEntries(16, 16, GDVars.mainPal);
            Blit.SetDacPalette(16, 16, GDVars.imagePal);
            GDVars.vmBand.zone0^.tileSet := value;
            CharHlp.DisplayNoncombatInterface
          end
      end;
      Move(value, GDVars.vmBand.zone0^.byAddr[vmAddr], width)
    end;
    1: EclMenu.SpecialWriteZ1(vmAddr, value);
    2: Move(value, GDVars.vmBand.zone3^[vmAddr], width)
  end
end;

function ReadGbvm(vmAddr: Word; kind: Byte): Word;
var
  zone: Byte;
  { Unused in this version; see the other implementations of this routine. }
  found: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  zoneIndex: Byte;
  value: Word;
  width: Byte;
  p: Types.PCharRecord;
  eff: Pointer;
begin
  if kind > 1 then width := 2 else width := 1;
  zone := EclMenu.GbvmZone(vmAddr);
  found := False;
  value := 0;
  case zone of
    0:
      case vmAddr - 1 of
        $0F: begin
          p := GDVars.creatureListHead;
          while (p <> nil) and not CharHlp.HasEffect(p, C_Effect.DETECT_MAGIC, eff) do
            p := p^.next;
          if p = nil then value := 0 else value := 1
        end;
        $22: value := GDVars.mapState.facing;
        $33: value := GDVars.mapState.x;
        $34: value := GDVars.mapState.y;
        $10:
          if GDVars.vmBand.zone0^.inDungeon = 0 then
            value := GDVars.mapState.facing
          else
            value := Word(GDVars.mapState.facing) div 2;
        $31: value := GDVars.mapState.wallAhead;
        $2C: value := GDVars.mapState.event
      else
        Move(GDVars.vmBand.zone0^.byAddr[vmAddr], value, width)
      end;
    1: value := EclMenu.SpecialReadZ1(vmAddr, width);
    2: Move(GDVars.vmBand.zone3^[vmAddr], value, width)
  end;
  ReadGbvm := value
end;

procedure WriteGbvmString(vmAddr: Word; s: String);
var
  zone: Byte;
  len: Byte;
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
begin
  zone := EclMenu.GbvmZone(vmAddr);
  len := Length(s);
  case zone of
    0: begin
      Move(s[1], GDVars.vmBand.zone0^.byAddr[vmAddr], len);
      GDVars.vmBand.zone0^.byAddr[vmAddr + len] := 0
    end;
    1:
      if vmAddr = $401 then GDVars.currentChar^.name := s
  end
end;

{ Decodes packed 6-bit game characters at the script's instruction pointer into a script string, four characters to
  three bytes; zero characters are dropped. The instruction pointer ends on the last byte read.
  @param(len The number of packed bytes.)
  @param(strIdx The script string to fill.) }
procedure ConvGbString(len, strIdx: Byte);
var
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  outPos: Byte;
  cur: Byte;
  prev: Byte;
  sixBitCode: Byte;
  phase: Byte;
  ch: Char;
begin
  GDVars.eclStrings[strIdx] := '';
  i := 0;
  phase := 1;
  while i < len do begin
    if phase < 4 then begin
      Inc(GDVars.vmBand.eclIp);
      prev := cur;
      cur := GDVars.vmBand.zone3^[GDVars.vmBand.eclIp];
      Inc(i);
    end;
    case phase of
      1:
        sixBitCode := cur shr 2;
      2: begin
        sixBitCode := Byte(prev shl 6) + Byte(cur shr 2);
        sixBitCode := sixBitCode shr 2;
      end;
      3: begin
        sixBitCode := Byte(prev shl 4) + Byte(cur shr 4);
        sixBitCode := sixBitCode shr 2;
      end;
      4:
        sixBitCode := cur and $3F;
    end;
    if phase < 4 then Inc(phase) else phase := 1;
    if sixBitCode <> 0 then begin
      ch := EclMenu.DecodeGameCharacter(sixBitCode);
      GDVars.eclStrings[strIdx] := GDVars.eclStrings[strIdx] + ch;
    end;
  end;
  if phase = 4 then begin
    sixBitCode := cur and $3F;
    if sixBitCode <> 0 then begin
      ch := EclMenu.DecodeGameCharacter(sixBitCode);
      GDVars.eclStrings[strIdx] := Concat(GDVars.eclStrings[strIdx], ch);
    end;
  end;
end;

{ Copies the zero-terminated string at a script address, or the current character's name, into a script string.
  @param(strIdx The string slot.)
  @param(vmAddr The script address.) }
procedure DerefGbString(strIdx: Byte; vmAddr: Word);
var
  zone: Byte;
  i: Byte;
begin
  zone := EclMenu.GbvmZone(vmAddr);
  GDVars.eclStrings[strIdx] := '';
  i := 0;
  case zone of
    0:
      while GDVars.vmBand.zone0^.byAddr[vmAddr + i] <> 0 do begin
        GDVars.eclStrings[strIdx] := GDVars.eclStrings[strIdx] + Char(GDVars.vmBand.zone0^.byAddr[vmAddr + i]);
        Inc(i);
      end;
    1:
      if vmAddr = $401 then
        GDVars.eclStrings[strIdx] := GDVars.currentChar^.name;
    2:
      while GDVars.vmBand.zone3^[vmAddr + i] <> 0 do begin
        GDVars.eclStrings[strIdx] := GDVars.eclStrings[strIdx] + Char(GDVars.vmBand.zone3^[vmAddr + i]);
        Inc(i);
      end;
  end;
end;

{ Prepares a script menu string: capitals are lower-cased, and each '~' is removed and the letter after it upper-cased
  as that option's hotkey. Note: digits are shifted along with the capitals, which turns them into letters.
  @param(menu The menu string, prepared in place.)
  @param(opts Receives the hotkeys in order.)
  @param(cnt Receives their count.) }
procedure MenuToOptions(var menu: String; var opts: Types.TStr40; var cnt: Byte);
var
  i: Byte;
begin
  opts := '';
  cnt := 0;
  for i := 1 to Length(menu) do begin
    if menu[i] in ['0'..'9', 'A'..'Z'] then
      menu[i] := Chr(Ord(menu[i]) + 32);
    if menu[i] = '~' then begin
      Delete(menu, i, 1);
      menu[i] := UpCase(menu[i]);
      opts := opts + menu[i];
      Inc(cnt);
    end;
  end;
end;

function MenuHorizontalCharacterSelect(query: Types.TStr40; menu: String; enterOk: Boolean; animate: Boolean): Byte;
var
  opts: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  idx: Byte;
  key: Byte;
  cnt: Byte;
begin
  EclMenu.MenuToOptions(menu, opts, cnt);
  MenuCore.ResetMenuSlots(cnt - 1);
  repeat
    key := Ord(MenuCore.MenuHorizontal(query, menu, True, animate));
    if GDVars.extendedKeyFlag and (GDVars.interfaceState <> C_Ifc.AREA_MAP) and
        (GDVars.vmBand.zone0^.inDungeon = 1) then begin
      CharHlp.DisplayRoster(GDVars.currentChar, False);
      ViewChar.SelectPrevNextChar(Char(key));
      CharHlp.DisplayRoster(GDVars.currentChar, True);
      key := $FF;
    end;
  until (key < cnt) or ((key = Ord(C_Keys.ESCAPE)) and enterOk);
  if key = Ord(C_Keys.ESCAPE) then
    MenuHorizontalCharacterSelect := 0
  else
    MenuHorizontalCharacterSelect := key;
end;

procedure EclVerticalMenu(query: Types.TStr40; menu: String; qCol, mCol, hlCol, ulCol: Byte; ulRow, lrRow: Word;
                          lrCol: Byte; var redraw: Boolean; var idx: Integer; var sel: Pointer);
var
  { Unused in this version; see the other implementations of this routine. }
  discard: Byte;
  opts: Types.TStr40;
  cnt: Byte;
  listArg: Types.PMenuLine absolute lrRow;
begin
  EclMenu.MenuToOptions(menu, opts, cnt);
  MenuCore.ResetMenuSlots(1);
  discard := Ord(MenuCore.MenuVertical(query, GDConsts.selectMenu, ShortInt(qCol), ShortInt(mCol), ShortInt(hlCol),
                                       ShortInt(ulCol), listArg, Boolean(lrCol), Byte(False), redraw, idx,
                                       Types.PMenuLine(sel)));
end;

procedure EclCompareStr(leftOperand, rightOperand: String);
begin
  GameIo.ZeroFill(GDVars.eclCmpFlags, SizeOf(GDVars.eclCmpFlags));
  if leftOperand = rightOperand then GDVars.eclCmpFlags[1] := 1;
  if leftOperand <> rightOperand then GDVars.eclCmpFlags[2] := 1;
  if leftOperand < rightOperand then GDVars.eclCmpFlags[3] := 1;
  if leftOperand > rightOperand then GDVars.eclCmpFlags[4] := 1;
  if leftOperand <= rightOperand then GDVars.eclCmpFlags[5] := 1;
  if leftOperand >= rightOperand then GDVars.eclCmpFlags[6] := 1;
end;

procedure EclCompareInt(leftOperand, rightOperand: Word);
begin
  GameIo.ZeroFill(GDVars.eclCmpFlags, SizeOf(GDVars.eclCmpFlags));
  if leftOperand = rightOperand then GDVars.eclCmpFlags[1] := 1;
  if leftOperand <> rightOperand then GDVars.eclCmpFlags[2] := 1;
  if leftOperand < rightOperand then GDVars.eclCmpFlags[3] := 1;
  if leftOperand > rightOperand then GDVars.eclCmpFlags[4] := 1;
  if leftOperand <= rightOperand then GDVars.eclCmpFlags[5] := 1;
  if leftOperand >= rightOperand then GDVars.eclCmpFlags[6] := 1;
end;

procedure EclGosub(varIdx: Byte);
var
  old: Pointer;
begin
  if GDVars.eclStackTop = nil then begin
    GetMem(GDVars.eclStackTop, SizeOf(Types.TGosubNode));
    GDVars.eclStackTop^.next := nil;
  end else begin
    old := GDVars.eclStackTop;
    GetMem(GDVars.eclStackTop, SizeOf(Types.TGosubNode));
    GDVars.eclStackTop^.next := old;
  end;
  GDVars.eclStackTop^.ip := GDVars.vmBand.eclIp;
  GDVars.vmBand.eclIp := EclMenu.CombineBytesToWord(GDVars.eclVarLo[varIdx], GDVars.eclVarHi[varIdx]);
end;

procedure EclMoveForward;
begin
  case GDVars.mapState.facing of
    C_Dir.NORTH:
      if GDVars.mapState.y > 0 then
        Dec(GDVars.mapState.y)
      else
        GDVars.mapState.y := 15;
    C_Dir.EAST:
      if GDVars.mapState.x < 15 then
        Inc(GDVars.mapState.x)
      else
        GDVars.mapState.x := 0;
    C_Dir.SOUTH:
      if GDVars.mapState.y < 15 then
        Inc(GDVars.mapState.y)
      else
        GDVars.mapState.y := 0;
    C_Dir.WEST:
      if GDVars.mapState.x > 0 then
        Dec(GDVars.mapState.x)
      else
        GDVars.mapState.x := 15;
  end;
  GDVars.mapState.event := View3D.GetMapEvent(GDVars.mapState.x, GDVars.mapState.y);
  GDVars.mapState.wallAhead := View3D.GetWallType(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
  GDVars.eclPicState.dirty := 1;
end;

procedure RobMoney(fraction: Real; cr: Pointer);
begin
  Types.PCharRecord(cr)^.coins[0] := Trunc(Types.PCharRecord(cr)^.coins[0] * fraction);
  Types.PCharRecord(cr)^.coins[1] := Trunc(Types.PCharRecord(cr)^.coins[1] * fraction);
  Types.PCharRecord(cr)^.coins[2] := Trunc(Types.PCharRecord(cr)^.coins[2] * fraction);
end;

procedure RobItems(chance: Byte; cr: Pointer);
var
  roll: Byte;
  item: Types.PItemRec;
  next: Types.PItemRec;
begin
  item := Types.PCharRecord(cr)^.items;
  while item <> nil do begin
    if item^.definition.weight > 255 then begin
      if chance > 90 then chance := chance - 90 else chance := 0;
    end else if item^.definition.weight > 24 then begin
      if chance > 50 then chance := chance - 50 else chance := 0;
    end;
    roll := FxEngine.RollDice(1, 100);
    next := item^.next;
    if roll <= chance then begin
      if item^.definition.equipped <> 0 then
        ViewChar.ToggleReadyItem(item);
      CharHlp.RemoveItem(cr, item);
    end;
    item := next;
  end;
end;

procedure SkipEclCmd;
begin
  GDVars.curEclOpcode := GDVars.vmBand.zone3^[GDVars.vmBand.eclIp];
  case GDVars.curEclOpcode of
    C_Ecl.OP_GOTO, C_Ecl.GOSUB, C_Ecl.LOAD_CHARACTER, C_Ecl.PICTURE, C_Ecl.PRINT, C_Ecl.PRINT_CLEAR,
        C_Ecl.JOURNAL_ENTRY, C_Ecl.NEW_ECL,
    C_Ecl.PLAY_SOUND, C_Ecl.CALL, C_Ecl.FIND_ITEM, C_Ecl.CLOCK, C_Ecl.ADD_NPC, C_Ecl.OP_PROGRAM,
        C_Ecl.WHO, C_Ecl.STORE, C_Ecl.HAS_EFFECT, C_Ecl.TAKE_ITEMS:
      EclMenu.LoadEclVars(1);
    C_Ecl.COMPARE, C_Ecl.OP_RANDOM, C_Ecl.SAVE, C_Ecl.INPUT_NUMBER, C_Ecl.INPUT_STRING, C_Ecl.AWARD_EXPERIENCE,
        C_Ecl.LOAD_FILES, C_Ecl.FIND_NPC:
      EclMenu.LoadEclVars(2);
    C_Ecl.ADD..C_Ecl.MULTIPLY, C_Ecl.LOAD_MONSTER, C_Ecl.ROB, C_Ecl.GET_TABLE, C_Ecl.OP_AND,
        C_Ecl.OP_OR, C_Ecl.SAVE_TABLE, C_Ecl.SPELL:
      EclMenu.LoadEclVars(3);
    C_Ecl.SETUP_MONSTER, C_Ecl.COMPARE_AND:
      EclMenu.LoadEclVars(4);
    C_Ecl.DAMAGE:
      EclMenu.LoadEclVars(5);
    $1E:
      EclMenu.LoadEclVars(6);
  else
    Inc(GDVars.vmBand.eclIp);
  end;
end;

procedure EclInflictDamage(dmg: Word; cr: Pointer);
var
  { Unused in this version; see the other implementations of this routine. }
  hpBefore: Integer;
  finalMsg: String[80];
  dmgStr: String[3];
  pause: Boolean;
begin
  if Types.PCharRecord(cr)^.inPlay <> 0 then begin
    pause := False;
    Str(dmg, dmgStr);
    if Types.PCharRecord(cr)^.hpCur + 10 < dmg then
      finalMsg := Concat('  ', Types.PCharRecord(cr)^.name, ' dies. ')
    else
      finalMsg := Concat('  ', Types.PCharRecord(cr)^.name, ' is hit FOR ', dmgStr, ' points of Damage.');
    if GDVars.textCursorRow > 22 then begin
      GDVars.textCursorRow := 17;
      pause := True;
      TextRend.DisplayAndPause(15, 0, GDConsts.pressButtonPrompt);
    end else
      pause := False;
    GDVars.textCursorCol := 38;
    TextRend.DisplayMessageWindow(1, 17, 38, 22, 15, 0, pause, finalMsg);
    CharHlp.InflictDamage(cr, dmg);
    TextRend.ClearRect(17, 1, 38, 15);
    CharHlp.DisplayParty(GDVars.currentChar);
  end;
end;

procedure UpdateEclDisplay;
begin
  GDVars.mapState.event := View3D.GetMapEvent(GDVars.mapState.x, GDVars.mapState.y);
  if GDVars.eclPicShown or (GDVars.monSpriteShown <> 0) or (GDVars.eclPicState.width <> 0) or
      (GDVars.eclPicState.dirty <> 0) or (GDVars.monsterDrawPending <> 0) then begin
    GameIo.ZeroFill(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags));
    GDVars.mapRedrawPending := 1;
    MapView.DisplayMapView;
    CharHlp.PrintMiscInfo;
    GDVars.monsterDrawPending := 0;
    GDVars.eclPicState.width := 0;
    GDVars.eclPicState.dirty := 0;
    GDVars.eclPicShown := False;
    GDVars.monSpriteShown := 0;
    GDVars.mapState.wallAhead := View3D.GetWallType(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
  end;
end;

procedure CharFightsAlone;
var
  mirrorId: Byte;
  limit: Byte;
  picId: Byte;
  counter: Byte;
  p: Types.PCharRecord;
  clone2: Types.PCharRecord;
  cr: Pointer;
  savedCurChar: Types.PCharRecord;
  inv: Pointer;
  oldItem: Pointer;
  invHead: Pointer;
  eff: Pointer;
  oldEff: Pointer;
  effHead: Pointer;
begin
  savedCurChar := GDVars.currentChar;
  counter := 1;
  p := nil;
  clone2 := nil;
  mirrorId := GDConsts.mirrorMonId[GDVars.vmBand.zone0^.tileSet];
  EclMenu.InitCreature(mirrorId, cr, inv, eff);
  Types.PCharRecord(cr)^.status := 9;
  Types.PCharRecord(cr)^.npc := Types.PCharRecord(cr)^.npc or $32;
  invHead := inv;
  effHead := eff;
  limit := 10;
  picId := GDConsts.mirrorPicId[GDVars.vmBand.zone0^.tileSet];
  p := GDVars.creatureListHead;
  MapTiles.LoadIconAnim('CPIC', picId, GDVars.monIconSlot);
  Types.PCharRecord(cr)^.orderNumber := GDVars.monIconSlot;
  while p^.next <> nil do p := p^.next;
  p^.next := Types.PCharRecord(cr);
  p := p^.next;
  p^.next := nil;
  Inc(GDVars.addedMonsterCount);
  Inc(counter);
  while (counter <= limit) and (GDVars.addedMonsterCount < 63) do begin
    GetMem(clone2, SizeOf(Types.TCharRecord));
    p^.next := clone2;
    p := p^.next;
    p^ := Types.PCharRecord(cr)^;
    p^.next := nil;
    p^.effects := nil;
    p^.items := nil;
    Inc(counter);
    Inc(GDVars.addedMonsterCount);
    while inv <> nil do begin
      if p^.items = nil then begin
        GetMem(p^.items, SizeOf(Types.TItemRec));
        p^.items^ := Types.PItemRec(inv)^;
        p^.items^.next := nil;
      end else begin
        oldItem := p^.items;
        GetMem(p^.items, SizeOf(Types.TItemRec));
        p^.items^ := Types.PItemRec(inv)^;
        p^.items^.next := oldItem;
      end;
      inv := Types.PItemRec(inv)^.next;
    end;
    inv := invHead;
    while eff <> nil do begin
      if p^.effects = nil then begin
        GetMem(p^.effects, SizeOf(Types.TEffectRec));
        p^.effects^ := Types.PEffectRec(eff)^;
        p^.effects^.next := nil;
      end else begin
        oldEff := p^.effects;
        GetMem(p^.effects, SizeOf(Types.TEffectRec));
        p^.effects^ := Types.PEffectRec(eff)^;
        p^.effects^.next := oldEff;
      end;
      eff := Types.PEffectRec(eff)^.next;
    end;
    eff := effHead;
  end;
  Inc(GDVars.monIconSlot);
  GDVars.currentChar := savedCurChar;
end;

procedure EclBuildRandomScroll(var item: Types.TItemDef);
var
  roll: Byte;
  matched: Boolean;
begin
  GameIo.ZeroFill(item, SizeOf(item));
  with item do begin
    itemType := 39;
    nameIds[3] := 40;
    nameIds[2] := 39;
    nameIds[1] := 102;
    plus := 1;
    weight := 1;
    value := 3000;
    for GDVars.scratchIndex := 1 to 3 do begin
      matched := False;
      repeat
        roll := FxEngine.RollDice(1, 126);
        if GDConsts.spellTable[roll].castClass = C_Spell.MAGIC_USER_LIST then matched := True;
      until matched;
      scrollSpells[GDVars.scratchIndex] := roll;
    end;
  end;
end;

begin
end.
