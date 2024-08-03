;##############################################################
; For support, help or other various macro related queries visit our discord at
; https://thrallway.com
;##############################################################
global VERSION := "3.0.0-alpha.1"
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
global DEBUG := False
global db_logfile := A_ScriptDir . "\debugs\AFKDoubleChest.log"
;##############################################################

#Requires AutoHotkey >=1.1.36 <1.2
#SingleInstance, Force
#Include *i %A_ScriptDir%\_Libraries\overlay_class.ahk
#Include *i %A_ScriptDir%\_Libraries\Gdip_ALL.ahk
#Include *i %A_ScriptDir%\_Libraries\AntraClassFiles.ahk
#NoEnv
#Persistent
SendMode Input
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen
SetWorkingDir, %A_ScriptDir%
SetBatchLines, -1
SetKeyDelay, -1
SetMouseDelay, -1
; Register message handlers
OnMessage(0x1003, "on_chest_open")
OnMessage(0x1004, "on_exotic_drop")
OnExit("on_script_exit")

; Startup Checks
; =================================== ;
    if InStr(A_ScriptDir, "AppData")
    {
        MsgBox, You must extract all files from the .zip folder you downloaded before running this script.
        Exitapp  
    }

	if (!FileExist( A_ScriptDir "/_Libraries/overlay_class.ahk" ) || !FileExist( A_ScriptDir "/_Libraries/Gdip_all.ahk" ))
    {
        MsgBox, Required files were not found in the same directory as this script. Place it in the same directory as overlay_class.ahk and Gdip_all.ahk.
        Exitapp  
    }

    WinGet, D2PID, PID, ahk_class Tiger D3D Window
    if(IsAdminProcess(D2PID)) {
        if not A_IsAdmin {
            Run *RunAs "%A_AhkPath%" "%A_ScriptFullPath%"
        }
    }
; =================================== ;

; Game Window Initialization
; =================================== ;
    ; will be coordinates of destinys client area (actual game window not including borders)
    global DESTINY_X := 0
    global DESTINY_Y := 0
    global DESTINY_WIDTH := 0
    global DESTINY_HEIGHT := 0
    global D2_WINDOW_HANDLE := -1

    find_d2(1)

    if (DESTINY_WIDTH > 1280 || DESTINY_HEIGHT > 720) ; make sure they are actually on windowed mode :D
    {
        MsgBox, % "This script is only designed to work with the game in windowed and a resolution of 1280x720. Your resolution is " DESTINY_WIDTH "x" DESTINY_HEIGHT "."
        ExitApp
    }
; =================================== ;

; Init for non standard AHK stuff
; =================================== ;
; (d)ynamic function to allow execution while zipped
    global dGdip_Startup := "Gdip_Startup"
    global dGdip_BitmapFromScreen := "Gdip_BitmapFromScreen"
    global dGdip_GetPixel := "Gdip_GetPixel"
    global dGdip_DisposeImage := "Gdip_DisposeImage"
    global dGdip_SaveBitmapToFile := "Gdip_SaveBitmapToFile"

    pToken := %dGdip_Startup%()

    global DEBUG := false

    global CHEST_PID, EXOTIC_PID

    ; Controller Stuff
    vigemwrapperdllsetup()      ; vigemwrapper dll setup used for tabbed out controller support
    global 360Controller := new ViGEmXb360()   ; vigem controller setup used for tabbed out 
; =================================== ;

; Data Initialization
; =================================== ;
    global CURRENT_GUARDIAN := "Hunter"
    global CURRENT_SLOT := "Top"
    global TOTALS_DISPLAY := "All"
    global HIDE_GUI := 0
    global ENABLE_TABBEDOUT := 0
    global CLASSES := ["Hunter", "Titan", "Warlock"]
    global CHARACTER_SLOTS := ["Top", "Middle", "Bottom"]
    global AACHEN_CHOICES := ["Kinetic", "Void"]
    global CLASS_STAT_TYPES := ["current_runs", "total_runs", "current_exotics", "total_exotics", "current_time", "total_time"]
    global CHEST_STAT_TYPES := ["current_appearances", "total_appearances", "current_pickups", "total_pickups"]
    global CHEST_IDS := ["21", "20", "17", "19", "18", "16"]

    global PLAYER_DATA := {}

    for _, class_type in CLASSES {
        PLAYER_DATA[class_type] := {"Settings": {}, "ClassStats": {}, "ChestStats": {}}
    
        PLAYER_DATA[class_type]["Settings"]["Slot"] := "Top"
        PLAYER_DATA[class_type]["Settings"]["Aachen"] := "Kinetic"
    
        for _, class_stat_type in CLASS_STAT_TYPES {
            PLAYER_DATA[class_type]["ClassStats"][class_stat_type] := 0
        }
    
        for _, chest_id in CHEST_IDS {
            PLAYER_DATA[class_type]["ChestStats"][chest_id] := {}
            for _, chest_stat_type in CHEST_STAT_TYPES {
                PLAYER_DATA[class_type]["ChestStats"][chest_id][chest_stat_type] := 0
            }
        }
    }

    global CURRENT_LOOP_START_TIME := 0

    global CHEST_OPENED := false
    global EXOTIC_DROP := false
    
    global API_URL := "https://api.zenairo.com/d2/heartbeat"
    global HEARTBEAT_ON := false

    global RECORDED_RUNTIME := 0
    global RECORDED_LOOPS := 0
    global RECORDED_CHESTS := 0
    global RECORDED_EXOTICS := 0
    
    read_ini()
; =================================== ;

; Stats GUI
; =================================== ;
    ; Offsets for Overlay class
    OVERLAY_OFFSET_X := DESTINY_X
    OVERLAY_OFFSET_Y := DESTINY_Y
    global GUI_VISIBLE := false

    ; background for all the stats
    Gui, info_BG: +E0x20 -Caption -Border +hWndExtraInfoBGGUI +ToolWindow
    Gui, info_BG: Color, 292929
    Gui, info_BG: Show, % "x" destiny_x-350 " y" destiny_y " w" 350 * dpiInverse " h" DESTINY_HEIGHT+1 " NA"
    Winset, Region, % "w500 h" DESTINY_HEIGHT+1 " 0-0 r15-15", ahk_id %ExtraInfoBGGUI%
    WinSet, Transparent, 255, ahk_id %ExtraInfoBGGUI%

    ; label text (wont change ever)
    label_version := new Overlay("label_version", "v" . VERSION, -340, 4, 4, 10, False, 0xFFFFFF)
    label_current := new Overlay("label_current", "Current Session Stats:", -340, 60, 1, 14, False, 0xFFFFFF)
    label_total := new Overlay("label_total", "Total AFK Stats (" . (TOTALS_DISPLAY = "All" ? "All" : CURRENT_GUARDIAN) . "):", -340, 425, 1, 14, False, 0xFFFFFF)
    label_start_hotkey := new Overlay("label_start_hotkey", "F3: Start", 10, DESTINY_HEIGHT+15, 1, 18, False, 0xFFFFFF, true, 0x292929, 15)
    label_stop_hotkey := new Overlay("label_stop_hotkey", "F4: Reload", 130, DESTINY_HEIGHT+15, 1, 18, False, 0xFFFFFF, true, 0x292929, 15)
    label_close_hotkey := new Overlay("label_close_hotkey", "F5: Close", 275, DESTINY_HEIGHT+15, 1, 18, False, 0xFFFFFF, true, 0x292929, 15)
    label_center_d2_hotkey := new Overlay("label_center_d2_hotkey", "F6: Center D2", 405, DESTINY_HEIGHT+15, 1, 18, False, 0xFFFFFF, true, 0x292929, 15)
    label_startTO_hotkey := new Overlay("label_startTO_hotkey", "F9: Settings", 580, DESTINY_HEIGHT+15, 1, 18, False, 0xFFFFFF, true, 0x292929, 15)
    ; extra info gui stuff 
    global info_ui := new Overlay("info_ui", "Doing Nothing :3", -340, 28, 1, 18, False, 0xFFFFFF)
    global runs_till_orbit_ui := new Overlay("runs_till_orbit_ui", "Runs till next orbit - 0", -340, 120, 1, 16, False, 0xFFFFFF)

    global current_class := new Overlay("current_class", "Class - " . CURRENT_GUARDIAN . " | Slot - " CURRENT_SLOT , -340, 90, 1, 14, False, 0xFFFFFF)
    global current_time_afk_ui := new Overlay("current_time_afk_ui", "Time AFK - !timer11101", -340, 150, 1, 16, False, 0xFFFFFF) 
    global current_runs_ui := new Overlay("current_runs_ui", "Runs - 0", -340, 180, 1, 16, False, 0xFFFFFF) 
    global current_chests_ui := new Overlay("current_chests_ui", "Chests - 0", -340, 210, 1, 16, False, 0xFFFFFF) 
    global current_exotics_ui := new Overlay("current_exotics_ui", "Exotics - 0", -340, 240, 1, 16, False, 0xFFFFFF) 
    global current_exotic_drop_rate_ui := new Overlay("current_exotic_drop_rate_ui", "Exotic Drop Rate - 0.00%", -340, 270, 1, 16, False, 0xFFFFFF) 
    global current_average_loop_time_ui := new Overlay("current_average_loop_time_ui", "Average Loop Time - 0:00.00", -340, 300, 1, 16, False, 0xFFFFFF) 
    global current_missed_chests_percent_ui := new Overlay("current_missed_chests_percent_ui", "Percent Chests Missed - 0.00%", -340, 330, 1, 16, False, 0xFFFFFF) 
    global current_chest_counters1 := new Overlay("current_chest_counters1", "21:[---/---]  20:[---/---]  17:[---/---]", -340, 360, 4, 10, False, 0xFFFFFF) 
    global current_chest_counters2 := new Overlay("current_chest_counters2", "19:[---/---]  18:[---/---]  16:[---/---]", -340, 380, 4, 10, False, 0xFFFFFF) 

    global total_time_afk_ui := new Overlay("total_time_afk_ui", "Time AFK - !timer11101", -340, 455, 1, 16, False, 0xFFFFFF) 
    global total_runs_ui := new Overlay("total_runs_ui", "Runs - 0", -340, 485, 1, 16, False, 0xFFFFFF) 
    global total_chests_ui := new Overlay("total_chests_ui", "Chests - 0", -340, 515, 1, 16, False, 0xFFFFFF) 
    global total_exotics_ui := new Overlay("total_exotics_ui", "Exotics - 0", -340, 545, 1, 16, False, 0xFFFFFF) 
    global total_exotic_drop_rate_ui := new Overlay("total_exotic_drop_rate_ui", "Exotic Drop Rate - 0.00%", -340, 575, 1, 16, False, 0xFFFFFF) 
    global total_average_loop_time_ui := new Overlay("total_average_loop_time_ui", "Average Loop Time - 0:00.00", -340, 605, 1, 16, False, 0xFFFFFF) 
    global total_missed_chests_percent_ui := new Overlay("total_missed_chests_percent_ui", "Percent Chests Missed - 0.00%", -340, 635, 1, 16, False, 0xFFFFFF) 
    global total_chest_counters1 := new Overlay("total_chest_counters1", "21:[---/---]  20:[---/---]  17:[---/---]", -340, 665, 4, 10, False, 0xFFFFFF) 
    global total_chest_counters2 := new Overlay("total_chest_counters2", "19:[---/---]  18:[---/---]  16:[---/---]", -340, 685, 4, 10, False, 0xFFFFFF) 

    global overlay_elements := [label_version, label_total, label_current, label_start_hotkey, label_stop_hotkey, label_close_hotkey, label_center_d2_hotkey, label_startTO_hotkey, info_ui, runs_till_orbit_ui, current_class, current_time_afk_ui, current_runs_ui, current_chests_ui, current_exotics_ui, current_exotic_drop_rate_ui, current_average_loop_time_ui, current_missed_chests_percent_ui, current_chest_counters1, current_chest_counters2, total_time_afk_ui, total_runs_ui, total_chests_ui, total_exotics_ui, total_exotic_drop_rate_ui, total_average_loop_time_ui, total_missed_chests_percent_ui, total_chest_counters1, total_chest_counters2]

    toggle_gui("show")

    total_time_afk_ui.update_content("Time AFK - " format_timestamp(compute_total_stat("time"), true, true, true, false))
    update_ui()
; =================================== ;


; =================================== ;

