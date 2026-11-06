{$F+,O-,S-,R-,V+,B-,I-}
program FixMain;
{ The game's main program. It lists every unit and which are overlaid, initializes the game, runs the title sequence and
  title menu, then loops forever: the main menu, the copy-protection check, and the adventure itself. A command-line
  argument of 1 skips the title and menus and loads a saved game straight away. When the title menu is left untouched
  until it times out, the game plays itself as a demo: GDVars.demoMode is set, so key reads do not wait, and the title
  returns once the demo ends. }

uses
  Overlay, Dos, Crt, ModeInit, Joystick, Mouse, SoundDrv, MusDrv, GameIo,
  DaxIo, ZeroFree, Music, TextRend, Blit, GameBoot, Border,
  Sym8x8, MapTiles, CbtMap, Pathing, EmptyC, View3D, Portrait, MapView, MenuCore, ClassCal, MapWin,
  CharHlp, FxEngine, Magic, Money, GameTime, ViewChar, CbtActs, EffHndlr, GameInit, SaveLoad,
  CharGen, Camp, Explore, CombatSt, CombatAi, Combat, EclMenu, Shop, PostCbt, Temple,
  CopyProt, Vault, ExitDos, EclVm, Intro, HeapErr, Types,
  GDConsts, GDVars,
  C_Ifc, C_Sound;

{$O Intro} {$O EclVm} {$O ExitDos} {$O Vault} {$O CopyProt}
{$O Temple} {$O PostCbt} {$O Shop} {$O EclMenu} {$O Combat}
{$O CombatAi} {$O CombatSt} {$O Explore} {$O Camp} {$O SaveLoad}
{$O CharGen} {$O GameInit} {$O EffHndlr} {$O CbtActs} {$O ViewChar}
{$O GameTime} {$O Money} {$O Magic} {$O FxEngine} {$O CharHlp}
{$O MapWin} {$O ClassCal} {$O MenuCore} {$O MapView} {$O Portrait}
{$O View3D} {$O Pathing} {$O CbtMap} {$O MapTiles} {$O Sym8x8}

begin
  GameInit.InitializeGame;
  Music.LoadDriverCode;
  if ParamStr(1) <> '1' then begin
    GDVars.gameInProgress := 0;
    Intro.Introduction;
    CharHlp.ClearEncounterState;
    GDVars.menuAutoDelay := 3000;
    GDVars.menuAutoKey := 1;
    MenuCore.ResetMenuSlots(1);
    GDVars.menuResult := MenuCore.MenuHorizontal(GDConsts.versionBanner, GDConsts.playDemoMenu, False, False);
    Blit.SetDacPalette(16, 16, GDVars.mainPal);
    GDVars.menuAutoDelay := 0;
    GDVars.menuAutoKey := 1;
    GDVars.skipMenus := 0;
  end else begin
    GDVars.skipMenus := 1;
    SaveLoad.LoadGame(True);
    GDVars.interfaceState := GDVars.savedInterfaceState;
    CharHlp.DisplayNoncombatInterface;
  end;
  if GDVars.menuResult = #1 then GDVars.demoMode := True;
{ One pass per game, or per run of the demo. }
repeat
  Music.StopMusic;
  Blit.SetDacPalette(16, 16, GDVars.mainPal);
  if GDVars.demoMode then GDVars.vmBand.zone0^.gameDelay := 9
  else GDVars.gameInProgress := 1;
  if not GDVars.demoMode then
    if GDVars.skipMenus = 0 then begin
      CharGen.MainMenu;
      if CopyProt.CopyProtection <> True then GameIo.ExitGame(0);
      for GDVars.protectionIndex := 1 to 4 do
        if GDVars.protectionFlags.flags[GDVars.protectionIndex] = 0 then
          GameIo.ExitGame(0);
      if (GDVars.interfaceState = AREA_MAP) and (GDVars.vmBand.zone0^.mapPaneEnabled = 1) then
        Border.ScreenText
      else Border.DrawExploreFrame;
      CharHlp.DisplayParty(GDVars.currentChar);
    end;
  { Run the adventure. }
  View3D.SetView3DColors(GDVars.viewSkyColor, GDVars.viewHorizonColor1, GDVars.viewHorizonColor2,
                         GDVars.viewFloorColor);
  EclVm.GameLoop;
  GameInit.ResetGameState;
  if GDVars.demoMode then begin
    Music.SendSoundCommand(GDConsts.soundReset);
    Intro.Introduction;
    Music.RestoreSoundDriver;
    GameIo.FlushKeys;
    GDVars.menuAutoDelay := 5000;
    GDVars.menuAutoKey := 1;
    MenuCore.ResetMenuSlots(1);
    GDVars.menuResult := MenuCore.MenuHorizontal(GDConsts.versionBanner, GDConsts.playDemoMenu, False, False);
    GDVars.menuAutoDelay := 0;
    GDVars.menuAutoKey := 0;
    GDVars.demoMode := GDVars.menuResult = #1;
    Music.SendSoundCommand(GDConsts.soundIds[OFF]);
  end;
until False;
end.
