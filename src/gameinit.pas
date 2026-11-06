{ Game startup and restart.

  InitializeGame runs once at startup. It allocates the long-lived buffers (the ECL zones, font, wall graphics, map
  geometry, music driver buffers, item definitions and sound staging), programs the base 16-color palette, builds Blit's
  image objects and the per-scanline row tables for the active display mode, sets up the mouse and joystick, puts every
  subsystem's state at its default, loads the font, the two 8x8 symbol sets, the cursor image and the ITEMS sprite
  sheet, sets up the Magic and EffHndlr dispatch tables, and loads the item and sound definitions.

  ResetGameState puts the same game state back at its defaults for a new game without allocating or loading anything,
  and clears the bottom line. }
{$O+,F+,S-,R-,V-,B-,I-}
unit GameInit;

interface

{ Allocates, loads and sets to its default everything the game needs before the first menu. Runs once, at startup. }
procedure InitializeGame;

{ Puts the game state back at its startup defaults for a new game, and clears the bottom line; nothing is allocated or
  loaded. }
procedure ResetGameState;

implementation

uses Crt, Blit, GameIo, Mouse, TextRend, DaxIo, ZeroFree, EffHndlr, Magic, MenuCore, Sym8x8, Types, GDConsts, GDVars,
  C_Dir, C_Ifc, C_Video, C_Driver;

var

  { BIOS keyboard-flags byte }
  biosKeyboardFlags: Byte absolute $0000:$0417;

{ Fills the item definition table with $FF, then copies the 17-byte records of ITEM0.DAX resource 1 into it, at most
  254, and frees the loaded data. A missing item file is fatal. }
procedure LoadItems;
var
  rawSize: Word;
  { read position in the loaded data }
  counter: Word;
  idx: Byte;
  raw: Types.PBytes;
  rec: Types.TItemDef;
begin
  FillChar(GDVars.itemDefBlock^, SizeOf(Types.TItemDefs), $FF);
  DaxIo.LoadDax('ITEM0', '.dax', 1, rawSize, raw);
  if rawSize = 0 then begin
    TextRend.DisplayAndPause(15, 0, 'Unable to find item file');
    GameIo.ExitGame(0);
  end;
  counter := 0;
  idx := 1;
  repeat
    Move(raw^[counter], rec, SizeOf(rec));
    GDVars.itemDefBlock^[idx] := rec;
    Inc(idx);
    Inc(counter, SizeOf(rec));
  until (counter >= rawSize) or (idx > 254);
  ZeroFree.PrefixFree(raw, rawSize);
end;

{ Clear the sound table, then load zounds resources 1 to 11 into it, LoadDax filling each entry's size and data. A
  missing sound is fatal. }
procedure LoadSoundDefs;
var
  idx: Byte;
begin
  GameIo.ZeroFill(GDVars.loadedSounds, SizeOf(GDVars.loadedSounds));
  for idx := 1 to 11 do
    with GDVars.loadedSounds[idx] do begin
      DaxIo.LoadDax('zounds', '.dax', idx, size, Types.PBytes(data));
      if size = 0 then begin
        TextRend.DisplayAndPause(15, 0, 'unable to load sound');
        GameIo.ExitGame(0);
      end;
    end;
end;

procedure InitializeGame;
var
  { Unused in this version; see the other implementations of this routine. }
  messageText: String;
