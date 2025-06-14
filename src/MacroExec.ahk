ExecMacro(scriptText, vars, current_path) {
    if (scriptText = "")
        return
    if (runMacroCount > 10)
        return Alert("실행 중인 매크로 수가 10을 초과 합니다.")
    
    ModiKeyWait()

    UpdateMacroState(+1)
    lines := SplitLine(scriptText)
    isConverted := false

    if !IsObject(vars) {
        ShowTip("Warning! : vars is not an object")
        vars := {}
    }
    
    vars.current_path := current_path
    for index, line in lines {
        if(macroAbortRequested)
            break
        line := StripComments(line)
        if (line = "")
            continue

        ExtractVar(vars, "start_line", start_line, "natural")
        tempVars := PrepareConditionVars(line, vars)
        
        ; 조건 확인: force가 없고, skip_mode=vars 이며, start_line 전이면 건너뛰기
        if (!tempVars.HasKey("force")) {
            if (InStr(vars.skip_mode, "vars") && index < start_line)
                continue
        
            if (tempVars.HasKey("if")){
                if(IsLogicExpr(tempVars.if)) {
                    if(!Eval(tempVars.if))
                        continue
                } else {
                    if(!TryStringLogic(tempVars.if))
                        continue
                }
            }
        }

        cmd := ResolveCommand(line, vars)
        ; 조건 2: 실행 전 제어 흐름
        if (ShouldBreak(vars, "wait"))
            break
        
        ; 조건 3: start_line 이후만 실행 (강제 실행 아닌 경우)
        if(!tempVars.HasKey("force")) {
            if(InStr(vars.skip_mode, "vars") || !RegExMatch(cmd, "i)^Read:\s*(.+?)$")) {
                if(index < start_line)
                    continue
            }
        }
        PrepareTargetHwnd(vars)

        EnsureScriptW3VersionMatch(lines, vars, isConverted)

        Loop, % vars.rep
        {
            ExecSingleCommand(cmd, vars, line, index)
            if(cmd != "" && vars.HasKey("limit")) {
                if(index = 1 || vars.limit_mode != "line")
                    vars.limit--
            }
            if (ShouldBreak(vars, "delay"))
                break
        }
    }
    UpdateMacroState(-1)
    ; ShowTip("--- Macro End ---`n,실행중인 매크로 수 : " runMacroCount)
}

PrepareConditionVars(line, vars) {
    temp := Clone(vars)
    ResolveMarker(line, temp, ["if", "force", "end_if"])

    ; if 블록 관리
    if (temp.HasKey("end_if"))
        vars.Delete("if")
    else if (temp.HasKey("if") && vars.if_mode = "block")
        vars.if := temp.if

    ; 문자열 false 처리
    if (StrLower(temp.if) = "false")
        temp.if := false

    return temp
}

ParseKeyValueLine(line, vars, delimiter := "@") {
    if (SubStr(Trim(line), 1, StrLen(delimiter)) != delimiter)
        return false

    parts := StrSplit(line, delimiter)  ; delimiter 기준 분할

    for each, token in parts {
        if !token
            continue

        kv := StrSplit(token, "=", , 2)  ; 최대 2개로 분할
        key := Trim(kv[1])
        val := (kv.Length() = 2) ? Trim(kv[2]) : ""  ; = 없으면 빈값
        vars[key] := val
    }
    return true
}

ResolveCommand(line, vars) {
    if (ParseKeyValueLine(line, vars))
        return
    ; 단일 라인 기본 변수 초기화
    vars.rep := 1
    vars.wait := 0
    vars.delay := vars.HasKey("base_delay") ? vars.base_delay : BASE_DELAY


    cmd := ResolveMarker(line, vars, "", ["if", "force", "end_if"])
    cmd := ResolveExpr(cmd, vars)
    ; 이스케이프 복원 처리
    
    ReplaceEscapeChar(cmd)

    return cmd
}

