ToggleMacroGui:
    ToggleMacroGui()
return

mainGuiClose:
    SaveCodeLoaderSettings()
    SaveMacroEditorSettings()
    ExitApp
return

MultiLoad:
    LoadSquad()
return

ExecMultiW3:
    ExecMultiW3()
return

HeroButtonClick:
    Gui, Submit, NoHide
    GuiControlGet, btnText, main:, %A_GuiControl% ; 버튼의 텍스트를 가져온다
    UpdateHeroInfo(btnText)
return

AddHero:
    GuiControlGet, resultText, main:, ResultOutput
    if(!resultText)
        return
    heroNames := ""

    Loop, Parse, resultText, `n, `r
    {
        if (RegExMatch(A_LoopField, "Hero:\s*(.+)", match))
            heroNames .= match1 . ","
    }

    ; 마지막 쉼표 제거
    StringTrimRight, heroNames, heroNames, 1
    GuiControlGet, oldSquad, main:, SquadField

    ; 일반 클릭 시 클래스 추가
    if (oldSquad != "")
        newSquad := oldSquad . "," . heroNames
    else
        newSquad := heroNames
    GuiControl, main:, SquadField, %newSquad%
    SetIniValue("Settings","SavedSquad",newSquad) 
return

RemoveHero:
    GuiControlGet, oldSquad, main:, SquadField
    if (oldSquad = "")
        return
    newSquad := TrimLastToken(oldSquad, ",")
    GuiControl, main:, SquadField, %newSquad%
    SetIniValue("Settings","SavedSquad",newSquad)
return

AptBtn:
    ReadAptFile()
    if(la != "" && WinExist(w3Win)) {
        WinActivate, %w3Win%
        Chat(la)
    }
return

LoadBtn:
    if(WinExist(w3Win)) {
        WinActivate, %w3Win%
        SendCodeToW3()
    }
return

#If (WinActive("ahk_class Warcraft III") and yMapped and !isRecording)
; Y → F (조합키 포함)
*f::SendMapped("y")
; F → Y (조합키 포함)
*y::SendMapped("f")

; Ctrl+F 예외처리
; ^f::
;     if (yMapped)
;         Send ^f  ; yMapped 상태에서는 실제 f 키 전송
;     else
;         Send ^f  ; 그대로
; return

#IfWinActive ahk_class Warcraft III
^y::ToggleYMapping(2)

; 키 매핑 토글
ToggleYMapping(force := 2) {
    if (force != 2)
        yMapped := !!force
    else
        yMapped := !yMapped
    ShowTip(yMapped ? "🟢 y↔f 매핑 켜짐" : "🔴 y↔f 매핑 꺼짐")
}

; 실제 전송 함수 (Shift, Ctrl 등 고려)
SendMapped(key) {
    mods := ""
    if (GetKeyState("Shift", "P"))
        mods .= "+"
    if (GetKeyState("Ctrl", "P"))
        mods .= "^"
    if (GetKeyState("Alt", "P"))
        mods .= "!"
    if(yMapped && mods = "^" && key = "y")
        mods := "", key := "f"
    Send, % mods key
}

;Interact
F4::
    SendKey("n",550)
    SendKey("{Numpad8}",100)
    SendKey("i",100)
    MouseClick,L
return

F5::Chat("-inv")
F6::Chat("-tt")

;마우스 가두기
F7::ClipWindow()

;아이템 교체
!x::
    KeyWait, Alt
    GuiControlGet, squadText, %hMain%:, SquadField
    StringSplit, squad, squadText, `,
    WinGet, w3List, List, %W3_WINTITLE%
    loopCount := Min(squad0,w3List)
    Loop, %loopCount%
    {
        gosub, F5
        Sleep, 200
        SwapItems()
        if (A_Index < loopCount)
            SwitchW3(false)
        else    
            SwitchToMainW3()
        Sleep, 300
    }
return

;Ctrl+Shift+C
^+n::ChampChat()
ChampChat() {
    Chat("!dr 10")
    Chat("-fog")
    Chat("-cdist 2300")
    Chat("-music")
    Chat("-spsi 4")
    SendAptToW3()
}

!+w::SaveW3Pos()

#If ;워크래프트3 내에서만 작동 끝

;Alt
!e::RestoreW3Pos()
!3::SwitchToMainW3()
!2::TrySwitchW3()
!u::MoveOldSaves()
!t::LoadSquad()
!h::LoadSquad(true) ;Champion Mode


;Ctrl+Shift
^+k::ExecW3()
^+a::SendAptToW3()
^+w::ExecMultiW3()
^+h::ExecHostW3()
^+c::LastSaveTimes()
^+i:: Run, notepad.exe "%CONFIG_FILE%"
^+o:: Run, %A_ScriptDir%
^+p:: Run, %SAVE_DIR%

;매크로 재시작
^+R::
    SaveCodeLoaderSettings()
    SaveMacroEditorSettings()
    reload
return