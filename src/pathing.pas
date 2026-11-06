{ Straight-line geometry on the combat grid: walking a line cell by cell, tracing line of sight over terrain heights,
  testing 90-degree facing wedges, and ranking the combatants that can be seen from a position. }
{$O+,F+,S-,R-,V-,B-,I-}
unit Pathing;

interface

uses CbtMap, Types, GDConsts, GDVars, C_Dir;

{ Gives the sign of a number.
  @param(x The number.)
  @returns(-1, 0 or 1.) }
function SignOf(x: Integer): Integer;

{ Starts a line walk from its start point to its end point: sets the current point, the deltas, the step signs, and zero
  error and distance.
  @param(w The walk, with its start and end points set.) }
procedure PathFind(var w: Types.TLineWalk);

{ Takes one Bresenham step along a line walk, adding 2 to the doubled distance for a straight step and 3 for a diagonal,
  and records the step's direction.
  @param(w The walk, started by PathFind.)
  @returns(False, without moving, once the end point is reached.) }
function NextPathStep(var w: Types.TLineWalk): Boolean;

{ Tells whether a direction leads from one arena cell toward another: the target must lie in the 90-degree cone around
  the cell one step away in that direction. A target on the start cell or on the cell one step away always counts.
  @param(x1 Arena column of the start cell.)
  @param(y1 Arena row of the start cell.)
  @param(x2 Arena column of the target cell.)
  @param(y2 Arena row of the target cell.)
  @param(facing The direction, 0 to 7; 8 or 255 for any direction, which always counts.)
  @returns(True when the direction leads toward the target; False when a cell lies outside the arena. Note: a direction
    from 9 to 254 matches no case and leaves the result unset.) }
function IsDirToward(x1, y1, x2, y2: ShortInt; facing: Byte): Boolean;

{ Walks the line of sight from a source cell to a target cell through the arena. A second walk carries the eye height
  level along the line from the source cell, and the trace stops where a cell's obstacle stands taller than that, unless
  the arena has no heights, or where the range runs out. Note: the coordinates are not range-checked before indexing the
  map.
  @param(x0 Source column.)
  @param(y0 Source row.)
  @param(x1 In: target column. Out: the stopping column when the walk stops short.)
  @param(y1 In: target row. Out: the stopping row when the walk stops short.)
  @param(distance In: the range in cells. Out: the doubled distance walked.)
  @returns(True when the target was reached.) }
function WalkLine(x0, y0: ShortInt; var x1, y1: ShortInt; var distance: Word): Boolean;

