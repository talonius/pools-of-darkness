{ The vault: a store where the party leaves money and items between visits. The vault menu reloads the stored contents
  from the save directory, lets the party view, take, pool, deposit money and deposit items, and writes the contents
  back to tmpvault.dat on exit. }
{$O+,F+,S-,R-,V-,B-,I-}
unit Vault;

interface

{ Runs the vault menu until Exit, then writes the vault contents back as tmpvault.dat. Does nothing more than redraw the
  party if the save directory is not ready. The vault's items are reloaded into the treasure list on entry; the menu
  offers View, Take (when the vault holds anything), Pool, money and item deposits (when the current character has coins
  or items) and Exit, and the up and down arrows change the current character. }
procedure PoolVault;

implementation

uses PostCbt, SaveLoad, ViewChar, Money, CharHlp, MenuCore, GameIo, TextRend, Types, GDConsts, GDVars, C_Keys, C_Ifc;

const
  { the vault menu's choices }
  CHOICE_VIEW = #0;
  CHOICE_TAKE = #1;
  CHOICE_POOL = #2;
  CHOICE_MONEY = #3;
  CHOICE_ITEMS = #4;
  CHOICE_EXIT = #5;

procedure PoolVault;
var
  hotkey: Char;
  choice: Char;
  { Unused in this version; see the other implementations of this routine. }
  moneyAmount: Word;
  exitFlag: Boolean;
  hasMoney: Boolean;
  hasItems: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  itemCount: Word;
  optionCount: Byte;
  actionDone: Boolean;
  savedSelection: Byte;
  savedNode: Pointer;
begin
  GDVars.interfaceState := C_Ifc.IN_VAULT;
  GDVars.storeFrameGate := 1;
  CharHlp.DisplayNoncombatInterface;
  GDVars.storeFrameGate := 1;
  CharHlp.DisplayParty(GDVars.currentChar);
  if not SaveLoad.CheckSaveDir then begin
    CharHlp.ClearEncounterState;
    Exit;
  end;

  { Release whatever vault contents are still held, then load them afresh. }
  while GDVars.treasureList <> nil do begin
    savedNode := GDVars.treasureList;
    GDVars.treasureList := GDVars.treasureList^.next;
    GameIo.FreeSlot(Types.PItemRec(savedNode));
  end;
  GDVars.treasureList := nil;
  SaveLoad.LoadVault(hasMoney, hasItems);
  GDVars.poolHasMoney := False;
  exitFlag := False;
  savedSelection := 1;
  repeat
    GameIo.ZeroFill(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable));
    optionCount := 0;
    MenuCore.AppendSlot(Ord(Vault.CHOICE_VIEW), optionCount);
    Money.DetermineTreasure(hasMoney, hasItems);
    if hasMoney or hasItems then
      MenuCore.AppendSlot(Ord(Vault.CHOICE_TAKE), optionCount);
    MenuCore.AppendSlot(Ord(Vault.CHOICE_POOL), optionCount);
    if (GDVars.currentChar^.coins[0] > 0) or (GDVars.currentChar^.coins[1] > 0) or
        (GDVars.currentChar^.coins[2] > 0) then
      MenuCore.AppendSlot(Ord(Vault.CHOICE_MONEY), optionCount);
    if GDVars.currentChar^.items <> nil then
      MenuCore.AppendSlot(Ord(Vault.CHOICE_ITEMS), optionCount);
    MenuCore.AppendSlot(Ord(Vault.CHOICE_EXIT), optionCount);
    GDVars.horizMenuChoice := savedSelection;
    choice := MenuCore.MenuHorizontal('', GDConsts.vaultMenuItems, True, False);
    savedSelection := GDVars.horizMenuChoice;
    if GDVars.extendedKeyFlag and (choice = C_Keys.ESCAPE) then begin
      GDVars.extendedKeyFlag := False;
      choice := Vault.CHOICE_EXIT;
    end;
    actionDone := False;
    if not GDVars.extendedKeyFlag then begin
      case choice of
        Vault.CHOICE_VIEW: ViewChar.ViewCharMenu(actionDone);
        Vault.CHOICE_TAKE: PostCbt.LootTakeMenu(hasMoney, hasItems);
        Vault.CHOICE_POOL: Money.PoolMoney;
        Vault.CHOICE_MONEY: begin
              ViewChar.DropMoneyMenu(0);
              TextRend.ClearRect(1, 17, 38, 22);
            end;
        Vault.CHOICE_ITEMS: begin
              ViewChar.UseItemMenu(actionDone);
              CharHlp.DisplayNoncombatInterface;
            end;
        Vault.CHOICE_EXIT: exitFlag := True;
      end;
    end else begin
      hotkey := choice;
      if (hotkey = C_Keys.DOWN) or (hotkey = C_Keys.UP) then begin
        CharHlp.DisplayRoster(GDVars.currentChar, False);
        ViewChar.SelectPrevNextChar(choice);
        CharHlp.DisplayRoster(GDVars.currentChar, True);
      end;
    end;
  until exitFlag;
  SaveLoad.WriteVaultFile(GDVars.saveDir + 'tmpvault.dat');
  CharHlp.ClearEncounterState;
end;

begin
end.
