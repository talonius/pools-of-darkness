{ The title sequence: up to three title pictures with the title music, ending on the third, which stays on screen as the
  backdrop for the title menu. }
{$O+,F+,S-,R-,V-,B-,I-}
unit Intro;

interface

{ Plays the title sequence: starts the title music and shows the first two title pictures for five seconds each, then
  the third, the title menu's backdrop, for up to 20 seconds; a key during the first two skips straight to the third. }
procedure Introduction;

implementation

uses Blit, GameIo, TextRend, Mouse, Music, Portrait, GDConsts, GDVars, Types;

{ Waits up to a number of seconds or until a key, flushing the keyboard before and after. A clock that runs backwards
  (midnight) also ends the wait.
  @param(timeoutSeconds Seconds to wait.)
  @returns(True when the wait ended early, by a key or by the clock running backwards.) }
function DelayOrKey(timeoutSeconds: Word): Boolean;
var
  startCentiseconds: LongInt;
  deadlineCentiseconds: LongInt;
begin
  GameIo.FlushKeys;
  startCentiseconds := TextRend.GetTicks;
  deadlineCentiseconds := startCentiseconds + timeoutSeconds * 100;
  repeat
  until GameIo.InputPending or (TextRend.GetTicks >= deadlineCentiseconds)
                            or (TextRend.GetTicks < startCentiseconds);
  { A clock that wraps at midnight ends the wait as if a key were pressed. }
  if TextRend.GetTicks >= deadlineCentiseconds then
    DelayOrKey := False
  else
    DelayOrKey := True;
  GameIo.FlushKeys;
end;

{ Show the mouse cursor again. }
procedure FinishIntroduction;
begin
  Mouse.ShowMouse;
end;

{ Show the third title picture, the title menu's backdrop, for up to 20 seconds or until a key. }
procedure ShowLastTitle;
begin
  Blit.LoadPic('title', 3, 0, 0, GDVars.titleImage);
  Blit.SetDacPalette(0, 256, GDVars.imagePal);
  Blit.ShowPic(0, 0, GDVars.titleImage);
  Blit.FreePic(GDVars.titleImage);
  if Intro.DelayOrKey(20) then Exit;
end;

procedure Introduction;
var
  { Unused in this version; see the other implementations of this routine. }
  key: Byte;
begin
  GDVars.titleImage := nil;
  Portrait.FreeAnimation;
  Mouse.HideMouse;
  TextRend.ClearScreen;
  Music.StartMusic(1);

  Blit.LoadPic('title', 1, 0, 0, GDVars.titleImage);
  Blit.SetDacPalette(0, 256, GDVars.imagePal);
  Blit.ShowPic(0, 0, GDVars.titleImage);
  Blit.FreePic(GDVars.titleImage);
  if Intro.DelayOrKey(5) then begin
    Intro.ShowLastTitle;
    Intro.FinishIntroduction;
  end else begin
    Blit.LoadPic('title', 2, 0, 0, GDVars.titleImage);
    TextRend.ClearScreen;
    Blit.SetDacPalette(0, 256, GDVars.imagePal);
    Blit.ShowPic(0, 0, GDVars.titleImage);
    Blit.FreePic(GDVars.titleImage);
    if Intro.DelayOrKey(5) then begin
      Intro.ShowLastTitle;
      Intro.FinishIntroduction;
    end else begin
      Intro.ShowLastTitle;
      Intro.FinishIntroduction;
      Exit;
    end;
  end;
end;

begin
end.