{ Fills the ranked target list with each combatant in the arena that a cell of a body of the given size at the given
  cell can see within range and in the facing wedge. For each combatant the closest such pair of footprint cells counts,
  with its doubled distance and a direction toward it (the facing itself when it is 0 to 7, else the first direction
  whose wedge holds the best pair). The list is then sorted nearest first.
  @param(x Column of the body.)
  @param(y Row of the body.)
  @param(maxDistance The range in cells.)
  @param(facing The direction, 0 to 7, or 8 or more for any.)
  @param(sizeCode The body's size.) }
procedure BuildTargetList(x, y: ShortInt; maxDistance: Word; facing, sizeCode: Byte);

implementation

function SignOf(x: Integer): Integer;
begin
  if x < 0 then
    SignOf := -1
  else if x > 0 then
    SignOf := 1
  else
    SignOf := 0;
end;

{ Sorts the target list nearest first; on equal distance a lower direction goes first unless it is diagonal and the
  other is not. }
procedure SortTargets;
var
  i: Byte;
  j: Byte;
  cj: Byte;
  ci: Byte;
  tmp: Types.TApproachResult;
begin
  if GDVars.rankedTargetCount <= 1 then Exit;
  for i := 1 to GDVars.rankedTargetCount - 1 do
    for j := i + 1 to GDVars.rankedTargetCount do begin
      ci := GDVars.rankedTargets[i].face;
      cj := GDVars.rankedTargets[j].face;
      if (GDVars.rankedTargets[j].cost < GDVars.rankedTargets[i].cost) or
          ((GDVars.rankedTargets[j].cost = GDVars.rankedTargets[i].cost) and (cj < ci) and
           (cj mod 2 <= ci mod 2)) then begin
        tmp := GDVars.rankedTargets[i];
        GDVars.rankedTargets[i] := GDVars.rankedTargets[j];
        GDVars.rankedTargets[j] := tmp;
      end;
    end;
end;

procedure PathFind(var w: Types.TLineWalk);
begin
  with w do begin
    currentX := x0;
    currentY := y0;
    deltaX := Abs(x1 - x0);
    deltaY := Abs(y1 - y0);
    stepX := Pathing.SignOf(x1 - x0);
    stepY := Pathing.SignOf(y1 - y0);
    errorTerm := 0;
    movementCost := 0;
  end;
end;

function NextPathStep(var w: Types.TLineWalk): Boolean;
var
  stepCodeX: ShortInt;
  stepCodeY: ShortInt;
begin
  NextPathStep := False;
  stepCodeX := 1;
  stepCodeY := 1;
  with w do begin
    if deltaX >= deltaY then begin
      if currentX <> x1 then begin
        Inc(currentX, stepX);
        stepCodeX := stepX + 1;
        Inc(errorTerm, deltaY);
        Inc(errorTerm, deltaY);
        Inc(movementCost);
        Inc(movementCost);
        if errorTerm >= deltaX then begin
          Dec(errorTerm, deltaX);
          Dec(errorTerm, deltaX);
          Inc(currentY, stepY);
          stepCodeY := stepY + 1;
          Inc(movementCost);
        end;
        NextPathStep := True;
      end;
    end else begin
      if currentY <> y1 then begin
        Inc(currentY, stepY);
        stepCodeY := stepY + 1;
        Inc(errorTerm, deltaX);
        Inc(errorTerm, deltaX);
        Inc(movementCost);
        Inc(movementCost);
        if errorTerm >= deltaY then begin
          Dec(errorTerm, deltaY);
          Dec(errorTerm, deltaY);
          Inc(currentX, stepX);
          stepCodeX := stepX + 1;
          Inc(movementCost);
        end;
        NextPathStep := True;
      end;
    end;
    direction := GDConsts.directionByStep[stepCodeY, stepCodeX];
  end;
end;

function WalkLine(x0, y0: ShortInt; var x1, y1: ShortInt; var distance: Word): Boolean;
var
  sightWalk: Types.TLineWalk;
  heightWalk: Types.TLineWalk;
  finished: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  ignoredHeightStep: Boolean;
  costLimit: Word;
begin
  costLimit := distance * 2 + 1;
  sightWalk.x0 := x0;
  sightWalk.y0 := y0;
  sightWalk.x1 := x1;
  sightWalk.y1 := y1;
  Pathing.PathFind(sightWalk);
  heightWalk.x0 := 0;
  heightWalk.y0 := GDConsts.terrainTable[GDVars.arenaPtr^.cells[y0, x0]].cellHeight;
  if sightWalk.deltaX > sightWalk.deltaY then
    heightWalk.x1 := sightWalk.deltaX
  else
    heightWalk.x1 := sightWalk.deltaY;

  { Note: the end height is read from the start cell, not the target, so the eye height stays level along the line. }
  heightWalk.y1 := GDConsts.terrainTable[GDVars.arenaPtr^.cells[y0, x0]].cellHeight;
  Pathing.PathFind(heightWalk);
  finished := False;
  repeat
    if ((GDVars.arenaPtr^.noHeight = 0) and
        (GDConsts.terrainTable[GDVars.arenaPtr^.cells[sightWalk.currentY,
                                             sightWalk.currentX]].obstacleHeight > heightWalk.currentY)) or
                                                  (sightWalk.movementCost > costLimit) then begin
      x1 := sightWalk.currentX;
      y1 := sightWalk.currentY;
      distance := sightWalk.movementCost;
      WalkLine := False;
      Exit;
    end;
    ignoredHeightStep := Pathing.NextPathStep(heightWalk);
    finished := not Pathing.NextPathStep(sightWalk);
  until finished;
  distance := sightWalk.movementCost;
  WalkLine := True;
end;

function IsDirToward(x1, y1, x2, y2: ShortInt; facing: Byte): Boolean;
var
  facingX: ShortInt;
  facingY: ShortInt;
begin
  if (x1 < 0) or (x1 > 49) or (y1 < 0) or (y1 > 24) or (x2 < 0) or (x2 > 49) or (y2 < 0) or
      (y2 > 24) then begin
    IsDirToward := False;
    Exit;
  end;
  if facing = $FF then
    facing := C_Dir.CENTER;
  facingX := x1 + GDConsts.dirDeltaX[facing];
  facingY := y1 + GDConsts.dirDeltaY[facing];
  if ((x1 = x2) and (y1 = y2)) or ((facingX = x2) and (facingY = y2)) then begin
    IsDirToward := True;
    Exit;
  end;
  case facing of
    C_Dir.NORTH: IsDirToward := ((x2 >= facingX) and (y2 <= (facingX - x2) + facingY)) or
      ((x2 <= facingX) and (y2 <= (x2 - facingX) + facingY));
    C_Dir.NORTHEAST: IsDirToward := ((x2 >= facingX) and (y2 <= (facingX - x2) + facingY)) or
      ((x2 >= (facingX + facingY) - y2) and (y2 <= facingY));
    C_Dir.EAST: IsDirToward := ((x2 >= (facingX + facingY) - y2) and (y2 <= facingY)) or
      ((x2 >= (facingX + y2) - facingY) and (y2 >= facingY));
    C_Dir.SOUTHEAST: IsDirToward := ((x2 >= (facingX + y2) - facingY) and (y2 >= facingY)) or
      ((x2 >= facingX) and (y2 >= (x2 - facingX) + facingY));
    C_Dir.SOUTH: IsDirToward := ((x2 >= facingX) and (y2 >= (x2 - facingX) + facingY)) or
      ((x2 <= facingX) and (y2 >= (facingX - x2) + facingY));
    C_Dir.SOUTHWEST: IsDirToward := ((x2 <= facingX) and (y2 >= (facingX - x2) + facingY)) or
      ((x2 <= (facingX + facingY) - y2) and (y2 >= facingY));
    C_Dir.WEST: IsDirToward := ((x2 <= (facingX + facingY) - y2) and (y2 >= facingY)) or
      ((x2 <= (facingX + y2) - facingY) and (y2 <= facingY));
    C_Dir.NORTHWEST: IsDirToward := ((x2 <= (facingX + y2) - facingY) and (y2 <= facingY)) or
      ((x2 <= facingX) and (y2 <= (x2 - facingX) + facingY));
    C_Dir.CENTER: IsDirToward := True;
  end;
end;

procedure BuildTargetList(x, y: ShortInt; maxDistance: Word; facing, sizeCode: Byte);
var
  i: Byte;
  d: Byte;
  a: Byte;
  b: Byte;
  bestTargetCell: Byte;
  bestEntityCell: Byte;
  wasFound: Boolean;
  tx: ShortInt;
  ty: ShortInt;
  footprintX: ShortInt;
  footprintY: ShortInt;
  targetX: array[0..5] of ShortInt;
  targetY: array[0..5] of ShortInt;
  entityX: array[0..5] of ShortInt;
  entityY: array[0..5] of ShortInt;
  traceDistance: Word;
  bestDistance: Word;
begin
  for a := 0 to 5 do
    if CbtMap.FootprintCell(sizeCode, a, footprintX, footprintY) then begin
      targetX[a] := x + footprintX;
      targetY[a] := y + footprintY;
    end else
      targetX[a] := -1;
  GDVars.rankedTargetCount := 0;
  for i := 1 to GDVars.arenaCount do begin
    if GDVars.arenaSlots[i].sizeCode > 0 then begin
      wasFound := False;
      bestDistance := 255;
      for b := 0 to 5 do
        if CbtMap.FootprintCell(GDVars.arenaSlots[i].sizeCode, b, footprintX, footprintY) then begin
          entityX[b] := GDVars.arenaSlots[i].x + footprintX;
          entityY[b] := GDVars.arenaSlots[i].y + footprintY;
        end else
          entityX[b] := -1;

      for b := 0 to 5 do
        if entityX[b] >= 0 then
          for a := 0 to 5 do
            if targetX[a] >= 0 then
              if Pathing.IsDirToward(targetX[a], targetY[a], entityX[b], entityY[b], facing) then begin
                tx := entityX[b];
                ty := entityY[b];
                traceDistance := maxDistance;
                if Pathing.WalkLine(targetX[a], targetY[a], tx, ty, traceDistance) then begin
                  wasFound := True;
                  if traceDistance < bestDistance then begin
                    bestDistance := traceDistance;
                    bestTargetCell := a;
                    bestEntityCell := b;
                  end;
                end;
              end;
      if wasFound then begin
        Inc(GDVars.rankedTargetCount);
        GDVars.rankedTargets[GDVars.rankedTargetCount].ent := i;
        GDVars.rankedTargets[GDVars.rankedTargetCount].cost := Lo(bestDistance);
        d := 0;
        if facing < C_Dir.CENTER then
          d := facing
        else
          while not Pathing.IsDirToward(targetX[bestTargetCell], targetY[bestTargetCell], entityX[bestEntityCell],
                                  entityY[bestEntityCell], d) do
            Inc(d);
        GDVars.rankedTargets[GDVars.rankedTargetCount].face := d;
      end;
    end;
  end;
  Pathing.SortTargets;
end;

begin

end.