; Keybind loading
; =================================== ; 
    keys_we_press := [
        ,"hold_zoom"
        ,"primary_weapon"
        ,"special_weapon"
        ,"heavy_weapon"
        ,"move_forward"
        ,"move_backward"
        ,"move_left"
        ,"move_right"
        ,"jump"
        ,"toggle_sprint"
        ,"interact"
        ,"ui_open_director" ; map
        ,"ui_open_start_menu_settings_tab"]

    global key_binds := get_d2_keybinds(keys_we_press) ; this gives us a dictionary of keybinds

    for key, value in key_binds ; make sure the keybinds are set (except for settings, dont technically need that one but having it bound speeds it up)
    {
        if (!value)
        {
            if (key != "ui_open_start_menu_settings_tab")
            {
                MsgBox, % "You need to set the keybind for " key " in the game settings."
                ExitApp
            }
        }
    }
; =================================== ;

;WinActivate, Destiny 2

gosub, settingsgui

global STARTUP_SUCCESSFUL := true

Return

; Hotkeys
; =================================== ;

    F3:: ; main hotkey that runs the script
    {
        if(ENABLE_TABBEDOUT)
            gosub, tabbedout
        else
            gosub, tabbedin
    }


    F4:: ; reload the script, release any possible held keys, save stats
    {
        Reload
        Return
    }

    F5:: ; same thing but close the script
    {
        for key, value in key_binds 
            send, % "{" value " Up}"
        ExitApp
    }

    F6::
    {
        WinGetPos,,, Width, Height, ahk_exe destiny2.exe
        WinMove, ahk_exe destiny2.exe,, (A_ScreenWidth/2)-((Width-(350 * dpiInverse))/2), (A_ScreenHeight/2)-(Height/2)
        Sleep 1000
        ; we also want it to reload script so gui is in the right spot
        Reload
        Return
    }

    F9::
    {
        if (winexist("user_input")) {
            gui user_input: show
        } else {
            HIDE_GUI := 0
            gosub, settingsgui
        }
        Return
    }

    F10::
    {
        360Controller := ""
        MsgBox, Check Device Manager
        Return
    }

Return
; =================================== ;

; Main Functions (run the script)
; =================================== ;
    tabbedin:
    {
        if (!INPUT_POPUP_HANDLED)
            Return

        ; Timers during the farm loop cause random interrupts during timing sensitive areas
        SetTimer, check_tabbed_out, Off 
        DetectHiddenWindows, On
        WinGet, MainPID, PID, %A_ScriptFullPath% - AutoHotkey v
        ; Start the child scripts
        Run, %A_AhkPath% "./_Libraries/monitor_loot.ahk" %MainPID% "chest", , , CHEST_PID
        Run, %A_AhkPath% "./_Libraries/monitor_loot.ahk" %MainPID% "exotic", , , EXOTIC_PID
        
        HEARTBEAT_ON := true
        send_heartbeat()

        info_ui.update_content("Starting chest farm")
        WinActivate, ahk_exe destiny2.exe ; make sure destiny is active window
        set_fireteam_privacy("closed")
        PreciseSleep(1000)
        change_character()
        PreciseSleep(500)
        loop, ; loop until we actually load in lol
        {
            if (orbit_landing())
                break
            PreciseSleep(500)
            change_character()
            PreciseSleep(500)
        }
        loop_successful := false
        CURRENT_LOOP_START_TIME := A_TickCount
        current_time_afk_ui.toggle_timer("start")
        total_time_afk_ui.update_content("Time AFK - !timer11101") ; yippee there is a LOT of just ui stuff in here for updating the stats
        total_time_afk_ui.toggle_timer("start")
        total_time_afk_ui.add_time(compute_total_stat("time"), false)
        info_ui.update_content("Loading in")
        PreciseSleep(15000)

        loop, ; Orbit loop
        {
            remaining_runs := 20 ; Initialize the remaining runs counter
            remaining_chests := 40 ; use this to know how many loops to do before we reach overthrow level 2
            runs_till_orbit_ui.update_content("Runs till next orbit - " Ceil(remaining_chests/2))
            loop, ; Run landing loop (break out of this if overthrow L2)
            {
                if (loop_successful) ; Reset the time only if the loop made it to the end.
                {
                    CURRENT_LOOP_START_TIME := A_TickCount
                    loop_successful := false
                }
                if (!wait_for_spawn(45000)) ; if we dont spawn in, change character and try again
                {
                    info_ui.update_content("Didn't detect spawn in :(")
                    PreciseSleep(5000)
                    break
                }
                WinActivate, ahk_exe destiny2.exe ; really make sure we are tabbed in
                info_ui.update_content("Waiting for chest spawns")
                PreciseSleep(1000)
                if (PLAYER_DATA[CURRENT_GUARDIAN]["Settings"]["Aachen"] == "Kinetic")
                    Send, % "{" key_binds["primary_weapon"] "}" ; make sure aachen is equipped
                else 
                    Send, % "{" key_binds["special_weapon"] "}"
                PreciseSleep(1000)
                chest_spawns := force_first_chest() ; go to first corner and get chest spawns
                if (!chest_spawns[1]) ; if no first chest we relaunch
                {
                    WinActivate, ahk_exe destiny2.exe ; triple check, just in case
                    reload_landing()
                    update_ui()
                    continue
                }
                info_ui.update_content("Going to chests - " chest_spawns[1] " and " chest_spawns[2])
                log_chest("appearance", chest_spawns[1])
                group_5_chest_opened := group_5_chests() ; open chest 21 if its spawned
                if (group_5_chest_opened)
                {
                    log_chest("pickup", chest_spawns[1])
                    remaining_chests--
                }
                update_chest_ui()

                if (chest_spawns[2]) ; open the second chest (one from group 4)
                {
                    log_chest("appearance", chest_spawns[2])
                    group_4_chest_opened := group_4_chests(chest_spawns[2])
                    if (group_4_chest_opened)
                    {
                        log_chest("pickup", chest_spawns[2])
                        remaining_chests--
                    }
                    update_chest_ui()
                }
                WinActivate, ahk_exe destiny2.exe ; make absolutely, positively, certain we are tabbed in

                StopMonitoring(EXOTIC_PID)
                if (EXOTIC_DROP)
                    PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["current_exotics"]++
                EXOTIC_DROP := false
                
                ; Run completion
                loop_successful := true
                PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["current_runs"]++
                PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["current_time"] += A_TickCount - CURRENT_LOOP_START_TIME

                ; Decrease the remaining runs counter
                remaining_runs--

                ; UI updates
                runs_till_orbit_ui.update_content("Runs till next orbit - " remaining_runs)
                update_ui()

                if (remaining_runs > 0)
                {
                    info_ui.update_content("Relaunching Landing")
                    reload_landing()
                }

                send_heartbeat()
                
                if (remaining_runs <= 0)
                    break
            }
            info_ui.update_content("Orbit and relaunch") ; opened 40 chests, time to orbit and relaunch
            WinActivate, ahk_exe destiny2.exe ; one more for good measure
            change_character()
            PreciseSleep(500)
            loop, ; same thing as start, go until we actually start loading in
            {
                if (orbit_landing())
                    break
                PreciseSleep(500)
                change_character()
                PreciseSleep(500)
            }
            PreciseSleep(30000)

            ; Reset remaining runs for next orbit loop
            remaining_runs := 20
            
            ; Keep the user's heartbeat alive as orbit_landing takes more time than a normal loop.
            send_heartbeat()
        }
        Return
    }

    tabbedout:
    {
        if (!INPUT_POPUP_HANDLED)
            Return

        ; Timers during the farm loop cause random interrupts during timing sensitive areas
        SetTimer, check_tabbed_out, Off 
        
        DetectHiddenWindows, On
        WinGet, MainPID, PID, %A_ScriptFullPath% - AutoHotkey
        ; Start the child scripts
    
        Run, %A_AhkPath% "./_Libraries/monitor_loot.ahk" %MainPID% "chest", , Min , CHEST_PID
        Run, %A_AhkPath% "./_Libraries/monitor_loot.ahk" %MainPID% "exotic", , Min , EXOTIC_PID
        

        HEARTBEAT_ON := true
        send_heartbeat()
        info_ui.update_content("Starting chest farm")
        set_fireteam_privacy("closed",1) ;; second value sets to tabbed out mode
        PreciseSleep(1000)
        change_character("",1)
        PreciseSleep(500)
        loop, ; loop until we actually load in lol
        {
            if (orbit_landing(1))
                break
            PreciseSleep(500)
            change_character("",1)
            PreciseSleep(500)
        }
        loop_successful := false
        CURRENT_LOOP_START_TIME := A_TickCount
        current_time_afk_ui.toggle_timer("start")
        total_time_afk_ui.update_content("Time AFK - !timer11101") ; yippee there is a LOT of just ui stuff in here for updating the stats
        total_time_afk_ui.toggle_timer("start")
        total_time_afk_ui.add_time(compute_total_stat("time"), false)
        info_ui.update_content("Loading in")
        PreciseSleep(15000)

        loop, ; Orbit loop
        {
            remaining_runs := 20 ; Initialize the remaining runs counter
            remaining_chests := 40 ; use this to know how many loops to do before we reach overthrow level 2
            ;runs_till_orbit_ui.update_content("Runs till next orbit - " Ceil(remaining_chests/2))
            runs_till_orbit_ui.update_content("Runs till next orbit - " remaining_runs)
            loop, ; Run landing loop (break out of this if overthrow L2)
            {
                if (loop_successful) ; Reset the time only if the loop made it to the end.
                {
                    CURRENT_LOOP_START_TIME := A_TickCount
                    loop_successful := false
                }
                info_ui.update_content("Waiting for Loadin")
                if (!wait_for_spawn(45000)) ; if we dont spawn in, change character and try again
                {
                    info_ui.update_content("Didn't detect spawn in :(")
                    PreciseSleep(5000)
                    break
                }
                info_ui.update_content("Waiting for chest spawns")
                PreciseSleep(1000)
                if (PLAYER_DATA[CURRENT_GUARDIAN]["Settings"]["Aachen"] == "Kinetic")
                    controller_sniper()
                else 
                    controller_sniper(1)

                PreciseSleep(500)
                TO_force_chest() ; go to first corner and get chest spawns
                PreciseSleep(3000)

                if (!TO_find_chest21()) ; if no first chest we relaunch
                {
                    reload_landing(1)
                    update_ui()
                    continue
                }
                info_ui.update_content("Going to chest 21")
                log_chest("appearance", 21)
                group_5_chest_opened := TO_run_to_chest21() ; open chest 21 if its spawned
                if (group_5_chest_opened)
                {
                    log_chest("pickup", 21)
                    remaining_chests--
                }
                update_chest_ui()

                G4Chest := TO_find_g4_chests()
                if(G4Chest) ; open the second chest (one from group 4)
                {
                    info_ui.update_content("Going to chest " G4Chest)
                    log_chest("appearance", G4Chest)
                    group_4_chest_opened := TO_run_to_G4_chest(G4Chest)
                    if (group_4_chest_opened)
                    {
                        log_chest("pickup", G4Chest)
                        remaining_chests--
                    }
                    update_chest_ui()
                }

                
                StopMonitoring(EXOTIC_PID)
                if (EXOTIC_DROP)
                    PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["current_exotics"]++
                EXOTIC_DROP := false
                
                ; Run completion
                loop_successful := true
                PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["current_runs"]++
                PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["current_time"] += A_TickCount - CURRENT_LOOP_START_TIME

                ; Decrease the remaining runs counter
                remaining_runs--

                ; UI updates
                runs_till_orbit_ui.update_content("Runs till next orbit - " remaining_runs)
                update_ui()

                if (remaining_runs > 0)
                {
                    info_ui.update_content("Relaunching Landing")
                    reload_landing(1)
                }

                send_heartbeat()
                
                ; Also break out if runs = 20 as fallback for not tracking chests
                if (remaining_runs <= 0)
                    break
            }
            info_ui.update_content("Orbit and relaunch") ; opened 40 chests, time to orbit and relaunch
            change_character("",1)
            PreciseSleep(500)
            loop, ; same thing as start, go until we actually start loading in
            {
                if (orbit_landing(1))
                    break
                PreciseSleep(500)
                change_character("",1)
                PreciseSleep(500)
            }
            PreciseSleep(30000)

            ; Reset remaining runs for next orbit loop
            remaining_runs := 20
            
            ; Keep the user's heartbeat alive as orbit_landing takes more time than a normal loop.
            send_heartbeat()
        }
        Return
    }
; =================================== ;

