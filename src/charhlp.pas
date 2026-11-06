{ Character and combat helpers: stat and movement recalculation, the party panel and combat info panel, item and spell
  bookkeeping, combat-icon animation, target counting and distance, the noncombat and combat screen frames, and
  character selection.

  The interface order and the implementation order differ, and both are fixed: do not reorder either. }
{$O+,F+,S-,R-,V-,B-,I-}
unit CharHlp;

interface

uses Crt, Blit, TextRend, Border, GameIo, Music, ClassCal, MenuCore, MapView, Portrait, Pathing, CbtMap, Types,
  GDConsts, GDVars, C_Class, C_Effect, C_Equip, C_Keys, C_Race, C_Ifc, C_Stat, C_Dir,
  C_Item, C_Spell, C_Status;

{ Rolls a percentile chance.
  @param(pct The chance in 100.)
  @returns(True with a chance of percent in 100.) }
function PercentileRoll(pct: Byte): Boolean;

{ Build an item's display name in place in it^.name, and print it if asked. The name is the Yes/No equipped column of an
  inventory list, a '*' when anyone in the party has Detect Magic running and the item is magical or cursed, the
  quantity, then each identified name component with the plural 's' on the right word. cr is not used.
  @param(cr Unused.)
  @param(it The item, a Types.PItemRec.)
  @param(col The column it is printed at.)
  @param(row The row.)
  @param(isInv True adds the equipped column of an inventory list.)
  @param(doPrint True prints the name.) }
procedure PrintItemString(cr, it: Pointer; col, row: Byte; isInv, doPrint: Boolean);

{ Draws the party panel and records its rectangle for mouse picks (to column 38, from row 4 down one row per member):
  the 'Name' and 'AC/HP' headings, then one row per party member (name, armor class and hit points right-aligned), each
  row cleared first, and one cleared row after the last. The given member is drawn plainly in white; the others are
  colored by DisplayCreatureName. The panel starts in column 1 in the main menu and column 17 otherwise. Skipped on the
  area map while the map pane is enabled, or while the party panel is hidden.
  @param(hl The member drawn plainly in white.) }
procedure DisplayParty(hl: Pointer);

{ Does nothing on the map screen while the map is shown there, or while the party panel is hidden. Otherwise sets the
  party panel's bounds and repaints only the highlighted member's row (name, armor class and hit points, each placed by
  its digit-width band), leaving the other rows as they are, then clears the row after the last member and drops the
  highlight.
  @param(hl Seeds the highlight when none is set.)
  @param(clearHl True draws the name plainly in white instead of in its condition color.) }
procedure DisplayRoster(hl: Pointer; clearHl: Boolean);

{ Prints a creature's current hit points at a screen position: yellow when wounded, light green when whole, light
  magenta when asked. When asked, the maximum follows after a slash in light green.
  @param(cr The creature.)
  @param(col The column.)
  @param(row The row.)
  @param(hotPink Set to print in light magenta.)
  @param(showMax Set to add the maximum after a slash.) }
procedure PrintHitPoints(cr: Pointer; col, row: Byte; hotPink, showMax: Boolean);

{ Prints a character's armor class in light green: 60 minus the stored value, with a minus sign when the value is above
  60.
  @param(cr The character.)
  @param(col Screen column.)
  @param(row Screen row.) }
procedure PrintArmorClass(cr: Pointer; col, row: Byte);

{ Fills the combat side panel for a creature when the panel is marked dirty (and clears the mark): name, hit points,
  armor class, readied weapon, and the status name of a creature out of play, '(Helpless)' or '(Casting)'.
  @param(cr The creature to show.) }
procedure CombatPrintCreatureInfo(cr: Pointer);

{ Tells whether a creature is helpless: any of the four helplessness effects is on it.
  @param(cr The creature.)
  @returns(True when the creature is helpless.) }
function IsHelpless(cr: Pointer): Boolean;

{ Recalculate a creature's derived statistics from its equipment: rebuild the equipped[] slot pointers from the item
  list, total the encumbrance and the hands in use, reset the attack dice to the unarmed values, apply Dexterity,
  Strength and the readied weapon, fold every equipped item into AC, recompute movement, and derive the rear AC
  (armorClass[1]). Magical body armor cancels any bonus from slot-9 and slot-7 protection items.
  @param(cr The creature, a Types.PCharRecord.) }
procedure RecalcStats(cr: Pointer);

{ Format v as a decimal string.
  @param(v The number.)
  @returns(Its decimal string.) }
function Int32Str(v: LongInt): String;

{ Format v as a decimal string.
  @param(v The number.)
  @returns(Its decimal string.) }
function Uint16Str(v: Word): String;

{ Format v as a decimal string.
  @param(v The number.)
  @returns(Its decimal string.) }
function Uint8Str(v: Byte): String;

{ Computes the Dexterity missile adjustment from the current Dexterity: -4 at 0..2, -3..-1 at 3..5, +1..+3 at 16..18, 3
  at 19..20, 4 at 21..23, 5 at 24..25, else 0.
  @param(cr The creature.)
  @returns(The adjustment.) }
function DexMissileAdjust(cr: Pointer): ShortInt;

{ Gives the Strength adjustment to damage, by translated Strength.
  @param(cr The creature.)
  @returns(The adjustment.) }
function StrDamageAdjust(cr: Pointer): ShortInt;

{ Finds a creature's weight allowance for its translated Strength, from -350 to 15000 encumbrance units.
  @param(cr The creature.)
  @returns(The allowance, which may be negative.) }
function WeightAllowance(cr: Pointer): Integer;

{ Marks the first memorized copy of a spell on a creature as cast by setting its high bit.
  @param(cr The creature.)
  @param(spell The spell.) }
procedure RemoveSpell(cr: Pointer; spell: Byte);

{ Unlinks an item from a creature's item list and returns it to the item pool; a nil item or one not in the list is
  reported instead.
  @param(cr The creature.)
  @param(it The item.) }
procedure RemoveItem(cr, it: Pointer);

{ Appends a copy of an item to a creature's item list. A monster in combat takes its copy from the heap; everyone else
  uses the slot pool.
  @param(cr The creature.)
  @param(it The item.) }
procedure AddItemCopy(cr, it: Pointer);

{ Shows a message on the bottom row in light green for the text delay, then clears the row.
  @param(s The message.) }
procedure PrintBottomLine(s: Types.TStr40);

{ Prints a creature's name with a message under it: in combat in the side panel from the given row on, elsewhere in the
  text window from row 17, or 18 while the border is off.
  @param(cr The creature.)
  @param(s The message.)
  @param(row The panel row of the name, read in combat.)
  @param(pause When set, pauses and then clears the message area.) }
procedure PrintCreatureMessage(cr: Pointer; s: String; row: Byte; pause: Boolean);

