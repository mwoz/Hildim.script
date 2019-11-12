local curFold

local curLine

local chLeftSide = '[\\),<>\\/\\=\\+\\-%\\*]\\s*[\\w\\d\\"\']'
local chRightSide = '[\\w\\d\\_)\\]}"\']\\s*[<>\\/\\=\\+\\-%\\*]'
local strunMin = '[,=(] \\- [\\d\\w_(]'
local strunMin2 = '(\\- [\\d\\w_(]'

_AUTOFORMAT_STYLES = {default = {
    operStyle = {[10] = true},
    keywordStyle = {[5] = true},
    ignoredStyle = {[8] = true, [1] = true},
    fixedStyle = {[20] = 0},
    middles = {'else', 'elseif'}
}, hypertext = {
    operStyle = {},
    keywordStyle = {[3] = true},
    ignoredStyle = {[8] = true, [6] = true, [3] = true},
    fixedStyle = {},
    middles = {'else', 'elseif'}
}}

local CurMap = _AUTOFORMAT_STYLES.default

local operStyle, keywordStyle = 10, 5

_G.g_session['custom.autoformat.lexers'] = {}

local function FormatString(line)
    if CurMap.ignoredStyle[editor.StyleAt[editor:PositionFromLine(editor:LineFromPosition(editor.SelectionStart)) - 1]] then return end

    local lStart = editor:PositionFromLine(line)
    local lEnd = lStart + (editor:GetLine(line) or ''):len()
    local lS = lStart
    local l

    while lS and lS < lEnd do
        l, lS = editor:findtext(chLeftSide, SCFIND_REGEXP, lS, lEnd)
        if lS and lS - l ~=  3 and editor.StyleAt[l] == operStyle then
            editor.TargetStart = l + 1
            editor.TargetEnd = lS - 1
            editor:ReplaceTarget" "
        end
    end
    local lEnd = lStart + (editor:GetLine(line) or ''):len()
    local lS = lStart

    while lS and lS < lEnd do
        l, lS = editor:findtext(chRightSide, SCFIND_REGEXP, lS, lEnd)
        if lS and lS - l ~= 3 and editor.StyleAt[lS - 1] == operStyle then
            editor.TargetStart = l + 1
            editor.TargetEnd = lS - 1
            editor:ReplaceTarget" "
        end
    end

    lEnd = lStart + (editor:GetLine(line) or ''):len()
    lS = lStart

    while lS and lS < lEnd do
        l, lS = editor:findtext(strunMin, SCFIND_REGEXP, lS, lEnd)
        if l and editor.StyleAt[l + 2] == operStyle then
            editor.TargetStart = l + 3
            editor.TargetEnd = l + 4
            editor:ReplaceTarget""
        end
    end

    lEnd = lStart + (editor:GetLine(line) or ''):len()
    lS = lStart

    while lS and lS < lEnd do
        l, lS = editor:findtext(strunMin2, SCFIND_REGEXP, lS, lEnd)
        if l and editor.StyleAt[l + 1] == operStyle then
            editor.TargetStart = l + 2
            editor.TargetEnd = l + 3
            editor:ReplaceTarget""
        end
    end

    lEnd = lStart + (editor:GetLine(line) or ''):len()
    lS = lStart

    while lS and lS < lEnd do
        l, lS = editor:findtext('\\w  +[^ ]', SCFIND_REGEXP, lS, lEnd)
        if lS and editor.StyleAt[l] == keywordStyle then
            editor.TargetStart = l + 1
            editor.TargetEnd = lS - 1
            editor:ReplaceTarget" "
        end
    end

    lEnd = lStart + (editor:GetLine(line) or ''):len()
    lS = lStart

    while lS and lS < lEnd do
        l, lS = editor:findtext('[^ ]  +\\w', SCFIND_REGEXP, lS, lEnd)
        if lS and lS - l ~= 3 and editor.StyleAt[lS - 1] == keywordStyle then
            editor.TargetStart = l + 1
            editor.TargetEnd = lS - 1
            editor:ReplaceTarget" "
        end
    end


end

local function FoldLevel(deltaL, L)
    return (editor.FoldLevel[L or (editor:LineFromPosition(editor.SelectionStart) - deltaL)] & SC_FOLDLEVELNUMBERMASK) - SC_FOLDLEVELBASE