; Chest Functions
; =================================== ;
    force_first_chest() ; walk to the corner to guarantee chest 21 spawns, also calls find_chests to, yknow, find teh chests :P
    {   
        WinActivate, ahk_exe destiny2.exe
        PreciseSleep(20)
        DllCall("mouse_event", uint, 1, int, 9091, int, 0) ; do 2 360s because yeah
        PreciseSleep(10)
        DllCall("mouse_event", uint, 1, int, -9091, int, 0)
        PreciseSleep(10)
        Send, % "{" key_binds["hold_zoom"] " Down}"
        PreciseSleep(50)
        Send, % "{" key_binds["hold_zoom"] " Up}"
        PreciseSleep(140)
        DllCall("mouse_event", uint, 1, int, -840, int, 0)
        Send, % "{" key_binds["move_forward"] " Down}"
        Send, % "{" key_binds["toggle_sprint"] " Down}"
        PreciseSleep(8000)
        Send, % "{" key_binds["toggle_sprint"] " Up}"
        Send, % "{" key_binds["move_forward"] " Up}"
        PreciseSleep(1000)
        DllCall("mouse_event", uint, 1, int, 2840, int, 0)
        Send, % "{" key_binds["move_forward"] " Down}"
        PreciseSleep(3000)
        Send, % "{" key_binds["move_forward"] " Up}"
        PreciseSleep(11000)
        Return find_chests()
    }

    find_chests() ; figures out which chest in group 4 is spawned and also waits for chest 21 to spawn
    {
        ; group 5 is chests 21,22, 23, 24, 25
        ; group 4 is chests 16, 17, 18, 19, 20
        ; group 3 is chests 11, 12, 13, 14, 15 (probably wont be used)
        ; group 2 is chests 6, 7, 8, 9, 10 (probably wont be used)
        ; group 1 is chests 1, 2, 3, 4, 5 (probably wont be used)

        forced_chest_x := 1755
        forced_chest_y := -50

        ; 16, 17, 18, 19, 20
        group_4_x_coords := [-4585, -275, -1963, -3436, 3470]
        group_4_y_coords := [-102, -1033, -55, -710, -1038]

        ; 11, 12, 13, 14, 15 (these are outdated, would need ot be updated to use anyways lol)
        group_3_x_coords := [-12220, -6810, -12430, -19130, -19580]
        group_3_y_coords := [-290, -300, 920, 680, 990]

        all_chests_found := false
        ; group 5, 4, 3 (not doing third chest group for now)
        chest_spots := [0, 0]

        Send, % "{" key_binds["hold_zoom"] " Down}"
        PreciseSleep(700)

        look_delay := 100
        started_looking := A_TickCount

        while (not all_chests_found) ; basically just loop until chests are all found (group 4 chest and also chest 21)
        {
            for index, chest in chest_spots ; make it so we dont have to check groups that already have foud chests
            {
                if (chest) 
                    continue
                if (index == 1)
                {
                    DllCall("mouse_event",uint,1,int,forced_chest_x,int,forced_chest_y)
                    PreciseSleep(look_delay)
                    if (simpleColorCheck("629|365|23|19", 23, 19) > 0.15) ; this looks where the chest icon would appear if it spawns and checks for white pixels, it can sometimes mess up if some very specific things spawn in
                        chest_spots[index] := 21
                    PreciseSleep(look_delay)
                    DllCall("mouse_event",uint,1,int,-forced_chest_x,int,-forced_chest_y)
                }
                else if (index == 2)
                {
                    loop, 5
                    {
                        DllCall("mouse_event",uint,1,int,group_4_x_coords[A_Index],int,group_4_y_coords[A_Index])
                        PreciseSleep(look_delay)
                        if (simpleColorCheck("629|365|23|19", 23, 19) > 0.15)
                        {
                            chest_spots[index] := 15 + A_Index
                            PreciseSleep(look_delay)
                            DllCall("mouse_event",uint,1,int,-group_4_x_coords[A_Index],int,-group_4_y_coords[A_Index])
                            break
                        }
                        PreciseSleep(look_delay)
                        DllCall("mouse_event",uint,1,int,-group_4_x_coords[A_Index],int,-group_4_y_coords[A_Index])
                    }
                }
                else if (index == 3) ; this checks for which group 3 chest spawns :D (we dont use it right now (or probably ever))
                {
                    loop, 5
                    {
                        DllCall("mouse_event",uint,1,int,group_3_x_coords[A_Index],int,group_3_y_coords[A_Index])
                        PreciseSleep(look_delay)
                        if (simpleColorCheck("629|365|23|19", 23, 19) > 0.15)
                        {
                            chest_spots[index] := 10 + A_Index
                            PreciseSleep(look_delay)
                            DllCall("mouse_event",uint,1,int,-group_3_x_coords[A_Index],int,-group_3_y_coords[A_Index])
                            break
                        }
                        PreciseSleep(look_delay)
                        DllCall("mouse_event",uint,1,int,-group_3_x_coords[A_Index],int,-group_3_y_coords[A_Index])
                    }
                }
            if (chest_spots[1] && chest_spots[2])
                all_chests_found := true
            }
            if (A_TickCount - started_looking > 20000) ; stop looking focefully after 20 seconds of looking
                break
        }
        PreciseSleep(100)
        Send, % "{" key_binds["hold_zoom"] " Up}"
        PreciseSleep(700)
        Return chest_spots
    }

    group_5_chests(chest_number:=21) ; picks up chest 21
    {
        group_5_chest_opened := false
        CHEST_OPENED := false
        ; we can force only chest 21 to spawn every time, so we will do that
        Send, % "{" key_binds["move_backward"] " Down}"
        PreciseSleep(200)
        Send, % "{" key_binds["move_backward"] " Up}"
        PreciseSleep(100)
        Send, % "{" key_binds["move_right"] " Down}"
        PreciseSleep(235)
        Send, % "{" key_binds["move_right"] " Up}"
        PreciseSleep(300)
        DllCall("mouse_event", uint, 1, int, 530, int, 0)
        Send, % "{" key_binds["move_forward"] " Down}"
        Send, % "{" key_binds["toggle_sprint"] " Down}"
        PreciseSleep(6400)
        DllCall("mouse_event", uint, 1, int, -980, int, 0)
        PreciseSleep(3300)
        Send, % "{" key_binds["toggle_sprint"] " Up}"
        Send, % "{" key_binds["move_forward"] " Up}"
        PreciseSleep(200)
        Send, % "{" key_binds["move_left"] " Down}"
        Send, % "{" key_binds["move_backward"] " Down}"
        PreciseSleep(1000)
        Send, % "{" key_binds["move_backward"] " Up}"
        Send, % "{" key_binds["move_left"] " Up}"
        DllCall("mouse_event", uint, 1, int, 4200, int, 400)
        StartMonitoring(CHEST_PID)
        StartMonitoring(EXOTIC_PID)
        PreciseSleep(1000)
        get_screenshot("21_tabbedin")
        Send, % "{" key_binds["interact"] " Down}"
        PreciseSleep(1100)
        Send, % "{" key_binds["interact"] " Up}"
        if (CHEST_OPENED)
            group_5_chest_opened := true
        else 
            StopMonitoring(CHEST_PID)
        CHEST_OPENED := false
        DllCall("mouse_event", uint, 1, int, -4400, int, -500)
        Return group_5_chest_opened
    }

    group_4_chests(chest_number) ; picks up chests 16-20 
    {
        group_4_chest_opened := false
        if (!chest_number)
            Return group_4_chest_opened
        Send, % "{" key_binds["move_right"] " Down}"
        PreciseSleep(400)
        Send, % "{" key_binds["move_right"] " Up}"
        PreciseSleep(100)
        DllCall("mouse_event", uint, 1, int, 350, int, 0)
        PreciseSleep(100)
        Send, % "{" key_binds["move_forward"] " Down}"
        Send, % "{" key_binds["toggle_sprint"] " Down}"
        PreciseSleep(1200)
        ; Stop exotic tracking and record the previous.
        StopMonitoring(EXOTIC_PID)
        if (EXOTIC_DROP)
            PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["current_exotics"]++
        EXOTIC_DROP := false
        PreciseSleep(1200)
        Send, % "{" key_binds["toggle_sprint"] " Up}"
        Send, % "{" key_binds["move_forward"] " Up}"
        PreciseSleep(200)

        if (chest_number == 20)
        {
            if (CURRENT_GUARDIAN == "Hunter")
            {
                DllCall("mouse_event", uint, 1, int, 2535, int, 400)
                Send, % "{" key_binds["jump"] " Down}"
                PreciseSleep(400)
                Send, % "{" key_binds["jump"] " Up}"
                PreciseSleep(100)
                Send, % "{" key_binds["jump"] " Down}"
                PreciseSleep(500)
                Send, % "{" key_binds["move_forward"] " Down}"
                PreciseSleep(100)
                Send, % "{" key_binds["jump"] " Up}"
                PreciseSleep(100)
                Send, % "{" key_binds["jump"] " Down}"
                PreciseSleep(600)
                Send, % "{" key_binds["jump"] " Up}"
                PreciseSleep(100)
                Send, % "{" key_binds["toggle_sprint"] " Down}"
                StartMonitoring(CHEST_PID)
                Send, % "{" key_binds["interact"] " Down}"
                Send, % "{" key_binds["heavy_weapon"] "}"
                PreciseSleep(2210)
                Send, % "{" key_binds["toggle_sprint"] " Up}"
                Send, % "{" key_binds["move_forward"] " Up}"
                DllCall("mouse_event", uint, 1, int, 130, int, 500)
                PreciseSleep(1300)
                StartMonitoring(EXOTIC_PID)
                Send, % "{" key_binds["interact"] " Up}"
            }
            else if (CURRENT_GUARDIAN == "Warlock")
            {
                DllCall("mouse_event", uint, 1, int, 2535, int, 400)
                Send, % "{" key_binds["jump"] "}"
                PreciseSleep(100)
                Send, % "{" key_binds["jump"] "}"
                PreciseSleep(500)
                Send, % "{" key_binds["move_forward"] " Down}"
                PreciseSleep(1200)
                Send, % "{" key_binds["jump"] "}"
                PreciseSleep(100)
                Send, % "{" key_binds["toggle_sprint"] " Down}"
                StartMonitoring(CHEST_PID)
                Send, % "{" key_binds["interact"] " Down}"
                Send, % "{" key_binds["heavy_weapon"] "}"
                PreciseSleep(2400)
                Send, % "{" key_binds["toggle_sprint"] " Up}"
                Send, % "{" key_binds["move_forward"] " Up}"
                DllCall("mouse_event", uint, 1, int, 130, int, 450)
                PreciseSleep(1300)
                StartMonitoring(EXOTIC_PID)
                Send, % "{" key_binds["interact"] " Up}"
            }
            else 
            {
                DllCall("mouse_event", uint, 1, int, 2535, int, 400)
                Send, % "{" key_binds["jump"] " Down}"
                PreciseSleep(400)
                Send, % "{" key_binds["jump"] "}"
                PreciseSleep(100)
                Send, % "{" key_binds["jump"] "}"
                PreciseSleep(500)
                Send, % "{" key_binds["move_forward"] " Down}"
                PreciseSleep(800)
                Send, % "{" key_binds["jump"] "}"
                PreciseSleep(100)
                Send, % "{" key_binds["toggle_sprint"] " Down}"
                StartMonitoring(CHEST_PID)
                Send, % "{" key_binds["interact"] " Down}"
                Send, % "{" key_binds["heavy_weapon"] "}"
                PreciseSleep(2350)
                Send, % "{" key_binds["toggle_sprint"] " Up}"
                Send, % "{" key_binds["move_forward"] " Up}"
                DllCall("mouse_event", uint, 1, int, 130, int, 450)
                PreciseSleep(1300)
                StartMonitoring(EXOTIC_PID)
                Send, % "{" key_binds["interact"] " Up}"
            }
        }
        else if (chest_number == 17)
        {
            if (CURRENT_GUARDIAN == "Hunter")
            {
                DllCall("mouse_event", uint, 1, int, -3350, int, 400)
                Send, % "{" key_binds["move_forward"] " Down}"
                Send, % "{" key_binds["jump"] " Down}"
                PreciseSleep(600)
                Send, % "{" key_binds["jump"] " Up}"
                PreciseSleep(100)
                Send, % "{" key_binds["jump"] " Down}"
                PreciseSleep(600)
                Send, % "{" key_binds["jump"] " Up}"
                PreciseSleep(100)
                Send, % "{" key_binds["jump"] " Down}"
                PreciseSleep(600)
                Send, % "{" key_binds["jump"] " Up}"
                PreciseSleep(100)
                Send, % "{" key_binds["toggle_sprint"] " Down}"
                DllCall("mouse_event", uint, 1, int, -380, int, 400)
                Send, % "{" key_binds["heavy_weapon"] "}"
                PreciseSleep(1250)
                Send, % "{" key_binds["toggle_sprint"] " Up}"
                StartMonitoring(CHEST_PID)
                Send, % "{" key_binds["interact"] " Down}"
                Send, % "{" key_binds["move_forward"] " Up}"
                PreciseSleep(1300)
                StartMonitoring(EXOTIC_PID)
                Send, % "{" key_binds["interact"] " Up}"
            }
            else if (CURRENT_GUARDIAN == "Warlock")
            {
                DllCall("mouse_event", uint, 1, int, -3350, int, 400)
                Send, % "{" key_binds["move_forward"] " Down}"
                Send, % "{" key_binds["jump"] "}"
                PreciseSleep(100)
                Send, % "{" key_binds["jump"] "}"
                PreciseSleep(1300)
                Send, % "{" key_binds["jump"] "}"
                PreciseSleep(700)
                Send, % "{" key_binds["toggle_sprint"] " Down}"
                DllCall("mouse_event", uint, 1, int, -400, int, 400)
                Send, % "{" key_binds["heavy_weapon"] "}"
                PreciseSleep(900)
                Send, % "{" key_binds["toggle_sprint"] " Up}"
                StartMonitoring(CHEST_PID)
                Send, % "{" key_binds["interact"] " Down}"
                Send, % "{" key_binds["move_forward"] " Up}"
                PreciseSleep(1300)
                StartMonitoring(EXOTIC_PID)
                Send, % "{" key_binds["interact"] " Up}"
            }
            else
            {
                DllCall("mouse_event", uint, 1, int, -3350, int, 400)
                Send, % "{" key_binds["move_forward"] " Down}"
                Send, % "{" key_binds["jump"] "}"
                PreciseSleep(100)
                Send, % "{" key_binds["jump"] "}"
                PreciseSleep(1300)
                Send, % "{" key_binds["jump"] "}"
                PreciseSleep(700)
                Send, % "{" key_binds["toggle_sprint"] " Down}"
                DllCall("mouse_event", uint, 1, int, -400, int, 400)
                Send, % "{" key_binds["heavy_weapon"] "}"
                PreciseSleep(1055)
                Send, % "{" key_binds["toggle_sprint"] " Up}"
                StartMonitoring(CHEST_PID)
                Send, % "{" key_binds["interact"] " Down}"
                Send, % "{" key_binds["move_forward"] " Up}"
                PreciseSleep(1300)
                StartMonitoring(EXOTIC_PID)
                Send, % "{" key_binds["interact"] " Up}"
            }
        }
        else if (chest_number == 19)
        {
            if (CURRENT_GUARDIAN == "Hunter")
            {
                DllCall("mouse_event", uint, 1, int, -1410, int, 400)
                Send, % "{" key_binds["move_forward"] " Down}"
                Send, % "{" key_binds["toggle_sprint"] " Down}"
                PreciseSleep(1800)
                Send, % "{" key_binds["jump"] " Down}"
                Send, % "{" key_binds["toggle_sprint"] " Up}"
                PreciseSleep(600)
                Send, % "{" key_binds["jump"] " Up}"
                PreciseSleep(100)
                Send, % "{" key_binds["jump"] " Down}"
                PreciseSleep(600)
                Send, % "{" key_binds["jump"] " Up}"
                PreciseSleep(100)
                Send, % "{" key_binds["jump"] " Down}"
                PreciseSleep(600)
                Send, % "{" key_binds["jump"] " Up}"
                StartMonitoring(CHEST_PID)
                Send, % "{" key_binds["interact"] " Down}"
                DllCall("mouse_event", uint, 1, int, -80, int, 250)
                Send, % "{" key_binds["heavy_weapon"] "}"
                PreciseSleep(2230)
                DllCall("mouse_event", uint, 1, int, 130, int, 250)
                Send, % "{" key_binds["move_forward"] " Up}"
                PreciseSleep(1300)
                StartMonitoring(EXOTIC_PID)
                Send, % "{" key_binds["interact"] " Up}"
            }
            else if (CURRENT_GUARDIAN == "Warlock")
            {
                DllCall("mouse_event", uint, 1, int, -1410, int, 400)
                Send, % "{" key_binds["move_forward"] " Down}"
                Send, % "{" key_binds["toggle_sprint"] " Down}"
                PreciseSleep(1800)
                Send, % "{" key_binds["jump"] "}"
                Send, % "{" key_binds["toggle_sprint"] " Up}"
                PreciseSleep(180)
                Send, % "{" key_binds["jump"] "}"
                PreciseSleep(1600)
                Send, % "{" key_binds["jump"] "}"
                StartMonitoring(CHEST_PID)
                Send, % "{" key_binds["interact"] " Down}"
                DllCall("mouse_event", uint, 1, int, -80, int, 250)
                Send, % "{" key_binds["heavy_weapon"] "}"
                PreciseSleep(2350)
                DllCall("mouse_event", uint, 1, int, 130, int, 250)
                Send, % "{" key_binds["move_forward"] " Up}"
                PreciseSleep(1300)
                StartMonitoring(EXOTIC_PID)
                Send, % "{" key_binds["interact"] " Up}"
            }
            else 
            {
                DllCall("mouse_event", uint, 1, int, -1410, int, 400)
                Send, % "{" key_binds["move_forward"] " Down}"
                Send, % "{" key_binds["toggle_sprint"] " Down}"
                PreciseSleep(1900)
                Send, % "{" key_binds["jump"] "}"
                Send, % "{" key_binds["toggle_sprint"] " Up}"
                PreciseSleep(200)
                Send, % "{" key_binds["jump"] "}"
                PreciseSleep(1600)
                Send, % "{" key_binds["jump"] "}"
                StartMonitoring(CHEST_PID)
                Send, % "{" key_binds["interact"] " Down}"
                DllCall("mouse_event", uint, 1, int, -80, int, 250)
                Send, % "{" key_binds["heavy_weapon"] "}"
                PreciseSleep(2350)
                DllCall("mouse_event", uint, 1, int, 130, int, 250)
                Send, % "{" key_binds["move_forward"] " Up}"
                PreciseSleep(1300)
                StartMonitoring(EXOTIC_PID)
                Send, % "{" key_binds["interact"] " Up}"
            }
        }
        else if (chest_number == 18)
        {
            DllCall("mouse_event", uint, 1, int, -1310, int, 400)
            Send, % "{" key_binds["move_forward"] " Down}"
            Send, % "{" key_binds["toggle_sprint"] " Down}"
            PreciseSleep(3500)
            Send, % "{" key_binds["toggle_sprint"] " Up}"
            DllCall("mouse_event", uint, 1, int, 1200, int, 450)
            PreciseSleep(2800)
            Send, % "{" key_binds["interact"] " Down}"
            StartMonitoring(CHEST_PID)
            Send, % "{" key_binds["heavy_weapon"] "}"
            PreciseSleep(2420)
            Send, % "{" key_binds["move_forward"] " Up}"
            PreciseSleep(1300)
            StartMonitoring(EXOTIC_PID)
            Send, % "{" key_binds["interact"] " Up}"
        }
        else if (chest_number == 16)
        {
            DllCall("mouse_event", uint, 1, int, -1310, int, 400)
            Send, % "{" key_binds["move_forward"] " Down}"
            Send, % "{" key_binds["toggle_sprint"] " Down}"
            PreciseSleep(3500)
            Send, % "{" key_binds["toggle_sprint"] " Up}"
            DllCall("mouse_event", uint, 1, int, 1200, int, 300)
            PreciseSleep(2100)
            DllCall("mouse_event", uint, 1, int, -1570, int, 0)
            PreciseSleep(4200)
            Send, % "{" key_binds["interact"] " Down}"
            StartMonitoring(CHEST_PID)
            DllCall("mouse_event", uint, 1, int, 610, int, 50)
            Send, % "{" key_binds["heavy_weapon"] "}"
            PreciseSleep(1450)
            Send, % "{" key_binds["move_forward"] " Up}"
            DllCall("mouse_event", uint, 1, int, -100, int, 50)
            PreciseSleep(1300)
            StartMonitoring(EXOTIC_PID)
            Send, % "{" key_binds["interact"] " Up}"
        }
        if (CHEST_OPENED)
            group_4_chest_opened := true
        else 
            StopMonitoring(CHEST_PID)
        CHEST_OPENED := false
        Return group_4_chest_opened
    }
