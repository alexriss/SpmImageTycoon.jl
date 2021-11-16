#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

#NoTrayIcon
#Persistent
#SingleInstance force

global script

/* Setup Tray icon and add item that will handle
* double click events
*/
Menu Tray, NoStandard
Menu Tray, Icon
Menu Tray, Icon, logo_diamond.ico
Menu Tray, Add, Show / Hide, TrayClick
Menu Tray, Add, Close, CloseItem
Menu Tray, Default, Show / Hide

;// Run program or batch file hidden
DetectHiddenWindows On
Run SpmImageTycoon.bat,, Hide, PID
WinWait ahk_pid %PID%
script := WinExist()
DetectHiddenWindows Off

SetTimer, Closer, 2000

return

TrayClick:
OnTrayClick()
return

;// Show / hide program or batch file on double click
OnTrayClick() {
    if DllCall("IsWindowVisible", "Ptr", script) {
        WinHide ahk_id %script%

    } else {
        WinShow ahk_id %script%
        WinActivate ahk_id %script%
    }
}

CloseItem() {

       DetectHiddenWindows On
       WinWait ahk_class ConsoleWindowClass
       Process, Close, cmd.exe
       DetectHiddenWindows Off
       ExitApp

}


Closer:
Process, Exist, %PID%
If !ErrorLevel
ExitApp
Return