ExecSingleCommand(command, vars, line := "", index := "") {
    if RegExMatch(command, "i)^Click:([LR])\s*(.+)", m) {
        if(vars.target && !vars.target_hwnd)
            return ShowTip("대상 창이 없습니다.`n" vars.target)

        btn := SubStr(m1,1,1), coords := Trim(m2)
        
        if(vars.HasKey(coords))
            coords := vars[coords]
        
        coords := ParseCoords(coords)

        if(coords)
            SmartClick(coords.x, coords.y, vars.target_hwnd, btn, vars.send_mode, vars.coord_mode, coords.type)
    }
    else if RegExMatch(command, "i)^(SendRaw|Send|Chat):\s*(.*)", m) {
        if(vars.target && !vars.target_hwnd)
            return ShowTip("대상 창이 없습니다." vars.target)

        cmdType := StrLower(m1), key := m2
        if(cmdType = "chat")
            Chat(key, vars.send_mode, vars.target_hwnd)
        else if(cmdType = "sendraw")
            SendKey(key, vars.send_mode . "R", vars.target_hwnd)
        else
            SendKey(key, vars.send_mode, vars.target_hwnd)
    }
    else if RegExMatch(command, "i)^(Sleep|Wait|Delay):\s*(\d*)", m) {
        vars.delay := m2
    }
    else if RegExMatch(command, "^([a-zA-Z0-9_]+)\((.*)\)$", m) {
        WinActivateWait(vars.target_hwnd)
        ExecFunc(m1, m2)
    }
    else if RegExMatch(command, "i)^Exec:\s*(.*)", m) {
        ExecMacroFile(m1, vars)
    }
    else if RegExMatch(command, "i)^Read:\s*(.*)", m) {
        ReadVarsFile(m1, vars)
    }
    else if RegExMatch(command, "i)^(Run|RunAs):\s*(.*)", m) {
        Run_(m1, m2)
    }
    else if (command && line && index) {
        ShowTip("올바른 명령문이 아님 (로그 확인 Alt+L)"
            . "`nPath: " StrReplace(vars.current_path, MACRO_DIR)
            . "`nLineNum : " index
            . "`nLine: " line
            . "`nCmd : " command "`n`n", 5000, true)
    }
}

EnsureScriptW3VersionMatch(lines, vars, ByRef isConverted) {
    if (!isConverted && vars.HasKey("w3_ver") && vars.target_hwnd && IsW3(vars.target_hwnd)) {
        active_w3_ver := GetW3_Ver(vars.target_hwnd)
        if (vars.w3_ver != active_w3_ver) {
            ConvertScriptMode(lines, vars.w3_ver, active_w3_ver)
            isConverted := true
            Log("Convert script: " vars.w3_ver " to " active_w3_ver)
        }
    }
}

ShouldBreak(vars, timeKey) {
    if (!CheckAbortAndSleep(vars[timeKey]))
        return true

    if (vars.HasKey("limit") && !IsNatural(vars.limit))
        return true

    if (vars.HasKey("break"))
        return true

    return false
}

PrepareTargetHwnd(vars) {
    ; 타겟이 없고 hwnd 도 없으면
    if (!vars.HasKey("target") && !vars.target_hwnd) {
        return

    ; 타겟이 변경되었을 경우 새로 검색
    } else if (vars.target != vars._last_target) {
        vars._last_target := vars.target
        if (vars.target) {
            vars.target_hwnd := GetTargetHwnd(vars.target)
            
            if (vars.target_hwnd && !InStr(vars.send_mode, "C", true))
                WinActivateWait(vars.target_hwnd)

            return vars.target_hwnd
        } else {
            vars.target_hwnd := ""
            return
        }

    ; 타겟은 같은데 hwnd 가 없는 경우 → 재검색
    } else if (!vars.target_hwnd) {
        vars.target_hwnd := GetTargetHwnd(vars.target)
        return vars.target_hwnd

    ; 타겟 동일하고 hwnd 있음 → hwnd 유효성 검사 후 반환
    } else if (WinExist("ahk_id " . vars.target_hwnd)) {
        return vars.target_hwnd
    }

    ; hwnd 있었지만 창이 사라졌음 → 재검색 시도
    vars.target_hwnd := GetTargetHwnd(vars.target)
    return vars.target_hwnd
}

