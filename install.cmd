@echo off

rem On defini le fond d'écran
set "WALLPAPER=C:\Documents and Settings\Administrator\Desktop\wallpapers\bdj1.png"

reg add "HKCU\Control Panel\Desktop" /v Wallpaper /t REG_SZ /d "%WALLPAPER%" /f

reg add "HKCU\Control Panel\Desktop" /v WallpaperStyle /t REG_SZ /d "2" /f
reg add "HKCU\Control Panel\Desktop" /v TileWallpaper /t REG_SZ /d "0" /f

RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters

cd /d "C:\Documents and Settings\Administrator\Desktop\Installers"

rem On install 7zip

start "/S" "/D=C:\Program Files\7-Zip" ".\7z.exe"
7z x ".\uniextract2.zip" -o"C:\Program Files\Uniextract"


mkdir C:\Documents and Settings\Administrator\Desktop\Games

rem On installe tout les exes
for %%f in (*.exe) do (
    mklink "%userprofile%\Start Menu\Programs\Startup\%%f" "%%f"
    "C:\Program Files\Uniextract\UniExtract.exe" %%f "C:\Documents and Settings\Administrator\Desktop\Games"
)
