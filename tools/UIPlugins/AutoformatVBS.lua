local goodmark, errmark

local function Init()
    local mark = nil
    local cGroupContinued = 999999
    local iChangedLine = -1

    local nextIndent = ''
    --[[local tRight
        local tLeft
local tTwo]]
-- local chLeftSide = '([%%),%{<>%/%=%+%-&%%%*])%s*([%w%d%"])'
local chLeftSide = '([%%),<>%/%=%+%-%%%*])%s*([%w%d%"])'
local chRightSide = '([%w%d%"])%s*([<>%/%=%+%-%%%*])'
-- local chRightSide = '([%w%d%"])%s*([%}<>%/%=%+%-&%%%*])'
goodmark = CORE.InidcFactory('FormatVbs.ok', 'VBS AutoFormat - ��', INDIC_BOX, 4834854, 0)
errmark = CORE.InidcFactory('FormatVbs.Error', 'VBS AutoFormat - Error', INDIC_STRIKE, 13311, 0)
--local chTwoSide = '(%w)%s*([<>%/%=%+%-&%%%*])%s*(%w)'

-- 3 ������� wrdBeginIndent wrdEndIndent wrdMidleInent -  � ������ ������ - �������
-- � ������ ������� ������� ������ �����������, � �� ������ - ������, �� �������� ��� ������� ���� � ������

local wrdBeginIndent = {
    {"^(%s*)If%s.+%sThen%W%s*(%'?)(.*)$", 1},
    {"^(%s*)For%s.+%sTo%W", 2},
    {"^(%s*)For Each%s.+%sIn%W", 2},
    {"^(%s*)Select Case%W", 3},
    {"^(%s*)Sub%W", 4},{"^(%s*)Private Sub%W", 4},
    {"^(%s*)Function%W", 5},{"^(%s*)Private Function%W", 5},
    {"^(%s*)Do%W", 6},
    --[[{"^(%s*)Do While%W", 7}, {"^(%s*)Do Until%W", 7},]]
    {"^(%s*)With%W", 8},
    {"^(%s*)While%W", 9},
    {"^(%s*)Class%W", 10},
{"^(%s*)Property%W", 11},{"^(%s*)Private Property%W", 11}}
local wrdEndIndent = {
    {"^(%s*)End If%W%s*(%'?)(.*)$", 1},
    {"^(%s*)Next%W%s*(%'?)(.*)$", 2},
    {"^(%s*)End Select%W%s*(%'?)(.*)$", 3},
    {"^(%s*)End Sub%W%s*(%'?)(.*)$", 4},{"^(%s*)End Function%W%s*(%'?)(.*)$", 5},
    {"^(%s*)Loop%W", 6}, --[[{"^(%s*)Loop While%W", 6}, {"^(%s*)Loop Until%W", 6},]]
    {"^(%s*)End With%W%s*(%'?)(.*)$", 8},
    {"^(%s*)Wend%W%s*(%'?)(.*)$", 9},
    {"^(%s*)End Class%W%s*(%'?)(.*)$", 10},
{"^(%s*)End Property%W%s*(%'?)(.*)$", 11}}
local wrdMidleInent =  {
    {"^(%s*)Else%W%s*(%'?)(.*)$", 1},{"^(%s*)ElseIf%s.+%sThen%W%s*(%'?)(.*)$", 1},
{"^(%s*)Case%W", 3}}
local strTab = string.rep(' ', props['tabsize'])

local keywords = {"If", "Then", "For", "To", "Each", "In", "Select", "Case", "Sub", "Function", "Do", "While", "Until", "With", "Set", "Let", "Get", "Default", "Private", "Public", "Property", "Class",
"End", "Next", "Loop", "Else", "ElseIf", "Or ", "And ", "Not ", "True", "False", "IsNull", "Is", "Nothing", "Exit", "Wend", "ExecuteGlobal", "Error", "On", "Resume", "GoTo", "IsEmpty"}
local keywordsUp = {}
local lk = #keywords
for i = 1, lk do
    table.insert(keywordsUp, "([^%w_])("..string.gsub(keywords[i], '.', function(s)
        local r = ''
        if s~= ' ' then r = '['..string.upper(s)..string.lower(s)..']' end
        return r
    end
)..")(%W)")
end