end

local function checkMiddle(line)
    local l = editor:GetLine(line) or ''
    local t = CurMap.middles
    for i = 1,  #t do
        if l:find('^%s*'..t[i]..'[^%w]') then return true end
    end
    return false
end

local function Indent(l)
    return string.rep(' ', l)
end

local bNewLine = false

local function doIndentation(line, bSel)
    if CurMap.ignoredStyle[editor.StyleAt[editor:PositionFromLine(line) - 1]] then return end
    if OnIndenation and OnIndenation(line, bSel) then return true end
    if CurMap.fixedStyle[editor.StyleAt[editor:PositionFromLine(line - 1) + editor.LineIndentation[line - 1]]] then
        editor.LineIndentation[line - 1] = CurMap.fixedStyle[editor.StyleAt[editor:PositionFromLine(line - 1) + editor.LineIndentation[line - 1]]]
    end
    local dL = 1
    local dLine = 1
    for i = line - 1, 0, -1 do
        if not CurMap.ignoredStyle[editor.StyleAt[editor:PositionFromLine(i) - 1]] and not CurMap.fixedStyle[editor.StyleAt[editor:PositionFromLine(i) + 1]] then break end
        dL = dL + 1
    end
    if bSel then
        for pl = line - 1, 0, -1 do
            if editor:LineLength(pl) > 2 and not CurMap.fixedStyle[editor.StyleAt[editor:PositionFromLine(pl) + 1]]  then dL = line - pl; break end
        end
    end
    local f0, f1 = FoldLevel(nil, line), FoldLevel(nil, line - dL)
    if OnCheckNotIndent and OnCheckNotIndent(line - dL) then f1 = f0 end

    curFold = nil
    if f0 == f1 and checkMiddle(line - 1) then
        for i = line - 2, 0, -1 do
            if FoldLevel(nil, i) < f0 then
                editor.LineIndentation[line] = editor.LineIndentation[i] + (tonumber(props['indent.size$']))
                editor.LineIndentation[line - 1] = editor.LineIndentation[i]
                if editor.SelectionStart == editor:PositionFromLine(editor:LineFromPosition(editor.SelectionStart)) then editor:VCHome() end
                if f0 <= FoldLevel(nil, line + 1) then return else break end
            end
        end
    end
    local d = f0 - f1
    if d < 0 then d = 0 end

    if f0 > FoldLevel(nil, line + 1) then
        d = d - (f0 - FoldLevel(nil, line + 1))
    end

    if d > 0 then
        editor.LineIndentation[line] = editor.LineIndentation[line - dL] + (tonumber(props['indent.size$']))
    elseif d < 0 then
        f0 = FoldLevel(nil, line + 1)
        for i = line - 2, 0, -1 do
            if FoldLevel(nil, i) <= f0 then
                editor.LineIndentation[line] = editor.LineIndentation[i]
                return
            end
        end
    elseif bSel and (editor:line(line) or ''):find('^%s*}%s*$') then
        editor.LineIndentation[line] = editor.LineIndentation[line - dL]
        editor:NewLine()
        editor.LineIndentation[line] = editor.LineIndentation[line - dL] + (tonumber(props['indent.size$']))
        editor:LineUp()
        editor:LineEnd()
        return
    else
        editor.LineIndentation[line] = editor.LineIndentation[line - dL]
    end
    if bSel and editor.SelectionStart == editor:PositionFromLine(editor:LineFromPosition(editor.SelectionStart)) then editor:VCHome() end

end

AddEventHandler("OnChar", function(char)
    if _G.g_session['custom.autoformat.lexers'][editor.Lexer] or not editor.Focus then return end
    bNewLine = false
	if (_G.iuprops['autoformat.indent'] or 0) == 1 or (_G.iuprops['autoformat.line'] or 0) == 1 then
        if not editor.Focus then return end
        if string.byte(char) == 13 then
            editor:BeginUndoAction()
            if editor.EOLMode == SC_EOL_CR then
                curFold = nil
                bNewLine = true
            end
        elseif string.byte(char) == 10 then
            curFold = nil
            bNewLine = true
            if editor.EOLMode == SC_EOL_LF then editor:BeginUndoAction() end
        elseif FoldLevel(-1) == FoldLevel(0) then
            curFold = FoldLevel(-1)
            if curFold == 0 then curFold = nil end
        end
        curLine = editor:LineFromPosition(editor.SelectionStart)
        return
    end
end)