; =================================== ;

; Tabbed Out Functions
; =================================== ;

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
            if(TO_color_check("1198|357|25|25",0xFFFFFF) > 0.12)
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
        chest_21_opened := false
        CHEST_OPENED := false

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
        
        StartMonitoring(CHEST_PID)
        StartMonitoring(EXOTIC_PID)
        PreciseSleep(500)

        360Controller.Buttons.X.SetState(true)
        PreciseSleep(1300)
        360Controller.Buttons.X.SetState(false)
        PreciseSleep(50)
        
        if(CHEST_OPENED)
            chest_21_opened := true
        else 
            StopMonitoring(CHEST_PID)
        CHEST_OPENED := False

        Return chest_21_opened

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

        if((TO_color_check("251|137|29|20",0xFFFFFF,"Chest17") > 0.05) || (TO_color_check("285|125|30|20",0xFFFFFF,"Chest17") > 0.05))
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
                if((TO_color_check("245|105|100|50|0.01",0xFFFFFF,"Chest19") > 0.01) || (TO_color_check("340|100|30|20|0.05",0xFFFFFF,"Chest19") > 0.01))
                {
                    chest_found := 19
                    360Controller.Axes.LT.SetState(0)
                    PreciseSleep(1000)
            
                    controller_aim_ver(90,475)      ;; 425
                    controller_aim_hor(10,300)     ;; 2100
                    Return chest_found
                }
            }
            if(A_TickCount - timer_start > 4000)
                break
        }
        timer_start := A_TickCount

        filename := "\ADS\ADS1_" . count
        get_screenshot(filename)

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
                if(TO_color_check(coords,0xFFFFFF,filename) > r)
                {
                    chest_found := g4_chest[A_Index]
                    360Controller.Axes.LT.SetState(0)
                    Return chest_found
                }
            }
            if(A_TickCount - timer_start > 4000)
                break
        }

        360Controller.Axes.LT.SetState(0)
        Return chest_found
    }

    TO_run_to_G4_chest(chest)
    {
        g4_chest_opened := false
        CHEST_OPENED := false
        if(chest != 19)
            chest := 19

        360Controller.Buttons.Y.SetState(True)
        controller_move_hor(100,700)
        360Controller.Buttons.Y.SetState(False)
        controller_aim_hor(85,1000)
        controller_aim_ver(10,475)
        StopMonitoring(EXOTIC_PID)
        if (EXOTIC_DROP)
            PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["current_exotics"]++
        EXOTIC_DROP := false
        controller_sprint(2500)

        if(chest == 17)
        {
            controller_sprint(1250)
            controller_aim_hor(10,2100)
            controller_sprint(1000)
            if(CURRENT_GUARDIAN == "Warlock")
            {
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
            }
            else if(CURRENT_GUARDIAN == "Hunter")
            {
                360Controller.Buttons.LS.SetState(True)
                360Controller.Axes.LY.SetState(100)
                PreciseSleep(100)
                360Controller.Buttons.A.SetState(True)
                PreciseSleep(500)
                360Controller.Buttons.A.SetState(False)
                PreciseSleep(50)
                360Controller.Buttons.A.SetState(True)
                PreciseSleep(500)
                360Controller.Buttons.A.SetState(False)
                PreciseSleep(50)
                360Controller.Buttons.A.SetState(True)
                PreciseSleep(500)
                360Controller.Buttons.A.SetState(False)
                PreciseSleep(500)
                360Controller.Buttons.LS.SetState(false)
                360Controller.Axes.LY.SetState(50)
                PreciseSleep(1000)
                controller_aim_hor(15,300)
                controller_sprint(300)
            }
            else
            {
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
            }
        }

        else if(chest == 20)
        {
            controller_sprint(500)
            controller_move_hor(0,500)
            controller_aim_hor(90,1550)
            if(CURRENT_GUARDIAN == "Warlock")
            {
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
                controller_sprint(2300)
                filename := count . "_ChestLoot_20"
                get_screenshot(filename)
            }
            else if(CURRENT_GUARDIAN == "Hunter")
            {
                360Controller.Buttons.A.SetState(True)
                PreciseSleep(500)
                360Controller.Buttons.A.SetState(False)
                PreciseSleep(50)
                360Controller.Axes.LY.SetState(100)
                PreciseSleep(50)
                360Controller.Buttons.A.SetState(True)
                PreciseSleep(500)
                360Controller.Buttons.A.SetState(False)
                PreciseSleep(50)
                360Controller.Buttons.A.SetState(True)
                PreciseSleep(500)
                360Controller.Buttons.A.SetState(False)
                PreciseSleep(500)
                360Controller.Axes.LY.SetState(50)
                controller_aim_hor(85,150)
                controller_sprint(2150)
                filename := count . "_ChestLoot_20"
                get_screenshot(filename)
            }
            else
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
                controller_sprint(2300)
                filename := count . "_ChestLoot_20"
                get_screenshot(filename)
            }
        }

        else if(chest == 19)
        {
            controller_sprint(1500)
            controller_aim_hor(15,1700)
            controller_sprint(2000)
            if(CURRENT_GUARDIAN == "Warlock")
            {
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
                controller_sprint(1200)
                filename := count . "_ChestLoot_19"
                get_screenshot(filename)
            }
            else if(CURRENT_GUARDIAN == "Hunter")
            {
                360Controller.Buttons.LS.SetState(True)
                PreciseSleep(50)
                360Controller.Axes.LY.SetState(100)
                360Controller.Buttons.A.SetState(True)
                PreciseSleep(500)
                360Controller.Buttons.A.SetState(False)
                PreciseSleep(50)
                360Controller.Buttons.A.SetState(True)
                PreciseSleep(500)
                360Controller.Buttons.A.SetState(False)
                PreciseSleep(50)
                360Controller.Buttons.A.SetState(True)
                PreciseSleep(500)
                360Controller.Buttons.A.SetState(False)
                PreciseSleep(50)
                360Controller.Axes.LY.SetState(50)
                PreciseSleep(50)
                360Controller.Buttons.LS.SetState(False)
                controller_aim_hor(85,1200)
                controller_sprint(1300)
                controller_aim_hor(15,900)
                controller_sprint(800)
                filename := count . "_ChestLoot_19"
                get_screenshot(filename)
            }
            else
            {
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
                controller_sprint(1200)
                filename := count . "_ChestLoot_19"
                get_screenshot(filename)
            }
        }

        else if(chest == 16)
        {
            controller_sprint(1500)
            controller_aim_hor(15,1700)
            controller_sprint(1800)
            controller_aim_hor(85,1100)
            controller_sprint(4300)

            controller_aim_hor(15,650)
            controller_sprint(4100)
            filename := count . "_ChestLoot_16"
            get_screenshot(filename)
        }

        if(chest == 18)
        {   
            controller_sprint(1500)
            controller_aim_hor(15,1700)
            controller_sprint(1800)
            controller_aim_hor(85,1450)
            controller_sprint(5950)
            filename := count . "_ChestLoot_18"
            get_screenshot(filename)
        }

        
        StartMonitoring(CHEST_PID)
        StartMonitoring(EXOTIC_PID)
        PreciseSleep(500)
        360Controller.Buttons.X.SetState(true)
        PreciseSleep(2000)
        360Controller.Buttons.X.SetState(false)
        PreciseSleep(50)
        
        if (CHEST_OPENED)
            g4_chest_opened := true
        else 
            StopMonitoring(CHEST_PID)
        CHEST_OPENED := False

        Return g4_chest_opened

    }