local function prnTable(name)
    print('> ________________')
    for i = 1, #name do
        print(name[i])
    end
    print('> ^^^^^^^^^^^^^^^')
end
local function prnTable2(name)
    for i = 1, #name do
        prnTable(name[i])
    end
end

local function FoldLevel(deltaL, L)
    return (editor.FoldLevel[L or (editor:LineFromPosition(editor.SelectionStart) - deltaL)] & SC_FOLDLEVELNUMBERMASK) - SC_FOLDLEVELBASE
end

local function LineIndent(deltaL, L)
    local line = L or (editor:LineFromPosition(editor.SelectionStart) - deltaL)
    local l = editor:PositionFromLine(line)
    local _, ln = editor:GetLine(line)
    local e = editor:findtext('[^ \t\n\r]', SCFIND_REGEXP, l, l + ln - 2) or (l + ln - 2)
    local strInd = (editor:textrange(l, e) or '')
    return strInd:gsub('\t', strTab):len(), strInd:len()
end

local function CheckPattern(str, pattern)
    local _s, _e, s, c, cc = string.find(str, pattern)
    --��������: ������, �����, ������, �����������, ���-��(�� �����������) �� ������������
    if c ~= nil then
        if c == '' and cc ~= '' then s = nil end --���� ���-�� - �� �����������-���� �� If��, ��������, �� ��� ������ ��� �� �����
    end
    return s, _e  --������� ������ � ������� ����� ������
end

local function GetFullLine(nLine)
    --���������� ������ ������-��������
    local result = ""
    local n = 0
    local _s, _e, c, p = 0, 0, '', '_'
    while (c ~= "'" and p == '_') do
        --������ ������, ���� �� ����� ������ �������� � ������ �������� ������������
        local l = editor:GetLine(nLine + n)
        if l == nil then break end
        result = result..l
        _s, _e, c, p = string.find(result, "^%s*('?).-(_?)%s*$")
        --��������: ������, �����, �������(���� ����), ������ ����������� ������(���� ����)
        n = n + 1
    end
    return result..' ', n, c == "'"
end

