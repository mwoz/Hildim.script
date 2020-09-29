require "seacher"
local findSettings = seacher{
wholeWord = false
,matchCase = false
,wrapFind = true
,backslash = false
,regExp = false
,style = nil
,searchUp = false
,replaceWhat = ''
}
-----------------------------------
local current_mark_number = CORE.InidcFactory('FindOnSel.mark', _T'Highlight the selected word throughout the text', INDIC_ROUNDBOX, 6750054, 30)
findres:SetHotspotActiveFore(true, 0xff0000)
findres.HotspotSingleLine = false


local function SelectMethod(bModified, bSelection, flag)
--подсветка слова, если оно выделено целиком
    if (bModified == 0 and bSelection == 0) then return end
	EditorClearMarks(current_mark_number)
    local sText, iFind = '', 0
    local sels = 1
    if bModified ~= 1 then
        sels = editor.Selections
        for i = 0, sels - 1 do
            if i == 0 then
                sText = editor:textrange(editor.SelectionNStart[i], editor.SelectionNEnd[i])
            elseif sText:lower() ~= editor:textrange(editor.SelectionNStart[i], editor.SelectionNEnd[i]):lower() then
                sText = ''
                break
            end
        end

        local flag1 = 0
        if props['findtext.matchcase'] == '1' then flag1 = SCFIND_MATCHCASE end

        if string.len(sText) > 0 and editor.SelectionStart == editor:WordStartPosition(editor.SelectionEnd) and editor.SelectionEnd == editor:WordEndPosition(editor.SelectionStart) then
            for m in editor:match(sText, SCFIND_WHOLEWORD + flag1) do
                EditorMarkText(m.pos, m.len, current_mark_number)
                iFind = iFind + 1
            end
        else
            sText = ''
        end
        iMark = props["findtextsimple.count"]
    end
    if onSetFindRes then onSetFindRes(sText, iFind, sels) end
end

AddEventHandler("OnUpdateUI", SelectMethod)

local function FindSelToConcoleL(id, ed, edfrom)
    local uMod = scite.buffers.GetBufferUnicMode(id)
    needCoding = (uMod ~= 0)

    local sText = (edfrom or editor):GetSelText()
    findSettings.wholeWord = false
    if (sText == '') then
        sText = GetCurrentWord(edfrom or editor)
        findSettings.wholeWord = true
    end

    findSettings.findWhat = sText
    findSettings.e = ed
    findSettings.unicMode = uMod
    findSettings.path = scite.buffers.NameAt(id)
    CORE.FindMarkAll(findSettings, 100, false, true)
end

CORE.FindSelToConcole = function()
    FindSelToConcoleL(scite.buffers.GetCurrent(), editor)
end

CORE.FindCoSelToConcole = function()
    CORE.ClearLiveFindMrk(true)
    FindSelToConcoleL(scite.buffers.BufferByName(scite.buffers.CoName()), coeditor)
end

CORE.ToggleSubfolders = function(bShow, line, e, maxlevel, action, noParent)
    if not e then
        if output.Focus then e = output
        elseif findres.Focus then e = findres
        else e = editor end
    end
    maxlevel = maxlevel or 0
    if not line and not action then action = Iif(bShow, 1, 0) end
    local lStart = line or e:LineFromPosition(e.SelectionStart)
    local baseLevel = (e.FoldLevel[lStart + 1] & SC_FOLDLEVELNUMBERMASK)

    local lEnd = e:GetLastChild(lStart, -1)
    if lStart == -1 then lEnd = e.LineCount end
    local bAct = false
    for l = lStart + 1, lEnd do
        local level = e.FoldLevel[l]
        if ((level & SC_FOLDLEVELHEADERFLAG)~= 0 and baseLevel == (level & SC_FOLDLEVELNUMBERMASK)) then
            if not action then action = Iif(e.FoldExpanded[l], 0, 1) end
            e:FoldLine(l, action)
            bAct = true
            if maxlevel > 0 then
                CORE.ToggleSubfolders(bShow, l , e, maxlevel - 1, action, true)
            end
        end
    end
    if not bAct and not noParent then
        local l = e.FoldParent[lStart]
        if not action then action = Iif(e.FoldExpanded[l], 0, 1) end
        e:FoldLine(l, action)
    end
    CORE.ShowCaretAfterFold()
