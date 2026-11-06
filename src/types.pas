{ The record, pointer and string types the game units share. }
{$F+}
{$A-}
unit Types;

interface

type
  { One spellTable row: who casts the spell and at what level, its range, duration, area and target, the saving throw it
    allows, the effect it lays on, when it may be cast, and how the combat AI rates it. }
  TSpellRec = record
    { 0 cleric, 1 druid, 2 mage, 3 magic item }
    castClass: Byte;
    { 1..9; a class-3 entry always says 6 }
    level: Byte;
    { $FF = attack roll }
    rangeFixed: Byte;
    { range per caster level }
    rangeVar: Byte;
    durFixed: Byte;
    { duration per caster level }
    durVar: Byte;
    { packed: low nibble area mode, high nibble radius }
    area: Byte;
    { 0..3 }
    target: Byte;
    { 0..3 }
    saveResult: Byte;
    { 0 or 4 }
    saveType: Byte;
    { effect id added on a hit }
    effect: Byte;
    { 0 noncombat, 1 combat, 2 any }
    whenCast: Byte;
    castTime: Byte;
    { 0..9; 0 = the AI never casts it }
    aiPriority: Byte;
    { 0 or 1 }
    offensive: Byte;
    { friendly-fire scan radius }
    aiRadius: Byte;
  end;

  { One copy-protection challenge; the strings are stored ciphered, see journalChallenges. }
  TEncodedJournalWord = String[20];
  TJournalChallenge = record
    encodedHeading: String[30];
    pageNumber: Byte;
    wordNumbers: array[1..3] of Byte;
    encodedWords: array[1..3] of TEncodedJournalWord;
  end;

  { The pooled money, one LongInt per kind, in pool order: platinum, gems, jewelry. }
  TMoney = array[0..2] of LongInt;

  { The part of bank 0 that EclInit zeroes each time an area's script loads, unless a saved game is being resumed. }
  TAreaState = record
    loadedMapIdLead: array[$96..$C4] of Byte;
    { the 3D map Load3DMap last read }
    loadedMapId: Byte;
    loadedMapIdTail: array[$C6..$C7] of Byte;
  end;

  { The ECL VM's memory. Bank 0 is the 1024-byte variable bank; zone 3 is the loaded script, addressed from $8000. Bank
    0 is read both by block offset and by ECL address, which is the offset plus one. The named cells are the ones the
    engine reads by name; a gap is a run of cells only scripts use. }
  TGbvmBank0 = record
    case Byte of
      { by block offset }
      0: (raw: array[0..$3FF] of Byte);
      { by ECL address }
      1: (byAddr: array[1..$400] of Byte);
      { added to a non-party attacker's to-hit roll }
      2: (monsterHitMod: ShortInt;
          { nonzero: no spells or magic items }
          antiMagic: Byte;
          movementState: Byte;
          movementStateTail: Byte;
          { [0] ticks .. [3] hours .. [6] years, each modulo clockModulus }
          clock: array[0..6] of Byte;
          clockTail: array[$0B..$0D] of Byte;
          { taken off the turning column }
          turnUndeadPenalty: Byte;
          turnUndeadPenaltyTail: array[$0F..$10] of Byte;
          { the speed setting; text pauses scale with it }
          gameDelay: Byte;
          { the 3D map ECL asked for }
          mapId: Byte;
          { 1: the healer menu opens next; still 1 while it runs }
          healerRequest: Byte;
          monstersDefeated: Byte;
          { the area script to load; 0 picks the default }
          areaScriptId: Byte;
          { the party's position before its last step }
          prevX: Byte;
          prevY: Byte;
          { bit 0 searching, bit 1 looking }
          travelFlags: Byte;
          { nonzero: no area map and no coordinates }
          areaRestricted: Byte;
          { monsters may break once their side loses this % of its hit points }
          breakLossPct: Byte;
          { added to a party member's movement }
          partyMoveMod: ShortInt;
          reviveFlag: Byte;
          noCombatItems: Byte;
          mirrorDuel: Byte;
          partySize: Byte;
          edgeClamp: Byte;
          { nonzero in a 3D area, 0 on the area map }
          inDungeon: Byte;
          inDungeonTail: Byte;
          mapPaneEnabled: Byte;
          { the party's cell on the area map }
          windowCol: Byte;
          windowRow: Byte;
          { camp's level menu; scales monster hit points }
          difficulty: Byte;
          priceScale: Byte;
          { left by the ECL divide }
          divRemainder: Byte;
          divRemainderTail: Byte;
          restPeriod: Byte;
          interruptPct: Byte;
          interruptPctTail: Byte;
          { bit 0 the party, bit 1 the monsters }
          surpriseMask: Byte;
          { added to a party attacker's to-hit roll }
          partyHitMod: ShortInt;
          trainMask: Byte;
          { 1: the vault menu opens next }
          vaultRequest: Byte;
          vaultRequestTail: Byte;
          { nonzero: combat maps get a river }
          placeRiver: Byte;
          placeRiverTail: array[$33..$34] of Byte;
          alliesAttacked: Byte;
          { how far away the encounter is drawn }
          encounterDist: Byte;
          encounterDistLimit: Byte;
          { PRINT's text color; out of 1..15 means 10 }
          printColor: Byte;
          { the area's tile set and picture }
          tileSet: Byte;
          skyVariant: Byte;
          skyVariantTail: array[$3B..$95] of Byte;
          areaState: TAreaState);
  end;
  PGbvmBank0 = ^TGbvmBank0;
  TZone3 = array[$8000..$9DFF] of Byte;
  PZone3 = ^TZone3;
  TVmBand = record
    zone0: PGbvmBank0;
    zone3: PZone3;
    { entry addresses CallEclScript starts from }
    vmRun: array[1..5] of Word;
    { the script instruction pointer into zone3^ }
    eclIp: Word;
  end;

  { One character class's level table; see classLevelTable. }
  TClassLevelTable = record
    xp: array[2..11] of LongInt;
    spellSlots: array[1..29] of array[1..9] of Byte;
  end;

  { One race's ability-score limits; see raceLimits. The three strength pairs are by gender, 0 male and 1 female. }
  TRaceLimits = record
    strMin: array[0..1] of Byte;
    strMax: array[0..1] of Byte;
    strExcMax: array[0..1] of Byte;
    intMin: Byte;
    intMax: Byte;
    wisMin: Byte;
    wisMax: Byte;
    dexMin: Byte;
    dexMax: Byte;
    conMin: Byte;
    conMax: Byte;
    chaMin: Byte;
    chaMax: Byte;
  end;

  { One starting-age entry; see startAges. }
  TStartAge = record
    base: Word;
    dice: Byte;
    sides: Byte;
  end;

  { One class's permitted alignments; see classAlignments. }
  TClassAlignments = record
    count: Byte;
    allowed: array[1..9] of Byte;
  end;

  { One terrain class; see terrainTable. A line of sight starts at the viewer's cellHeight and is blocked by a cell
    whose obstacleHeight is above it. }
  TTerrain = record
    { movement points to enter; $FF is impassable }
    cost: Byte;
    cellHeight: Byte;
    obstacleHeight: Byte;
    { the combat tile drawn for the cell }
    tileId: Byte;
  end;

  { A main-menu row: the label plus the flag the roster state toggles. }
  TMenuItem = record
    name: String[40];
    enabled: Byte;
  end;

  { The two flanking rays of a cone, and the four diagonal aim offsets; see coneSideRays and aimDeltas. }
  TConeSideRays = record
    dx1: array[0..7] of ShortInt;
    dy1: array[0..7] of ShortInt;
    dx2: array[0..7] of ShortInt;
    dy2: array[0..7] of ShortInt;
  end;
  TAimDeltas = record
    dx: array[1..4] of ShortInt;
    dy: array[1..4] of ShortInt;
  end;

  { One color-cycling range and the four a picture's preset carries; see palettePresets. }
  TPaletteCycle = record
    firstColor: Byte;
    colorCount: Byte;
    delay: Byte;
  end;
  TPalettePreset = array[1..4] of TPaletteCycle;

  { One cell offset of an icon footprint; see footprintOffsets. }
  TIconDelta = record
    dx: ShortInt;
    dy: ShortInt;
  end;

  { One combat row band, the x range creatures of a row may occupy; see rowBand. }
  TBandRec = record
    lo: ShortInt;
    hi: ShortInt;
  end;

  { One frame line for Sym8x8.DrawBorderRun, and the two list shapes Border walks to a $FE terminator; see
    fullFrameSegments. }
  TFrameSeg = record
    x1: Byte;
    y1: Byte;
    x2: Byte;
    y2: Byte;
    capStart: Byte;
    capEnd: Byte;
  end;
  TFrameList4 = record
    segs: array[1..4] of TFrameSeg;
    lineEnd: Byte;
    lineEndTail: Byte;
  end;
  TFrameList5 = record
    segs: array[1..5] of TFrameSeg;
    lineEnd: Byte;
    lineEndTail: Byte;
  end;

  { The 3-D view's wall-slice geometry, one entry per slot 0..9; see viewSlices. }
  TViewSliceGeometry = record
    startSymbol: array[0..9] of Byte;
    columns: array[0..9] of Byte;
    rows: array[0..9] of Byte;
    xColumn: array[0..9] of Integer;
    yRow: array[0..9] of Integer;
  end;

  { One registered menu option; see menuSlotTable. }
  TMenuSlot = record
    { the option returned when it is chosen; $FF marks a free slot }
    choiceIndex: Byte;
    { its hotkey, matched against the key pressed }
    keyCode: Byte;
  end;

  { One base-item row: an item type's equip slot, hands, damage and class mask. GameInit reads the table from the items
    file into baseItemTable with one BlockRead of up to 129 rows. }
  TBaseItem = record
    { equip slot }
    slot: Byte;
    { hands to wield or wear it }
    hands: Byte;
    { damage against a large target: dice count, }
    dmgLgRolls: Byte;
    { die faces }
    dmgLgDice: Byte;
    { and modifier }
    dmgLgMod: ShortInt;
    rateOfFire: Byte;
    { bit 7 counts toward AC; low 7 bits, the item's own AC }
    acDescr: Byte;
    wpnClass: Byte;
    { unused }
    wpnClassTail: Byte;
    { damage against anything smaller: dice count, }
    dmgSmRolls: Byte;
    { die faces }
    dmgSmDice: Byte;
    { and modifier }
    dmgSmMod: ShortInt;
    range: Byte;
    { ANDed with a character's classMask }
    classMask: Byte;
    { bits: 1 arrow ammo, 2 dex missile, 4 strength bonus, 8 fires ammo, $10 thrown, $80 quarrel ammo }
    props: Byte;
    { unused }
    propsTail: Byte;
  end;

  { One item definition, the part of an item that a new item copies whole: GameInit loads 254 of them from 'ITEM0.dax'
    into the block at itemDefBlock, and EclVm copies one into a new item. }
  TItemDef = record
    { row of the base-item table (TBaseItem) }
    itemType: Byte;
    { the name's three components }
    nameIds: array[1..3] of Byte;
    plus: ShortInt;
    saveBonus: ShortInt;
    equipped: Byte;
    { one bit per name component }
    unidMask: Byte;
    cursed: Byte;
    weight: Word;
    quantity: Byte;
    value: Word;
    case Byte of
      0: (charges: Byte;
          { low nibble, a weapon's alignment when special = $84 }
          effect: Byte;
          { $84 marks an alignment-restricted weapon }
          special: Byte);
      { a scroll's spell ids; bit 7 set while it is being scribed }
      1: (scrollSpells: array[1..3] of Byte);
  end;

  { One item instance, a node of an item list: a character's pack, a shop's stock, the vault, a treasure pile, or a
    record of GameIo's work pool, which is free while its itemType is zero. Its first fields match MenuCore's TMenuLine,
    so an item list can be handed to a menu as it stands. }
  PItemRec = ^TItemRec;
  TItemRec = record
    name: String[40];
    { MenuCore: nonzero marks a heading line }
    inUse: Byte;
    next: PItemRec;
    definition: TItemDef;
  end;

  TItemDefs = array[1..254] of TItemDef;
  PItemDefs = ^TItemDefs;

  { One active effect on a character, a node of its effects list. }
  PEffectRec = ^TEffectRec;
  TEffectRec = record
    id: Byte;
    duration: Word;
    strength: Byte;
    { nonzero: fire the effect's handler on removal }
    onRemove: Byte;
    next: PEffectRec;
  end;

  TStatPair = record
    base: Byte;
    cur: Byte;
  end;

  TIconColors = array[1..6] of Byte;

  PCharRecord = ^TCharRecord;
  PCombatRec = ^TCombatRec;

  { A combatant's per-combat state: CombatSt allocates one for each creature in the fight and hangs it on its character
    record's combatAddr. }
  TCombatRec = record
    spellCast: Byte;
    castAllowed: Byte;
    itemUseAllowed: Byte;
    initiative: ShortInt;
    attackPhase: Byte;
    movement: Byte;
    { CharHlp's guard sets it }
    guarding: Byte;
    madeAttack: Byte;
    direction: Byte;
    { the creature this one is attacking or aiming at }
    other: PCharRecord;
    { damage past 0 hp, set by CharHlp's InflictDamage; Combat's EndOfRound adds 1 each round, and past 9 the creature
      dies }
    overkill: Byte;
    flankCount: Byte;
    turned: Byte;
    turnAttempts: Byte;
    flankSpread: Byte;
    { CombatSt sets it to 1 }
    notPcNpc: Byte;
    fleeing: Byte;
    aiStance: Byte;
    initialized: Byte;
  end;

  { The character record: one node of the roster list, party and monsters alike. CharGen, EclVm and EclMenu allocate it.
    race, status and side are signed values. }
  TCharRecord = record
    name: String[15];
    { indexed by the C_Stat constants }
    stats: array[0..5] of TStatPair;
    { exceptional strength, read only at 18 }
    strExcCur: Byte;
    strExcBase: Byte;
    { memorized spell ids; bit 7 marks one cast and not yet memorized again }
    spells: array[0..140] of Byte;
    spellPrepTime: Byte;
    thac0Base: Byte;
    { raceNameTable index }
    race: 0..127;
    charClass: ShortInt;
    { ViewChar's cure handler decrements it }
    poisonCount: Byte;
    age: Word;
    hpMax: Byte;
    knownSpells: array[1..125] of Byte;
    levelHighest: ShortInt;
    iconDimensions: Byte;
    saves: array[0..4] of Byte;
    movementBase: Byte;
    hitDice: Byte;
    { SaveLoad sets it to the highest oldLevels entry }
    dualLevel: Byte;
    { the row CbtActs reads its turn-undead table at }
    levelUndead: ShortInt;
    thiefSkills: array[1..8] of Byte;
    effects: PEffectRec;
    { high bit: a creature, not a player; low 7 bits, its morale }
    npc: Byte;
    modified: Byte;
    modifiedTail: array[$149..$14A] of Byte;
    coins: array[0..2] of Word;
    classLevels: array[0..6] of Byte;
    oldLevels: array[0..6] of Byte;
    { the highest level reached in each class, which a level drain leaves behind; cleared by a class change }
    peakClassLevels: array[0..6] of Byte;
    { genderNameTable index }
    gender: ShortInt;
    { alignmentNameTable index }
    alignment: ShortInt;
    attacks: Byte;
    attacks2: Byte;
    { unarmed damage per attack: dice count, }
    unarmedRollsA: array[1..2] of Byte;
    { die faces }
    unarmedDiceA: array[1..2] of Byte;
    { and modifier }
    unarmedModA: array[1..2] of ShortInt;
    acBase: Byte;
    creatureId: Byte;
    experience: LongInt;
    { the experience and maximum hit points before the last level drain, which Restoration gives back }
    oldExperience: LongInt;
    oldHpMax: Byte;
    { one bit per class held; ANDed with TBaseItem.classMask }
    classMask: Byte;
    hpRolled: Byte;
    { spell slots by class list (C_Spell) and spell level }
    spellSlots: array[0..2, 1..9] of Byte;
    xpAward: Word;
    iconHeadClass: Byte;
    iconBodyClass: Byte;
    orderNumber: Byte;
    iconSize: Byte;
    iconColors: TIconColors;
    creatureType: Byte;
    immunities: Byte;
    numberOfItems: Byte;
    items: PItemRec;
    equipped: array[0..12] of PItemRec;
    handsEquipped: Byte;
    saveBonus: ShortInt;
    encumbrance: Word;
    next: PCharRecord;
    combatAddr: PCombatRec;
    { FxEngine's CheckSpellResistance adds it to the roll }
    spellResistance: Byte;
    { CharHlp.CanLevelUp(cr), stored }
    levelCapped: Byte;
    { statusNameTable index; values past 8 are also used }
    status: 0..127;
    inPlay: Byte;
    { 0 the party's, 1 the other; indexes the per-side tally }
    side: ShortInt;
    quickfight: Byte;
    thac0Adj: Byte;
    { armor class as 60 minus AC: [0] from the front, [1] from behind }
    armorClass: array[0..1] of Byte;
    { attacks left this round, by attack phase }
    attacksLeft: array[1..2] of Byte;
    curRollsA: array[1..2] of Byte;
    curDiceA: array[1..2] of Byte;
    curModA: array[1..2] of ShortInt;
    hpCur: Byte;
    movementCur: Byte;
  end;

  { The combat arena: CombatSt allocates it and Combat frees it. }
  PCombatMap = ^TCombatMap;
  TCombatMap = record
    oxLead: array[0..1] of Byte;
    { the view's upper-left corner, arena coordinates }
    ox: ShortInt;
    oy: ShortInt;
    cursorOn: Boolean;
    cursorSize: Byte;
    noHeight: Byte;
    { terrain index per cell, row stride 50 }
    cells: array[0..24, 0..49] of Byte;
  end;

  { A timed terrain patch over up to nine arena cells: Magic allocates it, FxEngine and Combat free it. terrainIndex and
    used hold one entry per patch cell 1..9, in patchDirs order. }
  PCellPatch = ^TCellPatch;
  TCellPatch = record
    { the caster }
    owner: Pointer;
    next: PCellPatch;
    terrainIndex: array[1..9] of Byte;
    used: array[1..9] of Byte;
    { the patch's center cell }
    x: ShortInt;
    y: ShortInt;
    { FxEngine's patch sweep decrements it; $FF = expired }
    ttl: ShortInt;
    { the caster's level, which Dispel Magic rolls against }
    casterLevel: Byte;
    { the code RefreshExplosionMap stamps into each covered cell }
    paintTerrain: Byte;
  end;

  { One combat-arena slot, 1-based over the 72 combatants; see arenaSlots. }
  TArenaEntity = record
    x: ShortInt;
    y: ShortInt;
    { CombatSt stores the slot's own index here }
    aux: Byte;
    { icon size, 0 = out }
    sizeCode: Byte;
  end;

  { One downed combatant: the creature, where it fell, and the terrain its body covers; see downedList. }
  TDownedRec = record
    { each unit compares or stores its own pointer type here }
    cr: Pointer;
    x: ShortInt;
    y: ShortInt;
    { saved from under the corpse }
    terrain: Byte;
  end;

  { One ranked approach: entity index, movement cost, facing. Pathing's BuildTargetList writes up to 72 of them into
    rankedTargets. }
  TApproachResult = record
    ent: Byte;
    cost: Byte;
    face: Byte;
  end;

  { EclMenu's picture state, two flags it sets and tests. }
  TPicState = record
    width: Byte;
    dirty: Byte;
  end;

  { One sound slot. GameInit's LoadSoundDefs fills both fields through LoadDax; SoundDrv's SoundCommand copies data^
    into the driver's staging buffer. }
  TSoundEntry = record
    size: Word;
    data: Pointer;
  end;

  { The INT 66h request block SoundDrv's DriverDispatch hands the sound driver. }
  TDriverCommand = record
    { a copy of GDVars.soundStagingBuf }
    buffer: Pointer;
    { bytes of sound data in buffer^ }
    length: Word;
    { reserved, zeroed with the block }
    lengthTail: array[0..3] of Byte;
    bufferSize: Word;
  end;

  { The seven-component game clock: [0] ticks .. [6] years. GDConsts.clockModulus[i] is the modulus of component i. }
  TClock = array[0..6] of Word;

  { Flags the menus, character creation and the effect handlers leave for one another. }
  TScratchFlags = record
    { nonzero sends the next effect-handler call to the item-effect handler, which clears it }
    itemEffectOverride: Byte;
    itemEffectOverrideTail: array[1..2] of Byte;
    { where SaveLoad reads and writes characters: 0 old saves, 1 the save directory, 2 a transfer }
    storageMode: ShortInt;
    { set when training finds nothing left to train }
    trainingDone: Byte;
    trainingDoneTail: Byte;
    { set while the modify-character screen is up; MenuCore then takes its clicks }
    modifyActive: Byte;
    { set while character creation trains a new character; training then runs without prompts }
    trainMode: Byte;
    { nonzero: the Memorize menu redraws in full }
    memorizeRedraw: Byte;
    memorizeRedrawTail: Byte;
    { extra magic-user slots the Memorize menu may still fill }
    magicBonusSlots: Byte;
    magicBonusSlotsTail: Byte;
    { set when the player confirms an attack on an ally }
    allyAttackConfirmed: Byte;
  end;

  { The copy-protection check's stages: CopyProt sets each flag as the stage is passed, and FixMain stops the game
    unless all four are set. }
  TProtectionFlags = record
    case Byte of
      0: (
          { a challenge was picked }
          challengeSelected: Byte;
          { an answer was typed }
          answerEntered: Byte;
          { the tries are over }
          retriesDone: Byte;
          { the result is in }
          resultReady: Byte);
      1: (flags: array[1..4] of Byte);
  end;

  { The party's place on the map. }
  TMapState = record
    { the party's map column }
    x: ShortInt;
    { the party's map row }
    y: ShortInt;
    { the party's facing, 0..7 clockwise from north in steps of 2 }
    facing: Byte;
    { the wall kind in front of the party }
    wallAhead: Byte;
    { the event number of the party's square }
    event: Byte;
  end;

  { A loaded wall set: its resource id and the symbol-set slot its pictures went into. }
  TWallSetRef = record
    id: Integer;
    slot: Integer;
  end;

  { One joystick axis's calibration: the low reading, the five thresholds between the six positions, and the high
    reading; pool4.cfg stores the seven in order. }
  TJoyAxis = record
    case Byte of
      0: (lo: Word;
          threshold: array[1..5] of Word;
          hi: Word);
      1: (points: array[0..6] of Word);
  end;
  TJoyCalibration = record
    x: TJoyAxis;
    y: TJoyAxis;
  end;

  { The area's 16x16 map: two planes of wall kinds (north/east and south/west, a nibble each), the event numbers and the
    barrier bits. }
  TMapPlane = array[0..15, 0..15] of Byte;
  PMapGeometry = ^TMapGeometry;
  TMapGeometry = record
    wallsNE: TMapPlane;
    wallsSW: TMapPlane;
    events: TMapPlane;
    barriers: TMapPlane;
  end;

  { The loaded wall sets' pictures: five 156-byte slices to a wall definition, four definitions, also read as one run of
    slices. }
  TWallDefinition = array[1..5, 0..155] of Byte;
  PWallGfx = ^TWallGfx;
  TWallGfx = record
    case Byte of
      0: (definitions: array[1..4] of TWallDefinition);
      1: (slices: array[1..20, 0..155] of Byte);
  end;

  { The pane the last split or side frame left open, in character cells. }
  TPaneRect = record
    left: Byte;
    top: Byte;
    right: Byte;
    bottom: Byte;
  end;

  { One Bresenham walk from (x0, y0) to (x1, y1). movementCost grows by 2 for a straight step and 3 for a diagonal one;
    direction is the compass direction of the last step. }
  TLineWalk = record
    x0: Integer;
    y0: Integer;
    x1: Integer;
    y1: Integer;
    errorTerm: Integer;
    deltaX: Integer;
    deltaY: Integer;
    currentX: Integer;
    currentY: Integer;
    stepX: Integer;
    stepY: Integer;
    movementCost: Byte;
    direction: Byte;
  end;

  { A far pointer as its offset and segment words. }
  TPtrRec = record
    ofs: Word;
    seg: Word;
  end;

  { Resting and the Fix operation. }
  TRestState = record
    { nonzero while Fix runs; it holds back spell preparation }
    fixBusy: Byte;
    { the rest time still to run }
    restTime: TClock;
    { per party member: rest steps until the next spell is ready }
    prepTimers: array[1..8] of Byte;
  end;

type
  TStr40 = String[40];
  TStr80 = String[80];
  TStr255 = String[255];
  TGbStrings = array[1..5] of String[255];
  { The encounter display state: [0] the 3D sprite is loaded, [1] the picture is shown. }
  TMonFlags = array[0..1] of Boolean;
  TGosubNode = record
    ip: Word;
    next: Pointer;
  end;
  PGosubNode = ^TGosubNode;
  { An effect handler: called with the creature, the effect record (or item) that owns the effect, and whether the
    effect is being removed. }
  TEffectHandler = procedure(var cr; p: Pointer; removed: Boolean);
  { The music driver's entry point: event eventCode with the parameter block at paramSegment:paramOffset. }
  TDrvProc = function(paramSegment, paramOffset, eventCode: Word): Word;
  { The overlay manager's read routine, laid out as Overlay.OvrReadFunc. }
  TOverlayRead = function(readParam: Word): Integer;
  { A spell's cast routine. }
  TSpellProc = procedure;
  { A target picker: fills spellTargetList for spell; ai is nonzero when the computer chooses, and selected is False
    when nothing was picked. }
  TCastMenuProc = procedure(spell, ai: Byte; var selected: Boolean);
  { Magic's dispatch table. }
  TSpellDispatch = record
    { the target picker: Magic's outside combat, CbtActs' in combat }
    castMenu: TCastMenuProc;
    { each spell's cast routine, by spell id }
    spells: array[1..126] of TSpellProc;
  end;

type
  { A packed color map: a display color for each of 16 colors, two to a byte, the even color in the high nibble. }
  TColorMap = array[0..7] of Byte;
  { A 16-entry color list, one entry per EGA color; Blit.RemapPic takes a source and a destination list. }
  TColorTab = array[0..15] of Byte;
  { A VGA DAC triplet and a full 256-color palette. }
  TRgb = array[0..2] of Byte;
  TPalette = array[0..255] of TRgb;
  { A raw DAX payload, addressed byte by byte. The bound is only the largest structure the compiler allows. }
  PBytes = ^TBytes;
  TBytes = array[0..65519] of Byte;
  { An image in the active display class's layout. The record header is followed directly by the pixel data of every
    frame. }
  PImage = ^TImage;
  TImage = record
    { height in pixel rows }
    rows: Word;
    { width in 8-pixel cells (the row stride) }
    cells: Word;
    { header word copied from the DAX payload }
    imgOriginX: Word;
    { header word copied from the DAX payload }
    imgOriginY: Word;
    { the frame count }
    frameCount: Word;
    { carried from image to image; only a CGA display would read it }
    colorMap: TColorMap;
    { bytes per frame: rows * cells * the class's bytes per cell }
    total: Word;
    { size of the whole block, header included, for FreePic }
    allocSize: Word;
    { the transparent color key (MCGA draws with it instead of a mask) }
    keyColor: Byte;
    { transparency mask, same layout as the pixel data, or nil }
    mask: PBytes;
    { pixel data, `total` bytes per frame, running past the declared bound }
    data: array[0..0] of Byte;
  end;
  TStr10 = String[10];
  { A picture or sprite archive's name. }
  TResourceName = String[8];
  { One line of a vertical menu's list, the node AllocStringList allocates. An item list can be shown as a menu list
    because an item record begins with the same fields. }
  PMenuLine = ^TMenuLine;
  TMenuLine = record
    name: TStr40;
    { nonzero marks a heading line }
    inUse: Byte;
    next: PMenuLine;
  end;
  { The character shown on the sheet, and the default target for trading. }
  TSheetGlobals = record
    sheetChar: PCharRecord;
    tradeTarget: PCharRecord
  end;
  { The register block for software interrupts, laid out as Dos.Registers so storage can hold one without using Dos;
    callers view it as a Registers. }
  TRegisters = record
    case Integer of
      0: (ax: Word;
          bx: Word;
          cx: Word;
          dx: Word;
          bp: Word;
          si: Word;
          di: Word;
          ds: Word;
          es: Word;
          flags: Word);
      1: (al: Byte;
          ah: Byte;
          bl: Byte;
          bh: Byte;
          cl: Byte;
          ch: Byte;
          dl: Byte;
          dh: Byte);
  end;

implementation

end.