; =================================== ;

; Monitoring Functions
; =================================== ;

    StartMonitoring(target_pid)
    {
        PostMessage, 0x1001, 0, 0, , % "ahk_pid " target_pid
    }

    StopMonitoring(target_pid)
    {
        PostMessage, 0x1002, 0, 0, , % "ahk_pid " target_pid
    }

    on_chest_open(wParam, lParam, msg, hwnd)
    {
        CHEST_OPENED := true
    }

    on_exotic_drop(wParam, lParam, msg, hwnd)
    {
        EXOTIC_DROP := true
    }

    log_chest(data, chest_id)
    {
        ; Log the chest to both current and total. Creates duplicate count info after stat refactoring.
        ; for _, chest_stat_type in CHEST_STAT_TYPES {
        ;     if (InStr(chest_stat_type, data))
        ;     {
        ;         PLAYER_DATA[CURRENT_GUARDIAN]["ChestStats"][chest_id][chest_stat_type]++
        ;     }
        ; }
        ; Log the chest only to current. Adds need to commit numbers on exit. Added after stat refactor.
        PLAYER_DATA[CURRENT_GUARDIAN]["ChestStats"][chest_id]["current_" data "s"]++
    }

    current_chest(stat)
    {
        sum := 0
        for _, chest_id in CHEST_IDS {
            sum += PLAYER_DATA[CURRENT_GUARDIAN]["ChestStats"][chest_id]["current_" . stat]
        }
        Return sum
    }

    total_chest(stat)
    {
        sum := 0
        if (TOTALS_DISPLAY = "All")
        {
            for _, class_type in CLASSES {
                for _, chest_id in CHEST_IDS {
                    sum += PLAYER_DATA[class_type]["ChestStats"][chest_id]["current_" . stat]
                    sum += PLAYER_DATA[class_type]["ChestStats"][chest_id]["total_" . stat]
                }
            }
        }
        Else
        {
            for _, chest_id in CHEST_IDS {
                sum += PLAYER_DATA[CURRENT_GUARDIAN]["ChestStats"][chest_id]["current_" . stat]
                sum += PLAYER_DATA[CURRENT_GUARDIAN]["ChestStats"][chest_id]["total_" . stat]
            }
        }
        Return sum
    }

    current_counter(id)
    {
        Return chest_counter(id, PLAYER_DATA[CURRENT_GUARDIAN]["ChestStats"][id]["current_appearances"], PLAYER_DATA[CURRENT_GUARDIAN]["ChestStats"][id]["current_pickups"])
    }

    total_counter(id)
    {
        appearances := 0
        pickups := 0
        if (TOTALS_DISPLAY = "All")
        {
            for _, class_type in CLASSES {
                appearances += PLAYER_DATA[class_type]["ChestStats"][id]["current_appearances"]
                appearances += PLAYER_DATA[class_type]["ChestStats"][id]["total_appearances"]
                pickups += PLAYER_DATA[class_type]["ChestStats"][id]["current_pickups"]
                pickups += PLAYER_DATA[class_type]["ChestStats"][id]["total_pickups"]
            }
        }
        Else
        {
            appearances += PLAYER_DATA[CURRENT_GUARDIAN]["ChestStats"][id]["current_appearances"]
            appearances += PLAYER_DATA[CURRENT_GUARDIAN]["ChestStats"][id]["total_appearances"]
            pickups += PLAYER_DATA[CURRENT_GUARDIAN]["ChestStats"][id]["current_pickups"]
            pickups += PLAYER_DATA[CURRENT_GUARDIAN]["ChestStats"][id]["total_pickups"]
        }
        Return chest_counter(id, appearances, pickups)
    }

    chest_counter(id, appearances, pickups)
    {
        Return id ":" Format("[{:3}/{:3}]", pickups, appearances)
    }

    compute_total_stat(stat)
    {
        total_runs := 0
        if (TOTALS_DISPLAY = "All")
        {
            for _, class_type in CLASSES {
                total_runs += PLAYER_DATA[class_type]["ClassStats"]["total_" . stat]
                total_runs += PLAYER_DATA[class_type]["ClassStats"]["current_" . stat]
            }
        }
        else
        {
            total_runs := PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["total_" . stat] + PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["current_" . stat]
        }
        Return total_runs        
    }

    commit_current_stats()
    {
        for _, class_type in CLASSES {
            for _, class_stat in CLASS_STAT_TYPES {
                if InStr(class_stat, "current_") {
                    total_stat := StrReplace(class_stat, "current_", "total_")
                    PLAYER_DATA[class_type]["ClassStats"][total_stat] += PLAYER_DATA[class_type]["ClassStats"][class_stat]
                    PLAYER_DATA[class_type]["ClassStats"][class_stat] := 0
                }
            }

            for _, chest_id in CHEST_IDS {
                for _, chest_stat in CHEST_STAT_TYPES {
                    if InStr(chest_stat, "current_") {
                        total_stat := StrReplace(chest_stat, "current_", "total_")
                        PLAYER_DATA[class_type]["ChestStats"][chest_id][total_stat] += PLAYER_DATA[class_type]["ChestStats"][chest_id][chest_stat]
                        PLAYER_DATA[class_type]["ChestStats"][chest_id][chest_stat] := 0
                    }
                }
            }
        }
    }
    ; Function to send heartbeat to the server
    send_heartbeat() 
    {
        unrecorded_runtime := PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["current_time"] - RECORDED_RUNTIME
        unrecorded_loops := PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["current_runs"] - RECORDED_LOOPS
        unrecorded_chests := current_chest("pickups") - RECORDED_CHESTS
        unrecorded_exotics := PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["current_exotics"] - RECORDED_EXOTICS

        ; Construct the JSON payload with the delta values
        json := "{"
        json .= """version""" . ":" . """" . VERSION . """" . ","
        json .= """runtime""" . ":" . unrecorded_runtime . ","
        json .= """loops""" . ":" . unrecorded_loops . ","
        json .= """chests_opened""" . ":" . unrecorded_chests . ","
        json .= """exotic_drops""" . ":" . unrecorded_exotics
        json .= "}"

        try {
            HttpObj := ComObjCreate("MSXML2.ServerXMLHTTP.6.0")
            HttpObj.SetTimeouts(1000, 1000, 1000, 1000) ; Timeout settings: Resolve, Connect, Send, Receive
            HttpObj.Open("POST", API_URL, false) ; true for async
            HttpObj.SetRequestHeader("Content-Type", "application/json")
            HttpObj.Send(json)
            response := HttpObj.responseText

            ; MsgBox, "Sent: " . %json%

            if InStr(response, "received")
            {
                ; Add what was received to the recorded totals, which are subtracted from current session values
                ; so we can send the difference (unrecorded) in the next heartbeat.
                RECORDED_RUNTIME += unrecorded_runtime
                RECORDED_LOOPS += unrecorded_loops
                RECORDED_CHESTS += unrecorded_chests
                RECORDED_EXOTICS += unrecorded_exotics
            }
            Else
            {
                ; MsgBox, "Recording error: " . %response%
            }
        } catch e {
            ; Silence any errors and continue execution
            ; MsgBox, "HTTP error."
        }
    }

; =================================== ;