{ Clears the message area: the side panel's rows 10..21 in combat, otherwise rows 18..22. }
procedure ClearMessageWindow;

{ Draw a creature's name at (col,row) in its condition color, followed by 's when possessive: light red out of play,
  yellow for a side-1 creature in combat, light magenta at the level cap, light cyan otherwise.
  @param(cr The creature, a Types.PCharRecord.)
  @param(col The column.)
  @param(row The row.)
  @param(possessive True adds 's.) }
procedure DisplayCreatureName(cr: Pointer; col, row: Byte; possessive: Boolean);

{ Copies one half of a combat icon into a row of the composite icon sheet, mirrored through a scratch image when asked;
  the sheet takes the icon's key color, and the mask is copied only when there is one.
  @param(cell The icon's row in the icon table.)
  @param(half The half, 0 or 1.)
  @param(row The row of the sheet filled.)
  @param(mirror True mirrors it.) }
procedure CopyIconFacing(cell, half, row: Byte; mirror: Boolean);

{ Builds the four-frame moving-icon sheet from an icon: frame 0 straight and mirrored, then frame 1 mirrored and
  straight.
  @param(cell The icon slot.) }
procedure BuildIconFacings(cell: Byte);

{ Moves a combat icon from the start cell to the end cell. Both cells are clamped into the 50x25 arena, the line between
  them is walked into a list of step directions, and the combat view is scrolled to show the move. The icon then steps
  three pixels per cell, cycling through its facing frames, waiting the given pace per step and restoring the background
  behind it. If the icon leaves the view before the end, the walk backs up from the end cell to find where the path
  re-enters the view, scrolls there and walks again. Very short moves are not animated, and the last two steps are not
  walked.
  @param(startX The start column.)
  @param(startY The start row.)
  @param(endX The end column.)
  @param(endY The end row.)
  @param(frames The facing frames cycled through.)
  @param(pace The wait per step.) }
procedure CombatAnimateMovingIcon(startX, startY, endX, endY: Integer; frames, pace: Byte);

{ Prints the creature's name and a message with an effect or damage flash. In combat it builds the facing sheet from the
  flash icon, scrolls the creature into view if needed, plays the effect or damage sound, prints the message, then
  flashes the icon over the creature: an effect repeats the flash for the game's delay setting, while a damage flash
  plays once and is followed by a pause. Out of combat it prints the message with a pause.
  @param(cr The creature.)
  @param(effect True for an effect flash, False for a damage flash.)
  @param(s The text.) }
procedure PrintNameStringAnim(cr: Pointer; effect: Boolean; s: String);

{ Tells whether a creature carries an effect.
  @param(cr The creature.)
  @param(id The effect.)
  @param(eff Receives the matching effect node, or nil when there is none.)
  @returns(True when it carries the effect.) }
function HasEffect(cr: Pointer; id: Byte; var eff: Pointer): Boolean;

{ Takes damage off a creature's hit points and updates its status. Falling more than 9 below 0, or an animated creature
  reaching 0, is death; any other drop below 0 is dying (combat records how far below); exactly 0 is unconscious. A
  creature that is then not okay or animated is taken out of play with no hit points (in combat its side's count drops
  and its initiative is cleared); otherwise it keeps the hit points left.
  @param(cr The creature.)
  @param(dmg The damage.) }
procedure InflictDamage(cr: Pointer; dmg: Word);

{ Announces that a creature is fully or partially healed; out of combat, also repaints its party-panel row, plainly when
  it is the current character.
  @param(cr The creature.) }
procedure AnnounceHealStatus(cr: Pointer);

{ Finds a creature's opposing team.
  @param(cr The creature.)
  @returns(1 for a creature that is not hostile, else 0.) }
function EnemyTeam(cr: Pointer): ShortInt;

{ Recounts the creatures in play on each side. }
procedure CountTeams;

{ Counts the creatures within range of a creature on the wanted side: its own side when asked, else the enemy side. The
  ranked approach list is compacted in place to those creatures, their indices are copied into the target table, and the
  count is returned. Under effect 91 the preferred target is moved to the front of that list.
  @param(cr The creature.)
  @param(range The range.)
  @param(ownTeam True counts the creature's own side, False the enemy side.)
  @returns(The count.) }
function CountTargets(cr: Pointer; range: Byte; ownTeam: Boolean): Byte;

{ Measures the distance in whole steps from one creature to another, read from a fresh range-255 target list built
  ignoring terrain (the previous list is saved and restored). Note: an absent target gives the last entry's distance.
  @param(cr The creature measuring.)
  @param(other The creature to find.)
  @returns(The distance.) }
function CalcDistance(cr, other: Pointer): Byte;

{ Ends a creature's actions for the round: clears its initiative, casting, guarding and movement.
  @param(cr The creature.)
  @returns(Always True.) }
function EndActions(cr: Pointer): Boolean;

{ Ends a creature's actions and, unless it is turned, sets it guarding with a 'Guarding' message.
  @param(cr The creature.)
  @returns(Always True.) }
function Guard(cr: Pointer): Boolean;

{ The level at which the current character casts `spell`, by the spell's casting class. A character with no cleric or
  mage levels and a ranger level below 8 casts at 6. Otherwise cleric spells use the better of the cleric and paladin
  levels, druid spells the ranger level less 7, mage spells the better of the mage level and the ranger level less 8,
  and magic-item spells cast at 12. While GDVars.castFromItem is set, any spell but a magic item's casts at 6. With
  capped the result is at most 31.
  @param(spell The spell.)
  @param(capped True caps the level at 31.)
  @returns(The level.) }
function GetCasterLevel(spell: Byte; capped: Boolean): Byte;

{ Let the player pick a party member from a horizontal menu, starting at sel and returning the choice in sel. Down moves
  to the next member, wrapping; Up moves to the previous one or, with the mouse active, back to the character that was
  current on entry (mode <> 0) or to GDVars.clickedChar. With addExit, Esc or the Exit choice returns nil.
  @param(query The menu prompt.)
  @param(addExit True offers Exit.)
  @param(mode Nonzero sends Up back to the character current on entry, with the mouse active.)
  @param(sel The member to start at; receives the choice, or nil.) }
procedure SelectChar(query: Types.TStr40; addExit: Boolean; mode: Byte; var sel: Pointer);

{ Redraw the noncombat screen for the current interfaceState: the frame, the picture or map view, the party panel and
  the status line, as each state needs. }
procedure DisplayNoncombatInterface;

{ Draw the status line on row 15: the party's map coordinates (unless the area hides them), the facing, the time as
  HH:MM, and a camping or searching tag. Not drawn on the area map. }
procedure PrintMiscInfo;

{ Set up the combat screen: palette and frame, then scroll the view onto the map camera. }
procedure DisplayCombatInterface;

{ Tells whether a creature's readied weapon reaches beyond 1, thrown weapons included.
  @param(cr The creature.)
  @returns(True for a ranged weapon.) }
function HasRangedWeapon(cr: Pointer): Boolean;

{ Tells whether the readied weapon is ranged and its properties mark it both thrown ($10) and Strength-adjusted ($04).
  @param(cr The creature.)
  @returns(True for a throwable weapon.) }
function HasThrowableWeapon(cr: Pointer): Boolean;

{ Finds the item that does the damage in a ranged attack: the readied weapon itself when thrown, else the readied arrows
  for a bow or the readied quarrels for a crossbow, or nil when there is none.
  @param(cr The creature.)
  @param(sel Receives the item, or nil.)
  @returns(True when an item is found, and also for a weapon whose properties are exactly $0A, which needs no
    ammunition.) }
function FindDamagingRangedWeapon(cr: Pointer; var sel: Pointer): Boolean;

{ Recompute a creature's movement from its base: body armor and encumbrance first, then effects 39 and 74 each double it
  and 42 halves it. A side-0 creature adds the party movement modifier, never dropping below 1. The result is kept in
  GDVars.movementRate and returned doubled.
  @param(cr The creature, a Types.PCharRecord.)
  @returns(The movement, doubled.) }
function RecalcMovement(cr: Pointer): Byte;

{ Tells whether any party member (a side-0 player or non-player character) is dying. With `apply` set, the first dying
  member found is bandaged: it becomes unconscious, its overkill is cleared and the bandaging is announced.
  @param(apply Set to bandage the first dying member.)
  @returns(True when a member is dying.) }
function BandageDying(apply: Boolean): Boolean;

{ Finds the compass direction (0 = N, 1 = NE, ... 7 = NW) from one creature to another on the combat grid, by octant:
  the slopes 618/256 and 106/256 are tan 67.5 and tan 22.5 degrees.
  @param(creature The creature looked from.)
  @param(other The creature looked at.)
  @returns(The direction.) }
function DirTowardTarget(creature, other: Pointer): Byte;

{ True if some class of the creature (level 1..39) already has the experience for its next level and is not held back by
  its race. raceCaps gives each race's limit per class, and the per-race exceptions below stop some classes earlier,
  mostly for an ability score under 18.
  @param(cr The creature, a Types.PCharRecord.)
  @returns(True when a level can be gained.) }
function CanLevelUp(cr: Pointer): Boolean;

{ Plays a scatter effect around the combat target point: issues the sound cue, builds the effect's four frames from an
  icon, then scatters frames over growing rings, each point at a random angle, clipped to the effect box and flushed
  ring by ring. Near an arena edge the pattern is offset toward that edge. The view is scrolled to the point before and
  after.
  @param(step The number of rings, less 1, divided by 3.)
  @param(cell The icon the frames are built from.)
  @param(cue The sound cue.) }
procedure ScatterCombatIcon(step, cell, cue: Byte);

{ Computes the Constitution hit-point adjustment: -2 at Constitution 3, -1 at 4 to 6, +1 at 15, +2 at 16, and at 17 to
  19 the Constitution less 14 for fighters, rangers and paladins but +2 for everyone else. Note: a Constitution outside
  3 to 19 leaves the result undefined.
  @param(cr The creature.)
  @param(cls The class.)
  @returns(The adjustment.) }
function ClassConAdj(cr: Pointer; cls: Byte): ShortInt;

{ Resets the encounter state: clears three flags, sets the monster icon slot to 8, zeroes the money pool, and returns
  each node queued on the treasure list to the pool. }
procedure ClearEncounterState;

{ Builds the single facing frame of an icon for a compass direction: the diagonals use the next icon (cell + 1),
  mirrored for 5 and 7; the cardinal directions take cell or cell + 2 and the half from the direction.
  @param(dir The compass direction.)
  @param(cell The icon's row in the icon table.) }
procedure BuildIconFacingsDir(dir, cell: Byte);

implementation

const
  { the cloak slot of TCharRecord.equipped }
  EQUIP_CLOAK = 7;
  { TBaseItem.props bit: a missile weapon, so the Dexterity missile adjustment applies to hit }
  ITEM_PROP_MISSILE = $02;

type
  PBoolean = ^Boolean;

  { AC adjustments gathered by RecalcStats: [0] Dexterity, [1] shield, [2] summed protection items, [3] best slot-9
    item, [4] the slot-7 item, [5] best body armor (never below the base AC). Signed; summed into the front
    armorClass. }
  TAcAdjust = array[0..5] of ShortInt;
  PAcAdjust = ^TAcAdjust;

function DexterityArmorAdjustment(cr: Types.PCharRecord): ShortInt; forward;

function StrToHitAdjust(cr: Types.PCharRecord): ShortInt; forward;

function PercentileRoll(pct: Byte): Boolean;
begin
  PercentileRoll := pct > Random(100);
end;

{ Recompute the to-hit and damage figures from the readied weapon. Dexterity applies to missile weapons and Strength to
  melee weapons, and the readied ammunition's bonus adds to the weapon's own.
  @param(cr The creature.) }
procedure WeaponAdjust(cr: Types.PCharRecord);
var
  w: Types.PItemRec;
  wtype: Byte;
  plus: ShortInt;
begin
  w := cr^.equipped[C_Equip.WEAPON];
  if w = nil then Exit;
  wtype := w^.definition.itemType;
  cr^.thac0Adj := cr^.thac0Base;
  if (GDVars.baseItemTable[wtype].props and CharHlp.ITEM_PROP_MISSILE) <> 0 then
    cr^.thac0Adj := CharHlp.DexMissileAdjust(cr) + cr^.thac0Adj;
  cr^.curModA[1] := GDVars.baseItemTable[wtype].dmgSmMod;
  if (GDVars.baseItemTable[wtype].props and C_Item.STRENGTH_BONUS) <> 0 then begin
    cr^.thac0Adj := CharHlp.StrToHitAdjust(cr) + cr^.thac0Adj;
    cr^.curModA[1] := CharHlp.StrDamageAdjust(cr) + cr^.curModA[1];
  end;
  plus := w^.definition.plus;
  { bit 128: quarrel ammunition }
  if GDVars.baseItemTable[wtype].props > $7F then
    if cr^.equipped[C_Equip.BOLT] <> nil then
      plus := plus + cr^.equipped[C_Equip.BOLT]^.definition.plus;
  { bit 1: arrow ammunition }
  if (GDVars.baseItemTable[wtype].props and C_Item.USES_ARROWS) > 0 then
    if cr^.equipped[C_Equip.ARROW] <> nil then
      plus := plus + cr^.equipped[C_Equip.ARROW]^.definition.plus;
  cr^.curModA[1] := cr^.curModA[1] + plus;
  { An elf gains +1 to hit with item types 18, 19 and 22..26. }
  if (cr^.race = C_Race.ELF) and
      (((w^.definition.itemType > 21) and (w^.definition.itemType < 27)) or (w^.definition.itemType = 19) or
       (w^.definition.itemType = 18)) then
    Inc(plus);
  cr^.thac0Adj := cr^.thac0Adj + plus;
  cr^.curRollsA[1] := GDVars.baseItemTable[wtype].dmgSmRolls;
  cr^.curDiceA[1] := GDVars.baseItemTable[wtype].dmgSmDice;
end;

{ Sets movement from readied body armor's weight: the base movement up to 150, 9 up to 399, else 6; magic armor adds 3
  when that leaves 9 or less.
  @param(cr The character.)
  @param(it A readied item; anything but body armor is ignored.) }
procedure ArmorMoveAdjust(cr: Types.PCharRecord; it: Types.PItemRec);
begin
  if GDVars.baseItemTable[it^.definition.itemType].slot = C_Equip.ARMOR then begin
    case it^.definition.weight of
      0..150: cr^.movementCur := cr^.movementBase;
      151..399: cr^.movementCur := 9;
    else
      cr^.movementCur := 6;
    end;
    if (it^.definition.plus <> 0) and (cr^.movementCur <= 9) then
      cr^.movementCur := cr^.movementCur + 3;
  end;
end;

{ Fold one equipped item into the AC-adjustment array and the creature's saving-throw bonus. Only items whose AC
  descriptor has the high bit set count. A shield (slot 1) adds its AC plus its bonus. A descriptor-0 item adds
  protection -- slot 9 keeps the best, slot 7 replaces, any other slot sums -- and its save bonus. Any other item keeps
  the best AC total in adj[5], and magical body armor sets isMagicBody.
  @param(cr The creature.)
  @param(it The item.)
  @param(adj The AC adjustments gathered.)
  @param(isMagicBody Set for magical body armor.) }
procedure AddItemArmorAdjust(cr: Types.PCharRecord; it: Types.PItemRec; adj: PAcAdjust; isMagicBody: PBoolean);
var
  { base acDescr, masked to its low 7 bits }
  descr: Byte;
  { base equip slot }
  slot: Byte;
begin
  descr := GDVars.baseItemTable[it^.definition.itemType].acDescr;
  if descr > $7F then begin
    descr := descr and $7F;
    slot := GDVars.baseItemTable[it^.definition.itemType].slot;
    if slot = C_Equip.SHIELD then
      adj^[1] := descr + it^.definition.plus
    else if descr = 0 then begin
      if slot = C_Equip.FIRST_RING then begin
        if it^.definition.plus > adj^[3] then
          adj^[3] := it^.definition.plus;
      end else if slot = CharHlp.EQUIP_CLOAK then
        adj^[4] := it^.definition.plus
      else
        adj^[2] := adj^[2] + it^.definition.plus;
      cr^.saveBonus := cr^.saveBonus + it^.definition.saveBonus;
    end else begin
      if descr + it^.definition.plus > adj^[5] then begin
        adj^[5] := descr + it^.definition.plus;
        if it^.definition.plus > 0 then
          if slot = C_Equip.ARMOR then
            isMagicBody^ := True;
      end;
    end;
  end;
end;

{ Lowers a creature's movement for the coins it carries past its weight allowance: up to 512 over changes nothing, and
  each further band of 256 steps down to 9, 6 and 3. The movement is only ever lowered.
  @param(cr The creature.) }
procedure EncumbranceAdjust(cr: Types.PCharRecord);
var
  over: Integer;
  moveRate: Byte;
begin
  over := cr^.encumbrance - CharHlp.WeightAllowance(cr);
  if over < 0 then
    over := 0;
  case over of
    0..512: moveRate := cr^.movementCur;
    513..768: moveRate := 9;
    769..1024: moveRate := 6;
  else
    moveRate := 3;
  end;
  if moveRate < cr^.movementCur then
    cr^.movementCur := moveRate;
end;

procedure PrintItemString(cr, it: Pointer; col, row: Byte; isInv, doPrint: Boolean);
var
  { name-component index, 1..3 }
  part: Byte;
  { which components are identified }
  mask: Byte;
  { HasEffect's out-node }
  eff: Pointer;
  { Detect Magic running on anyone }
  found: Boolean;
  { the plural 's' is already emitted }
  appended: Boolean;
  { roster walker }
  p: Types.PCharRecord;
begin
  Types.PItemRec(it)^.name := '';
  if isInv then begin
    if Types.PItemRec(it)^.definition.equipped <> 0 then
      Types.PItemRec(it)^.name := ' Yes  '
    else
      Types.PItemRec(it)^.name := ' No   ';
  end;
  { Detect Magic works for the whole party: the walk stops at the first member carrying the effect. }
  found := False;
  p := GDVars.creatureListHead;
  while (p <> nil) and not found do begin
    if CharHlp.HasEffect(p, C_Effect.DETECT_MAGIC, eff) then
      found := True;
    p := p^.next;
  end;
  if found then
    if (Types.PItemRec(it)^.definition.plus > 0) or (Types.PItemRec(it)^.definition.saveBonus > 0) or
        (Types.PItemRec(it)^.definition.cursed <> 0) then
      Types.PItemRec(it)^.name := Types.PItemRec(it)^.name + '*' + ' ';
  if Types.PItemRec(it)^.definition.quantity > 0 then
    Types.PItemRec(it)^.name := Types.PItemRec(it)^.name + CharHlp.Uint8Str(Types.PItemRec(it)^.definition.quantity) +
      ' ';
  { Pass 1 collects the visible components into a 3-bit mask: component `part` shows only when it exists and its
    unidMask bit is clear. The mask bit and the unidMask bit are numbered in opposite directions. }
  mask := 0;
  for part := 1 to 3 do
    if Types.PItemRec(it)^.definition.nameIds[part] <> 0 then
      if (Types.PItemRec(it)^.definition.unidMask shr (3 - part)) and 1 = 0 then
        Inc(mask, 1 shl (part - 1));
  { Pass 2 appends the components high first, so an item reads "Long Sword +1" rather than in storage order. The
    five-term test decides which word takes the plural 's'. }
  appended := False;
  for part := 3 downto 1 do
    if (mask shr (part - 1)) and 1 > 0 then begin
      Types.PItemRec(it)^.name := Types.PItemRec(it)^.name +
        GDConsts.itemNameParts[Types.PItemRec(it)^.definition.nameIds[part]];
      if (Types.PItemRec(it)^.definition.quantity < 2) or appended then
        Types.PItemRec(it)^.name := Types.PItemRec(it)^.name + ' '
      else if ((1 shl (part - 1)) = mask) or
        ((part = 1) and (mask > 4) and (Types.PItemRec(it)^.definition.itemType <> 55)) or
        ((part = 2) and not Odd(mask)) or ((part = 3) and (Types.PItemRec(it)^.definition.itemType = 55)) or
        (((Types.PItemRec(it)^.definition.itemType = 30) or (Types.PItemRec(it)^.definition.itemType = 5) or
          (Types.PItemRec(it)^.definition.itemType = 7) or (Types.PItemRec(it)^.definition.itemType = 12)) and
        (Types.PItemRec(it)^.definition.nameIds[3] <> 93)) then begin
        Types.PItemRec(it)^.name := Types.PItemRec(it)^.name + 's ';
        appended := True;
      end else
        Types.PItemRec(it)^.name := Types.PItemRec(it)^.name + ' ';
    end;
  if doPrint then
    TextRend.DisplayString(col, row, 10, 0, Types.PItemRec(it)^.name);
end;

procedure DisplayParty(hl: Pointer);
var
  { roster walker }
  p: Types.PCharRecord;
  { panel left column }
  col: Byte;
  { current row }
  row: Byte;
  { digit-width column nudge }
  band: Byte;
begin
  { Not drawn in the automap state while the map pane is enabled, or while GDVars.partyPanelHidden is set. }
  if ((GDVars.interfaceState = C_Ifc.AREA_MAP) and (GDVars.vmBand.zone0^.mapPaneEnabled = 1)) or
      (GDVars.partyPanelHidden <> 0) then
    Exit;
  if GDVars.interfaceState = C_Ifc.MAIN_MENU then
    col := 1
  else
    col := 17;
  { The panel rectangle, kept for the rest of the game; its bottom row GDVars.partyAreaBottom grows by one per member
    below. }
  GDVars.partyAreaLeft := col;
  GDVars.partyAreaTop := 4;
  GDVars.partyAreaRight := 38;
  GDVars.partyAreaBottom := 3;
  row := 2;
  TextRend.DisplayString(col, row, 15, 0, 'Name');
  TextRend.DisplayString(33, row, 15, 0, 'AC  HP');
  Inc(row, 2);
  p := GDVars.creatureListHead;
  while p <> nil do begin
    Inc(GDVars.partyAreaBottom);
    Border.ClearBox(col, row, 38, row);
    if p = hl then
      TextRend.DisplayString(col, row, 15, 0, p^.name)
    else
      CharHlp.DisplayCreatureName(p, col, row, False);
    { Right-align AC under the 'AC' header and HP at the panel's right edge: band is 3 minus the printed width. AC is
      stored biased by 60 (see PrintArmorClass), so the four AC bands print 2, 1, 2 and 3 characters. }
    case p^.armorClass[0] of
      0..50: band := 1;
      51..60: band := 2;
      61..69: band := 1;
    else
      band := 0;
    end;
    CharHlp.PrintArmorClass(p, band + 32, row);
    case p^.hpCur of
      0..9: band := 2;
      10..99: band := 1;
    else
      band := 0;
    end;
    CharHlp.PrintHitPoints(p, band + 36, row, False, False);
    Inc(row);
    p := p^.next;
  end;
  Border.ClearBox(col, row, 38, row);
end;

procedure DisplayRoster(hl: Pointer; clearHl: Boolean);
var
  { roster walker }
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  numberText: array[1..4] of Byte;
  { panel left column }
  col: Byte;
  { current row }
  row: Byte;
  { digit-width column nudge }
  band: Byte;
begin
  if ((GDVars.interfaceState = C_Ifc.AREA_MAP) and (GDVars.vmBand.zone0^.mapPaneEnabled = 1)) or
      (GDVars.partyPanelHidden <> 0) then
    Exit;
  { hl only seeds the highlight, and only when none is set, so a repaint in progress keeps its highlight. }
  if GDVars.highlightedChar = nil then
    GDVars.highlightedChar := hl;
  if GDVars.interfaceState = C_Ifc.MAIN_MENU then
    col := 1
  else
    col := 17;
  GDVars.partyAreaLeft := col;
  GDVars.partyAreaTop := 4;
  GDVars.partyAreaRight := 38;
  GDVars.partyAreaBottom := 3;
  { The first member row, below the panel headers. }
  row := 4;
  p := GDVars.creatureListHead;
  while p <> nil do begin
    Inc(GDVars.partyAreaBottom);
    if p = GDVars.highlightedChar then begin
      if clearHl then
        TextRend.DisplayString(col, row, 15, 0, p^.name)
      else
        CharHlp.DisplayCreatureName(p, col, row, False);
      { The same digit-width bands as DisplayParty. }
      case p^.armorClass[0] of
        0..50: band := 1;
        51..60: band := 2;
        61..69: band := 1;
      else
        band := 0;
      end;
      CharHlp.PrintArmorClass(p, band + 32, row);
      case p^.hpCur of
        0..9: band := 2;
        10..99: band := 1;
      else
        band := 0;
      end;
      CharHlp.PrintHitPoints(p, band + 36, row, False, False);
    end;
    Inc(row);
    p := p^.next;
  end;
  Border.ClearBox(col, row, 38, row);
  GDVars.highlightedChar := nil;
end;

procedure PrintArmorClass(cr: Pointer; col, row: Byte);
var
  { the formatted AC }
  s: String;
  { Unused in this version; see the other implementations of this routine. }
  color: Byte;
begin
  s := CharHlp.Uint8Str(Abs(Types.PCharRecord(cr)^.armorClass[0] - 60));
  if Types.PCharRecord(cr)^.armorClass[0] > 60 then
    s := '-' + s;
  TextRend.DisplayString(col, row, 10, 0, s);
end;

procedure PrintHitPoints(cr: Pointer; col, row: Byte; hotPink, showMax: Boolean);
var
  { the formatted current HP }
  s: String;
  { 14 wounded / 10 whole / 13 hotPink }
  color: Byte;
  { width of the current-HP text }
  len: ShortInt;
begin
  if Types.PCharRecord(cr)^.hpCur < Types.PCharRecord(cr)^.hpMax then
    color := 14
  else
    color := 10;
  if hotPink then
    color := 13;
  s := CharHlp.Uint8Str(Types.PCharRecord(cr)^.hpCur);
  TextRend.DisplayString(col, row, color, 0, s);
  if showMax then begin
    len := Length(s);
    TextRend.DisplayString(col + len, row, 10, 0, '/' + CharHlp.Uint8Str(Types.PCharRecord(cr)^.hpMax));
  end;
end;

procedure CombatPrintCreatureInfo(cr: Pointer);
var
  { Unused in this version; see the other implementations of this routine. }
  col: Byte;
  { current panel row }
  row: Byte;
begin
  if GDVars.infoPanelDirty <> 0 then begin
    GDVars.infoPanelDirty := 0;
    Border.ClearBox(23, 1, 38, 21);
    row := 1;
    CharHlp.PrintCreatureMessage(cr, ' ', row, False);
    Inc(row);
    TextRend.DisplayString(23, row + 1, 10, 0, 'Hitpoints');
    CharHlp.PrintHitPoints(cr, 33, row + 1, False, False);
    Inc(row, 2);
    TextRend.DisplayString(23, row + 1, 10, 0, 'AC');
    CharHlp.PrintArmorClass(cr, 26, row + 1);
    GDVars.textCursorRow := row + 1;
    if Types.PCharRecord(cr)^.equipped[C_Equip.WEAPON] <> nil then begin
      Inc(row, 2);
      col := 23;
      CharHlp.PrintItemString(cr, Types.PCharRecord(cr)^.equipped[C_Equip.WEAPON], 0, 0, False, False);
      TextRend.DisplayMessageWindow(23, row + 1, 38, row + 1 + 1 + 1, 10, 0, True,
                                    Types.PCharRecord(cr)^.equipped[C_Equip.WEAPON]^.name);
    end;
    row := GDVars.textCursorRow + 1;
    if Types.PCharRecord(cr)^.inPlay = 0 then
      TextRend.DisplayString(23, row + 1, 15, 0, GDConsts.statusNameTable[Types.PCharRecord(cr)^.status])
    else if CharHlp.IsHelpless(cr) then
      TextRend.DisplayString(23, row + 1, 15, 0, '(Helpless)')
    else if Types.PCharRecord(cr)^.combatAddr^.spellCast > 0 then
      TextRend.DisplayString(23, row + 1, 15, 0, '(Casting)');
  end;
end;

function IsHelpless(cr: Pointer): Boolean;
var
  i: Byte;
  eff: Pointer;
begin
  IsHelpless := False;
  for i := 1 to 4 do
    if CharHlp.HasEffect(cr, GDConsts.helplessEffects[i], eff) then
      IsHelpless := True;
end;

procedure RecalcStats(cr: Pointer);
var
  { unarmed-dice copy index }
  j: Byte;
  { AC summing index }
  k: ShortInt;
  { item-list walker }
  it: Types.PItemRec;
  { magical body armor is worn }
  magicBody: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  bag: Boolean;
  { AC adjustments }
  adj: TAcAdjust;
  { equipped[] clearing index }
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  coinIdx: Byte;
  { coin-type index }
  c: ShortInt;
  { one item's weight times its quantity }
  w: Word;
  { the item's equip slot }
  slot: Byte;
  { Unused in this version; see the other implementations of this routine. }
  weight: Word;
begin
  for i := C_Equip.WEAPON to C_Equip.BOLT do
    Types.PCharRecord(cr)^.equipped[i] := nil;
  bag := False;
  Types.PCharRecord(cr)^.numberOfItems := 0;
  it := Types.PCharRecord(cr)^.items;
  Types.PCharRecord(cr)^.handsEquipped := 0;
  Types.PCharRecord(cr)^.encumbrance := 0;
  GDVars.runTotal := 0;
  while it <> nil do begin
    Inc(Types.PCharRecord(cr)^.numberOfItems);
    w := it^.definition.weight;
    if it^.definition.quantity > 0 then
      w := it^.definition.quantity * w;
    Inc(Types.PCharRecord(cr)^.encumbrance, w);
    if it^.definition.equipped <> 0 then begin
      Inc(GDVars.runTotal, w);
      slot := GDVars.baseItemTable[it^.definition.itemType].slot;
      case slot of
        C_Equip.WEAPON..C_Equip.BOOTS: Types.PCharRecord(cr)^.equipped[ShortInt(slot)] := it;
        C_Equip.FIRST_RING:
          if Types.PCharRecord(cr)^.equipped[C_Equip.FIRST_RING] <> nil then begin
            if Types.PCharRecord(cr)^.equipped[C_Equip.SECOND_RING] = nil then
              Types.PCharRecord(cr)^.equipped[C_Equip.SECOND_RING] := it;
          end else
            Types.PCharRecord(cr)^.equipped[C_Equip.FIRST_RING] := it;
      end;
      { Arrows and quarrels also fill the two ammunition slots. }
      if it^.definition.itemType = 30 then
        Types.PCharRecord(cr)^.equipped[C_Equip.ARROW] := it;
      if (it^.definition.itemType = 12) or (it^.definition.itemType = 74) then
        Types.PCharRecord(cr)^.equipped[C_Equip.BOLT] := it;
      Types.PCharRecord(cr)^.handsEquipped := Types.PCharRecord(cr)^.handsEquipped +
        GDVars.baseItemTable[it^.definition.itemType].hands;
    end;
    it := it^.next;
  end;
  for c := 0 to 2 do
    Types.PCharRecord(cr)^.encumbrance := Types.PCharRecord(cr)^.encumbrance + Types.PCharRecord(cr)^.coins[c];
  for j := 1 to 2 do begin
    Types.PCharRecord(cr)^.curRollsA[j] := Types.PCharRecord(cr)^.unarmedRollsA[j];
    Types.PCharRecord(cr)^.curDiceA[j] := Types.PCharRecord(cr)^.unarmedDiceA[j];
    Types.PCharRecord(cr)^.curModA[j] := Types.PCharRecord(cr)^.unarmedModA[j];
  end;
  GameIo.ZeroFill(adj, SizeOf(adj));
  magicBody := False;
  Types.PCharRecord(cr)^.saveBonus := 0;
  Types.PCharRecord(cr)^.armorClass[0] := Types.PCharRecord(cr)^.acBase;
  Types.PCharRecord(cr)^.movementCur := Types.PCharRecord(cr)^.movementBase;
  Types.PCharRecord(cr)^.thac0Adj := Types.PCharRecord(cr)^.thac0Base;
  adj[0] := CharHlp.DexterityArmorAdjustment(cr);
  if Types.PCharRecord(cr)^.equipped[C_Equip.WEAPON] = nil then begin
    Types.PCharRecord(cr)^.thac0Adj := CharHlp.StrToHitAdjust(cr) + Types.PCharRecord(cr)^.thac0Adj;
    Types.PCharRecord(cr)^.curModA[1] := CharHlp.StrDamageAdjust(cr) + Types.PCharRecord(cr)^.curModA[1];
  end;
  CharHlp.WeaponAdjust(cr);
  it := Types.PCharRecord(cr)^.items;
  while it <> nil do begin
    if it^.definition.equipped <> 0 then begin
      CharHlp.ArmorMoveAdjust(cr, it);
      CharHlp.AddItemArmorAdjust(cr, it, @adj, @magicBody);
    end;
    it := it^.next;
  end;
  if magicBody then begin
    if adj[3] > 0 then adj[3] := 0;
    if adj[4] > 0 then adj[4] := 0;
  end;
  Types.PCharRecord(cr)^.movementCur := CharHlp.RecalcMovement(cr) div 2;
  if adj[5] < Types.PCharRecord(cr)^.armorClass[0] then
    adj[5] := Types.PCharRecord(cr)^.armorClass[0];
  Types.PCharRecord(cr)^.armorClass[0] := 0;
  for k := 5 downto 0 do
    Types.PCharRecord(cr)^.armorClass[0] := Types.PCharRecord(cr)^.armorClass[0] + adj[k];
  Types.PCharRecord(cr)^.armorClass[1] := adj[5] + adj[2] + adj[4] + adj[3] - 1 - 1;
end;

function RecalcMovement(cr: Pointer): Byte;
var
  it: Types.PItemRec;
  eff: Pointer;
begin
  Types.PCharRecord(cr)^.movementCur := Types.PCharRecord(cr)^.movementBase;
  it := Types.PCharRecord(cr)^.items;
  while it <> nil do begin
    if it^.definition.equipped <> 0 then
      CharHlp.ArmorMoveAdjust(cr, it);
    it := it^.next;
  end;
  CharHlp.EncumbranceAdjust(cr);
  if CharHlp.HasEffect(cr, C_Effect.HASTED, eff) then
    Types.PCharRecord(cr)^.movementCur := Types.PCharRecord(cr)^.movementCur * 2;
  if CharHlp.HasEffect(cr, C_Effect.SLOWED, eff) then
    Types.PCharRecord(cr)^.movementCur := Types.PCharRecord(cr)^.movementCur div 2;
  if CharHlp.HasEffect(cr, C_Effect.MAGIC_BOOTS, eff) then
    Types.PCharRecord(cr)^.movementCur := Types.PCharRecord(cr)^.movementCur * 2;
  GDVars.movementRate := Types.PCharRecord(cr)^.movementCur;
  if Types.PCharRecord(cr)^.side = 0 then begin
    if GDVars.movementRate + GDVars.vmBand.zone0^.partyMoveMod < 1 then
      GDVars.movementRate := 1
    else
      GDVars.movementRate := GDVars.movementRate + Byte(GDVars.vmBand.zone0^.partyMoveMod);
  end;
  GDVars.movementRate := GDVars.movementRate * 2;
  RecalcMovement := GDVars.movementRate;
end;

function Uint8Str(v: Byte): String;
var
  s: String;
begin
  Str(v, s);
  Uint8Str := s;
end;

function Uint16Str(v: Word): String;
var
  s: String;
begin
  Str(v, s);
  Uint16Str := s;
end;

function Int32Str(v: LongInt): String;
var
  s: String;
begin
  Str(v, s);
  Int32Str := s;
end;

{ Computes the Dexterity defensive adjustment from the current Dexterity: -4 at 1..3, -3..-1 at 4..6, +1..+4 at 15..18,
  4 at 19..20, 5 at 21..23, 6 at 24..25, else 0.
  @param(cr The creature.)
  @returns(The adjustment.) }
function DexterityArmorAdjustment;
var
  d: Byte;
begin
  d := cr^.stats[C_Stat.DEXTERITY].cur;
  case d of
    1..3: DexterityArmorAdjustment := -4;
    4..6: DexterityArmorAdjustment := d - 7;
    15..18: DexterityArmorAdjustment := d - 14;
    19..20: DexterityArmorAdjustment := 4;
    21..23: DexterityArmorAdjustment := 5;
    24..25: DexterityArmorAdjustment := 6;
  else
    DexterityArmorAdjustment := 0;
  end;
end;

function DexMissileAdjust(cr: Pointer): ShortInt;
var
  d: Byte;
begin
  d := Types.PCharRecord(cr)^.stats[C_Stat.DEXTERITY].cur;
  case d of
    0..2: DexMissileAdjust := -4;
    3..5: DexMissileAdjust := d - 6;
    16..18: DexMissileAdjust := d - 15;
    19..20: DexMissileAdjust := 3;
    21..23: DexMissileAdjust := 4;
    24..25: DexMissileAdjust := 5;
  else
    DexMissileAdjust := 0;
  end;
end;

{ Converts Strength to one scale: 0..17 as is; 18 by exceptional Strength (without it 18, 01-50 19, 51-75 20, 76-90 21,
  91-99 22, 00 23); 19..25 become 24..30. Note: other values leave the result undefined.
  @param(cr The creature.)
  @returns(Strength on that scale.) }
function TranslatedStrength(cr: Types.PCharRecord): Byte;
begin
  case cr^.stats[C_Stat.STRENGTH].cur of
    0..17: TranslatedStrength := cr^.stats[C_Stat.STRENGTH].cur;
    18:
      case cr^.strExcCur of
        0: TranslatedStrength := 18;
        1..50: TranslatedStrength := 19;
        51..75: TranslatedStrength := 20;
        76..90: TranslatedStrength := 21;
        91..99: TranslatedStrength := 22;
        100: TranslatedStrength := 23;
      end;
    19..25: TranslatedStrength := cr^.stats[C_Stat.STRENGTH].cur + 5;
  end;
end;

{ The Strength adjustment to hit, by translated Strength.
  @param(cr The creature.)
  @returns(The adjustment.) }
function StrToHitAdjust;
var
  ts: Byte;
begin
  StrToHitAdjust := 0;
  ts := CharHlp.TranslatedStrength(cr);
  case ts of
    1..3: StrToHitAdjust := -3;
    4..5: StrToHitAdjust := -2;
    6..7: StrToHitAdjust := -1;
    17..19: StrToHitAdjust := 1;
    20..22: StrToHitAdjust := 2;
    23..25: StrToHitAdjust := 3;
    26..27: StrToHitAdjust := 4;
    28..30: StrToHitAdjust := ts - 23;
  end;
end;

function StrDamageAdjust(cr: Pointer): ShortInt;
var
  ts: Byte;
begin
  StrDamageAdjust := 0;
  ts := CharHlp.TranslatedStrength(cr);
  case ts of
    1..2: StrDamageAdjust := -2;
    3..5: StrDamageAdjust := -1;
    16: StrDamageAdjust := 1;
    17..19: StrDamageAdjust := ts - 16;
    20..29: StrDamageAdjust := ts - 17;
    30: StrDamageAdjust := 14;
  end;
end;

function WeightAllowance(cr: Pointer): Integer;
var
  ts: Byte;
begin
  ts := CharHlp.TranslatedStrength(cr);
  case ts of
    1..3: WeightAllowance := -350;
    4..5: WeightAllowance := -250;
    6..7: WeightAllowance := -150;
    12..13: WeightAllowance := 100;
    14..15: WeightAllowance := 200;
    16: WeightAllowance := 350;
    17..21: WeightAllowance := (ts - 17) * 250 + 500;
    22..26: WeightAllowance := (ts - 22) * 1000 + 2000;
    27: WeightAllowance := 7500;
    28..30: WeightAllowance := (ts - 28) * 3000 + 9000;
  else
    WeightAllowance := 0;
  end;
end;

procedure RemoveSpell(cr: Pointer; spell: Byte);
var
  i: Byte;
begin
  i := 0;
  while i <= 140 do begin
    if Types.PCharRecord(cr)^.spells[i] = spell then begin
      Types.PCharRecord(cr)^.spells[i] := spell or C_Spell.PENDING_FLAG;
      i := 141;
    end;
    Inc(i);
  end;
end;

procedure RemoveItem(cr, it: Pointer);
var
  p: Types.PItemRec;
begin
  if it = nil then
    TextRend.DisplayAndPause(14, 0, 'Nil Item pointer...')
  else begin
    p := Types.PCharRecord(cr)^.items;
    if p = it then
      Types.PCharRecord(cr)^.items := Types.PItemRec(it)^.next
    else
      while (p <> nil) and (p^.next <> it) do
        p := p^.next;
    if p = nil then
      TextRend.DisplayAndPause(14, 0, 'Tried to Lose item & couldn''t find it!')
    else begin
      p^.next := Types.PItemRec(it)^.next;
      Types.PItemRec(it)^.next := nil;
      GameIo.FreeSlot(Types.PItemRec(it));
    end;
  end;
end;

procedure AddItemCopy(cr, it: Pointer);
var
  p: Types.PItemRec;
  n: Types.PItemRec;
begin
  if (GDVars.interfaceState = C_Ifc.IN_COMBAT) and (Types.PCharRecord(cr)^.combatAddr <> nil) and
      (Types.PCharRecord(cr)^.combatAddr^.notPcNpc = 1) then
    GetMem(n, SizeOf(Types.TItemRec))
  else
    n := GameIo.AllocSlot;
  Move(Types.PItemRec(it)^, n^, SizeOf(Types.TItemRec));
  n^.next := nil;
  p := Types.PCharRecord(cr)^.items;
  if p = nil then
    Types.PCharRecord(cr)^.items := n
  else begin
    while p^.next <> nil do
      p := p^.next;
    p^.next := n;
  end;
end;

procedure PrintBottomLine(s: Types.TStr40);
begin
  Border.ClearBox(0, 24, 39, 24);
  TextRend.DisplayString(0, 24, 10, 0, s);
  TextRend.PauseOnly;
  Border.ClearBox(0, 24, 39, 24);
end;

procedure PrintCreatureMessage(cr: Pointer; s: String; row: Byte; pause: Boolean);
var
  top: Byte;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    Border.ClearBox(23, row, 38, 21);
    CharHlp.DisplayCreatureName(cr, 23, row, False);
    TextRend.DisplayMessageWindow(23, row + 1, 38, 21, 10, 0, True, s);
  end else begin
    if GDVars.suppressBorder <> 0 then
      top := 18
    else
      top := 17;
    Border.ClearBox(1, top, 38, 22);
    CharHlp.DisplayCreatureName(cr, 1, top + 1, False);
    TextRend.DisplayMessageWindow(1, top + 2, 38, 22, 10, 0, True, s);
  end;
  if pause then begin
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
  end;
end;

procedure ClearMessageWindow;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then
    Border.ClearBox(23, 10, 38, 21)
  else
    Border.ClearBox(1, 18, 38, 22);
end;

procedure DisplayCreatureName(cr: Pointer; col, row: Byte; possessive: Boolean);
var
  color: Byte;
begin
  if Types.PCharRecord(cr)^.inPlay = 0 then
    color := 12
  else if (Types.PCharRecord(cr)^.side = 1) and (GDVars.interfaceState = C_Ifc.IN_COMBAT) then
    color := 14
  else if Types.PCharRecord(cr)^.levelCapped <> 0 then
    color := 13
  else
    color := 11;
  TextRend.DisplayString(col, row, color, 0, Types.PCharRecord(cr)^.name);
  if possessive then
    TextRend.DisplayString(col + Length(Types.PCharRecord(cr)^.name), row, color, 0, '''s');
end;

procedure CopyIconFacing(cell, half, row: Byte; mirror: Boolean);
var
  tmp: Types.PImage;
  stride: Word;
  rowOfs: Word;
begin
  stride := GDVars.moveIconSheet^.total;
  rowOfs := row * stride;
  if mirror then begin
    Blit.AllocPic(24, 3, 1, 1, tmp);
    Blit.MirrorPic(GDVars.iconAnimTable[cell, half], tmp);
    Move(tmp^.data, GDVars.moveIconSheet^.data[rowOfs], stride);
    GDVars.moveIconSheet^.keyColor := GDVars.iconAnimTable[cell, half]^.keyColor;
    if tmp^.mask <> nil then
      Move(tmp^.mask^, GDVars.moveIconSheet^.mask^[rowOfs], stride);
    Blit.FreePic(tmp);
  end else begin
    Move(GDVars.iconAnimTable[cell, half]^.data, GDVars.moveIconSheet^.data[rowOfs], stride);
    GDVars.moveIconSheet^.keyColor := GDVars.iconAnimTable[cell, half]^.keyColor;
    if GDVars.iconAnimTable[cell, half]^.mask <> nil then
      Move(GDVars.iconAnimTable[cell, half]^.mask^, GDVars.moveIconSheet^.mask^[rowOfs], stride);
  end;
end;

procedure BuildIconFacings(cell: Byte);
begin
  CharHlp.CopyIconFacing(cell, 0, 0, False);
  CharHlp.CopyIconFacing(cell, 0, 1, True);
  CharHlp.CopyIconFacing(cell, 1, 2, True);
  CharHlp.CopyIconFacing(cell, 1, 3, False);
end;

procedure CombatAnimateMovingIcon(startX, startY, endX, endY: Integer; frames, pace: Byte);
var
  { step directions, 8 = none }
  pathBuf: array[0..147] of Byte;
  { line-walk state }
  w: Types.TLineWalk;
  { Unused in this version; see the other implementations of this routine. }
  req: Integer;
  { index into pathBuf }
  n: Byte;
  { steps to walk }
  count: Byte;
  { facing frame, cycles 0..frames-1 }
  frame: Byte;
  { Unused in this version; see the other implementations of this routine. }
  lastFrame: Byte;
  { final outer iteration }
  lastPass: Boolean;
  { walk stopped or left the view }
  done: Boolean;
  { scroll target }
  camX: Integer;
  camY: Integer;
  { Unused in this version; see the other implementations of this routine. }
  prevX: Integer;
  { Unused in this version; see the other implementations of this routine. }
  prevY: Integer;
  { sub-cell accumulator, carries at 3 }
  accX: Integer;
  accY: Integer;
  { whole-move delta }
  dirX: Integer;
  dirY: Integer;
  { this step's delta }
  stepX: Integer;
  stepY: Integer;
  { icon pixel position in the view, 0..18 }
  pixX: Integer;
  pixY: Integer;
  { scroll overshoot near an arena edge }
  ovX: Integer;
  ovY: Integer;

  { Clamp a cell into the 50x25 arena. }
  procedure ClampIconPosition(var x, y: Integer);
  begin
    if x < 0 then
      x := 0
    else if x > 49 then
      x := 49;
    if y < 0 then
      y := 0
    else if y > 24 then
      y := 24;
  end;

begin
  ClampIconPosition(startX, startY);
  ClampIconPosition(endX, endY);
  prevX := startX;
  prevY := startY;
  FillChar(pathBuf, SizeOf(pathBuf), C_Dir.CENTER);
  GameIo.ZeroFill(w, SizeOf(w));
  n := 0;
  frame := 0;
  w.x0 := startX * 3;
  w.y0 := startY * 3;
  w.x1 := endX * 3;
  w.y1 := endY * 3;
  Pathing.PathFind(w);
  repeat
    done := not Pathing.NextPathStep(w);
    pathBuf[n] := w.direction;
    Inc(n);
  until done;
  if n < 4 then Exit;
  count := n - 2;
  dirX := endX - startX;
  dirY := endY - startY;
  if not CbtMap.ViewCoordsValid(startX - GDVars.arenaPtr^.ox, startY - GDVars.arenaPtr^.oy) or
      not CbtMap.ViewCoordsValid(endX - GDVars.arenaPtr^.ox, endY - GDVars.arenaPtr^.oy) then begin
    if (Abs(dirX) <= 6) and (Abs(dirY) <= 6) then begin
      lastPass := True;
      camX := startX + dirX div 2;
      camY := startY + dirY div 2;
    end else begin
      lastPass := False;
      camX := GDVars.arenaPtr^.ox + 3;
      camY := GDVars.arenaPtr^.oy + 3;
    end;
  end else begin
    lastPass := True;
    camX := GDVars.arenaPtr^.ox + 3;
    camY := GDVars.arenaPtr^.oy + 3;
  end;
  CbtMap.ScrollView(camX, camY, $FF, C_Dir.CENTER);
  n := 0;
  accX := 0;
  accY := 0;
  repeat
    pixX := (startX - GDVars.arenaPtr^.ox) * 3 + accX;
    pixY := (startY - GDVars.arenaPtr^.oy) * 3 + accY;
    prevX := startX;
    prevY := startY;
    done := False;
    repeat
      stepX := GDConsts.dirDeltaX[pathBuf[n]];
      stepY := GDConsts.dirDeltaY[pathBuf[n]];
      Inc(pixX, stepX);
      Inc(pixY, stepY);
      if (pace > 0) or (pixX mod 3 = 0) or (pixY mod 3 = 0) then begin
        Blit.BlitTileClipped(pixX, pixY, frame, 5, GDVars.moveIconSheet, GDVars.viewImageBuf);
        Blit.FlushView;
        Delay(pace);
        Blit.BlitTileClipped(pixX, pixY, 0, 0, GDVars.iconSaveBuf, GDVars.viewImageBuf);
        Inc(frame);
        if frame >= frames then
          frame := 0;
      end;
      Inc(n);
      if (pixX < 0) or (pixX > 18) or (pixY < 0) or (pixY > 18) then
        done := True;
      if not done and (n < count) then begin
        Inc(accX, stepX);
        Inc(accY, stepY);
        if Abs(accX) = 3 then begin
          Inc(startX, Pathing.SignOf(accX));
          Inc(camX, Pathing.SignOf(accX));
          accX := 0;
        end;
        if Abs(accY) = 3 then begin
          Inc(startY, Pathing.SignOf(accY));
          Inc(camY, Pathing.SignOf(accY));
          accY := 0;
        end;
      end;
    until (n >= count) or done;
    if n < count then begin
      ovX := 0;
      ovY := 0;
      accY := 0;
      accX := 0;
      startX := endX;
      startY := endY;
      prevX := startX;
      prevY := startY;
      if endX + 3 > 49 then
        ovX := endX - 49
      else if endX < 3 then
        ovX := 3 - endX;
      if endY + 3 > 24 then
        ovY := endY - 24
      else if endY < 3 then
        ovY := 3 - endY;
      camX := endX + ovX;
      camY := endY + ovY;
      CbtMap.ScrollView(camX, camY, $FF, C_Dir.CENTER);
      pixX := (endX - GDVars.arenaPtr^.ox) * 3;
      pixY := (endY - GDVars.arenaPtr^.oy) * 3;
      n := count;
      done := False;
      repeat
        stepX := -GDConsts.dirDeltaX[pathBuf[n]];
        stepY := -GDConsts.dirDeltaY[pathBuf[n]];
        Inc(pixX, stepX);
        Inc(pixY, stepY);
        if pixX > 18 then
          startX := GDVars.arenaPtr^.ox + 6
        else if pixX < 0 then
          startX := GDVars.arenaPtr^.ox;
        if pixY > 18 then
          startY := GDVars.arenaPtr^.oy + 6
        else if pixY < 0 then
          startY := GDVars.arenaPtr^.oy;
        if (pixX < 0) or (pixX > 18) or (pixY < 0) or (pixY > 18) then
          done := True;
        if not done then begin
          Inc(accX, stepX);
          Inc(accY, stepY);
          if Abs(accX) = 3 then begin
            Inc(startX, Pathing.SignOf(accX));
            Inc(camX, Pathing.SignOf(accX));
            accX := 0;
          end;
          if Abs(accY) = 3 then begin
            Inc(startY, Pathing.SignOf(accY));
            Inc(camY, Pathing.SignOf(accY));
            accY := 0;
          end;
          Dec(n);
        end;
      until done;
    end else begin
      lastPass := True;
      if not CbtMap.ViewCoordsValid(endX - GDVars.arenaPtr^.ox, endY - GDVars.arenaPtr^.oy) then
        CbtMap.ScrollView(endX, endY, 3, C_Dir.CENTER);
      pixX := (endX - GDVars.arenaPtr^.ox) * 3;
      pixY := (endY - GDVars.arenaPtr^.oy) * 3;
      Blit.BlitTileClipped(pixX, pixY, frame, 5, GDVars.moveIconSheet, GDVars.viewImageBuf);
      if pace > 0 then begin
        Blit.FlushView;
        Delay(pace);
        Blit.BlitTileClipped(pixX, pixY, 0, 0, GDVars.iconSaveBuf, GDVars.viewImageBuf);
      end;
    end;
  until lastPass;
  Blit.FlushView;
end;

procedure PrintNameStringAnim(cr: Pointer; effect: Boolean; s: String);
var
  { flash x = grid cell x * 3 }
  gx: ShortInt;
  { flash y = grid cell y * 3 }
  gy: ShortInt;
  { icon sheet cell, 21 or 23 }
  cell: Byte;
  { facing frame index, 0..3 }
  j: Byte;
  { repetition index }
  i: Byte;
  { flash repetitions after the first }
  reps: Byte;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    if effect then
      cell := 21
    else
      cell := 23;
    CharHlp.BuildIconFacings(cell);
    if not CbtMap.CombatIconVisible(cr, 1) then
      CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 3, C_Dir.CENTER);
    if effect then
      Music.SendSoundCommand(GDConsts.soundIds[6])
    else
      Music.SendSoundCommand(GDConsts.soundIds[9]);
    CharHlp.PrintCreatureMessage(cr, s, 10, False);
    if effect then
      reps := GDVars.vmBand.zone0^.gameDelay
    else
      reps := 0;
    gx := GDVars.arenaGridX[CbtMap.CombatSlot(cr)] * 3;
    gy := GDVars.arenaGridY[CbtMap.CombatSlot(cr)] * 3;
    for i := 0 to reps do
      for j := 0 to 3 do begin
        Blit.BlitTileClipped(gx, gy, j, 5, GDVars.moveIconSheet, GDVars.viewImageBuf);
        Blit.FlushView;
        Delay(70);
        Blit.BlitTileClipped(gx, gy, 0, 0, GDVars.iconSaveBuf, GDVars.viewImageBuf);
      end;
    Blit.FlushView;
    if reps = 0 then
      TextRend.PauseOnly;
  end else
    CharHlp.PrintCreatureMessage(cr, s, 10, True);
end;

function HasEffect(cr: Pointer; id: Byte; var eff: Pointer): Boolean;
var
  found: Boolean;
begin
  found := False;
  eff := Types.PCharRecord(cr)^.effects;
  while (eff <> nil) and not found do begin
    if Types.PEffectRec(eff)^.id = id then
      found := True
    else
      eff := Types.PEffectRec(eff)^.next;
  end;
  HasEffect := found;
end;

procedure InflictDamage(cr: Pointer; dmg: Word);
var
  { hp left after the hit }
  remain: Byte;
  { damage past 0 hp }
  over: Word;
begin
  over := 0;
  remain := 0;
  if Types.PCharRecord(cr)^.hpCur >= dmg then
    remain := Types.PCharRecord(cr)^.hpCur - dmg
  else
    over := dmg - Types.PCharRecord(cr)^.hpCur;
  if (over > 9) or ((remain = 0) and (Types.PCharRecord(cr)^.status = C_Status.ANIMATED)) then
    Types.PCharRecord(cr)^.status := C_Status.DEAD_STATUS
  else if over > 0 then begin
    Types.PCharRecord(cr)^.status := C_Status.DYING;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then
      Types.PCharRecord(cr)^.combatAddr^.overkill := over;
  end else if remain = 0 then
    Types.PCharRecord(cr)^.status := C_Status.UNCONSCIOUS;
  if not (Types.PCharRecord(cr)^.status in [C_Status.OKAY, C_Status.ANIMATED]) then begin
    Types.PCharRecord(cr)^.inPlay := 0;
    Types.PCharRecord(cr)^.hpCur := 0;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
      Dec(GDVars.teamCount[Types.PCharRecord(cr)^.side]);
      Types.PCharRecord(cr)^.combatAddr^.initiative := 0;
    end;
  end else
    Types.PCharRecord(cr)^.hpCur := remain;
end;

procedure AnnounceHealStatus(cr: Pointer);
var
  s: Types.TStr40;
begin
  if Types.PCharRecord(cr)^.hpCur = Types.PCharRecord(cr)^.hpMax then
    s := 'is fully healed'
  else
    s := 'is partially healed';
  CharHlp.PrintCreatureMessage(cr, s, 10, True);
  if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
    CharHlp.DisplayRoster(cr, cr = GDVars.currentChar);
end;

function EnemyTeam(cr: Pointer): ShortInt;
begin
  if Types.PCharRecord(cr)^.side = 0 then
    EnemyTeam := 1
  else
    EnemyTeam := 0;
end;

procedure CountTeams;
var
  p: Types.PCharRecord;
begin
  GDVars.teamCount[0] := 0;
  GDVars.teamCount[1] := 0;
  p := GDVars.creatureListHead;
  while p <> nil do begin
    if p^.inPlay <> 0 then
      Inc(GDVars.teamCount[p^.side]);
    p := p^.next;
  end;
end;

function CountTargets(cr: Pointer; range: Byte; ownTeam: Boolean): Byte;
var
  { creatures in the ranked list }
  n: Byte;
  { creatures kept; later the swap temporary }
  cnt: Byte;
  i: Byte;
  { HasEffect's out-node, not used }
  eff: Pointer;
  { the swap is made }
  done: Boolean;
  { the wanted side }
  want: ShortInt;
begin
  Pathing.BuildTargetList(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), range, 255, CbtMap.GetIconSize(cr));
  n := GDVars.rankedTargetCount;
  cnt := 0;
  if ownTeam then
    want := Types.PCharRecord(cr)^.side
  else
    want := CharHlp.EnemyTeam(cr);
  if n > 0 then begin
    for i := 1 to n do
      if GDVars.slotCreatures[GDVars.rankedTargets[i].ent]^.side = want then begin
        Inc(cnt);
        Move(GDVars.rankedTargets[i], GDVars.rankedTargets[cnt], SizeOf(GDVars.rankedTargets[i]));
      end;
    n := cnt;
    GDVars.rankedTargetCount := cnt;
  end;
  CountTargets := n;
  for i := 1 to n do
    GDVars.potentialTargets[i] := GDVars.rankedTargets[i].ent;
  if CharHlp.HasEffect(cr, C_Effect.BLUE_DRAGON_BREATH, eff) then begin
    i := 1;
    done := False;
    while (i <= n) and not done do begin
      if GDVars.slotCreatures[GDVars.potentialTargets[i]] = GDVars.preferredTarget then begin
        cnt := GDVars.potentialTargets[1];
        GDVars.potentialTargets[1] := GDVars.potentialTargets[i];
        GDVars.potentialTargets[i] := cnt;
        done := True;
      end;
      Inc(i);
    end;
  end;
end;

function CalcDistance(cr, other: Pointer): Byte;
var
  { the caller's ranked list }
  saved: array[1..255] of Types.TApproachResult;
  i: Byte;
begin
  Move(GDVars.rankedTargets, saved, SizeOf(GDVars.rankedTargets));
  GDVars.arenaPtr^.noHeight := 1;
  Pathing.BuildTargetList(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 255, 255, CbtMap.GetIconSize(cr));
  GDVars.arenaPtr^.noHeight := 0;
  i := 1;
  while (GDVars.slotCreatures[GDVars.rankedTargets[i].ent] <> other) and (i < GDVars.rankedTargetCount) do
    Inc(i);
  CalcDistance := GDVars.rankedTargets[i].cost shr 1;
  Move(saved, GDVars.rankedTargets, SizeOf(GDVars.rankedTargets));
end;

function EndActions(cr: Pointer): Boolean;
begin
  Types.PCharRecord(cr)^.combatAddr^.initiative := 0;
  Types.PCharRecord(cr)^.combatAddr^.spellCast := 0;
  Types.PCharRecord(cr)^.combatAddr^.guarding := 0;
  Types.PCharRecord(cr)^.combatAddr^.movement := 0;
  EndActions := True;
end;

function Guard(cr: Pointer): Boolean;
begin
  Guard := CharHlp.EndActions(cr);
  if Types.PCharRecord(cr)^.combatAddr^.turned = 0 then begin
    Types.PCharRecord(cr)^.combatAddr^.guarding := 1;
    CharHlp.PrintBottomLine('Guarding');
  end;
end;

function GetCasterLevel(spell: Byte; capped: Boolean): Byte;
var
  lvl: ShortInt;
  alt: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  bonusLevels: array[1..2] of Byte;
begin
  if (ClassCal.EffectiveClassLevel(GDVars.currentChar, C_Class.CLERIC) = 0) and
      (ClassCal.EffectiveClassLevel(GDVars.currentChar, C_Class.MAGE) = 0) and
      (ClassCal.EffectiveClassLevel(GDVars.currentChar, C_Class.RANGER) < 8) then
    lvl := 6
  else
    case GDConsts.spellTable[spell].castClass of
      C_Spell.CLERIC_LIST:
        begin
          lvl := ClassCal.EffectiveClassLevel(GDVars.currentChar, C_Class.CLERIC);
          alt := ClassCal.EffectiveClassLevel(GDVars.currentChar, C_Class.PALADIN);
          if lvl < alt then lvl := alt;
        end;
      C_Spell.DRUID_LIST:
        begin
          lvl := ClassCal.EffectiveClassLevel(GDVars.currentChar, C_Class.RANGER) - 7;
          if lvl < 0 then lvl := 0;
        end;
      C_Spell.MAGIC_USER_LIST:
        begin
          lvl := ClassCal.EffectiveClassLevel(GDVars.currentChar, C_Class.MAGE);
          alt := ClassCal.EffectiveClassLevel(GDVars.currentChar, C_Class.RANGER) - 8;
          if lvl < alt then lvl := alt;
        end;
      C_Spell.ITEM_LIST:
        lvl := 12;
    end;
  if (GDVars.castFromItem <> 0) and (GDConsts.spellTable[spell].castClass <> C_Spell.ITEM_LIST) then
    lvl := 6;
  if capped and (lvl > 31) then
    lvl := 31;
  GetCasterLevel := lvl;
end;

procedure DisplayNoncombatInterface;
begin
  GDVars.mapRedrawPending := 1;
  case GDVars.interfaceState of
    C_Ifc.MAIN_MENU:
      Border.DrawWindowFrame(0);
    C_Ifc.IN_VAULT, C_Ifc.IN_SHOP:
      begin
        if GDVars.storeFrameGate <> 0 then
          Border.DrawExploreFrame;
        Portrait.DisplayImageBuf(3, 3, True, 0);
        CharHlp.DisplayParty(GDVars.currentChar);
        CharHlp.PrintMiscInfo;
      end;
    C_Ifc.CAMPING:
      begin
        Border.DrawExploreFrame;
        Portrait.LoadAnimation('PIC', 128, 0);
        Portrait.DisplayImageBuf(3, 3, True, 0);
        CharHlp.DisplayParty(GDVars.currentChar);
        CharHlp.PrintMiscInfo;
        GDVars.mainPalReload := True;
      end;
    C_Ifc.DUNGEON:
      begin
        Border.DrawExploreFrame;
        MapView.DisplayMapView;
        CharHlp.DisplayParty(GDVars.currentChar);
        CharHlp.PrintMiscInfo;
        GDVars.panelRestorePending := 0;
      end;
    C_Ifc.AREA_MAP:
      if (GDVars.picArcId <> 9) and (GDVars.vmBand.zone0^.mapPaneEnabled = 1) then
        MapView.DisplayMapView;
    C_Ifc.LOOT:
      begin
        Border.DrawExploreFrame;
        Portrait.LoadAnimation('PIC', 129, 0);
        Portrait.DisplayImageBuf(3, 3, True, 0);
        CharHlp.DisplayParty(GDVars.currentChar);
        GDVars.mainPalReload := True;
      end;
  end;
end;

procedure PrintMiscInfo;
var
  { party map position }
  x: Byte;
  y: Byte;
  { two-digit hours }
  hrs: String[2];
  { two-digit minutes }
  mins: String[2];
  { the assembled line }
  info: Types.TStr40;
begin
  if GDVars.interfaceState = C_Ifc.AREA_MAP then Exit;
  info := '';
  x := Byte(GDVars.mapState.x);
  y := Byte(GDVars.mapState.y);
  hrs := CharHlp.Uint8Str(GDVars.vmBand.zone0^.clock[3]);
  if Length(hrs) < 2 then
    hrs := '0' + hrs;
  mins := CharHlp.Uint8Str(GDVars.vmBand.zone0^.clock[2] * 10 + GDVars.vmBand.zone0^.clock[1]);
  if Length(mins) < 2 then
    mins := '0' + mins;
  if GDVars.vmBand.zone0^.areaRestricted = 0 then
    info := CharHlp.Uint8Str(x) + ',' + CharHlp.Uint8Str(y) + ' ';
  info := info + GDConsts.directionNames[GDVars.mapState.facing] + ' ';
  info := info + hrs + ':' + mins;
  if GDVars.interfaceState = C_Ifc.CAMPING then
    info := info + ' camping'
  else if GDVars.vmBand.zone0^.travelFlags and 1 > 0 then
    info := info + ' search';
  Border.ClearBox(17, 15, 38, 15);
  TextRend.DisplayString(17, 15, 10, 0, info);
end;

procedure DisplayCombatInterface;
begin
  CbtMap.SetNoncombatPalette;
  Border.DrawCombatFrame;
  CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, $FF, C_Dir.CENTER);
end;

function HasRangedWeapon(cr: Pointer): Boolean;
begin
  if (Types.PCharRecord(cr)^.equipped[C_Equip.WEAPON] <> nil) and
      (GDVars.baseItemTable[Types.PCharRecord(cr)^.equipped[C_Equip.WEAPON]^.definition.itemType].range > 1) then
    HasRangedWeapon := True
  else
    HasRangedWeapon := False;
end;

function HasThrowableWeapon(cr: Pointer): Boolean;
begin
  HasThrowableWeapon := CharHlp.HasRangedWeapon(cr) and
    Boolean((GDVars.baseItemTable[Types.PCharRecord(cr)^.equipped[C_Equip.WEAPON]^.definition.itemType].props and
             C_Item.THROWABLE) = C_Item.THROWABLE);
end;

function FindDamagingRangedWeapon(cr: Pointer; var sel: Pointer): Boolean;
var
  w: Types.PItemRec;
  props: Byte;
begin
  FindDamagingRangedWeapon := False;
  w := Types.PCharRecord(cr)^.equipped[C_Equip.WEAPON];
  sel := nil;
  props := 0;
  if w <> nil then begin
    props := GDVars.baseItemTable[w^.definition.itemType].props;
    if (props and C_Item.THROWN) <> 0 then
      sel := w;
    if (props and C_Item.FIRES_AMMO) <> 0 then begin
      if (props and C_Item.USES_ARROWS) <> 0 then
        sel := Types.PCharRecord(cr)^.equipped[C_Equip.ARROW];
      if (props and C_Item.USES_QUARRELS) <> 0 then
        sel := Types.PCharRecord(cr)^.equipped[C_Equip.BOLT];
    end;
  end;
  if (sel <> nil) or (props = $0A) then
    FindDamagingRangedWeapon := True;
end;

function BandageDying(apply: Boolean): Boolean;
var
  cr: Types.PCharRecord;
  found: Boolean;
begin
  found := False;
  cr := GDVars.creatureListHead;
  while cr <> nil do begin
    if (cr^.combatAddr^.notPcNpc = 0) and (cr^.side = 0) and (cr^.status = C_Status.DYING) then begin
      found := True;
      if apply then begin
        cr^.status := C_Status.UNCONSCIOUS;
        cr^.combatAddr^.overkill := 0;
        CharHlp.PrintCreatureMessage(cr, 'is bandaged', 10, True);
        apply := False;
      end;
    end;
    cr := cr^.next;
  end;
  BandageDying := found;
end;

procedure SelectChar(query: Types.TStr40; addExit: Boolean; mode: Byte; var sel: Pointer);
var
  ch2: Char;
  ch: Char;
  { Unused in this version; see the other implementations of this routine. }
  reinterpret: Byte;
  anim: Boolean;
  p: Pointer;
  savedPartyClickMode: Byte;
  savedCombatClickMode: Byte;
begin
  savedPartyClickMode := GDVars.mouseMenuMode;
  GDVars.charSelectMode := mode;
  GDVars.selectStartChar := GDVars.currentChar;
  ch := #$FF;
  savedCombatClickMode := GDVars.clickInputMode;
  GDVars.clickInputMode := 0;
  while (ch >= #2) and (ch <> C_Keys.ESCAPE) do begin
    CharHlp.DisplayParty(sel);
    if (GDVars.interfaceState = C_Ifc.CAMPING) or (GDVars.interfaceState = C_Ifc.LOOT) then
      anim := True
    else
      anim := False;
    if GDVars.interfaceState = C_Ifc.MAIN_MENU then
      GDVars.mouseMenuMode := 1;
    if addExit then
      MenuCore.ResetMenuSlots(1)
    else
      MenuCore.ResetMenuSlots(0);
    ch := MenuCore.MenuHorizontal(query + ' ', GDConsts.selectExitMenu, True, anim);
    GDVars.mouseMenuMode := savedPartyClickMode;
    p := sel;
    if GDVars.extendedKeyFlag then begin
      ch2 := ch;
      case ch2 of
        C_Keys.ESCAPE:
          if addExit then
            p := nil;
        C_Keys.DOWN:
          begin
            p := Types.PCharRecord(p)^.next;
            if p = nil then
              p := GDVars.creatureListHead;
          end;
        C_Keys.UP:
          if GDVars.keyFromMouse <> 0 then begin
            if GDVars.charSelectMode <> 0 then
              p := GDVars.selectStartChar
            else begin
              p := GDVars.clickedChar;
              GDVars.currentChar := GDVars.clickedChar;
            end;
          end else begin
            p := GDVars.creatureListHead;
            if sel <> GDVars.creatureListHead then
              while Types.PCharRecord(p)^.next <> sel do
                p := Types.PCharRecord(p)^.next
            else
              while Types.PCharRecord(p)^.next <> nil do
                p := Types.PCharRecord(p)^.next;
          end;
      end;
    end else begin
      if addExit and (ch = #1) then
        p := nil;
    end;
    sel := p;
  end;
  GDVars.clickInputMode := savedCombatClickMode;
  GDVars.charSelectMode := 0;
end;

function DirTowardTarget(creature, other: Pointer): Byte;
var
  dir: Byte;
  found: Boolean;
  x1: Integer;
  y1: Integer;
  x2: Integer;
  y2: Integer;
  deltaX: Integer;
  deltaY: Integer;
begin
  x1 := CbtMap.CombatCellX(creature);
  y1 := CbtMap.CombatCellY(creature);
  x2 := CbtMap.CombatCellX(other);
  y2 := CbtMap.CombatCellY(other);
  deltaX := abs(x2 - x1);
  deltaY := abs(y2 - y1);
  dir := 0;
  found := False;
  while not found do begin
    case dir of
      0: found := (y2 <= y1) and (deltaX * 618 div 256 <= deltaY);
      2: found := (x2 >= x1) and (deltaX * 106 div 256 >= deltaY);
      4: found := (y2 >= y1) and (deltaX * 618 div 256 <= deltaY);
      6: found := (x2 <= x1) and (deltaX * 106 div 256 >= deltaY);
      1: found := (y2 < y1) and (x2 > x1) and (deltaX * 618 div 256 >= deltaY) and (deltaX * 106 div 256 <= deltaY);
      3: found := (y2 > y1) and (x2 > x1) and (deltaX * 618 div 256 >= deltaY) and (deltaX * 106 div 256 <= deltaY);
      5: found := (y2 > y1) and (x2 < x1) and (deltaX * 618 div 256 >= deltaY) and (deltaX * 106 div 256 <= deltaY);
      7: found := (y2 < y1) and (x2 < x1) and (deltaX * 618 div 256 >= deltaY) and (deltaX * 106 div 256 <= deltaY);
    end;
    if not found then Inc(dir);
  end;
  DirTowardTarget := dir;
end;

function CanLevelUp(cr: Pointer): Boolean;
var
  capped: Boolean;
  found: Boolean;
  i: ShortInt;
  lvl: Byte;
  needed: LongInt;
begin
  found := False;
  i := 0;
  while (i <= C_Class.THIEF) and not found do begin
    if Types.PCharRecord(cr)^.classLevels[i] > 0 then
      if Types.PCharRecord(cr)^.classLevels[i] < 40 then begin
        lvl := Types.PCharRecord(cr)^.classLevels[i];
        needed := ClassCal.XpForLevel(Types.PCharRecord(cr), lvl + 1, i);
        capped := GDConsts.raceCaps[Types.PCharRecord(cr)^.race, i] <= lvl;
        if not capped then
          with Types.PCharRecord(cr)^ do
            case race of
              C_Race.DWARF:
                if (i = C_Class.FIGHTER) and
                    (((lvl = 8) and (stats[C_Stat.STRENGTH].cur = 17)) or
                     ((lvl = 7) and (stats[C_Stat.STRENGTH].cur < 17))) then
                  capped := True;
              C_Race.ELF:
                begin
                  if (i = C_Class.FIGHTER) and
                      (((lvl = 6) and (stats[C_Stat.STRENGTH].cur = 17)) or
                       ((lvl = 5) and (stats[C_Stat.STRENGTH].cur < 17))) then
                    capped := True;
                  if (i = C_Class.MAGE) and
                      (((lvl = 9) and (stats[C_Stat.INTELLIGENCE].cur < 17)) or
                       ((lvl = 10) and (stats[C_Stat.INTELLIGENCE].cur = 17))) then
                    capped := True;
                end;
              C_Race.GNOME:
                begin
                  if (i = C_Class.FIGHTER) and (lvl = 5) and (stats[C_Stat.STRENGTH].cur < 18) then
                    capped := True;
                  if (i = C_Class.CLERIC) and (lvl >= 7) then
                    capped := True;
                end;
              C_Race.HALF_ELF:
                begin
                  if ((i = C_Class.FIGHTER) or (i = C_Class.RANGER)) and
                      (((lvl = 7) and (stats[C_Stat.STRENGTH].cur = 17)) or
                       ((lvl = 6) and (stats[C_Stat.STRENGTH].cur < 17))) then
                    capped := True;
                  if (i = C_Class.MAGE) and
                      (((lvl = 7) and (stats[C_Stat.INTELLIGENCE].cur = 17)) or
                       ((lvl = 6) and (stats[C_Stat.INTELLIGENCE].cur < 17))) then
                    capped := True;
                end;
              C_Race.HALFLING:
                if (i = C_Class.FIGHTER) and
                    (((lvl = 5) and (stats[C_Stat.STRENGTH].cur = 17)) or
                     ((lvl = 4) and (stats[C_Stat.STRENGTH].cur < 17))) then
                  capped := True;
            end;
        found := (Types.PCharRecord(cr)^.experience >= needed) and (needed > 0) and not capped;
      end;
    Inc(i);
  end;
  CanLevelUp := found;
end;

procedure ScatterCombatIcon(step, cell, cue: Byte);
var
  rnd: Byte;
  stepR: Real;
  angle: Real;
  count: Byte;
  k: Byte;
  sub: Byte;
  flag: Byte;
  savedScatterX: ShortInt;
  savedScatterY: ShortInt;
  xOff: ShortInt;
  yOff: ShortInt;
  yBase: ShortInt;
  xBase: ShortInt;
begin
  CbtMap.ScrollView(GDVars.gTargetX, GDVars.gTargetY, 255, C_Dir.CENTER);
  savedScatterX := GDVars.gTargetX;
  savedScatterY := GDVars.gTargetY;
  Music.SendSoundCommand(cue);
  CharHlp.CopyIconFacing(cell, 0, 0, False);
  CharHlp.CopyIconFacing(cell, 0, 1, True);
  CharHlp.CopyIconFacing(cell, 1, 2, False);
  CharHlp.CopyIconFacing(cell, 1, 3, True);
  flag := 1;
  xBase := 0;
  yBase := 0;
  if savedScatterX < 3 then
    xBase := (savedScatterX - 3) * 3
  else if savedScatterX > 46 then
    xBase := ((savedScatterX - 49) + 3) * 3;
  if savedScatterY < 3 then
    yBase := (savedScatterY - 3) * 3
  else if savedScatterY > 21 then
    yBase := ((savedScatterY - 24) + 3) * 3;
  count := (step * 3) + 1;
  for k := 1 to count do begin
    stepR := k;
    for sub := (k * 2) - 2 downto 0 do begin
      angle := Random * 2.0 * Pi;
      xOff := xBase + Trunc(Cos(angle) * stepR);
      yOff := yBase + Trunc(Sin(angle) * stepR);
      if (xOff >= -9) and (xOff <= 9) and (yOff >= -9) and (yOff <= 9) then begin
        rnd := Random(4);
        Blit.BlitTileClipped(xOff + 9, yOff + 9, rnd, flag, GDVars.moveIconSheet, GDVars.viewImageBuf);
      end;
    end;
    Blit.FlushView;
  end;
  CbtMap.ScrollView(GDVars.gTargetX, GDVars.gTargetY, 255, C_Dir.CENTER);
end;

function ClassConAdj(cr: Pointer; cls: Byte): ShortInt;
var
  adj: ShortInt;
begin
  case Types.PCharRecord(cr)^.stats[C_Stat.CONSTITUTION].cur of
    3: adj := -2;
    4..6: adj := -1;
    7..14: adj := 0;
    15: adj := 1;
    16: adj := 2;
    17..19:
      if (cls = C_Class.FIGHTER) or (cls = C_Class.RANGER) or (cls = C_Class.PALADIN) then
        adj := Types.PCharRecord(cr)^.stats[C_Stat.CONSTITUTION].cur - 14
      else
        adj := 2;
  end;
  ClassConAdj := adj;
end;

procedure ClearEncounterState;
var
  next: Pointer;
begin
  GDVars.turnUndeadLimit := 0;
  GDVars.addedMonsterCount := 0;
  GDVars.monstersLoaded := 0;
  GDVars.monIconSlot := 8;
  GameIo.ZeroFill(GDVars.moneyPool, SizeOf(GDVars.moneyPool));
  while GDVars.treasureList <> nil do begin
    next := GDVars.treasureList^.next;
    GameIo.FreeSlot(GDVars.treasureList);
    GDVars.treasureList := next;
  end;
  GDVars.treasureList := nil;
end;

procedure BuildIconFacingsDir(dir, cell: Byte);
begin
  if Odd(dir) then begin
    if (dir = 3) or (dir = 5) then
      CharHlp.CopyIconFacing(cell + 1, 1, 0, dir = 5)
    else
      CharHlp.CopyIconFacing(cell + 1, 0, 0, dir = 7);
  end else
    CharHlp.CopyIconFacing(cell + (dir mod 4), dir div 4, 0, False);
end;

begin
end.
