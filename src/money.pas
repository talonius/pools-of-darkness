{ Party funds: the money pool, sharing and taking money, and appraising gems and jewelry. }
{$O+,F+}
unit Money;

interface

uses Crt, Types, GDConsts, GDVars, GameIo, Border, TextRend, FxEngine, CharHlp, MenuCore, C_Keys, C_Ifc,
  C_Npc;

{ Tells whether more weight would overload a character.
  @param(p Character to test.)
  @param(w Weight to add.)
  @param(takable Receives what it can still take when it would be overloaded (0 if already over), otherwise 0.)
  @returns(True when the weight would overload it.) }
function CheckOverload(p: Types.PCharRecord; w: LongInt; var takable: LongInt): Boolean;

{ Moves the money of each player character, and of each NPC with the value $B3, into the pool, taking its weight off,
  and marks the pool as holding money. }
procedure PoolMoney;

{ Divides the pool. Each money type's share is the pool divided by CountPoolers, the remainder held back. The first pass
  gives each member with an NPC value below $80, highest money type first, its share and one coin of the remainder while
  they fit, or as much of the share as it can carry, the rest going back to the remainder. The second pass hands what is
  left, type by type, to each member in list order as far as it can carry, and the rest stays in the pool, which is
  marked as holding money when anything stays. Note: the divisor counts animated members ($B3), whom the first pass
  skips, and not NPC values 1 to $7F, whom it pays. }
procedure ShareMoney;

{ Lists the money in the pool and lets the current character take an amount of the chosen type, until the pool is empty
  or the player leaves. Note: leaving the menu without choosing does not free the list it was built from. }
procedure TakeMoneyMenu;