; Load Zone Functions
; =================================== ;
    reload_landing(mode:=0) ; in the name innit
    {
        loop, 5
        {   
            if(mode == 0)
            {       
                Send, % "{" key_binds["ui_open_director"] "}"
                PreciseSleep(1400)
                d2_click(20, 381, 0) ; mouse to drag map and show landing icon
                PreciseSleep(850)
                d2_click(270, 338, 0) ; mouse stop drag and hover landing
                PreciseSleep(100)
                Click, Up
                PreciseSleep(100)
                Click, % DESTINY_X + 270 " " DESTINY_Y + 338 " "
                Click, Down
                PreciseSleep(1100)
                Click, % DESTINY_X + 270 " " DESTINY_Y + 338 " "
                Click, Up
                PreciseSleep(1000)
                landingOffset := 0
                loop, 10
                {
                    ; check if we are still on the map screen (this means this function fucked up)
                    percent_white := exact_color_check("920|58|56|7", 56, 7, 0xECECEC)
                    if (percent_white >= 0.3)
                    {
                        d2_click(295 + landingOffset, 338, 0) ; try clicking a bit to the side
                        PreciseSleep(100)
                        Click, Up
                        PreciseSleep(100)
                        Click, % DESTINY_X + 295 + landingOffset " " DESTINY_Y + 338 " "
                        Click, Down
                        PreciseSleep(1100)
                        Click, % DESTINY_X + 295 + landingOffset " " DESTINY_Y + 338 " "
                        Click, Up
                        PreciseSleep(1000)
                    }
                    percent_white := exact_color_check("920|58|56|7", 56, 7, 0xECECEC)
                    if (!percent_white >= 0.3) ; we clicked succesfully
                        break
                    landingOffset := landingOffset + 25
                }
                if (!percent_white >= 0.3) ; we clicked succesfully
                    break
                Send, % "{" key_binds["ui_open_director"] "}"
                PreciseSleep(2000)
            }
            if(mode == 1)
            {       
                360Controller.Buttons.Back.SetState(True)
                PreciseSleep(1500)
                360Controller.Buttons.Back.SetState(False)
                controller_move_hor(0,2100) ; move cusror left towards the landing zone
                controller_move_ver(30,100)             ; move cursor down a little for consistency
                controller_move_ver(50,100)             ; MAKE SURE CURSOR DOESN'T FLY OFF INTO
                controller_move_ver(50,100)             ; FUCKING NARNIA FOR SOME FUCKASS REASON
                360Controller.Buttons.A.SetState(true)
                PreciseSleep(2000)
                360Controller.Buttons.A.SetState(false)
                PreciseSleep(1500)
                loop, 5
                {
                    ; check if we are still on the map screen (this means this function fucked up)
                    percent_white := TO_color_check("920|58|56|7",0xECECEC)
                    if (percent_white >= 0.3)
                    {
                        controller_move_hor(0,100)
                        360Controller.Buttons.A.SetState(true)
                        PreciseSleep(1500)
                        360Controller.Buttons.A.SetState(false)
                        PreciseSleep(1000)
                    }
                    percent_white := TO_color_check("920|58|56|7",0xECECEC)
                    if (!percent_white >= 0.3) ; we clicked succesfully
                        break
                }
                if (!percent_white >= 0.3) ; we clicked succesfully
                    break
                360Controller.Buttons.Back.SetState(True)
                PreciseSleep(500)
                360Controller.Buttons.Back.SetState(False)
                PreciseSleep(2000)                                                                                              
            }
        }
        Return
    }

    orbit_landing(mode:=0) ; loads into the landing from orbit
    {
        loop, 5
        {
            if(mode == 0)
            {
                Send, % "{" key_binds["ui_open_director"] "}"
                PreciseSleep(2500)
                d2_click(640, 360, 0)
                PreciseSleep(500)
                d2_click(640, 360)
                PreciseSleep(1800)
                d2_click(20, 381, 0) ; mouse to drag map and show landing icon
                PreciseSleep(850)
                d2_click(270, 338, 0) ; mouse stop drag and hover landing
                PreciseSleep(100)
                d2_click(270, 338) ; mouse click landing
                PreciseSleep(1500)
                percent_white := simpleColorCheck("33|573|24|24", 24, 24)
                if (!percent_white >= 0.4) ; we missed the landing zone
                {
                    d2_click(295, 338, 0) ; try clicking a bit to the side
                    PreciseSleep(100)
                    d2_click(295, 338)
                    PreciseSleep(1500)
                    percent_white := simpleColorCheck("33|573|24|24", 24, 24) ; check again, if still not in the right screen, close map and try again
                    if (!percent_white >= 0.4)
                    {
                        Send, % "{" key_binds["ui_open_director"] "}"
                        PreciseSleep(1500)
                        Continue
                    }
                }
                d2_click(1080, 601, 0)
                PreciseSleep(100)
                d2_click(1080, 601)
            }
            if(mode == 1)
            {
                360Controller.Buttons.Back.SetState(True)
                PreciseSleep(100)
                360Controller.Buttons.Back.SetState(False)
                PreciseSleep(2500)
                controller_move_ver(60,100)
                controller_move_ver(40,100)
                controller_move_ver(50,100)
                controller_move_ver(50,100)
                PreciseSleep(600)
                360Controller.Buttons.A.SetState(true)
                PreciseSleep(100)
                360Controller.Buttons.A.SetState(false)
                PreciseSleep(2000)
                controller_move_hor(0,2100)             ; move cusror left towards the landing zone
                controller_move_ver(30,100)             ; move cursor down a little for consistency
                controller_move_ver(50,100)             ; MAKE SURE CURSOR DOESN'T FLY OFF INTO
                controller_move_ver(50,100)             ; FUCKING NARNIA FOR SOME FUCKASS REASON
                360Controller.Buttons.A.SetState(true)
                PreciseSleep(300)
                360Controller.Buttons.A.SetState(false)
                PreciseSleep(1500)
                loop, 5
                {
                    ; check if we are still on the map screen (this means this function fucked up)
                    percent_white := TO_color_check("46|577|10|10",0xFFFFFF)
                    if (!percent_white >= 0.3)
                    {
                        controller_move_hor(0,100)
                        360Controller.Buttons.A.SetState(true)
                        PreciseSleep(1500)
                        360Controller.Buttons.A.SetState(false)
                        PreciseSleep(1000)
                    }
                    percent_white := TO_color_check("46|577|10|10",0xFFFFFF)
                    if (percent_white >= 0.3) ; we clicked succesfully
                        break
                }
                if (!percent_white >= 0.3) ; we did not succesfully
                    break
                controller_move_hor(100,900)
                controller_move_ver(0,550)
                360Controller.Buttons.A.SetState(true)
                PreciseSleep(100)
                360Controller.Buttons.A.SetState(false)
                PreciseSleep(100)
            }
            Return true
        }
        Return false ; 5 fuckups in a row and it fails
    }
; =================================== ;

; Destiny Helper Functions
; =================================== ;
    change_character(slot := "",mode:=0)
    {
        if (slot = "")
            slot := PLAYER_DATA[CURRENT_GUARDIAN]["Settings"]["Slot"]
        
        if(mode == 0)  ;; Defaults to clicking on screen
        {
            if (!key_binds["ui_open_start_menu_settings_tab"]) ; if no settings keybind use f1 :D (slower)
            {
                Send, {F1}
                PreciseSleep(3000)
                d2_click(1144, 38, 0)
                PreciseSleep(100)
                d2_click(1144, 38)
            }
            else
                Send, % "{" key_binds["ui_open_start_menu_settings_tab"] "}"
            PreciseSleep(1500)
            d2_click(184, 461, 0)
            PreciseSleep(150)
            d2_click(184, 461)
            PreciseSleep(700)
            d2_click(1030, 165, 0)
            PreciseSleep(150)
            d2_click(1030, 165)
            PreciseSleep(500)
            Send, {Enter}
            PreciseSleep(5000)
        }

        if(mode == 1) ;; Goes to char select with controller inputs
        {
            360Controller.Buttons.Start.SetState(True)
            PreciseSleep(100)
            360Controller.Buttons.Start.SetState(False)
            PreciseSleep(1000)
            360Controller.Buttons.RB.SetState(True)
            PreciseSleep(100)
            360Controller.Buttons.RB.SetState(False)
            PreciseSleep(500)
            360Controller.Buttons.RB.SetState(True)
            PreciseSleep(100)
            360Controller.Buttons.RB.SetState(False)
            PreciseSleep(500)
            loop, 4
            {
                360Controller.Dpad.SetState("Down")
                PreciseSleep(100)
                360Controller.Dpad.SetState("None")
                PreciseSleep(100)
            }
            360Controller.Axes.LX.SetState(100)
            PreciseSleep(800)
            360Controller.Axes.LX.SetState(50)
            PreciseSleep(100)
            360Controller.Axes.LY.SetState(100)
            PreciseSleep(550)
            360Controller.Axes.LY.SetState(50)
            PreciseSleep(100)
            360Controller.Buttons.A.SetState(True)
            PreciseSleep(100)
            360Controller.Buttons.A.SetState(False)
            PreciseSleep(500)
            360Controller.Buttons.A.SetState(True)
            PreciseSleep(100)
            360Controller.Buttons.A.SetState(False)
        }

        search_start := A_TickCount
        while (TO_color_check("803|270|42|60",0xFFFFFF) < 0.03)
        {
            if (A_TickCount - search_start > 90000)
                break
        }
        PreciseSleep(2000)
        if (slot == "Top")
        {
            if(mode == 0)
            {
                d2_click(900, 304, 0)
                PreciseSleep(100)
                d2_click(900, 304)
                PreciseSleep(400)
                d2_click(900, 304, 0)
                PreciseSleep(100)
                d2_click(900, 304)
            }
            if(mode == 1)
            {
                controller_move_hor(100,300)
                controller_move_ver(100,150)
                360Controller.Buttons.A.SetState(True)
                PreciseSleep(50)
                360Controller.Buttons.A.SetState(False)
            }
        }
        else if (slot == "Middle")
        {
            if(mode == 0)
            {
                d2_click(885, 379, 0)
                PreciseSleep(100)
                d2_click(885, 379)
                PreciseSleep(400)
                d2_click(885, 379, 0)
                PreciseSleep(100)
                d2_click(885, 379)
            }
            if(mode == 1)
            {
                controller_move_hor(100,300)
                360Controller.Buttons.A.SetState(True)
                PreciseSleep(50)
                360Controller.Buttons.A.SetState(False)
            }
        }
        else if (slot == "Bottom")
        {
            if(mode == 0)
            {
                d2_click(902, 448, 0)
                PreciseSleep(100)
                d2_click(902, 448)
                PreciseSleep(400)
                d2_click(902, 448, 0)
                PreciseSleep(100)
                d2_click(902, 448)
            }
            if(mode == 1)
            {
                controller_move_hor(100,300)
                controller_move_ver(0,250)
                360Controller.Buttons.A.SetState(True)
                PreciseSleep(50)
                360Controller.Buttons.A.SetState(False)
            }
        }
        if(mode == 0)
            d2_click(640, 360, 0)
        PreciseSleep(6000)
        search_start := A_TickCount
        while (true) ; wait for screen to be not black (just checking 3 random pixels)
        {
            if(((!TO_color_check("50|50|5|5",0x000000)) > .1)
                || ((!TO_color_check("100|100|5|5",0x000000)) > .1)
                || ((!TO_color_check("400|400|5|5",0x000000)) > .1)
                || A_TickCount - search_start > 90000)
            {
                break
            }
        }
        Return
    }

    set_fireteam_privacy(choice="invite",mode:=0) ; sets fireteam privacy :D
    {
        StringLower, choice, choice

        Switch choice {
            case "1", "public", "open":
                choice := 0
            case "2", "friend", "friends":
                choice := 2
            case "3", "invite":
                choice := 3
            case "4", "closed", "private":
                choice := 4
            default:
                choice := 4  
        }
        if(mode == 0)
        {
            if (!key_binds["ui_open_start_menu_settings_tab"])
            {
                Send, {F1}
                PreciseSleep(3000)
                d2_click(1144, 38, 0)
                PreciseSleep(100)
                d2_click(1144, 38)
            }
            else
                Send, % "{" key_binds["ui_open_start_menu_settings_tab"] "}"
            PreciseSleep(900)
            d2_click(192, 524, 0)
            PreciseSleep(900)
            d2_click(192, 524)
            PreciseSleep(500)
            d2_click(1187, 167, 0) 
            PreciseSleep(200)
            Loop, 4 ; go to closed
            {
                d2_click(1187, 167)
                PreciseSleep(85)
            }
            d2_click(989, 167, 0)
            PreciseSleep(85)
            Loop, % 4 - choice ; go from closed back to choice
            {
                d2_click(989, 167)
                PreciseSleep(85)
            }
            if (key_binds["ui_open_start_menu_settings_tab"])
                send, % "{" key_binds["ui_open_start_menu_settings_tab"] "}"
            else 
                send, {esc}
        }
        if(mode == 1)
        {
            360Controller.Buttons.Start.SetState(True)
            PreciseSleep(100)
            360Controller.Buttons.Start.SetState(False)
            PreciseSleep(1000)
            360Controller.Buttons.RB.SetState(True)
            PreciseSleep(100)
            360Controller.Buttons.RB.SetState(False)
            PreciseSleep(500)
            360Controller.Buttons.RB.SetState(True)
            PreciseSleep(100)
            360Controller.Buttons.RB.SetState(False)
            PreciseSleep(500)
            loop, 5
            {
                360Controller.Dpad.SetState("Down")
                PreciseSleep(100)
                360Controller.Dpad.SetState("None")
                PreciseSleep(100)
            }
            360Controller.Axes.LX.SetState(100)
            PreciseSleep(1100)
            360Controller.Axes.LX.SetState(50)
            PreciseSleep(100)
            360Controller.Axes.LY.SetState(100)
            PreciseSleep(550)
            360Controller.Axes.LY.SetState(50)
            PreciseSleep(100)
            Loop, 4 ; go to closed
            {
                360Controller.Buttons.A.SetState(True)
                PreciseSleep(100)
                360Controller.Buttons.A.SetState(False)
                PreciseSleep(100)
            }
            360Controller.Axes.LX.SetState(0)
            PreciseSleep(500)
            360Controller.Axes.LX.SetState(50)
            PreciseSleep(100)
            Loop, % 4 - choice ; go from closed back to choice
            {
                360Controller.Buttons.A.SetState(True)
                PreciseSleep(100)
                360Controller.Buttons.A.SetState(False)
                PreciseSleep(100)
            }
            360Controller.Buttons.Start.SetState(True)
            PreciseSleep(100)
            360Controller.Buttons.Start.SetState(False)
        }
        Return
    }

    game_restart() ; not used in this script but could be added to allwo it to run through crashes :partying_face:
    {
        WinKill, Destiny 2 ; Close Destiny 2 window
        PreciseSleep(20000) ; Wait for 30 seconds to ensure the window has fully closed
        Run, steam://rungameid/1085660,, Hide ; This launches Destiny 2 through Steam
        PreciseSleep(20000)
        WinWait, Destiny 2
        PreciseSleep(20000)
        WinActivate, Destiny 2
        find_d2(1)
        while (simpleColorCheck("581|391|87|15", 87, 15) < 0.90)
        {
            if (A_TickCount - search_start > 90000)
                break
        }
        PreciseSleep(10)
        Send, {enter}
        Send, {enter}
        Send, {enter}
        PreciseSleep(10000)
        while (simpleColorCheck("802|274|64|20", 64, 20) < 0.12)
        {
            if (A_TickCount - search_start > 90000)
                break
        }
        d2_click(900, 374, 0)
        PreciseSleep(100)
        d2_click(900, 374)
        Return
    }

    wait_for_spawn(time_out:=200000) ; waits for spawn in by checking for heavy ammo color and blue blip on minimap
    {
        start_time := A_TickCount
        loop,
        {
            x_off := -2
            loop, 3
            {
                y_off := 0
                loop, 5
                {
                    xref := 65 + x_off
                    yref := 60 + y_off
                    coords1 := xref "|" yref "|2|2"
                    if(TO_color_check(coords1,0xFFFFFF)> .3) ; raid logo
                    {
                        xref := 387 + x_off
                        yref := 667 + y_off
                        coords1 := xref "|" yref "|2|2" 
                        if((TO_color_check(coords1,0xFF9AC1) > .3) && (TO_color_check(coords1,0xFF99C2) < .3)) ; heavy ammo
                            Return true ; This subsequent check prevents some planets from throwing false positive
                    }
                    PreciseSleep(10)
                    xref := 85 + x_off
                    yref := 84 + y_off
                    coords1 := xref "|" yref "|2|2" 
                    if(TO_color_check(coords1,0xCB986F) > .3) ; minimap
                        Return true
                    PreciseSleep(10)
                    xref := 387 + x_off
                    yref := 667 + y_off
                    coords1 := xref "|" yref "|2|2" 

                    if((TO_color_check(coords1,0xFF9AC1) > .3) && (TO_color_check(coords1,0xFF99C2) < .3)) ; heavy ammo
                        Return true ; This subsequent check prevents some planets from throwing false positive
                    PreciseSleep(10)
                    y_off := y_off + 2
                }
                x_off := x_off + 1
            }
            if (A_TickCount - start_time > time_out) ; times out eventually so we dont get stuck forever
                Return false
        }
        Return true
    }