begin
  { Base 16-color palette: copy the default table into GDVars.imagePal, save the current colors into both backup
    palettes, then program the DAC. }
  for GDVars.startupIdx := 0 to 15 do begin
    for GDVars.rgbIdx := 0 to 2 do
      GDVars.imagePal[GDVars.startupIdx][GDVars.rgbIdx] := GDConsts.defaultPalette16[GDVars.startupIdx][GDVars.rgbIdx];
    GDVars.palIndexMap[GDVars.startupIdx] := GDVars.startupIdx;
  end;
  Blit.ShadowPaletteEntries(0, 16, GDVars.backupPal);
  Blit.ShadowPaletteEntries(0, 16, GDVars.mainPal);
  Blit.SetDacPalette(0, 16, GDVars.imagePal);

  { Force Num Lock on via the BIOS keyboard-flags byte, then reseed the RNG. }
  biosKeyboardFlags := biosKeyboardFlags or $20;
  Randomize;

  { Probe the mouse: park it at x 639 and read it back; a driver that reports x below 321 works in raw 320-wide
    coordinates. Then center it. }
  if GDVars.mouseInstalled then begin
    GDVars.mouseMenuMode := 1;
    GDVars.mouseButtonCount := 0;
    Mouse.InitMouse;
    if GDVars.mouseInstalled then begin
      GDVars.mouseRawX := True;
      GDVars.mouseCursorMask := @GDConsts.mouseCursor;
      Mouse.SetMouseCursor(0, 0, GDVars.mouseCursorMask);
      Mouse.SetMouse(639, 100);
      Mouse.GetMouse(GDVars.probeButtons, GDVars.probeX, GDVars.probeY);
      GDVars.mouseRawX := (GDVars.probeX >= 321) = False;
      Mouse.ShowMouse;
    end;
    GDVars.mousePosX := 160;
    GDVars.mousePosY := 100;
    Mouse.SetMouse(GDVars.mousePosX, GDVars.mousePosY);
    GDVars.mousePrevX := 0;
    GDVars.mousePrevY := 0;
  end;
  if GDVars.joystickInstalled then begin
    GDVars.joyCursorX := 160;
    GDVars.joyCursorY := 100;
  end;

  GetMem(GDVars.vmBand.zone0, SizeOf(Types.TGbvmBank0));
  GetMem(GDVars.vmBand.zone3, SizeOf(Types.TZone3));
  GetMem(GDVars.gameFont, 1416);
  GetMem(GDVars.wallGfx, 2340);
  GetMem(GDVars.map3d, 1024);

  Blit.AllocPic(8, 1, 1, 0, GDVars.current8x8Symbol);
  Blit.AllocPic(8, 1, 1, 0, GDVars.mapWinBackdrop);
  Blit.AllocPic(8, 1, 1, 0, GDVars.mapWinImage);
  GDVars.mapWinOverlay := nil;
  Blit.AllocPic(168, 21, 1, 0, GDVars.viewImageBuf);
  Blit.AllocPic(24, 3, 1, 0, GDVars.iconSaveBuf);

  GameIo.ZeroFill(GDVars.spanRowActive, SizeOf(GDVars.spanRowActive));
  GameIo.ZeroFill(GDVars.spanRowActive, SizeOf(GDVars.spanRowActive));
  GameIo.ZeroFill(GDVars.spanScreenOfs, SizeOf(GDVars.spanScreenOfs));
  FillChar(GDVars.spanFirstOfs, SizeOf(GDVars.spanFirstOfs), $FF);
  GameIo.ZeroFill(GDVars.spanLastOfs, SizeOf(GDVars.spanLastOfs));

  case GDVars.videoMode of
    C_Video.DISPLAY_EGA: begin
      GDVars.rowAddr := 0;
      for GDVars.startupIdx := 0 to 199 do begin
        GDVars.fbRowOfs[GDVars.startupIdx] := GDVars.rowAddr;
        Inc(GDVars.rowAddr, 40);
      end;
    end;
    C_Video.DISPLAY_TANDY: begin
      GDVars.startupIdx := 0;
      GDVars.rowAddr := 0;
      while GDVars.startupIdx <= 199 do begin
        GDVars.tandyRowSeg[GDVars.startupIdx] := GDVars.rowAddr + $B800;
        Inc(GDVars.startupIdx);
        GDVars.tandyRowSeg[GDVars.startupIdx] := GDVars.rowAddr + $BA00;
        Inc(GDVars.startupIdx);
        GDVars.tandyRowSeg[GDVars.startupIdx] := GDVars.rowAddr + $BC00;
        Inc(GDVars.startupIdx);
        GDVars.tandyRowSeg[GDVars.startupIdx] := GDVars.rowAddr + $BE00;
        Inc(GDVars.startupIdx);
        GDVars.rowAddr := GDVars.rowAddr + 10;
      end;
    end;
  end;

  GameIo.ZeroFill(GDVars.symbolSets, SizeOf(GDVars.symbolSets));
  GameIo.ZeroFill(GDVars.mapTileSheet, SizeOf(GDVars.mapTileSheet));

  GameIo.ZeroFill(GDVars.backdropPicture, SizeOf(GDVars.backdropPicture) + SizeOf(GDVars.skyPicture));
  GDVars.prevSkyId := 0;
  GDVars.curSkyId := 0;
  GameIo.ZeroFill(GDVars.vmBand.zone0^, SizeOf(Types.TGbvmBank0));
  GDVars.vmBand.zone0^.difficulty := 3;
  GDVars.vmBand.zone0^.inDungeon := 1;
  GDVars.vmBand.zone0^.areaScriptId := 0;
  GDVars.vmBand.zone0^.printColor := 10;
  GameIo.ZeroFill(GDVars.vmBand.zone3^, SizeOf(Types.TZone3));
  GameIo.ZeroFill(GDVars.iconAnimTable, SizeOf(GDVars.iconAnimTable));
  GameIo.ZeroFill(GDVars.animFramesTail, SizeOf(GDVars.animFramesTail));
  { Note: 40 bytes from a 36-byte array, so GDVars.vgaFrameImage is cleared as well. }
  GameIo.ZeroFill(GDVars.vgaFrameBufs, 40);
  GameIo.ZeroFill(GDVars.animFrames, SizeOf(GDVars.animFrames));
  GameIo.ZeroFill(GDVars.animFrameDelays,
                  SizeOf(GDVars.animFrameDelays) + SizeOf(GDVars.animFrameSizes) + SizeOf(GDVars.animKeyFrame) +
                  SizeOf(GDVars.animFirstFrame) + SizeOf(GDVars.animLastFrame) + SizeOf(GDVars.animCurFrame));
  GDVars.bigPicImage := nil;
  GDVars.treasureList := nil;

  GameIo.ZeroFill(GDVars.mapState, SizeOf(GDVars.mapState));
  GDVars.mapState.x := 7;
  GDVars.mapState.y := 13;
  GDVars.mapState.facing := C_Dir.NORTH;
  GameIo.ZeroFill(GDVars.loadedWallSet, SizeOf(GDVars.loadedWallSet));
  GDVars.menuQueryColor := 13;
  GDVars.menuTextColor := 10;
  GDVars.menuHighlightColor := 15;
  GDVars.gameLoaded := 1;
  GDVars.msgDelayFlag := True;
  GDVars.savedGameLoaded := 0;
  GDVars.restTicks := 0;
  GDVars.creatureListHead := nil;
  GDVars.currentChar := nil;
  GDVars.highlightedChar := nil;
  GDVars.castTarget := nil;
  GDVars.vmBand.eclIp := $8000;
  GDVars.vmBand.zone0^.gameDelay := 4;
  GDVars.demoMode := False;
  GDVars.automapShown := 0;
  LastMode := 1;
  GDVars.vmBand.zone0^.partySize := 0;
  GDVars.vertMenuTop := 1;
  GDVars.suppressBorder := 0;
  GDVars.savedSearching := 0;
  GDVars.clearBoxDone := 0;
  GDVars.protNewLine := 0;
  GDVars.eclPicShown := False;
  GDVars.partyDefeatedFlag := False;
  GDVars.clipFlag := 1;
  GDVars.monSpriteShown := 0;
  GDVars.suppressDiskPrompt := 0;
  GDVars.picArcName := '';
  GDVars.savedResourceName[0] := #0;
  GDVars.picArcId := $FF;
  GDVars.savedResourceId := $FF;
  GDVars.justSaved := 0;
  GDVars.ceilFloorColorSel := $E8;
  GDVars.wallColorSel := $DB;
  GDVars.inEncMenu := 0;
  GDVars.charSelectMode := 0;
  GDVars.combatGfxOn := 1;
  GDVars.bigPicId := $FF;
  GDVars.sharedScratch.trainMode := 0;
  GDVars.horizMenuChoice := 1;
  GDVars.interfaceState := C_Ifc.DUNGEON;
  GDVars.savedInterfaceState := C_Ifc.MAIN_MENU;
  GDVars.sharedScratch.itemEffectOverride := 0;
  GDVars.partyPanelHidden := 0;
  GDVars.secondWallSet := 0;
  GDVars.thirdWallSet := 0;
  GDVars.fourthWallSet := 0;
  GDVars.panelRestorePendingTail := 0;
  GDVars.manualMoveActive := 0;
  GDVars.aimCursorOn := 0;
  GDVars.clickInputMode := 0;
  GDVars.keyFromMouse := 0;
  GDVars.sharedScratch.modifyActive := 0;
  GDVars.agingPending := 0;
  GDVars.debugEnabled := 1;
  GDVars.savedDriverState := C_Driver.NO_DRIVER;
  GDVars.driverState := C_Driver.NO_DRIVER;
  GDVars.drvImageLoaded := 0;
  GDVars.drvParamsDaxId := $FF;
  GDVars.restState.fixBusy := 0;
  GDVars.palettePresetOn := 0;
  GDVars.vaultDirty := 0;
  GDVars.monstersLoaded := 0;

  TextRend.LoadGameFont;
  TextRend.DisplayLoading;
  Sym8x8.Load8x8Set(202, 1);
  Sym8x8.Load8x8Set(0, 2);
  Blit.ShadowPaletteEntries(16, 16, GDVars.mainPal);
  Blit.SetDacPalette(16, 16, GDVars.imagePal);
  Blit.LoadPic('cursor', 1, 1, 13, GDVars.mapWinOverlay);

  GDVars.itemsOk := DaxIo.OpenWithRetry('ITEMS', GDConsts.insertDisk2Prompt, 0, GDVars.itemsFile);
  Reset(GDVars.itemsFile, 1);
  BlockRead(GDVars.itemsFile, GDVars.baseItemTable, SizeOf(GDVars.baseItemTable), GDVars.itemsBytesRead);
  Close(GDVars.itemsFile);

  GameIo.ZeroFill(GDVars.workSlots, SizeOf(GDVars.workSlots));
  GDVars.backdropPalActive := False;
  GDVars.viewPaletteDirty := False;
  Magic.InitSpellFns;
  EffHndlr.InitEffectHandlers;

  GetMem(GDVars.itemDefBlock, SizeOf(Types.TItemDefs));
  GameInit.LoadItems;
  GetMem(GDVars.soundStagingBuf, 9000);
  GameInit.LoadSoundDefs;
  GDVars.drvImageBuffer := nil;
  GDVars.drvParamsBuffer := nil;
  GetMem(GDVars.drvImageBuffer, 13000);
  GetMem(GDVars.drvParamsBuffer, 6144);