local function FindUp(stek, nLine, poses)
    local bPrevComment = false
    while true do
        local strUpLine, nContinued, bIsComment = GetFullLine(nLine) --������ "������������" ������, ������, ������� �� ��� ��� ������� ��� ��� ����������
        local bIsFound = false
        if nContinued > 1 and #poses > 0 then
            poses[#poses][4] = cGroupContinued  --��������, ��� ������ �������� ������������
        end
        local s, _e
        if not bIsComment then
            for j = 1, #wrdEndIndent do
                s, _e = CheckPattern(strUpLine, wrdEndIndent[j][1])
                if s ~= nil then --����� ������ ����������� ������
                    table.insert(poses,{string.len(s), _e, nLine, #stek })
                    table.insert(stek, wrdEndIndent[j][2])
                    bIsFound = true
                    break
                end
            end

            if not bIsFound then
                for j = 1, #wrdMidleInent do
                    s, _e = CheckPattern(strUpLine, wrdMidleInent[j][1])
                    if s ~= nil then
                        if bPrevComment and #poses > 0 and poses[#poses][4] == 0 then
                            poses[#poses][4] = cGroupContinued + 1
                            --poses[#poses][1] = string.len(s) + 1
                        end
                        if stek[#stek] ~= wrdMidleInent[j][2] then
                            table.insert(poses,{string.len(s), _e, nLine, 0 })
                            return true, s
                        end
                        table.insert(poses,{string.len(s), _e, nLine, #stek - 1 })
                        bIsFound = true
                        break
                    end
                end
            end
            if not bIsFound then
                for j = 1, #wrdBeginIndent do
                    s, _e = CheckPattern(strUpLine, wrdBeginIndent[j][1])
                    if s ~= nil then
                        if bPrevComment and #poses > 0 and poses[#poses][4] == 0 then
                            poses[#poses][4] = cGroupContinued + 1
                            --poses[#poses][1] = string.len(s) + 1
                        end
                        if stek[#stek] ~= wrdBeginIndent[j][2] then
                            table.insert(poses,{string.len(s), _e, nLine , 0})
                            return true, s
                        else
                            table.remove(stek)
                            table.insert(poses,{string.len(s), _e, nLine, #stek })
                            if #stek == 0 then
                                return false, s
                            end
                            bIsFound = true
                            break
                        end
                    end
                end
            end
        end
        if not bIsFound then
            local _s1, _e1, intnt = string.find(strUpLine, "^(%s*)%S")
            local level = #stek
            if bIsComment and level == 1 and string.len(intnt) < 4 then level = level - 1 end
            if _s1 ~= nil then table.insert(poses,{string.len(intnt), 0, nLine, level }) end
        end
        nLine = nLine - 1
        bPrevComment = bIsComment
        if nLine == 0 then
            return true, ''
        end
    end
end

local function FormatString(strLine, startPos, bForce)
    --�������������� ������ - ���������� �������� ����� �����������, �������� ����� � ������� �����
    local i = 0
    local _s, _e, strSep, strBody = string.find(strLine, "(%s*)(.*)")
    if not bForce and (_G.iuprops['autoformat.line'] or 0) == 0 then return strSep, strBody:gsub('[\r\n]', '') end

    strSep = string.gsub(string.gsub(strSep, "\t", strTab), "\r", "")
    local lk = #keywords

    local strOut = ''

    local strOutComm = ''
    local commPos = 0
    while true do --������� �����������, ���� ����� ��� ����� ���������. �� ��� ���� �������, ������� �� ��� - ����� ���� ������������ ������
        _s, _e, strOutComm, commPos = strBody:find("(%s*()'[^\n\r]*)", commPos + 1)
        if _s then
            if editor.StyleAt[startPos + commPos - 1 + strSep:len()] == SCE_FM_VB_COMMENT then
                strBody = strBody:sub(1, _s - 1)
                break
            end
        else
            break
        end
    end
    if not strOutComm then strOutComm = '' end

    for substr2 in string.gmatch(strBody, '[^"]*"?') do
        if i % 2 == 0 and not isComment then --������������ ������ ��� ����� � ���������
            local j = 0
            local ss1 = ""
            for substr in string.gmatch(substr2, '[^#]*#?') do --������ ���������� ���������� ����� ����� # -  ���� ��� ������
                if j % 2 == 0 then

                    local _d

                    if i > 1 then substr = '"'..substr end
                    substr = string.gsub(substr, chLeftSide, "%1 %2")
                    substr = string.gsub(substr, chRightSide, "%1 %2")
                    substr = string.gsub(substr, "%)([<>%/%=%+%-&%%%*])", ") %1")
                    substr = string.gsub(substr, "([<>%/%=%+%-&%%%*])%)", "%1 )")
                    substr = string.gsub(substr, "([=,<>%/%*%(] ?)%- ([%w%(])", "%1-%2") --������������ ������� �����
                    substr = string.gsub(substr, "Step %- ([%w%(])", "Step -%1") --������������ ������� �����
                    if i > 1 then substr = string.sub(substr, 2) end
                    substr = " "..substr.." "

                    for k = 1, lk do
                        substr = string.gsub(substr, keywordsUp[k], function(s1, s2, s3) return s1..keywords[k]..s3 end)
                    end
                    substr = string.sub(substr, 2,- 2)
                    substr = string.gsub(substr, "%s+", " ")
                end
                ss1 = ss1..substr
                j = j + 1
            end
            substr2 = ss1
        end
        i = i + 1

        strOut = strOut..substr2
    end
    return strSep, strOut..strOutComm
end

function FormatSelectedStrings()
    local lEnd = editor:LineFromPosition(editor.SelectionEnd)
    local lStart = editor:LineFromPosition(editor.SelectionStart)
    editor:BeginUndoAction()
    for i = lStart, lEnd do
        local strUpLine = editor:GetLine(i)
        local strSep, strOut = FormatString(strUpLine, editor:PositionFromLine(i), true)
        if (strOut or '') ~= "" then
            editor:SetSel(editor:PositionFromLine(i), editor:PositionBefore(editor:PositionFromLine(i + 1)))
            editor:ReplaceSel((strSep or '')..strOut)
        end
    end
    editor:EndUndoAction()
    local sp = editor.LineEndPosition[lEnd]
    editor:SetSel(sp, sp)
end

local function ParseStructure(strSep, strOut, current_pos, current_line)

    local bIsError = false
    local bIsFound = false
    local strOutTest = strOut..' '
    local stek = {}  --� ���� ����� ������ ������� �����������, ����������� � ����������� �����������
    local poses ={}   --������ ������ - �������: �������� �������� �������, ������� ��������� ������, ����� ������, ��������������� ������� �����
    local s, _e
    for i = 1, #wrdBeginIndent do
        s, _e = CheckPattern(strOut, wrdBeginIndent[i][1])
        if s ~= nil then --����� ������������� ������ �����������
            nextIndent = strSep..strTab  --������ ����� ������ �������
            bIsFound = true
            break
        end
    end
    if not bIsFound then
        for i = 1, #wrdEndIndent do
            s, _e = CheckPattern(strOut, wrdEndIndent[i][1])  --���� �����������, ����������� ������
            if s ~= nil then
                stek ={wrdEndIndent[i][2]} --�������� � ���� ������ ���� �����������
                local nLine = current_line - 1
                local l = string.len(strSep)
                bIsError, strSep = FindUp(stek, nLine, poses)
                table.insert(poses , 1,{l, _e + l, current_line, 0})
                bIsFound = true
                break
            end
        end
        if bIsFound then
            nextIndent = strSep
        else
            for i = 1, #wrdMidleInent do
                s, _e = CheckPattern(strOut, wrdMidleInent[i][1])
                if s ~= nil then
                    stek ={wrdMidleInent[i][2]}
                    local nLine = current_line - 1
                    local l = string.len(strSep)
                    bIsError, strSep = FindUp(stek, nLine, poses)
                    table.insert(poses , 1,{l, _e + l, current_line, 0})
                    bIsFound = true
                    break
                end
            end
            if bIsFound then
                nextIndent = strSep..strTab
                bIsFound = true
            end
            if not bIsFound then
                nextIndent = strSep
                local s = string.find(strOut, "%_%s*$")
                if s == nil then
                    local n = current_line - 1
                    if n >= 0 then
                        local _s, _e, ni, _b, p = string.find(editor:GetLine(n), "(%s*)(.-)(%_?)%s*$")
                        while p == '_' and n > 0 do
                            nextIndent = ni
                            n = n - 1
                            _s, _e, ni, _b, p = string.find(editor:GetLine(n), "(%s*)(.-)(%_?)%s*$")
                        end
                    end
                end
            end
        end
    end
    return bIsError, strSep, poses
end


local function doAutoformat(current_pos)
    if current_pos < 0 then return true end
    local current_line = editor:LineFromPosition(current_pos)
    local startLine = editor:PositionFromLine(current_line)
    --�������� ����� - ������������� ����� ������ � �������
    if cmpobj_GetFMDefault() ~= SCE_FM_VB_DEFAULT then return end
    local strLine = editor:textrange(startLine, current_pos)
    local strSep, strOut = FormatString(strLine, startLine, true)
    if strOut == '' then
        nextIndent = strSep
        return true
    end
    local bIsError, poses
    bIsError, strSep, poses = ParseStructure(strSep, strOut, current_pos, current_line)
    local strNew = strSep..strOut
    if strLine:gsub('%s*$', '')~= strNew:gsub('%s*$', '') then
        editor:SetSel(startLine, current_pos)

        editor:ReplaceSel(strNew)

        -- current_pos = current_pos + 1 + editor.SelectionEnd -editor.SelectionStart - (current_pos - startLine)
        current_pos = current_pos + 1 + #strNew - #strLine
        editor:SetSel(current_pos, current_pos)
    end

    if poses ~= nil then
        if bIsError then mark = errmark else mark = goodmark end
        for i = 1, #poses do
            local lStart = editor:PositionFromLine(poses[i][3])
            if poses[i][4] == 0 then EditorMarkText(lStart + poses[i][1], poses[i][2] - poses[i][1] - 1, mark) end
        end
    end
end

local needFormat = false
local function OnChar_local(char)
    if not editor.Focus then return end
    curFold = nil
    if string.byte(char) == 13 then
        if (_G.iuprops['autoformat.indent'] or 0) == 1 and (editor.StyleAt[editor:PositionFromLine(editor:LineFromPosition(editor.SelectionStart) - 1)] < 14) then doAutoformat(editor.CurrentPos - 1) end
        editor:ReplaceSel(nextIndent)
        return
    end
    nextIndent = ''
    if mark ~= nil then
        EditorClearMarks(goodmark)
        EditorClearMarks(errmark)
        mark = nil
    end
    if string.byte(char) ~= 10 --[[and FoldLevel(-1) == FoldLevel(0)]] then
        curFold = FoldLevel(-1)
        if curFold == 0 then curFold = nil end
    end

    iChangedLine = editor:LineFromPosition(editor.SelectionStart)
    needFormat = (char ~= '\n')
    return

end

local prevFold
local function OnUpdateUI_local(bModified, bSelection, flag)
    if bModified == 0 and bSelection == 0 then return end
    if not editor.Focus then return end
    local s = editor.SelectionStart
    local e = editor.SelectionEnd
    if needFormat and iChangedLine > - 1 and s == e and ((_G.iuprops['autoformat.indent'] or 0) == 1 or (_G.iuprops['autoformat.line'] or 0) == 1)
      and iChangedLine ~= editor:LineFromPosition(s) and (editor.StyleAt[editor:PositionFromLine(iChangedLine)] < 14) then
        local upLine = editor:textrange(editor:PositionFromLine(iChangedLine), editor:PositionFromLine(iChangedLine + 1))
        local strSep, strOut = FormatString(upLine , editor:PositionFromLine(iChangedLine))
        if strOut ~= "" and upLine:gsub('%s*$', '') ~= (strSep..strOut):gsub('%s*$', '') then
            editor.TargetStart = editor:PositionFromLine(iChangedLine)
            editor.TargetEnd = editor:PositionFromLine(iChangedLine + 1) - 1
            editor:ReplaceTarget(strSep..strOut)
        end
    end
    if prevFold and FoldLevel(-1) == FoldLevel(0) then
        editor.LineIndentation[editor:LineFromPosition(editor.SelectionStart)] = prevFold
    elseif iChangedLine > - 1 and s == e and (_G.iuprops['autoformat.indent'] or 0) == 1 and (editor.StyleAt[editor:PositionFromLine(iChangedLine)] < 14) then
        local l = editor:LineFromPosition(s)
        if l ~= iChangedLine then
            local iline = editor.FirstVisibleLine
            doAutoformat(editor:PositionFromLine(iChangedLine + 1) - 1)
            editor.FirstVisibleLine = iline
            editor:SetSel(s, e)
            iChangedLine = -1
        elseif curFold and curFold > FoldLevel(-1) --[[and FoldLevel(-1) < FoldLevel(0)]] and editor.StyleAt[editor.CurrentPos - 2] == 13 then
            curFold = nil
            local bSet = true
            for i = editor.CurrentPos, editor.Length - 1 do
                local c = editor.CharAt[i]
                if c == 13 or c == 39 then    -- \n � '
                    break
                elseif c ~= 32 then   -- ������
                    bSet = false
                    break
                end
            end

            if editor:textrange(editor:PositionFromLine(editor:LineFromPosition(editor.CurrentPos)), editor.CurrentPos):find('%S +%S') then bSet = false end

            if bSet then
                local curS = editor.SelectionStart
                local ls = editor:LineFromPosition(curS)
                local cL = FoldLevel(-1)
                local curI, curIPos = LineIndent(0) --print(ls, cL)
                for i = ls - 1, 0,- 1 do
                    if cL >= FoldLevel(ls - i) then
                        local endWhat = ''
                        if editor:GetLine(ls):lower():find('^%s*end') then
                            local lUp = editor:GetLine(i):lower():gsub('public', ''):gsub('private', ''):gsub('^%s*', '')
                            if lUp:find('^if') or lUp:find('^else') then endWhat = 'If'
                            elseif lUp:find('^select') or lUp:find('^case') then endWhat = 'Select'
                            elseif lUp:find('^function') then endWhat = 'Function'
                            elseif lUp:find('^sub') then endWhat = 'Sub'
                            elseif lUp:find('^property') then endWhat = 'Property'
                            elseif lUp:find('^with') then endWhat = 'With'
                            end
                        end
                        local li = LineIndent(ls - i)
                        if endWhat ~= '' then
                            local newPos = editor:PositionFromLine(ls)
                            editor.TargetStart = newPos
                            curIPos = curIPos + 3

                            editor.TargetEnd = editor:PositionFromLine(ls) + curIPos + 1

                            local sRep = string.rep(' ', li)..Iif(endWhat == '', '', 'End '..endWhat)
                            editor:ReplaceTarget(sRep)
                            newPos = newPos + #sRep
                            editor.SelectionStart = newPos
                            editor.SelectionEnd = newPos
                            prevFold = nil
                            editor:AutoCCancel()
                        else
                            local curL = editor:GetCurLine(ls):lower()
                            local strRep = string.rep(' ', li)
                            if curL:find('next') then strRep = strRep..'Next'
                            elseif curL:find('wend') then strRep = strRep..'Wend'
                            elseif curL:find('loop') then strRep = strRep..'Loop'
                            else return
                            end
                            editor:AutoCCancel()
                            editor.TargetStart = editor:PositionFromLine(ls)
                            curIPos = curIPos + 4
                            editor.TargetEnd = editor:PositionFromLine(ls) + curIPos
                            editor:ReplaceTarget(strRep)
                            editor.SelectionStart = editor:PositionFromLine(ls) + li + 4
                            editor.SelectionEnd = editor.SelectionStart
                        end
                        if (_G.iuprops['autoformat.indent.force'] or 1) == 1 then IndentBlockUp() end
                        return
                    end
                end
            end
        end
    elseif iChangedLine > - 1 then
        if editor:LineFromPosition(s) ~= editor:LineFromPosition(e) then
            iChangedLine = -1
        end
    end
    prevFold = nil
end

function IndentBlockUp()
    local current_pos = editor.CurrentPos
    local cur_line = editor:LineFromPosition(current_pos)
    local current_line_real = cur_line
    local startLine = editor:PositionFromLine(cur_line)
    local pos_in_line = current_pos - startLine
    local strLine = editor:textrange(startLine, editor.LineEndPosition[cur_line])
    local checked = false
    local curLevel = 0
    repeat
        for j = 1, #wrdEndIndent do
            if CheckPattern(strLine..'    ', wrdEndIndent[j][1]) then --����� �����-�� ����� �����
                curLevel = curLevel - 1
                if curLevel < 0 then
                    checked = true
                end
                break
            end
        end
        if not checked then --���������� �� ������ ����
            for j = 1, #wrdBeginIndent do
                if CheckPattern(strLine..'    ', wrdBeginIndent[j][1]) then --������ ����� - ����������� ������� ������
                    curLevel = curLevel + 1
                    break
                end
            end
            cur_line = cur_line + 1
            if editor.LineCount <= cur_line then break end
            startLine = editor:PositionFromLine(cur_line)
            current_pos = editor.LineEndPosition[cur_line]
            strLine = editor:textrange(startLine, current_pos)
        end
    until checked
    nextIndent = nil
    local _, _, strSep, strOut = string.find(strLine, "^(%s*)(%S.*)")
    if strOut == nil or not checked then
        nextIndent = strSep
        return
    end

    local bIsError, poses
    bIsError, strSep, poses = ParseStructure(strSep, strOut..' ', current_pos, cur_line)
    if poses ~= nil then
        if bIsError then mark = errmark else mark = goodmark end
        if bIsError then
            for i = 1, #poses do
                local lStart = editor:PositionFromLine(poses[i][3])
                if poses[i][4] == 0 then EditorMarkText(lStart + poses[i][1], poses[i][2] - poses[i][1] - 1, mark) end
            end
        else
            editor:BeginUndoAction()
            local startIndent = -1
            local newIndent, oldLine, newLine, prevIndent, prevIndentPreset
            for i = #poses, 1,- 1 do
                local lStart = editor:PositionFromLine(poses[i][3])
                if startIndent == -1 then
                    --������ ������  - ��������-������������
                    startIndent = poses[i][1]
                    EditorMarkText(lStart + startIndent, poses[i][2] - poses[i][1] - 1, mark)
                    prevIndent = startIndent
                    prevIndentPreset = startIndent
                else
                    oldLine = editor:GetLine(poses[i][3])
                    local sepLen
                    if poses[i][4] >= cGroupContinued then
                        if poses[i][4] == cGroupContinued then
                            newIndent = prevIndent + poses[i][1] - prevIndentPreset
                            -- print(poses[i][1],oldLine)
                        else
                            newIndent = prevIndent
                        end
                        sepLen = poses[i][1]
                        if sepLen > 0 then sepLen = sepLen + 1 end
                    else
                        newIndent = startIndent + poses[i][4] * props['tabsize']
                        prevIndent = newIndent
                        prevIndentPreset = poses[i][1]
                        sepLen = poses[i][1]
                        if sepLen > 0 then sepLen = sepLen + 1 end
                    end
                    editor.LineIndentation[poses[i][3]] = newIndent
                    if poses[i][4] == 0 then EditorMarkText(lStart + newIndent, poses[i][2] - poses[i][1] - 1, mark) end
                end
            end
            editor:EndUndoAction()
        end
        --end
    else
        print('No Strcture', strSep, strOut, current_pos, cur_line)
    end
    current_pos = editor:PositionFromLine(current_line_real) + pos_in_line
    editor:SetSel(current_pos, current_pos)
    --editor:LineEnd()
end

------------------------------------------------------
_G.g_session['custom.autoformat.lexers'][SCLEX_FORMENJINE] = true
_G.g_session['custom.autoformat.lexers'][SCLEX_VB] = true

AddEventHandler("OnChar", function(char)
    if cmpobj_GetFMDefault() == SCE_FM_VB_DEFAULT or editor.Lexer == SCLEX_VB then
        if OnChar_local(char) then return true end
    end
end)
AddEventHandler("OnUpdateUI", function(bModified, bSelection, flag)
    if cmpobj_GetFMDefault() == SCE_FM_VB_DEFAULT or editor.Lexer == SCLEX_VB then
        OnUpdateUI_local(bModified, bSelection, flag)
        _G.g_session['custom.autoformat.lexers'][SCLEX_FORMENJINE] = true
    else
        _G.g_session['custom.autoformat.lexers'][SCLEX_FORMENJINE] = false
    end
end)
AddEventHandler("OnSwitchFile", function() iChangedLine = -1 end)
AddEventHandler("OnOpen", function() iChangedLine = -1 end)
AddEventHandler("OnSave", function() iChangedLine = -1 end)
AddEventHandler("Format_String", FormatSelectedStrings)
AddEventHandler("Format_Block", IndentBlockUp)

end
return {
    title = '������������������ VBS � FormEnjine ������',
    hidden = Init,
    destroy = function() CORE.FreeIndic(goodmark); CORE.FreeIndic(errmark) end,
}