; =================================== ;

; Custom Controller Movement Functions
; =================================== ;
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

    controller_sniper(mode:=0)
    {
        if(!(TO_color_check("385|667|2|2",0xFF9AC1) > .3) && !(TO_color_check("385|667|2|2",0xFF99C2) < .3)) ; heavy ammo
        {
            360Controller.Buttons.Y.SetState(True)
            PreciseSleep(50)
            360Controller.Buttons.Y.SetState(False)
            PreciseSleep(500)
        }
        360Controller.Buttons.Y.SetState(True)
        PreciseSleep(500)
        360Controller.Buttons.Y.SetState(False)
        PreciseSleep(50)
        360Controller.Buttons.Y.SetState(True)
        PreciseSleep(50)
        360Controller.Buttons.Y.SetState(False)
        PreciseSleep(50)
        if(mode == 1)
        {
            360Controller.Buttons.Y.SetState(True)
            PreciseSleep(50)
            360Controller.Buttons.Y.SetState(False)
            PreciseSleep(50)
        }
    }
; =================================== ;

; Color Functions
; =================================== ;
    simpleColorCheck(coords, w, h) ; bad function to check for pixels that are "white enough" in a given area
    {
        ; convert the coords to be relative to destiny 
        coords := StrSplit(coords, "|")
        x := coords[1] + DESTINY_X
        y := coords[2] + DESTINY_Y
        coords := x "|" y "|" w "|" h
        pBitmap := %dGdip_BitmapFromScreen%(coords)
        ; save bitmap 
        ; %dGdip_SaveBitmapToFile%(pBitmap, A_ScriptDir . "\test.png")
        x := 0
        y := 0
        white := 0
        total := 0
        loop %h%
        {
            loop %w%
            {
                color := ( %dGdip_GetPixel%(pBitmap, x, y) & 0x00F0F0F0)
                if (color == 0xF0F0F0)
                    white += 1
                total += 1
                x+= 1
            }
            x := 0
            y += 1
        }
        %dGdip_DisposeImage%(pBitmap)
        pWhite := white/total
        Return pWhite
    }

    exact_color_check(coords, w, h, base_color) ; also bad function to check for specific color pixels in a given area
    {
        ; convert the coords to be relative to destiny 
        coords := StrSplit(coords, "|")
        x := coords[1] + DESTINY_X
        y := coords[2] + DESTINY_Y
        coords := x "|" y "|" w "|" h
        pBitmap := %dGdip_BitmapFromScreen%(coords)
        ; save bitmap 
        ; %dGdip_SaveBitmapToFile%(pBitmap, A_ScriptDir . "\test.png")
        x := 0
        y := 0
        white := 0
        total := 0
        loop %h%
        {
            loop %w%
            {
                color := (%dGdip_GetPixel%(pBitmap, x, y) & 0x00FFFFFF)
                if (color == base_color)
                    white += 1
                total += 1
                x+= 1
            }
            x := 0
            y += 1
        }
        %dGdip_DisposeImage%(pBitmap)
        pWhite := white/total
        Return pWhite

    }

    TO_color_check(coords, base_color:=0xFFFFFF,filename:="test") ; also bad function to check for specific color pixels in a given area
    {
        pD2WindowBitmap := Gdip_BitmapFromHWND(D2_WINDOW_HANDLE,clientOnly:=1)
        if(DEBUG)
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
        if(DEBUG)
            Gdip_SaveBitmapToFile(pElementBitmap, A_ScriptDir . "\debugs\screenshots\" . filename . ".png")

        colx := 0
        coly := 0
        white := 0
        total := 0
        if(DEBUG)
            FileAppend, Color Check Started`n, %db_logfile%
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
                    FileAppend, %colx% %coly% | C: %color% Ref: %base_color%`n, %db_logfile%
            }
            colx := 0
            coly += 1
        }
        Gdip_DisposeImage(pElementBitmap)
        pWhite := white/total
        Return pWhite
    }

    check_pixel( allowed_colors, pixel_x, pixel_y )
    {
        pixel_x := pixel_x + DESTINY_X
        pixel_y := pixel_y + DESTINY_Y

        PixelGetColor, pixel_color, pixel_x, pixel_y, RGB
        found := false
        for _, color in allowed_colors {
            if (pixel_color == color) {
                found := true
            }
        }

        if (DEBUG)
            draw_crosshair(pixel_x, pixel_y)

        Return found
    }


; =================================== ;

