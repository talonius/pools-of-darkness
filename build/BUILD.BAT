@echo off
rem  Build the four shipped artifacts for Pools of Darkness v1.00.
rem  Run with gametools/build.sh --game pools --ver v10. The driver creates
rem  obj\ and build\logs\, mounts the drives, and calls this batch:
rem      C: = drive_c (read-only)  D: = toolchain\TP6-1990  E: = v10
rem      F: = toolchain\TASM       G: = toolchain\EXEPACK
rem  Keep a separate drive for each tool and each PATH at three characters;
rem  longer paths consume memory needed by the whole-image link.
rem  TASM writes objects to obj\; TPC's /E directs EXEs, OVR, MAPs and TPUs
rem  there, and /O finds the objects for {$L}. TPC reads src\TPC.CFG.

e:
cd \src

rem  Start clean. TPC searches src\ for {$L} objects before /O, so remove
rem  stale TPUs and objects there as well as all products in obj\.
rem  Guard DEL to avoid 'File not found' messages for an empty output tree.
if exist *.TPU del *.TPU
if exist *.OBJ del *.OBJ
if exist ..\obj\*.TPU del ..\obj\*.TPU
if exist ..\obj\*.OBJ del ..\obj\*.OBJ
if exist ..\obj\*.EXE del ..\obj\*.EXE
if exist ..\obj\*.OVR del ..\obj\*.OVR
if exist ..\obj\*.MAP del ..\obj\*.MAP

rem  Assemble all six linked objects explicitly; add new assembly here.
path f:\
tasm blit,..\obj\blit > e:\build\logs\TASM.OUT
tasm sounddrv,..\obj\sounddrv >> e:\build\logs\TASM.OUT
tasm joystick,..\obj\joystick >> e:\build\logs\TASM.OUT
tasm keyboard,..\obj\keyboard >> e:\build\logs\TASM.OUT
tasm textrend,..\obj\textrend >> e:\build\logs\TASM.OUT
tasm vgaframe,..\obj\vgaframe >> e:\build\logs\TASM.OUT

rem  Compile and link every game unit with the current TPC.CFG. /B rebuilds
rem  units even when only compiler switches changed; /M checks timestamps.
path d:\
tpc fixmain.pas /B /E..\obj /O..\obj > e:\build\logs\TPC.OUT

rem  Ship the linked overlay as GAME.OVR and EXEPACK-compress the executable
rem  as GAME.EXE. Keep FIXMAIN.EXE as the separate, unpacked packer input.
ren ..\obj\FIXMAIN.OVR GAME.OVR
path g:\
exepack ..\obj\FIXMAIN.EXE ..\obj\GAME.EXE > e:\build\logs\PACK.OUT

rem  Compile the unpacked utilities with the same compiler and TPC.CFG.
rem  CONTROL uses Dos; STARTUP uses Dos, Crt and the assembled JOYSTICK.OBJ.
rem  Their /M builds follow the whole-image link and pack.
path d:\
tpc control.pas /M /E..\obj /O..\obj > e:\build\logs\CONTROL.OUT
tpc startup.pas /M /E..\obj /O..\obj > e:\build\logs\STARTUP.OUT
