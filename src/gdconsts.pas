{ Typed constants: every initialized table, message and menu in the data segment, grouped in sections by the subsystem
  that uses them and kept in address order. A new section starts wherever the data needs a word boundary. }
unit GDConsts;

interface

uses Types, C_Class, C_Effect, C_Keys, C_Terr, C_Prot;

{ The STORE opcode's stock tables. }
const
  { A store category 1..11 stocks the slots from its first slot here to its last slot below; each of the 170 slots names
    an item definition. This is each category's first slot. }
  storeFirstSlot: array[1..11] of Byte = (1, 45, 51, 62, 71, 100, 110, 130, 138, 146, 155);
  { each category's last slot }
  storeLastSlot: array[1..11] of Byte = (44, 50, 61, 70, 99, 109, 129, 137, 145, 154, 170);
  { the item definition each slot stocks; $FF is a scroll made at random }
  storeSlotItems: array[1..170] of Byte = (
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 49, 32, 33, 34, 35, 49, 223, 1, 4, 5, 6, 7, 9, 11, 15, 20, 22,
    25, 36, 37, 38, 39, 40, 41, 42, 43, 44, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59,
    60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 71, 72, 73, 74, 75, 76, 77, 78, 79, 45,
    80, 82, 83, 84, 86, 89, 91, 93, 95, 81, 85, 87, 88, 90, 92, 94, 96, 97, 98, 99,
    101, 102, 103, 104, 105, 106, 107, 108, 109, 70, 210, 225, 241, 243, 244, 250, $FF, 100, 211, 226,
    238, 245, 246, 251, $FF, 237, 242, 247, 248, 250, 251, $FF, $FF, $FF, 222, 201, 208, 209, 204, 203,
    205, 206, 207, 48, 46, 47, 145, 146, 233, 236);

{ The copy-protection check's journal entries. }
const
  { The copy-protection challenges, one per journal entry -- heading, page number, three word numbers and the three
    words at those positions. The text is stored ciphered; CopyProt.DecodeJournalText reads each string backwards and
    subtracts its own length from every character. Record 1's heading is INTRODUCTION. The last record's third slot is
    unused. }
  journalChallenges: array[1..21] of Types.TJournalChallenge = (
    (encodedHeading: 'Z[U`OaP[^`ZU'; pageNumber: 1; wordNumbers: (2, 3, 6);
     encodedWords: ('QHW', 'XWFJ^', 'HREF')),
    (encodedHeading: 'i[_jhWf6ZdW6ih[jYWhW^Y'; pageNumber: 1; wordNumbers: (1, 2, 4);
     encodedWords: ('XR\', 'HIIR', '^YWFU')),
    (encodedHeading: '_QOM^,^QeMX\'; pageNumber: 1; wordNumbers: (1, 3, 6);
     encodedWords: ('JWJMY', '[LV', 'MHNM\')),
    (encodedHeading: 'aS`]Qa.gbWZWPO'; pageNumber: 2; wordNumbers: (3, 5, C_Prot.NO_WORD);
     encodedWords: ('VDK', 'aTUWLVIZ', '')),
    (encodedHeading: 'dVddR]T1cVeTRcRYT'; pageNumber: 3; wordNumbers: (2, 5, C_Prot.NO_WORD);
     encodedWords: ('HUD', '^YZT^^PQZ][', '')),
    (encodedHeading: ']WNVWPRUJ'; pageNumber: 4; wordNumbers: (7, 8, 5);
     encodedWords: ('XJ[NQ', '[D', 'B')),
    (encodedHeading: 'cUdeRYbddQ0bUXd_'; pageNumber: 5; wordNumbers: (5, 7, 9);
     encodedWords: ('JJWMY', 'YK[RG\', 'KMTGNI')),
    (encodedHeading: 'tom\k;gpann`^^pn;\;bid_gdp]'; pageNumber: 6; wordNumbers: (1, 9, C_Prot.NO_WORD);
     encodedWords: ('NUPTYVM', '\HN', '')),
    (encodedHeading: 'ZGHSUI'; pageNumber: 6; wordNumbers: (2, 3, 5);
     encodedWords: ('XWYQ', 'KRZZGH', '\DZ')),
    (encodedHeading: 'ZKW*^KLWYM'; pageNumber: 6; wordNumbers: (6, 9, C_Prot.NO_WORD);
     encodedWords: ('TIKQ\KI\', 'XELX', '')),
    (encodedHeading: 'O`S^KS^SXS'; pageNumber: 6; wordNumbers: (2, 5, 9);
     encodedWords: ('ISZTW', 'UK', '[\VMUOM[')),
    (encodedHeading: 'gbWZWPO.bOP[]Q'; pageNumber: 6;
     wordNumbers: (7, C_Prot.NO_WORD, C_Prot.NO_WORD);
     encodedWords: ('KLUPMLK', '', '')),
    (encodedHeading: 'PWRTLJ]]J'; pageNumber: 7; wordNumbers: (3, 5, 8);
     encodedWords: ('RZW', 'XJU^Y', 'JJQJR')),
    (encodedHeading: 'c]T\Te^\/cPQ\^R'; pageNumber: 8; wordNumbers: (2, 4, 7);
     encodedWords: ('XKHS[T', 'ZLYH\XZ', 'QDF')),
    (encodedHeading: 'dVZXVeRced1eRS^`T'; pageNumber: 8; wordNumbers: (2, 6, 8);
     encodedWords: ('KLLJJ\Z', 'KLSSPRZ', 'Z`VSWLK')),
    (encodedHeading: '`MNY[O,^Q`RM'; pageNumber: 9; wordNumbers: (6, 9, C_Prot.NO_WORD);
     encodedWords: ('L]P]Y\Z', 'OWPTQPW__LM', '')),
    (encodedHeading: 'HNLFR'; pageNumber: 9; wordNumbers: (3, 6, 8);
     encodedWords: ('UJR]WN\\N', 'TI^Q^Z][', 'HKW')),
    (encodedHeading: '^]P^`8NTRLX'; pageNumber: 9; wordNumbers: (4, 7, 8);
     encodedWords: ('YTOGXZ', 'ZHQ', 'QJ[JQ')),
    (encodedHeading: 'ZJPYLSJ'; pageNumber: 10; wordNumbers: (3, 6, C_Prot.NO_WORD);
     encodedWords: ('[MZQ]YMZ', 'XPTTG', '')),
    (encodedHeading: 'PVTNZ-[\-`]Va'; pageNumber: 10; wordNumbers: (1, 6, 8);
     encodedWords: ('LXSF', 'XWEG', 'MHNM\')),
    (encodedHeading: 'dVcfdRVce1]RTZXR^'; pageNumber: 10; wordNumbers: (3, 8, C_Prot.NO_WORD);
     encodedWords: ('RK\GXZ', '[ZM\[VWU', '')));

{ The temple's healing menu. }
const
  { The spellNames ids that label Temple's healing menu, rows 1..11. }
  healMenuSpellIds: array[1..11] of Byte = (37, 39, 3, 58, 71, 36, 67, 75, 43, 113, 102);

{ What a mirror shows. }
const
  { The monster a mirror shows, by the area's tileSet. }
  mirrorMonId: array[0..4] of Byte = (59, 6, 2, 8, 59);
  { the picture a mirror shows, by the area's tileSet }
  mirrorPicId: array[0..4] of Byte = (59, 6, 2, 8, 59);

{ Old age. }
const
  { The age at which a character is warned of dying of old age, by race in raceNameTable order; death comes ten years
    past it. }
  ageThreshold: array[0..5] of Word = (1600, 325, 525, 525, 199, 120);

{ The combat AI's approach. }
const
  { The direction offset a combatant tries on each of five approach attempts, by AI stance 1..6. }
  aiDirOffsets: array[1..6, 1..5] of Byte = (
    (8, 7, 6, 1, 2),
    (8, 1, 2, 7, 6),
    (7, 1, 8, 6, 2),
    (1, 7, 8, 2, 6),
    (8, 7, 6, 5, 4),
    (8, 1, 2, 3, 4));

{ Combat set-up: the placement rings and the wilderness terrain classes. }
const
  { CombatSt's ring directions by team facing }
  ringDirTbl: array[0..3, 0..3] of Byte = (
    (8, 4, 6, 2),
    (8, 6, 4, 0),
    (8, 0, 6, 2),
    (8, 2, 0, 4));
  { the ring start quadrants by team facing }
  ringStart: array[0..3, 0..3] of Byte = (
    (0, 0, 2, 6),
    (2, 2, 0, 4),
    (4, 4, 2, 6),
    (6, 6, 4, 0));
  { the four quadrant directions }
  quadDir: array[0..3] of Byte = (7, 2, 3, 6);
  { each quadrant's leg start column, inner ring then outer ring }
  startQuadX: array[Boolean, 0..3] of ShortInt = (
    (5, 4, 5, 6),
    (3, 8, 7, 2));
  { each quadrant's leg start row, inner ring then outer ring }
  startQuadY: array[Boolean, 0..3] of ShortInt = (
    (3, 2, 2, 3),
    (0, 2, 5, 3));
  { the columns a team may be placed in, by distance band and row }
  rowBand: array[0..4, 0..5] of Types.TBandRec = (
    ((lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 2; hi: 9), (lo: 3; hi: 10), (lo: 4; hi: 10)),
    ((lo: 0; hi: 2), (lo: 0; hi: 3), (lo: 1; hi: 4), (lo: 2; hi: 5), (lo: 3; hi: 6), (lo: 4; hi: 7)),
    ((lo: 0; hi: 6), (lo: 0; hi: 7), (lo: 1; hi: 8), (lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 1; hi: 0)),
    ((lo: 3; hi: 6), (lo: 4; hi: 7), (lo: 5; hi: 8), (lo: 6; hi: 9), (lo: 7; hi: 10), (lo: 8; hi: 10)),
    ((lo: 0; hi: 6), (lo: 0; hi: 7), (lo: 1; hi: 8), (lo: 2; hi: 9), (lo: 3; hi: 10), (lo: 4; hi: 10)));
  { The terrain class by wilderness terrain char, read by CombatSt.TerrainClassOf. }
  terrainClassByChar: array[0..31] of Byte = (
    $00, $18, $11, $15, $01, $01, $60, $14, $08, $01, $00, $21, $71, $09, $06, $04,
    $01, $09, $09, $08, $59, $00, $11, $11, $00, $00, $01, $11, $00, $00, $20, $20);

{ The roster of characters that can join the party. }
const
  { pads roster names to 15 }
  rosterNameFill: String[15] = '               ';
  { The roster scan's per-storage constants indexed 0 (.who) and 1 (.pc): where the character name sits in the file. }
  saveNameOffsets: array[0..1] of Byte = (0, 0);
  { where the NPC marker sits }
  saveMarkerOffsets: array[0..1] of Word = ($00FF, $0147);
  { the file size }
  saveFileSizes: array[0..1] of Word = (439, 510);

{ Combat icon customization. }
const
  { CHEAD/CBODY suffix by iconSize }
  iconHeightMark: array[1..2] of Char = ('S', 'T');
  { menu slots per icon-edit state }
  iconMenuCounts: array[1..5] of Byte = (4, 2, 7, 3, 3);

{ A new character's starting items. }
const
  { The item templates a new character starts with, by equipment family (1 fighter-type, 2 thief, 3 cleric, 4
    magic-user) and line 1..6; 0 is an empty line. }
  startingItems: array[1..4, 1..6] of Byte = (
    (126, 135, 108, 83, 80, 0),
    (211, 226, 126, 93, 0, 0),
    (120, 135, 108, 95, 250, 250),
    (211, 226, 124, 86, 0, 0));

{ The sixteen-color palette. }
const
  { The default sixteen-color palette as DAC (r, g, b) triples. }
  defaultPalette16: array[0..15, 0..2] of Byte = (
    (0, 0, 0), (0, 0, 170), (0, 170, 0), (0, 170, 170),
    (170, 0, 0), (170, 0, 170), (170, 85, 0), (170, 170, 170),
    (85, 85, 85), (85, 85, 255), (85, 255, 85), (85, 255, 255),
    (255, 85, 85), (255, 85, 255), (255, 255, 85), (255, 255, 255));

{ Turning undead. }
const
  { The d20 roll a turning attempt needs, by [undead level 1..13, turning column 0..10]; 99 cannot turn, 0 needs no
    roll, and a negative value is the D result, which also draws 1d6+6 attempts instead of 1d12. }
  turnUndeadTable: array[1..13, 0..10] of ShortInt = (
    (99, 10, 7, 4, 1, 1, 0, 0, -1, -1, -1),
    (99, 13, 10, 7, 1, 1, 0, 0, 0, -1, -1),
    (99, 16, 13, 10, 4, 1, 1, 0, 0, 0, -1),
    (99, 19, 16, 13, 7, 4, 1, 1, 0, 0, -1),
    (99, 20, 19, 16, 10, 7, 4, 1, 1, 0, 0),
    (99, 99, 20, 19, 13, 10, 7, 4, 1, 1, 0),
    (99, 99, 99, 20, 16, 13, 10, 7, 4, 1, 0),
    (99, 99, 99, 99, 20, 16, 13, 10, 7, 4, 1),
    (99, 99, 99, 99, 99, 20, 16, 13, 10, 7, 1),
    (99, 99, 99, 99, 99, 99, 20, 16, 13, 10, 4),
    (99, 99, 99, 99, 99, 99, 99, 20, 16, 13, 10),
    (99, 99, 99, 99, 99, 99, 99, 99, 19, 16, 10),
    (99, 99, 99, 99, 99, 99, 99, 99, 20, 19, 13));

{ Areas of effect. }
const
  { [row dy, radius]: half-width of a radius-1..3 area of effect on the row dy cells from its center; -3 marks a row the
    area does not reach. }
  areaHalfWidth: array[-3..3, 1..3] of ShortInt = (
    (-3, -3, 1),
    (-3, 1, 2),
    (1, 2, 3),
    (1, 2, 3),
    (1, 2, 3),
    (-3, 1, 2),
    (-3, -3, 1));

{ The spell list's level headings. }
const
  { The spell-list group headings by spell level; level 0 is the item group. }
  spellLevelNames: array[0..9] of String[40] = (
    'Special',
    '1st Level',
    '2nd Level',
    '3rd Level',
    '4th Level',
    '5th Level',
    '6th Level',
    '7th Level',
    '8th Level',
    '9th Level');

{ Aiming: cone rays and diagonal steps. }
const
  { The two flanking rays of a cone by its center direction 0..7. }
  coneSideRays: Types.TConeSideRays = (
    dx1: (-1, 0, 0, 1, 1, 0, 0, -1);
    dy1: (0, -1, -1, 0, 0, 1, 1, 0);
    dx2: (1, 1, 0, 0, -1, -1, 0, 0);
    dy2: (0, 0, 1, 1, 0, 0, -1, -1));
  { The diagonal aim offsets by aim mode 1..4: NW, NE, SW, SE. }
  aimDeltas: Types.TAimDeltas = (
    dx: (-1, 1, -1, 1);
    dy: (-1, -1, 1, 1));

{ Effects that end at zero hit points. }
const
  { The sixteen effects FxEngine removes from a character whose hit points reach zero, walked 1..16. }
  hpZeroEffects: array[1..16] of Byte = (C_Effect.SNAKE_HARASS, C_Effect.IMMUNE_ELECTRICITY, C_Effect.CHARM,
                                         C_Effect.SILENCE,
    C_Effect.SPIRITUAL_HAMMER, C_Effect.CONFUSED_LOSE_TURN, C_Effect.STINKING_CLOUD_COUGH, C_Effect.HELPLESS,
        C_Effect.CONFUSED, C_Effect.HELD, C_Effect.ASLEEP,
    C_Effect.CONFUSED_BERSERK, C_Effect.STUNNED, C_Effect.BERSERK, C_Effect.FRIGHTENED,
    C_Effect.DANCING);

{ The vertical menu's paging labels. }
const
  { appended to a menu when a later page exists }
  nextLabel: String[10] = ' Next';
  { appended to a menu that offers Exit }
  exitLabel: Types.TStr10 = ' Exit';
  { appended to a menu when an earlier page exists }
  prevLabel: Types.TStr10 = ' Prev';

{ Movement keys, and palette cycling for the big pictures. }
const
  { extended scan codes: H up, M right, P down, K left }
  arrowKeyByFacing: array[0..3, 0..3] of Char = (
    (C_Keys.UP, C_Keys.RIGHT, C_Keys.DOWN, C_Keys.LEFT),
    (C_Keys.LEFT, C_Keys.UP, C_Keys.RIGHT, C_Keys.DOWN),
    (C_Keys.DOWN, C_Keys.LEFT, C_Keys.UP, C_Keys.RIGHT),
    (C_Keys.RIGHT, C_Keys.DOWN, C_Keys.LEFT, C_Keys.UP));
  { The palette-cycling preset each big picture selects, four ranges of (first color, color count, delay in
    centiseconds); an unused range is all zero. Portrait copies the chosen row to GDVars.palettePreset, where MenuCore
    times each range. }
  palettePresets: array[0..14] of Types.TPalettePreset = (
    {  0 } ((firstColor: 96; colorCount: 16; delay: 3),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0)),
    {  1 } ((firstColor: 160; colorCount: 16; delay: 10),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0)),
    {  2 } ((firstColor: 176; colorCount: 16; delay: 7),
           (firstColor: 192; colorCount: 16; delay: 11),
           (firstColor: 208; colorCount: 8; delay: 17),
           (firstColor: 224; colorCount: 15; delay: 18)),
    {  3 } ((firstColor: 32; colorCount: 16; delay: 16),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0)),
    {  4 } ((firstColor: 32; colorCount: 24; delay: 10),
           (firstColor: 176; colorCount: 16; delay: 11),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0)),
    {  5 } ((firstColor: 80; colorCount: 48; delay: 20),
           (firstColor: 128; colorCount: 16; delay: 20),
           (firstColor: 144; colorCount: 16; delay: 20),
           (firstColor: 160; colorCount: 16; delay: 20)),
    {  6 } ((firstColor: 224; colorCount: 16; delay: 1),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0)),
    {  7 } ((firstColor: 144; colorCount: 11; delay: 10),
           (firstColor: 160; colorCount: 11; delay: 17),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0)),
    {  8 } ((firstColor: 176; colorCount: 15; delay: 17),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0)),
    {  9 } ((firstColor: 128; colorCount: 8; delay: 6),
           (firstColor: 144; colorCount: 8; delay: 4),
           (firstColor: 224; colorCount: 10; delay: 10),
           (firstColor: 0; colorCount: 0; delay: 0)),
    { 10 } ((firstColor: 224; colorCount: 16; delay: 10),
           (firstColor: 240; colorCount: 15; delay: 3),
           (firstColor: 208; colorCount: 16; delay: 7),
           (firstColor: 192; colorCount: 9; delay: 6)),
    { 11 } ((firstColor: 240; colorCount: 4; delay: 8),
           (firstColor: 244; colorCount: 4; delay: 9),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0)),
    { 12 } ((firstColor: 118; colorCount: 3; delay: 5),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0)),
    { 13 } ((firstColor: 176; colorCount: 15; delay: 15),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0)),
    { 14 } ((firstColor: 208; colorCount: 24; delay: 13),
           (firstColor: 232; colorCount: 8; delay: 7),
           (firstColor: 0; colorCount: 0; delay: 0),
           (firstColor: 0; colorCount: 0; delay: 0)));

{ The 3-D view's wall slices. }
const
  { The ten wall slices of the 3-D view: each slot's first symbol in the wall set, its width and height in cells, and
    where it is drawn. }
  viewSlices: Types.TViewSliceGeometry = (
    startSymbol: (0, 2, 6, 10, 22, 38, 54, 110, 132, 154);
    columns: (1, 1, 1, 3, 2, 2, 7, 2, 2, 1);
    rows: (2, 4, 4, 4, 8, 8, 8, 11, 11, 2);
    xColumn: (5, 4, 6, 4, 2, 7, 2, 0, 9, 5);
    yRow: (4, 3, 3, 3, 1, 1, 1, 0, 0, 4));

{ The screen frames Border draws. }
const
  { The line lists Border draws, each a run of segments ended by $FE and a pad byte. This one is the 40x24 outer
    frame. }
  fullFrameSegments: Types.TFrameList4 = (
    segs: ((x1: 0; y1: 0; x2: 39; y2: 0; capStart: 0; capEnd: 1),
           (x1: 0; y1: 0; x2: 0; y2: 23; capStart: 0; capEnd: 2),
           (x1: 39; y1: 0; x2: 39; y2: 23; capStart: 1; capEnd: 3),
           (x1: 0; y1: 23; x2: 39; y2: 23; capStart: 2; capEnd: 3));
    lineEnd: $FE; lineEndTail: 0);
  { the inner box DrawExploreFrame adds inside the split frame }
  splitFrameSegments: Types.TFrameList5 = (
    segs: ((x1: 16; y1: 0; x2: 16; y2: 16; capStart: 6; capEnd: 7),
           (x1: 2; y1: 2; x2: 14; y2: 2; capStart: 0; capEnd: 1),
           (x1: 2; y1: 14; x2: 14; y2: 14; capStart: 2; capEnd: 3),
           (x1: 2; y1: 2; x2: 2; y2: 14; capStart: 0; capEnd: 2),
           (x1: 14; y1: 2; x2: 14; y2: 14; capStart: 1; capEnd: 3));
    lineEnd: $FE; lineEndTail: 0);
  { the side-divided frame }
  sideFrameSegments: Types.TFrameList5 = (
    segs: ((x1: 0; y1: 0; x2: 39; y2: 0; capStart: 0; capEnd: 1),
           (x1: 0; y1: 0; x2: 0; y2: 22; capStart: 0; capEnd: 2),
           (x1: 39; y1: 0; x2: 39; y2: 22; capStart: 1; capEnd: 3),
           (x1: 0; y1: 22; x2: 39; y2: 22; capStart: 2; capEnd: 3),
           (x1: 22; y1: 0; x2: 22; y2: 22; capStart: 6; capEnd: 7));
    lineEnd: $FE; lineEndTail: 0);

{ Word wrap. }
const
  { The punctuation word wrap may break after. }
  punct: set of '!'..'?' = ['!', ',', '-', '.', ':', ';', '?'];

{ Save file names. }
const
  { the characters SanitizeString removes from a save file name }
  invalidFileChars: array[1..10] of Char = (' ', '.', '*', ',', '?', '/', '\', ':', ';', '|');

{ The continue prompt, and the class, race, alignment, gender and coin names. }
const
  { shown when a script or message waits for a key }
  pressButtonPrompt: String[33] = 'Press button or enter to continue';
  { the continue prompt with a leading ~ }
  tildePressButtonPrompt: String[34] = '~Press button or enter to continue';
  { by class id; the last entry stands for an impossible class }
  classNameTable: array[0..17] of String[26] = (
    'Cleric',
    'Druid',
    'Fighter',
    'Paladin',
    'Ranger',
    'Magic-User',
    'Thief',
    'Monk',
    'Cleric/Fighter',
    'Cleric/Fighter/Magic-User',
    'Cleric/Ranger',
    'Cleric/Magic-User',
    'Cleric/Thief',
    'Fighter/Magic-User',
    'Fighter/Thief',
    'Fighter/Magic-User/Thief',
    'Magic-User/Thief',
    'Illegal type');
  { by race id }
  raceNameTable: array[0..6] of String[8] = (
    'Elf',
    'Half-Elf',
    'Dwarf',
    'Gnome',
    'Halfling',
    'Human',
    'Monster');
  { by alignment id }
  alignmentNameTable: array[0..8] of String[16] = (
    'Lawful Good',
    'Lawful Neutral',
    'Lawful Evil',
    'Neutral Good',
    'True Neutral',
    'Neutral Evil',
    'Chaotic Good',
    'Chaotic Neutral',
    'Chaotic Evil');
  { by gender id }
  genderNameTable: array[0..1] of String[6] = (
    'Male',
    'Female');
  { the coin and valuables names the money menus list }
  moneyNameTable: array[0..2] of String[10] = (
    'Platinum',
    'Gems',
    'Jewelry');

{ Status names, the main menu, and the item, spell and money prompts. }
const
  { by character status }
  statusNameTable: array[0..8] of String[12] = (
    'Okay',
    'Animated',
    'tempgone',
    'Running',
    'Unconscious',
    'Dying',
    'Dead',
    'Petrified',
    'Gone');
  { the main menu's choices, and which are offered before a party exists }
  mainMenuItems: array[0..12] of Types.TMenuItem = (
    (name: 'Create New Character'; enabled: 1),
    (name: 'Drop Character'; enabled: 0),
    (name: 'Modify Character'; enabled: 0),
    (name: 'Train Character'; enabled: 0),
    (name: 'Human Change Classes'; enabled: 0),
    (name: 'View Character'; enabled: 0),
    (name: 'Add Character to Party'; enabled: 1),
    (name: 'Remove Character from Party'; enabled: 0),
    (name: 'Load Saved Game'; enabled: 1),
    (name: 'Save Current Game'; enabled: 0),
    (name: 'Begin Adventuring'; enabled: 0),
    (name: 'Initialize Mouse/Joystick'; enabled: 1),
    (name: 'Exit to DOS'; enabled: 1));
  { asks whether an item is to be dropped for good }
  loseItemPrompt: String[40] = 'Lose it? ';
  { a spell or item that cannot be used where the party is }
  cantCastHereMsg: String[40] = 'Can''t be cast here...';
  { starts the message about an item that cannot be used here }
  thatItemMsg: String[40] = 'That item';
  { an item that works only in combat }
  combatOnlyItemMsg: String[40] = 'Is a combat-only item...';
  { asks whether to use the item }
  useItemPrompt: String[40] = 'Use it? ';
  { between a caster's name and the spell }
  castsWord: String[40] = 'casts';
  { the choice that stops a spell being cast }
  abortSpellPrompt: String[40] = 'Abort Spell';
  { shown when a spell is stopped }
  spellAbortedMsg: String[40] = 'Spell Aborted';
  { the money menu asks how many coins to take }
  howManyPrompt: String[40] = 'How many ';
  { and finishes the question }
  willYouTakePrompt: String[40] = ' will you take? ';
  { the money menus ask how much to move }
  howMuchPrompt: String[40] = 'How much ';
  { the gems line of the valuables count }
  gemsPrompt: String[40] = 'gems : ';
  { the jewelry line of the valuables count }
  jewelryPrompt: String[40] = 'jewelry : ';
  { heads the list of a character's valuables }
  fineCollectionMsg: String[40] = 'You have a fine collection of:';
  { starts an appraised gem's value }
  gemValuedAtMsg: String[40] = 'The gem is valued at ';
  { starts an appraised jewel's value }
  jewelValuedAtMsg: String[40] = 'The jewel is valued at ';
  { Prompts for the coin trade and drop menus. }
  selectCoinTypePrompt: String[40] = 'select type of coin ';
  { asks who receives the coins }
  tradeToPrompt: String[40] = 'trade to?';
  { asks how many coins to trade }
  willYouTradePrompt: String[40] = 'will you trade? ';

{ Messages for resting, scribing, readying, selling, identifying, dropping, depositing and quitting, and for creating,
  dropping, modifying, adding and training characters. }
const
  { asks whether to break off a rest }
  stopRestingPrompt: String[40] = 'Stop resting? ';
  { follows the name of a character who could not scribe from a scroll }
  wasGoingToScribeMsg: String[40] = ' was going to scribe from that scroll';
  { heads the item list }
  itemsHeading: String[40] = 'Items';
  { heads the list of items to ready }
  readyItemHeading: String[40] = 'Ready Item';
  { starts a message about one of the character's items }
  yourPrefix: String[40] = 'Your ';
  { warns that a dropped item is lost }
  goneForeverMsg: String[40] = 'will be gone forever';
  { an item that works only when readied }
  mustBeReadiedMsg: String[40] = 'Must be readied';
  { starts a shop's offer for an item }
  illGiveYouMsg: String[40] = 'I''ll give you ';
  { continues the offer }
  platinumForYourMsg: String[40] = ' platinum pieces for your ';
  { asks whether to take the offer }
  isItADealPrompt: String[40] = 'is it a deal? ';
  { shown when the sale goes through }
  soldMsg: String[40] = 'sold!';
  { the seller cannot carry the money }
  overloadedMsg: String[40] = 'overloaded. money will be put in pool.';
  { Note: cut off at 40 characters }
  identifyOfferMsg: String[40] = 'for 100 platinum pieces i''ll identify yo';
  { an identified item with nothing more to learn }
  nothingNewMsg: String[40] = 'i cannot tell anything new about your ';
  { starts the description of an unidentified item }
  looksLikeMsg: String[40] = 'it looks like some sort of ';
  { asks how many coins to drop }
  willYouDropPrompt: String[40] = 'will you drop? ';
  { ViewChar: At a vault coins are deposited; anywhere else they are dropped. }
  willYouDepositPrompt: String[40] = 'will you deposit? ';
  { asks whether to leave the game }
  quitToDosPrompt: String[40] = 'Quit to DOS ';
  { asks again when the game has not been saved }
  quitUnsavedPrompt: String[40] = 'game not saved. quit anyway? ';
  { character creation's race menu }
  pickRacePrompt: String[40] = 'Pick Race';
  { the gender menu }
  pickGenderPrompt: String[40] = 'Pick Gender';
  { the class menu }
  pickClassPrompt: String[40] = 'Pick Class';
  { the deity menu }
  pickDeityPrompt: String[40] = 'Pick Diety';
  { the alignment menu }
  pickAlignmentPrompt: String[40] = 'Pick Alignment';
  { asks whether to roll the ability scores again }
  rerollStatsPrompt: String[40] = 'reroll stats? ';
  { asks for the new character's name }
  characterNamePrompt: String[40] = 'character name: ';
  { asks whether to keep the new character }
  saveCharacterPrompt: String[40] = 'save character? ';
  { starts the question before a character is dropped }
  dropPrefix: String[40] = 'drop ';
  { ends it }
  foreverSuffix: String[40] = ' forever ';
  { asks for confirmation }
  areYouSurePrompt: String[40] = 'Are you sure? ';
  { follows the name of a character dropped from the party }
  dumpedOutBackMsg: String[40] = ' is dumped out back.';
  { follows the name of a character who leaves the party }
  bidsFarewellMsg: String[40] = ' bids you farewell.';
  { follows the party's name when a dropped character is kept after all }
  sighOfReliefMsg: String[40] = ' breathe a sigh of relief.';
  { follows the name of a character that cannot be modified }
  cantBeModifiedMsg: String[40] = ' can''t be modified.';
  { asks which storage to add a character from }
  addFromWherePrompt: String[40] = 'add from where? ';
  { asks which character to add }
  addCharacterPrompt: String[40] = 'add a character: ';
  { a choice the CGA display does not offer }
  notInCgaMsg: String[40] = 'sorry not in CGA';
  { heads the combat icon's ready and action poses }
  readyActionHeading: String[40] = 'ready   action';
  { labels the new icon }
  newWord: String[40] = 'new';
  { labels the old icon }
  oldWord: String[40] = 'old';
  { asks whether to keep the edited icon }
  iconOkPrompt: String[40] = 'is this icon ok? ';
  { a character not ready to train }
  notEnoughExperienceMsg: String[40] = 'not enough experience';
  { follows the name of a character about to train }
  willBecomeMsg: String[40] = ' will become:';
  { starts each class line of the training result }
  aLevelPrefix: String[40] = '    a level ';
  { starts each further class line }
  andALevelPrefix: String[40] = 'and a level ';
  { asks whether to train }
  wishToTrainPrompt: String[40] = 'do you wish to train? ';
  { shown when training succeeds }
  congratulationsMsg: String[40] = 'congratulations...';
  { follows the name of a character seeking knighthood }
  petitioningMsg: String[40] = 'is petitioning to become a';
  { the knightly order of the sword }
  swordWord: String[40] = 'sword';
  { the knightly order of the rose }
  roseWord: String[40] = 'rose';
  { starts the order's title }
  knightOfThePrefix: String[40] = 'knight of the ';
  { follows the name of a character too low in level to be knighted }
  tooInexperiencedMsg: String[40] = ' is too inexperienced';
  { follows the name of a character who does not qualify }
  doesNotQualifyMsg: String[40] = ' does not qualify.';
  { follows the name of a character who qualifies }
  mayBecomeMsg: String[40] = ' may become a';

{ Messages for saving and loading, the game speed and making camp. }
const
  { Asks for the save disk; saveDiskInDrivePrompt2 holds the same text. }
  saveDiskInDrivePrompt1: String[40] = 'is your save disk in drive ';
  { the same question again }
  saveDiskInDrivePrompt2: String[40] = 'is your save disk in drive ';
  { follows the drive letter }
  driveQuerySuffix: String[40] = ':? ';
  { the game's save directory is missing }
  noPodDirMsg: String[40] = 'error, can''t locate POD directory';
  { the directory characters are imported from is missing }
  noSsbDirMsg: String[40] = 'error, can''t locate SSB directory';
  { a save that does not fit }
  diskFullMsg: String[40] = 'can''t save.  disk is full.';
  { starts the question before a save file is replaced }
  overwritePrompt: String[40] = 'overwrite ';
  { ends a question }
  questionSuffix: String[40] = '? ';
  { asks for a save file name }
  newFileNamePrompt: String[40] = 'new file name : ';
  { follows a choice that has been made }
  hasBeenSelectedMsg: String[40] = 'has been selected';
  { asks for the game speed }
  gameSpeedPrompt: String[40] = 'Game Speed (0=fastest 9=slowest) = ';
  { shown when Camp starts }
  makesCampMsg: String[40] = 'the party makes camp...';

{ Messages for searching, fighting and shopping. }
const
  { shown when a search or camp is not allowed }
  notHereMsg: String[40] = 'not here';
  { asks before an ally is attacked }
  attackAllyPrompt: String[40] = 'attack ally? ';
  { starts the range line of the aim cursor }
  rangePrompt: String[40] = 'range = ';
  { quick magic switched on }
  magicOnMsg: String[40] = 'magic on';
  { quick magic switched off }
  magicOffMsg: String[40] = 'magic off';
  { asks whether to flee }
  fleePrompt: String[40] = 'flee ? ';
  { a move the arena does not allow }
  cantGoThereMsg: String[40] = 'cant''t go there';
  { follows the name of a character who buys an item }
  buysSuffix: String[40] = ' buys ';
  { the same with the article }
  buysASuffix: String[40] = ' buys a ';
  { an item the buyer cannot pay for }
  notEnoughMoneyMsg: String[40] = 'not enough money.';
  { warns that pooled money was left in the shop }
  leftMoneyMsg: String[80] = 'as you leave a man says, "excuse me but you have left some money here." ';
  { asks whether to go back for it }
  goBackForMoneyPrompt: String[80] = 'do you want to go back and get your money?';

{ Messages for the end of a fight, the bank and the treasure. }
const
  { ends a fight the party ran from }
  partyFledMsg: String[40] = 'the party has fled.';
  { ends a fight the party lost }
  lostFightMsg: String[40] = 'you have lost the fight.';
  { ends a fight the party won }
  partyWonMsg: String[40] = 'the party has won.';
  { the bank's withdrawal fee message }
  withdrawalFeeMsg1: String[40] = 'the party makes a withdrawl. a small';
  { and its second line }
  withdrawalFeeMsg2: String[40] = 'fee has been assessed by the bank.';
  { shown when the defeated left treasure }
  foundTreasureMsg: String[40] = 'the party has found treasure';
  { shown when they left none }
  noTreasureMsg: String[40] = 'the party has found no treasure';
  { starts the experience award }
  eachReceivesMsg: String[40] = 'each character receives ';
  { ends it }
  experiencePointsMsg: String[40] = 'experience points.';
  { warns that treasure is being left behind }
  treasureLeftMsg: String[40] = 'there is still treasure left. ';

{ Messages for unclaimed treasure and the temple's cures. }
const
  { asks whether to go back for it }
  claimTreasurePrompt: String[40] = 'do you want to go back and claim it?';
  { asks whether to cast a cure that is not needed }
  cureAnywayPrompt: String[40] = 'cast cure anyway? ';
  { asks whether to pay the temple }
  payForCurePrompt: String[40] = 'pay for cure? ';
  { follows the name of a cured character }
  isCuredMsg: String[40] = 'is cured.';
  { follows the name of a character with no blindness to cure }
  notBlindMsg: String[40] = 'is not blind.';
  { no disease to cure }
  notDiseasedMsg: String[40] = 'is not diseased.';
  { a character beyond raising }
  cannotRaiseMsg: String[40] = 'cannot be raised.';
  { a character the temple cannot help }
  beyondHelpMsg: String[40] = 'is beyond our help';
  { no death to undo }
  notDeadMsg: String[40] = 'is not dead.';
  { no poison to cure }
  notPoisonedMsg: String[40] = 'is not poisoned.';
  { no curse to lift }
  notCursedMsg: String[40] = 'is not cursed.';
  { no petrification to undo }
  notStonedMsg: String[40] = 'is not stoned.';
  { no drained levels to restore }
  noLostLevelsMsg: String[40] = 'has no lost levels.';
  { the temple's greeting after the character's name }
  howCanWeHelpPrompt: String[40] = ', how can we help you?';

{ Menu prompts. }
const
  { the empty prompt of a menu that asks nothing }
  emptyQuery: String[40] = '';
  { the in-game version }
  versionBanner: String[40] = 'POOLS OF DARKNESS 1.10 ';
  { the spell menu's prompt }
  chooseSpellPrompt: String[40] = 'Choose Spell:';
  { asks which kind of flame a spell makes }
  flameTypePrompt: String[40] = 'Flame type: ';
  { the appraisal menu's prompt }
  appraisePrompt: String[40] = 'Appraise : ';
  { the character menu's prompt }
  pickCharacterPrompt: String[40] = 'Pick Character ';
  { the modify menu's prompt }
  modifyPrompt: String[40] = 'Modify : ';
  { the input device menu's prompt }
  initMousePrompt: String[40] = 'Init mouse/joystick: ';
  { asks before a character is dropped }
  loseCharacterPrompt: String[40] = 'lose character? ';
  { asks which storage to load from }
  loadFromWherePrompt: String[40] = 'load from where? ';
  { asks which saved game to load }
  loadWhichGamePrompt: String[40] = 'load which game: ';
  { asks which slot to save into }
  saveWhichGamePrompt: String[40] = 'save which game: ';
  { asks whether the memorized spells are right }
  spellsOkPrompt: String[40] = 'spells OK? ';
  { asks whether to scribe the listed spells }
  scribeSpellsPrompt: String[40] = 'scribe these spells? ';
  { the party order menu's prompt }
  partyOrderPrompt: String[40] = 'party order ';
  { starts the game speed line }
  gameSpeedPrefix: String[40] = 'game speed: ';
  { the aim menu's prompt }
  aimPrompt: String[40] = 'aim: ';
  { reminds the player how to move the aim cursor }
  useCursorKeysPrompt: String[40] = '(use cursor keys) ';
  { asks whether to keep fighting }
  continueBattlePrompt: String[40] = 'continue battle? ';
  { starts the moves-left line of the combat move menu }
  moveLeftPrompt: String[40] = 'move/attack, move left = ';
  { the item menu's prompt }
  itemsPrompt: String[40] = 'items : ';
  { the take menu's prompt }
  takePrompt: String[40] = 'take: ';

{ Menu choice lists. }
const
  { an empty prompt }
  blankPrompt: String[40] = '';
  { the title menu's choice }
  playDemoMenu: String[40] = 'Play Demo';
  { the yes/no menu }
  yesNoChoices: String[40] = 'Yes No';
  { a menu with Select alone }
  selectMenu: String[40] = 'Select';
  { a menu with Select and Exit }
  selectExitMenu: String[40] = 'Select Exit';
  { the cast choice }
  castMenu: String[40] = 'Cast';
  { the memorize choice }
  memorizeMenu: String[40] = 'Memorize';
  { the keep choice }
  keepMenu: String[40] = 'Keep';
  { the scribe choice }
  scribeMenu: String[40] = 'Scribe';
  { the learn choice }
  learnMenu: String[40] = 'Learn';
  { the two kinds of flame }
  hotColdMenu: String[40] = 'Hot Cold';
  { the valuables menu }
  gemsJewelryMenu: String[40] = 'Gems Jewelry Exit';
  { the sell or keep menu }
  sellKeepMenu: String[40] = 'Sell Keep';
  { the rest menu's time-setting choices }
  restMenu: String[40] = 'Rest Days Hours Mins Add Subtract Exit';
  { the camp menu for one character }
  encampCharMenu: String[80] = 'Items Spells Trade Deposit Drop Lay Cure Exit';
  { what can be done with an item }
  itemActionMenu: String[80] = 'Ready Use Trade Deposit Drop Halve Join Sell Id';
  { the number adjusting menu }
  addSubtractKeepMenu: String[40] = 'Add Subtract Keep Exit';
  { the transfer menu's storages }
  poolsSecretMenu: String[40] = 'Pools Secret Exit';
  { the add choice }
  addMenu: String[40] = 'Add';
  { a menu with Change and Exit }
  changeExitMenu: String[40] = 'Change Exit';
  { the missing disk menu }
  tryAnotherDiskMenu: String[40] = 'Ok Try another disk';
  { the drive letters a disk can be read from }
  driveLetterMenu: String[40] = 'A B C D E F G H I J';
  { the party order menu's choices }
  selectPlaceMenu: String[40] = 'Select Place Exit';
  { the game speed menu }
  speedMenuItems: String[40] = 'Faster Slower Exit';
  { the exploring menu }
  moveMenuItems: String[40] = 'Move Area Cast View Encamp Search Look';
  { a menu with Exit alone }
  exitMenu: String[40] = 'Exit';
  { the combat menu; @ marks the line break }
  combatMenuItems: String[80] = 'Move Aim Use Cast Turn Guard Quick@Delay Bandage View Speed End';
  { a menu with Done alone }
  doneMenu: String[40] = 'Done';
  { the aim menu }
  aimMenu: String[40] = 'Next Prev Manual Target Center Exit';
  { the manual aim cursor's menu, where MenuCore.AppendSlot enables one of the two words; Space centers the cursor }
  targetExitMenu: String[40] = 'Target Exit';
  { the buy choice }
  buyMenu: String[40] = 'Buy';
  { the shop menu }
  storeMenuItems: String[40] = 'Buy View Take Pool Share Appraise Exit';
  { clears a price line }
  blankPriceLine: String[30] = '                              ';
  { the take choice }
  takeMenu: String[40] = 'Take';
  { the money or items menu }
  moneyItemsMenu: String[40] = 'Money Items Exit';
  { the treasure menu after a fight }
  treasureMenu: String[40] = 'View Take Pool Share Detect Exit';
  { heads the temple's healing list }
  healHeading: String[40] = 'Heal';
  { the temple menu }
  healBuildingMenu: String[40] = 'Heal View Repair Exit';
  { the vault menu }
  vaultMenuItems: String[40] = 'View Take Pool Money Items Exit';
  { CharGen's icon-customization menus, by menu state: parts, head/weapon, body parts, size, next/previous. }
  iconMenus: array[1..5] of String[45] = (
    'Parts 1st-color 2nd-color Size Exit',
    'Head Weapon Exit',
    'Weapon Body Hair Face Shield Arm Leg Exit',
    'Small Large Keep Exit',
    'Next Prev Keep Exit');
  { the camp menu }
  campMenu: String[40] = 'Save View Magic Rest Alter Fix Exit';
  { the camp magic menu }
  campMagicMenuItems: String[40] = 'Cast Memorize Scribe Display Rest Exit';
  { the camp alter menu }
  campAlterMenuItems: String[40] = 'Order Drop Speed Icon Level Exit';
  { the difficulty levels of the alter menu's Level choice }
  levelMenu: String[40] = 'Novice Squire Veteran Adept Champion';
  { follows a difficulty name }
  levelSuffix: String[10] = ' Level';

{ Item names. }
const
  { item name words by nameIds }
  itemNameParts: array[1..125] of String[20] = (
    'Battle Axe',
    'Hand Axe',
    'Club',
    'Dagger',
    'Dart',
    'Hammer',
    'Javelin',
    'Mace',
    'Morning Star',
    'Military Pick',
    'Awl Pike',
    'Bolt',
    'Scimitar',
    'Spear',
    'Quarter Staff',
    'Bastard Sword',
    'Broad Sword',
    'Long Sword',
    'Short Sword',
    'Two-Handed Sword',
    'Trident',
    'Composite Long Bow',
    'Composite Short Bow',
    'Long Bow',
    'Short Bow',
    'Fine',
    'Light Crossbow',
    'Sling',
    'Staff',
    'Arrow',
    'Leather',
    'Ring',
    'Scale',
    'Chain',
    'Banded',
    'Plate',
    'Shield',
    'Cleric',
    'Scroll',
    'Mage',
    'Helm',
    'Belt',
    'Robe',
    'Cloak',
    'Boots',
    'Ring',
    'Mail',
    'Armor',
    'Of Prot',
    'Bracers',
    'Wand',
    'Elixir',
    'Potion',
    'Youth',
    'Ruby',
    'Boulder',
    'Dragon Breath',
    'Displacement',
    'Eyes',
    'Drow',
    'Elfin Chain',
    'Ice Storm',
    'Saphire',
    'Emerald',
    'Wizardry',
    'Hornet''s Nest',
    'Fire Resistance',
    'Stone',
    'Good Luck',
    'Flail',
    'Halberd',
    'Gauntlets',
    'Periapt',
    'Health',
    'Cursed',
    'Blessed',
    'Bundle of',
    'Ogre Power',
    'Girdle',
    'Giant Strength',
    'Mirror',
    'Necklace',
    'Dragon',
    'vs Giants',
    'vorpal',
    'cold resistance',
    'Diamond',
    'Lightning',
    'Fireballs',
    'of',
    'Vulnerability',
    'Speed',
    'Silver',
    'Extra',
    'Healing',
    'Charming',
    'Fear',
    'Magic Missiles',
    'Missiles',
    '1 Spell',
    '2 Spells',
    '3 Spells',
    'Paralyzation',
    'Invisibility',
    'Cute Yellow Canary',
    'AC 10',
    'AC 6',
    'AC 4',
    'AC 3',
    'AC 2',
    '+1',
    '+2',
    '+3',
    '+4',
    '+5',
    '-1',
    '-2',
    '-3',
    'Electrical Immunity',
    'Gaze Resistance',
    'Spiritual',
    'Gem',
    'Jewelry',
    'Blinking',
    'from evil');

{ Compass directions. }
const
  { the direction abbreviations, by facing 0..7 }
  directionNames: array[0..7] of String[2] = (
    'N',
    'NE',
    'E',
    'SE',
    'S',
    'SW',
    'W',
    'NW');
  { The direction code of a line step by [stepY + 1, stepX + 1]: 0..7 clockwise from north, 8 for no step. }
  directionByStep: array[0..2, 0..2] of Byte = (
    (7, 0, 1),
    (6, 8, 2),
    (5, 4, 3));
  { the EGA plane masks from plane 3 down to 0, then 0 }
  egaPlaneMask: array[0..4] of Byte = (
    $08, $04, $02, $01, $00);

{ EGA planes and color maps. }
const
  { the EGA plane mask by plane }
  planeBit: array[0..3] of Byte = (1, 2, 4, 8);
  { The pattern CharGen and View3D pass to Blit.FillPicRect. Note: FillPicRect takes it but never uses it. }
  standardColorMap: Types.TColorMap = ($00, $11, $22, $12, $01, $21, $30, $33);
  { The source map MapTiles hands Blit.RemapPic: the identity. }
  identityColorMap: Types.TColorTab = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
  { the identity with color 8 as 0 }
  pink8ColorMap: Types.TColorTab = (0, 1, 2, 3, 4, 5, 6, 7, 0, 9, 10, 11, 12, 13, 14, 15);

{ Sound ids and the disk prompts. }
const
  { DaxIo: the reset request DiskBegin sends the driver; SoundDrv.SoundCommand ignores ids outside 2..12 }
  soundReset: Word = $00FF;
  { The sound ids 0..15 as Words, the values the game hands its sound routines; the C_Sound names index the ones it
    plays by name. }
  soundIds: array[0..15] of Word = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
  { the disk prompts by disk }
  insertDisk2Prompt: String[29] = 'Insert disk 2 in drive ';
  { disk 3 }
  insertDisk3Prompt: String[29] = 'Insert disk 3 in drive ';
  { disk 4 }
  insertDisk4Prompt: String[29] = 'Insert disk 4 in drive ';
  { no prompt }
  blankDiskPrompt: String[29] = '';
  { disk 5 }
  insertDisk5Prompt: String[29] = 'Insert disk 5 in drive ';

{ The 8x8 symbol sets. }
const
  { By 8x8 symbol set 0..2: the symbol number a set's glyph 0 has; set 2 is the frame border set. }
  symbolSetBase: array[0..2] of Word = (0, 256, 296);
  { the highest symbol number each set covers }
  symbolSetCeiling: array[0..2] of Word = (255, 275, 307);

{ Directions, terrain and icon footprints. }
const
  { The x step of each direction 0..7 clockwise from north; entry 8 is no step. }
  dirDeltaX: array[0..8] of ShortInt = (0, 1, 1, 1, 0, -1, -1, -1, 0);
  { the y step of each direction }
  dirDeltaY: array[0..8] of ShortInt = (-1, -1, 0, 1, 1, 1, 0, -1, 0);
  { By terrain class 1..69, the index a combat-arena cell holds. CbtMap draws tileId, the combat movers charge cost, and
    Pathing tests the two heights for line of sight. }
  terrainTable: array[1..69] of Types.TTerrain = (
    {  1 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 0),
    {  2 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 1),
    {  3 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 2),
    {  4 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 3),
    {  5 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 4),
    {  6 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 5),
    {  7 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 6),
    {  8 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 7),
    {  9 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 8),
    { 10 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 9),
    { 11 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 10),
    { 12 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 11),
    { 13 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 12),
    { 14 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 13),
    { 15 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 14),
    { 16 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 15),
    { 17 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 16),
    { 18 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 17),
    { 19 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 18),
    { 20 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 19),
    { 21 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 20),
    { 22 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 21),
    { 23 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 22),
    { 24 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 23),
    { 25 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 24),
    { 26 } (cost: 2; cellHeight: 2; obstacleHeight: 0; tileId: 38),
    { 27 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 14),
    { 28 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 13),
    { 29 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 12),
    { 30 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 20),
    { 31 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 21),
    { 32 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 0),
    { 33 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 1),
    { 34 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 2),
    { 35 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 3),
    { 36 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 4),
    { 37 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 5),
    { 38 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 6),
    { 39 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 7),
    { 40 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 8),
    { 41 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 9),
    { 42 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 10),
    { 43 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 2; tileId: 11),
    { 44 } (cost: 2; cellHeight: 1; obstacleHeight: 0; tileId: 12),
    { 45 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 13),
    { 46 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 14),
    { 47 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 15),
    { 48 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 16),
    { 49 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 17),
    { 50 } (cost: 2; cellHeight: 1; obstacleHeight: 0; tileId: 18),
    { 51 } (cost: 2; cellHeight: 1; obstacleHeight: 0; tileId: 19),
    { 52 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 20),
    { 53 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 21),
    { 54 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 22),
    { 55 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 0; tileId: 23),
    { 56 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 0; tileId: 24),
    { 57 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 0; tileId: 25),
    { 58 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 26),
    { 59 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 27),
    { 60 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 28),
    { 61 } (cost: 1; cellHeight: 0; obstacleHeight: 0; tileId: 29),
    { 62 } (cost: 1; cellHeight: 0; obstacleHeight: 0; tileId: 30),
    { 63 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 0; obstacleHeight: 0; tileId: 31),
    { 64 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 0; tileId: 32),
    { 65 } (cost: 2; cellHeight: 1; obstacleHeight: 0; tileId: 33),
    { 66 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 34),
    { 67 } (cost: C_Terr.TERRAIN_IMPASSABLE; cellHeight: 1; obstacleHeight: 0; tileId: 35),
    { 68 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 36),
    { 69 } (cost: 1; cellHeight: 1; obstacleHeight: 0; tileId: 37));
  { The cells an icon of footprint size 1..5 covers, as offsets from its anchor cell; a negative dx marks a cell the
    size does not use. }
  footprintOffsets: array[1..5, 0..5] of Types.TIconDelta = (
    { 1 } ((dx: 0; dy: 0), (dx: -1; dy: -1), (dx: -1; dy: -1),
          (dx: -1; dy: -1), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    { 2 } ((dx: 0; dy: 0), (dx: 0; dy: 1), (dx: -1; dy: -1),
          (dx: -1; dy: -1), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    { 3 } ((dx: 0; dy: 0), (dx: 1; dy: 0), (dx: -1; dy: -1),
          (dx: -1; dy: -1), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    { 4 } ((dx: 0; dy: 0), (dx: 1; dy: 0), (dx: 0; dy: 1),
          (dx: 1; dy: 1), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    { 5 } ((dx: 0; dy: 0), (dx: 1; dy: 0), (dx: 0; dy: 1),
          (dx: 1; dy: 1), (dx: 2; dy: 0), (dx: 2; dy: 1)));

{ Effect lists, the effect report's words, and the effect names. }
const
  { The effect ids that mean helpless (CharHlp). }
  helplessEffects: array[1..4] of Byte = (C_Effect.HELPLESS, C_Effect.HELPLESS_51, C_Effect.HELD,
                                          C_Effect.ASLEEP);
  { the effect ids that mean diseased (Temple) }
  diseaseEffects: array[1..4] of Byte = (C_Effect.HELPLESS, C_Effect.DISEASED, C_Effect.DISEASE_STRENGTH,
                                         C_Effect.DISEASE_HIT_POINTS);
  { the fifteen effects PostCbt clears from every combatant when a fight ends }
  clearEffects: array[1..15] of Byte = (C_Effect.SNAKE_HARASS, C_Effect.CHARM, C_Effect.SILENCE,
                                        C_Effect.SPIRITUAL_HAMMER,
    C_Effect.CONFUSED_LOSE_TURN, C_Effect.CONFUSED, C_Effect.HELPLESS, C_Effect.HELPLESS_51,
        C_Effect.HELD, C_Effect.ASLEEP, C_Effect.DRAGON_FEARED,
    C_Effect.DANCING, C_Effect.FRIGHTENED, C_Effect.STUNNED, C_Effect.CONFUSED_BERSERK);
  { the effect report's words }
  isWord: String[10] = 'is ';
  { negates the report }
  notWord: String[10] = 'not ';
  { a target healed }
  healedMsg: String[10] = 'Healed';
  { a target the spell took hold of }
  affectedMsg: String[10] = 'Affected';
  { a target that resisted }
  unaffectedMsg: String[10] = 'Unaffected';
  { a target protected from the spell }
  protectedMsg: String[10] = 'Protected';
  { starts the name of what the target is protected from }
  protectedFromPrefix: String[20] = 'Protected from ';
  { starts what the target gains }
  gainsWord: String[10] = 'gains ';
  { the effect names, by effect id }
  effectNames: array[1..127] of String[37] = (
    'Blessed',
    'Cursed',
    'Harrassed by Snakes',
    'Dispelling Evil',
    'Detecting Magic',
    'Immune to Electricity',
    'Gnome thac0 bonus',
    'Protected from Evil',
    'Protected from Good',
    'Resistant to Cold',
    'Charmed',
    'Enlarged',
    'Barkskin',
    'Friendly',
    'Slow Poison',
    'Reading Magic',
    'Shielded',
    '30% resistant to charm',
    'Able to Find Traps',
    'Fire Resistant (spell)',
    'Silenced',
    'Slow poison wears off',
    'Carries Spiritual Hammer',
    'Sees Invisible',
    'Invisible (spell)',
    'Dwarf thac0 bonus',
    'Confused. Lose Turn',
    'Duplicated',
    'Enfeebled',
    'Nauseated',
    'Helpless Effect # 31',
    'Dispel Evil On',
    'Blind',
    'Diseased',
    'Confused',
    'Accursed',
    'Blinking',
    'Strengthened',
    'Hastened',
    'Rakshasa Protection',
    'Protected from Normal Missiles',
    'Slowed',
    'Disease Strength Lose',
    'Disease Health Lose',
    'Protected from Evil, 10'' Radius',
    'Protected from Good, 10'' Radius',
    'Dwarf Giant Bonus',
    'Gnome Large Monster Bonus',
    'Affected by Prayer',
    'Fire Shield, Hot flames',
    'Helpless Effect #51',
    'Held',
    'Asleep',
    'Fire Shield, Cold flames',
    'POISONED',
    'Invisible (ring)',
    'Enveloped in Globe of Invulnerability',
    'Petrification Gaze Attack',
    'Effect #59',
    '+3 weapons or better to hit',
    'Fire Resistant (ring)',
    'Regeneration',
    'Within Minor Globe of Invulnerability',
    'Deadly Poison Attack',
    'Petrification Touch Attack',
    'half damage from pierce/cut weapons',
    'half damage from crushing weapons',
    'Mentally Enfeebled',
    'Invisible to Animals',
    'confusion gaze',
    'Magically Highlighted',
    'mirror ready',
    'Immune to Dragon Breath',
    'Wearing Magical Boots',
    'giant slaying sword',
    'Immune to Disease',
    'Confused',
    'Carrying Magical Stone',
    'iron golem spell immunity',
    'luck stone',
    'half damage fro weapons < +3',
    'killed by blessed crossbow bolts',
    'big red dragon breath',
    'red dragon breath',
    'white dragon breath',
    'deadly poison -2',
    'effect 87',
    'paralzing poison',
    'Wearing Magical Cloak',
    'green dragon breath',
    'blue dragon breath',
    'immune to fear',
    'immune to fire',
    'dwarven save bonus',
    '90% resistant to sleep/charm',
    'black dragon breath',
    'dwarven save bonus',
    'immune to cold',
    'bullet rake attack',
    'dragon fear attack',
    'drain 1 level',
    'drain 2 levels',
    'immune to nonmagical weapons',
    '+4d6 fire damage',
    'bonus damage from rangers',
    'Stunned',
    'Berserk',
    '+2d6 fire damage',
    'paladin can heal',
    'paladin cant''t remove curse',
    'FRIGHTENED',
    'fire shield',
    'Giant Strength',
    'paralyze gaze attack',
    'vorpal weapon',
    'multiple attacks by new weapons',
    'Effect #117',
    'Dancing',
    'Resist Fire (Druid)',
    'affected by dragon fear',
    'Fire Touch',
    'Iron Skin',
    'Shielded by Mind Blank',
    'effect 124',
    'immune to weapons < +2',
    'immune to gaze attacks',
    'effect 127');

{ The yes/no menu's answers. }
const
  { The two answers MenuCore.YesNoMenu returns, passed to it as the highlighted default and compared with its result.
    This one is Yes. }
  yesChoice: Byte = 0;
  { the No answer }
  noChoice: Byte = 1;

{ Keypad and mouse keys. }
const
  { Keypad digits 1..9 as the extended scan codes of the keys they sit on: End, Down, Page Down, Left, (5 is a space)
    Right, Home, Up, Page Up. }
  keypadArrowKeys: array[0..8] of Byte = (Ord(C_Keys.END_KEY), Ord(C_Keys.DOWN), Ord(C_Keys.PAGE_DOWN),
                                          Ord(C_Keys.LEFT), 32, Ord(C_Keys.RIGHT), Ord(C_Keys.HOME),
                                          Ord(C_Keys.UP), Ord(C_Keys.PAGE_UP));
  { The arrow an aimed mouse click stands for, by combat-view cell [row, column]: 72 up, 77 right, 80 down, 75 left, the
    center cell reading as up. }
  combatClickKeys: array[3..13, 3..13] of Byte = (
    (72, 72, 72, 72, 72, 72, 72, 72, 72, 72, 72),
    (75, 72, 72, 72, 72, 72, 72, 72, 72, 72, 77),
    (75, 75, 72, 72, 72, 72, 72, 72, 72, 77, 77),
    (75, 75, 75, 72, 72, 72, 72, 72, 77, 77, 77),
    (75, 75, 75, 75, 72, 72, 72, 77, 77, 77, 77),
    (75, 75, 75, 75, 75, 72, 77, 77, 77, 77, 77),
    (75, 75, 75, 75, 80, 80, 80, 77, 77, 77, 77),
    (75, 75, 75, 80, 80, 80, 80, 80, 77, 77, 77),
    (75, 75, 80, 80, 80, 80, 80, 80, 80, 77, 77),
    (75, 80, 80, 80, 80, 80, 80, 80, 80, 80, 77),
    (80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 80));

{ The cells of a terrain patch. }
const
  { The nine cells of a 3x3 patch as dirDeltaX/dirDeltaY direction codes: 8 is the center, then E clockwise round to NE.
    CbtMap, GameTime, Magic and FxEngine walk it 1..9. }
  patchDirs: array[1..9] of Byte = (8, 2, 3, 4, 5, 6, 7, 0, 1);

{ Spell names. }
const
  { The spell names, indexed by spell id 1..126 -- the same ids as spellTable. }
  spellNames: array[1..126] of String[34] = (
    { 1 }
    'Bless',
    { 2 }
    'Curse',
    { 3 }
    'Cure Light Wounds',
    { 4 }
    'Cause Light Wounds',
    { 5 }
    'Detect Magic',
    { 6 }
    'Protection From Evil',
    { 7 }
    'Protection from Good',
    { 8 }
    'Resist Cold',
    { 9 }
    'Burning Hands',
    { 10 }
    'Charm Person',
    { 11 }
    'Detect Magic',
    { 12 }
    'Enlarge',
    { 13 }
    'Reduce',
    { 14 }
    'Friends',
    { 15 }
    'Magic Missile',
    { 16 }
    'Protection From Evil',
    { 17 }
    'Protection From Good',
    { 18 }
    'Read Magic',
    { 19 }
    'Shield',
    { 20 }
    'Shocking Grasp',
    { 21 }
    'Sleep',
    { 22 }
    'Find Traps',
    { 23 }
    'Hold Person',
    { 24 }
    'Resist Fire',
    { 25 }
    'Silence, 15'' Radius',
    { 26 }
    'Slow Poison',
    { 27 }
    'Snake Charm',
    { 28 }
    'Spiritual Hammer',
    { 29 }
    'Detect Invisibility',
    { 30 }
    'Invisibility',
    { 31 }
    'Knock',
    { 32 }
    'Mirror Image',
    { 33 }
    'Ray of Enfeeblement',
    { 34 }
    'Stinking Cloud',
    { 35 }
    'Strength',
    { 36 }
    'Heal',
    { 37 }
    'Cure Blindness',
    { 38 }
    'Cause Blindness',
    { 39 }
    'Cure Disease',
    { 40 }
    'Cause Disease',
    { 41 }
    'Dispel Magic',
    { 42 }
    'Prayer',
    { 43 }
    'Remove Curse',
    { 44 }
    'Bestow Curse',
    { 45 }
    'Blink',
    { 46 }
    'Dispel Magic',
    { 47 }
    'Fireball',
    { 48 }
    'Haste',
    { 49 }
    'Hold Person',
    { 50 }
    'Invisibility, 10'' Radius',
    { 51 }
    'Lightning Bolt',
    { 52 }
    'Protection From Evil, 10'' Radius',
    { 53 }
    'Protection From Good, 10'' Radius',
    { 54 }
    'Protection From Normal Missiles',
    { 55 }
    'Slow',
    { 56 }
    'Harm',
    { 57 }
    'Potion Of Speed',
    { 58 }
    'Cure Serious Wounds',
    { 59 }
    'Potion Of Frost',
    { 60 }
    'Javelin Of Lightning',
    { 61 }
    'Wand Of Paralyzation',
    { 62 }
    'Potion Of Healing',
    { 63 }
    'Elixir Of Youth',
    { 64 }
    'Necklace Of Missiles',
    { 65 }
    'Wand Of Magic Missiles',
    { 66 }
    'Cause Serious Wounds',
    { 67 }
    'Neutralize Poison',
    { 68 }
    'Poison',
    { 69 }
    'Protection Evil, 10'' Radius',
    { 70 }
    'Sticks to Snakes',
    { 71 }
    'Cure Critical Wounds',
    { 72 }
    'Cause Critical Wounds',
    { 73 }
    'Dispel Evil',
    { 74 }
    'Flame Strike',
    { 75 }
    'Raise Dead',
    { 76 }
    'Slay Living',
    { 77 }
    'Detect Magic',
    { 78 }
    'Entangle',
    { 79 }
    'Faerie Fire',
    { 80 }
    'Invisibility to Animals',
    { 81 }
    'Charm Monsters',
    { 82 }
    'Confusion',
    { 83 }
    'Dimension Door',
    { 84 }
    'Fear',
    { 85 }
    'Fire Shield',
    { 86 }
    'Fumble',
    { 87 }
    'Ice Storm',
    { 88 }
    'Minor Globe Of Invulnerability',
    { 89 }
    'Remove Curse',
    { 90 }
    'Barkskin',
    { 91 }
    'Cloud Kill',
    { 92 }
    'Cone of Cold',
    { 93 }
    'Feeblemind',
    { 94 }
    'Hold Monsters',
    { 95 }
    'Scroll of Protection',
    { 96 }
    'Charm Person Or Mammal',
    { 97 }
    'Potion Of Invisibility',
    { 98 }
    'Cure Light Wounds',
    { 99 }
    'Potion Of Extra Healing',
    { 100 }
    'Bestow Curse',
    { 101 }
    'Blade Barrier',
    { 102 }
    'Restoration',
    { 103 }
    'Energy Drain',
    { 104 }
    'Destruction',
    { 105 }
    'Resurrection',
    { 106 }
    'Cure Disease',
    { 107 }
    'Neutralize Poison',
    { 108 }
    'Hold Animal',
    { 109 }
    'Prot. from Fire',
    { 110 }
    'Death Spell',
    { 111 }
    'Disintegrate',
    { 112 }
    'Globe of Invulnerability',
    { 113 }
    'Stone to Flesh',
    { 114 }
    'Flesh to Stone',
    { 115 }
    'Delayed Blast Fireball',
    { 116 }
    'Mass Invisibility',
    { 117 }
    'Power Word Stun',
    { 118 }
    'Fire Touch',
    { 119 }
    'Iron Skin',
    { 120 }
    'Mass Charm',
    { 121 }
    'Otto''s Irr. Dance',
    { 122 }
    'Mind Blank',
    { 123 }
    'Power Word Blind',
    { 124 }
    'Meteor Swarm',
    { 125 }
    'Power Word Kill',
    { 126 }
    'Monster Summoning');

{ The spell table. }
const
  { Every spell's casting record, indexed by spell id 1..126. }
  spellTable: array[1..126] of Types.TSpellRec = (
    { 1 Bless }
    (castClass: 0; level: 1; rangeFixed: 6; rangeVar: 0; durFixed: 6; durVar: 0; area: $0A; target: 3;
     saveResult: 0; saveType: 4; effect: C_Effect.BLESS;
     whenCast: 2; castTime: 10; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 2 Curse }
    (castClass: 0; level: 1; rangeFixed: 6; rangeVar: 0; durFixed: 6; durVar: 0; area: $0A; target: 0;
     saveResult: 0; saveType: 4; effect: C_Effect.CURSE;
     whenCast: 1; castTime: 10; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 3 Cure Light Wounds }
    (castClass: 0; level: 1; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 2; castTime: 5; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 4 Cause Light Wounds }
    (castClass: 0; level: 1; rangeFixed: $FF; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 1; castTime: 5; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 5 Detect Magic }
    (castClass: 0; level: 1; rangeFixed: 3; rangeVar: 0; durFixed: 10; durVar: 0; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: C_Effect.DETECT_MAGIC;
     whenCast: 2; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 6 Protection From Evil }
    (castClass: 0; level: 1; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 3; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.PROTECTION_FROM_EVIL;
     whenCast: 2; castTime: 4; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 7 Protection from Good }
    (castClass: 0; level: 1; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 3; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.PROTECTION_FROM_GOOD;
     whenCast: 2; castTime: 4; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 8 Resist Cold }
    (castClass: 0; level: 1; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 10; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.RESIST_COLD;
     whenCast: 2; castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 9 Burning Hands }
    (castClass: 2; level: 1; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 1; castTime: 1; aiPriority: 2; offensive: 1; aiRadius: 0),
    { 10 Charm Person }
    (castClass: 2; level: 1; rangeFixed: 12; rangeVar: 0; durFixed: 60; durVar: 60; area: $04; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.CHARM;
     whenCast: 1; castTime: 1; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 11 Detect Magic }
    (castClass: 2; level: 1; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 2; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: C_Effect.DETECT_MAGIC;
     whenCast: 2; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 12 Enlarge }
    (castClass: 2; level: 1; rangeFixed: 0; rangeVar: 2; durFixed: 0; durVar: 10; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.ENLARGE;
     whenCast: 2; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 13 Reduce }
    (castClass: 2; level: 1; rangeFixed: 0; rangeVar: 2; durFixed: 0; durVar: 10; area: $04; target: 2;
     saveResult: 1; saveType: 4; effect: C_Effect.ENLARGE;
     whenCast: 2; castTime: 1; aiPriority: 0; offensive: 1; aiRadius: 0),
    { 14 Friends }
    (castClass: 2; level: 1; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 1; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: C_Effect.FRIENDS;
     whenCast: 0; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 15 Magic Missile }
    (castClass: 2; level: 1; rangeFixed: 6; rangeVar: 4; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 1; castTime: 1; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 16 Protection From Evil }
    (castClass: 2; level: 1; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 2; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.PROTECTION_FROM_EVIL;
     whenCast: 2; castTime: 1; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 17 Protection From Good }
    (castClass: 2; level: 1; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 2; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.PROTECTION_FROM_GOOD;
     whenCast: 2; castTime: 1; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 18 Read Magic }
    (castClass: 2; level: 1; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 2; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: C_Effect.READ_MAGIC;
     whenCast: 0; castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 19 Shield }
    (castClass: 2; level: 1; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 5; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: C_Effect.SHIELD;
     whenCast: 2; castTime: 1; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 20 Shocking Grasp }
    (castClass: 2; level: 1; rangeFixed: $FF; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 1; castTime: 1; aiPriority: 2; offensive: 1; aiRadius: 0),
    { 21 Sleep }
    (castClass: 2; level: 1; rangeFixed: 3; rangeVar: 4; durFixed: 0; durVar: 5; area: $09; target: 0;
     saveResult: 0; saveType: 4; effect: C_Effect.ASLEEP;
     whenCast: 1; castTime: 1; aiPriority: 4; offensive: 1; aiRadius: 1),
    { 22 Find Traps }
    (castClass: 0; level: 2; rangeFixed: 0; rangeVar: 0; durFixed: 30; durVar: 0; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: C_Effect.FIND_TRAPS;
     whenCast: 0; castTime: 5; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 23 Hold Person }
    (castClass: 0; level: 2; rangeFixed: 6; rangeVar: 0; durFixed: 4; durVar: 1; area: $06; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.HELD;
     whenCast: 1; castTime: 5; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 24 Resist Fire }
    (castClass: 0; level: 2; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 10; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.RESIST_FIRE;
     whenCast: 2; castTime: 5; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 25 Silence, 15' Radius }
    (castClass: 0; level: 2; rangeFixed: 12; rangeVar: 0; durFixed: 0; durVar: 2; area: $1F; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.SILENCE;
     whenCast: 1; castTime: 5; aiPriority: 2; offensive: 1; aiRadius: 1),
    { 26 Slow Poison }
    (castClass: 0; level: 2; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 60; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.SLOW_POISON_END;
     whenCast: 0; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 27 Snake Charm }
    (castClass: 0; level: 2; rangeFixed: 3; rangeVar: 0; durFixed: 0; durVar: 0; area: $F0; target: 0;
     saveResult: 0; saveType: 4; effect: C_Effect.HELPLESS_51;
     whenCast: 1; castTime: 5; aiPriority: 0; offensive: 1; aiRadius: 0),
    { 28 Spiritual Hammer }
    (castClass: 0; level: 2; rangeFixed: 3; rangeVar: 0; durFixed: 0; durVar: 1; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: C_Effect.SPIRITUAL_HAMMER;
     whenCast: 2; castTime: 5; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 29 Detect Invisibility }
    (castClass: 2; level: 2; rangeFixed: 0; rangeVar: 4; durFixed: 0; durVar: 5; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: C_Effect.SEE_INVISIBLE;
     whenCast: 2; castTime: 2; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 30 Invisibility }
    (castClass: 2; level: 2; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.INVISIBLE;
     whenCast: 2; castTime: 2; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 31 Knock }
    (castClass: 2; level: 2; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $00; target: 0;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 0; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 32 Mirror Image }
    (castClass: 2; level: 2; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 2; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: C_Effect.MIRROR_IMAGE;
     whenCast: 2; castTime: 2; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 33 Ray of Enfeeblement }
    (castClass: 2; level: 2; rangeFixed: 1; rangeVar: 1; durFixed: 0; durVar: 1; area: $04; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.ENFEEBLE;
     whenCast: 1; castTime: 2; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 34 Stinking Cloud }
    (castClass: 2; level: 2; rangeFixed: 3; rangeVar: 0; durFixed: 0; durVar: 1; area: $09; target: 0;
     saveResult: 3; saveType: 0; effect: C_Effect.STINKING_CLOUD_COUGH;
     whenCast: 1; castTime: 2; aiPriority: 4; offensive: 1; aiRadius: 1),
    { 35 Strength }
    (castClass: 2; level: 2; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 60; area: $00; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.STRENGTH;
     whenCast: 0; castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 36 Heal }
    (castClass: 0; level: 6; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 2; castTime: 0; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 37 Cure Blindness }
    (castClass: 0; level: 3; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 2; castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 38 Cause Blindness }
    (castClass: 0; level: 3; rangeFixed: $FF; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.BLIND;
     whenCast: 1; castTime: 10; aiPriority: 3; offensive: 1; aiRadius: 0),
    { 39 Cure Disease }
    (castClass: 0; level: 3; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $00; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 0; castTime: 100; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 40 Cause Disease }
    (castClass: 0; level: 3; rangeFixed: $FF; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.DISEASED;
     whenCast: 1; castTime: 100; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 41 Dispel Magic }
    (castClass: 0; level: 3; rangeFixed: 6; rangeVar: 0; durFixed: 0; durVar: 0; area: $09; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 2; castTime: 4; aiPriority: 1; offensive: 1; aiRadius: 1),
    { 42 Prayer }
    (castClass: 0; level: 3; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 1; area: $00; target: 3;
     saveResult: 0; saveType: 4; effect: C_Effect.PRAYER;
     whenCast: 2; castTime: 6; aiPriority: 5; offensive: 0; aiRadius: 0),
    { 43 Remove Curse }
    (castClass: 0; level: 3; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 2; castTime: 6; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 44 Bestow Curse }
    (castClass: 0; level: 3; rangeFixed: $FF; rangeVar: 0; durFixed: 0; durVar: 10; area: $04; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.BESTOW_CURSE;
     whenCast: 1; castTime: 6; aiPriority: 2; offensive: 1; aiRadius: 0),
    { 45 Blink }
    (castClass: 2; level: 3; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 1; area: $00; target: 0;
     saveResult: 0; saveType: 4; effect: C_Effect.BLINKING;
     whenCast: 1; castTime: 1; aiPriority: 4; offensive: 0; aiRadius: 0),
    { 46 Dispel Magic }
    (castClass: 2; level: 3; rangeFixed: 12; rangeVar: 0; durFixed: 0; durVar: 1; area: $09; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 2; castTime: 3; aiPriority: 1; offensive: 1; aiRadius: 1),
    { 47 Fireball }
    (castClass: 2; level: 3; rangeFixed: 10; rangeVar: 4; durFixed: 0; durVar: 0; area: $0B; target: 0;
     saveResult: 2; saveType: 4; effect: 0;
     whenCast: 1; castTime: 3; aiPriority: 7; offensive: 1; aiRadius: 3),
    { 48 Haste }
    (castClass: 2; level: 3; rangeFixed: 6; rangeVar: 0; durFixed: 3; durVar: 1; area: $0A; target: 3;
     saveResult: 0; saveType: 4; effect: C_Effect.HASTED;
     whenCast: 2; castTime: 3; aiPriority: 5; offensive: 0; aiRadius: 0),
    { 49 Hold Person }
    (castClass: 2; level: 3; rangeFixed: 12; rangeVar: 0; durFixed: 0; durVar: 2; area: $07; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.HELD;
     whenCast: 1; castTime: 3; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 50 Invisibility, 10' Radius }
    (castClass: 2; level: 3; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $09; target: 3;
     saveResult: 0; saveType: 4; effect: C_Effect.INVISIBLE;
     whenCast: 2; castTime: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 51 Lightning Bolt }
    (castClass: 2; level: 3; rangeFixed: 4; rangeVar: 4; durFixed: 0; durVar: 0; area: $08; target: 0;
     saveResult: 2; saveType: 4; effect: 0;
     whenCast: 1; castTime: 3; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 52 Protection From Evil, 10' Radius }
    (castClass: 2; level: 3; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 2; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.PROTECTION_FROM_EVIL_10_FOOT;
     whenCast: 2; castTime: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 53 Protection From Good, 10' Radius }
    (castClass: 2; level: 3; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 2; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.PROTECTION_FROM_GOOD_10_FOOT;
     whenCast: 2; castTime: 3; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 54 Protection From Normal Missiles }
    (castClass: 2; level: 3; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 10; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.PROTECTION_FROM_MISSILES;
     whenCast: 2; castTime: 3; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 55 Slow }
    (castClass: 2; level: 3; rangeFixed: 9; rangeVar: 4; durFixed: 3; durVar: 1; area: $0A; target: 0;
     saveResult: 0; saveType: 4; effect: C_Effect.SLOWED;
     whenCast: 1; castTime: 3; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 56 Harm }
    (castClass: 0; level: 6; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 1; castTime: 10; aiPriority: 0; offensive: 1; aiRadius: 0),
    { 57 Potion Of Speed }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: C_Effect.HASTED;
     whenCast: 2; castTime: 0; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 58 Cure Serious Wounds }
    (castClass: 0; level: 4; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 2; castTime: 7; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 59 Potion Of Frost }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: C_Effect.GIANT_STRENGTH;
     whenCast: 2; castTime: 0; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 60 Javelin Of Lightning }
    (castClass: 3; level: 6; rangeFixed: 10; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 2; saveType: 4; effect: 0;
     whenCast: 1; castTime: 0; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 61 Wand Of Paralyzation }
    (castClass: 3; level: 6; rangeFixed: 6; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 1; saveType: 0; effect: C_Effect.HELD;
     whenCast: 1; castTime: 0; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 62 Potion Of Healing }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 2; castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 63 Elixir Of Youth }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $07; target: 3;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 2; castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 64 Necklace Of Missiles }
    (castClass: 3; level: 6; rangeFixed: 7; rangeVar: 0; durFixed: 0; durVar: 0; area: $0B; target: 0;
     saveResult: 2; saveType: 4; effect: 0;
     whenCast: 1; castTime: 0; aiPriority: 7; offensive: 1; aiRadius: 3),
    { 65 Wand Of Magic Missiles }
    (castClass: 3; level: 6; rangeFixed: 12; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 1; castTime: 0; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 66 Cause Serious Wounds }
    (castClass: 0; level: 4; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 1; castTime: 7; aiPriority: 3; offensive: 1; aiRadius: 0),
    { 67 Neutralize Poison }
    (castClass: 0; level: 4; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $00; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 0; castTime: 7; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 68 Poison }
    (castClass: 0; level: 4; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 1; saveType: 0; effect: 0;
     whenCast: 1; castTime: 7; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 69 Protection Evil, 10' Radius }
    (castClass: 0; level: 4; rangeFixed: 3; rangeVar: 0; durFixed: 0; durVar: 10; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.PROTECTION_FROM_EVIL_10_FOOT;
     whenCast: 2; castTime: 7; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 70 Sticks to Snakes }
    (castClass: 0; level: 4; rangeFixed: 3; rangeVar: 0; durFixed: 0; durVar: 2; area: $04; target: 0;
     saveResult: 0; saveType: 4; effect: C_Effect.SNAKE_HARASS;
     whenCast: 1; castTime: 7; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 71 Cure Critical Wounds }
    (castClass: 0; level: 5; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 2; castTime: 8; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 72 Cause Critical Wounds }
    (castClass: 0; level: 5; rangeFixed: $FF; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 1; saveType: 4; effect: 0;
     whenCast: 1; castTime: 8; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 73 Dispel Evil }
    (castClass: 0; level: 5; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 1; area: $00; target: 0;
     saveResult: 0; saveType: 4; effect: C_Effect.DISPEL_EVIL_TOUCH;
     whenCast: 1; castTime: 8; aiPriority: 5; offensive: 0; aiRadius: 0),
    { 74 Flame Strike }
    (castClass: 0; level: 5; rangeFixed: 6; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 2; saveType: 4; effect: 0;
     whenCast: 1; castTime: 8; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 75 Raise Dead }
    (castClass: 0; level: 5; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $00; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 0; castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 76 Slay Living }
    (castClass: 0; level: 5; rangeFixed: 3; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 1; saveType: 4; effect: 0;
     whenCast: 1; castTime: 10; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 77 Detect Magic }
    (castClass: 1; level: 1; rangeFixed: 3; rangeVar: 0; durFixed: 12; durVar: 0; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: C_Effect.DETECT_MAGIC;
     whenCast: 2; castTime: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 78 Entangle }
    (castClass: 1; level: 1; rangeFixed: 8; rangeVar: 0; durFixed: 10; durVar: 0; area: $0B; target: 0;
     saveResult: 1; saveType: 4; effect: 0;
     whenCast: 1; castTime: 3; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 79 Faerie Fire }
    (castClass: 1; level: 1; rangeFixed: 8; rangeVar: 0; durFixed: 0; durVar: 4; area: $05; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.HIGHLIGHTED;
     whenCast: 1; castTime: 3; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 80 Invisibility to Animals }
    (castClass: 1; level: 1; rangeFixed: $FF; rangeVar: 0; durFixed: 10; durVar: 1; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.INVISIBLE_TO_ANIMALS;
     whenCast: 2; castTime: 4; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 81 Charm Monsters }
    (castClass: 2; level: 4; rangeFixed: 6; rangeVar: 0; durFixed: 0; durVar: 0; area: $05; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.CHARM;
     whenCast: 1; castTime: 4; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 82 Confusion }
    (castClass: 2; level: 4; rangeFixed: 12; rangeVar: 0; durFixed: 2; durVar: 1; area: $0B; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.CONFUSED;
     whenCast: 1; castTime: 4; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 83 Dimension Door }
    (castClass: 2; level: 4; rangeFixed: 0; rangeVar: 12; durFixed: 0; durVar: 0; area: $08; target: 0;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 1; castTime: 1; aiPriority: 0; offensive: 1; aiRadius: 0),
    { 84 Fear }
    (castClass: 2; level: 4; rangeFixed: 6; rangeVar: 0; durFixed: 0; durVar: 1; area: $08; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.FRIGHTENED;
     whenCast: 1; castTime: 4; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 85 Fire Shield }
    (castClass: 2; level: 4; rangeFixed: 0; rangeVar: 0; durFixed: 2; durVar: 1; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 2; castTime: 4; aiPriority: 7; offensive: 0; aiRadius: 0),
    { 86 Fumble }
    (castClass: 2; level: 4; rangeFixed: 0; rangeVar: 4; durFixed: 0; durVar: 1; area: $04; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.CONFUSED_LOSE_TURN;
     whenCast: 1; castTime: 4; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 87 Ice Storm }
    (castClass: 2; level: 4; rangeFixed: 0; rangeVar: 4; durFixed: 0; durVar: 0; area: $0A; target: 0;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 1; castTime: 4; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 88 Minor Globe Of Invulnerability }
    (castClass: 2; level: 4; rangeFixed: 0; rangeVar: 16; durFixed: 0; durVar: 1; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: C_Effect.MINOR_GLOBE;
     whenCast: 2; castTime: 4; aiPriority: 6; offensive: 0; aiRadius: 0),
    { 89 Remove Curse }
    (castClass: 2; level: 4; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 2; castTime: 4; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 90 Barkskin }
    (castClass: 1; level: 2; rangeFixed: 1; rangeVar: 0; durFixed: 4; durVar: 1; area: $F0; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.BARKSKIN;
     whenCast: 2; castTime: 3; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 91 Cloud Kill }
    (castClass: 2; level: 5; rangeFixed: 2; rangeVar: 0; durFixed: 0; durVar: 1; area: $09; target: 0;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 2; castTime: 5; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 92 Cone of Cold }
    (castClass: 2; level: 5; rangeFixed: 6; rangeVar: 0; durFixed: 0; durVar: 0; area: $08; target: 0;
     saveResult: 2; saveType: 4; effect: 0;
     whenCast: 1; castTime: 5; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 93 Feeblemind }
    (castClass: 2; level: 5; rangeFixed: 16; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.FEEBLEMIND;
     whenCast: 1; castTime: 5; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 94 Hold Monsters }
    (castClass: 2; level: 5; rangeFixed: 0; rangeVar: 2; durFixed: 0; durVar: 1; area: $07; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.HELD;
     whenCast: 1; castTime: 5; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 95 Scroll of Protection }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 1; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: C_Effect.IMMUNE_DRAGON_BREATH;
     whenCast: 2; castTime: 10; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 96 Charm Person Or Mammal }
    (castClass: 1; level: 2; rangeFixed: 8; rangeVar: 0; durFixed: 60; durVar: 60; area: $04; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.CHARM;
     whenCast: 1; castTime: 4; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 97 Potion Of Invisibility }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: C_Effect.INVISIBLE;
     whenCast: 2; castTime: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 98 Cure Light Wounds }
    (castClass: 1; level: 2; rangeFixed: $FF; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 2; castTime: 4; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 99 Potion Of Extra Healing }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 2; castTime: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 100 Bestow Curse }
    (castClass: 2; level: 4; rangeFixed: 3; rangeVar: 0; durFixed: 0; durVar: 3; area: $04; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.BESTOW_CURSE;
     whenCast: 1; castTime: 4; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 101 Blade Barrier }
    (castClass: 0; level: 6; rangeFixed: 3; rangeVar: 0; durFixed: 0; durVar: 3; area: $09; target: 0;
     saveResult: 1; saveType: 4; effect: 0;
     whenCast: 1; castTime: 9; aiPriority: 9; offensive: 1; aiRadius: 0),
    { 102 Restoration }
    (castClass: 0; level: 7; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $00; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 0; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 103 Energy Drain }
    (castClass: 0; level: 7; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 1; castTime: 3; aiPriority: 8; offensive: 1; aiRadius: 0),
    { 104 Destruction }
    (castClass: 0; level: 7; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 1; castTime: 10; aiPriority: 9; offensive: 1; aiRadius: 0),
    { 105 Resurrection }
    (castClass: 0; level: 7; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $00; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 0; castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 106 Cure Disease }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $00; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 0; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 107 Neutralize Poison }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $00; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 0; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 108 Hold Animal }
    (castClass: 1; level: 3; rangeFixed: 8; rangeVar: 0; durFixed: 0; durVar: 2; area: $07; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.HELD;
     whenCast: 1; castTime: 5; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 109 Prot. from Fire }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.RESIST_FIRE_DRUID;
     whenCast: 2; castTime: 5; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 110 Death Spell }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 4; durFixed: 0; durVar: 0; area: $09; target: 0;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 1; castTime: 6; aiPriority: 3; offensive: 1; aiRadius: 0),
    { 111 Disintegrate }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 2; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 1; saveType: 4; effect: 0;
     whenCast: 1; castTime: 6; aiPriority: 8; offensive: 1; aiRadius: 0),
    { 112 Globe of Invulnerability }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 1; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: C_Effect.GLOBE_OF_INVULNERABILITY;
     whenCast: 2; castTime: 1; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 113 Stone to Flesh }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 4; durFixed: 0; durVar: 0; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 2; castTime: 6; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 114 Flesh to Stone }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 4; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.PETRIFY_TOUCH;
     whenCast: 1; castTime: 6; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 115 Delayed Blast Fireball }
    (castClass: 2; level: 7; rangeFixed: 10; rangeVar: 4; durFixed: 0; durVar: 0; area: $0B; target: 0;
     saveResult: 2; saveType: 4; effect: 0;
     whenCast: 1; castTime: 1; aiPriority: 9; offensive: 1; aiRadius: 0),
    { 116 Mass Invisibility }
    (castClass: 2; level: 7; rangeFixed: 0; rangeVar: 4; durFixed: 0; durVar: 0; area: $0A; target: 3;
     saveResult: 0; saveType: 4; effect: C_Effect.INVISIBLE;
     whenCast: 2; castTime: 7; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 117 Power Word Stun }
    (castClass: 2; level: 7; rangeFixed: 0; rangeVar: 2; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 0; saveType: 4; effect: C_Effect.STUNNED;
     whenCast: 1; castTime: 1; aiPriority: 3; offensive: 1; aiRadius: 0),
    { 118 Fire Touch }
    (castClass: 2; level: 5; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 1; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.FIRE_TOUCH;
     whenCast: 2; castTime: 6; aiPriority: 4; offensive: 0; aiRadius: 0),
    { 119 Iron Skin }
    (castClass: 2; level: 5; rangeFixed: 0; rangeVar: 0; durFixed: 0; durVar: 1; area: $00; target: 1;
     saveResult: 0; saveType: 4; effect: C_Effect.IRON_SKIN;
     whenCast: 2; castTime: 5; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 120 Mass Charm }
    (castClass: 2; level: 8; rangeFixed: 0; rangeVar: 1; durFixed: 0; durVar: 0; area: $09; target: 0;
     saveResult: 1; saveType: 4; effect: C_Effect.CHARM;
     whenCast: 1; castTime: 8; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 121 Otto's Irr. Dance }
    (castClass: 2; level: 8; rangeFixed: $FF; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 0;
     saveResult: 0; saveType: 4; effect: C_Effect.DANCING;
     whenCast: 1; castTime: 5; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 122 Mind Blank }
    (castClass: 2; level: 8; rangeFixed: 3; rangeVar: 0; durFixed: 0; durVar: 0; area: $04; target: 2;
     saveResult: 0; saveType: 4; effect: C_Effect.MIND_BLANK;
     whenCast: 2; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 123 Power Word Blind }
    (castClass: 2; level: 8; rangeFixed: 0; rangeVar: 1; durFixed: 0; durVar: 0; area: $0A; target: 0;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 1; castTime: 1; aiPriority: 3; offensive: 1; aiRadius: 0),
    { 124 Meteor Swarm }
    (castClass: 2; level: 9; rangeFixed: 4; rangeVar: 1; durFixed: 0; durVar: 0; area: $08; target: 0;
     saveResult: 2; saveType: 4; effect: 0;
     whenCast: 1; castTime: 9; aiPriority: 3; offensive: 1; aiRadius: 0),
    { 125 Power Word Kill }
    (castClass: 2; level: 9; rangeFixed: 0; rangeVar: 1; durFixed: 0; durVar: 0; area: $09; target: 0;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 1; castTime: 1; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 126 Monster Summoning }
    (castClass: 2; level: 9; rangeFixed: 9; rangeVar: 0; durFixed: 0; durVar: 0; area: $00; target: 0;
     saveResult: 0; saveType: 4; effect: 0;
     whenCast: 1; castTime: 9; aiPriority: 0; offensive: 1; aiRadius: 0));

{ The game clock. }
const
  { The game clock's seven moduli, ticks through years: a component that reaches its modulus carries into the next
    (GameTime.ValidateClock). }
  clockModulus: array[0..6] of Word = (10, 10, 6, 24, 30, 12, 100);

{ Character rules: to-hit, class masks and hit points. }
const
  { By class 0..6 and level 0..21: the base to-hit number, 60 minus THAC0, so 40 is THAC0 20. Column 0 is read for every
    class a character lacks. }
  thac0ByLevel: array[0..6, 0..21] of Byte = (
    { 0 cleric } (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46, 46, 46, 48, 48, 48, 50, 50, 50, 51, 51, 51),
    { 1 druid } (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46, 46, 46, 48, 48, 48, 50, 50, 50, 51, 51, 51),
    { 2 fighter } (39, 40, 40, 42, 42, 44, 44, 46, 46, 48, 48, 50, 50, 52, 52, 54, 54, 56, 56, 56, 56, 56),
    { 3 paladin } (40, 40, 40, 42, 42, 44, 44, 46, 46, 48, 48, 50, 50, 52, 52, 54, 54, 56, 56, 56, 56, 56),
    { 4 ranger } (40, 40, 40, 42, 42, 44, 44, 46, 46, 48, 48, 50, 50, 52, 52, 54, 54, 56, 56, 56, 56, 56),
    { 5 magic-user } (39, 40, 40, 40, 40, 40, 41, 41, 41, 41, 41, 44, 44, 44, 44, 44, 47, 47, 47, 47, 47, 49),
    { 6 thief } (40, 40, 40, 40, 40, 41, 41, 41, 41, 44, 44, 44, 44, 46, 46, 46, 46, 48, 48, 48, 48, 50));
  { By class: the bit a class holds in a character's classMask, which an item's class byte is tested against before it
    can stay readied. }
  classMaskBit: array[0..6] of Byte = ($02, $10, $08, $40, $40, $01, $04);
  { By class: the bit a class holds in the level-up mask ViewChar.AdjustLevelHitPoints takes to roll, or on a drain
    remove, that class's hit points. Cleric and druid share. }
  levelUpClassBit: array[0..6] of Byte = ($02, $02, $08, $10, $20, $01, $04);
  { reserved }
  levelUpClassBitTail: array[0..8] of Byte = (
    $10, $10, $10, $20, $20, $20, $40, $40, $40);
  { By class: the first level whose hit points are a fixed gain instead of a die (cleric 10, druid 15, fighter 10,
    paladin 10, ranger 11, magic-user 12, thief 11). }
  firstFixedHpLevel: array[0..6] of Byte = (10, 15, 10, 10, 11, 12, 11);
  { By class: hit dice rolled at level 1; only the ranger rolls two. }
  firstLevelHitDice: array[0..6] of Byte = (1, 1, 1, 1, 2, 1, 1);
  { By class: the hit die (d8, d8, d10, d10, d8, d4, d6). }
  hitDieSides: array[0..6] of Byte = (8, 8, 10, 10, 8, 4, 6);

{ Combat icon colors. }
const
  { By icon color slot 1..6: the palette index that slot occupies in a CHEAD/CBODY sprite; index + 8 is its highlight. }
  iconSlotColor: array[1..6] of Byte = (1, 2, 3, 4, 6, 7);

{ Character rules: thief skills, experience, races, ages, classes, saving throws and level caps. }
const
  { By thief level 1..18 and skill 1..8 (pick pockets, open locks, find and remove traps, move silently, hide in
    shadows, hear noise, climb walls, read languages): the base percentage before the race and Dexterity adjustments. }
  thiefSkillsByLevel: array[1..18, 1..8] of Byte = (
    {  1 } ( 30, 25, 20, 15, 10, 10, 85, 0),
    {  2 } ( 35, 29, 25, 21, 15, 10, 86, 0),
    {  3 } ( 40, 33, 30, 27, 20, 15, 87, 0),
    {  4 } ( 45, 37, 35, 33, 25, 15, 88, 20),
    {  5 } ( 50, 42, 40, 40, 31, 20, 90, 25),
    {  6 } ( 55, 47, 45, 47, 37, 20, 92, 30),
    {  7 } ( 60, 52, 50, 55, 43, 25, 94, 35),
    {  8 } ( 65, 57, 55, 62, 49, 25, 96, 40),
    {  9 } ( 70, 62, 60, 70, 56, 30, 98, 45),
    { 10 } ( 80, 67, 65, 78, 63, 30, 99, 50),
    { 11 } ( 90, 72, 70, 86, 70, 35, 99, 55),
    { 12 } (100, 77, 75, 94, 77, 35, 99, 60),
    { 13 } (105, 82, 80, 99, 85, 40, 99, 65),
    { 14 } (110, 87, 85, 99, 93, 40, 99, 70),
    { 15 } (115, 92, 90, 99, 99, 50, 100, 75),
    { 16 } (125, 97, 95, 99, 99, 50, 100, 80),
    { 17 } (125, 99, 99, 99, 99, 55, 100, 80),
    { 18 } (130, 99, 99, 99, 99, 55, 100, 85));
  { By race 0..5 and thief skill 1..8: the racial adjustments added to thiefSkillsByLevel. Note: row 5, the human row,
    carries the half-orc figures instead of all zeroes. }
  thiefRaceAdjustments: array[0..5, 1..8] of ShortInt = (
    { 0 elf } ( 5, -5, 0, 5, 10, 5, 0, 0),
    { 1 half-elf } ( 10, 0, 0, 0, 5, 0, 0, 0),
    { 2 dwarf } ( 0, 10, 15, 0, 0, 0, -10, -5),
    { 3 gnome } ( 0, 5, 10, 5, 5, 10, -15, 0),
    { 4 halfling } ( 5, 5, 5, 10, 15, 5, -15, -5),
    { 5 human } ( -5, 5, 5, 0, 0, 5, 5, -10));
  { By Dexterity 9..19 and thief skill 1..5 (pick pockets through hide in shadows): the Dexterity adjustment; ClassCal
    adds it for skills below 6 only. }
  thiefDexterityAdjustments: array[9..19, 1..5] of ShortInt = (
    {  9 } (-15, -10, -10, -20, -10),
    { 10 } (-19, -5, -10, -15, -5),
    { 11 } ( -5, 0, -5, -10, 0),
    { 12 } ( 0, 0, 0, -5, 0),
    { 13 } ( 0, 0, 0, 0, 0),
    { 14 } ( 0, 0, 0, 0, 0),
    { 15 } ( 0, 0, 0, 0, 0),
    { 16 } ( 0, -5, 0, 0, 0),
    { 17 } ( 5, 10, 0, 5, 5),
    { 18 } ( 10, 15, 5, 10, 10),
    { 19 } ( 15, 20, 10, 12, 12));
  { By class 0..6: the experience each level past 11 costs; ClassCal.XpForLevel extrapolates from classLevelTable's
    level-11 threshold with it. }
  xpIncrement: array[0..6] of LongInt = (225000, 750000, 250000, 350000, 325000, 375000, 220000);
  { By race 0..5: the ability-score limits character creation clamps to. }
  raceLimits: array[0..5] of Types.TRaceLimits = (
    { 0 elf }
    (strMin: (3, 3); strMax: (18, 16); strExcMax: (75, 0); intMin: 8; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 7; dexMax: 19; conMin: 6; conMax: 18; chaMin: 8; chaMax: 18),
    { 1 half-elf }
    (strMin: (3, 3); strMax: (18, 17); strExcMax: (90, 0); intMin: 4; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 6; dexMax: 18; conMin: 6; conMax: 18; chaMin: 3; chaMax: 18),
    { 2 dwarf }
    (strMin: (8, 8); strMax: (18, 17); strExcMax: (99, 0); intMin: 3; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 17; conMin: 12; conMax: 19; chaMin: 3; chaMax: 16),
    { 3 gnome }
    (strMin: (6, 6); strMax: (18, 15); strExcMax: (50, 0); intMin: 7; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 18; conMin: 8; conMax: 18; chaMin: 3; chaMax: 18),
    { 4 halfling }
    (strMin: (6, 6); strMax: (17, 14); strExcMax: (0, 0); intMin: 6; intMax: 18;
     wisMin: 3; wisMax: 17; dexMin: 8; dexMax: 18; conMin: 10; conMax: 19; chaMin: 3; chaMax: 18),
    { 5 human }
    (strMin: (3, 3); strMax: (18, 18); strExcMax: (100, 50); intMin: 3; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 18; conMin: 3; conMax: 18; chaMin: 3; chaMax: 18));
  { By race 0..5: column 0 counts the classes that race may choose and columns 1..count list them as classNameTable
    ids. }
  raceClasses: array[0..5, 0..13] of ShortInt = (
    { 0 elf } (7, C_Class.FIGHTER, C_Class.MAGE, C_Class.THIEF, C_Class.FIGHTER_MAGE,
               C_Class.FIGHTER_THIEF,
               C_Class.FIGHTER_MAGE_THIEF, C_Class.MAGE_THIEF, 0, 0, 0, 0, 0, 0),
    { 1 half-elf } (13, C_Class.CLERIC, C_Class.FIGHTER, C_Class.MAGE, C_Class.THIEF,
                    C_Class.RANGER, C_Class.CLERIC_FIGHTER,
                    C_Class.CLERIC_RANGER, C_Class.CLERIC_FIGHTER_MAGE, C_Class.CLERIC_MAGE,
                        C_Class.FIGHTER_MAGE,
                    C_Class.FIGHTER_THIEF, C_Class.FIGHTER_MAGE_THIEF, C_Class.MAGE_THIEF),
    { 2 dwarf } (3, C_Class.FIGHTER, C_Class.THIEF, C_Class.FIGHTER_THIEF, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                 0),
    { 3 gnome } (3, C_Class.FIGHTER, C_Class.THIEF, C_Class.FIGHTER_THIEF, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                 0),
    { 4 halfling } (3, C_Class.FIGHTER, C_Class.THIEF, C_Class.FIGHTER_THIEF, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0),
    { 5 human } (6, C_Class.CLERIC, C_Class.FIGHTER, C_Class.MAGE, C_Class.THIEF,
                 C_Class.PALADIN, C_Class.RANGER,
                 0, 0, 0, 0, 0, 0, 0));
  { By race 0..5 and single class 0..6: a new character's age is base plus dice d sides plus ten; a multi-class
    character takes one column at the dice's maximum (CharGen.CreateCharacterMenu). Classes a race cannot be are zero. }
  startAges: array[0..5, 0..6] of Types.TStartAge = (
    { 0 elf }
    ((base: 650; dice: 10; sides: 10), (base: 0; dice: 0; sides: 0), (base: 130; dice: 5; sides: 6),
     (base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0),
     (base: 150; dice: 5; sides: 6), (base: 100; dice: 5; sides: 6)),
    { 1 half-elf }
    ((base: 40; dice: 2; sides: 4), (base: 0; dice: 0; sides: 0), (base: 22; dice: 3; sides: 4),
     (base: 22; dice: 0; sides: 0), (base: 22; dice: 0; sides: 0),
     (base: 30; dice: 2; sides: 8), (base: 22; dice: 3; sides: 8)),
    { 2 dwarf }
    ((base: 250; dice: 2; sides: 20), (base: 0; dice: 0; sides: 0), (base: 40; dice: 5; sides: 4),
     (base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0),
     (base: 0; dice: 0; sides: 0), (base: 75; dice: 3; sides: 6)),
    { 3 gnome }
    ((base: 300; dice: 3; sides: 12), (base: 0; dice: 0; sides: 0), (base: 60; dice: 5; sides: 4),
     (base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0),
     (base: 100; dice: 2; sides: 12), (base: 80; dice: 5; sides: 4)),
    { 4 halfling }
    ((base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0), (base: 20; dice: 3; sides: 4),
     (base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0),
     (base: 0; dice: 0; sides: 0), (base: 40; dice: 2; sides: 4)),
    { 5 human }
    ((base: 18; dice: 1; sides: 4), (base: 18; dice: 1; sides: 4), (base: 15; dice: 1; sides: 4),
     (base: 17; dice: 1; sides: 4), (base: 20; dice: 1; sides: 4),
     (base: 24; dice: 2; sides: 4), (base: 18; dice: 1; sides: 4)));
  { By race 0..5: the ages at which the five ability-score adjustments of age begin; character creation compares a
    rolled age against them. }
  ageThresholds: array[0..5, 0..4] of Word = (
    { 0 elf } ( 175, 550, 875, 1200, 1600),
    { 1 half-elf } ( 40, 100, 175, 250, 325),
    { 2 dwarf } ( 50, 150, 250, 350, 450),
    { 3 gnome } ( 90, 300, 450, 600, 750),
    { 4 halfling } ( 33, 68, 101, 144, 199),
    { 5 human } ( 20, 40, 60, 90, 120));
  { By classNameTable id 0..16 and ability score 0..5 (Str Int Wis Dex Con Cha): the minimum a class requires. Character
    creation raises a roll to it; ClassCal treats a minimum of 9 or more as a prime requisite when a human changes
    class. }
  classMinStats: array[0..16, 0..5] of Byte = (
    {  0 cleric } ( 6, 6, 9, 0, 0, 6),
    {  1 druid } ( 0, 0, 12, 0, 0, 15),
    {  2 fighter } ( 9, 0, 6, 6, 7, 6),
    {  3 paladin } (12, 9, 13, 0, 9, 17),
    {  4 ranger } (13, 13, 14, 0, 14, 6),
    {  5 magic-user } ( 0, 9, 6, 6, 0, 6),
    {  6 thief } ( 6, 6, 0, 9, 0, 6),
    {  7 monk } (15, 0, 15, 15, 11, 6),
    {  8 cleric/fighter } ( 9, 0, 9, 0, 0, 6),
    {  9 cleric/fighter/magic-user } ( 9, 9, 9, 0, 0, 6),
    { 10 cleric/ranger } ( 0, 13, 14, 0, 14, 6),
    { 11 cleric/magic-user } ( 0, 9, 9, 0, 0, 6),
    { 12 cleric/thief } ( 0, 0, 9, 9, 0, 6),
    { 13 fighter/magic-user } ( 9, 9, 0, 0, 0, 6),
    { 14 fighter/thief } ( 9, 0, 0, 9, 0, 6),
    { 15 fighter/magic-user/thief } ( 9, 9, 0, 9, 0, 6),
    { 16 magic-user/thief } ( 0, 9, 0, 9, 0, 6));
  { By classNameTable id 0..16: the alignments a class may hold, as a count and up to nine alignmentNameTable ids. }
  classAlignments: array[0..16] of Types.TClassAlignments = (
    {  0 cleric } (count: 9; allowed: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    {  1 druid } (count: 5; allowed: (1, 3, 4, 5, 7, 0, 0, 0, 0)),
    {  2 fighter } (count: 9; allowed: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    {  3 paladin } (count: 1; allowed: (0, 0, 0, 0, 0, 0, 0, 0, 0)),
    {  4 ranger } (count: 3; allowed: (0, 3, 6, 0, 0, 0, 0, 0, 0)),
    {  5 magic-user } (count: 9; allowed: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    {  6 thief } (count: 7; allowed: (1, 2, 3, 4, 5, 7, 8, 0, 0)),
    {  7 monk } (count: 9; allowed: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    {  8 cleric/fighter } (count: 9; allowed: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    {  9 cleric/fighter/magic-user } (count: 9; allowed: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    { 10 cleric/ranger } (count: 3; allowed: (0, 3, 6, 0, 0, 0, 0, 0, 0)),
    { 11 cleric/magic-user } (count: 9; allowed: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    { 12 cleric/thief } (count: 9; allowed: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    { 13 fighter/magic-user } (count: 9; allowed: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    { 14 fighter/thief } (count: 7; allowed: (1, 2, 3, 4, 5, 7, 8, 0, 0)),
    { 15 fighter/magic-user/thief } (count: 7; allowed: (1, 2, 3, 4, 5, 7, 8, 0, 0)),
    { 16 magic-user/thief } (count: 7; allowed: (1, 2, 3, 4, 5, 7, 8, 0, 0)));
  { By Constitution 3..25: the hit-point bonus per level. }
  conBonusTable: array[3..25] of ShortInt = (-2, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2);
  { One record per character class: the XP needed for levels 2..11 (ClassCal.XpForLevel extrapolates 12..40 from
    xpIncrement), then the spell slots by spell level 1..9 for each character level 1..29. }
  classLevelTable: array[0..6] of Types.TClassLevelTable = (
    { 0 cleric }
    (xp: (1501, 3001, 6001, 13001, 27501, 55001, 110001, 225001, 450001, 675001);
     spellSlots: (
       (1, 0, 0, 0, 0, 0, 0, 0, 0),
       (2, 0, 0, 0, 0, 0, 0, 0, 0),
       (2, 1, 0, 0, 0, 0, 0, 0, 0),
       (3, 2, 0, 0, 0, 0, 0, 0, 0),
       (3, 3, 1, 0, 0, 0, 0, 0, 0),
       (3, 3, 2, 0, 0, 0, 0, 0, 0),
       (3, 3, 2, 1, 0, 0, 0, 0, 0),
       (3, 3, 3, 2, 0, 0, 0, 0, 0),
       (4, 4, 3, 2, 1, 0, 0, 0, 0),
       (4, 4, 3, 3, 2, 0, 0, 0, 0),
       (5, 4, 4, 3, 2, 1, 0, 0, 0),
       (6, 5, 5, 3, 2, 2, 0, 0, 0),
       (6, 6, 6, 4, 2, 2, 0, 0, 0),
       (6, 6, 6, 5, 3, 2, 0, 0, 0),
       (7, 7, 7, 5, 4, 2, 0, 0, 0),
       (7, 7, 7, 6, 5, 3, 1, 0, 0),
       (8, 8, 8, 6, 5, 3, 1, 0, 0),
       (8, 8, 8, 7, 6, 4, 1, 0, 0),
       (9, 9, 9, 7, 6, 4, 2, 0, 0),
       (9, 9, 9, 8, 7, 5, 2, 0, 0),
       (9, 9, 9, 9, 8, 6, 2, 0, 0),
       (9, 9, 9, 9, 9, 6, 3, 0, 0),
       (9, 9, 9, 9, 9, 7, 3, 0, 0),
       (9, 9, 9, 9, 9, 8, 3, 0, 0),
       (9, 9, 9, 9, 9, 8, 4, 0, 0),
       (9, 9, 9, 9, 9, 9, 4, 0, 0),
       (9, 9, 9, 9, 9, 9, 5, 0, 0),
       (9, 9, 9, 9, 9, 9, 6, 0, 0),
       (9, 9, 9, 9, 9, 9, 7, 0, 0))),
    { 1 unused (no progression: every threshold is -1) }
    (xp: (-1, -1, -1, -1, -1, -1, -1, -1, -1, -1);
     spellSlots: (
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0))),
    { 2 fighter }
    (xp: (2001, 4001, 8001, 18001, 35001, 70001, 125001, 250001, 500001, 750001);
     spellSlots: (
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0))),
    { 3 paladin }
    (xp: (2751, 5501, 12001, 24001, 45001, 95001, 175001, 350001, 700001, 1050000);
     spellSlots: (
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (1, 0, 0, 0, 0, 0, 0, 0, 0),
       (2, 0, 0, 0, 0, 0, 0, 0, 0),
       (2, 1, 0, 0, 0, 0, 0, 0, 0),
       (2, 2, 0, 0, 0, 0, 0, 0, 0),
       (2, 2, 1, 0, 0, 0, 0, 0, 0),
       (3, 2, 1, 0, 0, 0, 0, 0, 0),
       (3, 2, 1, 1, 0, 0, 0, 0, 0),
       (3, 3, 1, 1, 0, 0, 0, 0, 0),
       (3, 3, 2, 1, 0, 0, 0, 0, 0),
       (3, 3, 3, 1, 0, 0, 0, 0, 0),
       (3, 3, 3, 2, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0))),
    { 4 ranger }
    (xp: (2251, 4501, 10001, 20001, 40001, 90001, 150001, 225001, 325001, 650000);
     spellSlots: (
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (1, 0, 0, 0, 0, 0, 0, 0, 0),
       (1, 0, 0, 0, 1, 0, 0, 0, 0),
       (2, 0, 0, 0, 1, 0, 0, 0, 0),
       (2, 0, 0, 0, 2, 0, 0, 0, 0),
       (2, 1, 0, 0, 2, 0, 0, 0, 0),
       (2, 1, 0, 0, 2, 1, 0, 0, 0),
       (2, 2, 0, 0, 2, 1, 0, 0, 0),
       (2, 2, 0, 0, 2, 2, 0, 0, 0),
       (2, 2, 1, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0))),
    { 5 magic-user }
    (xp: (2501, 5001, 10001, 22501, 40001, 60001, 90001, 135001, 250001, 375001);
     spellSlots: (
       (1, 0, 0, 0, 0, 0, 0, 0, 0),
       (2, 0, 0, 0, 0, 0, 0, 0, 0),
       (2, 1, 0, 0, 0, 0, 0, 0, 0),
       (3, 2, 0, 0, 0, 0, 0, 0, 0),
       (4, 2, 1, 0, 0, 0, 0, 0, 0),
       (4, 2, 2, 0, 0, 0, 0, 0, 0),
       (4, 3, 2, 1, 0, 0, 0, 0, 0),
       (4, 3, 3, 2, 0, 0, 0, 0, 0),
       (4, 3, 3, 2, 1, 0, 0, 0, 0),
       (4, 4, 3, 2, 2, 0, 0, 0, 0),
       (4, 4, 4, 3, 3, 0, 0, 0, 0),
       (4, 4, 4, 4, 4, 1, 0, 0, 0),
       (5, 5, 5, 4, 4, 2, 0, 0, 0),
       (5, 5, 5, 4, 4, 2, 1, 0, 0),
       (5, 5, 5, 5, 5, 2, 1, 0, 0),
       (5, 5, 5, 5, 5, 3, 2, 1, 0),
       (5, 5, 5, 5, 5, 3, 3, 2, 0),
       (5, 5, 5, 5, 5, 3, 3, 2, 1),
       (5, 5, 5, 5, 5, 3, 3, 3, 1),
       (5, 5, 5, 5, 5, 4, 3, 3, 2),
       (5, 5, 5, 5, 5, 4, 4, 4, 2),
       (5, 5, 5, 5, 5, 5, 4, 4, 3),
       (5, 5, 5, 5, 5, 5, 5, 5, 3),
       (5, 5, 5, 5, 5, 5, 5, 5, 4),
       (5, 5, 5, 5, 5, 5, 5, 5, 5),
       (6, 6, 6, 6, 5, 5, 5, 5, 5),
       (6, 6, 6, 6, 6, 6, 6, 5, 5),
       (6, 6, 6, 6, 6, 6, 6, 6, 6),
       (7, 7, 7, 7, 6, 6, 6, 6, 6))),
    { 6 thief }
    (xp: (1251, 2501, 5001, 10001, 20001, 42501, 70001, 110001, 160001, 220001);
     spellSlots: (
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0))));
  { By class 0..6: starting-gold dice as count and sides: 3d6 cleric and druid, 5d4 fighter, paladin and ranger, 2d4
    magic-user, 2d6 thief. }
  startingGoldDice: array[0..13] of Byte = (
    3, 6, 3, 6, 5, 4, 5, 4, 5, 4, 2, 4, 2, 6);
  { By class 0..6, character level 1..21 and save 0..4: the saving-throw targets. ClassCal indexes the level from 1 and
    caps it at 21. }
  savingThrowTable: array[0..6] of array[1..21] of array[0..4] of Byte = (
    { 0 cleric }
    ((10, 13, 14, 16, 15),
     (10, 13, 14, 16, 15),
     (10, 13, 14, 16, 15),
     (9, 12, 13, 15, 14),
     (9, 12, 13, 15, 14),
     (9, 12, 13, 15, 14),
     (7, 10, 11, 13, 12),
     (7, 10, 11, 13, 12),
     (7, 10, 11, 13, 12),
     (6, 9, 10, 12, 11),
     (6, 9, 10, 12, 11),
     (6, 9, 10, 12, 11),
     (5, 8, 9, 11, 10),
     (5, 8, 9, 11, 10),
     (5, 8, 9, 11, 10),
     (4, 7, 8, 10, 9),
     (4, 7, 8, 10, 9),
     (4, 7, 8, 10, 9),
     (4, 7, 8, 10, 9),
     (2, 5, 6, 8, 7),
     (2, 5, 6, 8, 7)),
    { 1 druid }
    ((10, 13, 14, 16, 15),
     (10, 13, 14, 16, 15),
     (10, 13, 14, 16, 15),
     (9, 12, 13, 15, 14),
     (9, 12, 13, 15, 14),
     (9, 12, 13, 15, 14),
     (7, 10, 11, 13, 12),
     (7, 10, 11, 13, 12),
     (7, 10, 11, 13, 12),
     (6, 9, 10, 12, 11),
     (6, 9, 10, 12, 11),
     (6, 9, 10, 12, 11),
     (5, 8, 9, 11, 10),
     (5, 8, 9, 11, 10),
     (5, 8, 9, 11, 10),
     (4, 7, 8, 10, 9),
     (4, 7, 8, 10, 9),
     (4, 7, 8, 10, 9),
     (4, 7, 8, 10, 9),
     (4, 7, 8, 10, 9),
     (4, 7, 8, 10, 9)),
    { 2 fighter }
    ((14, 15, 16, 17, 17),
     (14, 15, 16, 17, 17),
     (13, 14, 15, 16, 16),
     (13, 14, 15, 16, 16),
     (11, 12, 13, 13, 14),
     (11, 12, 13, 13, 14),
     (10, 11, 12, 12, 13),
     (10, 11, 12, 12, 13),
     (8, 9, 10, 9, 11),
     (8, 9, 10, 9, 11),
     (7, 8, 9, 8, 10),
     (7, 8, 9, 8, 10),
     (5, 6, 7, 5, 8),
     (5, 6, 7, 5, 8),
     (4, 5, 6, 4, 7),
     (4, 5, 6, 4, 7),
     (3, 4, 5, 4, 6),
     (3, 4, 5, 4, 6),
     (3, 4, 5, 4, 6),
     (3, 4, 5, 4, 6),
     (3, 4, 5, 4, 6)),
    { 3 paladin }
    ((12, 13, 14, 15, 15),
     (12, 13, 14, 15, 15),
     (11, 12, 13, 14, 14),
     (11, 12, 13, 14, 14),
     (9, 9, 11, 11, 12),
     (9, 9, 11, 11, 12),
     (8, 9, 10, 10, 11),
     (9, 9, 10, 10, 11),
     (6, 7, 8, 7, 9),
     (6, 7, 8, 7, 9),
     (5, 6, 7, 6, 8),
     (5, 6, 7, 6, 8),
     (3, 4, 5, 3, 6),
     (3, 4, 5, 3, 6),
     (2, 3, 4, 2, 5),
     (2, 3, 4, 2, 5),
     (1, 2, 3, 2, 4),
     (1, 2, 3, 2, 4),
     (1, 2, 3, 2, 4),
     (1, 2, 3, 2, 4),
     (1, 2, 3, 2, 4)),
    { 4 ranger }
    ((14, 15, 16, 17, 17),
     (14, 15, 16, 17, 17),
     (13, 14, 15, 16, 16),
     (13, 14, 15, 16, 16),
     (11, 12, 13, 13, 14),
     (11, 12, 13, 13, 14),
     (10, 11, 12, 12, 13),
     (10, 11, 12, 12, 13),
     (8, 9, 10, 9, 11),
     (8, 9, 10, 9, 11),
     (7, 8, 9, 8, 10),
     (7, 8, 9, 8, 10),
     (5, 6, 7, 5, 8),
     (5, 6, 7, 5, 8),
     (4, 5, 6, 4, 7),
     (4, 5, 6, 4, 7),
     (3, 4, 5, 4, 6),
     (3, 4, 5, 4, 6),
     (3, 4, 5, 4, 6),
     (3, 4, 5, 4, 6),
     (3, 4, 5, 4, 6)),
    { 5 magic-user }
    ((14, 13, 11, 15, 12),
     (14, 13, 11, 15, 12),
     (14, 13, 11, 15, 12),
     (14, 13, 11, 15, 12),
     (14, 13, 11, 15, 12),
     (13, 11, 9, 13, 10),
     (13, 11, 9, 13, 10),
     (13, 11, 9, 13, 10),
     (13, 11, 9, 13, 10),
     (13, 11, 9, 13, 10),
     (11, 9, 7, 11, 8),
     (11, 9, 7, 11, 8),
     (11, 9, 7, 11, 8),
     (11, 9, 7, 11, 8),
     (11, 9, 7, 11, 8),
     (10, 7, 5, 9, 6),
     (10, 7, 5, 9, 6),
     (10, 7, 5, 9, 6),
     (10, 7, 5, 9, 6),
     (10, 7, 5, 9, 6),
     (8, 5, 3, 7, 4)),
    { 6 thief }
    ((13, 12, 14, 16, 15),
     (13, 12, 14, 16, 15),
     (13, 12, 14, 16, 15),
     (13, 12, 14, 16, 15),
     (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13),
     (11, 10, 10, 14, 11),
     (11, 10, 10, 14, 11),
     (11, 10, 10, 14, 11),
     (11, 10, 10, 14, 11),
     (10, 9, 8, 13, 9),
     (10, 9, 8, 13, 9),
     (10, 9, 8, 13, 9),
     (10, 9, 8, 13, 9),
     (9, 8, 6, 12, 7),
     (9, 8, 6, 12, 7),
     (10, 9, 8, 13, 9),
     (9, 8, 6, 12, 7),
     (8, 7, 4, 11, 5)));
  { The level cap by [race, class] in raceNameTable and class 0..6 order; 0 bars the class and 40 is unlimited. }
  raceCaps: array[0..5, 0..6] of Byte = (
    (0, 0, 7, 0, 0, 11, 40),
    (5, 0, 8, 0, 8, 8, 40),
    (0, 0, 9, 0, 0, 0, 40),
    (0, 0, 6, 0, 0, 0, 40),
    (0, 0, 6, 0, 0, 0, 40),
    (40, 0, 40, 40, 40, 40, 40));

{ Area pictures. }
const
  { The picture Portrait.LoadBigPic shows for an area, by the zone's picture index (bank 0's tileSet), as MapView,
    SaveLoad and EclVm all read it. }
  areaPictureIds: array[0..5] of Byte = (240, 241, 242, 242, 245, 0);

{ The mouse cursor. }
const
  { The mouse arrow as INT 33h function 9 takes it: the 16-row screen mask, then the 16-row cursor mask. }
  mouseCursor: array[0..1, 0..15] of Word = (
    ($3FFF, $1FFF, $0FFF, $87FF, $A3FF, $E1FF, $F0FF, $F847,
     $FC23, $FE0F, $FF07, $F807, $FC43, $FFE0, $FFF9, $FFFF),
    ($0000, $4000, $6000, $3000, $1800, $0C00, $0600, $0310,
     $0188, $00B0, $0030, $02F0, $0118, $000E, $0000, $0000));

{ The joystick. }
const
  { The joystick direction 0..7 by [y bin, x bin] of the five calibration thresholds; 8 is the dead zone. }
  joystickZones: array[0..5, 0..5] of Byte = (
    (7, 7, 0, 0, 1, 1),
    (7, 8, 8, 8, 8, 1),
    (6, 8, 8, 8, 8, 2),
    (6, 8, 8, 8, 8, 2),
    (5, 8, 8, 8, 8, 3),
    (5, 5, 4, 4, 3, 3));
  { the keypad digit for each joystick direction }
  joystickKeys: array[0..7] of Char = ('8', '9', '6', '3', '2', '1', '4', '7');
  { reserved }
  joystickKeysTail: array[0..1] of Byte = (
    32, 0);

{ Tandy color fill. }
const
  { Each 4-bit color duplicated into both nibbles of a Tandy packed byte, Blit's mode-1 FillChar value. }
  tandyDup: array[0..15] of Byte = ($00, $11, $22, $33, $44, $55, $66, $77, $88, $99, $AA, $BB, $CC, $DD, $EE, $FF);

implementation

end.
