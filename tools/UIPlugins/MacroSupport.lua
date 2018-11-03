local tSet
local function Init_hidden()

    MACRO = {}

    function MACRO.RestoreColumn(col)
        local line = editor:LineFromPosition(editor.CurrentPos)
        local lineStart = editor:PositionFromLine(line)
        local ln = editor.LineEndPosition[line] - lineStart
        if ln > col then
            editor:SetSel(lineStart + col, lineStart + col )
            editor:ReplaceSel('')
        else
            editor:SetSel(lineStart + ln, lineStart + ln)
            editor:ReplaceSel('')
            editor.SelectionNAnchorVirtualSpace[0] = col - ln
            editor.SelectionNCaretVirtualSpace[0] = col - ln
        end
    end

    function MACRO.SelToPosition(col)
        local line = editor:LineFromPosition(editor.CurrentPos)
        local lineStart = editor:PositionFromLine(line)
        local ln = editor.LineEndPosition[line] - lineStart
        local c1 = editor.SelectionNAnchorVirtualSpace[0]
        if ln > col then
            editor:SetSel(editor.CurrentPos, lineStart + col)
            editor.SelectionNAnchorVirtualSpace[0] = c1
        else
            editor:SetSel(editor.CurrentPos, lineStart + ln)
            editor.SelectionNAnchorVirtualSpace[0] = c1
            editor.SelectionNCaretVirtualSpace[0] = col - ln
        end
    end

    function MACRO.SelectWord()
        local current_pos = editor.CurrentPos
        return editor:SetSel(editor:WordStartPosition(current_pos, true),
        editor:WordEndPosition(current_pos, true))
    end

    function MACRO.ReplaceSel(s)
        s = s..''
        local prevSel = editor.SelectionStart
        local prevSelEnd = editor.SelectionEnd
        local col = editor.Column[prevSelEnd] + editor.SelectionNAnchorVirtualSpace[0]
        local line = editor:LineFromPosition(prevSelEnd)
        local lineStart = editor:PositionFromLine(line)
        local ln = editor.LineEndPosition[line] - lineStart
        if ln < col and prevSelEnd == prevSel then s = string.rep(' ', col - ln)..s end
        if ln > col and editor.Overtype then
            if prevSelEnd ~= prevSelEnd then col = col - 1 end
            local nEnd = ln - col
            if nEnd > #s then nEnd = #s end
            editor.SelectionEnd = editor.SelectionEnd + nEnd
        end
        editor:ReplaceSel(s)
        editor.SelectionStart = prevSel + #s
        editor.SelectionEnd = editor.SelectionStart
    end

    local SavedState, MC, pCurBlock, positions_t, lines_t, recordet_macros, recorded_props, started_overtype, macro_list
    local jCounter, caret_fore, started_cycle, params, overtype

    local function nextMC(force)
        if force or MC.typ then
            table.insert(pCurBlock, MC)
            local prevSel = editor.SelectionStart
            local prevSelEnd = editor.SelectionEnd
            local col = editor.Column[prevSelEnd] + editor.SelectionNAnchorVirtualSpace[0]
            MC = {Start = editor.SelectionStart, End = editor.SelectionEnd,
                Anchor = editor.SelectionNAnchorVirtualSpace[0],
            Caret = editor.SelectionNCaretVirtualSpace[0]}
        end
    end

    local prevCol
    local function local_OnMacro(typ, fname, w, l, s)
        if not MACRO.Record then return end
        -- print(typ, fname, w, l, s)
        if fname == 'ReplaceSel' then
            if s == '\n' or s == '\r' then
                if s == '\n' then return end
                fname = 'NewLine'; s = nil; w = nil; l = nil
            else
                typ = "P"
            end
        elseif prevCol and (fname == 'LineUp' or fname == 'LineDown') then
            --!!!!Компенсируем некорректное поведение этих функций при записи макросов
            scite.RunAsync(function() MACRO.RestoreColumn(prevCol) end)
        end
        prevCol = editor.Column[editor.CurrentPos] + editor.SelectionNAnchorVirtualSpace[0]

        if typ ~= 'L' and MC.typ == typ and MC.fname == fname and MC.w == w and MC.l == l then
            if MC.fname == 'ReplaceSel' then --повтор функции со строковым параметром
                MC.s = MC.s..s
                return
            else --повтор обычных функции
                MC.count = MC.count + 1
                return
            end
        end

        nextMC(true)
        MC.typ = typ; MC.fname = fname; MC.w = w; MC.l = l; MC.s = s; MC.count = 1
    end


    local function do_KeepPosition()
        table.insert(positions_t, {name = 'Position '..(#positions_t + 1), pos = editor.Column[editor.CurrentPos] + editor.SelectionNAnchorVirtualSpace[0]})
        local_OnMacro('L', 'column'..#positions_t..' = editor.Column[editor.CurrentPos] + editor.SelectionNAnchorVirtualSpace[0]')
    end

    local function do_KeepLine()
        table.insert(lines_t, {name = 'Line '..(#lines_t + 1), pos = editor:LineFromPosition(editor.CurrentPos)})
        local_OnMacro('L', 'line'..#lines_t..' = editor:LineFromPosition(editor.CurrentPos)')
    end

    local function do_BeginFor()
        local ret, num, isConst, cap =
        iup.GetParam(_T"New Command Block Repetition".."^macros",
            function(h, id)
                if id == iup.GETPARAM_BUTTON1 then
                    local cap = iup.GetParamParam(h, 1).value
                    for i = 1, #params do
                        if params[i].caption == cap then
                            iup.Alarm(_T"Macro", _FMT(_T'Caption "%1" is already in use', cap), _TH'Ok')
                            return 0
                        end
                    end
                end
                return 1
            end,
            _T'Number of Repetition'..'%i[1,1000,1]\n'..
            _T'Constant'..'%b\n'..
            _T'Caption'..'%s\n'
            ,
            2, 0,
            '<New Repeat '..(#params + 1)..'>'
        )
        if ret then
            local sSuff = Iif(isConst == 0, '%i[1,1000,1]', nil)
            table.insert(params, {caption = cap, typ = 'for', suff = sSuff, id = #params + 1, num = num})
            nextMC()

            newBlock = {typ = 'for', id = #params, pUpper = pCurBlock, jCounter = jCounter}
            jCounter = jCounter + 1
            table.insert(pCurBlock, newBlock)
            pCurBlock = newBlock
        end
    end

    local function str2strScript(v)
        return v:gsub("\\", "\\\\"):gsub("'", "\\'"):gsub('"', '\\"')
    end

    local function do_NewFind()
        local ret, txt, cap, isPar, isUp, isSel, isWW, isRE, isCS, isNot, isBrk =
        iup.GetParam(_T"New Macro Find".."^macros",
            function(h, id)
                if id == iup.GETPARAM_BUTTON1 then
                    local cap = iup.GetParamParam(h, 1).value
                    for i = 1, #params do
                        if params[i].caption == cap then
                            iup.Alarm(_T"Macro", _FMT(_T'Caption "%1" is already in use', cap), _TH'Ok')
                            return 0
                        end
                    end
                end
                return 1
            end,
            _T"Find".."%s\n"..
            _T"Caption".."%s\n"..
            " %o".._T"|Constant|Input Parameter|".."\n"..
            " %o".._T"|Down|Up|".."\n"..
            _T"In Selection".."%b\n"..
            _T"Whole Word".."%b\n"..
            "RegExp%b\n"..
            _T"Case Sensitive".."%b\n"..
            _T"Call next Block If".."%o".._T"|Found|Not Found|".."\n"..
            _T"Else Exit Macro".."%b\n",
            "", "<Find "..(#params + 1)..">", 0, 0, 0, 0, 0, 0, 0, 0
        )
        if ret then
            local newF = {}
            newF.isBrk = isBrk
            newF.isNot = isNot
            newF.isCS = isCS
            newF.isRE = isRE
            newF.isWW = isWW
            newF.isSel = isSel
            newF.isUp = isUp
            newF.isPar = isPar
            newF.cap = cap
            newF.findWhat = txt

            MACRO.Record = false
            local bFound = MACRO.Find(newF)
            MACRO.Record = true

            if bFound then
                local sSuff = Iif(isPar == 1, '%s', nil)
                table.insert(params, {caption = cap, typ = 'find', suff = sSuff, id = #params + 1, tbl = newF, str = str2strScript(txt)})
                nextMC()

                newBlock = {typ = 'find', id = #params, pUpper = pCurBlock}
                table.insert(pCurBlock, newBlock)
                pCurBlock = newBlock
            else
                iup.Alarm(_T"Macro", _T"Text not found search not saved", 'Ok')
            end

        end
    end

    local function play_find(i)

        local tbl = params[i].tbl

        local bFound = MACRO.Find(tbl)

        if bFound then
            nextMC()

            newBlock = {typ = 'find', id = #params, pUpper = pCurBlock}
            table.insert(pCurBlock, newBlock)
            pCurBlock = newBlock
        end
    end

    function MACRO.Find(tFind)
        local findSettings = seacher{
            wholeWord = (tFind.isWW == 1)
            , matchCase = (tFind.isCS == 1)
            , regExp = (tFind.isRE == 1)
            , searchUp = (tFind.isUp == 1)
            , wrapFind = false
            , backslash = false
            , style = nil
            , replaceWhat = ''
        }

        findSettings.findWhat = tFind.findWhat

        local sS, sE = editor.SelectionStart, editor.SelectionEnd
        if tFind.isSel == 1 then
            if tFind.isUp == 1 then
                editor.SelectionStart = editor.SelectionEnd
            else
                editor.SelectionEnd = editor.SelectionStart
            end
        end
        local pFind = findSettings:FindNext(false, true)
        if pFind >= 0 and tFind.isSel == 1 then
            if pFind < sS or pFind > sE or editor.TargetEnd < sS or editor.TargetEnd > sE then
                pFind = -1
                editor.SelectionStart, editor.SelectionEnd = sS, sE
            end
        end
        if pFind >= 0 then
            editor:SetSel(pFind, editor.TargetEnd)
        end
        local rez = (pFind > 0)
        if tFind.isNot == 1 then rez = not rez end
        if not rez and tFind.isBrk == 1 then error('----') end
        return rez
    end

    local function do_PasteHist()
        local tItems = {'<Fixed>'}
        local tId = {}
        local pB = pCurBlock
        while pB.pUpper do
            if params[pB.id].typ == 'for' then
                table.insert(tId, pB.id)
                table.insert(tItems, params[pB.id].caption)
            end
            pB = pB.pUpper
        end

        local ret, num, fix, reverce =
        iup.GetParam(_T"Pasting From History".."^macros",
            nil,
            _T'Repetition Parameter'..'%l|'..table.concat(tItems, '|')..'|\n'..
            _T'Fixed'..'%i[1,100,1]\n'..
            _T'Move Up the list'..'%b\n'
            ,
            0, 0, 0
        )
        if ret then
            local id
            if num == 0 then
                id = fix
            else
                id = Iif(reverce == 1, 'par', 'j')..tId[num]
            end

            MACRO.Record = false
            if num == 0 then
                MACRO.ReplaceSel(CLIPHISTORY.GetClip(id, reverce == 1) or "")
            elseif reverce == 1 then
                MACRO.ReplaceSel(CLIPHISTORY.GetClip(params[tId[num]].num, true) or "")
            else
                MACRO.ReplaceSel(CLIPHISTORY.GetClip(1) or "")
            end
            MACRO.Record = true

            nextMC()

            MC.typ = 'L'; MC.fname = 'MACRO.ReplaceSel(CLIPHISTORY.GetClip('..id..', '..Iif(reverce == 1, 'true', 'false')..') or "")'
            nextMC()
        end
    end

    local function ClearSciKeys()
        if CLIPHISTORY then
            editor:ClearCmdKey(string.byte'Y', SCMOD_CTRL)
            editor:ClearCmdKey(string.byte'Z', SCMOD_CTRL)
            editor:ClearCmdKey(string.byte'C', SCMOD_CTRL)
            editor:ClearCmdKey(string.byte'V', SCMOD_CTRL)
            editor:ClearCmdKey(string.byte'X', SCMOD_CTRL)
            editor:ClearCmdKey(SCK_INSERT, SCMOD_CTRL)
            editor:ClearCmdKey(SCK_INSERT, SCMOD_SHIFT)
        end
    end
    local function ReassignSciKeys()
        if CLIPHISTORY then
            editor:AssignCmdKey(string.byte'Y', SCMOD_CTRL, SCI_REDO)
            editor:AssignCmdKey(string.byte'Z', SCMOD_CTRL, SCI_UNDO)
            editor:AssignCmdKey(string.byte'C', SCMOD_CTRL, SCI_COPY)
            editor:AssignCmdKey(string.byte'V', SCMOD_CTRL, SCI_PASTE)
            editor:AssignCmdKey(string.byte'X', SCMOD_CTRL, SCI_CUT)
            editor:AssignCmdKey(SCK_INSERT, SCMOD_CTRL    , SCI_COPY)
            editor:AssignCmdKey(SCK_INSERT, SCMOD_SHIFT   , SCI_PASTE)

        end
    end

    local function do_BeginIf()
        local ret, def, cap =
        iup.GetParam(_T"New Condition".."^macros",
            function(h, id)
                if id == iup.GETPARAM_BUTTON1 then
                    local cap = iup.GetParamParam(h, 1).value
                    for i = 1, #params do
                        if params[i].caption == cap then
                            iup.Alarm(_T"Macro", _FMT(_T'Caption "%1" is already in use', cap), _TH'Ok')
                            return 0
                        end
                    end
                end
                return 1
            end,
            _T'Default'..'%b\n'..
            _T'Caption'..'%s\n'
            ,
            0,
            '<New Condition '..(#params + 1)..'>'
        )
        if ret then
            table.insert(params, {caption = cap, typ = 'if', suff = '%b', id = #params + 1, num = 1, default = def})
            nextMC()

            newBlock = {typ = 'if', id = #params, pUpper = pCurBlock}
            table.insert(pCurBlock, newBlock)
            pCurBlock = newBlock
        end
    end

    local function do_NewStringPar()
        local ret, val, def, cap =
        iup.GetParam(_T"New String Parameter".."^macros",
            function(h, id)
                if id == iup.GETPARAM_BUTTON1 then
                    local cap = iup.GetParamParam(h, 1).value
                    for i = 1, #params do
                        if params[i].caption == cap then
                            iup.Alarm(_T"Macro", _FMT(_T'Caption "%1" is already in use', cap), _TH'Ok')
                            return 0
                        end
                    end
                end
                return 1
            end,
            _T'Value'..'%s\n'..
            _T'Use By Default'..'%b\n'..
            _T'Caption'..'%s\n'
            ,
            '',
            0,
            '<New String '..(#params + 1)..'>'
        )
        if ret then
            table.insert(params, {caption = cap, typ = 'str', suff = '%s', id = #params + 1, str = str2strScript(val), default = def})
            nextMC()

            MACRO.Record = false
            MACRO.ReplaceSel(val)
            MACRO.Record = true

            MC.typ = 'L'; MC.fname = 'MACRO.ReplaceSel(par'..#params..')'
            nextMC()

        end
    end

    local function insert_string(id)
        nextMC()

        local val = params[id].str

        MACRO.Record = false
        MACRO.ReplaceSel(val)
        MACRO.Record = true

        MC.typ = 'L'; MC.fname = 'MACRO.ReplaceSel(par'..id..')'
        nextMC()
    end

    local function insert_iffor_block(id, typ)
        nextMC()
        newBlock = {typ = typ, id = id, pUpper = pCurBlock}
        if typ == 'for' then
            newBlock.jCounter = jCounter
            jCounter = jCounter + 1
        end
        table.insert(pCurBlock, newBlock)
        pCurBlock = newBlock
    end

    local function do_RestoreColumn(p)
        local_OnMacro('P', 'RestoreColumn', 'column'..p)
        MACRO.RestoreColumn(positions_t[p].pos)
    end
    local function do_SelToPosition(p)
        local_OnMacro('P', 'SelToPosition', 'column'..p)
        MACRO.SelToPosition(positions_t[p].pos)
    end

    local function submenu_positions()
        local t = {}
        for i = 1, #positions_t do
            table.insert(t, {positions_t[i].name, action = function() do_RestoreColumn(i) end})
        end
        return t
    end

    local function submenu_lines()
        local t = {}
        for i = 1, #lines_t do
            table.insert(t, {lines_t[i].name, action = function()
                local p = editor:PositionFromLine(lines_t[i].pos); editor.SelectionStart = p; editor.SelectionEnd = p
                local_OnMacro('L', 'do local p = editor:PositionFromLine(line'..i..'); editor.SelectionStart = p; editor.SelectionEnd = p end')
            end})
        end
        return t
    end

    local function update_position_list()
        local t = {}
        for i = 1, #positions_t do
            table.insert(t, {positions_t[i].name, action = function()
                positions_t[i].pos = editor.Column[editor.CurrentPos] + editor.SelectionNAnchorVirtualSpace[0]
                local_OnMacro('L', 'column'..i..' = editor.Column[editor.CurrentPos] + editor.SelectionNAnchorVirtualSpace[0]')
            end})
        end
        if #t > 0 then table.insert(t,{"s", separator = 1}) end
        return t
    end

    local function update_line_list()
        local t = {}
        for i = 1, #lines_t do
            table.insert(t, {lines_t[i].name, action = function()
                lines_t[i].pos = editor:LineFromPosition(editor.CurrentPos)
                local_OnMacro('L', 'line'..i..' = editor:LineFromPosition(editor.CurrentPos)')
            end})
        end
        if #t > 0 then table.insert(t,{"s", separator = 1}) end
        return t
    end

    local function submenu_selto_positions()
        local t = {}
        for i = 1, #positions_t do
            table.insert(t, {positions_t[i].name, action = function() do_SelToPosition(i) end})
        end
        return t
    end

    local function submenu_selto_line()
        local t = {}
        for i = 1, #lines_t do
            table.insert(t, {lines_t[i].name, action = function()
                local p = editor:PositionFromLine(lines_t[i].pos) if p > editor.CurrentPos then editor.SelectionEnd = p else editor.SelectionStart = p end
                local_OnMacro('L', 'do local p = editor:PositionFromLine(line'..i..') if p > editor.CurrentPos then editor.SelectionEnd = p else editor.SelectionStart = p end end')
            end})
        end
        return t
    end

    local function GetBlock(b)
        local sOut, sVal = '', ''

        local function defFind(strOut, i)
            sOut = sOut..'    local tFind'..i..' = {'
            for tN, fP in pairs(params[i].tbl) do
                if type(fP) == 'number' then
                    sOut = sOut..tN..' = '..fP..'; '
                end
            end
            sOut = sOut..'findWhat = '..Iif(params[i].tbl.isPar == 1, 'par'..i, '"'..params[i].str..'"')..'}\n'
        end

        sOut = ''
        for i = 1, #positions_t do
            if i == 1 then
                sOut = sOut..'\nlocal '
            else
                sOut = sOut..', '
                if MACRO.Record then sVal = sVal..', ' end
            end
            sOut = sOut..'column'..i
            if MACRO.Record then sVal = sVal..positions_t[i].pos end
        end
        if MACRO.Record then sOut = sOut..' = '..sVal; sVal = '' end
        for i = 1, #lines_t do
            if i == 1 then
                sOut = sOut..'\nlocal '
            else
                sOut = sOut..', '
                if MACRO.Record then sVal = sVal..', ' end
            end
            sOut = sOut..'line'..i
            if MACRO.Record then sVal = sVal..lines_t[i].pos end
        end
        if MACRO.Record then sOut = sOut..' = '..sVal end

        if MACRO.Record then
            for i = 1,  #params do
                if params[i].typ == 'find' then
                    defFind(strOut, i)
                else

                    sOut = sOut..'\nlocal par'..i..' = '..params[i].num
                end
            end
        else
            if #params > 0 then
                local strUp = '\nlocal ret'
                local strParams = ''
                local strValues = ''
                local isDlg, isFind = false, false
                for i = 1,  #params do
                    if params[i].typ == 'find' then isFind = true end
                    if params[i].suff then
                        isDlg = true
                        strUp = strUp..', par'..i
                        strParams = strParams..'\n"'..params[i].caption..params[i].suff..'\\n"..'
                        if params[i].typ == 'for' or params[i].typ == 'cnt' then
                            strValues = strValues..',\n'..params[i].num
                        elseif params[i].typ == 'if' then
                            strValues = strValues..',\n'..params[i].default
                        elseif params[i].typ == 'str' or params[i].typ == 'find' then
                            strValues = strValues..',\n"'..Iif(params[i].default == 1, params[i].str, '')..'"'
                        end
                    else
                        if params[i].typ == 'for' or params[i].typ == 'cnt' then
                            sOut = sOut..'\nlocal par'..i..' = '..params[i].num
                        end
                    end
                end
                if isDlg then
                    sOut = sOut..strUp..
                    ' = \niup.GetParam(_T"Macro Parameters".."^macros", nil,'..strParams..
                    '\n"" '..strValues..")\nif not ret then return end"
                end
                if isFind then
                    sOut = sOut..'\n'
                    for i = 1,  #params do
                        if params[i].typ == 'find' then
                            defFind(strOut, i)
                        end
                    end
                end
            end
        end

        local function get_block_script(block, nTab)
            local indent = string.rep(' ', editor.Indent * nTab)
            local line
            for i = 1,  #block do
                line = indent
                if block[i].typ == 'F' or block[i].typ == 'P' then
                    if block[i].count > 1 then
                        line = line..'for i = 1, '..block[i].count..' do '
                    end

                    if block[i].typ == 'F' then
                        line = line..'editor:'..block[i].fname..'('
                    else
                        line = line..'MACRO.'..block[i].fname..'('
                    end

                    local nextComma = false
                    if block[i].w then
                        nextComma = true
                        line = line..block[i].w
                    end

                    if block[i].l then
                        if nextComma then line = line..', ' end
                        line = line..block[i].l
                    elseif block[i].s then
                        if nextComma then line = line..', ' end
                        line = line.."'"..block[i].s:gsub('\\', '¦'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub("'", '\\x27'):gsub('¦', '\\\\').."'"
                    end

                    line = line..')'

                    if block[i].count > 1 then
                        line = line..' end'
                    end
                elseif block[i].typ == 'L' then
                    line = line..block[i].fname
                elseif block[i].typ == 'for' then
                    local jStart = 1
                    if MACRO.Record then if pCurBlock == block[i] then jStart = 2 end end
                    sOut = sOut..'\n'..line..'for j'..block[i].jCounter..' = '..jStart..', par'..block[i].id..' do'

                    get_block_script(block[i], nTab + 1)
                    line = line..'end\n'
                elseif block[i].typ == 'if' then
                    sOut = sOut..'\n'..line..'if par'..block[i].id..' == 1 then'
                    get_block_script(block[i], nTab + 1)
                    line = line..'end\n'
                elseif block[i].typ == 'find' then
                    sOut = sOut..'\n'..line..'if MACRO.Find(tFind'..block[i].id..') then'
                    get_block_script(block[i], nTab + 1)
                    line = line..'end\n'
                end
                sOut = sOut..'\n'..line
                --sOut = sOut..';'..line
            end
        end

        get_block_script(b, 1)

        return sOut..'\n::exit::'
    end

    local function do_StopBlock()
        nextMC()
        local par = params[pCurBlock.id]

        if par.typ == 'for' and par.num > 1 then
            --par.num = par.num - 1
            local scr = GetBlock({pCurBlock}, num)
            MACRO.Record = false

            local bOk, msg = pcall(dostring, scr)
            if not bOk and not (msg or ''):find('----') then
                print(msg, scr)
            end
            MACRO.Record = true
            --par.num = par.num + 1
        end
        pCurBlock = pCurBlock.pUpper
    end

    local function do_Undo()
        if MC.typ then
            if MC.fname == 'ReplaceSel' then
                MC.s = MC.s:gsub('.$', '')
                MACRO.Record = false
                editor:DeleteBack()
                MACRO.Record = true
                if MC.s ~= '' then return end
            end
            if MC.fname == 'NewLine' then
                MACRO.Record = false
                editor:DeleteBack()
                MACRO.Record = true
            end
            editor.SelectionStart = MC.Start
            editor.SelectionEnd = MC.End
            editor.SelectionNAnchorVirtualSpace[0] = MC.Anchor
            editor.SelectionNCaretVirtualSpace[0] = MC.Caret
            if #pCurBlock > 0 then
                MC = pCurBlock[#pCurBlock]
                pCurBlock[#pCurBlock] = nil
            else
                --
            end
        end
    end

    local function GetScript()
        local scr = GetBlock(recordet_macros)
        local p = '--dorepeat='..(recorded_props.dorepeat or (Iif(scr:find('iup%.GetParam%(_T"'), 0, 1)))..';abbr='..(recorded_props.abbr or '')
        return p..'\neditor.Overtype = '..Iif(overtype, 'true', 'false')..'\n'..scr
    end

    OnMacroBlockedEvents = function(msg, wParam, lParam)
        if msg == 516 then
            menuhandler:PopUp('MainWindowMenu|Macro')
        end
        if not editor.Focus then iup.PassFocus() end
        return 1
    end

    local onContextMenuGlobal
    local function OnContextMenu_local()
        menuhandler:PopUp('MainWindowMenu|Macro')
    end

    local function SaveState()

        SavedState = {}
        if true then
            SavedState.bMenuBar = iup.GetDialogChild(iup.GetLayout(), "MenuBar").isOpen()
            SavedState.bToolBar = iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").isOpen()
            SavedState.bStatusBar = iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").isOpen()
            SavedState.bTabBar = iup.GetDialogChild(iup.GetLayout(), "TabbarExpander").state == 'OPEN'
            if SavedState.bMenuBar then iup.GetDialogChild(iup.GetLayout(), "MenuBar").switch() end
            if SavedState.bToolBar then iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").switch() end
            if SavedState.bStatusBar then iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").switch() end
            if SavedState.bTabBar then iup.GetDialogChild(iup.GetLayout(), "TabbarExpander").state = 'CLOSE' end

            if ((_G.iuprops['sidebar.win'] or '0')~= '2') and SideBar_obj.handle then SavedState.SideBar = _G.iuprops['sidebar.win'] end
            if ((_G.iuprops['leftbar.win'] or '0')~= '2') and LeftBar_obj.handle then SavedState.LeftBar = _G.iuprops['leftbar.win'] end
            if (_G.iuprops['concolebar.win'] or '0')~= '2' then SavedState.consoleBar = _G.iuprops['concolebar.win'] end
            if (_G.iuprops['findresbar.win'] or '0')~= '2' then SavedState.FindResBar = _G.iuprops['findresbar.win'] end
            if (_G.iuprops['findrepl.win'] or '0')~= '2' then SavedState.FindRepl = _G.iuprops['findrepl.win'] end
            if (_G.iuprops['coeditor.win'] or '0')~= '2' then SavedState.Coeditor = _G.iuprops['coeditor.win'] end


            if SavedState.SideBar then SideBar_obj.handle.cmdHide() end
            if SavedState.LeftBar then LeftBar_obj.handle.cmdHide() end
            if SavedState.consoleBar then iup.GetDialogChild(iup.GetLayout(), "ConsoleDetach").cmdHide() end
            if SavedState.FindRepl then iup.GetDialogChild(iup.GetLayout(), "FindReplDetach").cmdHide() end
            if SavedState.FindResBar then iup.GetDialogChild(iup.GetLayout(), "FindResDetach").cmdHide() end
            if SavedState.Coeditor then iup.GetDialogChild(iup.GetLayout(), "SourceExDetach").cmdHide() end

        end

        started_overtype = editor.Overtype
        caret_fore = editor.CaretFore
        started_cycle = iup.GetDialogChild(iup.GetLayout(), "chkWholeWord").value
        editor.CaretFore = 255
        scite.RegistryHotKeys({})
        iup.GetDialogChild(iup.GetLayout(), "chkWholeWord").value = 'OFF'


        BlockEventHandler"OnUpdateUI"
        BlockEventHandler"OnChar"
        BlockEventHandler"OnKey"
        BlockEventHandler"OnContextMenu"
        onContextMenuGlobal = OnContextMenu
        OnContextMenu = OnContextMenu_local
        if CLIPHISTORY then BlockEventHandler"OnDrawClipboard" end
        ClearSciKeys()
    end

    local function RestoreState()

        if SavedState.bMenuBar then iup.GetDialogChild(iup.GetLayout(), "MenuBar").switch() end
        if SavedState.bToolBar then iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").switch() end
        if SavedState.bStatusBar then iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").switch() end
        if SavedState.bTabBar then iup.GetDialogChild(iup.GetLayout(), "TabbarExpander").state = 'OPEN' end

        if SavedState.SideBar then SideBar_obj.handle.Switch() end
        if SavedState.LeftBar then LeftBar_obj.handle.Switch() end
        if SavedState.consoleBar then if SavedState.consoleBar == '0' then iup.GetDialogChild(iup.GetLayout(), "ConsoleDetach").Attach() else iup.GetDialogChild(iup.GetLayout(), "ConsoleDetach").ShowDialog() end end
        if SavedState.FindResBar then if SavedState.FindResBar == '0' then iup.GetDialogChild(iup.GetLayout(), "FindResDetach").Attach() else iup.GetDialogChild(iup.GetLayout(), "FindResDetach").ShowDialog() end end
        if SavedState.Coeditor then if SavedState.Coeditor == '0' then iup.GetDialogChild(iup.GetLayout(), "SourceExDetach").Attach() else iup.GetDialogChild(iup.GetLayout(), "SourceExDetach").ShowDialog() end end
        if SavedState.FindRepl then if SavedState.FindRepl == '0' then iup.GetDialogChild(iup.GetLayout(), "FindReplDetach").Attach() else iup.GetDialogChild(iup.GetLayout(), "FindReplDetach").ShowDialog() end end

        editor.Overtype = started_overtype
        editor.CaretFore = caret_fore
        iup.GetDialogChild(iup.GetLayout(), "chkWholeWord").value = started_cycle
        menuhandler:RegistryHotKeys()

        OnContextMenu = onContextMenuGlobal
        UnBlockEventHandler"OnUpdateUI"
        UnBlockEventHandler"OnChar"
        UnBlockEventHandler"OnKey"
        UnBlockEventHandler"OnContextMenu"
        if CLIPHISTORY then UnBlockEventHandler"OnDrawClipboard" end
        ReassignSciKeys()
    end

    local function StartRecord()

        SaveState()
        MACRO.Record = true
        MC = nil
        params = {}
        recordet_macros = {}
        recorded_props = {}
        pCurBlock = recordet_macros
        jCounter = 1
        overtype = editor.Overtype

        positions_t, lines_t = {}, {}

        OnMacro = local_OnMacro
        scite.MenuCommand(IDM_MACRORECORD)

        do_KeepPosition()
        do_KeepLine()
    end

    local function StopRecord()
        OnMacro = nil
        scite.MenuCommand(IDM_MACROSTOPRECORD)
        prevCol = nil
        if #recordet_macros <= 1 then recordet_macros = nil end
        if MC.typ then table.insert(pCurBlock, MC) end

        RestoreState()
        MACRO.Record = nil

    end

    function MACRO.StopRecord() StopRecord() end

    local function GetPropsFromScr(scr)
        local dorepeat, abbr = '1', ''
        local _, _, l = scr:find('^[-][-]([^\n\r]+)')
        if l then
            _, _, dorepeat = l:find('dorepeat=([01])')
            _, _, abbr = l:find('abbr=(%w+)')
        end
        if not dorepeat then dorepeat = Iif(scr:find('iup%.GetParam%(_T"'), '0', '1') end
        return dorepeat, abbr
    end

    local function play_scr(scr)
        local cnt = 1
        if GetPropsFromScr(scr) == '1' then
            local ret
            ret, cnt =
            iup.GetParam(_T"Number of Repetition".."^macros", nil,
                _T"Repeat"..": %i[1,100,1]\n",
            1)
            if not ret then return end
        end

        MACRO.Play = true
        BlockEventHandler"OnUpdateUI"
        BlockEventHandler"OnChar"
        BlockEventHandler"OnKey"
        local strCycle = iup.GetDialogChild(iup.GetLayout(), "chkWholeWord").value
        iup.GetDialogChild(iup.GetLayout(), "chkWholeWord").value = 'OFF'
        local curOverype = editor.Overtype

        editor:BeginUndoAction()
        local bOk, msg
        for i = 1, cnt do
            bOk, msg = pcall(dostring, scr)
            if not bOk or not MACRO.Play then break end
        end
        editor:EndUndoAction()

        editor.Overtype = curOverype
        iup.GetDialogChild(iup.GetLayout(), "chkWholeWord").value = strCycle
        UnBlockEventHandler"OnUpdateUI"
        UnBlockEventHandler"OnChar"
        UnBlockEventHandler"OnKey"
        MACRO.Play = nil

        if not bOk and not (msg or ''):find('----') then
            print(msg, scr)
        end
    end


    local function PlayCurrent()
        play_scr(GetScript())
    end

    local function RunMacroFile(strPath)
        local f = io.open(strPath)
        if f then
            local scr = f:read('*a')
            f:close()
            play_scr(scr)
        end
    end

    function MACRO.PlayMacro(strPath)
        if not strPath:find('%.') then strPath = strPath..'.macro' end
        if not strPath:find('\\') then strPath = props["SciteDefaultHome"].."\\data\\Macros\\"..strPath end
        RunMacroFile(strPath)
    end

    local function SaveCurrent()
        local dir = props["SciteDefaultHome"].."\\data\\Macros\\"
        shell.greateDirectory(dir)
        local d = iup.filedlg{dialogtype = 'SAVE', parentdialog = 'SCITE', extfilter = 'Macros|*.macro;', directory = dir}
        d:popup()
        local filename = d.value
        d:destroy()
        if filename then
            filename = filename:gsub('%.macro$', '')..'.macro'
            local scr = GetScript()
            local f = io.open(filename, "w")
            if f then
                f:write(scr)
                f:flush()
                f:close()

                macro_list = nil
                recordet_macros = nil
                recorded_props = nil
            end
        end
    end

    local function insert_counter(block)
        local par = params[block.id]
        local ret, term, isConst, mult, cap =
        iup.GetParam(_T"New Counter for"..par.caption.."^macros",
            function(h, id)
                if id == iup.GETPARAM_BUTTON1 then
                    local cap = iup.GetParamParam(h, 1).value
                    for i = 1, #params do
                        if params[i].caption == cap then
                            iup.Alarm(_T"Macro", _FMT(_T'Caption "%1" is already in use', cap), _TH'Ok')
                            return 0
                        end
                    end
                end
                return 1
            end,
            _T"Multiply Counter by"..'%i[-100,100,1]\n'..
            _T'...and add'..'%i[-1000,1000,1]\n'..
            _T'Constant'..'%b\n'..
            _T'Caption'..'%s\n'
            ,
            1, 0, 1,
            '<New Counter '..(#params + 1)..'>'
        )
        if ret then
            local suff = Iif(isConst == 1, nil, '%i[-1000,1000,1]')
            table.insert(params, {caption = cap, typ = 'cnt', suff = suff, id = #params + 1, num = term})
            nextMC()

            MACRO.Record = false
            MACRO.ReplaceSel(1 * mult + term)
            MACRO.Record = true
            MC.typ = 'L'; MC.fname = 'MACRO.ReplaceSel((j'..block.jCounter..' or 1) * ('..mult..') + par'..#params..')'
            nextMC()
        end
    end

    local function counter_block_content()
        local t = {}
        local block = pCurBlock
        while block.pUpper do
            local par = params[block.id]
            if block.typ == 'for' then
                local b = block
                table.insert(t, {par.caption, action = function() insert_counter(b) end})
            end
            block = block.pUpper
        end
        return t
    end

    local function for_block_content()
        local t = {}
        for i = 1,  #params do
            if params[i].typ == 'for' then
                table.insert(t, {params[i].caption.._T'\ttimes', action = function() insert_iffor_block(i, "for") end})
            end
        end
        if #t > 0 then table.insert(t,{"s", separator = 1}) end
        return t
    end

    local function counter_block_visible()
        for i = 1,  #params do
            if params[i].typ == 'for' then return true end
        end
        return false
    end

    local function if_block_content()
        local t = {}
        for i = 1,  #params do
            if params[i].typ == 'if' then
                table.insert(t, {params[i].caption, action = function() insert_iffor_block(i, "if") end})
            end
        end
        if #t > 0 then table.insert(t,{"s", separator = 1}) end
        return t
    end

    local function string_block_content()
        local t = {}
        for i = 1,  #params do
            if params[i].typ == 'str' then
                table.insert(t, {params[i].caption, action = function() insert_string(i) end})
            end
        end
        if #t > 0 then table.insert(t,{"s", separator = 1}) end
        return t
    end

    local function find_block_content()
        local t = {}
        for i = 1,  #params do
            if params[i].typ == 'find' then
                table.insert(t, {params[i].caption, action = function() play_find(i) end})
            end
        end
        if #t > 0 then table.insert(t,{"s", separator = 1}) end
        return t
    end

    local function get_macro_list()
        local path = props["SciteDefaultHome"].."\\data\\Macros\\"
        if not shell.fileexists(path) then return {} end
        if not macro_list and shell.fileexists(props["SciteDefaultHome"].."\\data\\Macros\\") then
            local t = scite.findfiles(props["SciteDefaultHome"].."\\data\\Macros\\*.macro")
            macro_list = {}
            local mnu_i
            for i = 1,  #t do
                local l, abbr = '', ''
                pcall(function()
                    local f = io.open(path..t[i].name)
                    l = f:read('l')
                    f:close()
                    _, _, abbr = l:find('abbr=(%w+)')
                end)

                mnu_i = {t[i].name:gsub('%.[^.]*$', '')..'\t'..(abbr or ''), action = function() RunMacroFile(props["SciteDefaultHome"]..'\\data\\Macros\\'..t[i].name) end, abbr = abbr}
                table.insert(macro_list, mnu_i)
            end
            if FILEMAN then
                table.insert(macro_list, {'s2', separator = 1})
                table.insert(macro_list, {'Open Macro Folder', cpt = _T'Open Macro Folder', action = function() FILEMAN.OpenFolder(props["SciteDefaultHome"]..'\\data\\Macros\\') end, image = 'folder_search_result_µ'})
            end
        end
        return macro_list
    end

    local function TryInsAbbrev()

        local pos = editor.SelectionStart
        local lBegin = editor:textrange(editor:PositionFromLine(editor:LineFromPosition(pos)), pos)
        local abbr_table = get_macro_list()
        for i, v in ipairs(abbr_table) do
            debug_prnArgs(v)
            if v.abbr then
                if lBegin:sub(-v.abbr:len()):lower() == v.abbr:lower() then
                    editor.SelectionStart = editor.SelectionStart - v.abbr:len()
                    editor:ReplaceSel()
                    v.action()
                    return
                end
            end
        end
        print("Macro not found by '"..lBegin.."'")
    end

    local function do_Copy()
        CLIPHISTORY.Copy(1, editor:GetSelText())

        nextMC()

        MC.typ = 'L'; MC.fname = 'CLIPHISTORY.Copy(1, editor:GetSelText())'
        nextMC()
    end

    local function do_Paste()
        MACRO.Record = false
        MACRO.ReplaceSel(CLIPHISTORY.GetClip(1) or "")
        MACRO.Record = true

        nextMC()

        MC.typ = 'L'; MC.fname = 'MACRO.ReplaceSel(CLIPHISTORY.GetClip(1) or "")'
        nextMC()
    end

    local function do_SelectWord()
        MACRO.SelectWord()

        nextMC()

        MC.typ = 'L'; MC.fname = 'MACRO.SelectWord()'
        nextMC()
    end

    local function do_Cut()
        CLIPHISTORY.Copy(1, editor:GetSelText())
        MACRO.Record = false
        MACRO.ReplaceSel('')
        MACRO.Record = true

        nextMC()

        MC.typ = 'L'; MC.fname = 'CLIPHISTORY.Copy(1, editor:GetSelText())'
        nextMC()

        MC.typ = 'L'; MC.fname = 'MACRO.ReplaceSel("")'
        nextMC()
    end

    local function SetMacroProps()
        local ret, dorepeat, abbr, scr, filename
        if recordet_macros then
            scr = GetBlock(recordet_macros)
            dorepeat = ''..(recorded_props.dorepeat or (Iif(scr:find('iup%.GetParam%(_T"'), 0, 1)))
            abbr = recorded_props.abbr or ''
        else
            local d = iup.filedlg{dialogtype = 'OPEN', parentdialog = 'SCITE', extfilter = 'Macros|*.macro;', directory = props["SciteDefaultHome"].."\\data\\Macros\\" }
            d:popup()
            filename = d.value
            d:destroy()
            if not filename then return end
            if not pcall(function()
                local f = io.open(filename)
                scr = f:read('*a')
                f:close()
            end)
            then
            print("Can't open macro file - "..filename)
            return
            end
            local _, _, l = scr:find('^[-][-]([^\n\r]+)')
            if l then
                scr = scr:gsub('^([-][-][^\n\r]+[\n\r]+)', "")
                _, _, dorepeat = l:find('dorepeat=([01])')
                _, _, abbr = l:find('abbr=(%w*)')
            else
                dorepeat = Iif(scr:find('iup%.GetParam%(_T"'), '0', '1')
                abbr = ''
            end
        end
        ret, dorepeat, abbr = iup.GetParam(_T"Macro Properties".."^macros",
            nil,
            _T'Request number of repetitions'..'%b\n'..
            _T'Abbreviation'..'%s\n'
            ,
            tonumber(dorepeat), abbr
        )
        if ret then
            if recordet_macros then
                recorded_props.dorepeat = ''..dorepeat
                recorded_props.abbr = ''..abbr
            else
                scr = '--dorepeat='..dorepeat..';abbr='..abbr..'\n'..scr
                if not pcall(function()
                    local f = io.open(filename, "w")
                    f:write(scr)
                    f:flush()
                    f:close()
                end)
                then
                print("Can't write macro file - "..filename)
                return
                end
            end
        end
    end

    local item = {'Macro', {
		{'Start Recording', action = StartRecord, visible = function() return not MACRO.Record and not recordet_macros end, image = "control_record_µ"},
		{'Playback Current Macro', action = PlayCurrent, visible = function() return not MACRO.Record and recordet_macros end, image = "control_µ"},
		{'Delete Current Macro', action = function() if iup.Alarm(_T"Macros", _T'Delete Macro?', _TH'Yes', _TH'No') == 1 then recordet_macros = nil;recorded_props = nil end end, visible = function() return not MACRO.Record and recordet_macros end, image = "cross_script_µ"},
		{'Save Current Macro', action = SaveCurrent, visible = function() return not MACRO.Record and recordet_macros end, image = "disk_µ" },
		{'View Current Macro', action = function() print(GetScript()) end, visible = function() return not MACRO.Record and recordet_macros end },
		{'Stop Recording', action = StopRecord, visible = function() return MACRO.Record end, image = "control_stop_square_µ" },
        {'s1', separator = 1},
        {'macrolist', plane = 1, visible = function() return not MACRO.Record end , get_macro_list},
        {'Macro Properties', action = SetMacroProps, visible = function() return not MACRO.Record end},
        {'Record', plane = 1, visible = function() return MACRO.Record end, {
            {'Store Position in String', {
                {'StringList', plane = 1, update_position_list},
                {'New Position in String', action = do_KeepPosition, image = "marker_µ"},
            },},
            {'Go to Position in String', submenu_positions},
            {'Select to position', submenu_selto_positions},
            {'s2', separator = 1},
            {'Save Line Number', {
                {'LinesList', plane = 1, update_line_list},
                {'New Line Number', action = do_KeepLine, image = "marker_µ"},
            },},
            {'Go to Line', submenu_lines},
            {'Select to Line', submenu_selto_line},
            {'s3', separator = 1},

            {'Insert User-Defined String...', {
                {'StringList', plane = 1, string_block_content},
                {'Set New String Parameter', action = do_NewStringPar}
            }},
            {'Repeat Next Command Block...', {
                {'ForList', plane = 1, for_block_content},
                {'Set New Repetition Parameter', action = do_BeginFor},
            }},
            {'Insert Repetition Counter Value...', {
                {'CounterList', plane = 1, counter_block_content},
            }, visible = counter_block_visible},
            {'Playback Commands on Condition...', {
                {'IfList', plane = 1, if_block_content},
                {'Set New Condition', action = do_BeginIf}
            }},
            {'Find And Playback Commands...', {
                {'FindList', plane = 1, find_block_content},
                {'New Find', action = function() do_NewFind() end, image = "IMAGE_search"},
            }},
            {'StopRecordBlock', plane = 1, visible = function() return MACRO.Record and pCurBlock.id end, function()
                return {
                    {_T'Complete Block/Condition "'..params[pCurBlock.id].caption..'"', action = do_StopBlock, image = 'control_double_µ'}
                }
            end},
            {'s4', separator = 1},
            {'Select Word Under Cursor', action = do_SelectWord},
            {'Copy', action = do_Copy, visible = function() return CLIPHISTORY end, image = 'document_copy_µ'},
            {'Cut', action = do_Cut, visible = function() return CLIPHISTORY end, image = 'scissors_µ'},
            {'Paste', action = do_Paste, visible = function() return CLIPHISTORY end, image = 'clipboard_paste_µ'},
            {'Paste from Clip History', action = do_PasteHist, visible = function() return CLIPHISTORY end, image = "clipboard_list_µ"},
            {'Undo', active = function() return MC and (MC.typ == "F" or MC.typ == "P") end, action = do_Undo, image = "arrow_return_270_left_µ"} ,
        }},
    }}
    menuhandler:AddMenu(item, "hildim/ui/macros.html", _T)

    menuhandler:InsertItem('MainWindowMenu', 'Edit|s3',
        {'Expand Abbreviation into Macro', action = TryInsAbbrev, key = 'Ctrl+\\'}
    , "hildim/ui/macros.html", _T)

end
return {
    title = _T'Macro Support',
    hidden = Init_hidden,
}
