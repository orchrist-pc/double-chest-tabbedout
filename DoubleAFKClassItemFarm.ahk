;##############################################################
; For support, help or other various macro related queries visit our discord at
; https://thrallway.com
;##############################################################
global VERSION := "3.0.0"
;##############################################################
; 
; MASSIVE Shoutout to @a2tc for  the original brainception of the Double Chest Macro
;   - Without his ideas and foundation of the original two chest macro NONE of this is possible
;   - All of his hard work for creating stat tracking and conceptualizing this
;   - Helping to map out these chests and figure out optimal timings
;   - General vibes man, dude's a genius
; Special Thanks to @Zenairo for:
;   - Massive refactoring and optimization of the og Double Chest Macro
;   - Huge overhaul to Stat tracking
;   - API coding and hosting
;   - BIGLY Big Brain Energy
;   - Finding that GDIP can screenshot in the background
; Special Thanks to @Asha for:
;   - Incredible levels of Patience and help with supporting the users
;   - Countless hours of testing and brainstorming
;   - Fixing stat tracking when Zen broke it :)
;   - <3
; Special Thanks to @antrament for:
;	- The framework and class files necessary for tabbed out control to work
;	- Quite literally none of the tabbed out versions of this farm work without his efforts in getting the afk xp script working
;	- The support and troubleshooting he's done with the community in getting this working
; Special Thanks to @_leopoldprime for:
;   - API processing with the discord bot allowing for public stat tracking across all users
;   - Discord bot development enabling for easy support and quick help for all users
; Special Thanks to @krekn for:
;   - Convincing our doubting asses that background app screenshots is a thing that works
;   - Actually inspiring me to work on this
; Special Thanks to @.zovc for helping on the OG version of tabbed out single chest macro
; 
;##############################################################
global debugging := False
global db_logfile := A_ScriptDir . "\debugs\AFKDoubleChest.log"
;##############################################################

#Include *i %A_ScriptDir%\_Libraries\overlay_class.ahk
#Include *i %A_ScriptDir%\_Libraries\Gdip_ALL.ahk
#Include *i %A_ScriptDir%\_Libraries\AntraClassFiles.ahk
#Requires AutoHotkey >=1.1.36 <1.2
#SingleInstance, Force
#NoEnv
#Persistent
Sendmode Input
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen
SetBatchLines, -1
SetKeyDelay, -1
SetMouseDelay, -1
DetectHiddenWindows, On
SetWorkingDir, %A_ScriptDir%

; Register message handlers
/*
OnMessage(0x1003, "on_chest_open")
OnMessage(0x1004, "on_exotic_drop")
OnExit("on_script_exit")
*/

;; Init for non standard AHK stuff
pToken := Gdip_Startup()    ; gdip init used for image processing
vigemwrapperdllsetup()      ; vigemwrapper dll setup used for tabbed out controller support
global 360Controller := new ViGEmXb360()   ; vigem controller setup used for tabbed out 

;; INITIALIZE
global DESTINY_X := 0
global DESTINY_Y := 0
global DESTINY_WIDTH := 0
global DESTINY_HEIGHT := 0
global D2_WINDOW_HANDLE := -1

global fasttravel_sleep 		= 2200
global run_to_start_delay 		= 10000
global count := 1
global testing := false

return
	
;; Start Farm Script stuff
	Start_Farm:
		find_d2()
        /*
        loop, ; loop until we actually load in lol
        {
            if (orbit_landing())
                break
            Sleep, 500
            change_character()
            Sleep, 500
        }
        */
		loop,
		{
			find_d2()
			TO_ft_to_landing()
            PreciseSleep(run_to_start_delay)    ;CONVERT THIS SHIT TO WAIT FOR SPAWN
            
            TO_force_chest()
            if(!testing)
			    PreciseSleep(5000)                 ;wait for chest spawns
            if(TO_find_chest21())
            {
                TO_run_to_chest21()
            }
            else
            {
                ;; LOGIC TO RESTART LOOP OR SOME SHIT
            }

			G4Chest := TO_find_g4_chests()
            FileAppend, Run: %count% | Chest: %G4Chest%`n, %db_logfile%
            
            360Controller.Axes.LT.SetState(100)
            PreciseSleep(500)
            filename := "\ADS\" . count . "_" . G4Chest
            get_gs_screenshot(filename)
            360Controller.Axes.LT.SetState(0)

            ;FileAppend, Running to %G4Chest%`n, %db_logfile%
            TO_run_to_G4_chest(G4Chest)
            

            count++
		}
    Return

    test:
        
    Return