ResolveMarker(line, vars, allowedKey := "", excludedKey := "") {
    Log("ResolveMarker(): " line, 4)
    command := line
    pos := 1
    while (found := RegExMatch(line, "(?<!#)#([^#]+)#", m, pos)) {
        fullMatch := m
        inner := Trim(m1)

        ; Match key:val or key=val
        if RegExMatch(inner, "^\s*(\w+)\s*(([:=])\s*(.*))?$", m) {
            key := m1, sep := m3, rawVal := Trim(m4)

            if ((!allowedKey || HasValue(allowedKey, key))
            && (!excludedKey || !HasValue(excludedKey, key))) {
                ; If it's key:value → evaluate expression
                ; If it's key=value  → assign as literal
                val := (sep = ":") ? EvaluateExpr(rawVal, vars) : rawVal
                vars[key] := val
            }
        }
        ; Remove the #...# from command string
        command := StrReplace(command, fullMatch, "")
        pos := found + StrLen(fullMatch)
    }
    return Trim(command)
}

ResolveExpr(line, vars, maxDepth := 5) {
    depth := 0
    prevLine := ""

    while (line != prevLine && depth < maxDepth) {
        prevLine := line
        pos := 1
        while (found := RegExMatch(line, "(?<!%)%([^%]+)%", m, pos)) {
            fullMatch := m
            rawExpr := Trim(m1)
            result := EvaluateExpr(rawExpr, vars)
            line := SubStr(line, 1, found - 1) . result . SubStr(line, found + StrLen(fullMatch))
            pos := found + StrLen(result)
        }
        depth++
    }
    return line
}

ReplaceEscapeChar(ByRef str) {
    str := StrReplace(str, "##", "#")
    str := StrReplace(str, "%%", "%")
}

EvaluateExpr(expr, vars) {
    ; 기본값 문법 처리
    hasDefault := false
    defaultVal := ""
    if (RegExMatch(expr, "^(.*[^|])?\|([^|].*)?$", m)) {
        expr := Trim(m1)
        defaultVal := Trim(m2)
        hasDefault := true
    }

    expr := EvaluateFunctions(expr, vars)

    ; 새 방식으로 키 치환 (안전하게)
    res := ExplodeByKeys(expr, vars)
    expr := res.expr
    isReplaced := res.isReplaced

    ; 기본값에도 동일한 키 치환 적용
    resDef := ExplodeByKeys(defaultVal, vars)
    defaultVal := resDef.expr

    ; 키 치환이 없었고, 기본값 문법이 있었다면 기본값 사용
    if (hasDefault && !isReplaced)
        expr := defaultVal

    return TryEval(expr, vars.dp_mode)
}


ExplodeByKeys(expr, vars) {
    result := []
    sorted := ToKeyLengthSortedArray(vars)

    ; Step 0: 큰따옴표로 감싼 문자열 보호
    while (found := RegExMatch(expr, """([^""]*)""", m)) {
        result[found] := m
        expr := StrReplace(expr, m, Dummy(m, placeHolder), , 1)
    }

    ; Step 1: 키워드(길이 내림차순)를 찾아 dummy로 치환하며 값 저장
    for i, item in sorted {
        while (found := RegExMatch(expr, item.key, m)) {
            is_replaced := true
            result[found] := item.value
            expr := StrReplace(expr, m, Dummy(m, placeHolder), , 1)
        }
    }

    ; Step 2: 남은 일반 문자열 처리
    while (found := RegExMatch(expr, "[^" . placeHolder . "]+", m)) {
        result[found] := m
        expr := StrReplace(expr, m, Dummy(m, placeHolder), , 1)
    }

    return {expr: StrJoin(result, ""), isReplaced: is_replaced}
}