end

CORE.ShowCaretAfterFold = function(w)
    local lineSel = -1
    if not editor.LineVisible[editor:LineFromPosition(editor.SelectionStart)] or
        not editor.LineVisible[editor:LineFromPosition(editor.SelectionStart)] then
        lineSel = editor:LineFromPosition(editor.SelectionStart)
        repeat
            lineSel = editor.FoldParent[lineSel]
        until lineSel <= 0 or editor.LineVisible[lineSel]
    end
    if lineSel >= 0 then
        editor.SelectionStart = editor:PositionFromLine(lineSel)
        editor.SelectionEnd = editor:PositionFromLine(lineSel)
    end

end

CORE.Find_FindInDialog = function(ud)
    local tmpUD = Iif(ud, "1", "0")
    local curUD = iup.GetDialogChild(iup.GetLayout(), "zUpDown").valuepos
    local sText = editor:GetSelText()
    local wholeWord = 'OFF'
    if (sText == '') then
        sText = GetCurrentWord()
        wholeWord = 'ON'
    end
    local pos = editor.CurrentPos
    iup.GetDialogChild(iup.GetLayout(), "chkWholeWord").value = wholeWord
    iup.GetDialogChild(iup.GetLayout(), "zUpDown").valuepos = tmpUD
    iup.GetDialogChild(iup.GetLayout(), "cmbFindWhat").value = sText
    iup.GetDialogChild(iup.GetLayout(), "cmbFindWhat"):SaveHist()
    iup.GetDialogChild(iup.GetLayout(), "btnFind").flat_action()
    iup.GetDialogChild(iup.GetLayout(), "zUpDown").valuepos = curUD
    return pos ~= editor.CurrentPos
end

CORE.FindNextWrd = function(ud)
    local sText = editor:GetSelText()
    local wholeWord = false
    if (sText == '') then
        sText = GetCurrentWord()
        wholeWord = true
    end
    local bNoMacro = true
    if MACRO then bNoMacro = not MACRO.Record and not MACRO.Play end
    local prevpos = editor.CurrentPos
    local fs = seacher{
        wholeWord = wholeWord
        , matchCase = false
        , wrapFind = bNoMacro
        , backslash = false
        , regExp = false
        , style = nil
        , searchUp = (ud == 2)
        , replaceWhat = ''
        , findWhat = sText
    }
    local pos = fs:FindNext(true)
    if wholeWord then
        editor.SelectionStart = pos + 1
        editor.SelectionEnd = pos + 1
    end
    return prevpos ~= pos and pos > -1
end

AddEventHandler("OnClick", function(shift, ctrl, alt, middle)
        if not shift and ctrl and alt then
            if middle and  scite.buffers.SecondEditorActive() == 1 and scite.buffers.IsCloned(scite.buffers.GetCurrent()) == 0  then
                CORE.FindCoSelToConcole()
            else
                local id = scite.buffers.GetCurrent()
                if editor.Focus then FindSelToConcoleL(id, editor, editor)
                elseif findres.Focus then FindSelToConcoleL(id, editor, findres)
                elseif output.Focus then FindSelToConcoleL(id, editor, output)
                end
            end
            CORE.ScipHidePannel()
        end
end)

CORE.PrintVariantsVisible = function()
    if findres.StyleAt[findres.CurrentPos] == SCE_SEARCHRESULT_SEARCH_HEADER then
        local ls = findres:PositionFromLine(findres:LineFromPosition(findres.CurrentPos))
        return findres:textrange(ls + 8, ls + 10) == 'RE'
    end
end

