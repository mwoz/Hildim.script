local curFold

local curLine

local chLeftSide = '[\\),<>\\/\\=\\+\\-%\\*]\\s*[\\w\\d\\"\']'
local chRightSide = '[\\w\\d\\_)\\]}"\']\\s*[<>\\/\\=\\+\\-%\\*]'
local strunMin = '[,=(] \\- [\\d\\w_(]'
local strunMin2 = '(\\- [\\d\\w_(]'

local stylesMap = {default = {
    operStyle = {[10] = true},
    keywordStyle = {[5] = true},
    ignoredStyle = {[8] = true, [1] = true}
}, hypertext = {
    operStyle = {[1] = true},
    keywordStyle = {[3] = true},
    ignoredStyle = {[8] = true, [6] = true, [3] = true}
}}

local CurMap = stylesMap.default


local operStyle = 10
local keywordStyle = 5

_G.g_session['custom.autoformat.lexers'] = {}

local function FormatString(line)
    if CurMap.ignoredStyle[editor.StyleAt[editor:PositionFromLine(editor:LineFromPosition(editor.SelectionStart))]] then return end

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
    return shell.bit_and(editor.FoldLevel[L or (editor:LineFromPosition(editor.SelectionStart) - deltaL)],SC_FOLDLEVELNUMBERMASK) - SC_FOLDLEVELBASE
end

local function checkMiddle(line)
    local l = editor:GetLine(line)
    return l:find('^%s*else[^%w]') or l:find('^%s*elseif[^%w]')
end

local function Indent(l)
    return string.rep(' ', l)
end

local bNewLine = false

local function doIndentation(line, bSel)
    if CurMap.ignoredStyle[editor.StyleAt[editor:PositionFromLine(line)]] then return end
    local dL = 1
    if bSel then
        for pl = line - 1, 0, -1 do
            if editor:LineLength(pl) > 2 then dL = line - pl; break end
        end
    end
    local f0, f1 = FoldLevel(nil, line), FoldLevel(nil, line - dL)

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
    elseif bSel and editor:textrange(editor:PositionFromLine(line), editor:PositionFromLine(line) + editor:LineLength(line)):find('^%s*}%s*$') then
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
	if (_G.iuprops['autoformat.line'] or 0) == 1 then
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
            if editor.EOLMode == SC_EOL_LF then  editor:BeginUndoAction() end
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
    if (_G.iuprops['autoformat.line'] or 0) == 1 then
        if bNewLine then
            --editor:BeginUndoAction()
            FormatString(curLine - 1)
            doIndentation(curLine, true)
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
local function OnSwitchFile_local()
    CurMap = stylesMap[editor.LexerLanguage] or stylesMap.default
    curLine = nil
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
