{ Saving and loading characters, the party, saved games and the vault. }
{$O+,F+,S-,R-,V-,B-,I-}
unit SaveLoad;

interface

uses Portrait, C_Stat, Dos, GameIo, Types, GDConsts, GDVars, Blit, MapTiles, ClassCal,
  DaxIo, MenuCore, TextRend, CharHlp, FxEngine, ZeroFree, View3D, Sym8x8, C_Keys, C_Npc, C_Video, C_Ifc, C_Race;

{ Lists the characters that can join the party from the current storage. NPCs and characters already in the party are
  left out. Both lists stay nil when the save directory is not ready.
  @param(rawNameList Receives the names stored in the files, padded to 15 characters, as a menu list.)
  @param(displayNameList Receives the matching file names, in step with rawNameList.) }
procedure LoadCharlist(var rawNameList, displayNameList: Pointer);

{ Checks that the current mode's directory is reachable. While a floppy drive holds the disk labeled SECRET it asks for
  the save disk. A missing directory is created (on a floppy after asking, and asking for the save disk on No): the save
  directory in save mode, the other configured directory otherwise, transfer mode included. Another error asks for the
  save disk and retries on a floppy, and on a hard drive reports the directory missing and returns False.
  @returns(False when a hard-disk directory cannot be reached, True otherwise.) }
function CheckSaveDir: Boolean;

