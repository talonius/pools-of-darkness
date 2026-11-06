{ Installs the heap allocation-failure handler. When an allocation fails, the player is warned, offered a chance to save
  the game if one is in progress, and the program then shuts down cleanly. }
{$O+,F+}
unit HeapErr;

interface

uses TextRend, SaveLoad, GameIo, GDConsts, GDVars;

{ Installed as HeapError, so the heap manager calls it when an allocation fails. For a nonzero request it shows an
  insufficient-memory warning; while a game is active it runs the save menu and repeats until a save sets the
  recently-saved flag, otherwise it says the program is exiting. Either way it then quits through GameIo.ExitGame. A
  zero-size request returns at once. Note: the result is never assigned.
  @param(size Bytes requested; 0 does nothing.)
  @returns(Nothing: the result is never assigned.) }
function HeapErrorHandler(size: Word): Integer;

implementation

function HeapErrorHandler(size: Word): Integer;
var
  exitFlag: Byte;
begin
  if size > 0 then begin
    exitFlag := 0;
    repeat
      TextRend.DisplayAndPause(14, 0, 'WARNING: Insufficient Memory');
      if GDVars.gameInProgress <> 0 then begin
        SaveLoad.SaveGame(True, False);
        exitFlag := GDVars.justSaved;
      end else begin
        exitFlag := 1;
        TextRend.DisplayAndPause(14, 0, 'Insufficient Memory. Exiting Program');
      end;
    until exitFlag <> 0;
    GameIo.ExitGame(0);
  end;
end;

begin
  HeapError := @HeapErr.HeapErrorHandler;
end.