CORE.PrintFoundVariants = function()
    if findres.StyleAt[findres.CurrentPos] == SCE_SEARCHRESULT_SEARCH_HEADER then
        local lStart = findres:LineFromPosition(findres.CurrentPos) + 1
        local lEnd = 0
        for i = lStart, findres.LineCount - 1 do
            if findres.StyleAt[findres:PositionFromLine(i)] == SCE_SEARCHRESULT_SEARCH_HEADER then break end
            lEnd = i
        end
        if lStart < lEnd then
            local lS = findres:IndicatorEnd(31, findres:PositionFromLine(lStart))
            local lE
            local tRes = {}
            while lS < findres.Length and findres:LineFromPosition(lS) <= lEnd do
                lE = findres:IndicatorEnd(31, lS)
                tRes[findres:textrange(lS, lE)] = true
                lS = findres:IndicatorEnd(31, lE)
            end
            local ts = {}
            for s, _ in pairs(tRes) do
                table.insert(ts, s)
            end
            table.sort(ts)
            for _, s in ipairs(ts) do
                print(s)
            end
        end

    end
end

CORE.OpenFoundFiles = function(msg)
    local function fndFiles()
        local t = {}
        if findres.StyleAt[findres.CurrentPos] == SCE_SEARCHRESULT_SEARCH_HEADER then
            local lineNum = findres:LineFromPosition(findres.CurrentPos) + 1
            while true do
                local style = findres.StyleAt[findres:PositionFromLine(lineNum) + 1]
                if style == SCE_SEARCHRESULT_SEARCH_HEADER then break
                elseif style == SCE_SEARCHRESULT_FILE_HEADER then
                    local s = findres:line(lineNum):gsub('^ ', '')
                    table.insert(t, s)
                end
                lineNum = lineNum + 1
            end
        end
        return t
    end

    local function CloseIfFound(_,t, bFounded)
        if not t then return end
        for i = 1, #t do
            if t[i]:upper() == string.upper(props['FileDir']..'\\'..props["FileNameExt"]) then
                if bFounded then scite.MenuCommand(IDM_CLOSE) end
                return
            end
        end
        if not bFounded then scite.MenuCommand(IDM_CLOSE) end
    end

    if msg == 1 then
        if findres.StyleAt[findres.CurrentPos] == SCE_SEARCHRESULT_SEARCH_HEADER then
            scite.BlockUpdate(UPDATE_BLOCK)
            BlockEventHandler"OnTextChanged"
            BlockEventHandler"OnBeforeOpen"
            BlockEventHandler"OnOpen"
            BlockEventHandler"OnSwitchFile"
            BlockEventHandler"OnNavigation"
            BlockEventHandler"OnUpdateUI"
            editor.VScrollBar = false
            local lineNum = findres:LineFromPosition(findres.CurrentPos) + 1
            while true do
                local style = findres.StyleAt[findres:PositionFromLine(lineNum) + 1]
                if style == SCE_SEARCHRESULT_SEARCH_HEADER then break
                elseif style == SCE_SEARCHRESULT_FILE_HEADER then
                    scite.Open(findres:line(lineNum):gsub('^ ', ''))
                end
                lineNum = lineNum + 1
            end
            editor.VScrollBar = true
            UnBlockEventHandler"OnUpdateUI"
            UnBlockEventHandler"OnNavigation"
            UnBlockEventHandler"OnSwitchFile"
            UnBlockEventHandler"OnOpen"
            UnBlockEventHandler"OnBeforeOpen"
            UnBlockEventHandler"OnTextChanged"
            scite.BlockUpdate(UPDATE_FORCE)
        end
        return true
    elseif msg == 2 then
        DoForBuffers(CloseIfFound, fndFiles(), true)
        scite.BlockUpdate(UPDATE_FORCE)
        return true
    elseif msg == 3 then
        DoForBuffers(CloseIfFound, fndFiles(), false)
        scite.BlockUpdate(UPDATE_FORCE)
        return true
    end
end