{ Builds the current character's combat icon in its order slot from its head and body pictures.
  @param(applyColorMap True recolors the icon with the character's icon colors.) }
procedure LoadCharIconAnim(applyColorMap: Boolean);

{ Deletes the character's .pc, .thg and .efx files from the save directory.
  @param(characterData The character.) }
procedure DeleteCharacterFiles(characterData: Pointer);

{ Writes a character to the save directory, or to the transfer directory in transfer mode: the record to a .pc file (or
  resourceName.sav for a saved game), its items to .thg, and its effects to .efx. Checks for room first, offering
  another disk, and asks before overwriting a .pc file, letting the player pick a new name that also becomes the
  character's name.
  @param(characterData The character record.)
  @param(resourceName The saved game's file name, or empty for a character saved on its own.) }
procedure SaveChar(characterData: Pointer; resourceName: Types.TResourceName);

{ Loads a character, with its items and effects, from the current storage. A legacy record is converted to the current
  layout: a human's dual-class level is taken from its old levels, and hit points lost to the constitution recalculation
  are added back to the rolled hit points. Its items are carried over, skipping containers along with their contents,
  giving bundles a count of 2, and updating item kind 58. Files read in transfer mode are deleted.
  @param(characterFileName The character's file name, extension included.)
  @param(characterData Receives the character, a Types.PCharRecord.)
  @param(savedGame Unused.)
  @param(promptForDisk True picks the save-disk prompt over the alternate one.) }
procedure LoadChar(characterFileName: String; characterData: Pointer; savedGame, promptForDisk: Boolean);

{ Loads a monster: its record from MON1CHA.DAX, its effects from MON1SPC.DAX and its items from MON1ITM.DAX, taking the
  items from the item pool or the heap as asked. A missing monster is fatal. The monster's class mask becomes the sum of
  its classes' bits.
  @param(creatureId The monster's record.)
  @param(useSlotAllocator True takes the items from the item pool; False allocates them on the heap.)
  @param(characterData Receives the monster.) }
procedure LoadCreatureData(creatureId: Byte; useSlotAllocator: Boolean; characterData: Pointer);

{ Adds a monster to the party as an NPC with its picture as its icon, unless the party is full.
  @param(creatureId The monster's record.) }
procedure AddCreatureToParty(creatureId: Byte);

{ Loads a saved game. The player picks the save or legacy source and then a save letter. Reads the settings and game
  state, loads each listed character (dropping legacy NPCs), removes the loaded characters' own files from the save
  directory, and rebuilds the icons, the map or area picture, and the tile set.
  @param(vaultMode True takes save Z from the transfer directory instead, deleting it after reading.) }
procedure LoadGame(vaultMode: Boolean);

{ Saves the game, first pruning the roster to the party size when asked. In vault mode it saves to the transfer slot
  under the letter Z; otherwise a menu picks a letter A..J. After the directory and free-space checks it writes
  savgam<letter>.pty (the game state, the location and the member names CHRDAT<letter>1..8) and each member, deleting
  the member's working files, and then the vault: tmpvault.dat becomes vault<letter>.dat when the vault changed, or the
  last save's vault is copied to this letter.
  @param(trimParty When set, first drops the characters beyond the party size.)
  @param(vaultMode When set, saves to the transfer slot instead of asking for a letter.) }
procedure SaveGame(trimParty, vaultMode: Boolean);

{ Appends a character to the party, makes it current, gives it the first free order slot, and counts it in the party
  size; an NPC also has its class values recalculated. Note: with all eight order slots taken, the order slot is left at
  8.
  @param(characterData The character.) }
procedure AddCharToParty(characterData: Pointer);

{ Loads the vault's money and items for the vault's save letter, from tmpVault.dat while there are unsaved vault
  changes, appending the items to the treasure list. A transfer-directory vault file is deleted after reading.
  @param(hasMoney Set False. Note: it is never set True, even when the money is read.)
  @param(hasItems Receives True when an item was read.) }
procedure LoadVault(var hasMoney, hasItems: Boolean);

{ Writes the vault's money and items to a file, marks the vault as changed, and clears the encounter state. Note: when
  the disk lacks room it warns but still writes.
  @param(vaultPath The file.) }
procedure WriteVaultFile(vaultPath: String);

implementation

uses CharGen;

const
  { GDVars.sharedScratch.storageMode values }
  LEGACY_STORAGE = 0;
  SAVE_STORAGE = 1;
  TRANSFER_STORAGE = 2;
  { DosError codes }
  DOS_FILE_NOT_FOUND = 2;
  DOS_ACCESS_DENIED = 5;
  DOS_NO_MORE_FILES = 18;

procedure LoadCharlist(var rawNameList, displayNameList: Pointer);

  { Appends each eligible character file matching fileMask to both lists in step. }
  procedure ScanSaveFiles(fileMask: Types.TStr80; nameOffset, markerOffset, expectedSize: Word; var rawNameList,
                          displayNameList: Pointer);
  var
    rawNode: Types.PMenuLine;
    rawTail: Types.PMenuLine;
    displayNode: Types.PMenuLine;
    displayTail: Types.PMenuLine;
    rosterChar: Types.PCharRecord;
    searchResult: SearchRec;
    bytesRead: Word;
    charFile: file;
    { Unused in this version; see the other implementations of this routine. }
    searchPath: Types.TStr80;
    marker: Byte;
    { Unused in this version; see the other implementations of this routine. }
    entryName: String[16];
  begin
    rawNode := nil;
    displayNode := nil;
    FindFirst(fileMask, 0, searchResult);
    while DosError = 0 do begin
      if GDVars.sharedScratch.storageMode = SaveLoad.SAVE_STORAGE then
        Assign(charFile, GDVars.saveDir + searchResult.Name)
      else
        Assign(charFile, GDVars.importDir + searchResult.Name);
      Reset(charFile, 1);
      if FileSize(charFile) = expectedSize then begin
        GetMem(rawNode, SizeOf(Types.TMenuLine));
        GetMem(displayNode, SizeOf(Types.TMenuLine));
        GameIo.ZeroFill(rawNode^, SizeOf(Types.TMenuLine));
        GameIo.ZeroFill(displayNode^, SizeOf(Types.TMenuLine));
        Seek(charFile, nameOffset);
        BlockRead(charFile, rawNode^, 16, bytesRead);
        Seek(charFile, markerOffset);
        BlockRead(charFile, marker, SizeOf(marker));
        displayNode^.name := searchResult.Name;
        rawNode^.name := rawNode^.name + Copy(GDConsts.rosterNameFill, 1,
                                              15 - Length(rawNode^.name));
        rosterChar := GDVars.creatureListHead;
        while (rosterChar <> nil) and
              (Copy(rawNode^.name, 1, 15) <> rosterChar^.name +
               Copy(GDConsts.rosterNameFill, 1,
                    15 - Length(rosterChar^.name))) do
          rosterChar := rosterChar^.next;
        if (marker > $7F) or (rosterChar <> nil) then begin
          FreeMem(rawNode, SizeOf(Types.TMenuLine));
          FreeMem(displayNode, SizeOf(Types.TMenuLine));
          rawNode := nil;
          displayNode := nil;
        end;
        if rawNode <> nil then begin
          if rawNameList = nil then begin
            rawNameList := rawNode;
            rawTail := Types.PMenuLine(rawNameList);
            displayNameList := displayNode;
            displayTail := Types.PMenuLine(displayNameList);
          end else begin
            rawTail^.next := rawNode;
            rawTail := rawTail^.next;
            displayTail^.next := displayNode;
            displayTail := displayTail^.next;
          end;
        end;
      end;
      Close(charFile);
      FindNext(searchResult);
    end;
  end;

begin
  rawNameList := nil;
  displayNameList := nil;
  if not SaveLoad.CheckSaveDir then Exit;
  case GDVars.sharedScratch.storageMode of
    SaveLoad.LEGACY_STORAGE: ScanSaveFiles(GDVars.importDir + '*.who',
                                           GDConsts.saveNameOffsets[GDVars.sharedScratch.storageMode],
                                           GDConsts.saveMarkerOffsets[GDVars.sharedScratch.storageMode],
                                           GDConsts.saveFileSizes[GDVars.sharedScratch.storageMode], rawNameList,
                                           displayNameList);
    SaveLoad.SAVE_STORAGE: ScanSaveFiles(GDVars.saveDir + '*.pc',
                                         GDConsts.saveNameOffsets[GDVars.sharedScratch.storageMode],
                                         GDConsts.saveMarkerOffsets[GDVars.sharedScratch.storageMode],
                                         GDConsts.saveFileSizes[GDVars.sharedScratch.storageMode], rawNameList,
                                         displayNameList);
  end;
end;

function CheckSaveDir: Boolean;
var
  errorCode: Integer;
  searchResult: SearchRec;
  promptChoice: Byte;
  directoryPath: String;
begin
  CheckSaveDir := False;
  case GDVars.sharedScratch.storageMode of
    SaveLoad.SAVE_STORAGE: directoryPath := GDVars.saveDir;
    SaveLoad.TRANSFER_STORAGE: directoryPath := GDVars.currentDataPath;
  else
    directoryPath := GDVars.importDir;
  end;
  repeat
    while (DaxIo.GetVolumeLabel(directoryPath[1]) = 'SECRET') and
        (directoryPath[1] < 'C') do
      TextRend.DisplayAndPause(14, 0,
                               'Put save disk in ' + directoryPath[1] + ':');
    repeat
      FindFirst(Copy(directoryPath, 1, Length(directoryPath) - 1),
                    Directory, searchResult);
      errorCode := DosError;
      case errorCode of
        0: ;
        SaveLoad.DOS_FILE_NOT_FOUND, SaveLoad.DOS_NO_MORE_FILES:
          begin
            if UpCase(directoryPath[1]) < 'C' then begin
              if GDVars.sharedScratch.storageMode = SaveLoad.SAVE_STORAGE then
                promptChoice :=
                  MenuCore.YesNoMenu(GDConsts.saveDiskInDrivePrompt2 + directoryPath[1] +
                  GDConsts.driveQuerySuffix, GDConsts.yesChoice)
              else
                promptChoice :=
                  MenuCore.YesNoMenu(GDConsts.saveDiskInDrivePrompt1 + directoryPath[1] +
                  GDConsts.driveQuerySuffix, GDConsts.yesChoice);
              if promptChoice <> GDConsts.yesChoice then
                TextRend.DisplayAndPause(14, 0,
                                         'Put save disk in ' + directoryPath[1] +
                                           ':');
            end;
            if GDVars.sharedScratch.storageMode = SaveLoad.SAVE_STORAGE then
              MkDir(Copy(GDVars.saveDir, 1, Length(GDVars.saveDir) - 1))
            else
              MkDir(Copy(GDVars.importDir, 1, Length(GDVars.importDir) - 1));
            errorCode := DosError;
          end;
      else
        if UpCase(directoryPath[1]) < 'C' then
          TextRend.DisplayAndPause(14, 0,
                                   'Put save disk in ' + directoryPath[1] + ':')
        else begin
          if GDVars.sharedScratch.storageMode = SaveLoad.LEGACY_STORAGE then
            TextRend.DisplayAndPause(14, 0, GDConsts.noSsbDirMsg)
          else
            TextRend.DisplayAndPause(14, 0, GDConsts.noPodDirMsg);
          Exit;
        end;
      end;
    until errorCode in [0, SaveLoad.DOS_ACCESS_DENIED];
  until errorCode in [0, SaveLoad.DOS_ACCESS_DENIED];
  CheckSaveDir := True;
end;

{ Lays a head image over a body image: in masked display mode only the head's opaque pixels are copied, otherwise the
  pixels are ORed together, and the masks are combined.
  @param(sourceImage The head image.)
  @param(destinationImage The body image, which receives the result.) }
procedure MergeIcon(sourceImage, destinationImage: Types.PImage);
var
  { Unused in this version; see the other implementations of this routine. }
  count: Word;
  pixelIndex: Word;
begin
  for pixelIndex := 0 to sourceImage^.total - 1 do begin
    if GDVars.videoMode = C_Video.DISPLAY_MCGA then begin
      if sourceImage^.data[pixelIndex] <> sourceImage^.keyColor then
        destinationImage^.data[pixelIndex] := sourceImage^.data[pixelIndex];
    end else
      destinationImage^.data[pixelIndex] := destinationImage^.data[pixelIndex] or sourceImage^.data[pixelIndex];
    if destinationImage^.mask <> nil then
      destinationImage^.mask^[pixelIndex] := destinationImage^.mask^[pixelIndex] and sourceImage^.mask^[pixelIndex];
  end;
end;

procedure LoadCharIconAnim(applyColorMap: Boolean);
var

  { Unused in this version; see the other implementations of this routine. }
  animSlot: Byte;
  { Unused in this version; see the other implementations of this routine. }
  frame: Byte;
  { Unused in this version; see the other implementations of this routine. }
  iconIds: Byte;
  fromMap: Types.TColorTab;
  toMap: Types.TColorTab;
  colorIndex: Byte;
  { Unused in this version; see the other implementations of this routine. }
  partIdx: Byte;
begin
  with GDVars.currentChar^ do begin
    MapTiles.LoadIconAnim('CHEAD' + GDConsts.iconHeightMark[iconSize], iconHeadClass, 11);
    MapTiles.LoadIconAnim('CBODY' + GDConsts.iconHeightMark[iconSize], iconBodyClass, orderNumber);
    SaveLoad.MergeIcon(GDVars.iconAnimTable[11, 0],
                       GDVars.iconAnimTable[orderNumber, 0]);
    SaveLoad.MergeIcon(GDVars.iconAnimTable[11, 1],
                       GDVars.iconAnimTable[orderNumber, 1]);
    if applyColorMap then begin
      for colorIndex := 0 to 15 do begin
        fromMap[colorIndex] := colorIndex;
        toMap[colorIndex] := colorIndex;
      end;
      for colorIndex := 1 to 6 do begin
        toMap[GDConsts.iconSlotColor[colorIndex]] := iconColors[colorIndex] and $F;
        toMap[GDConsts.iconSlotColor[colorIndex] + 8] := (iconColors[colorIndex] and
                                                                                 $F0) shr 4;
      end;
      Blit.RemapPic(fromMap, toMap, 0, False, GDVars.iconAnimTable[orderNumber, 0]);
      Blit.RemapPic(fromMap, toMap, 0, False, GDVars.iconAnimTable[orderNumber, 1]);
    end;
  end;
  MapTiles.FreeIconAnim(11);
  GameIo.FlushKeys;
end;

procedure DeleteCharacterFiles(characterData: Pointer);
var
  directoryPath: Types.TStr80;
  { Unused in this version; see the other implementations of this routine. }
  fileBuf: array[1..128] of Byte;
begin
  directoryPath := GDVars.saveDir + DaxIo.SanitizeFileName(Types.PCharRecord(characterData)^.name);
  DaxIo.DeleteIfPresent(directoryPath + '.pc');
  DaxIo.DeleteIfPresent(directoryPath + '.thg');
  DaxIo.DeleteIfPresent(directoryPath + '.efx');
end;

procedure SaveChar(characterData: Pointer; resourceName: Types.TResourceName);
var
  charFile: file;
  fileStem: Types.TStr40;
  fileExtension: String[4];
  menuChoice: Byte;
  { Unused in this version; see the other implementations of this routine. }
  response: Byte;
  itemCursor: Types.PItemRec;
  effectCursor: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  list: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  cursor: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  node: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  nameBuf: array[1..12] of Byte;
  errorCode: Word;
  requiredBytes: Word;
  { Unused in this version; see the other implementations of this routine. }
  redraw: Byte;
  directoryPath: String;
begin
  if GDVars.sharedScratch.storageMode <> SaveLoad.TRANSFER_STORAGE then begin
    GDVars.sharedScratch.storageMode := SaveLoad.SAVE_STORAGE;
    directoryPath := GDVars.saveDir;
  end else
    directoryPath := GDVars.currentDataPath;
  repeat
    if not SaveLoad.CheckSaveDir then Exit;
    requiredBytes := 0;
    Inc(requiredBytes, SizeOf(Types.TCharRecord));
    if Types.PCharRecord(characterData)^.items <> nil then begin
      itemCursor := Types.PItemRec(Types.PCharRecord(characterData)^.items);
      while itemCursor <> nil do begin
        Inc(requiredBytes, SizeOf(Types.TItemRec));
        itemCursor := itemCursor^.next;
      end;
    end;
    if Types.PCharRecord(characterData)^.effects <> nil then begin
      effectCursor := Types.PEffectRec(Types.PCharRecord(characterData)^.effects);
      while effectCursor <> nil do begin
        Inc(requiredBytes, SizeOf(Types.TEffectRec));
        effectCursor := effectCursor^.next;
      end;
    end;
    menuChoice := 0;
    if requiredBytes > DiskFree(Ord(UpCase(directoryPath[1])) -
                                    Ord('@')) then begin
      TextRend.DisplayAndPause(14, 0, GDConsts.diskFullMsg);
      MenuCore.ResetMenuSlots(1);
      menuChoice := Ord(MenuCore.MenuHorizontal(GDConsts.loseCharacterPrompt, GDConsts.tryAnotherDiskMenu, False,
                                                False));
    end;
  until menuChoice = 0;
  if Length(resourceName) = 0 then begin
    fileExtension := '.pc';
    fileStem := DaxIo.SanitizeFileName(DaxIo.SanitizeString(Types.PCharRecord(characterData)^.name,
                                                            '.'));
  end else begin
    fileExtension := '.sav';
    fileStem := resourceName;
  end;
  repeat
    Assign(charFile, directoryPath + fileStem + fileExtension);
    Reset(charFile, 1);
    errorCode := DosError;
    if not (errorCode in [0, SaveLoad.DOS_FILE_NOT_FOUND]) then begin
      if UpCase(directoryPath[1]) < 'C' then
        TextRend.DisplayAndPause(14, 0,
                                 'Put save disk in ' + directoryPath[1] + ':')
      else begin
        TextRend.DisplayAndPause(14, 0, GDConsts.noPodDirMsg);
        Close(charFile);
        Exit;
      end;
    end;
  until (errorCode = 0) or (errorCode = SaveLoad.DOS_FILE_NOT_FOUND);
  Close(charFile);
  menuChoice := 1;

  while (menuChoice = 1)
        and (Length(resourceName) = 0)
        and DaxIo.FileExists(directoryPath + fileStem + fileExtension) do begin
    menuChoice := MenuCore.YesNoMenu(GDConsts.overwritePrompt + fileStem + GDConsts.questionSuffix,
                                     GDConsts.noChoice);
    if menuChoice = 1 then begin
      fileStem := '';
      while fileStem = '' do
        fileStem := TextRend.ReadString(GDConsts.newFileNamePrompt, 10, 0, 8);
      Types.PCharRecord(characterData)^.name := fileStem;
    end;
  end;
  Assign(charFile, directoryPath + fileStem + fileExtension);
  Rewrite(charFile, 1);
  BlockWrite(charFile, Types.PCharRecord(characterData)^, SizeOf(Types.TCharRecord));
  Close(charFile);
  DaxIo.DeleteIfPresent(directoryPath + fileStem + '.thg');
  if Types.PCharRecord(characterData)^.items <> nil then begin
    Assign(charFile, directoryPath + fileStem + '.thg');
    Rewrite(charFile, 1);
    itemCursor := Types.PItemRec(Types.PCharRecord(characterData)^.items);
    while itemCursor <> nil do begin
      BlockWrite(charFile, itemCursor^, SizeOf(Types.TItemRec));
      itemCursor := itemCursor^.next;
    end;
    Close(charFile);
  end;
  DaxIo.DeleteIfPresent(directoryPath + fileStem + '.efx');
  if Types.PCharRecord(characterData)^.effects <> nil then begin
    Assign(charFile, directoryPath + fileStem + '.efx');
    Rewrite(charFile, 1);
    effectCursor := Types.PEffectRec(Types.PCharRecord(characterData)^.effects);
    while effectCursor <> nil do begin
      BlockWrite(charFile, effectCursor^, SizeOf(Types.TEffectRec));
      effectCursor := effectCursor^.next;
    end;
    Close(charFile);
  end;
end;

procedure LoadChar(characterFileName: String; characterData: Pointer; savedGame, promptForDisk: Boolean);
var
  charFile: file;
  bytesRead: Word;
  itemTail: Types.PItemRec;
  itemBuf: Types.PItemRec;
  effTail: Types.PEffectRec;
  effBuf: Types.PEffectRec;
  diskPrompt: String[40];
  { Unused in this version; see the other implementations of this routine. }
  ignoredOpenResult: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  recordBuffer: array[1..292] of Byte;
  itemCount: Byte;
  directoryPath: String;
  { Unused in this version; see the other implementations of this routine. }
  castClass: Byte;
  itemExtension: String[4];
  effectExtension: String[4];
  legacyChar: Types.PBytes;
  recordSize: Word;
  fileOffset: LongInt;
  oldLevelIndex: ShortInt;
  importedHpMax: Byte;
begin
  case GDVars.sharedScratch.storageMode of
    SaveLoad.SAVE_STORAGE: begin
         directoryPath := GDVars.saveDir;
         itemExtension := '.thg';
         effectExtension := '.efx';
       end;
    SaveLoad.TRANSFER_STORAGE: begin
         directoryPath := GDVars.currentDataPath;
         itemExtension := '.thg';
         effectExtension := '.efx';
       end;
  else
    directoryPath := GDVars.importDir;
    itemExtension := '.stf';
    effectExtension := '.sfx';
  end;
  if promptForDisk then
    diskPrompt := 'Put save disk in '
  else
    diskPrompt := GDConsts.insertDisk2Prompt;
  ignoredOpenResult := DaxIo.OpenWithRetry(directoryPath + characterFileName, diskPrompt, 0, charFile);
  TextRend.DisplayString(0, 24, 10, 0, 'Loading...Please Wait');
  GameIo.ZeroFill(Types.PCharRecord(characterData)^, SizeOf(Types.TCharRecord));
  case GDVars.sharedScratch.storageMode of
    SaveLoad.LEGACY_STORAGE: begin
         GetMem(legacyChar, 439);
         GameIo.ZeroFill(legacyChar^, 439);
         GameIo.ZeroFill(Types.PCharRecord(characterData)^, SizeOf(Types.TCharRecord));
         BlockRead(charFile, legacyChar^, 439, bytesRead);
         Close(charFile);
         Move(legacyChar^[0], Types.PBytes(characterData)^[0],
                     30);
         Move(legacyChar^[$69], Types.PBytes(characterData)^[$AB],
                     126);
         Move(legacyChar^[$E7], Types.PBytes(characterData)^[$131],
                     9);
         Move(legacyChar^[$F2], Types.PBytes(characterData)^[$13A],
                     17);
         Move(legacyChar^[$10B], Types.PBytes(characterData)^[$14B],
                     20);
         Move(legacyChar^[$11F], Types.PBytes(characterData)^[$166], 11);
         Move(legacyChar^[$12B], Types.PBytes(characterData)^[$171],
                     5);
         Move(legacyChar^[$130], Types.PBytes(characterData)^[$17B],
                     9);
         Move(legacyChar^[$139], Types.PBytes(characterData)^[$186],
                     7);
         Move(legacyChar^[$147], Types.PBytes(characterData)^[$18F],
                     8);
         Move(legacyChar^[$153], Types.PBytes(characterData)^[$19A],
                     12);
         Move(legacyChar^[$160], Types.PBytes(characterData)^[$1A6],
                     70);
         Move(legacyChar^[$1A6], Types.PBytes(characterData)^[$1ED],
                     17);
         Types.PCharRecord(characterData)^.race := Pred(Types.PCharRecord(characterData)^.race);
         Types.PCharRecord(characterData)^.items := nil;
         Types.PCharRecord(characterData)^.effects := nil;
         Types.PCharRecord(characterData)^.combatAddr := nil;
         Types.PCharRecord(characterData)^.next := nil;
         Types.PCharRecord(characterData)^.creatureType := 2;
         Types.PCharRecord(characterData)^.immunities := 2;
         FreeMem(legacyChar, 439);
         with Types.PCharRecord(characterData)^ do begin
           dualLevel := 0;
           if Types.PCharRecord(characterData)^.race = C_Race.HUMAN then
             for oldLevelIndex := 0 to 6 do
               if oldLevels[oldLevelIndex] > dualLevel then
                 dualLevel := oldLevels[oldLevelIndex];
         end;
         importedHpMax := Types.PCharRecord(characterData)^.hpMax;
         FxEngine.RecalcAbility(characterData, C_Stat.CONSTITUTION);
         if Types.PCharRecord(characterData)^.hpMax < importedHpMax then begin
           Inc(Types.PCharRecord(characterData)^.hpRolled, importedHpMax - Types.PCharRecord(characterData)^.hpMax);
           FxEngine.RecalcAbility(characterData, C_Stat.CONSTITUTION);
         end;
       end;
    SaveLoad.SAVE_STORAGE, SaveLoad.TRANSFER_STORAGE: begin
         BlockRead(charFile, Types.PCharRecord(characterData)^, SizeOf(Types.TCharRecord), bytesRead);
         Close(charFile);
         if GDVars.sharedScratch.storageMode = SaveLoad.TRANSFER_STORAGE then
           DaxIo.DeleteIfPresent(directoryPath + characterFileName);
         Types.PCharRecord(characterData)^.items := nil;
         Types.PCharRecord(characterData)^.effects := nil;
         Types.PCharRecord(characterData)^.combatAddr := nil;
         Types.PCharRecord(characterData)^.next := nil;
       end;
  end;
  Delete(characterFileName, Pos('.', characterFileName), 4);
  itemCount := 0;
  if DaxIo.FileExists(directoryPath + characterFileName + itemExtension) then begin
    GetMem(itemBuf, SizeOf(Types.TItemRec));
    ignoredOpenResult := DaxIo.OpenWithRetry(directoryPath + characterFileName + itemExtension, diskPrompt,
                                             0, charFile);
    recordSize := SizeOf(Types.TItemRec);
    if GDVars.sharedScratch.storageMode = SaveLoad.LEGACY_STORAGE then begin
      repeat
        BlockRead(charFile, itemBuf^, recordSize, bytesRead);
        if bytesRead = recordSize then begin
          fileOffset := FilePos(charFile) + 4;
          Seek(charFile, fileOffset);
          if itemBuf^.definition.itemType = 73 then begin
            Inc(fileOffset, itemBuf^.definition.quantity * (recordSize + 4));
            Seek(charFile, fileOffset);
          end else begin
            Inc(itemCount);
            if Types.PCharRecord(characterData)^.items = nil then begin
              Types.PCharRecord(characterData)^.items := GameIo.AllocSlot;
              itemTail := Types.PItemRec(Types.PCharRecord(characterData)^.items);
            end else begin
              itemTail^.next := GameIo.AllocSlot;
              itemTail := itemTail^.next;
            end;
            if itemBuf^.definition.itemType = 45 then
              itemBuf^.definition.plus := 2;
            if itemBuf^.definition.itemType = 58 then
              itemBuf^.definition.effect := 89;
            itemTail^ := itemBuf^;
            itemTail^.next := nil;
          end;
        end;
      until bytesRead <> recordSize;
    end else begin
      repeat
        BlockRead(charFile, itemBuf^, recordSize, bytesRead);
        if bytesRead = recordSize then begin
          Inc(itemCount);
          if Types.PCharRecord(characterData)^.items = nil then begin
            Types.PCharRecord(characterData)^.items := GameIo.AllocSlot;
            itemTail := Types.PItemRec(Types.PCharRecord(characterData)^.items);
          end else begin
            itemTail^.next := GameIo.AllocSlot;
            itemTail := itemTail^.next;
          end;
          itemTail^ := itemBuf^;
          itemTail^.next := nil;
        end;
      until bytesRead <> recordSize;
    end;
    Close(charFile);
    if GDVars.sharedScratch.storageMode = SaveLoad.TRANSFER_STORAGE then
      DaxIo.DeleteIfPresent(directoryPath + characterFileName + itemExtension);
    FreeMem(itemBuf, SizeOf(Types.TItemRec));
  end;
  if DaxIo.FileExists(directoryPath + characterFileName + effectExtension) then begin
    GetMem(effBuf, SizeOf(Types.TEffectRec));
    ignoredOpenResult := DaxIo.OpenWithRetry(directoryPath + characterFileName + effectExtension, diskPrompt,
                                             0, charFile);
    repeat
      BlockRead(charFile, effBuf^, SizeOf(Types.TEffectRec), bytesRead);
      if bytesRead = SizeOf(Types.TEffectRec) then begin
        if Types.PCharRecord(characterData)^.effects = nil then begin
          GetMem(Types.PCharRecord(characterData)^.effects, SizeOf(Types.TEffectRec));
          effTail := Types.PEffectRec(Types.PCharRecord(characterData)^.effects);
        end else begin
          GetMem(effTail^.next, SizeOf(Types.TEffectRec));
          effTail := effTail^.next;
        end;
        effTail^ := effBuf^;
        effTail^.next := nil;
      end;
    until bytesRead <> SizeOf(Types.TEffectRec);
    Close(charFile);
    if GDVars.sharedScratch.storageMode = SaveLoad.TRANSFER_STORAGE then
      DaxIo.DeleteIfPresent(directoryPath + characterFileName + effectExtension);
    FreeMem(effBuf, SizeOf(Types.TEffectRec));
  end;
  GameIo.FlushKeys;
  CharHlp.RecalcStats(characterData);
  FxEngine.RecalcAbility(characterData, C_Stat.STRENGTH);
  ClassCal.RecalcClassStats(Types.PCharRecord(characterData));
end;

procedure LoadCreatureData(creatureId: Byte; useSlotAllocator: Boolean; characterData: Pointer);
var
  dataSize: Word;
  daxData: Types.PBytes;
  dataOffset: Word;
  itemCursor: Types.PItemRec;
  effectCursor: Types.PEffectRec;
  archiveNumber: String[1];
  { Unused in this version; see the other implementations of this routine. }
  index: Byte;
  { Unused in this version; see the other implementations of this routine. }
  roll: Byte;
  classIndex: ShortInt;
begin
  archiveNumber := '1';
  DaxIo.LoadDax('MON' + archiveNumber + 'CHA', '.dax', creatureId, dataSize, daxData);
  if dataSize = 0 then begin
    TextRend.DisplayAndPause(15, 0, 'Unable to load monster');
    GameIo.ExitGame(0);
  end;
  Move(daxData^, Types.PCharRecord(characterData)^, SizeOf(Types.TCharRecord));
  with Types.PCharRecord(characterData)^ do begin
    items := nil;
    effects := nil;
    next := nil;
    combatAddr := nil;
  end;
  ZeroFree.PrefixFree(daxData, dataSize);

  GDVars.suppressDiskPrompt := 1;
  DaxIo.LoadDax('MON' + archiveNumber + 'SPC', '.dax', creatureId, dataSize, daxData);
  if dataSize <> 0 then begin
    dataOffset := 0;
    GetMem(Types.PCharRecord(characterData)^.effects, SizeOf(Types.TEffectRec));
    effectCursor := Types.PEffectRec(Types.PCharRecord(characterData)^.effects);
    repeat
      Move(daxData^[dataOffset], effectCursor^, SizeOf(Types.TEffectRec));
      effectCursor^.next := nil;
      Inc(dataOffset, SizeOf(Types.TEffectRec));
      if dataOffset < dataSize then begin
        GetMem(effectCursor^.next, SizeOf(Types.TEffectRec));
        effectCursor := effectCursor^.next;
      end;
    until dataOffset >= dataSize;
    ZeroFree.PrefixFree(daxData, dataSize);
  end;

  DaxIo.LoadDax('MON' + archiveNumber + 'ITM', '.dax', creatureId, dataSize, daxData);
  if dataSize <> 0 then begin
    dataOffset := 0;
    if useSlotAllocator then
      Types.PCharRecord(characterData)^.items := GameIo.AllocSlot
    else
      GetMem(Types.PCharRecord(characterData)^.items, SizeOf(Types.TItemRec));
    itemCursor := Types.PItemRec(Types.PCharRecord(characterData)^.items);
    repeat
      Move(daxData^[dataOffset], itemCursor^.definition, SizeOf(itemCursor^.definition));
      itemCursor^.next := nil;
      itemCursor^.inUse := 0;
      Inc(dataOffset, SizeOf(itemCursor^.definition));
      if dataOffset < dataSize then begin
        if useSlotAllocator then
          itemCursor^.next := GameIo.AllocSlot
        else
          GetMem(itemCursor^.next, SizeOf(Types.TItemRec));
        itemCursor := itemCursor^.next;
      end;
    until dataOffset >= dataSize;
    ZeroFree.PrefixFree(daxData, dataSize);
  end;
  GDVars.suppressDiskPrompt := 0;
  GameIo.FlushKeys;
  with Types.PCharRecord(characterData)^ do begin
    classMask := 0;
    for classIndex := 0 to 6 do
      if classLevels[classIndex] > 0 then
        Inc(classMask, GDConsts.classMaskBit[classIndex]);
  end;
end;

procedure AddCreatureToParty(creatureId: Byte);
var

  { Unused in this version; see the other implementations of this routine. }
  node: Pointer;
  newChar: Types.PCharRecord;

  { Unused in this version; see the other implementations of this routine. }
  slot: Byte;
begin
  if GDVars.vmBand.zone0^.partySize > 7 then Exit;
  GetMem(newChar, SizeOf(Types.TCharRecord));
  SaveLoad.LoadCreatureData(creatureId, True, newChar);
  SaveLoad.AddCharToParty(newChar);
  newChar^.npc := newChar^.npc or C_Npc.NON_PLAYER;
  newChar^.creatureId := creatureId;
  MapTiles.LoadIconAnim('CPIC', creatureId, newChar^.orderNumber);
end;

procedure AddCharToParty(characterData: Pointer);
var
  partyCursor: Types.PCharRecord;
  usedOrderSlots: array[0..7] of Byte;
begin
  Types.PCharRecord(characterData)^.orderNumber := $FF;
  if GDVars.creatureListHead = nil then
    GDVars.creatureListHead := Types.PCharRecord(characterData)
  else begin
    partyCursor := GDVars.creatureListHead;
    while partyCursor^.next <> nil do
      partyCursor := partyCursor^.next;
    partyCursor^.next := Types.PCharRecord(characterData);
  end;
  GDVars.currentChar := Types.PCharRecord(characterData);
  GameIo.ZeroFill(usedOrderSlots, SizeOf(usedOrderSlots));
  partyCursor := GDVars.creatureListHead;
  while partyCursor <> nil do begin
    if partyCursor^.orderNumber in [0..7] then
      usedOrderSlots[partyCursor^.orderNumber] := 1;
    partyCursor := partyCursor^.next;
  end;
  with GDVars.currentChar^ do begin
    orderNumber := 0;
    while (orderNumber < 8) and (usedOrderSlots[orderNumber] <> 0) do
      Inc(orderNumber);
  end;
  Inc(GDVars.vmBand.zone0^.partySize);
  if Types.PCharRecord(characterData)^.npc > $7F then
    ClassCal.RecalcClassStats(Types.PCharRecord(characterData));
end;

procedure LoadGame(vaultMode: Boolean);
var
  characterNames: array[1..8] of String[40];
  partyFile: file;
  characterIndex: Byte;
  loadedChar: Types.PCharRecord;
  characterFileName: String[40];
  bytesRead: Word;
  characterCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  ignoredOpenResult: Boolean;
  saveLetterIndex: Byte;
  menuSlotCount: Byte;
  menuChoice: Char;
  saveLetter: Char;
  { Unused in this version; see the other implementations of this routine. }
  fileFound: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  menuQuery: String[20];
  characterExtension: String[4];
  partyExtension: String[4];
  nextEffect: Types.PEffectRec;
  nextItem: Types.PItemRec;
  directoryPath: String;
  { Unused in this version; see the other implementations of this routine. }
  vaultChoice: Byte;
  previousTileSet: Byte;
begin
  TextRend.ClearRect(1, 1, 38, 22);
  if vaultMode then begin
    GDVars.sharedScratch.storageMode := SaveLoad.TRANSFER_STORAGE;
    partyExtension := '.pty';
    characterExtension := '.sav';
    directoryPath := GDVars.currentDataPath;
  end else begin
    MenuCore.ResetMenuSlots(2);
    menuChoice := MenuCore.MenuHorizontal(GDConsts.loadFromWherePrompt, GDConsts.poolsSecretMenu, False,
                                          False);
    case menuChoice of
      #0: begin
        GDVars.sharedScratch.storageMode := SaveLoad.SAVE_STORAGE;
        directoryPath := GDVars.saveDir;
        partyExtension := '.pty';
        characterExtension := '.sav';
      end;
      #1: begin
        GDVars.sharedScratch.storageMode := SaveLoad.LEGACY_STORAGE;
        directoryPath := GDVars.importDir;
        partyExtension := '.dat';
        characterExtension := '.sav';
      end;
      #2: Exit;
      else if GDVars.extendedKeyFlag and (menuChoice = C_Keys.ESCAPE) then Exit;
    end;
  end;
  if not SaveLoad.CheckSaveDir then Exit;
  if vaultMode then
    saveLetter := 'Z'
  else begin
    menuQuery := '';
    FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
    menuSlotCount := 0;
    saveLetterIndex := 0;
    for saveLetter := 'A' to 'J' do begin
      if DaxIo.FileExists(directoryPath + 'savgam' + saveLetter + partyExtension) then begin
        GDVars.menuSlotTable[menuSlotCount].choiceIndex := saveLetterIndex;
        Inc(menuSlotCount);
      end;
      Inc(saveLetterIndex);
    end;
    if GDVars.menuSlotTable[0].choiceIndex = $FF then Exit;
    repeat
      menuChoice := MenuCore.MenuHorizontal(GDConsts.loadWhichGamePrompt, GDConsts.driveLetterMenu, False, False);
      if GDVars.extendedKeyFlag and (menuChoice = C_Keys.ESCAPE) then
        saveLetter := C_Keys.ESCAPE
      else
        saveLetter := Chr(Ord(menuChoice) + Ord('A'));
    until (saveLetter in ['A'..'J']) and
        DaxIo.FileExists(directoryPath + 'savgam' + saveLetter + partyExtension) or (saveLetter = C_Keys.ESCAPE);
    if saveLetter = C_Keys.ESCAPE then Exit;
  end;
  ignoredOpenResult := DaxIo.OpenWithRetry(directoryPath + 'savgam' + saveLetter + partyExtension,
                                           'Put save disk in ' + directoryPath, 1, partyFile);
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, 10, 0, 'Loading...Please Wait');
  GDVars.savedGameLoaded := Byte(GDVars.sharedScratch.storageMode = SaveLoad.SAVE_STORAGE);
  previousTileSet := GDVars.vmBand.zone0^.tileSet;
  if GDVars.sharedScratch.storageMode <> SaveLoad.LEGACY_STORAGE then begin
    GDVars.vaultSaveLetter := saveLetter;
    BlockRead(partyFile, GDVars.vmBand.zone0^, SizeOf(Types.TGbvmBank0), bytesRead);
    BlockRead(partyFile, GDVars.mapState, SizeOf(GDVars.mapState), bytesRead);
    BlockRead(partyFile, GDVars.savedInterfaceState, SizeOf(GDVars.savedInterfaceState), bytesRead);
    BlockRead(partyFile, GDVars.interfaceState, SizeOf(GDVars.interfaceState), bytesRead);
    BlockRead(partyFile, GDVars.loadedWallSet.id, SizeOf(GDVars.loadedWallSet.id), bytesRead);
    BlockRead(partyFile, GDVars.loadedWallSet.slot, SizeOf(GDVars.loadedWallSet.slot), bytesRead);
  end else
    Seek(partyFile, $1414);
  BlockRead(partyFile, characterCount, SizeOf(characterCount), bytesRead);
  BlockRead(partyFile, characterNames, SizeOf(characterNames), bytesRead);
  Close(partyFile);
  if vaultMode then
    DaxIo.DeleteIfPresent(directoryPath + 'savgam' + saveLetter + partyExtension);
  GDVars.gameLoaded := 1;
  GDVars.vmBand.zone0^.partySize := 0;
  for characterIndex := 1 to characterCount do begin
    characterFileName := DaxIo.SanitizeFileName(DaxIo.SanitizeString(characterNames[characterIndex],
                                                                     '.'));
    if DaxIo.FileExists(directoryPath + characterFileName + characterExtension) then begin
      GetMem(loadedChar, SizeOf(Types.TCharRecord));
      SaveLoad.LoadChar(characterFileName + characterExtension, loadedChar, True, True);
      if (GDVars.sharedScratch.storageMode = SaveLoad.LEGACY_STORAGE) and
          (loadedChar^.npc >= C_Npc.NON_PLAYER) then begin
        nextItem := loadedChar^.items;
        while nextItem <> nil do begin
          nextItem := loadedChar^.items^.next;
          GameIo.FreeSlot(Types.PItemRec(loadedChar^.items));
          loadedChar^.items := Types.PItemRec(nextItem);
        end;
        nextEffect := Types.PEffectRec(loadedChar^.effects);
        while nextEffect <> nil do begin
          nextEffect := Types.PEffectRec(loadedChar^.effects)^.next;
          FreeMem(loadedChar^.effects, SizeOf(Types.TEffectRec));
          loadedChar^.effects := nextEffect;
        end;
        FreeMem(loadedChar, SizeOf(Types.TCharRecord));
      end else
        SaveLoad.AddCharToParty(loadedChar);
      if not SaveLoad.CheckSaveDir then Exit;
    end;
  end;
  loadedChar := GDVars.creatureListHead;
  while loadedChar <> nil do begin
    SaveLoad.DeleteCharacterFiles(loadedChar);
    loadedChar := loadedChar^.next;
  end;
  GDVars.currentChar := GDVars.creatureListHead;
  while GDVars.currentChar <> nil do begin
    if GDVars.currentChar^.npc < C_Npc.NON_PLAYER then
      SaveLoad.LoadCharIconAnim(True)
    else
      MapTiles.LoadIconAnim('CPIC', GDVars.currentChar^.creatureId, GDVars.currentChar^.orderNumber);
    GDVars.currentChar := GDVars.currentChar^.next;
  end;
  GDVars.currentChar := GDVars.creatureListHead;
  if GDVars.sharedScratch.storageMode <> SaveLoad.LEGACY_STORAGE then begin
    if GDVars.vmBand.zone0^.inDungeon <> 0 then begin
      if GDVars.loadedWallSet.id > 0 then begin
        View3D.Load3DMap(GDVars.vmBand.zone0^.mapId);
        View3D.LoadWallSet(Byte(GDVars.loadedWallSet.id), Byte(GDVars.loadedWallSet.slot));
      end;
    end else
      Portrait.LoadBigPic(GDConsts.areaPictureIds[GDVars.vmBand.zone0^.tileSet]);
  end;
  if previousTileSet <> GDVars.vmBand.zone0^.tileSet then begin
    if GDVars.vmBand.zone0^.tileSet = 4 then
      Sym8x8.Load8x8Set(0, 2)
    else
      Sym8x8.Load8x8Set(GDVars.vmBand.zone0^.tileSet, 2);
    Blit.ShadowPaletteEntries(16, 16, GDVars.mainPal);
    Blit.SetDacPalette(16, 16, GDVars.imagePal);
  end;
  GameIo.FlushKeys;
  MenuCore.ClearBottomLine;
  GDVars.interfaceState := C_Ifc.MAIN_MENU;
end;

procedure SaveGame(trimParty, vaultMode: Boolean);
var
  characterNames: array[1..8] of String[40];
  partyFile: file;
  { Unused in this version; see the other implementations of this routine. }
  pathBuffer: array[1..128] of Byte;
  characterCount: Byte;
  nextCharacter: Types.PCharRecord;
  partyCursor: Types.PCharRecord;
  characterNumber: String[1];
  vaultPath: Types.TStr80;
  hasMoney: Boolean;
  hasItems: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  overwrite: Boolean;
  menuChoice: Char;
  saveLetter: Char;
  errorCode: Word;
  requiredBytes: Word;
  savePath: String;

  { Totals the disk space the party's character records, items, and effects take. }
  function SaveSize: Word;
  var
    characterCursor: Types.PCharRecord;
    itemCursor: Types.PItemRec;
    effectCursor: Types.PEffectRec;
    byteCount: Word;
  begin
    byteCount := 0;
    characterCursor := GDVars.creatureListHead;
    while characterCursor <> nil do begin
      Inc(byteCount, SizeOf(Types.TCharRecord));
      if characterCursor^.items <> nil then begin
        itemCursor := characterCursor^.items;
        while itemCursor <> nil do begin
          Inc(byteCount, SizeOf(Types.TItemRec));
          itemCursor := itemCursor^.next;
        end;
      end;
      if characterCursor^.effects <> nil then begin
        effectCursor := Types.PEffectRec(characterCursor^.effects);
        while effectCursor <> nil do begin
          Inc(byteCount, SizeOf(Types.TEffectRec));
          effectCursor := effectCursor^.next;
        end;
      end;
      characterCursor := characterCursor^.next;
    end;
    SaveSize := byteCount;
  end;
begin
  if trimParty then begin
    characterCount := 0;
    partyCursor := GDVars.creatureListHead;
    while partyCursor <> nil do begin
      if characterCount >= GDVars.vmBand.zone0^.partySize then begin
        nextCharacter := partyCursor^.next;
        CharGen.RemoveCreature(True, True);
        partyCursor := nextCharacter;
      end else begin
        Inc(characterCount);
        partyCursor := partyCursor^.next;
      end;
    end;
  end;
  if vaultMode then begin
    saveLetter := 'Z';
    GDVars.sharedScratch.storageMode := SaveLoad.TRANSFER_STORAGE;
    savePath := GDVars.currentDataPath + 'savgam' + saveLetter;
  end else begin
    repeat
      MenuCore.ResetMenuSlots(9);
      menuChoice := MenuCore.MenuHorizontal(GDConsts.saveWhichGamePrompt, GDConsts.driveLetterMenu, False,
                                            GDVars.interfaceState = C_Ifc.CAMPING);
    until (Ord(menuChoice) < 10) or
        (GDVars.extendedKeyFlag and (Ord(menuChoice) = Ord(C_Keys.ESCAPE)));
    if Ord(menuChoice) > 9 then Exit;
    saveLetter := Chr(Ord(menuChoice) + Ord('A'));
    GDVars.sharedScratch.storageMode := SaveLoad.SAVE_STORAGE;
    savePath := GDVars.saveDir + 'savgam' + saveLetter;
  end;
  if not SaveLoad.CheckSaveDir then Exit;
  if DaxIo.FileExists(savePath + '.pty') then
    requiredBytes := 0
  else
    requiredBytes := 1031;
  Inc(requiredBytes, SaveSize);
  if LongInt(requiredBytes) >
      DiskFree(Ord(UpCase(savePath[1])) - Ord('@')) then begin
    TextRend.DisplayAndPause(14, 0, GDConsts.diskFullMsg);
    Exit;
  end;
  repeat
    Assign(partyFile, savePath + '.pty');
    Rewrite(partyFile, 1);
    errorCode := DosError;
    if not (errorCode in [0, SaveLoad.DOS_FILE_NOT_FOUND, SaveLoad.DOS_NO_MORE_FILES]) then begin
      if UpCase(savePath[1]) < 'C' then
        TextRend.DisplayAndPause(14, 0,
                                 'Put save disk in ' + savePath[1] + ':')
      else begin
        TextRend.DisplayAndPause(14, 0, GDConsts.noPodDirMsg);
        Close(partyFile);
        Exit;
      end;
    end;
  until errorCode in [0, SaveLoad.DOS_FILE_NOT_FOUND, SaveLoad.DOS_NO_MORE_FILES];
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, 10, 0, 'Saving...Please Wait');
  BlockWrite(partyFile, GDVars.vmBand.zone0^, SizeOf(Types.TGbvmBank0));
  BlockWrite(partyFile, GDVars.mapState, SizeOf(GDVars.mapState));
  BlockWrite(partyFile, GDVars.savedInterfaceState, SizeOf(GDVars.savedInterfaceState));
  BlockWrite(partyFile, GDVars.interfaceState, SizeOf(GDVars.interfaceState));
  BlockWrite(partyFile, GDVars.loadedWallSet.id, SizeOf(GDVars.loadedWallSet.id));
  BlockWrite(partyFile, GDVars.loadedWallSet.slot, SizeOf(GDVars.loadedWallSet.slot));
  characterCount := 0;
  partyCursor := GDVars.creatureListHead;
  if partyCursor = nil then
    TextRend.DisplayAndPause(14, 0, 'WARNING: Problem Saving Characters');
  while (partyCursor <> nil) and (characterCount < 8) do begin
    Inc(characterCount);
    Str(characterCount, characterNumber);
    characterNames[characterCount] := 'CHRDAT' + saveLetter + characterNumber;
    partyCursor := partyCursor^.next;
  end;
  BlockWrite(partyFile, characterCount, SizeOf(characterCount));
  BlockWrite(partyFile, characterNames, SizeOf(characterNames));
  Close(partyFile);
  partyCursor := GDVars.creatureListHead;
  characterCount := 0;
  while (partyCursor <> nil) and (characterCount < 8) do begin
    Inc(characterCount);
    Str(characterCount, characterNumber);
    SaveLoad.SaveChar(partyCursor, 'CHRDAT' + saveLetter + characterNumber);
    SaveLoad.DeleteCharacterFiles(partyCursor);
    partyCursor := partyCursor^.next;
  end;
  if vaultMode then
    vaultPath := GDVars.currentDataPath + 'vault' + saveLetter + '.dat'
  else
    vaultPath := GDVars.saveDir + 'vault' + saveLetter + '.dat';
  if GDVars.vaultDirty <> 0 then begin
    DaxIo.DeleteIfPresent(vaultPath);
    DaxIo.RenameIfExists(GDVars.saveDir + 'tmpvault.dat', GDVars.saveDir + 'vault' + saveLetter + '.dat');
  end else if GDVars.vaultSaveLetter <> saveLetter then begin
    SaveLoad.LoadVault(hasMoney, hasItems);
    if vaultMode then
      vaultPath := GDVars.currentDataPath + 'vault' + saveLetter + '.dat'
    else
      vaultPath := GDVars.saveDir + 'vault' + saveLetter + '.dat';
    SaveLoad.WriteVaultFile(vaultPath);
  end;
  GDVars.vaultSaveLetter := saveLetter;
  GDVars.vaultDirty := 0;
  GDVars.justSaved := 1;
  MenuCore.ClearBottomLine;
end;

procedure LoadVault(var hasMoney, hasItems: Boolean);
var

  vaultFile: file;
  vaultPath: String;
  diskPrompt: String[40];
  { Unused in this version; see the other implementations of this routine. }
  errorCode: Word;
  itemBuffer: Types.PItemRec;
  bytesRead: Word;
  { Unused in this version; see the other implementations of this routine. }
  ignoredOpenResult: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  vaultFunds: Word;
begin
  hasMoney := False;
  hasItems := False;
  if GDVars.vaultDirty <> 0 then
    vaultPath := GDVars.saveDir + 'tmpVault.dat'
  else if GDVars.vaultSaveLetter = 'Z' then
    vaultPath := GDVars.currentDataPath + 'vault' + GDVars.vaultSaveLetter + '.dat'
  else
    vaultPath := GDVars.saveDir + 'vault' + GDVars.vaultSaveLetter + '.dat';
  if not DaxIo.FileExists(vaultPath) then Exit;
  ignoredOpenResult := DaxIo.OpenWithRetry(vaultPath, diskPrompt, 0, vaultFile);
  BlockRead(vaultFile, GDVars.moneyPool, SizeOf(GDVars.moneyPool), bytesRead);
  hasItems := False;
  GetMem(itemBuffer, SizeOf(Types.TItemRec));
  repeat
    BlockRead(vaultFile, itemBuffer^, SizeOf(Types.TItemRec), bytesRead);
    if bytesRead = SizeOf(Types.TItemRec) then begin
      if GDVars.treasureList = nil then begin
        GetMem(GDVars.treasureList, SizeOf(Types.TItemRec));
        GDVars.treasureList^ := itemBuffer^;
        GDVars.vaultTail := GDVars.treasureList;
      end else begin
        GetMem(GDVars.vaultTail^.next, SizeOf(Types.TItemRec));
        GDVars.vaultTail := GDVars.vaultTail^.next;
        GDVars.vaultTail^ := itemBuffer^;
      end;
      hasItems := True;
    end;
  until bytesRead <> SizeOf(Types.TItemRec);
  Close(vaultFile);
  if GDVars.vaultSaveLetter = 'Z' then
    DaxIo.DeleteIfPresent(vaultPath);
  FreeMem(itemBuffer, SizeOf(Types.TItemRec));
  Exit;
end;

procedure WriteVaultFile(vaultPath: String);
var

  vaultFile: file;
  requiredBytes: Word;
  { Unused in this version; see the other implementations of this routine. }
  oldTail: Types.PItemRec;
begin
  requiredBytes := 0;
  Inc(requiredBytes, SizeOf(GDVars.moneyPool));
  if GDVars.treasureList <> nil then begin
    GDVars.vaultTail := GDVars.treasureList;
    while GDVars.vaultTail <> nil do begin
      Inc(requiredBytes, SizeOf(Types.TItemRec));
      GDVars.vaultTail := GDVars.vaultTail^.next;
    end;
  end;
  DaxIo.DeleteIfPresent(vaultPath);
  if requiredBytes > DiskFree(Ord(UpCase(GDVars.saveDir[1])) - Ord('@')) then begin
    TextRend.DisplayAndPause(14, 0, 'Can''t save.  No room on this disk.');
    TextRend.DisplayAndPause(14, 0, 'Please insert another disk.');
  end;
  Assign(vaultFile, vaultPath);
  Rewrite(vaultFile, 1);
  BlockWrite(vaultFile, GDVars.moneyPool, SizeOf(GDVars.moneyPool));
  GDVars.vaultTail := GDVars.treasureList;
  while GDVars.vaultTail <> nil do begin
    BlockWrite(vaultFile, GDVars.vaultTail^, SizeOf(Types.TItemRec));
    oldTail := GDVars.vaultTail;
    GDVars.vaultTail := GDVars.vaultTail^.next;
  end;
  Close(vaultFile);
  GDVars.vaultDirty := 1;
  CharHlp.ClearEncounterState;
end;

begin
end.
