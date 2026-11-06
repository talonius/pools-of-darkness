{ Leaves the game for DOS: saves the party to the transfer save slot without prompting, then shuts down the input and
  sound drivers and halts. }
{$O+,F+,S-,R-,V-,B-,I-}
unit ExitDos;

interface

{ Saves the party through SaveLoad's vault-mode path, without trimming it, and ends the program with exit status 23. }
procedure ExitToDos;

implementation

uses SaveLoad, GameIo;

procedure ExitToDos;
begin
  SaveLoad.SaveGame(False, True);
  GameIo.ExitGame(23);
end;

begin
end.
