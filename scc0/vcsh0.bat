@echo off

SETLOCAL

SET SCC0_BASE=%~dp0%

SET LAUNCH_FILES=
SET LAUNCH_FILES=%LAUNCH_FILES% -Xinit-load=%SCC0_BASE%\scheme.scf
SET LAUNCH_FILES=%LAUNCH_FILES% -Xinit-load=%SCC0_BASE%\invoke-repl.scf

%SCC0_BASE%\..\vm\scansh0 %LAUNCH_FILES% %1 %2 %3 %4 %5 %6 %7 %8 %9
