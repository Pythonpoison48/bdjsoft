@echo off
cd /d "C:\Documents and Settings\Administrator\Desktop\Installers"

rem On installe tout les exes
for %%f in (*.exe) do (
    start "" "%%f"
)
