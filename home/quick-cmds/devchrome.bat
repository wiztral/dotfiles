@echo off
start "" chrome.exe --disable-web-security --user-data-dir="%TEMP%\DevChromeUserData" %*