end;

procedure ResetGameState;
begin
  GameIo.ZeroFill(GDVars.spanRowActive, SizeOf(GDVars.spanRowActive));
  GameIo.ZeroFill(GDVars.spanScreenOfs, SizeOf(GDVars.spanScreenOfs));
  FillChar(GDVars.spanFirstOfs, SizeOf(GDVars.spanFirstOfs), $FF);
  GameIo.ZeroFill(GDVars.spanLastOfs, SizeOf(GDVars.spanLastOfs));
  GameIo.ZeroFill(GDVars.vmBand.zone0^, SizeOf(Types.TGbvmBank0));
  GDVars.vmBand.zone0^.difficulty := 3;
  GDVars.vmBand.zone0^.inDungeon := 1;
  GDVars.vmBand.zone0^.areaScriptId := 0;
  GDVars.vmBand.zone0^.printColor := 10;
  GameIo.ZeroFill(GDVars.vmBand.zone3^, SizeOf(Types.TZone3));
  GameIo.ZeroFill(GDVars.mapState, SizeOf(GDVars.mapState));
  GDVars.mapState.x := 7;
  GDVars.mapState.y := 13;
  GDVars.mapState.facing := C_Dir.EAST;
  GDVars.mouseMenuMode := 1;
  GameIo.ZeroFill(GDVars.loadedWallSet, SizeOf(GDVars.loadedWallSet));
  GDVars.msgDelayFlag := True;
  GDVars.savedGameLoaded := 0;
  GDVars.restTicks := 0;
  GDVars.creatureListHead := nil;
  GDVars.currentChar := nil;
  GDVars.highlightedChar := nil;
  GDVars.vmBand.eclIp := $8000;
  GDVars.vmBand.zone0^.gameDelay := 4;
  GDVars.automapShown := 0;
  LastMode := 1;
  GDVars.vmBand.zone0^.partySize := 0;
  GDVars.vertMenuTop := 1;
  GDVars.suppressBorder := 0;
  GDVars.savedSearching := 0;
  GDVars.clearBoxDone := 0;
  GDVars.protNewLine := 0;
  GDVars.eclPicShown := False;
  GDVars.partyDefeatedFlag := False;
  GDVars.clipFlag := 1;
  GDVars.monSpriteShown := 0;
  GDVars.suppressDiskPrompt := 0;
  GDVars.picArcName := '';
  GDVars.savedResourceName[0] := #0;
  GDVars.picArcId := $FF;
  GDVars.savedResourceId := $FF;
  GDVars.justSaved := 0;
  GDVars.ceilFloorColorSel := $E8;
  GDVars.wallColorSel := $DB;
  GDVars.inEncMenu := 0;
  GDVars.combatGfxOn := 1;
  GDVars.bigPicId := $FF;
  GDVars.sharedScratch.trainMode := 0;
  MenuCore.ClearBottomLine;
  GDVars.horizMenuChoice := 1;
  GDVars.interfaceState := C_Ifc.DUNGEON;
  GDVars.savedInterfaceState := C_Ifc.MAIN_MENU;
  GDVars.sharedScratch.itemEffectOverride := 0;
  GDVars.panelRestorePendingTail := 0;
  GDVars.manualMoveActive := 0;
  GDVars.aimCursorOn := 0;
  GDVars.clickInputMode := 0;
  GDVars.keyFromMouse := 0;
  GDVars.charSelectMode := 0;
  GDVars.sharedScratch.modifyActive := 0;
  GDVars.partyPanelHidden := 0;
  GDVars.agingPending := 0;
  GDVars.turnUndeadLimitTail := 0;
  GDVars.vaultDirty := 0;
  GDVars.monstersLoaded := 0;
end;

begin
end.
