{ General-store purchasing and party-fund management.

  ShopMainMenu draws the noncombat store screen and offers Buy, View, Take, Pool, Share, Appraise, and Exit. Entering a
  store clears the pooled-money account; the player must explicitly Pool the party's funds before pooled money can pay
  for a purchase. Leaving with money still pooled asks for confirmation.

  ShopBuyMenu shows the store inventory as a priced vertical menu. The price setting scales an item's value from
  one-sixteenth through eight times its base value, after which quantity is applied and the result is clamped to at
  least one. Payment comes from the current character's own funds first, then from the pool.

  GiveItemCopyToCreature checks encumbrance, copies the item into a new inventory record, links it into the character's
  item chain, and recalculates derived statistics. }
{$O+,F+,S-,R-,V-,B-,I-}
unit Shop;

interface

{ Runs a store: the money pool starts empty and the store's goods are the treasure item list. The menu offers Buy, View,
  Pool, Appraise and Exit, plus Take and Share while the pool holds money; the up and down arrow keys change the current
  character; leaving with money in the pool asks first. }
procedure ShopMainMenu;

{ Appends a copy of an item to the current character's items, joins a stackable item into matching stacks and
  recalculates the character's stats; a character who cannot carry it is reported as overloaded instead. Note: when the
  character had no items, the stack is joined through a pointer that was never set.
  @param(sourceItem The item to copy.)
  @param(overloaded Set when the character cannot carry the item, cleared otherwise.) }
procedure GiveItemCopyToCreature(sourceItem: Pointer; var overloaded: Boolean);

implementation

uses Crt, ViewChar, Money, CharHlp, MenuCore, Border, GameIo, TextRend, Types, GDConsts, GDVars,
  C_Keys, C_Ifc;

