
SendCodeToW3(hwnd := "") {
    if(pl1 != "" && pl2 != "") {
        if(hwnd) {
            ChatI(pl1,hwnd)
            ChatI(pl2,hwnd)
        } else {
            Chat(pl1)
            Chat(pl2)
        }
        Sleep, 1500
        SendAptToW3(hwnd)
    } else {
        MsgBox, 코드를 입력하지 못했습니다.
    }
}

SendAptToW3(hwnd := "") {
    ReadAptFile()
    if(hwnd)
        ChatI(la, hwnd)
    else
        Chat(la)
}


; Account 파일 중 가장 최신 것에서 -la 코드 추출
ReadAptFile() {
    aptFile := GetLatestFile(SAVE_DIR, "Account*.txt")
    if (aptFile.path != "") {
        FileRead, content, % aptFile.path
        RegExMatch(content, "Code:\s*-la\s+([^\r\n]+)", match)
            la := "-la " match1
        RegExMatch(content, "APT:\s*(\d+)", apt)
        RegExMatch(content, "DEDI PTS:\s*(\d+)", dedi)
        GuiControl, main:, AptText, % "APT: " apt1 "`nDEDI: " dedi1
        return aptFile
    } else
        MsgBox, Account*.txt 파일을 찾을수 없습니다.
}

LoadHero(selectedHero := "", hwnd := "") {
    if(selectedHero = ""){
        GuiControlGet, squadText, main:, SquadField
        StringSplit, squad, squadText, `,
        selectedHero := squad1
    }
    if(selectedHero = ""){
        ShowTip("선택된 영웅이 없습니다.")
        return
    }
    UpdateHeroInfo(selectedHero)
    SendCodeToW3(hwnd)
}

UpdateHeroInfo(selectedHero) {
    heroFolder := SAVE_DIR . "\" . selectedHero
    if !FileExist(heroFolder) {
        GuiControl, main:, ResultOutput, 해당 클래스 폴더가 존재하지 않습니다. `n%heroFolder%
        return
    }

    latest := GetLatestFile(heroFolder, selectedHero . "*.txt")
    if (latest.path != "") {
        FileRead, content, % latest.path
        info := ParseHeroFileContent(content)
        info.time := latest.time
        outputText := HeroInfoToText(info)
        pl1 := info.pl1
        pl2 := info.pl2
        GuiControl, main:, ResultOutput, %outputText%
    } else {
        GuiControl, main:, ResultOutput, 해당 클래스에 Hero:%selectedHero% 가 포함된 최신 파일이 없습니다.
    }
}

ParseHeroFileContent(content) {
    info := {}
    RegExMatch(content, "Hero:\s*([A-Za-z\s]+)", m), info.hero := m1
    RegExMatch(content, "Level:\s*(\d+)", m), info.level := m1
    RegExMatch(content, "EXP:\s*(\d+)", m), info.exp := m1
    RegExMatch(content, "Gold:\s*(\d+)", m), info.gold := m1
    RegExMatch(content, "Star Glass:\s*(\d+)", m), info.starGlass := m1
    RegExMatch(content, "Code:\s*(-l[^\r\n""]+)", m), info.pl1 := m1
    RegExMatch(content, "-l2\s+([^\r\n""]+)", m), info.pl2 := "-l2 " . m1
    return info
}

HeroInfoToText(info) {
    FormatTime, fileDateTime, % info.time, yyyy-MM-dd HH:mm:ss
    txt := fileDateTime . "`n"
    txt .= "Hero: " . info.hero . "`n"
    txt .= "Level: " . info.level . "`n"
    txt .= "Exp: " . info.exp . "`n"
    txt .= "Gold: " . info.gold . "`n"
    txt .= "Star Glass: " . info.starGlass . "`n"
    txt .= info.pl1 . "`n" . info.pl2
    return txt
}