function CORE.FindresClickPos(curpos)
    local style = findres.StyleAt[curpos]
    local lineNum = findres:LineFromPosition(curpos)
    local function perfGo(s, p, strI)
        if iup.GetGlobal("SHIFTKEY") == "ON" then CORE.ScipHidePannel(2) end
        OnNavigation("Go")
        s = s:to_utf8()
        if s ~= props['FilePath'] then scite.Open(s) end
        if strI and strI:len() > 0 then
            editor.TargetStart = editor:PositionFromLine(p)
            editor.TargetEnd = editor:PositionFromLine(p + 1)
            local posFind = editor:SearchInTarget(strI)
            if posFind and posFind >= p then
                editor:EnsureVisibleEnforcePolicy(p)
                editor:SetSel(posFind, posFind + strI:len())
                iup.PassFocus()
                OnNavigation("Go-")
                return
            end
        end
        editor:EnsureVisibleEnforcePolicy(p)
        p = editor:PositionFromLine(p)
        editor:SetSel(p, p)
        iup.PassFocus()
        OnNavigation("Go-")
    end
    local function GetFindTxt(lS, lE)
        local sInd = findres:IndicatorEnd(31, lS)
        if lE >= sInd and sInd >= lS then
            local eInd = findres:IndicatorEnd(31, sInd)
            return findres:textrange(sInd, eInd)
        end
    end

    if style == SCE_SEARCHRESULT_FILE_HEADER then
        local s = findres:line(lineNum):gsub('^ ', ''):to_utf8()
        if s ~= props['FilePath'] then
            OnNavigation("Go")
            scite.Open(s)
            OnNavigation("Go-")
        end
    elseif style == SCE_SEARCHRESULT_LINE_NUMBER or
           (not _G.iuprops['findres.clickonlynumber'] and style == SCE_SEARCHRESULT_CURRENT_LINE) then
        local lS, lE = findres:PositionFromLine(lineNum), findres:PositionFromLine(lineNum + 1) -1
        local s = findres:textrange(lS, lE)
        local exPath, lHeadPath
        local _,_,p = s:find('^%s+(%d*)')
        if not p then _,_,exPath,p = s:find('^%.\\([^:]*):(%d+)') end
        if not p then _, _, lHeadPath, exPath, p = s:find('^([A-Z]:([^:]*)):(%d*)') end
        if not p then return end
        p = tonumber(p) - 1
        for i = lineNum, 0, -1 do
            style = findres.StyleAt[findres:PositionFromLine(i) + 2]
            if style == SCE_SEARCHRESULT_SEARCH_HEADER then
                if not exPath then break end
                if not lHeadPath then
                    lHeadPath = findres:line(i)
                    _, _, lHeadPath = lHeadPath:find(' in "([^"]+)')
                    if not lHeadPath:find('\\') then lHeadPath = props['FileDir']..'\\'..lHeadPath end
                    if exPath ~= '' then _,_,lHeadPath = lHeadPath:find('(.-)[^\\]+$') end
                    lHeadPath = lHeadPath..exPath
                end
                perfGo(lHeadPath, p, GetFindTxt(lS, lE))
                break
            elseif style == SCE_SEARCHRESULT_FILE_HEADER then
                perfGo(findres:line(i):gsub('^ ', ''), p, GetFindTxt(lS, lE))
                break
            end
        end
    end
end

function CORE.FindResult(dl)
    local curLine = findres:LineFromPosition(findres.SelectionEnd)
    local bRound = true
    while curLine >= 0 and curLine <= findres.LineCount do
        curLine = curLine + dl
        local cSt = findres.StyleAt[findres:PositionFromLine(curLine)]
        if cSt == 3 then
            findres:EnsureVisibleEnforcePolicy(curLine)
            findres.SelectionEnd = findres:PositionFromLine(curLine)
            findres.SelectionStart = findres:PositionFromLine(curLine)
            CORE.FindresClickPos(findres.CurrentPos)
            return
        elseif (cSt == 1 or curLine == 0 or curLine == findres.LineCount - 1) and bRound then
            bRound = false
            while curLine >= 0 and curLine <= findres.LineCount do
                curLine = curLine - dl
                if findres.StyleAt[findres:PositionFromLine(curLine)] == 1 then
                    break
                end
            end
        end
    end
end

AddEventHandler("OnDoubleClick", function(shift, ctrl, alt)
    if not findres.Focus then return end
    CORE.FindresClickPos(findres.CurrentPos)
end)
AddEventHandler("OnHotSpotReleaseClick", function(modif)
    if not findres.Focus then return end
    CORE.FindresClickPos(findres.CurrentPos)
end)
require "menuhandler"