local prevFold
AddEventHandler("OnUpdateUI", function(bModified, bSelection, flag)
    if _G.g_session['custom.autoformat.lexers'][editor.Lexer] or (bModified == 0 and bSelection == 0) then return end
    if (_G.iuprops['autoformat.indent'] or 0) == 1 or (_G.iuprops['autoformat.line'] or 0) == 1 then
        if bNewLine then
            --editor:BeginUndoAction()
            if (_G.iuprops['autoformat.line'] or 0) == 1 then FormatString(curLine - 1) end
            if (_G.iuprops['autoformat.indent'] or 0) == 1 then doIndentation(curLine, true) end
            editor:EndUndoAction()
            bNewLine = false
        elseif (bModified == 1 and bSelection == 0) and curFold and curLine and curLine == editor:LineFromPosition(editor.SelectionStart) and FoldLevel(-1) < FoldLevel(0) then
            if editor.CharAt[editor.CurrentPos] == 13 then
                local curS = editor.SelectionStart
                local ls = editor:LineFromPosition(curS)
                local cL = FoldLevel(-1)
                local curI, curIPos = editor.LineIndentation[ls]
                for i = ls - 1, 0,- 1 do
                    if cL >= FoldLevel(ls - i) then
                        local newPos = curS - (curI - editor.LineIndentation[i])
                        editor.LineIndentation[ls] = editor.LineIndentation[i]
                        editor.SelectionStart = newPos
                        editor.SelectionEnd = newPos
                        prevFold = curI
                        editor:AutoCCancel()
                        if (_G.iuprops['autoformat.indent.force'] or 1) == 1 then Format_Block() end
                        return
                    end
                end
            end
            curFold = nil
            return
        elseif prevFold and curLine and curLine == editor:LineFromPosition(editor.SelectionStart) and FoldLevel(-1) == FoldLevel(0) then
            editor.LineIndentation[curLine] = prevFold
        elseif curLine and (curLine ~= editor:LineFromPosition(editor.SelectionEnd) or curLine ~= editor:LineFromPosition(editor.SelectionStart)) then
            if editor:LineFromPosition(editor.SelectionStart) == editor:LineFromPosition(editor.SelectionEnd) then FormatString(curLine) end
            curLine = nil
        end
        curFold = nil
        prevFold = nil
    end
end)

_G.g_session['custom.autoformat.lexers'][SCLEX_MSSQL] = true
local function OnSwitchFile_local()
    CurMap = _AUTOFORMAT_STYLES[editor_LexerLanguage()] or _AUTOFORMAT_STYLES.default
    _AUTOFORMAT_STYLES.current = CurMap
    curLine = nil
    local f, t = pairs(CurMap.operStyle);
    operStyle = f(t)
    f, t = pairs(CurMap.keywordStyle);
    keywordStyle = f(t)
end
AddEventHandler("OnSave", OnSwitchFile_local)
AddEventHandler("OnSwitchFile", OnSwitchFile_local)
AddEventHandler("OnOpen", OnSwitchFile_local)

AddEventHandler("Format_String", function()
    if _G.g_session['custom.autoformat.lexers'][editor.Lexer] then return end
    FormatString(editor:LineFromPosition(editor.SelectionStart))
end)
AddEventHandler("Format_Block", function()
    if _G.g_session['custom.autoformat.lexers'][editor.Lexer] then return end
    local line = editor:LineFromPosition(editor.SelectionStart)
    local lineEnd, lineStart = 0, 0
    local indS = FoldLevel(0, line )
    for i = line + 1 , editor.LineCount do
        if indS > FoldLevel(0, i) then
            lineEnd = i - 1
            indS = FoldLevel(0, i)
            break
        end
    end
    for i = lineEnd - 1, 0, -1 do
        if indS >= FoldLevel(0, i) then
            lineStart = i + 1
            break
        end
    end
    editor:BeginUndoAction()
    for i = lineStart, lineEnd do
        if i > 0 then FormatString(i - 1) end
        doIndentation(i)
    end
    editor:EndUndoAction()
end)