;##############################################################
;; HOTKEYS
;##############################################################
F4::
	gosub, Start_Farm
Return

F3::gosub, test
F5::Reload
F8::ExitApp

;##############################################################
;; CHEST FUNCTIONS
;##############################################################
    TO_force_chest()
    {
        360Controller.Buttons.RS.SetState(True)     ; 
        PreciseSleep(50)                            ; 
        360Controller.Buttons.RS.SetState(False)    ; THIS IS ALL TO PREVENT BUNGIE FROM
        PreciseSleep(50)                            ; EATING OUR INPUTS AT THE START
        360Controller.Buttons.RS.SetState(True)     ; FUCK THIS JANK SHIT
        PreciseSleep(50)                            ; FUCK MY LIFE
        360Controller.Buttons.RS.SetState(False)    ; 
        PreciseSleep(50)                            ; 

        ;360Controller.Buttons.Y.SetState(True)
        ;PreciseSleep(200)
        ;360Controller.Buttons.Y.SetState(false)
        ;360Controller.Buttons.Y.SetState(True)
        ;PreciseSleep(50)
        ;360Controller.Buttons.Y.SetState(False)
        controller_aim_hor(20,1200)                 ; aim left towards pavilion
        controller_sprint(7300)                     ; run to the pavilion
        PreciseSleep(10)
        controller_aim_hor(90,1600)                 ; aim right towards the corner        
        controller_sprint(1000)                     ; run into corner
        controller_move_hor(0,110)                  ; run into corner
        controller_move_ver(100,1300)               ; run into corner
        controller_move_hor(0,150)                  ; run into corner
        controller_move_ver(100,1300)               ; run into corner
    }
    
    TO_find_chest21()
    {
        timer_start := A_TickCount
        chest_found := false
        360Controller.Axes.LT.SetState(100)
        while(not chest_found)
        {
            if(exact_color_check("1198|357|25|25",0xFFFFFF) > 0.12)
            {
                chest_found := true
                360Controller.Axes.LT.SetState(0)
                Return true
            }
            if(A_TickCount - timer_start > 20000)
                break
        }
        360Controller.Axes.LT.SetState(0)
        Return false
    }

    TO_run_to_chest21()
    {
        controller_move_ver(0,100)                  ; Side Step out of the Pavilion
        controller_move_hor(100,300)                ; 
        controller_aim_hor(90,450)                 ; Aim Towards Chest 21

        controller_sprint(5000)

        controller_aim_hor(10,485)                 ; Aim towards Chest 21

        controller_sprint(4600)

        controller_aim_hor(10,1700)                 ; Turn around to jam into corner
        
        controller_sprint(2100)

        controller_aim_hor(10,1000)                 ; Aim left towards chest to loot
        controller_aim_ver(10,500)                  ; Aim down at chest to loot
        /*
        360Controller.Buttons.X.SetState(true)
		PreciseSleep(2000)
		360Controller.Buttons.X.SetState(false)
		PreciseSleep(1000)
        */
        return

    }

    TO_find_g4_chests()
    {
        g4_coords := ["1177|275|25|25|0.05","1040|520|100|60|0.01"]
        g4_chest := [20,18]
        g4_index := g4_chest.MaxIndex()
        chest_found := 16
        timer_start := A_TickCount

        controller_aim_ver(90,425)      ;; 425
        controller_aim_hor(90,2100)     ;; 2100

        if((exact_color_check("251|137|29|20",0xFFFFFF,"Chest17") > 0.05) || (exact_color_check("285|125|30|20",0xFFFFFF,"Chest17") > 0.05))
        {
            chest_found := 17
            360Controller.Axes.LT.SetState(0)
            PreciseSleep(1000)

            controller_aim_ver(90,475)      ;; 425
            controller_aim_hor(10,300)     ;; 2100
            Return chest_found
        }

        360Controller.Axes.LT.SetState(100)

        while(chest_found == 16)    ; loop until a chest that isn't chest 16 is found (or 5 seconds passes)
        {
            loop, 5
            {
                if((exact_color_check("245|105|100|50|0.01",0xFFFFFF,"Chest19") > 0.01) || (exact_color_check("340|100|30|20|0.05",0xFFFFFF,"Chest19") > 0.01))
                {
                    chest_found := 19
                    360Controller.Axes.LT.SetState(0)
                    PreciseSleep(1000)
            
                    controller_aim_ver(90,475)      ;; 425
                    controller_aim_hor(10,300)     ;; 2100
                    Return chest_found
                }
            }
            if(A_TickCount - timer_start > 5000)
                break
        }
        timer_start := A_TickCount

        filename := "\ADS\ADS1_" . count
        get_gs_screenshot(filename)

        360Controller.Axes.LT.SetState(0)
        PreciseSleep(1000)

        controller_aim_ver(90,475)      ;; 425
        controller_aim_hor(10,300)     ;; 2100

        360Controller.Axes.LT.SetState(100)

        while(chest_found == 16)    ; loop until a chest that isn't chest 16 is found (or 5 seconds passes)
        {
            loop, %g4_index%
            {
                coords := g4_coords[A_Index]
                coords := StrSplit(coords, "|")
                x := coords[1]
                y := coords[2]
                w := coords[3]
                h := coords[4]
                r := coords[5]
                coords := x "|" y "|" w "|" h
                filename := "Chest" . g4_chest[A_Index]
                if(exact_color_check(coords,0xFFFFFF,filename) > r)
                {
                    chest_found := g4_chest[A_Index]
                    360Controller.Axes.LT.SetState(0)
                    Return chest_found
                }
            }
            if(A_TickCount - timer_start > 5000)
                break
        }

        360Controller.Axes.LT.SetState(0)
        Return chest_found
    }

    TO_run_to_G4_chest(chest)
    {
        360Controller.Buttons.Y.SetState(True)
        controller_move_hor(100,700)
        360Controller.Buttons.Y.SetState(False)
        controller_aim_hor(85,1000)
        controller_aim_ver(10,475)
        controller_sprint(2500)

        if(chest == 17)
        {
            controller_sprint(1250)
            controller_aim_hor(10,2100)
            controller_sprint(1000)
            360Controller.Buttons.LS.SetState(True)
            360Controller.Axes.LY.SetState(100)
            PreciseSleep(100)
            360Controller.Buttons.A.SetState(True)
            PreciseSleep(50)
            360Controller.Buttons.A.SetState(False)
            PreciseSleep(50)
            360Controller.Buttons.A.SetState(True)
            PreciseSleep(50)
            360Controller.Buttons.A.SetState(False)
            PreciseSleep(1000)
            360Controller.Buttons.A.SetState(True)
            PreciseSleep(50)
            360Controller.Buttons.A.SetState(False)
            360Controller.Buttons.LS.SetState(false)
            360Controller.Axes.LY.SetState(50)
            PreciseSleep(1000)
            controller_aim_hor(15,300)
            controller_sprint(600)
            filename := count . "_ChestLoot_17"
            get_gs_screenshot(filename)
        }

        if(chest == 20)
        {
            controller_sprint(500)
            controller_move_hor(0,500)
            controller_aim_hor(90,1550)
            360Controller.Buttons.A.SetState(True)
            PreciseSleep(50)
            360Controller.Buttons.A.SetState(False)
            PreciseSleep(50)
            360Controller.Buttons.A.SetState(True)
            PreciseSleep(50)
            360Controller.Buttons.A.SetState(False)
            360Controller.Axes.LY.SetState(100)
            PreciseSleep(1800)
            360Controller.Buttons.A.SetState(True)
            PreciseSleep(50)
            360Controller.Buttons.A.SetState(False)
            360Controller.Axes.LY.SetState(50)
            controller_aim_hor(85,150)
            controller_sprint(2000)
            filename := count . "_ChestLoot_20"
            get_gs_screenshot(filename)
        }


        if(chest == 19)
        {
            controller_sprint(1500)
            controller_aim_hor(15,1700)
            controller_sprint(2000)
            360Controller.Buttons.A.SetState(True)
            PreciseSleep(50)
            360Controller.Buttons.A.SetState(False)
            PreciseSleep(50)
            360Controller.Buttons.A.SetState(True)
            PreciseSleep(50)
            360Controller.Buttons.A.SetState(False)
            360Controller.Axes.LY.SetState(100)
            PreciseSleep(1800)
            360Controller.Buttons.A.SetState(True)
            PreciseSleep(50)
            360Controller.Buttons.A.SetState(False)
            360Controller.Axes.LY.SetState(50)
            controller_aim_hor(85,1200)
            controller_sprint(1300)
            controller_aim_hor(15,900)
            controller_sprint(900)
            filename := count . "_ChestLoot_19"
            get_gs_screenshot(filename)   
        }


        if(chest == 16)
        {
            controller_sprint(1500)
            controller_aim_hor(15,1700)
            controller_sprint(1800)
            controller_aim_hor(85,1100)
            controller_sprint(4300)

            controller_aim_hor(15,650)
            controller_sprint(4100)
            filename := count . "_ChestLoot_16"
            get_gs_screenshot(filename)
        }

        if(chest == 18)
        {   
            controller_sprint(1500)
            controller_aim_hor(15,1700)
            controller_sprint(1800)
            controller_aim_hor(85,1450)
            controller_sprint(5950)
            filename := count . "_ChestLoot_18"
            get_gs_screenshot(filename)
        }

        360Controller.Buttons.X.SetState(true)
		PreciseSleep(2000)
		360Controller.Buttons.X.SetState(false)
		PreciseSleep(1000)
        360Controller.Buttons.Y.SetState(True)
		PreciseSleep(100)
        360Controller.Buttons.Y.SetState(False)

    }

