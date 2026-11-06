{ VGA animation frames. Each frame of a VGA animation is kept run-length packed as the difference from the key frame;
  PrepareVgaFrame unpacks one, combines it with the key frame, and leaves the full picture in the shared image buffer.
  The unpacking and combining routines are in assembler. }
{$F+,O-,S-,R-,V-,B-,I-}
unit VgaFrame;

interface

{ Decodes a frame into the display picture's data; does nothing while no frames are loaded.
  @param(picIdx The frame: the key frame is copied as it is, any other is expanded and XORed with it.) }
procedure PrepareVgaFrame(picIdx: Byte);

{ Expands a run-length-coded frame into dst.
  @param(src The run-length code.)
  @param(dst Receives the expanded frame.)
  @param(encodedBytes The length of the code at src.) }
procedure ExpandRleFrame(src, dst: Pointer; encodedBytes: Word);

{ Stores src xor key into dst, byte by byte; dst may be src.
  @param(src The bytes to combine.)
  @param(dst Receives the result.)
  @param(key The bytes `src` is XORed with.)
  @param(n The byte count; 0 processes 65536 bytes.) }
procedure XorFrame(src, dst, key: Pointer; n: Word);

implementation

uses ZeroFree, GDConsts, GDVars;

{$L VGAFRAME.OBJ}

procedure ExpandRleFrame; external;

procedure XorFrame; external;

procedure PrepareVgaFrame(picIdx: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  frameSize: Pointer;
  work: Pointer;

  { Expands the current frame's code into the work buffer, then XORs it with the key frame into the display picture. }
  procedure DecodeDelta;
  begin
    VgaFrame.ExpandRleFrame(GDVars.vgaFrameBufs[picIdx], work, GDVars.animFrameSizes[picIdx]);
    VgaFrame.XorFrame(work, @GDVars.vgaFrameImage^.data,
                      GDVars.vgaFrameBufs[GDVars.animKeyFrame], 7744);
  end;

begin
  if GDVars.vgaFrameBufs[0] = nil then Exit;
  GetMem(work, 7744);
  if picIdx <> GDVars.animKeyFrame then
    DecodeDelta
  else
    Move(GDVars.vgaFrameBufs[picIdx]^, GDVars.vgaFrameImage^.data, 7744);
  ZeroFree.PrefixFree(work, 7744);
end;

end.