LoadSquadI() {
    GuiControlGet, squadText, main:, SquadField
    StringSplit, squad, squadText, `,

    clients := GetClientHwndArray()
    host := client[1]
    for index, client in clients {
        if (index > 1)
            ShareUnit(client)
        
        thisHero := squad%A_Index%
        LoadHero(thisHero, client)
        ChatPI("-qs", client)
        Sleep, 300
        if (thisHero = "Shadowblade") {
            ClickBackEx([{x:0.976, y:0.879, btn:"R",hwnd:client},{x:0.906, y:0.879, btn:"R"}])
        } else if (thisHero = "Barbarian") {
            ClickBack(0.801, 0.953, client, "R")
        } else if (thisHero = "Chaotic Knight") {
            ClickBack(0.797, 0.954, client, "R")
        }
    }
    
    if(clients.Length() >= 2)
        SmartSendKey("^s {F3} ^3 {F2} ^2 {F1} ^1 +{F2} +{F3}", host, 0, "inactive", true)
    else
        SmartSendKey("^s {F1} ^1", host, 0, "inactive", true)
    ChatPI("!dr 10", host)
    ChatPI("-clear", host)
    ChatPI("-apt", host)
}

LoadSquad(champ := false) {
    SwitchW3(1)

    IfWinNotActive, %W3_WINTITLE%
    {
        MsgBox, 현재 활성화된 창이 Warcraft III가 아닙니다. 실행을 중단합니다.
        return
    }
    GuiControlGet, squadText, main:, SquadField
    StringSplit, squad, squadText, `,

    WinGet, w3List, List, %W3_WINTITLE%
    ; squad0 값과 창 수 중 작은 쪽으로 루프 돌리기
    loopCount := Min(squad0,w3List)

    Loop, %loopCount%
    {
        if (A_Index > 1)
            ShareUnit()
        if(!champ) {
            thisHero := squad%A_Index%
            LoadHero(thisHero)
            Chat("-qs")
            Sleep, 300
            if (thisHero = "Shadowblade") {
                ClickA(0.976, 0.879, "R")
                ClickA(0.906, 0.879, "R")
                Sleep, 500
            } else if (thisHero = "Barbarian") {
                ClickA(0.801, 0.953, "R")
                Sleep, 500 
            } else if (thisHero = "Chaotic Knight") {
                ClickA(0.797, 0.954, "R")
                Sleep, 500 
            }
        }
        
        if (loopCount >= 2)
            SwitchNextW3(loopCount = A_Index)
    }
    if(squad0 > 1)
        SmartSendKey("^s {F3} ^3 {F2} ^2 {F1} ^1 +{F2} +{F3}", 0, "", "", true)
    else
        SmartSendKey("^s {F1} ^1", 0, "", "", true)
    if(champ)
        ChampChat() ;!dr -fog -cdist 
    else
        Chat("!dr 10")
    Chat("-apt")
}


LastSaveTimes() {
    GuiControlGet, squad, main:, SquadField ; GUI에서 squad 문자열 얻기
    heroInfo := {} ; 클래스명 => { time: ..., exp: ... }
    ; squad 파싱 (쉼표 구분)
    Loop, Parse, squad, `,
    {
        heroName := Trim(A_LoopField)
        heroFolder := SAVE_DIR "\" heroName
        if !FileExist(heroFolder)
            continue

        latest := GetLatestFile(heroFolder, heroName . "*.txt")
        if (latest.time) {
            FileRead, content, % latest.path
            info := ParseHeroFileContent(content)
            info.time := latest.time
            heroInfo[heroName] := info
        }
    }

    msg := ""
    ; 각 squad 클래스 시간 차이 + EXP 출력
    for heroName, info in heroInfo {
        diff := A_Now
        EnvSub, diff, % info.time, Seconds
        msg := heroName ": " . FormatTimeDiff(diff) . " (" . info.exp . " Exp)`n" . msg
    }

    ; account 파일 시간 차이
    accDiff := A_Now
    EnvSub, accDiff, ReadAptFile().time, Seconds
    msg := "Account: " . FormatTimeDiff(accDiff) . "`n" . msg

    MsgBox, %msg%
}


SwapItems() {
    ClickA(0.187, 0.221)
    ClickA(0.155, 0.374)
    ClickA(0.155, 0.263)
    ClickA(0.192, 0.374)
    ClickA(0.289, 0.270)
    ClickA(0.225, 0.379)
}

MoveOldSaves() {
    MsgBox, 4, MoveOldSaves, 세이브 파일을 이동하시겠습니까?
    IfMsgBox, No
        return

    Loop, Files, %SAVE_DIR%\*, D
    {
        folderName := A_LoopFileName
        if !RegExMatch(folderName, "^[A-Z]")
            Continue

        heroDir := A_LoopFileFullPath
        oldDir := heroDir . "\old_" . folderName
        if !FileExist(oldDir)
            FileCreateDir, %oldDir%

        ; 최신 파일 찾기
        latest := GetLatestFile(heroDir, "*.txt")
        if (latest.path = "")
            continue

        ; 이동할 파일들
        Loop, Files, %heroDir%\*.txt
        {
            if (A_LoopFileFullPath = latest.path)
                continue
            FileMove, %A_LoopFileFullPath%, % oldDir . "\" . A_LoopFileName, 1
        }
    }

    ; Account 파일 처리
    latest := GetLatestFile(SAVE_DIR, "Account*.txt")
    if (latest.path != "") {
        oldAccountDir := SAVE_DIR . "\old_Account"
        if !FileExist(oldAccountDir)
            FileCreateDir, %oldAccountDir%

        Loop, Files, %SAVE_DIR%\Account*.txt
        {
            if (A_LoopFileFullPath = latest.path)
                continue
            FileMove, %A_LoopFileFullPath%, % oldAccountDir . "\" . A_LoopFileName, 1
        }
    }
    MsgBox, 최신 파일 1개를 제외한 나머지 txt 파일을 old_폴더로 이동했습니다.
}