;##############################################################
;; TRAVEL FUNCTIONS
;##############################################################
    TO_ft_to_landing()
    {
        360Controller.Buttons.Back.SetState(true)
        PreciseSleep(1500)
        360Controller.Buttons.Back.SetState(false)
        PreciseSleep(2000)                      ; WAIT TIME BEFORE MOVING CURSOR
        controller_move_hor(0,fasttravel_sleep) ; move cusror left towards the landing zone
        controller_move_ver(30,100)             ; move cursor down a little for consistency
        controller_move_ver(50,100)             ; MAKE SURE CURSOR DOESN'T FLY OFF INTO
        controller_move_ver(50,100)             ; FUCKING NARNIA FOR SOME FUCKASS REASON
        360Controller.Buttons.A.SetState(true)
        PreciseSleep(2000)
        360Controller.Buttons.A.SetState(false)
        return
    }
    TO_orbit_to_landing()
    {
        360Controller.Buttons.Back.SetState(true)
        PreciseSleep(100)
        360Controller.Buttons.Back.SetState(false)
        PreciseSleep(2000)
        controller_move_ver(60,100)
        controller_move_ver(40,100)
        controller_move_ver(50,100)
        controller_move_ver(50,100)
        PreciseSleep(600)
        360Controller.Buttons.A.SetState(true)
        PreciseSleep(100)
        360Controller.Buttons.A.SetState(false)
        controller_move_hor(0,fasttravel_sleep) ; move cusror left towards the landing zone
        controller_move_ver(30,100)             ; move cursor down a little for consistency
        controller_move_ver(50,100)             ; MAKE SURE CURSOR DOESN'T FLY OFF INTO
        controller_move_ver(50,100)             ; FUCKING NARNIA FOR SOME FUCKASS REASON
        360Controller.Buttons.A.SetState(true)
        PreciseSleep(300)
        360Controller.Buttons.A.SetState(false)
        controller_move_hor(100,900)
        controller_move_ver(0,550)
        360Controller.Buttons.A.SetState(true)
        PreciseSleep(300)
        360Controller.Buttons.A.SetState(false)
        ;;;; ADD WAIT FOR SPAWN RETURN TRUE BULLSHIT HERE
        return
    }