{ Finds the money type named by the first non-blank letter of a string.
  @param(s The string, a money menu line.)
  @param(typeName Receives the type's name.)
  @returns(Platinum 0, Gems 1, Jewelry 2. Note: any other letter leaves it undefined.) }
function ParseMoneyType(s: String; var typeName: String): ShortInt;

{ Shows a question on the bottom row and reads a number up to the largest accepted: digits are echoed in white, a larger
  number is cut to the largest, and backspace takes off the last digit. Enter or Escape ends the input.
  @param(max The largest number accepted.)
  @param(query The question shown.)
  @param(color The question's color.)
  @returns(The number, or 0 on Escape.) }
function InputNumberMax(max: LongInt; query: Types.TStr40; color: Byte): LongInt;

{ Moves coins of one type, with their weight, from one character to another when the receiver can carry them; otherwise
  shows "Overloaded", pauses and flushes the keyboard.
  @param(giver The character giving the coins.)
  @param(rcv The character receiving them.)
  @param(qty The amount.)
  @param(mType The money type.) }
procedure TradeMoney(var giver, rcv: Types.PCharRecord; qty: LongInt; mType: ShortInt);

{ Takes money from a character; in the loot screen, in shops and temples and in the vault it goes into the pool,
  elsewhere it is lost.
  @param(p The character.)
  @param(qty The amount.)
  @param(mType The money type.) }
procedure DropMoney(p: Types.PCharRecord; qty: LongInt; mType: ShortInt);

{ Reports whether the pool holds money and whether the treasure list holds items.
  @param(hasMoney Receives True when the pool holds money.)
  @param(items Receives True when the treasure list holds items.) }
procedure DetermineTreasure(var hasMoney, items: Boolean);

{ Appraises the current character's gems and jewelry one piece at a time. A piece can be kept as an item when the
  character has room and fewer than 16 items, or sold for its value in platinum. Note: a kept piece is lost when the
  character carries no items, because it is linked to a local pointer rather than to the item list.
  @param(ok Receives False when there was nothing to appraise, True otherwise.) }
procedure AppraiseMenu(var ok: Boolean);

implementation

{ Gives the most weight a character can carry: its weight allowance plus 1500.
  @param(p The character.)
  @returns(The capacity.) }
function CarryingCapacity(p: Types.PCharRecord): Word;
begin
  CarryingCapacity := CharHlp.WeightAllowance(p) + 1500;
end;

{ Takes weight off a character's encumbrance.
  @param(p The character.)
  @param(w The weight removed.) }
procedure RemoveWeight(p: Types.PCharRecord; w: LongInt);
begin
  p^.encumbrance := p^.encumbrance - w;
end;

{ Adds weight to a character's encumbrance.
  @param(p The character.)
  @param(w The weight added.) }
procedure AddWeight(p: Types.PCharRecord; w: LongInt);
begin
  p^.encumbrance := p^.encumbrance + w;
end;

function CheckOverload(p: Types.PCharRecord; w: LongInt; var takable: LongInt): Boolean;
var cap: Word;
begin
  cap := Money.CarryingCapacity(p);
  if p^.encumbrance + w > cap then begin
    CheckOverload := True;
    if p^.encumbrance > cap then
      takable := 0
    else
      takable := cap - p^.encumbrance;
  end else begin
    CheckOverload := False;
    takable := 0;
  end;
end;

{ Gives platinum to the current character; what does not fit goes to the pooled money, with a message on the bottom row.
  @param(qty The platinum pieces.) }
procedure GivePlatinum(qty: Word);
var takable: LongInt;
begin
  if Money.CheckOverload(GDVars.currentChar, qty, takable) then begin
    CharHlp.PrintBottomLine('Overloaded.  Money will be put in Pool.');
    Inc(GDVars.currentChar^.coins[0], takable);
    Money.AddWeight(GDVars.currentChar, takable);
    Inc(GDVars.moneyPool[0], qty - takable);
  end else begin
    Inc(GDVars.currentChar^.coins[0], qty);
    Money.AddWeight(GDVars.currentChar, qty);
  end;
end;

function InputNumberMax(max: LongInt; query: Types.TStr40; color: Byte): LongInt;
var
  col: Byte;
  { Unused in this version; see the other implementations of this routine. }
  questionLength: Byte;
  qLen: Byte;
  maxStr: String[5];
  s: String[6];
  ch: Char;
  v: LongInt;
  code: Integer;
  n: LongInt;
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
  TextRend.DisplayString(0, 24, color, 0, query);
  qLen := Length(query);
  col := qLen;
  Str(max, maxStr);
  s := '';
  repeat
    ch := GameIo.ReadGameKey;
    case ch of
      '0'..'9': begin
        s := Concat(s, ch);
        Val(s, v, code);
        if v <= max then
          Inc(col)
        else begin
          s := maxStr;
          col := qLen + Length(maxStr);
        end;
        TextRend.DisplayString(qLen, 24, White, 0, s);
      end;
      C_Keys.BACKSPACE: if Length(s) > 0 then begin
        s := Copy(s, 1, Length(s) - 1);
        Dec(col);
        TextRend.PrintSpaces(col, 24, Black, 1);
      end;
    end;
  until (ch = C_Keys.ENTER) or (ch = C_Keys.ESCAPE);
  TextRend.PrintSpaces(0, 24, Black, 40);
  if ch = C_Keys.ESCAPE then
    n := 0
  else
    Val(s, n, code);
  InputNumberMax := n;
end;

procedure TradeMoney(var giver, rcv: Types.PCharRecord; qty: LongInt; mType: ShortInt);
begin
  if rcv^.encumbrance + qty <= Money.CarryingCapacity(rcv) then begin
    giver^.coins[mType] := giver^.coins[mType] - qty;
    Money.RemoveWeight(giver, qty);
    rcv^.coins[mType] := rcv^.coins[mType] + qty;
    Money.AddWeight(rcv, qty);
  end else begin
    CharHlp.PrintBottomLine('Overloaded');
    TextRend.PauseOnly;
    GameIo.FlushKeys;
  end;
end;

procedure PoolMoney;
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  coinIndex: Byte;
  i: ShortInt;
begin
  p := GDVars.creatureListHead;
  GDVars.poolHasMoney := True;
  while p <> nil do begin
    if (p^.npc = 0) or (p^.npc = 179) then begin
      for i := 0 to 2 do begin
        Inc(GDVars.moneyPool[i], p^.coins[i]);
        Money.RemoveWeight(p, p^.coins[i]);
      end;
      GameIo.ZeroFill(p^.coins, SizeOf(p^.coins));
    end;
    p := p^.next;
  end;
end;

{ Counts the party members and animated creatures (NPC value 0 or $B3).
  @returns(The count.) }
function CountPoolers: Byte;
var
  p: Types.PCharRecord;
  n: Byte;
begin
  p := GDVars.creatureListHead;
  n := 0;
  while p <> nil do begin
    if (p^.npc = 0) or (p^.npc = 179) then
      Inc(n);
    p := p^.next;
  end;
  CountPoolers := n;
end;

procedure ShareMoney;
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  receiver: Types.PCharRecord;
  cnt: Byte;
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
  takable: LongInt;
  share: array[0..2] of Word;
  rem: array[0..2] of Word;
  i: ShortInt;
begin
  p := GDVars.creatureListHead;
  done := False;
  cnt := Money.CountPoolers;
  GameIo.ZeroFill(share, SizeOf(share));
  GameIo.ZeroFill(rem, SizeOf(rem));
  for i := 0 to 2 do
    if GDVars.moneyPool[i] > 0 then begin
      share[i] := GDVars.moneyPool[i] div cnt;
      rem[i] := GDVars.moneyPool[i] mod cnt;
    end else begin
      share[i] := 0;
      rem[i] := 0;
    end;
  while p <> nil do begin
    if p^.npc < C_Npc.NON_PLAYER then
      for i := 2 downto 0 do
        if not Money.CheckOverload(p, share[i], takable) then begin
          p^.coins[i] := share[i] + p^.coins[i];
          Money.AddWeight(p, share[i]);
          if rem[i] > 0 then
            if not Money.CheckOverload(p, 1, takable) then begin
              p^.coins[i] := p^.coins[i] + 1;
              Money.AddWeight(p, 1);
              Dec(rem[i]);
            end;
        end else begin
          p^.coins[i] := p^.coins[i] + takable;
          rem[i] := rem[i] + share[i] - takable;
          Money.AddWeight(p, takable);
        end;
    p := p^.next;
  end;
  for i := 2 downto 0 do
    if rem[i] > 0 then begin
      p := GDVars.creatureListHead;
      while p <> nil do begin
        takable := Money.CarryingCapacity(p) - p^.encumbrance;
        if takable > 0 then
          if rem[i] > takable then begin
            p^.coins[i] := p^.coins[i] + takable;
            Money.AddWeight(p, takable);
            rem[i] := rem[i] - takable;
          end else begin
            p^.coins[i] := p^.coins[i] + rem[i];
            Money.AddWeight(p, rem[i]);
            rem[i] := 0;
          end;
        p := p^.next;
      end;
    end;
  GDVars.poolHasMoney := False;
  for i := 0 to 2 do begin
    GDVars.moneyPool[i] := rem[i];
    if GDVars.moneyPool[i] <> 0 then
      GDVars.poolHasMoney := True;
  end;
end;

procedure DropMoney(p: Types.PCharRecord; qty: LongInt; mType: ShortInt);
begin
  p^.coins[mType] := p^.coins[mType] - qty;
  Money.RemoveWeight(p, qty);
  if (GDVars.interfaceState = C_Ifc.LOOT) or (GDVars.interfaceState = C_Ifc.IN_SHOP)
     or (GDVars.interfaceState = C_Ifc.IN_VAULT) then
    GDVars.moneyPool[mType] := GDVars.moneyPool[mType] + qty;
end;

{ Moves money from the pool to a character, at most what the pool holds; an amount that would overload the character is
  refused whole: "Overloaded" is shown, the game pauses and the keyboard is flushed. Note: the overload test uses the
  amount asked for, before it is cut down to what the pool holds.
  @param(p The character.)
  @param(qty The amount asked for.)
  @param(mType The money type.) }
procedure TakeMoney(p: Types.PCharRecord; qty: LongInt; mType: ShortInt);
var takable: LongInt;
begin
  if Money.CheckOverload(p, qty, takable) then begin
    CharHlp.PrintBottomLine('Overloaded');
    TextRend.PauseOnly;
    GameIo.FlushKeys;
  end else begin
    if qty > GDVars.moneyPool[mType] then
      qty := GDVars.moneyPool[mType];
    GDVars.moneyPool[mType] := GDVars.moneyPool[mType] - qty;
    p^.coins[mType] := p^.coins[mType] + qty;
    Money.AddWeight(p, qty);
  end;
end;

function ParseMoneyType(s: String; var typeName: String): ShortInt;
var i: Byte;
begin
  i := 1;
  while s[i] = ' ' do Inc(i);
  case s[i] of
    'G': begin
      ParseMoneyType := 1;
      typeName := 'Gems ';
    end;
    'P': begin
      typeName := 'Platinum ';
      ParseMoneyType := 0;
    end;
    'J': begin
      typeName := 'Jewelry ';
      ParseMoneyType := 2;
    end;
  end;
end;

procedure TakeMoneyMenu;
var
  i: ShortInt;
  mType: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  weight: Word;
  p: Types.PItemRec;
  sel: Types.PItemRec;
  save: Types.PItemRec;
  cnt: Word;
  idx: Integer;
  numStr: String;
  n: Word;
  exitF: Boolean;
  redraw: Boolean;
  ch: Char;
begin
  Border.DrawWindowFrame(1);
  idx := 0;
  repeat
    redraw := True;
    p := nil;
    sel := nil;
    for i := 0 to 2 do
      if GDVars.moneyPool[i] > 0 then begin
        Inc(cnt);
        if p = nil then begin
          GetMem(p, SizeOf(Types.TMenuLine));
          p^.next := nil;
        end else begin
          sel := p;
          GetMem(p, SizeOf(Types.TMenuLine));
          p^.next := sel;
        end;
        Str(GDVars.moneyPool[i], numStr);
        p^.name := GDConsts.moneyNameTable[i] + ' ' + numStr;
        p^.inUse := 0;
      end;
    sel := p;
    save := p;
    MenuCore.ResetMenuSlots(1);
    ch := MenuCore.MenuVertical(GDConsts.selectCoinTypePrompt, GDConsts.selectMenu, 2, 2, 15, 8, Types.PMenuLine(p),
                                True, 0, redraw, idx, Types.PMenuLine(sel));
    if (sel = nil) or (ch = #1) or (GDVars.extendedKeyFlag and (ch = C_Keys.ESCAPE)) then
      exitF := True
    else begin
      exitF := False;
      mType := Money.ParseMoneyType(sel^.name, numStr);
      if mType = 1 then
        numStr := GDConsts.howManyPrompt + numStr + GDConsts.willYouTakePrompt
      else
        numStr := GDConsts.howMuchPrompt + numStr + GDConsts.willYouTakePrompt;
      n := Money.InputNumberMax(GDVars.moneyPool[mType], numStr, 10);
      Money.TakeMoney(GDVars.currentChar, n, mType);
      MenuCore.FreeStringList(Types.PMenuLine(save));
      GDVars.poolHasMoney := False;
      exitF := True;
      for i := 0 to 2 do
        if GDVars.moneyPool[i] > 0 then begin
          GDVars.poolHasMoney := True;
          exitF := False;
        end;
    end;
  until exitF;
end;

procedure DetermineTreasure(var hasMoney, items: Boolean);
var i: ShortInt;
begin
  hasMoney := False;
  items := False;
  for i := 0 to 2 do
    if GDVars.moneyPool[i] <> 0 then hasMoney := True;
  if GDVars.treasureList <> nil then items := True;
end;

procedure AppraiseMenu(var ok: Boolean);
var
  gemStr: String[40];
  jwlStr: String[40];
  ch: Char;
  { Unused in this version; see the other implementations of this routine. }
  menu: String[40];
  { Unused in this version; see the other implementations of this routine. }
  actionStr: String[40];
  r: Byte;
  value: LongInt;
  takable: LongInt;
  p: Types.PItemRec;
  gem: Types.PItemRec;
  exitF: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  extendedKey: Byte;
  mustSell: Boolean;
  ext: Boolean;
begin
  ok := True;
  if (GDVars.currentChar^.coins[1] = 0) and (GDVars.currentChar^.coins[2] = 0) then begin
    CharHlp.PrintBottomLine('No Gems or Jewelry');
    ok := False;
  end else
    repeat
      if (GDVars.currentChar^.coins[1] = 0) and (GDVars.currentChar^.coins[2] = 0) then
        exitF := True
      else begin
        exitF := False;
        Str(GDVars.currentChar^.coins[1], gemStr);
        Str(GDVars.currentChar^.coins[2], jwlStr);
        gemStr := GDConsts.gemsPrompt + gemStr;
        jwlStr := GDConsts.jewelryPrompt + jwlStr;
        TextRend.ClearRect(1, 1, 38, 22);
        CharHlp.DisplayCreatureName(GDVars.currentChar, 1, 1, False);
        TextRend.DisplayString(1, 7, White, 0, GDConsts.fineCollectionMsg);
        TextRend.DisplayString(1, 9, White, 0, gemStr);
        TextRend.DisplayString(1, 10, White, 0, jwlStr);
        FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
        ext := False;
        if GDVars.currentChar^.coins[1] <> 0 then MenuCore.AppendSlot(0, Byte(ext));
        if GDVars.currentChar^.coins[2] <> 0 then MenuCore.AppendSlot(1, Byte(ext));
        MenuCore.AppendSlot(2, Byte(ext));
        ch := MenuCore.MenuHorizontal(GDConsts.appraisePrompt, GDConsts.gemsJewelryMenu, True, False);
        if GDVars.extendedKeyFlag and (ch = C_Keys.ESCAPE) then ch := #2;
        case ch of
          #0: if GDVars.currentChar^.coins[1] <> 0 then begin
              Dec(GDVars.currentChar^.coins[1]);
              r := FxEngine.RollDice(1, 100);
              case r of
                1..25: value := 5;
                26..50: value := 25;
                51..70: value := 50;
                71..90: value := 250;
                91..99: value := 500;
                100: value := 2500;
              end;
              Str(value, gemStr);
              gemStr := GDConsts.gemValuedAtMsg + gemStr + ' platinum.';
              TextRend.DisplayString(1, 12, White, 0, gemStr);
              FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
              GDVars.menuSlotTable[0].choiceIndex := 0;
              if Money.CheckOverload(GDVars.currentChar, 1, takable) or
                  (GDVars.currentChar^.numberOfItems >= 16) then begin
                mustSell := True;
              end else begin
                GDVars.menuSlotTable[1].choiceIndex := 1;
                mustSell := False;
              end;
              ch := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.sellKeepMenu, False, False);
              if (ch = #1) and not mustSell then begin
                gem := GameIo.AllocSlot;
                GameIo.ZeroFill(gem^, SizeOf(Types.TItemRec));
                gem^.next := nil;
                gem^.definition.equipped := 0;
                gem^.definition.nameIds[3] := 122;
                gem^.definition.nameIds[2] := 0;
                gem^.definition.nameIds[1] := 0;
                gem^.definition.itemType := 47;
                gem^.definition.value := value;
                gem^.definition.weight := 1;
                gem^.definition.unidMask := 0;
                p := GDVars.currentChar^.items;
                if p = nil then p := gem
                else begin
                  while p^.next <> nil do p := p^.next;
                  p^.next := gem;
                end;
              end else
                Money.GivePlatinum(value);
            end;
          #1: if GDVars.currentChar^.coins[2] <> 0 then begin
              Dec(GDVars.currentChar^.coins[2]);
              r := FxEngine.RollDice(1, 100);
              case r of
                1..10: value := Trunc(Random(450)) + 50;
                11..20: value := Trunc(Random(500)) + 100;
                21..40: value := Trunc(Random(750)) + 150;
                41..50: value := Trunc(Random(1250)) + 250;
                51..70: value := Trunc(Random(2500)) + 500;
                71..90: value := Trunc(Random(3000)) + 1000;
                91..100: value := Trunc(Random(5000)) + 1000;
              end;
              Str(value, jwlStr);
              jwlStr := GDConsts.jewelValuedAtMsg + jwlStr + ' platinum.';
              TextRend.DisplayString(1, 12, White, 0, jwlStr);
              FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
              GDVars.menuSlotTable[0].choiceIndex := 0;
              if Money.CheckOverload(GDVars.currentChar, 1, takable) or (GDVars.currentChar^.numberOfItems >= 16) then
                mustSell := True
              else begin GDVars.menuSlotTable[1].choiceIndex := 1; mustSell := False end;
              ch := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.sellKeepMenu, False, False);
              if (ch = #1) and not mustSell then begin
                gem := GameIo.AllocSlot;
                GameIo.ZeroFill(gem^, SizeOf(Types.TItemRec));
                gem^.next := nil;
                gem^.definition.equipped := 0;
                gem^.definition.nameIds[3] := 123;
                gem^.definition.nameIds[2] := 0;
                gem^.definition.nameIds[1] := 0;
                gem^.definition.itemType := 47;
                gem^.definition.value := value;
                gem^.definition.weight := 1;
                gem^.definition.unidMask := 0;
                p := GDVars.currentChar^.items;
                if p = nil then p := gem
                else begin while p^.next <> nil do p := p^.next; p^.next := gem end;
              end else
                Money.GivePlatinum(value);
            end;
          #2: exitF := True;
        end;
        CharHlp.RecalcStats(GDVars.currentChar);
      end;
    until exitF;
end;

begin
end.