; Other Functions
; =================================== ;
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
        Return
    }

    get_mouse_pos_relative_to_d2() ; gets the mouse coords in x, y form relative to destinys client area
    {
        ; Get the current mouse position
        MouseGetPos, mouseX, mouseY

        ; Calculate the position relative to the Destiny 2 client area
        relativeX := mouseX - DESTINY_X
        relativeY := mouseY - DESTINY_Y

        Clipboard := relativeX ", " relativeY
        Return {X: relativeX, Y: relativeY}
    }

    d2_click(x, y, press_button:=1) ; click somewhere on d2
    {
        Click, % DESTINY_X + x " " DESTINY_Y + y " " press_button
        Return
    }

    format_timestamp(timestamp, show_hours, show_minutes, show_seconds, show_ms, round_ms:=2) ; just like, dont ask, its shit
    {
        numSeconds := Floor(timestamp / 1000)
        numHours := Floor(numSeconds / 3600)
        numMinutes := Mod(Floor(numSeconds / 60), 60)
        numSeconds := Mod(numSeconds, 60)
        numMS := Mod(timestamp, 1000)

        highestUnit := show_hours ? 1 : (show_minutes ? 2 : (show_seconds ? 3 : 4))
        lowestUnit := show_ms ? 4 : (show_seconds ? 3 : (show_minutes ? 2 : 1))

        show_hours := (highestUnit <= 1 && lowestUnit >= 1)
        show_minutes := (highestUnit <= 2 && lowestUnit >= 2)
        show_seconds := (highestUnit <= 3 && lowestUnit >= 3)
        show_ms := (highestUnit <= 4 && lowestUnit >= 4)

        formattedTime := ""

        if (show_hours) {
            formattedTime .= Format("{:02}", numHours)
            if (show_minutes || show_seconds || show_ms) 
                formattedTime .= ":"
        }
        if (show_minutes) {
            formattedTime .= Format("{:02}", numMinutes)
            if (show_seconds || show_ms) 
                formattedTime .= ":"
        }
        if (show_seconds) {
            formattedTime .= Format("{:02}", numSeconds)
            if (show_ms) 
                formattedTime .= "."
        }
        if (show_ms) 
            formattedTime .= SubStr(Format("{:03}", numMS), 1, round_ms)

        Return formattedTime
    }

    get_d2_keybinds(k) ; very readable function that parses destiny 2 cvars file for keybinds
    {
        FileRead, f, % A_AppData "\Bungie\DestinyPC\prefs\cvars.xml"
        if ErrorLevel 
            Return False
        b := {}, t := {"shift": "LShift", "control": "LCtrl", "alt": "LAlt", "menu": "AppsKey", "insert": "Ins", "delete": "Del", "pageup": "PgUp", "pagedown": "PgDn", "keypad`/": "NumpadDiv", "keypad`*": "NumpadMult", "keypad`-": "NumpadSub", "keypad`+": "NumpadAdd", "keypadenter": "NumpadEnter", "leftmousebutton": "LButton", "middlemousebutton": "MButton", "rightmousebutton": "RButton", "extramousebutton1": "XButton1", "extramousebutton2": "XButton2", "mousewheelup": "WheelUp", "mousewheeldown": "WheelDown", "escape": "Esc"}
        for _, n in k 
            RegExMatch(f, "<cvar\s+name=""`" n `"""\s+value=""([^""]+)""", m) ? b[n] := t.HasKey(k2 := StrReplace((k1 := StrSplit(m1, "!")[1]) != "unused" ? k1 : k1[2], " ", "")) ? t[k2] : k2 : b[n] := "unused"
        Return b
    }

    IsAdminProcess(pid)
    {
        hProcess := DllCall("OpenProcess", "UInt", 0x1000, "Int", False, "UInt", pid, "Ptr")
        if (!hProcess)
            Return False
        if !DllCall("Advapi32.dll\OpenProcessToken", "Ptr", hProcess, "UInt", 0x0008, "PtrP", hToken)
        {
            DllCall("CloseHandle", "Ptr", hProcess)
            Return False
        }
        VarSetCapacity(TOKEN_ELEVATION, 4, 0)
        cbSize := 4
        if !DllCall("Advapi32.dll\GetTokenInformation", "Ptr", hToken, "UInt", 20, "Ptr", &TOKEN_ELEVATION, "UInt", cbSize, "UIntP", cbSize)
        {
            DllCall("CloseHandle", "Ptr", hToken)
            DllCall("CloseHandle", "Ptr", hProcess)
            Return False
        }
        DllCall("CloseHandle", "Ptr", hToken)
        DllCall("CloseHandle", "Ptr", hProcess)
        Return NumGet(TOKEN_ELEVATION, 0) != 0
    }

    release_d2_bindings()
    {
        for key, value in key_binds 
            send, % "{" value " Up}"
        Return
    }
; =================================== ;

; Debugging Functions
; =================================== ;
    draw_crosshair( x:=0, y:=0 )
    {   
        CrosshairColor := 0x0000FF ; Red
        LineLength := 50

        ; Create a device context for the screen
        hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
        
        ; Create a red pen with 1px width
        hPen := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", CrosshairColor, "Ptr")
        hOldPen := DllCall("SelectObject", "Ptr", hdc, "Ptr", hPen)
        
        ; Draw the vertical line
        DllCall("MoveToEx", "Ptr", hdc, "Int", x, "Int", y - LineLength, "Ptr", 0)
        DllCall("LineTo", "Ptr", hdc, "Int", x, "Int", y + LineLength)
        
        ; Draw the horizontal line
        DllCall("MoveToEx", "Ptr", hdc, "Int", x - LineLength, "Int", y, "Ptr", 0)
        DllCall("LineTo", "Ptr", hdc, "Int", x + LineLength, "Int", y)
        
        ; Restore the old pen and delete the created pen
        DllCall("SelectObject", "Ptr", hdc, "Ptr", hOldPen)
        DllCall("DeleteObject", "Ptr", hPen)
        
        ; Release the device context
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
        
        Return
    }

    get_screenshot(filename:="destiny_screenshot",mode:=0) ; save screenshot for DEBUG
    {
        pD2WindowBitmap := Gdip_BitmapFromHWND(D2_WINDOW_HANDLE,clientOnly:=1)
        if(mode == 1)
            pD2WindowBitmap := Gdip_BitmapConvertGray(pD2WindowBitmap)
        Gdip_SaveBitmapToFile(pD2WindowBitmap, A_ScriptDir . "\debugs\screenshots\" . filename . ".png")

        Gdip_DisposeImage(pD2WindowBitmap)
    }
; =================================== ;

; GUI Functions
; =================================== ;
    read_ini() ; yuck, json would be so much nicer
    {
        ; check if there is a file called `afk_chest_stats.ini` and if so, load the stats from it
        if (FileExist("afk_chest_stats.ini")) {

            IniRead, ENABLE_TABBEDOUT, afk_chest_stats.ini, Settings, enable_tabbedout, %A_Space%
            IniRead, CURRENT_GUARDIAN, afk_chest_stats.ini, Stats, Last_Guardian, Hunter
            IniRead, CURRENT_SLOT, afk_chest_stats.ini, % CURRENT_GUARDIAN, Slot, Top
            IniRead, TOTALS_DISPLAY, afk_chest_stats.ini, Stats, Totals_Display, All
            IniRead, HIDE_GUI, afk_chest_stats.ini, Settings, hide_gui, %A_Space%

            for _, class_type in CLASSES {

                IniRead, temp, afk_chest_stats.ini, % class_type, Slot, Top
                PLAYER_DATA[class_type]["Settings"]["Slot"] := temp
                IniRead, temp, afk_chest_stats.ini, % class_type, Aachen, Kinetic
                PLAYER_DATA[class_type]["Settings"]["Aachen"] := temp

                for _, class_stat_type in CLASS_STAT_TYPES {
                    if (InStr(class_stat_type, "total")) {
                        IniRead, temp, afk_chest_stats.ini, % class_type, % class_stat_type, 0
                        PLAYER_DATA[class_type]["ClassStats"][class_stat_type] := temp
                    }
                }

                for _, chest_id in CHEST_IDS {
                    for _, chest_stat_type in CHEST_STAT_TYPES {
                        if (InStr(chest_stat_type, "total"))
                        {
                            for _, chest_id in CHEST_IDS {
                                IniRead, temp, afk_chest_stats.ini, % class_type, % chest_id "_" chest_stat_type, 0
                                PLAYER_DATA[class_type]["ChestStats"][chest_id][chest_stat_type] := temp
                            }
                        }
                    }
                }
            }
        }
    }

    write_ini()
    {
        if (STARTUP_SUCCESSFUL)
        {
            commit_current_stats()

            IniWrite, %ENABLE_TABBEDOUT%, afk_chest_stats.ini, Settings, enable_tabbedout
            IniWrite, % CURRENT_GUARDIAN, afk_chest_stats.ini, Stats, Last_Guardian
            IniWrite, % TOTALS_DISPLAY, afk_chest_stats.ini, Stats, Totals_Display
            IniWrite, %HIDE_GUI%, afk_chest_stats.ini, Settings, hide_gui

            for _, class_type in CLASSES {

                IniWrite, % PLAYER_DATA[class_type]["Settings"]["Slot"], afk_chest_stats.ini, % class_type, Slot
                IniWrite, % PLAYER_DATA[class_type]["Settings"]["Aachen"], afk_chest_stats.ini, % class_type, Aachen

                for _, class_stat_type in CLASS_STAT_TYPES {
                    if (InStr(class_stat_type, "total")) {
                        IniWrite, % PLAYER_DATA[class_type]["ClassStats"][class_stat_type], afk_chest_stats.ini, % class_type, % class_stat_type
                    }
                }

                for _, chest_id in CHEST_IDS {
                    for _, chest_stat_type in CHEST_STAT_TYPES {
                        if (InStr(chest_stat_type, "total"))
                        {
                            for _, chest_id in CHEST_IDS {
                                IniWrite, % PLAYER_DATA[class_type]["ChestStats"][chest_id][chest_stat_type], afk_chest_stats.ini, % class_type, % chest_id "_" chest_stat_type
                            }
                        }
                    }
                }
            }
        }
    }

    toggle_gui(visibility := "")
    {
        if (visibility = "")
            visibility := (GUI_VISIBLE) ? "hide" : "show"

        for index, ui_element in overlay_elements
        {
            ui_element.toggle_visibility(visibility)
            if (ui_element.has_background)
                ui_element.toggle_background_visibility(visibility)
        }

        if (visibility = "show") {
            Gui, info_BG: Show
            GUI_VISIBLE := true
        } else {
            Gui, info_BG: Hide
            GUI_VISIBLE := false
        }
        
        Return
    }

    update_ui() ; Fully update UI, optimized to only compute values once.
    {
        ; Compute these once.
        c_current_pickups := current_chest("pickups")
        c_current_appearances := current_chest("appearances")
        ; Current
        ; Time AFK
        ; -Handled by timer.
        ; Runs
        current_runs_ui.update_content("Runs - " PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["current_runs"])
        ; Chests
        ; -update_chest_ui()
        ; Exotics
        current_exotics_ui.update_content("Exotics - " PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["current_exotics"])
        ; Exotic Drop Rate
        current_exotic_drop_rate_ui.update_content("Exotic Drop Rate - " Round(PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["current_exotics"]/c_current_pickups*100,2) "%")
        ; Average Loop Time
        current_average_loop_time_ui.update_content("Average Loop Time - " format_timestamp(PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["current_time"]/PLAYER_DATA[CURRENT_GUARDIAN]["ClassStats"]["current_runs"], false, true, true, true, 2))
        ; Percent Chests Missed
        current_missed_chests_percent_ui.update_content("Percent Chests Missed - " Round(100 - (c_current_pickups/c_current_appearances)*100, 2) "%")
        ; Per chest stats
        ; -update_chest_ui()

        ; Compute these once.
        c_total_runs := compute_total_stat("runs")
        c_total_exotics := compute_total_stat("exotics")
        c_total_time := compute_total_stat("time")
        c_total_pickups := total_chest("pickups")
        c_total_appearances := total_chest("appearances")
        ; Total
        ; Time AFK
        ; -Handled by timer.
        ; Runs
        total_runs_ui.update_content("Runs - " c_total_runs)
        ; Chests
        ; -update_chest_ui()
        ; Exotics
        total_exotics_ui.update_content("Exotics - " c_total_exotics)
        ; Exotic Drop Rate
        total_exotic_drop_rate_ui.update_content("Exotic Drop Rate - " Round(c_total_exotics/c_total_pickups*100,2) "%")
        ; Average Loop Time
        total_average_loop_time_ui.update_content("Average Loop Time - " format_timestamp(c_total_time/c_total_runs, false, true, true, true, 2))
        ; Percent Chests Missed
        total_missed_chests_percent_ui.update_content("Percent Chests Missed - " Round(100 - (c_total_pickups/c_total_appearances)*100, 2) "%")
        ; Per chest stats
        ; -update_chest_ui()

        update_chest_ui(c_current_pickups, c_total_pickups)
    }

    update_chest_ui(current_chests := -1, total_chests := -1)
    {
        current_chests_ui.update_content("Chests - "  . (current_chests = -1 ? current_chest("pickups") : current_chests))
        total_chests_ui.update_content("Chests - "  . (total_chests = -1 ? total_chest("pickups") : total_chests))

        current_chest_counters1.update_content(current_counter(21) "  " current_counter(20) "  " current_counter(17))
        current_chest_counters2.update_content(current_counter(19) "  " current_counter(18) "  " current_counter(16))
        total_chest_counters1.update_content(total_counter(21) "  " total_counter(20) "  " total_counter(17))
        total_chest_counters2.update_content(total_counter(19) "  " total_counter(18) "  " total_counter(16))
    }

    on_script_exit()
    {
        if (CHEST_PID)
            Process, Close, %CHEST_PID%
        if (EXOTIC_PID)
            Process, Close, %EXOTIC_PID%

        release_d2_bindings()
        if (HEARTBEAT_ON)
        {
            send_heartbeat()
            HEARTBEAT_ON := false
        }
        write_ini()
    }

    check_tabbed_out:
    {
        destiny_active := false
        selection_ui_active := false
        IfWinActive, ahk_exe destiny2.exe
            destiny_active := true
        IfWinActive, ahk_id %user_input_hwnd%
            selection_ui_active := true
        if (destiny_active || selection_ui_active)
        {
            if (!GUI_VISIBLE)
                toggle_gui("show")
        }
        else
        {
            if (GUI_VISIBLE)
                toggle_gui("hide")
        }
        Return
    }
; =================================== ;

; Settings Dialog Functions
; =================================== ;
    build_dropdown_string(options, selected) {
        dropdown := ""
        for index, option in options {
            if (option = selected)
                dropdown .= option "||"
            else
                dropdown .= option "|"
        }
        Return dropdown
    }

    ; Popup Dialog
    ; =================================== ;
    settingsgui:
        global INPUT_POPUP_HANDLED := false
        classDropdown := build_dropdown_string(CLASSES, CURRENT_GUARDIAN)
        slotDropdown := build_dropdown_string(CHARACTER_SLOTS, PLAYER_DATA[CURRENT_GUARDIAN]["Settings"]["Slot"])
        aachenDropdown := build_dropdown_string(AACHEN_CHOICES, PLAYER_DATA[CURRENT_GUARDIAN]["Settings"]["Aachen"])
        ; gui to get users character and character slot on character select screen
        Gui, user_input: New, , Select class and their slot on the character select screen
        Gui, user_input: +Caption -minimizebox +hWnduser_input_hwnd +AlwaysOnTop
        Gui, user_input: Add, Checkbox, x10 y+5 checked%ENABLE_TABBEDOUT% venable_tabbedout, Enable Tabbed Out
        Gui, user_input: Add, Text, y+10, Select Class:
        Gui, user_input: Add, DropDownList, vClassChoice gClassChoiceChanged, % classDropdown
        Gui, user_input: Add, Text,, Select Slot:`n(on character select)
        Gui, user_input: Add, DropDownList, vSlotChoice, % slotDropdown
        Gui, user_input: Add, Text,, Which Aachen do you have:
        Gui, user_input: Add, DropDownList, vAachenChoice, % aachenDropdown
        Gui, user_input: Add, Text,, Totals:
        Gui, user_input: Add, Radio, x+10 vTotalModeAll gTotalModeChanged, All
        Gui, user_input: Add, Radio, x+10 vTotalModeClass gTotalModeChanged, Class
        GuiControl,, TotalModeAll, % (TOTALS_DISPLAY = "All") ? 1 : 0
        GuiControl,, TotalModeClass, % (TOTALS_DISPLAY = "Class") ? 1 : 0
        Gui, user_input: Add, Checkbox, x10 y+10 vDebugChoice, Debug
        Gui, user_input: Add, Checkbox, x+10 yp+0 checked%HIDE_GUI% vhide_gui, Hide GUI
        Gui, user_input: Add, Button, x10 y+10 guser_input_OK Default, OK
        if(HIDE_GUI)
        {    
            INPUT_POPUP_HANDLED := true
            Gui, user_input: Destroy
        }
        else
            Gui, user_input: Show
    Return

    ; Handle ClassChoice change
    ClassChoiceChanged:
        Gui, user_input: Submit, NoHide
        CURRENT_GUARDIAN := ClassChoice
        CURRENT_SLOT := PLAYER_DATA[CURRENT_GUARDIAN]["Settings"]["Slot"]
        current_class.update_content("Class - " . CURRENT_GUARDIAN . " | Slot - " CURRENT_SLOT)   
        label_total.update_content("Total AFK Stats (" . (TOTALS_DISPLAY = "All" ? "All" : CURRENT_GUARDIAN) . "):")
        slotDropdown := build_dropdown_string(CHARACTER_SLOTS, PLAYER_DATA[CURRENT_GUARDIAN]["Settings"]["Slot"])
        aachenDropdown := build_dropdown_string(AACHEN_CHOICES, PLAYER_DATA[CURRENT_GUARDIAN]["Settings"]["Aachen"])
        GuiControl,, SlotChoice, % "|" slotDropdown
        GuiControl,, AachenChoice, % "|" aachenDropdown
        total_time_afk_ui.update_content("Time AFK - " format_timestamp(compute_total_stat("time"), true, true, true, false))
        update_ui()
    Return

    ; Handle OK button click
    user_input_OK:
        Gui, user_input: Submit
        CURRENT_GUARDIAN := ClassChoice
        PLAYER_DATA[CURRENT_GUARDIAN]["Settings"]["Slot"] := SlotChoice
        PLAYER_DATA[CURRENT_GUARDIAN]["Settings"]["Aachen"] := AachenChoice
        DEBUG := DebugChoice
        WinActivate, ahk_id %D2_WINDOW_HANDLE%
        INPUT_POPUP_HANDLED := true
        SetTimer, check_tabbed_out, 1000
        Gui, user_input: Destroy
        write_ini()
    Return

    TotalModeChanged:
        Gui, user_input: Submit, NoHide
        if (TotalModeAll = 1) {
            TOTALS_DISPLAY := "All"
        } else if (TotalModeClass = 1) {
            TOTALS_DISPLAY := "Class"
        }
        label_total.update_content("Total AFK Stats (" . (TOTALS_DISPLAY = "All" ? "All" : CURRENT_GUARDIAN) . "):")
        total_time_afk_ui.update_content("Time AFK - " format_timestamp(compute_total_stat("time"), true, true, true, false))
        update_ui()
    Return
    
    ; Exit script when GUI is closed
    GuiClose:
        Gui, user_input: Destroy
    Return
; =================================== ;