;##############################################################
;; UTILITY FUNCTIONS
;##############################################################
    find_d2() ; find the client area of d2
    {
        ; Detect the Destiny 2 game window
        WinGet, Destiny2ID, ID, ahk_exe destiny2.exe
        D2_WINDOW_HANDLE := Destiny2ID
        
        ; Get the dimensions of the game window's client area
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

    get_screenshot(filename) ; save screenshot for debugging
    {
        pD2WindowBitmap := Gdip_BitmapFromHWND(D2_WINDOW_HANDLE,clientOnly:=1)
        Gdip_SaveBitmapToFile(pD2WindowBitmap, A_ScriptDir . "\debugs\screenshots\" . filename . ".png")

        Gdip_DisposeImage(pD2WindowBitmap)
    }

    get_gs_screenshot(filename) ; save screenshot for debugging
    {
        pD2WindowBitmap := Gdip_BitmapFromHWND(D2_WINDOW_HANDLE,clientOnly:=1)
        pD2WindowBitmap := Gdip_BitmapConvertGray(pD2WindowBitmap)
        Gdip_SaveBitmapToFile(pD2WindowBitmap, A_ScriptDir . "\debugs\screenshots\" . filename . ".png")

        Gdip_DisposeImage(pD2WindowBitmap)
    }

    exact_color_check(coords, base_color,filename:="test.png") ; also bad function to check for specific color pixels in a given area
    {
        pD2WindowBitmap := Gdip_BitmapFromHWND(D2_WINDOW_HANDLE,clientOnly:=1)
        if(debugging)
            Gdip_SaveBitmapToFile(pD2WindowBitmap, A_ScriptDir . "\debugs\screenshots\Bigly" . filename . ".png")

        width := Gdip_GetImageWidth(pD2WindowBitmap)
        height := Gdip_GetImageHeight(pD2WindowBitmap)

        ;FileAppend, color checking`n, %gs_logfile%
        ; convert the coords to be relative to destiny 
        coords := StrSplit(coords, "|")
        x := coords[1]
        y := coords[2]
        w := coords[3]
        h := coords[4]

        ;MsgBox, %cropX% %cropY% %cropWidth% %cropHeight% %width% %height%
        ; Create a new bitmap with the cropped dimensions
        pElementBitmap := Gdip_CreateBitmap(w, h)
        G := Gdip_GraphicsFromImage(pElementBitmap)
        Gdip_DrawImage(G, pD2WindowBitmap, 0, 0, w, h, x, y, w, h)

        Gdip_DisposeImage(pD2WindowBitmap)
        ; save bitmap 
        if(debugging)
            Gdip_SaveBitmapToFile(pElementBitmap, A_ScriptDir . "\debugs\screenshots\" . filename . ".png")

        colx := 0
        coly := 0
        white := 0
        total := 0
        if(debugging)
            FileAppend, Color Check Started`n, %db_logfile%
        loop, %h%
        {
            loop, %w%
            {
                color := (Gdip_GetPixelColor(pElementBitmap, colx, coly, 3))
                rcolor := (base_color)
                if (color == base_color)
                    white += 1
                total += 1
                colx += 1
                if(debugging)
                    FileAppend, %colx% %coly% | C: %color% Ref: %rcolor%`n, %db_logfile%
            }
            colx := 0
            coly += 1
        }
        Gdip_DisposeImage(pElementBitmap)
        pWhite := white/total
        return pWhite
    }

;##############################################################
;; CONTROLLER FUNCTIONS
;##############################################################
    controller_move_hor(per, time)
    {
        PreciseSleep(100)
        360Controller.Axes.LX.SetState(per)
        PreciseSleep(time)
        360Controller.Axes.LX.SetState(50)
        PreciseSleep(100)
    }

    controller_move_ver(per,time)
    {
        PreciseSleep(100)
        360Controller.Axes.LY.SetState(per)
        PreciseSleep(time)
        360Controller.Axes.LY.SetState(50)
        PreciseSleep(100)
    }

    controller_aim_hor(per, time)
    {
        PreciseSleep(100)
        360Controller.Axes.RX.SetState(per)
        PreciseSleep(time)
        360Controller.Axes.RX.SetState(50)
        PreciseSleep(100)
    }

    controller_aim_ver(per,time)
    {
        PreciseSleep(100)
        360Controller.Axes.RY.SetState(per)
        PreciseSleep(time)
        360Controller.Axes.RY.SetState(50)
        PreciseSleep(100)
    }

    controller_sprint(time)
    {
        360Controller.Buttons.LS.SetState(True)
        controller_move_ver(100,time)
        360Controller.Buttons.LS.SetState(False)
    }