EvaluateFunctions(expr, vars) {
    pos := 1
    while (found := RegExMatch(expr, "(\w+)\(([^)]*)\)", m, pos)) {
        full := m, fnName := m1, argStr := m2

        Log("EvaluateFunctions(): " full)

        args := StrSplit(argStr, ",")

        Loop % args.Length()
        {
            val := args[A_Index]
            val := Trim(val)
            val := ExplodeByKeys(val, vars).expr  ; 변경: 결과에서 .expr 만 사용
            args[A_Index] := TryEval(val)
        }

        result := ExecFunc(fnName, args)
        expr := StrReplace(expr, full, result)
        ;test(fnname, args, result ,pos , expr, full)
        pos := found + StrLen(result)
    }
    return expr
}

ReadVarsFile(path, vars) {
    fullPath := ResolveMacroFilePath(path, vars)

    if (!vars.HasKey("__Readed__"))
        vars["__Readed__"] := {}

    if (vars["__Readed__"].HasKey(fullPath))
        return

    vars["__Readed__"][fullPath] := true

    content := ReadFile(fullPath)

    ParseVars(content, vars)
}

ParseVars(content, vars) {
    lines := SplitLine(content)
    for index, line in lines {
        line := Trim(line)
        line := StripComments(line)

        if (RegExMatch(line, "i)^Read:\s*(.+?)$", m)) {
            ReadVarsFile(m1, vars)  ; 재귀 Read
            continue
        }

        parts := StrSplit(line, "=",, 2)
        if (parts.Length() < 2)
            continue
        
        key := Trim(parts[1])
        val := Trim(parts[2])
        if (key != "" && val != "")
            vars[key] := val
    }
}

Run_(mode, path) {
    try {
        if (StrLower(mode) = "runas") {
            Run *RunAs %path%
        } else {
            Run %path%
        }
    } catch e {
        MsgBox, 16, Run Failed, % "Failed to run:`n" path "`n`nError: " e.Message
    }
}

ExecFunc(fnName, argsStr) {
    fn := Func(fnName)
    if !IsObject(fn)
        return Alert("Function " fnName " not found.")

    ; argsStr가 배열이 아니라면 쉼표로 나눔
    if !IsObject(argsStr) {
        args := []
        argsStr := StrReplace(argsStr, "``,", placeHolder)
        Loop, Parse, argsStr, `,  ; 문자열로 간주하고 파싱
        {
            arg := UnescapeLiteral(Trim(A_LoopField, " `t""'"))
            args.Push(arg)
        }
    } else {
        args := argsStr  ; 이미 배열이면 그대로 사용
    }
    Log("ExecFunc(): " fnName "() args : " StrJoin(args, ", "))
    return fn.Call(args*)
}

ExecMacroFile(macroFilePath, vars) {
    fullPath := ResolveMacroFilePath(macroFilePath, vars)
    if (fullPath)
        ExecMacro(ReadFile(fullPath), vars, fullPath)
}

ResolveMacroFilePath(macroFilePath, vars) {
    AppendExt(macroFilePath)
    macroFilePath := StrReplace(macroFilePath, "/", "\")

    if (IsAbsolutePath(macroFilePath))
        return macroFilePath

    try1 := GetContainingFolder(vars.current_path) . "\" . macroFilePath
    if (IsFile(try1))
        return try1

    try2 := GetContainingFolder(vars.base_path) . "\" . macroFilePath
    if (IsFile(try2))
        return try2    

    try3 := MACRO_DIR . "\" . macroFilePath
    if (IsFile(try3))
        return try3

    Alert("매크로 파일을 찾을 수 없습니다.`n" . try1 . "`n" . try2 . "`n" . try3, "Error", 0)
    return false
}

UpdateMacroState(delta) {
    runMacroCount += delta
    if (runMacroCount > 0) {
        GuiControl, macro:Text, execBtn, ■ Stop
    } else {
        GuiControl, macro:Text, execBtn, ▶ Run
        macroAbortRequested := false
    }
}

CheckAbortAndSleep(totalDelay) {
    endTime := A_TickCount + totalDelay
    while (A_TickCount < endTime) {
        if (macroAbortRequested) {
            ShowTip("매크로 중단 요청")
            return false
        }
        Sleep, % Min(100, totalDelay)
    }
    return !macroAbortRequested
}