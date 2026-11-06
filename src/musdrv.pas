{ Calls into the music driver. The driver is a .COM image copied to a paragraph boundary; StartDriver turns that address
  into a far entry point whose segment starts 256 bytes below the image, as if the image had been loaded behind a PSP,
  and every request goes through that entry with an event code and the parameter pointer. }
{$F+,O-,S-,R-,V-,B-,I-}
unit MusDrv;

interface

{ Calls the driver's dispatch entry with a function code and a far argument; returns its status. Codes used: 0 install
  (StartDriver), 1 start (StartPlayback), 3 stop (StopHook).
  @param(eventCode Driver function code.)
  @param(paramOffset Offset of the far argument.)
  @param(paramSegment Segment of the far argument.)
  @returns(The driver's status.) }
function DriverCall(eventCode, paramOffset, paramSegment: Word): Word;

{ Marks the music driver installed and halts unless the image address is a paragraph multiple; turns the address into a
  far entry point whose segment starts 256 bytes below the image, as if the image had been loaded behind a PSP; saves
  the parameter block and sends the initialize event.
  @param(driverLoadAddress Far address of the loaded driver image, as a LongInt.)
  @param(driverParams The parameter block handed to the driver at install.) }
procedure StartDriver(driverLoadAddress: LongInt; driverParams: Pointer);

{ Calls driver code 1 when given 0; any other value does nothing.
  @param(guardValue 0 to start playback.) }
procedure StartPlayback(guardValue: Word);

{ When the music driver is installed, marks it idle and sends it the shutdown event. }
procedure StopHook;

implementation

uses GDConsts, GDVars, C_Driver;

const
  DRIVER_EVENT_INITIALIZE = 0;
  DRIVER_EVENT_SHUTDOWN = 3;

function DriverCall(eventCode, paramOffset, paramSegment: Word): Word;
begin
  DriverCall := GDVars.drvEntry(paramSegment, paramOffset, eventCode);
end;

procedure StartDriver(driverLoadAddress: LongInt; driverParams: Pointer);
begin
  GDVars.driverState := C_Driver.MUSIC_INSTALLED;
  { A misaligned image cannot be entered: stop the program. }
  if Byte(driverLoadAddress and $F) <> 0 then Halt;
  Inc(driverLoadAddress, (driverLoadAddress and $FFF0) shl 12);
  driverLoadAddress := driverLoadAddress and $FFFF0000;
  Inc(driverLoadAddress, $100);
  Dec(driverLoadAddress, $100000);
  @GDVars.drvEntry := Pointer(driverLoadAddress);
  Move(driverParams, GDVars.drvParamsOfs, SizeOf(driverParams));
  GDVars.lastDriverResult := MusDrv.DriverCall(MusDrv.DRIVER_EVENT_INITIALIZE, GDVars.drvParamsOfs,
                                               GDVars.drvParamsSeg);
end;

procedure StartPlayback(guardValue: Word);
begin
  if guardValue <> 0 then Exit;
  GDVars.lastDriverResult := MusDrv.DriverCall(1, 0, 0);
end;

procedure StopHook;
begin
  if GDVars.driverState = C_Driver.MUSIC_INSTALLED then begin
    GDVars.driverState := C_Driver.NO_DRIVER;
    GDVars.lastDriverResult := MusDrv.DriverCall(MusDrv.DRIVER_EVENT_SHUTDOWN, 0, 0);
  end;
end;

begin
end.
