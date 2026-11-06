{ Global variables: every variable in the data segment, grouped in sections by the subsystem that owns them and kept in
  address order. A new section starts wherever the data needs a word boundary. }
unit GDVars;

interface

uses Types;

{ The main loop's title menu, and the title picture Intro shows. }
var
  { the key the title menu returned; #1 starts the demo }
  menuResult: Char;
  { FixMain's loop over the four copy-protection flags }
  protectionIndex: Byte;
  { unused }
  titleImageLead: Byte;
  { the title picture, loaded, shown and freed by Intro }
  titleImage: Types.PImage;

{ The script interpreter's run state. }
var
  { set to stop CallEclScript }
  loopRunning: Byte;
  { set when a script has moved the party to a new area or script }
  areaExitFlag: Boolean;
  { EXIT restores the saved character }
  pendingCharSwap: Boolean;
  { the character EXIT restores }
  pendingChar: Types.PCharRecord;

{ The copy-protection check: the word asked for and the answer typed. }
var
  { the decoded journal word the player must type }
  expectedWord: String;
  { what the player typed }
  enteredWord: String;
  { the try being made, 1..3 }
  attemptNumber: Byte;

{ The copy-protection challenge being asked. }
var
  { the journal entry asked about }
  challengeIndex: Byte;
  { which of the entry's words is asked for }
  wordSlot: Byte;
  { unused }
  wordSlotTail: Byte;

{ The end of a fight, and the shop's menu. }
var
  { there were monsters to defeat }
  monstersKilled: Boolean;
  { set when a party member ran from the fight }
  partyFled: Boolean;
  { the defeated monsters left coins }
  treasureHasMoney: Boolean;
  { the defeated monsters left items }
  treasureHasItems: Boolean;
  { MenuVertical's redraw flag }
  menuNeedsRedraw: Boolean;

{ The combat AI's movement. }
var
  { direction of the last step, for the back-and-forth test }
  lastMoveDir: Byte;
  { times this turn the creature has stalled or reversed }
  stuckCount: Byte;
  { unused: cleared at the start of AiMoveAttack, never read }
  stuckCountTail: Byte;

{ Combat set-up: placing the two teams on the arena and drawing its walls. }
var
  { The placement cells still free, by [team, ring, row, column]; 1 is free. }
  quadFree: array[0..1, 0..3, 0..5, 0..10] of Byte;
  { each team's base square column, relative to the party }
  placeX: array[0..1] of ShortInt;
  { each team's base square row, relative to the party }
  placeY: array[0..1] of ShortInt;
  { each team's placement tries on the first pass of a ring }
  teamRows: array[0..1] of ShortInt;
  { each team's facing, as a quarter turn 0..3 }
  teamDir: array[0..1] of ShortInt;
  { the column of the dungeon square being drawn, relative to the party }
  dx: ShortInt;
  { the row of the dungeon square being drawn, relative to the party }
  dy: ShortInt;
  { The wall kind on that square's north side: 0 open, 1 solid, 3 any other wall. }
  wallN: Byte;
  { the west side's wall kind }
  wallW: Byte;
  { the east side's wall kind }
  wallE: Byte;
  { the south side's kind, found but not used }
  wallS: Byte;
  { the team being placed: 0 the party's side, 1 the other }
  team: ShortInt;

{ The wilderness terrain under a fight. }
var
  { the wilderness terrain under the party }
  terrainChar: Byte;
  { unused }
  terrainCharTail: array[0..5] of Byte;

{ Start-up: GameInit's loops, the mouse probe and the ITEMS file. }
var
  { loop index shared by the startup loops }
  startupIdx: Byte;
  { palette-copy inner loop index }
  rgbIdx: Byte;
  { OpenWithRetry result for the ITEMS file }
  itemsOk: Boolean;
  { unused }
  itemsOkTail: array[0..42] of Byte;
  { mouse buttons, read while probing the driver }
  probeButtons: Integer;
  { mouse x }
  probeX: Integer;
  { mouse y }
  probeY: Integer;
  { the ITEMS sprite sheet }
  itemsFile: file;
  { unused }
  itemsFileTail: Byte;
  { row address accumulator while filling the row tables }
  rowAddr: Word;

{ The character sheet, timed effects and the spell selector. }
var
  { the character the sheet shows, and the one it trades with }
  globals: Types.TSheetGlobals;
  { Per party member: nonzero while its timed effects still need aging. }
  effectFlags: array[1..72] of Byte;
  { The spell selector's list: the menu lines, then per spell line its count, its spell id and the scroll it is on. }
  selectorVars: record
    spellList: Types.PMenuLine;
    spellCounts: array[0..140] of Byte;
    spellIds: array[0..140] of Byte;
    scrollPtrs: array[0..48] of Pointer;
    scrollCount: Byte;
  end;
  { Scratch value the spell handlers share. }
  spellTemp1: Byte;
  { a second scratch value the spell handlers share; set from the spell's variant before the effect is added }
  spellTemp2: Byte;

{ Start-up: the encumbrance total, the Tandy screen, and reading pool4.cfg. }
var
  { weight of the equipped items, summed by RecalcStats }
  runTotal: Word;
  { HeapEnd lowered to make room for the Tandy screen }
  tandyHeapEnd: Pointer;
  { unused }
  tandyHeapEndTail: Byte;
  { the one-letter or one-digit answer on the current cfg line }
  configCode: Char;
  { unused }
  configCodeTail: Byte;
  { pool4.cfg, which STARTUP wrote }
  configFile: Text;
  { unused }
  configFileTail: array[0..128] of Byte;
  { the joystick calibration line being read from the cfg }
  calibrationIndex: Byte;
  { unused }
  calibrationIndexTail: array[0..80] of Byte;
  { the running program's name, from FSplit }
  executableName: String[8];
  { and its extension }
  executableExtension: String[4];
  { unused }
  executableExtensionTail: array[0..80] of Byte;

{ Where the data files are. GameBoot sets all three at startup; OpenWithRetry swaps the two paths when a file is found
  only on the other one. }
var
  { directory searched first for data files }
  currentDataPath: String[79];
  { directory tried when a file is missing from currentDataPath }
  alternateDataPath: String[79];
  { the drive letter a floppy prompt names }
  promptDrive: Char;

{ The music driver's last answer. }
var
  { what the driver returned from the last request }
  lastDriverResult: Word;
  { unused }
  lastDriverResultTail: array[0..3] of Byte;

{ The session: the script machine's zones, which screen is up, and the game's demo, load and defeat flags. }
var
  { the ECL VM's zone pointers, run addresses and instruction pointer }
  vmBand: Types.TVmBand;
  { which screen is up: 3 the area map, 4 a 3D area, 5 combat }
  interfaceState: Byte;
  { interfaceState put aside across a screen change }
  savedInterfaceState: Byte;
  { set while the demo runs; the input routines then return without waiting for a key }
  demoMode: Boolean;
  { the party panel is not drawn while set }
  partyPanelHidden: Byte;
  { set once a game has been started or loaded }
  gameLoaded: Byte;
  { set when a saved game has just been restored; the script's first step clears it }
  savedGameLoaded: Byte;
  { rest's count toward vmBand.zone0^.restPeriod }
  restTicks: Word;
  { set when the whole party is down or gone }
  partyDefeatedFlag: Boolean;
  { set when a fight ends; DisplayMessageWindow then paces each character }
  msgDelayFlag: Boolean;
  { set once a real game, not the demo, is under way; HeapErr saves the party only then }
  gameInProgress: Byte;

{ The video hardware: interrupt registers, EGA pages and the display mode. }
var
  { the register block for the BIOS and DOS calls }
  interruptRegs: Types.TRegisters;
  { the segment of the EGA page being drawn on }
  egaCurPage: Word;
  { the segment of the EGA page on show }
  egaOtherPage: Word;
  { TextRend: page number currently selected for drawing }
  drawPageNum: Byte;
  { the EGA page on show }
  shownPageNum: Byte;
  { Blit: BIOS video mode in effect before the last SetVideoMode }
  savedVideoMode: Byte;
  { the BIOS video mode SetVideoMode last set }
  curVideoMode: Byte;
  { The display class chosen at startup: 0 EGA planar, 1 Tandy 4-bank, 2 MCGA linear. }
  videoMode: Byte;

{ The screen buffers: the view surface, the icon save area, Blit's deferred spans and the scanline address tables. }
var
  { the off-screen view picture the 3-D view and the arena are drawn into }
  viewImageBuf: Types.PImage;
  { the pixels a clipped blit covered, kept so the caller can put them back }
  iconSaveBuf: Types.PImage;
  { unused }
  iconSaveBufTail: array[0..15] of Byte;
  { Blit's four deferred-span tables, one slot per scanline of the view surface; Blit describes them. This one marks the
    rows with a span waiting. }
  spanRowActive: array[0..167] of Byte;
  { the screen offset each waiting span is copied to }
  spanScreenOfs: array[0..167] of Word;
  { the lowest source offset a row's span covers }
  spanFirstOfs: array[0..167] of Word;
  { the highest source offset a row's span covers }
  spanLastOfs: array[0..167] of Word;
  { unused }
  spanLastOfsTail: array[0..671] of Byte;
  { The per-scanline video address tables, filled by GameInit for the active class: fbRowOfs is the EGA byte offset of
    each scanline in video memory, tandyRowSeg the Tandy segment of each scanline. }
  fbRowOfs: array[0..199] of Word;
  { the Tandy segment of each scanline }
  tandyRowSeg: array[0..199] of Word;
  { set to 1 by GameInit, never read }
  clipFlag: Byte;

{ Sound: the device, and the music driver Music loads and MusDrv calls. }
var
  { Music: the sound device; C_Sound.MUTED while sound is off }
  soundDevice: Byte;
  { the sound device put aside while sound is toggled off }
  savedSoundMode: Byte;
  { the developer switch; GameIo toggles it }
  debugEnabled: Byte;
  { reserved }
  debugEnabledTail: array[0..7] of Byte;
  { the linear address the driver image is copied to }
  drvLoadAddress: LongInt;
  { the size of the driver image read from MUSIC.DAX }
  drvImageSize: Word;
  { the driver's parameter block }
  drvParams: Pointer;
  { the size of the parameter block read from MUSIC.DAX }
  drvParamsSize: Word;
  { DaxIo: driverState as it was when DiskBegin ran }
  savedDriverState: Byte;
  { Music: the driver state, a C_Driver value }
  driverState: Byte;
  { set once the driver image is in place }
  drvImageLoaded: Byte;
  { the memory holding the driver image }
  drvImageBuffer: Types.PBytes;
  { the memory holding the parameter block }
  drvParamsBuffer: Types.PBytes;
  { Music: the parameter block the installed driver was given }
  drvParamsDaxId: Byte;
  { the driver's entry point, called far for every event }
  drvEntry: Types.TDrvProc;
  { the offset of the parameter block passed with the initialize event }
  drvParamsOfs: Word;
  { and its segment }
  drvParamsSeg: Word;

{ Save and import directories, and the disk prompts. }
var
  { the directory characters are imported from }
  importDir: String;
  { GameBoot: cfg's first path: the game's own save directory }
  saveDir: String;
  { set while OpenWithRetry must not ask for a disk }
  suppressDiskPrompt: Byte;
  { set just after a save; cleared by the next menu choice that is not a save }
  justSaved: Byte;

{ Items and characters: the base-item table, the roster, the character in hand, and the item files. }
var
  { the base-item table }
  baseItemTable: array[0..128] of Types.TBaseItem;
  { the last spell target, offered first the next time }
  castTarget: Types.PCharRecord;
  { the character SelectChar draws highlighted }
  highlightedChar: Types.PCharRecord;
  { the character being acted on }
  currentChar: Types.PCharRecord;
  { the first creature of the roster: the party, then any monsters }
  creatureListHead: Types.PCharRecord;
  { the character a mouse click picked }
  clickedChar: Types.PCharRecord;
  { CbtActs: the last missile item; MakeAttack also stops its walk of the treasure pile here }
  lastMissileItem: Types.PItemRec;
  { Combat: AgingDeaths runs when it is non-zero, and clears it at its tail }
  agingPending: Byte;
  { the item definitions read from ITEMS, by item id }
  itemDefBlock: Types.PItemDefs;
  { the file DaxIo renames and erases }
  scratchFile: file;
  { the bytes BlockRead returned from ITEMS }
  itemsBytesRead: Word;

{ Text: the font, the glyph being drawn, the message window's cursor and the active pane. }
var
  { the 8x8 font }
  gameFont: Types.PBytes;
  { TextRend: The 8 rows of the glyph being drawn, staged by RenderChar for the EGA and Tandy blitters. }
  glyphRowBuf: array[0..7] of Byte;
  { TextRend: The word-wrap cursor is global rather than local to DisplayMessageWindow, so a paragraph resumes where the
    previous one stopped as long as that position lies inside the new rectangle. }
  textCursorCol: Byte;
  { FxEngine: row of the text cursor in the message window }
  textCursorRow: Byte;
  { reserved }
  textCursorRowTail: array[0..2] of Byte;
  { the pane rectangle Border clears and writes into }
  activePane: Types.TPaneRect;
  { unused }
  activePaneTail: array[0..12] of Byte;

{ Symbol, tile and icon pictures. }
var
  { the three 8x8 symbol sets }
  symbolSets: array[0..2] of Types.PImage;
  { the 8x8 picture one symbol is copied into to be shown }
  current8x8Symbol: Types.PImage;
  { what lay under the map window, put back when it moves }
  mapWinBackdrop: Types.PImage;
  { the map window as composed before it is shown }
  mapWinImage: Types.PImage;
  { the 24x24 tile set the area map and the arena draw from }
  mapTileSheet: Types.PImage;
  { the combat icons' animation pictures, two per icon }
  iconAnimTable: array[0..37, 0..1] of Types.PImage;

{ The combat arena: combatants, their cells, the downed and the targets in reach. }
var
  { CombatSt: the combat slot count, advanced as creatures are placed }
  arenaCount: Byte;
  { CbtMap: Each combatant's arena cell and icon size, by combat slot; a size of 0 means not on the map. }
  arenaSlots: array[1..72] of Types.TArenaEntity;
  { each combatant's column in the view, by combat slot }
  arenaGridX: array[1..72] of ShortInt;
  { each combatant's row in the view, by combat slot }
  arenaGridY: array[1..72] of ShortInt;
  { the combat slot standing on each arena cell, 0 for none }
  arenaCellSlot: array[0..24, 0..49] of Byte;
  { the creature in each combat slot }
  slotCreatures: array[1..72] of Types.PCharRecord;
  { CombatSt: party members lying on the arena, with their cells }
  downedList: array[1..8] of Types.TDownedRec;
  { the entries of downedList in use }
  downedListCount: Byte;
  { the arena map }
  arenaPtr: Types.PCombatMap;
  { CbtActs: Pathing.BuildTargetList's result count }
  rankedTargetCount: Byte;
  { Pathing.BuildTargetList's results, rankedTargetCount entries in rank order. }
  rankedTargets: array[1..72] of Types.TApproachResult;

{ Treasure: the pooled money and the item pile. }
var
  { the pooled money: platinum, gems and jewelry }
  moneyPool: Types.TMoney;
  { EclVm: treasure to hand out, or a store's stock }
  treasureList: Types.PItemRec;

{ The attack and effect being resolved. }
var
  { the in-play creatures on each side }
  teamCount: array[0..1] of Byte;
  { the last saving-throw roll, after the effects' modifiers }
  modifiedSaveRoll: Byte;
  { FxEngine: effect being applied; a handler clears it to block it }
  pendingEffectId: Byte;
  { the element of the attack: 1 fire, 2 cold, 4 electricity, 8 magic }
  elementMask: Byte;
  { The attacks a creature gets this round; haste doubles it and slow halves it. }
  attackRate: Byte;
  { the moves a creature gets this round, after the effects' changes }
  movementRate: Byte;
  { the spell behind the current effect, or the special attack being made }
  spellBeingCast: Byte;
  { the dice count of the last damage roll }
  gDamageDice: Byte;

{ The damage and saving throw being resolved, and the effect handlers. }
var
  { damage about to be dealt; handlers may reduce or cancel it }
  pendingDamage: Integer;
  { Set by a target or attacker veto effect to forbid the attack. }
  attackVetoed: Byte;
  { set while an effect is being applied, so it is not applied again }
  effectLock: Byte;
  { set while an area spell or a terrain hazard hits several targets }
  gMultiTarget: Byte;
  { set to have the items menu redraw its frame }
  itemsMenuRedraw: Byte;
  { the last attack roll; a natural 20 is stored as 100 }
  lastAttackRoll: ShortInt;
  { The hits landed in each attack phase during the current swing. }
  attackHits: array[1..2] of Byte;
  { The figure a morale check compares with the losses taken; bless and curse move it. }
  moraleCheck: Byte;
  { The target of the creature whose effect is being run. }
  effectTarget: Types.PCharRecord;
  { the save category of the throw being rolled }
  saveThrowType: Byte;
  { the outcome of the last saving throw }
  lastSaveResult: Boolean;
  { CbtActs zeroes it before the attack-rate effects run; never read }
  attackInitByte: Byte;
  { FxEngine: last attack hit on a natural 17 or better }
  beheadEligible: Boolean;
  { the handler for each effect id }
  effectFns: array[1..127] of Types.TEffectHandler;

{ The 3-D view: wall sets, map, colors and the party's place on the map. }
var
  { the wall pictures of the loaded wall sets }
  wallGfx: Types.PWallGfx;
  { the area's 16x16 map of walls and events }
  map3d: Types.PMapGeometry;
  { the sky color the view is filled with }
  viewSkyColor: Byte;
  { the first horizon band's color }
  viewHorizonColor1: Byte;
  { the second horizon band's color }
  viewHorizonColor2: Byte;
  { the floor color }
  viewFloorColor: Byte;
  { set while the automap is on show in place of the 3-D view }
  automapShown: Byte;
  { the party's place on the map, cleared and saved as one block }
  mapState: Types.TMapState;
  { the wall set loaded last, and the symbol-set slot it went into }
  loadedWallSet: Types.TWallSetRef;
  { cleared by GameInit with the second wall slot }
  secondWallSet: LongInt;
  { cleared by GameInit with the third wall slot }
  thirdWallSet: LongInt;
  { cleared by GameInit with the fourth wall slot }
  fourthWallSet: LongInt;

{ Pictures and animations: the palette-cycling preset, the loaded animation's frames and the big picture. }
var
  { set when the picture on show has a palette-cycling preset }
  palettePresetOn: Byte;
  { the displayed picture's palette-cycle preset }
  palettePreset: Types.TPalettePreset;
  { set when the animation came from a sprite archive rather than a picture archive }
  animFromSprite: Boolean;
  { each frame's delay }
  animFrameDelays: array[0..8] of Byte;
  { each VGA frame's encoded size }
  animFrameSizes: array[0..8] of Word;
  { the frame the others are drawn as differences from }
  animKeyFrame: Byte;
  { the first frame of the loop }
  animFirstFrame: Byte;
  { the last frame loaded; an inclusive bound }
  animLastFrame: Byte;
  { the frame on show }
  animCurFrame: Byte;
  { each VGA frame of the loaded animation: the key frame expanded, the others still run-length coded }
  vgaFrameBufs: array[0..8] of Types.PImage;
  { VgaFrame: the image that receives the prepared frame }
  vgaFrameImage: Types.PImage;
  { each frame's picture }
  animFrames: array[0..8] of Types.PImage;
  { cleared by GameInit, never read }
  animFramesTail: array[0..65] of Byte;
  { the loaded animation's archive name }
  picArcName: Types.TResourceName;
  { camp's saved copy of picArcName }
  savedResourceName: Types.TResourceName;
  { CharHlp: on the area map the map view is skipped while this is 9 }
  picArcId: Byte;
  { camp's saved copy of picArcId }
  savedResourceId: Byte;
  { the big picture on show }
  bigPicImage: Types.PImage;
  { CombatSt: the big picture loaded; $FF forces the next one to load }
  bigPicId: Byte;
  { reserved }
  bigPicIdTail: array[0..1] of Byte;

{ Menus: character selection, the horizontal and vertical menus, the mouse hot areas and the menu colors. }
var
  { SelectChar's mode while it runs }
  charSelectMode: Byte;
  { the character SelectChar started from }
  selectStartChar: Types.PCharRecord;
  { the list position shown on the vertical menu's first line }
  vertMenuTop: Integer;
  { the horizontal menu's highlighted choice }
  horizMenuChoice: Byte;
  { set by the menus when the key was an extended one }
  extendedKeyFlag: Boolean;
  { set when a click moved the highlighted choice, so the menu acts on the clicked row }
  menuClickChanged: Boolean;
  { ticks before the title menu answers by itself; 0 for never }
  menuAutoDelay: LongInt;
  { the key it answers with }
  menuAutoKey: Byte;
  { the screen row of each vertical menu line, $FF past the last }
  menuHotRows: array[1..25] of Byte;
  { the vertical menu list's left column, for mouse hits }
  listColLeft: ShortInt;
  { and its right column }
  listColRight: ShortInt;
  { the party panel's left column, for mouse hits }
  partyAreaLeft: Byte;
  { its right column }
  partyAreaRight: Byte;
  { its top row }
  partyAreaTop: Byte;
  { its bottom row }
  partyAreaBottom: Byte;
  { the field a click picked on the modify-character screen; $FF for none }
  modifyMouseRow: Byte;
  { Camp and CbtActs store $FF here before a horizontal menu }
  menuResetByte: Byte;
  { the horizontal menu's slots }
  menuSlotTable: array[0..19] of Types.TMenuSlot;
  { the menu text color }
  menuTextColor: Byte;
  { the menu prompt color }
  menuQueryColor: Byte;
  { the highlighted choice's color }
  menuHighlightColor: Byte;

{ Spells: the scroll or item being used, the spell handlers and the targets. }
var
  { the scroll or item a spell is cast from }
  castingItem: Types.PItemRec;
  { Magic's dispatch table: the target picker and one procedure per spell }
  spellFps: Types.TSpellDispatch;
  { the entries of spellTargetList in use }
  spellTargetTotal: Byte;
  { the current spell's targets }
  spellTargetList: array[1..72] of Types.PCharRecord;
  { the aimed cell's column }
  gTargetX: ShortInt;
  { the aimed cell's row }
  gTargetY: ShortInt;
  { the terrain patches laid on the arena }
  cellPatchList: Types.PCellPatch;
  { set while a spell is cast from an item; an item casts at its own level }
  castFromItem: Byte;
  { set while the party pool holds money; the shops clear it when they empty the pool }
  poolHasMoney: Boolean;

{ Resting, and the screen redraw requests. }
var
  { Fix's busy flag, the rest time and the spell-preparation timers }
  restState: Types.TRestState;
  { the turns rested toward the next day's healing }
  restHealTicks: Word;
  { CharHlp: moves the bottom message window down a row }
  suppressBorder: Byte;
  { CharHlp: set when the noncombat screen is redrawn }
  mapRedrawPending: Byte;

{ The combat round: scratch the menus share, the round count, targets, the aim cursor and the initiative queue. }
var
  { flags the menus, character creation and the effect handlers leave for one another }
  sharedScratch: Types.TScratchFlags;
  { the round count of the current fight }
  combatRound: Byte;
  { the round the fight ends on if neither side has won }
  fightEndRound: Byte;
  { CombatAi: CharHlp.CountTargets' list of targets in reach, as slotCreatures indexes }
  potentialTargets: array[1..72] of Byte;
  { CbtActs: The attacks made in each attack phase during the current swing. }
  attackCounts: array[1..2] of Byte;
  { the hit points the hostile side has left, as a percentage }
  hostileHpPercent: Byte;
  { CombatAi: quick magic: nonzero lets the party's quick-fighters cast spells }
  quickMagic: Byte;
  { set when the creature's turn is over }
  roundDone: Boolean;
  { reserved }
  roundDoneTail: array[0..3] of Byte;
  { the four-frame composite of the icon being moved }
  moveIconSheet: Types.PImage;
  { unused }
  moveIconSheetTail: Byte;
  { the aim cursor's arena column }
  aimCursorX: ShortInt;
  { and row }
  aimCursorY: ShortInt;
  { 1 while the manual aim cursor is up }
  aimCursorOn: Byte;
  { CombatSt: The directions the enemies close in from, set by the event script: bit n stands for facing 2n. Zero puts
    them all ahead of the party. }
  hostileDirections: Byte;
  { Combat: set while the player is moving a creature }
  manualMoveActive: Byte;
  { the creature a breath weapon is aimed at first }
  preferredTarget: Types.PCharRecord;
  { CombatAi: set once the acting creature can attack its target this turn }
  targetInReach: Byte;
  { set when the combat info panel must be redrawn }
  infoPanelDirty: Byte;
  { set while the combat map is drawn }
  combatGfxOn: Byte;
  { the combatants in the order they act this round }
  initiativeQueue: array[1..72] of Types.PCharRecord;
  { Combat: the place in initiativeQueue of the creature acting }
  initiativeIndex: Byte;

{ The 3-D view's wall and ceiling color choices. }
var
  { set to $DB by GameInit, never read }
  wallColorSel: Byte;
  { set to $E8 by GameInit, never read }
  ceilFloorColorSel: Byte;
  { reserved }
  ceilFloorColorSelTail: array[0..5] of Byte;

{ The script interpreter: the gosub stack, comparisons, operands, strings and the encounter's pictures. }
var
  { the top of the GOSUB return stack }
  eclStackTop: Types.PGosubNode;
  { the outcome of the last COMPARE, one flag per IF opcode }
  eclCmpFlags: array[1..6] of Byte;
  { the opcode run before the current one }
  prevEclOpcode: Byte;
  { the opcode being run }
  curEclOpcode: Byte;
  { reserved }
  curEclOpcodeTail: Byte;
  { the monster sprite the script shows }
  monSpriteId: Byte;
  { the monster picture the script shows }
  monPicId: Byte;
  { EclVm: combat icon slot for the next monster group }
  monIconSlot: Byte;
  { reserved }
  monIconSlotTail: array[0..129] of Byte;
  { EclVm: type of each operand read by LoadEclVars }
  eclVarTypes: array[1..64] of Byte;
  { each operand's high byte }
  eclVarHi: array[1..64] of Byte;
  { each operand's low byte }
  eclVarLo: array[1..64] of Byte;
  { Border: set when DrawFrameSegments reaches the list end }
  scratchFlag: Boolean;
  { A global loop counter shared by Blit, Joystick, TextRend and others. }
  scratchIndex: ShortInt;
  { the script's string registers }
  eclStrings: Types.TGbStrings;
  { unused }
  eclStringsTail: array[0..3839] of Byte;
  { the display flags DisplayMonster is given }
  monsterFlags: Types.TMonFlags;
  { reserved }
  monsterFlagsTail: array[0..7] of Byte;
  { set to have the shop screen framed again }
  storeFrameGate: Byte;

{ The end of a fight's experience share, and the script interpreter's area and text-box state. }
var
  { party members who take no share of the experience }
  nonAnimCount: Byte;
  { each sharing member's experience award }
  expShare: LongInt;
  { set when the party won the fight }
  combatWon: Boolean;
  { the area script being run }
  eclScriptId: Byte;
  { the search bit EclVm's travel loop saves and restores }
  savedSearching: Byte;
  { set once the script has cleared the text box }
  clearBoxDone: Byte;
  { set when the next PRINT starts a new line }
  protNewLine: Byte;
  { set while a script picture is on show }
  eclPicShown: Boolean;

{ The script interpreter: what the encounter shows. }
var
  { set while a monster sprite is on show }
  monSpriteShown: Byte;
  { set once the view box has been drawn }
  viewBoxDrawn: Byte;
  { the script picture's state }
  eclPicState: Types.TPicState;
  { set once LOAD MONSTER has added monsters }
  monstersLoaded: Byte;
  { cleared when the monsters are drawn }
  monsterDrawPending: Byte;
  { cleared by GameInit, never read }
  inEncMenu: Byte;

{ The script interpreter: loading characters and monsters, input mode and the overlay read hook. }
var
  { set when LOAD CHARACTER finds no such party member }
  loadCharFailed: Byte;
  { set when the party panel must be put back after the script }
  panelRestorePending: Byte;
  { cleared by GameInit, never read }
  panelRestorePendingTail: Byte;
  { how mouse clicks are read: on the menu or on the view }
  clickInputMode: Byte;
  { CombatAi: the turn-undead limit set up for this fight; a creature turns only while its attempts are below it }
  turnUndeadLimit: Byte;
  { cleared by GameInit, never read }
  turnUndeadLimitTail: Byte;
  { EclVm: stops the run loop and the movement loop }
  scriptAbort: Byte;
  { the monsters LOAD MONSTER has added, capped at 63 }
  addedMonsterCount: Byte;
  { reserved }
  addedMonsterCountTail: array[0..4] of Byte;
  { the saved overlay-read hook }
  savedOvrReadFunc: Types.TOverlayRead;
  { reserved }
  savedOvrReadFuncTail: array[0..1] of Byte;
  { the cursor picture laid over the map window }
  mapWinOverlay: Types.PImage;

{ The developer password and the copy-protection flags. }
var
  { the word that unlocks the developer mode from the command line; ModeInit sets it }
  debugPassword: String[20];
  { the journal check's stage flags }
  protectionFlags: Types.TProtectionFlags;

{ How the game was started. }
var
  { set when the game was started with a saved game, so the menus are skipped }
  skipMenus: Byte;

{ The mouse. }
var
  { Mouse: False: X is halved to match the 320-pixel screen }
  mouseRawX: Boolean;
  { CharHlp: forced to 1 for the main menu }
  mouseMenuMode: Byte;
  { set when a mouse driver answered }
  mouseInstalled: Boolean;
  { GameIo: set when the last key came from the mouse }
  keyFromMouse: Byte;
  { the buttons the driver reported }
  mouseButtonCount: Byte;
  { the mouse column }
  mousePosX: Integer;
  { the mouse row }
  mousePosY: Integer;
  { the mouse column last seen }
  mousePrevX: Integer;
  { the mouse row last seen }
  mousePrevY: Integer;
  { the cursor shape handed to the driver }
  mouseCursorMask: Pointer;

{ The joystick. }
var
  { Joystick's calibrations: two sticks, x and y axes }
  joyCalibrations: array[1..2] of Types.TJoyCalibration;
  { set when a joystick was found }
  joystickInstalled: Boolean;
  { the joystick cursor column }
  joyCursorX: Word;
  { the joystick cursor row }
  joyCursorY: Word;

{ Palettes: the sky and backdrop of the 3-D view, the picture palettes and the main palette. }
var
  { set when the view's palette has changed and must be loaded }
  viewPaletteDirty: Boolean;
  { set while the backdrop palette is in use }
  backdropPalActive: Boolean;
  { the sky picture shown last }
  prevSkyId: Byte;
  { the sky picture to show }
  curSkyId: Byte;
  { the backdrop picture behind the 3-D view }
  backdropPicture: Types.PImage;
  { the sky picture }
  skyPicture: Types.PImage;
  { the sky's palette }
  skyPal: Types.TPalette;
  { the backdrop's palette }
  backdropPal: Types.TPalette;
  { the big picture's palette }
  picPal: Types.TPalette;
  { a palette put aside while another is shown }
  backupPal: Types.TPalette;
  { the palette the game screen is drawn with }
  mainPal: Types.TPalette;
  { Blit: The palette of the last decoded image: imagePal holds the DAC triplet of each color and palIndexMap the 4-bit
    color each index maps to in the 16-color classes. }
  imagePal: Types.TPalette;
  { the 4-bit color each index of imagePal maps to }
  palIndexMap: array[0..255] of Byte;
  { set when mainPal has changed and the screen must be redrawn }
  mainPalReload: Boolean;
  { unused }
  mainPalReloadTail: array[0..4] of Byte;
  { set while vault changes wait in tmpvault.dat for the next save }
  vaultDirty: Byte;
  { the save letter the vault in memory belongs to }
  vaultSaveLetter: Char;
  { the last item of a vault or item list being built }
  vaultTail: Types.PItemRec;

{ The work slots: GameIo's pool of item and text records. }
var
  { the slot pool }
  workSlots: array[1..138] of Types.TItemRec;

{ Sound effects: the loaded sounds and the driver command. }
var
  { the sound effects loaded, by sound id }
  loadedSounds: array[1..11] of Types.TSoundEntry;
  { the buffer a sound is staged in for the driver }
  soundStagingBuf: Types.PBytes;
  { unused }
  soundStagingBufTail: array[0..3] of Byte;
  { the command block handed to the sound driver }
  soundDriverCmd: Types.TDriverCommand;

implementation

end.
