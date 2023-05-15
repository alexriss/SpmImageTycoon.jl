SetWorkingDir(A_ScriptDir)  ; Ensures a consistent starting directory.
#SingleInstance
Persistent

global script

; Setup Tray icon and add item that will handle double click events
Tray:= A_TrayMenu
Tray.Delete()
TraySetIcon("SpmImageTycoon.ico")
Tray.Add("Show / Hide", TrayClick)
Tray.Add("Close", CloseItem)
Tray.Default := "Show / Hide"

;// Run program or batch file hidden
DetectHiddenWindows(true)
Run("SpmImageTycoon.bat", , "Hide", &PID)
ErrorLevel := WinWait("ahk_pid " PID) , ErrorLevel := ErrorLevel = 0 ? 1 : 0
script := WinExist()
DetectHiddenWindows(false)

SetTimer(Closer, 2000)

return

TrayClick(A_ThisMenuItem, A_ThisMenuItemPos, MyMenu) {
    OnTrayClick()
    return
}

;// Show / hide program or batch file on double click
OnTrayClick(*) {
    if DllCall("IsWindowVisible", "Ptr", script) {
        WinHide("ahk_id " script)
    } else {
        WinShow("ahk_id " script)
        WinActivate("ahk_id " script)
    }
}

CloseItem(*) {
    DetectHiddenWindows(true)
    ErrorLevel := WinWait("ahk_class ConsoleWindowClass") , ErrorLevel := ErrorLevel = 0 ? 1 : 0
    ErrorLevel := ProcessClose("cmd.exe")
    DetectHiddenWindows(false)
    ExitApp()
}


Closer(*) {
    ErrorLevel := ProcessExist(PID)
    If !ErrorLevel
    ExitApp()
    Return
}