const
  { GDVars.vmBand.zone0^.priceScale values: the store price as a fraction or multiple of an item's value }
  PRICE_SCALE_SIXTEENTH = 1;
  PRICE_SCALE_EIGHTH = 2;
  PRICE_SCALE_QUARTER = 4;
  PRICE_SCALE_HALF = 8;
  PRICE_SCALE_BASE = 16;
  PRICE_SCALE_DOUBLE = 32;
  PRICE_SCALE_QUADRUPLE = 64;
  PRICE_SCALE_OCTUPLE = 128;
  { the store menu's choices }
  STORE_OPTION_BUY = #0;
  STORE_OPTION_VIEW = #1;
  STORE_OPTION_TAKE = #2;
  STORE_OPTION_POOL = #3;
  STORE_OPTION_SHARE = #4;
  STORE_OPTION_APPRAISE = #5;
  STORE_OPTION_EXIT = #6;

{ Shows the current character's funds and the pooled funds on rows 20 and 21. }
procedure DisplayShopMoney;
var
  fundsText: String[10];
begin
  Str(GDVars.currentChar^.coins[0], fundsText);
  TextRend.RightAlignString(fundsText, 10);
  TextRend.DisplayString(1, 20, White, Black, 'Personal funds:' + fundsText);
  Str(GDVars.moneyPool[0], fundsText);
  TextRend.RightAlignString(fundsText, 10);
  TextRend.DisplayString(1, 21, White, Black, 'Pooled funds:  ' + fundsText);
end;

{ Writes each item's price, right-aligned, into its name, runs the vertical menu over the shop's items and restores the
  names. Price level 1, 2, 4 or 8 divides the value by 16, 8, 4 or 2; $20, $40 or $80 multiplies it by 2, 4 or 8;
  anything else is the value. A stack costs its quantity times as much and nothing costs less than 1.
  @param(choice Receives the key that ended the menu.)
  @param(chosen Receives the item under the cursor when the menu ended.)
  @param(selectedNode The menu's cursor row, kept between calls.)
  @param(listIndex The menu's scroll position, kept between calls.) }
procedure ShopBuyItemSelection(var choice: Char; var chosen: Types.PItemRec; var selectedNode: Types.PMenuLine;
                               var listIndex: Integer);
var
  menuHead: Types.PMenuLine;
  node: Types.PItemRec;
  priceStr: String[16];
  priceLine: String[30];
  textLength: Byte;
  characterIndex: Byte;
  scaledPrice: Word;
begin
  node := GDVars.treasureList;
  while node <> nil do begin
    priceLine := GDConsts.blankPriceLine;
    if node^.definition.value = 0 then
      node^.definition.value := 1;
    case GDVars.vmBand.zone0^.priceScale of
      Shop.PRICE_SCALE_SIXTEENTH: scaledPrice := node^.definition.value div 16;
      Shop.PRICE_SCALE_EIGHTH: scaledPrice := node^.definition.value div 8;
      Shop.PRICE_SCALE_QUARTER: scaledPrice := node^.definition.value div 4;
      Shop.PRICE_SCALE_HALF: scaledPrice := node^.definition.value div 2;
      Shop.PRICE_SCALE_DOUBLE: scaledPrice := node^.definition.value shl 1;
      Shop.PRICE_SCALE_QUADRUPLE: scaledPrice := node^.definition.value * 4;
      Shop.PRICE_SCALE_OCTUPLE: scaledPrice := node^.definition.value * 8;
      else scaledPrice := node^.definition.value;
    end;
    if node^.definition.quantity > 1 then
      scaledPrice := node^.definition.quantity * scaledPrice;
    if scaledPrice = 0 then
      scaledPrice := 1;
    Str(scaledPrice, priceStr);
    textLength := Length(priceStr);
    for characterIndex := 1 to textLength do
      priceLine[30 - textLength + characterIndex] := priceStr[characterIndex];
    textLength := Length(node^.name);
    for characterIndex := 1 to textLength do
      priceLine[characterIndex] := node^.name[characterIndex];
    node^.name := priceLine;
    node^.name[0] := #30;
    node := node^.next;
  end;
  menuHead := Types.PMenuLine(GDVars.treasureList);
  GDVars.horizMenuChoice := 0;
  MenuCore.ResetMenuSlots(0);
  choice := MenuCore.MenuVertical(GDConsts.itemsPrompt, GDConsts.buyMenu, 1, 1, 38,
                                  18, menuHead, True, 0,
                                  GDVars.menuNeedsRedraw, listIndex, selectedNode);
  chosen := Types.PItemRec(selectedNode);
  node := GDVars.treasureList;
  while node <> nil do begin
    CharHlp.PrintItemString(nil, node, 0, 0, False, False);
    node := node^.next;
  end;
end;

procedure GiveItemCopyToCreature(sourceItem: Pointer; var overloaded: Boolean);
var
  node: Types.PItemRec;
  tailNode: Types.PItemRec;
begin
  if ViewChar.CannotCarryItem(GDVars.currentChar, 1, sourceItem) then begin
    CharHlp.PrintBottomLine('OverLoaded');
    overloaded := True;
    Exit;
  end;
  overloaded := False;
  node := GDVars.currentChar^.items;
  if node = nil then begin
    node := GameIo.AllocSlot;
    node^ := Types.PItemRec(sourceItem)^;
    node^.next := nil;
    GDVars.currentChar^.items := node;
  end else begin
    while node^.next <> nil do
      node := node^.next;
    tailNode := GameIo.AllocSlot;
    tailNode^ := Types.PItemRec(sourceItem)^;
    tailNode^.next := nil;
    node^.next := tailNode;
  end;
  if Types.PItemRec(sourceItem)^.definition.quantity > 0 then
    ViewChar.JoinItem(tailNode);
  CharHlp.RecalcStats(GDVars.currentChar);
end;

{ The Buy menu: price the chosen item and pay for it from the character's funds, then from the pool, until Escape. }
procedure ShopBuyMenu;
var
  chosen: Types.PItemRec;
  choice: Char;
  exitFlag: Boolean;
  scaledPrice: Word;
  personalFunds: Word;
  pooledFunds: LongInt;
  overloaded: Boolean;
  selectedNode: Types.PMenuLine;
  listIndex: Integer;
begin
  chosen := nil;
  selectedNode := Types.PMenuLine(GDVars.treasureList);
  listIndex := 0;
  Border.DrawWindowFrame(0);
  GDVars.menuNeedsRedraw := True;
  repeat
    Shop.DisplayShopMoney;
    Shop.ShopBuyItemSelection(choice, chosen, selectedNode, listIndex);
    if (choice = C_Keys.ESCAPE) and GDVars.extendedKeyFlag then
      exitFlag := True
    else begin
      exitFlag := False;
      { Note: unlike ShopBuyItemSelection's, this case has no else; an unrecognized price scale leaves scaledPrice
        undefined. }
      case GDVars.vmBand.zone0^.priceScale of
        Shop.PRICE_SCALE_SIXTEENTH: scaledPrice := chosen^.definition.value div 16;
        Shop.PRICE_SCALE_EIGHTH: scaledPrice := chosen^.definition.value div 8;
        Shop.PRICE_SCALE_QUARTER: scaledPrice := chosen^.definition.value div 4;
        Shop.PRICE_SCALE_HALF: scaledPrice := chosen^.definition.value div 2;
        Shop.PRICE_SCALE_BASE: scaledPrice := chosen^.definition.value;
        Shop.PRICE_SCALE_DOUBLE: scaledPrice := chosen^.definition.value shl 1;
        Shop.PRICE_SCALE_QUADRUPLE: scaledPrice := chosen^.definition.value * 4;
        Shop.PRICE_SCALE_OCTUPLE: scaledPrice := chosen^.definition.value * 8;
      end;
      if chosen^.definition.quantity > 1 then
        scaledPrice := chosen^.definition.quantity * scaledPrice;
      if scaledPrice = 0 then
        scaledPrice := 1;
      personalFunds := GDVars.currentChar^.coins[0];
      pooledFunds := GDVars.moneyPool[0];
      if scaledPrice <= personalFunds then begin
        Shop.GiveItemCopyToCreature(chosen, overloaded);
        if not overloaded then begin
          Dec(GDVars.currentChar^.coins[0], scaledPrice);
          if chosen^.definition.quantity > 0 then
            CharHlp.PrintBottomLine(GDVars.currentChar^.name + GDConsts.buysSuffix + chosen^.name)
          else
            CharHlp.PrintBottomLine(GDVars.currentChar^.name + GDConsts.buysASuffix + chosen^.name);
        end;
      end else if scaledPrice <= personalFunds + pooledFunds then begin
        Shop.GiveItemCopyToCreature(chosen, overloaded);
        if not overloaded then begin
          GDVars.currentChar^.coins[0] := 0;
          Dec(GDVars.moneyPool[0], scaledPrice - personalFunds);
          if chosen^.definition.quantity > 0 then
            CharHlp.PrintBottomLine(GDVars.currentChar^.name + GDConsts.buysSuffix + chosen^.name)
          else
            CharHlp.PrintBottomLine(GDVars.currentChar^.name + GDConsts.buysASuffix + chosen^.name);
        end;
      end else
        CharHlp.PrintBottomLine(GDConsts.notEnoughMoneyMsg);
    end;
  until exitFlag;
end;

procedure ShopMainMenu;
var
  viewCompleted: Boolean;
  exitFlag: Boolean;
  slotCount: Byte;
  slotIndex: Byte;
  choice: Char;
  hasMoney: Boolean;
  hasItems: Boolean;
  conditionalRedraw: Boolean;
  node: Types.PItemRec;
  defaultSelection: Byte;
begin
  GDVars.savedInterfaceState := GDVars.interfaceState;
  GDVars.interfaceState := C_Ifc.IN_SHOP;
  GDVars.storeFrameGate := 0;
  CharHlp.DisplayNoncombatInterface;
  GDVars.storeFrameGate := 1;
  CharHlp.DisplayParty(GDVars.currentChar);
  GameIo.ZeroFill(GDVars.moneyPool, SizeOf(Types.TMoney));
  GDVars.poolHasMoney := False;
  exitFlag := False;
  node := GDVars.treasureList;
  while node <> nil do begin
    CharHlp.PrintItemString(nil, node, 0, 0, False, False);
    node := node^.next;
  end;
  defaultSelection := Ord(Shop.STORE_OPTION_VIEW);
  repeat
    Money.DetermineTreasure(hasMoney, hasItems);
    if hasMoney then
      MenuCore.ResetMenuSlots(Ord(Shop.STORE_OPTION_EXIT))
    else begin
      slotCount := 0;
      for slotIndex := 0 to Ord(Shop.STORE_OPTION_EXIT) do
        if (slotIndex <> Ord(Shop.STORE_OPTION_TAKE)) and (slotIndex <> Ord(Shop.STORE_OPTION_SHARE)) then
          MenuCore.AppendSlot(slotIndex, slotCount);
    end;
    GDVars.horizMenuChoice := defaultSelection;
    choice := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.storeMenuItems, True, False);
    defaultSelection := GDVars.horizMenuChoice;
    if GDVars.extendedKeyFlag then
      case choice of
        C_Keys.UP, C_Keys.DOWN: begin
          ViewChar.SelectPrevNextChar(choice);
          choice := #255;
        end;
        C_Keys.ESCAPE: choice := Shop.STORE_OPTION_EXIT;
      end;
    case choice of
      Shop.STORE_OPTION_BUY: Shop.ShopBuyMenu;
      Shop.STORE_OPTION_VIEW: ViewChar.ViewCharMenu(viewCompleted);
      Shop.STORE_OPTION_TAKE: Money.TakeMoneyMenu;
      Shop.STORE_OPTION_POOL: Money.PoolMoney;
      Shop.STORE_OPTION_SHARE: Money.ShareMoney;
      Shop.STORE_OPTION_APPRAISE: Money.AppraiseMenu(conditionalRedraw);
      Shop.STORE_OPTION_EXIT: begin
        Money.DetermineTreasure(hasMoney, hasItems);
        if hasMoney then begin
          TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, Black,
                                        True, GDConsts.leftMoneyMsg);
          TextRend.DisplayMessageWindow(1, 17, 38, 22, White, Black, False,
                                        GDConsts.goBackForMoneyPrompt);
          if MenuCore.YesNoMenu(GDConsts.emptyQuery, GDConsts.yesChoice) = GDConsts.noChoice then
            exitFlag := True
          else
            TextRend.ClearRect(1, 17, 38, 22);
        end else
          exitFlag := True;
      end;
    end;
    { Note: Pool redraws according to conditionalRedraw, which only Appraise sets, so a Pool before any Appraise reads
      it uninitialized and a later one reads a stale value. }
    case choice of
      Shop.STORE_OPTION_BUY, Shop.STORE_OPTION_TAKE, Shop.STORE_OPTION_APPRAISE:
        CharHlp.DisplayNoncombatInterface;
      Shop.STORE_OPTION_POOL:
        if conditionalRedraw then CharHlp.DisplayNoncombatInterface;
    end;
    CharHlp.DisplayParty(GDVars.currentChar);
  until exitFlag;
  GDVars.interfaceState := GDVars.savedInterfaceState;
end;

begin
end.
