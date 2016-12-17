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


local function SelectMethod()
--��������� �����, ���� ��� �������� �������
	local current_mark_number = tonumber(props['findsel.mark'])
	EditorClearMarks(current_mark_number)
	local sText = editor:GetSelText()

	local flag1 = 0
	if props['findtext.matchcase'] == '1' then flag1 = SCFIND_MATCHCASE end

	iFind = 0

	if string.len(sText) > 0 and editor.SelectionStart == editor:WordStartPosition(editor.SelectionEnd) and editor.SelectionEnd == editor:WordEndPosition(editor.SelectionStart) then
        for m in editor:match(sText, SCFIND_WHOLEWORD + flag1) do
			EditorMarkText(m.pos, m.len, current_mark_number)
			iFind = iFind + 1
		end
    else
        sText = ''
	end
    iMark = props["findtextsimple.count"]
    if onSetFindRes then onSetFindRes(sText, iFind) end
    if iFind > 0 then strStatus='Sel+{'..tostring(iFind-1)..'}' else strStatus='NoSel'  end
    if iMark ~= '0' then strStatus = strStatus..' | Mark{'..iMark..'}' end
	props['findtext.status'] = strStatus
end

AddEventHandler("OnUpdateUI", SelectMethod)

CORE.FindSelToConcole = function()
    needCoding = (scite.SendEditor(SCI_GETCODEPAGE) ~= 0)
    local sText = editor:GetSelText()
    findSettings.wholeWord = false
    if (sText == '') then
        sText = GetCurrentWord()
        findSettings.wholeWord= true
    end

    findSettings.findWhat = sText

    findSettings:FindAll(100, false)
end

CORE.ToggleSubfolders = function(bShow, line)
    local action
    if not line then action = Iif(bShow, 1, 0) end
    local lStart = line or editor:LineFromPosition(editor.SelectionStart)
    local baseLevel = shell.bit_and(editor.FoldLevel[lStart],SC_FOLDLEVELNUMBERMASK)
    if baseLevel > SC_FOLDLEVELBASE and shell.bit_and(baseLevel,SC_FOLDLEVELHEADERFLAG) == 0 then
        lStart = editor.FoldParent[lStart]
    end
    local lEnd = editor:GetLastChild(lStart, -1)
    for l = lStart + 1, lEnd do
        local level = editor.FoldLevel[l]
        if (shell.bit_and(level, SC_FOLDLEVELHEADERFLAG)~= 0 and baseLevel == shell.bit_and(level, SC_FOLDLEVELNUMBERMASK)) then
            if not action then action = Iif(editor.FoldExpanded[l], 0, 1) end
            editor:FoldLine(l, action)
        end
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
    iup.GetDialogChild(iup.GetLayout(), "chkWholeWord").value = wholeWord
    iup.GetDialogChild(iup.GetLayout(), "zUpDown").valuepos = tmpUD
    iup.GetDialogChild(iup.GetLayout(), "cmbFindWhat").value = sText
    iup.GetDialogChild(iup.GetLayout(), "cmbFindWhat"):SaveHist()
    iup.GetDialogChild(iup.GetLayout(), "btnFind").action()
    iup.GetDialogChild(iup.GetLayout(), "zUpDown").valuepos = curUD
end

CORE.FindNextWrd = function(ud)
    local sText = editor:GetSelText()
    local wholeWord = false
    if (sText == '') then
        sText = GetCurrentWord()
        wholeWord = true
    end
    local fs = seacher{
        wholeWord = wholeWord
        , matchCase = false
        , wrapFind = true
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
end

AddEventHandler("OnClick", function(shift, ctrl, alt)
    if editor.Focus and not shift and ctrl and alt then
        CORE.FindSelToConcole()
    end
end)

CORE.OpenFoundFiles = function(msg)
    local function fndFiles()
        local t = {}
        if findres.StyleAt[findres.CurrentPos] == SCE_SEARCHRESULT_SEARCH_HEADER then
            local lineNum = findres:LineFromPosition(findres.CurrentPos) + 1
            while true do
                local style = findres.StyleAt[findres:PositionFromLine(lineNum) + 1]
                if style == SCE_SEARCHRESULT_SEARCH_HEADER then break
                elseif style == SCE_SEARCHRESULT_FILE_HEADER then
                    local s = findres:textrange(findres:PositionFromLine(lineNum) + 1, findres:PositionFromLine(lineNum + 1) -1)
                    table.insert(t,s)
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
            local lineNum = findres:LineFromPosition(findres.CurrentPos) + 1
            while true do
                local style = findres.StyleAt[findres:PositionFromLine(lineNum) + 1]
                if style == SCE_SEARCHRESULT_SEARCH_HEADER then break
                elseif style == SCE_SEARCHRESULT_FILE_HEADER then
                    local s = findres:textrange(findres:PositionFromLine(lineNum) + 1, findres:PositionFromLine(lineNum + 1) -1)
                    scite.Open(s)
                end
                lineNum = lineNum + 1
            end
        end
        return true
    elseif msg == 2 then
        DoForBuffers(CloseIfFound, fndFiles(), true)
        return true
    elseif msg == 3 then
        DoForBuffers(CloseIfFound, fndFiles(), false)
        return true
    end
end

AddEventHandler("OnDoubleClick", function(shift, ctrl, alt)
    if not findres.Focus then return end
    local style = findres.StyleAt[findres.CurrentPos]
    local lineNum = findres:LineFromPosition(findres.CurrentPos)
    local function perfGo(s, p, strI)
        OnNavigation("Go")
        s = s:to_utf8(1251)
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
        local sInd = scite.SendFindRes(SCI_INDICATOREND, 31, lS)
        if lE >= sInd and sInd >= lS then
            local eInd = scite.SendFindRes(SCI_INDICATOREND, 31, sInd)
            return findres:textrange(sInd, eInd)
        end
    end

    if style == SCE_SEARCHRESULT_FILE_HEADER then
        local s = findres:textrange(findres:PositionFromLine(lineNum) + 1, findres:PositionFromLine(lineNum + 1) -1):to_utf8(1251)
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
        if not p then _,_,lHeadPath,exPath,p = s:find('^([A-Z]:([^:]*)):(%d*)') end
        if not p then return end
        p = tonumber(p) - 1
        for i = lineNum, 0, -1 do
            style = findres.StyleAt[findres:PositionFromLine(i) + 2]
            if style == SCE_SEARCHRESULT_SEARCH_HEADER then
                if not exPath then break end
                if not lHeadPath then
                    lHeadPath = findres:textrange(findres:PositionFromLine(i), findres:PositionFromLine(i +1) -2)
                    _,_,lHeadPath = lHeadPath:find(' in "([^"]+)')
                    if exPath ~= '' then _,_,lHeadPath = lHeadPath:find('(.-)[^\\]+$') end
                    lHeadPath = lHeadPath..exPath
                end
                perfGo(lHeadPath, p, GetFindTxt(lS, lE))
                break
            elseif style == SCE_SEARCHRESULT_FILE_HEADER then
                local s = findres:textrange(findres:PositionFromLine(i) + 1, findres:PositionFromLine(i + 1) -1)
                perfGo(s, p, GetFindTxt(lS, lE))
                break
            end
        end
    end
end)
require "menuhandler"
