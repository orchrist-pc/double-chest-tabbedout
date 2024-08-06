#Requires AutoHotkey v1.1.27+
#Include %A_ScriptDir%/Gdip_ALL.ahk
#SingleInstance, Off
#Persistent
DetectHiddenWindows, On
; Register message handlers for start and stop commands
OnMessage(0x1001, "StartMonitoring")
OnMessage(0x1002, "StopMonitoring")

; Get the task from command line arguments
global main_pid := A_Args[1]
;global task := A_Args[2]
global ml_logfolder := A_Args[2]
;MsgBox, "mainpid: " . %main_pid% . " task: " . %task%

global ml_e_logfile := ml_logfolder . "Exotic_Monitor.log"

global pToken := -1
global DESTINY_X := 0
global DESTINY_Y := 0
global TitleBarHeight := 0
global BorderWidth := 0
global DESTINY_WIDTH := 0
global DESTINY_HEIGHT := 0
global D2_WINDOW_HANDLE := -1
find_d2(1)

global monitoring_exotic := false

Gui, +AlwaysOnTop +ToolWindow -Caption
Gui, Show, Hide, MessageReceiver

SetTimer, CheckParentRunning, 10000
Return

StartMonitoring(wParam, lParam, msg, hwnd) {
    find_d2(1)
    if (pToken = -1)
        pToken := Gdip_Startup()
    monitoring_exotic := true

    Gui, +AlwaysOnTop +ToolWindow -Caption
    Gui, Show, Hide, MessageReceiver

    CheckExoticDrop()
    SetTimer, CheckExoticDrop, 200
}

StopMonitoring(wParam, lParam, msg, hwnd) {
    monitoring_exotic := false
    SetTimer, CheckExoticDrop, Off
}

CheckExoticDrop()
{
    ; WinActivate, Destiny 2
    locations := ["1258|198|20|80","1258|278|20|80","1258|358|20|80","1258|438|20|80"]
    loop, 4
    {
        if(DEBUG)
            FileAppend, Loot Monitoring | STARTING EXOTIC DETECTION`n, %ml_e_logfile%
        if (exact_color_check(locations[A_Index],0x48BDD8,ml_e_logfile) > 0.01)
        {
            if(DEBUG)
                FileAppend, EXOTIC FOUND`n, %ml_e_logfile%
            PostMessage, 0x1004, 0, 0, , % "ahk_pid " main_pid
            SetTimer, CheckExoticDrop, Off
        }
    }
    Return
}

find_d2(mode:=0) ; find the client area of d2
{
    ; Detect the Destiny 2 game window
    WinGet, Destiny2ID, ID, ahk_exe destiny2.exe
    D2_WINDOW_HANDLE := Destiny2ID

    if (!D2_WINDOW_HANDLE)
    {
        MsgBox, Unable to find Destiny 2. Please launch the game and then run the script.
        ExitApp
    }
    
    ; Get the dimensions of the game window's client area
    WinGetPos, X, Y, Width, Height, ahk_id %Destiny2ID%
    if(Y < 1) {
        if(mode == 0)
            WinMove, ahk_exe destiny2.exe,, X, 1
    }
    WinGetPos, X, Y, Width, Height, ahk_id %Destiny2ID%
    VarSetCapacity(Rect, 16)
    DllCall("GetClientRect", "Ptr", WinExist("ahk_id " . Destiny2ID), "Ptr", &Rect)
    ClientWidth := NumGet(Rect, 8, "Int")
    ClientHeight := NumGet(Rect, 12, "Int")

    ; Calculate border and title bar sizes
    BorderWidth := (Width - ClientWidth) // 2
    TitleBarHeight := Height - ClientHeight - BorderWidth

    ; Update the global vars
    DESTINY_X := X + BorderWidth
    DESTINY_Y := Y + TitleBarHeight
    DESTINY_WIDTH := ClientWidth
    DESTINY_HEIGHT := ClientHeight
    return
}

exact_color_check(coords,base_color,filename:="test") ; also bad function to check for specific color pixels in a given area
{
    pD2WindowBitmap := Gdip_BitmapFromHWND(D2_WINDOW_HANDLE,clientOnly:=1)
    ;Gdip_SaveBitmapToFile(pD2WindowBitmap, A_Desktop . "\" filename . ".png")
    width := Gdip_GetImageWidth(pD2WindowBitmap)
    height := Gdip_GetImageHeight(pD2WindowBitmap)

    
    if(DEBUG)
        FileAppend, color checking`n, %gs_logfile%
    ; convert the coords to be relative to destiny 
    coords := StrSplit(coords, "|")
    x := coords[1]
    y := coords[2]
    w := coords[3]
    h := coords[4]

    ; Create a new bitmap with the cropped dimensions
    pElementBitmap := Gdip_CreateBitmap(w, h)
    G := Gdip_GraphicsFromImage(pElementBitmap)
    Gdip_DrawImage(G, pD2WindowBitmap, 0, 0, w, h, x, y, w, h)

    Gdip_DisposeImage(pD2WindowBitmap)

    colx := 0
    coly := 0
    white := 0
    total := 0

    loop, %h%
    {
        loop, %w%
        {
            color := (Gdip_GetPixelColor(pElementBitmap, colx, coly, 3))
            if (color == base_color)
                white += 1
            total += 1
            colx += 1
            if(DEBUG)           
                FileAppend, Color: %color% | Ref: %base_color%`n, %filename%
        }
        colx := 0
        coly += 1
    }
    Gdip_DisposeImage(pElementBitmap)
    pWhite := white/total
    return pWhite
}

CheckParentRunning()
{
    Process, Exist, %main_pid%
    if (!ErrorLevel) ; If ErrorLevel is 0, the process does not exist
    {
        ExitApp
    }
    return
}
