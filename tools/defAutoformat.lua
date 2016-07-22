local curFold

local curLine
local strTab = string.rep(' ',props['tabsize'])

local chLeftSide = '[\\),<>\\/\\=\\+\\-%\\*]\\s*[\\w\\d\\"\']'
local chRightSide = '[\\w\\d\\_)\\]}"\']\\s*[<>\\/\\=\\+\\-%\\*]'
local strunMin = '[,=(] \\- [\\d\\w_(]'
local strunMin2 = '(\\- [\\d\\w_(]'

local operStyle = 10
local keywordStyle = 5

_G.g_session['custom.autoformat.lexers'] = {}

local function FormatString(line)
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

    local lEnd = lStart + editor:GetLine(line):len()
    local lS = lStart

    while lS and lS < lEnd do
        l, lS = editor:findtext(chRightSide, SCFIND_REGEXP, lS, lEnd)
        if lS and lS - l ~= 3 and editor.StyleAt[lS - 1] == operStyle then
            editor.TargetStart = l + 1
            editor.TargetEnd = lS - 1
            editor:ReplaceTarget" "
        end
    end

    lEnd = lStart + editor:GetLine(line):len()
    lS = lStart

    while lS and lS < lEnd do
        l, lS = editor:findtext(strunMin, SCFIND_REGEXP, lS, lEnd)
        if l and editor.StyleAt[l + 2] == operStyle then
            editor.TargetStart = l + 3
            editor.TargetEnd = l + 4
            editor:ReplaceTarget""
        end
    end

    lEnd = lStart + editor:GetLine(line):len()
    lS = lStart

    while lS and lS < lEnd do
        l, lS = editor:findtext(strunMin2, SCFIND_REGEXP, lS, lEnd)
        if l and editor.StyleAt[l + 1] == operStyle then
            editor.TargetStart = l + 2
            editor.TargetEnd = l + 3
            editor:ReplaceTarget""
        end
    end

    lEnd = lStart + editor:GetLine(line):len()
    lS = lStart

    while lS and lS < lEnd do
        l, lS = editor:findtext('\\w  +[^ ]', SCFIND_REGEXP, lS, lEnd)
        if lS and editor.StyleAt[l] == keywordStyle then
            editor.TargetStart = l + 1
            editor.TargetEnd = lS - 1
            editor:ReplaceTarget" "
        end
    end

    lEnd = lStart + editor:GetLine(line):len()
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

local bDoFold = false

local function doIndentation(line, bSel)
    local f0, f1 = FoldLevel(nil, line), FoldLevel(nil, line - 1)
    curFold = nil
    if f0 == f1 and checkMiddle(line - 1) then
        for i = line - 2, 0, -1 do
            if FoldLevel(nil, i) < f0 then
                editor.LineIndentation[line] = editor.LineIndentation[i] + (tonumber(props['tabsize']))
                editor.LineIndentation[line - 1] = editor.LineIndentation[i]
                if bSel then editor:VCHome() end
                return
            end
        end
    else
        local d = f0 - f1
        if d < 0 then d = 0 end
        if bSel then
            -- local _, lineEnd = editor:GetLine(line)
            -- if not lineEnd then return true end
            -- if editor.CurrentPos - editor:PositionFromLine(line) < lineEnd - 2 then d = 0 end
        elseif f0 > FoldLevel(nil, line + 1) then
            d = d - (f0 - FoldLevel(nil, line + 1))
        end
        if d > 0 then d = 1 elseif d < 0 then d = -1 end
        editor.LineIndentation[line] = editor.LineIndentation[line - 1] + (d *  (tonumber(props['tabsize'])))
        if bSel then editor:VCHome() end
    end
end

AddEventHandler("OnChar", function(char)
    if _G.g_session['custom.autoformat.lexers'][editor.Lexer] or not editor.Focus then return end

	if (_G.iuprops['autoformat.line'] or 0) == 1 then
        if not editor.Focus then return end
        if string.byte(char) == 13 then
            local line = editor:LineFromPosition(editor.SelectionStart)
            editor:BeginUndoAction()
            FormatString(line - 1)
            doIndentation(line, true)
            editor:EndUndoAction()
            bDoFold = true
            return true
        elseif string.byte(char) == 10 then
            curFold = nil
            if bDoFold then
                bDoFold = false
                return true
            end
        elseif FoldLevel(-1) == FoldLevel(0) then
            curFold = FoldLevel(-1)
            if curFold == 0 then curFold = nil end
        end
        curLine = editor:LineFromPosition(editor.SelectionStart)
        return false
    end
end)

AddEventHandler("OnUpdateUI", function()
    if _G.g_session['custom.autoformat.lexers'][editor.Lexer] then return end
    if (_G.iuprops['autoformat.line'] or 0) == 1 then
        if curFold and curLine and curLine == editor:LineFromPosition(editor.SelectionStart) and FoldLevel(-1) < FoldLevel(0) then
            curFold = nil
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
                    return
                end
            end
        elseif curLine and (curLine ~= editor:LineFromPosition(editor.SelectionEnd) or curLine ~= editor:LineFromPosition(editor.SelectionStart)) then
            if editor:LineFromPosition(editor.SelectionStart) == editor:LineFromPosition(editor.SelectionEnd) then FormatString(curLine) end
            curLine = nil
        end
        curFold = nil
    end
end)
AddEventHandler("OnSave", function() curLine = nil end)
AddEventHandler("OnSwitchFile", function() curLine = nil end)
AddEventHandler("OnOpen", function() curLine = nil end)

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
        FormatString(i - 1)
        doIndentation(i)
    end
    editor:EndUndoAction()
end)
