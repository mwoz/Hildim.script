local curFold

-----------------------------------------------------------------------
-- local startWords
-- do
--     local w1st = {'create ', 'for', 'insert', 'intersect', 'into', 'open', 'output', 'option', 'return', 'set', 'values', 'ubion'}
--     local w1stUp = {'alter +table', 'compute', 'declare', 'delete', 'else', 'exec', 'execute','if',  'from', 'fetch', 'group +by', 'having', 'order +by', 'select', 'update', 'when', 'where', 'while'}
--     local wUp = {'begin', }
--     local w2Up = {'inner +join', 'left +outer +join', 'join', 'outer +join', 'left +join','right +join','right +outer +join', }

--     startWords = {}
--     for i = 1,  #w1st do
--         if not startWords[w1st[i]:byte(1)] then startWords[w1st[i]:byte(1)] = {} end
--         table.insert(startWords[w1st[i]:byte(1)], {'^'..w1st[i], true, false, false})
--     end
--     for i = 1,  #w1stUp do
--         if not startWords[w1stUp[i]:byte(1)] then startWords[w1stUp[i]:byte(1)] = {} end
--         table.insert(startWords[w1stUp[i]:byte(1)], {'^'..w1stUp[i], true, true, false})
--     end
--     for i = 1,  #wUp do
--         if not startWords[wUp[i]:byte(1)] then startWords[wUp[i]:byte(1)] = {} end
--         table.insert(startWords[wUp[i]:byte(1)], {'^'..wUp[i], 1, true, false})
--     end
--     for i = 1,  #w2Up do
--         if not startWords[w2Up[i]:byte(1)] then startWords[w2Up[i]:byte(1)] = {} end
--         table.insert(startWords[w2Up[i]:byte(1)], {'^'..w2Up[i], true, true, true})
--     end
--     function startWords:mtch(sIn)
--         local s = (sIn or ''):lower()
--         if self[s:byte(1)] then
--             local t = self[s:byte(1)]
--             for i = 1,  #t do
--                 if s:find(t[i][1]) then return true, t[i][2], t[i][3], t[i][4] end
--             end
--         end
--     end
-- end
-----------------------------------------------------------------------

local curLine, OnPostCheckCase, CurMap


local IS_NORMAL <const>, IS_ZEROINDENT <const>, IS_FIXED <const>, IS_STICKY <const>, IS_STICKYHDR <const>, IS_ABS <const> = 0, 1, 2, 3, 4, 5
local S_LINE <const>, S_WRD <const>, S_LINEHDR <const> = 0, 1, 2

local function IndLevel(line)
    local c, n = editor.FoldLevel[line] & SC_FOLDLEVELNUMBERMASK - SC_FOLDLEVELBASE, (editor.FoldLevel[line] >> 16) & SC_FOLDLEVELNUMBERMASK - SC_FOLDLEVELBASE
    return math.min(c, n), c - n
end

local function FoldParentLevel(line, lvl)
    local lvl2, l2
    l2 = line
    if lvl >= 0 then
        repeat
            l2 = editor.FoldParent[l2]
            lvl2 = editor.FoldLevel[l2] & SC_FOLDLEVELNUMBERMASK - SC_FOLDLEVELBASE
        until lvl2 <= lvl
    end
    return l2
end

_AUTOFORMAT_STYLES = {none = {
    empty = true
}, default = {
    operStyle = {[10] = true},
    keywordStyle = {[5] = true},
    ignoredStyle = {[8] = true, [1] = true},
    fixedStyle = {[20] = 0},
}, hypertext = {
    operStyle = {},
    keywordStyle = {[3] = true},
    ignoredStyle = {[8] = true, [6] = true, [3] = true},
    fixedStyle = {},
}, xml = {
    operStyle = {},
    keywordStyle = {[3] = true},
    ignoredStyle = {[8] = true, [6] = true, [3] = true},
    stickyStyle = {[SCE_H_OTHER] = S_LINE, [SCE_H_COMMENT] = S_WRD},
    fixedStyle = {[SCE_H_SINGLESTRING] = S_LINE,[SCE_H_DOUBLESTRING] = S_LINE, [SCE_H_COMMENT] = S_LINE, [SCE_H_CDATA] = S_LINE},
    correctDelta = function(line, delta, deltaNext)
        if ((editor.FoldLevel[line] >> 16) & SC_FOLDLEVELNUMBERMASK) < (editor.FoldLevel[line] & SC_FOLDLEVELNUMBERMASK) and
            editor:line(line):lower():find('></field>') then
            delta = delta + editor.Indent
            deltaNext = deltaNext - editor.Indent
        end
        return delta, deltaNext
    end
}, formenjine = {
    keywordStyle = {[SCE_FM_VB_KEYWORD] = true},
    operStyle = {[SCE_FM_VB_OPERATOR] = true},
    ignoredStyle = {[8] = true, [6] = true, [3] = true},
    stickyStyle = {[SCE_FM_VB_STRINGCONT] = S_LINEHDR, [SCE_FM_VB_COMMENT] = S_WRD, [SCE_FM_X_TAG] = S_LINE, [SCE_FM_X_COMMENT] = S_WRD, [SCE_FM_SQL_COMMENT] = S_WRD, [SCE_FM_SQL_LINE_COMMENT] = S_WRD, },
    fixedStyle = {[SCE_FM_X_STRING] = S_LINE, [SCE_FM_PLAINCDATA] = S_LINE, [SCE_FM_SQL_STRING] = S_LINE, [SCE_FM_X_COMMENT] = S_LINE, [SCE_FM_SQL_COMMENT] = S_LINE, [SCE_FM_PREPROCESSOR] = S_WRD,[SCE_FM_SQL_FMPARAMETR] = S_WRD,},
    wordsCaseStyles = {[SCE_FM_VB_FUNCTIONS] = true, [SCE_FM_VB_KEYWORD] = true},
    wordsCase = {"ByRef", "ByVal", "ElseIf", "ExecuteGlobal", "ReDim",
        "TypeName", "TimeSHerial", "IsObject", "IsNumeric", "IsNull", "IsEmpty", "IsDate", "IsArray", "InStrRev",
        "InStr", "GetRef", "GetObject", "GetLocale", "FormatPpercent", "FormatNumber", "FormatDatetime",
        "FormatCurrency", "DateValue", "Dateserial", "DatePart", "DateDiff", "DateAdd", "CreateObject",
    },
    wordsCasePostProcess = function(word, tgtStart)
        if (word:lower() ~= 'end') or (tgtStart and tgtStart ~= editor.LineIndentPosition[editor:LineFromPosition(tgtStart)]) then return end

        if not tgtStart then return true end
        if editor.SelectionStart ~= tgtStart + 4 or editor.CharAt[tgtStart + 3] ~= 32 then return end

        local lS = editor.FoldParent[editor:LineFromPosition(tgtStart)]
        local strLine = editor:GetLine(lS):lower()
        if strLine:find('^%s*case[^%w]') or strLine:find('^%s*else[^%w]') or strLine:find('^%s*elseif[^%w]') then
            lS = editor.FoldParent[lS]
            strLine = editor:GetLine(lS):lower()
        end

        local _, _, w1, w2 = strLine:gsub('^%s+', ''):gsub('^private%s+', ''):find('^(%w)(%w+)')
        if w2 then
            strLine = 'End '..w1:upper()..w2
            editor.TargetEnd = tgtStart + 4
            editor:ReplaceTarget(strLine)
            editor.SelectionStart = tgtStart + strLine:len()
            editor.SelectionEnd = editor.SelectionStart
        end

        return true
    end,
    check1stWrdStyle = {
        style = SCE_FM_SQL_STATEMENT,
        check = function() return editor.LineState[editor:LineFromPosition(editor.SelectionStart)] & 0xF ~= 2 end,
    },
    correctDelta = function(line, delta, deltaNext)
        local function checkPrevEq(l)
    -- сдвиг одной строки после оператора

            if l > 0 then
                local prevP = editor.LineEndPosition[l - 1] - 1
                while editor.CharAt[prevP] == 32 and prevP > 0 do prevP = prevP - 1 end
                local c = editor.CharAt[prevP] -- =-+/*<>
                if editor:ustyle(prevP) == SCE_FM_SQL_OPERATOR and (c == 61 or c == 45 or c == 43 or c == 47 or c == 42 or c == 60 or c == 62) then --'='
                    return true
                end
            end
        end
        local lState = editor.LineState[line]
        local sector = lState & 0xF
        local newIS, calcDelta
        if lState & 0x800 ~= 0 then
            delta = editor.LineIndentation[editor.FoldParent[line]]  --лучше циклом пробежать вверх до 0x400!
            return delta, 0, IS_ABS
        end
        local style = editor:ustyle(editor.LineIndentPosition[line])

        if (style == SCE_FM_X_TAG) then
            if sector ~= 2 then deltaNext = -editor.Indent end
            local f = editor.FoldLevel[line]
            if (f & SC_FOLDLEVELNUMBERMASK) - SC_FOLDLEVELBASE == 1 then
                return 0, deltaNext, IS_ABS
            end
            if (f & SC_FOLDLEVELNUMBERMASK) - SC_FOLDLEVELBASE == 2 then
                local s = editor.LineIndentPosition[line] + 1
                local e = editor:WordEndPosition(s, true)
                local w = editor:textrange(s, e)
                if w == 'String' or w == 'string' or w == 'script' then
                    return 0, deltaNext, IS_ABS
                elseif w == 'option' then
                    return editor.Indent * 2, -editor.Indent, IS_ABS
                end
            end
        elseif sector == 1 then --vb
            local lvl, dLvl = IndLevel(line)
            if dLvl == -2 and lState & 0x2000 ~= 0 and deltaNext == 0 then
                -- local s = editor:line(line):lower()
                -- if s:find('^%s*select') or s:find('then%s*$') then
                deltaNext = -editor.Indent
            --end
            end
        elseif sector == 3 then --sql
            if editor:ustyle(editor.LineIndentPosition[line]) == SCE_FM_SQL_STATEMENT then
                local indentFlag = (lState >> 20) & 0xF
                if indentFlag > 0 then
                    local b1st = 0;
                    if indentFlag == 3 then b1st = 1 end
                    newIS = IS_ABS
                    local d = Iif(indentFlag == 4, editor.Indent, 0)
                    local p1 = editor.FoldParent[line] or -1
                    local p1Ind = Iif(editor.LineState[p1] & 0x400 == 0, editor.LineIndentation[p1], 0)
                    -- print(line, p1Ind, p1, calcDelta)
                    if indentFlag ~= 3 then
                        if not calcDelta then
                            if p1 >= 0 then
                                delta = p1Ind + editor.Indent + d
                            else
                                delta = d
                            end
                        else
                            delta = editor.Indent
                        end
                        deltaNext = editor.Indent        -----
                    else
                        if not calcDelta then
                            if p1 >= 0 then
                                if editor:GetLine(p1):lower():find('^%s*create%s+') then
                                    delta = p1Ind + d
                                else
                                    delta = p1Ind + editor.Indent + d
                                end
                            else
                                delta = d
                            end
                        end
                        deltaNext = editor.Indent
                    end

                    return delta, deltaNext, newIS
                end
            elseif (style == SCE_FM_SQL_OPERATOR and editor.FoldLevel[line] & SC_FOLDLEVELHEADERFLAG ~= 0) then
                -- уменьшение отступа для открывающей скобки - первой в строке
                for i = line - 1, 0, -1 do
                    local lip = editor.LineIndentPosition[i]
                    if lip < editor.LineEndPosition[i] and not CurMap.fixedStyle[editor:ustyle(lip)]
                        and not CurMap.fixedStyle[editor:ustyle(lip)]
                        and not CurMap.stickyStyle[editor:ustyle(lip)] then
                        if (editor.LineState[i] >> 20) & 0xF ~= 0 then
                            delta = delta - editor.Indent
                        elseif editor:ustyle(editor.LineEndPosition[i] - 1) == SCE_FM_SQL_FUNCTION then
                            newIS = IS_ABS
                            delta = editor.LineIndentation[i]
                        end
                        break;
                    end
                end
            end
        end
        if sector == 3 then
            local lvl, dLvl = IndLevel(line)
            if dLvl > 0 then
                return editor.LineIndentation[FoldParentLevel(line, lvl) or 0], 0, IS_ABS
            end

            if checkPrevEq(line) then
                delta, deltaNext = delta + editor.Indent, deltaNext - editor.Indent
            end
        end
        return delta, deltaNext, newIS
    end
}, lua = {
    operStyle = {[SCE_LUA_OPERATOR] = true},
    keywordStyle = {[SCE_LUA_WORD] = true},
    ignoredStyle = {},
    zeroStyle = {[SCE_LUA_LABEL] = S_WRD},
    stickyStyle = {[SCE_LUA_COMMENTLINE] = S_WRD},
    fixedStyle = {[SCE_LUA_LITERALSTRING] = S_LINE,[SCE_LUA_COMMENT] = S_LINE},
}, mssql = {
    keywordStyle = {},
    operStyle = {},
    ignoredStyle = {},
    zeroStyle = {[SCE_MSSQL_LINE_COMMENT_EX] = S_WRD,[SCE_MSSQL_M4KEYS] = S_WRD},
    stickyStyle = { },
    fixedStyle = {[SCE_MSSQL_STRING] = S_LINE, [SCE_MSSQL_COMMENT] = S_WRD, [SCE_MSSQL_LINE_COMMENT] = S_WRD,},
    check1stWrdStyle = {
        style = SCE_MSSQL_STATEMENT,
        check = function() return true end,
    },
    correctDelta = function(line, delta, deltaNext)
        local function checkPrevEq(l)
            -- сдвиг одной строки после оператора

            if l > 0 then
                local prevP = editor.LineEndPosition[l - 1] - 1
                while editor.CharAt[prevP] == 32 and prevP > 0 do prevP = prevP - 1 end
                local c = editor.CharAt[prevP] -- =-+/*<>
                if editor:ustyle(prevP) == SCE_MSSQL_OPERATOR and (c == 61 or c == 45 or c == 43 or c == 47 or c == 42 or c == 60 or c == 62) then --'='
                    return true
                end
            end
        end

        local lState = editor.LineState[line]
        if lState & 0x1000000 ~= 0 then
            return delta, deltaNext, IS_FIXED
        end
        local sector = lState & 0xF
        local newIS, calcDelta
        if lState & 0x1000 ~= 0 then
            delta = -editor.LineIndentation[line - 1]
            calcDelta = true
        end
        if lState & 0x800 ~= 0 then
            delta = editor.LineIndentation[editor.FoldParent[line]]  --лучше циклом пробежать вверх до 0x400!
            return delta, 0, IS_ABS
        end

        local style = editor:ustyle(editor.LineIndentPosition[line])
        if style == SCE_MSSQL_STATEMENT then

            local indentFlag = (lState >> 20) & 0xF
            if indentFlag > 0 and indentFlag ~= 5 then
                local b1st = 0;
                if indentFlag == 3 then b1st = 1 end

                newIS = IS_ABS
                local d = Iif(indentFlag == 4, editor.Indent, 0)
                local p1 = editor.FoldParent[line] or -1
                local p1Ind = Iif(editor.LineState[p1] & 0x400 == 0, editor.LineIndentation[p1], - editor.Indent)

                if indentFlag ~= 3 then
                    -- local notFoldHead = editor.FoldLevel[line] & SC_FOLDLEVELHEADERFLAG == 0  ;
                    notFoldHead = true
                    if not calcDelta then
                        if p1 >= 0 and notFoldHead then
                            delta = p1Ind + editor.Indent + d
                        else
                            delta = d
                        end
                    end
                    deltaNext = Iif(notFoldHead, editor.Indent, 0)        -----
                else
                    if not calcDelta then
                        if p1 >= 0 then
                            if editor:GetLine(p1):lower():find('^%s*create%s+') then
                                delta = p1Ind + d
                            else
                                delta = p1Ind + editor.Indent + d
                            end
                        else
                            delta = d
                        end
                    end
                    deltaNext = editor.Indent
                end
                return delta, deltaNext, newIS
            end
        elseif (style == SCE_MSSQL_OPERATOR and editor.CharAt[editor.LineIndentPosition[line]] == 40) or (style == SCE_MSSQL_M4KBRASHES and editor.CharAt[editor.LineIndentPosition[line]] == 123) then
            -- уменьшение отступа для открывающей скобки ({ - первой в строке
            for i = line - 1, 0, -1 do
                local lip = editor.LineIndentPosition[i]
                if lip < editor.LineEndPosition[i] and not CurMap.fixedStyle[editor:ustyle(lip)]
                    and not CurMap.fixedStyle[editor:ustyle(lip)]
                    and not CurMap.zeroStyle[editor:ustyle(lip)] then
                    if (editor.LineState[i] >> 20) & 0xF ~= 0 then
                    -- if editor:ustyle(lip) == SCE_MSSQL_STATEMENT then
                        if (editor.LineState[i] >> 20) & 0xF ~= 5 then delta = delta - editor.Indent end
                        if (editor.FoldLevel[i] & SC_FOLDLEVELHEADERFLAG) ~= 0 then delta = delta - editor.Indent end
                    elseif editor:ustyle(editor.LineEndPosition[i] - 1) == SCE_MSSQL_FUNCTION or editor.StyleAt[editor.LineIndentPosition[i]] == SCE_MSSQL_SYSMCONSTANTS then
                        newIS = IS_ABS
                        delta = editor.LineIndentation[i]
                    end
                    break;
                end
            end
        elseif style == SCE_MSSQL_SYSMCONSTANTS then
            local lP = FoldParentLevel(line, IndLevel(line))
            if lP == line or (editor.FoldLevel[line] & SC_FOLDLEVELNUMBERMASK) == SC_FOLDLEVELBASE then
                return 0, 0, IS_ABS
            else
                return editor.LineIndentation[FoldParentLevel(line, IndLevel(line))] + editor.Indent, 0, IS_ABS
            end
        end
        local lvl, dLvl = IndLevel(line)

        if dLvl > 0 then
            local lP = FoldParentLevel(line, lvl) or 0
            local dP = editor.LineIndentation[lP]
            local dN = 0
            if dP > 0 and checkPrevEq(lP) then dN = -editor.Indent end
            return editor.LineIndentation[FoldParentLevel(line, lvl) or 0], dN, IS_ABS
        end

        if checkPrevEq(line) then
            delta, deltaNext = delta + editor.Indent, deltaNext - editor.Indent
        end
        return delta, deltaNext, newIS
    end

}}

CurMap = _AUTOFORMAT_STYLES.default

local operStyle, keywordStyle = 10, 5

local function FormatString(line)

    local chLeftSide = '[),<>/=+\\-%*&|\\\\]\\s*[\\w\\d\\"\']'
    local chRightSide = '[\\w\\d\\_)\\]}"\']\\s*[<>/=+\\-%*&|\\\\]'
    local strunMin = '[,=(\\w] \\- [\\d\\w_(]'
    local strunMin2 = '(\\- [\\d\\w_(]'

    if CurMap.ignoredStyle[editor:ustyle(editor:PositionFromLine(editor:LineFromPosition(editor.SelectionStart)) - 1)] then return end
    editor:BeginUndoAction()
    local lStart = editor:PositionFromLine(line)
    local lEnd = lStart + (editor:GetLine(line) or ''):len()
    local lS = lStart
    local l

    while lS and lS < lEnd do
        l, lS = editor:findtext(chLeftSide, SCFIND_REGEXP, lS, lEnd)
        if lS and lS - l ~= 3 and editor:ustyle(l) == operStyle then
            -- print("ls", l, lS, editor:textrange(l, lS))
            editor.TargetStart = l + 1
            editor.TargetEnd = lS - 1
            editor:ReplaceTarget" "
        end
    end
    local lEnd = lStart + (editor:GetLine(line) or ''):len()
    local lS = lStart

    while lS and lS < lEnd do
        l, lS = editor:findtext(chRightSide, SCFIND_REGEXP, lS, lEnd)
        if lS and lS - l ~= 3 and editor:ustyle(lS - 1) == operStyle then
            -- print("rs", l, lS, editor:textrange(l, lS))
            editor.TargetStart = l + 1
            editor.TargetEnd = lS - 1
            editor:ReplaceTarget" "
        end
    end

    lEnd = lStart + (editor:GetLine(line) or ''):len()
    lS = lStart

    while lS and lS < lEnd do
        l, lS = editor:findtext(strunMin, SCFIND_REGEXP, lS, lEnd)
        if l and (editor:ustyle(l) == operStyle or editor:ustyle(l) == keywordStyle) then
            editor.TargetStart = l + 3
            editor.TargetEnd = l + 4
            editor:ReplaceTarget""
        end
    end

    lEnd = lStart + (editor:GetLine(line) or ''):len()
    lS = lStart

    while lS and lS < lEnd do
        l, lS = editor:findtext(strunMin2, SCFIND_REGEXP, lS, lEnd)
        if l and editor:ustyle(l + 1) == operStyle then
            editor.TargetStart = l + 2
            editor.TargetEnd = l + 3
            editor:ReplaceTarget""
        end
    end

    lEnd = lStart + (editor:GetLine(line) or ''):len()
    lS = lStart

    while lS and lS < lEnd do
        l, lS = editor:findtext('\\w  +[^ ]', SCFIND_REGEXP, lS, lEnd)
        if lS and editor:ustyle(l) == keywordStyle then
            editor.TargetStart = l + 1
            editor.TargetEnd = lS - 1
            editor:ReplaceTarget" "
        end
    end

    lEnd = lStart + (editor:GetLine(line) or ''):len()
    lS = lStart

    while lS and lS < lEnd do
        l, lS = editor:findtext('[^ ]  +\\w', SCFIND_REGEXP, lS, lEnd)
        if lS and lS - l ~= 3 and editor:ustyle(lS - 1) == keywordStyle then
            editor.TargetStart = l + 1
            editor.TargetEnd = lS - 1
            editor:ReplaceTarget" "
        end
    end
    editor:EndUndoAction()

end

local function FoldLevel(deltaL, L)
    return (editor.FoldLevel[L or (editor:LineFromPosition(editor.SelectionStart) - deltaL)] & SC_FOLDLEVELNUMBERMASK) - SC_FOLDLEVELBASE
end

local function Indent(l)
    return string.rep(' ', l)
end

local bNewLine = false

local prevFold

local function OnSwitchFile_local()
    if editor.Length == 0 then
        CurMap = nil
    elseif (editor.FoldLevel[0] >> 16) & SC_FOLDLEVELNUMBERMASK == 0 then
        CurMap = nil
    else
        CurMap = _AUTOFORMAT_STYLES[editor_LexerLanguage()] or _AUTOFORMAT_STYLES.default
    end
    _AUTOFORMAT_STYLES.current = CurMap
    if not CurMap or CurMap.empty then return end
    curLine = nil
    local f, t = pairs(CurMap.operStyle);
    operStyle = f(t)
    f, t = pairs(CurMap.keywordStyle);
    keywordStyle = f(t)
    if CurMap.wordsCase and not CurMap.wc_calc then
        CurMap.wc_calc = {}
        for i = 1,  #(CurMap.wordsCase) do
            CurMap.wc_calc[(CurMap.wordsCase[i]):lower()] = CurMap.wordsCase[i]
        end
    end
end

AddEventHandler("OnSave", OnSwitchFile_local)
AddEventHandler("OnSwitchFile", OnSwitchFile_local)
AddEventHandler("OnOpen", OnSwitchFile_local)

AddEventHandler("OnUpdateUI", function(bModified, bSelection, flag)
    if not CurMap and editor.Length > 0 then
        if ((editor.FoldLevel[0] >> 16) & SC_FOLDLEVELNUMBERMASK) ~= 0 then
            CurMap = _AUTOFORMAT_STYLES[editor_LexerLanguage()] or _AUTOFORMAT_STYLES.default
        elseif editor.LineCount > 1 then
            CurMap = _AUTOFORMAT_STYLES.none
        end
        _AUTOFORMAT_STYLES.current = CurMap
    end
    if not CurMap or CurMap.empty then return end
    if (bModified == 0 and bSelection == 0) then return end
    if OnPostCheckCase and (bModified ~= 0 or bSelection ~= 0) then scite.RunAsync(OnPostCheckCase) end
    if (_G.iuprops['autoformat.line'] or 0) == 1 then
        if curLine and curLine ~= editor:LineFromPosition(editor.SelectionStart) then     --bNewLine and
            editor:BeginUndoAction()
            FormatString(curLine)
            editor:EndUndoAction()
            bNewLine = false
        end
    end
end)

AddEventHandler("Format_String", function()
    if not CurMap or CurMap.empty then return end
    FormatString(editor:LineFromPosition(editor.SelectionStart))
end)

local function FormatLinesDEF(lineStart, lineEnd, bFormatEmpty)
    -- print(lineStart, lineEnd, bFormatEmpty)
    local EOL_LENGTH <const> = Iif(editor.EOLMode == SC_EOL_CRLF, 2, 1)
    local function Delta4LineDEF(line, lvlPr)
        local bIsHeader = ((editor.FoldLevel[line] & SC_FOLDLEVELHEADERFLAG) ~= 0)
        local delta, deltaNext = 0, 0
        local indentStyle = Iif(not bFormatEmpty and editor:LineLength(line) - Iif(editor.LineCount == line + 1, 0, EOL_LENGTH) == editor.LineIndentation[line], IS_ZEROINDENT, IS_NORMAL)
        local lvl, deltaFold = IndLevel(line)
        local styleBefore = editor:ustyle(editor:PositionFromLine(line) - 1)
        local styleStart = editor:ustyle(editor.LineIndentPosition[line])

        if CurMap.zeroStyle and (CurMap.zeroStyle[styleBefore] == S_LINE or CurMap.zeroStyle[styleStart] == S_WRD) then
            return delta, deltaNext, IS_ZEROINDENT, lvlPr
        end
        if CurMap.fixedStyle and (CurMap.fixedStyle[styleBefore] == S_LINE or CurMap.fixedStyle[styleStart] == S_WRD) then
            return delta, deltaNext, IS_FIXED, lvlPr
        end
        if CurMap.stickyStyle and (CurMap.stickyStyle[styleBefore] == S_LINE or CurMap.stickyStyle[styleStart] == S_WRD or (not bIsHeader and CurMap.stickyStyle[styleBefore] == S_LINEHDR)) then
            return delta, deltaNext, IS_STICKY, lvlPr
        end

        local l2, lvl2, deltaFold2, isCalc
        if deltaFold > 1 then  --конец многократного фолдинга
            l2 = FoldParentLevel(line, lvl)
            lvl2, deltaFold2 = IndLevel(l2)
            --print('b', line, deltaFold)
            if deltaFold2 == - deltaFold then
                delta = (lvl - lvlPr + deltaFold - 1) * editor.Indent
                isCalc = true
            end
        elseif deltaFold < -1 then --начало многократного фолдинга
            l2 = editor:GetLastChild(line, lvl + SC_FOLDLEVELBASE)
            if (((editor.FoldLevel[l2] >> 16) & SC_FOLDLEVELNUMBERMASK - SC_FOLDLEVELBASE) - (editor.FoldLevel[l2] & SC_FOLDLEVELNUMBERMASK - SC_FOLDLEVELBASE)) == deltaFold then
                delta = (lvl - lvlPr) * editor.Indent
                deltaNext = (deltaFold + 1) * editor.Indent
                isCalc = true
            end
            if  bIsHeader and CurMap.stickyStyle[styleBefore] == S_LINEHDR then
                return delta, deltaNext, IS_STICKYHDR, lvlPr
            end
        end

        if not isCalc then delta = (lvl - lvlPr) * editor.Indent end
        if CurMap.correctDelta  then  --[[and indentStyle == IS_NORMAL]]
            local is
            delta, deltaNext, is = CurMap.correctDelta(line, delta, deltaNext)
            indentStyle = is or indentStyle
        end
        return delta, deltaNext, indentStyle, lvl
    end

    local prevInd = 0
    local prevFold = 0
    local prevDelta = 0
    local delta, deltaNext
    local indentStyle, deltaNext0
    for line = lineStart - 1, 0, -1 do
        if line > 0 then
            prevFold = IndLevel(line)
        else
            prevFold = 0
        end
        if editor.LineIndentation[line] < editor:LineLength(line) - EOL_LENGTH then
            delta, deltaNext, indentStyle, prevFold = Delta4LineDEF(line, prevFold)
            if indentStyle == IS_STICKYHDR then
                deltaNext0 = deltaNext
            elseif indentStyle == IS_NORMAL or indentStyle == IS_ABS then
                prevInd = editor.LineIndentation[line] + (deltaNext0 or deltaNext)
                break
            end
        end
    end
--print(lineStart, delta, deltaNext, indentStyle, prevFold, prevInd)

    editor:BeginUndoAction()
    for line = lineStart, lineEnd do
        --print(delta, deltaNext)
        delta, deltaNext, indentStyle, prevFold = Delta4LineDEF(line, prevFold)
        --print(line, delta, deltaNext, indentStyle, prevFold)
        if indentStyle == IS_FIXED then goto cont end

        if indentStyle == IS_STICKY then
            editor.LineIndentation[line] = editor.LineIndentation[line] + prevDelta
            goto cont
        end

        if indentStyle == IS_ABS then indentStyle = IS_NORMAL; prevInd = 0 end

        local curInd = prevInd + delta
     --print(line, delta, deltaNext, indentStyle, prevFold, prevInd, delta)
        if indentStyle == IS_NORMAL then
            prevDelta = curInd - editor.LineIndentation[line]
            editor.LineIndentation[line] = curInd
        elseif indentStyle == IS_ZEROINDENT then
            editor.LineIndentation[line] = 0
        elseif indentStyle == IS_STICKYHDR then
            editor.LineIndentation[line] = editor.LineIndentation[line] + prevDelta
        end
        prevInd = curInd + deltaNext
    ::cont::
    end
    editor:EndUndoAction()
end

local function Style1stWordEvent(pos)
    if CurMap.check1stWrdStyle and CurMap.check1stWrdStyle.check() then
        local s1 = editor:ustyle(pos - 2) --editor.StyleAt[editor.LineIndentPosition[curLine]]
        local tmr = iup.timer{time = 1, action_cb = (function(h)
            local pos = editor.SelectionStart
            h.run = 'NO'
            local s2 = editor:ustyle(pos - 1) --editor.StyleAt[editor.LineIndentPosition[curLine]]
            if s1 ~= s2 and (s1 == CurMap.check1stWrdStyle.style or s2 == CurMap.check1stWrdStyle.style) then
                local _, delta = IndLevel(curLine)
                if delta <= 0 then FormatLinesDEF(curLine, curLine) end
            end

            if CurMap.wordsCaseStyles and CurMap.wordsCaseStyles[s2] then
                local e = editor:WordEndPosition(pos - 2)
                local s = editor:WordStartPosition(e)
                local w = editor:textrange(s, e)
                local w2

                if CurMap.wordsCasePostProcess and CurMap.wordsCasePostProcess(w,nil) then
                    w2 = w
                elseif CurMap.wc_calc and CurMap.wc_calc[w:lower()] then
                    w2 = CurMap.wc_calc[w:lower()]
                    if w == w2 then return end
                else
                    w2 = w:gsub('(.)(.*)', function(a,b) return a:upper()..b:lower() end)
                    if w == w2 then return end
                end
                OnPostCheckCase = function()
                    --[[print(s, editor:WordStartPosition(pos - 1), e, editor:WordEndPosition(editor:WordStartPosition(pos - 1)) )]]
                    OnPostCheckCase = nil
                    if s ~= editor:WordStartPosition(pos - 1) or e ~= editor:WordEndPosition(editor:WordStartPosition(pos - 1)) then return end
                    editor.TargetStart = s
                    editor.TargetEnd = e
                    if CurMap.wordsCasePostProcess and CurMap.wordsCasePostProcess(w,s) then return end
                    editor:ReplaceTarget(w2)
                end
            end
        end)}
        tmr.run = 'YES'
    end
end

AddEventHandler("OnChar", function(char)
    if not CurMap or CurMap.empty or not editor.Focus then return end
    if string.byte(char) == 13 then
        bNewLine = true
        local l = editor:LineFromPosition(editor.SelectionStart)
        if (_G.iuprops['autoformat.indent'] or 0) == 1  then
            BlockEventHandler"OnCurrentLineFold"
            scite.RunAsync(function()
                FormatLinesDEF(l, l, true)
                editor.SelectionStart = editor.LineIndentPosition[l]
                editor.SelectionEnd = editor.LineIndentPosition[l]
                UnBlockEventHandler"OnCurrentLineFold"
            end)
        end
    else
        bNewLine = false
        curLine = editor:LineFromPosition(editor.SelectionStart)
        Style1stWordEvent(editor.SelectionStart)
    end
end)

AddEventHandler("OnAutocSelection", function(method, pos)
    if not CurMap or CurMap.empty then return end
    Style1stWordEvent(pos)
end)

AddEventHandler("Format_Lines", function(s, e)
    if not CurMap or CurMap.empty then return end
    if (_G.iuprops['autoformat.indent'] or 0) ~= 1 or (_G.iuprops['autoformat.on.insert'] or 0) ~= 1  then return end

    local l = editor.FirstVisibleLine
    editor.FirstVisibleLine = e
    editor.FirstVisibleLine = l
    FormatLinesDEF(s, e)
end)

local function IndentBlockUp()
    if (_G.iuprops['autoformat.indent'] or 0) ~= 1  then return end
    local current_pos = editor.CurrentPos
    local cur_line = editor:LineFromPosition(current_pos)
    local curFoldLevel = editor.FoldLevel[cur_line]
    local fromLine = editor:GetLastChild(cur_line, curFoldLevel)
    curFoldLevel = ( curFoldLevel>> 16 ) & SC_FOLDLEVELNUMBERMASK - SC_FOLDLEVELBASE
    local toLine = FoldParentLevel(fromLine, curFoldLevel)

    local l = editor.FirstVisibleLine
    if l ~= fromLine then
        editor.FirstVisibleLine = fromLine
        editor.FirstVisibleLine = l
    end

    FormatLinesDEF(toLine + 1, fromLine)
end

AddEventHandler("OnCurrentLineFold", function(line, foldLevelPrev, foldLevelNow)
    if (_G.iuprops['autoformat.indent.force'] or 1) ~= 1 or (_G.iuprops['autoformat.indent'] or 0) ~= 1 then return end
    if not CurMap or CurMap.empty then return end
    if line == editor:LineFromPosition(editor.SelectionStart) and editor.LineEndPosition[line] > editor.LineIndentPosition[line] then
        if (foldLevelPrev & SC_FOLDLEVELHEADERFLAG == 0 and foldLevelNow & SC_FOLDLEVELHEADERFLAG == 0 and
                foldLevelPrev & SC_FOLDLEVELNUMBERMASK == foldLevelNow & SC_FOLDLEVELNUMBERMASK and
            (foldLevelPrev >> 16) & SC_FOLDLEVELNUMBERMASK ~= (foldLevelNow >> 16) & SC_FOLDLEVELNUMBERMASK) or (
                (foldLevelPrev & SC_FOLDLEVELHEADERFLAG == 0) ~= (foldLevelNow & SC_FOLDLEVELHEADERFLAG == 0) and
                (foldLevelPrev >> 16) & SC_FOLDLEVELNUMBERMASK == (foldLevelNow >> 16) & SC_FOLDLEVELNUMBERMASK and
                foldLevelPrev & SC_FOLDLEVELNUMBERMASK ~= foldLevelNow & SC_FOLDLEVELNUMBERMASK
            )then

            foldLevelNow = ( foldLevelNow >> 16 ) & SC_FOLDLEVELNUMBERMASK - SC_FOLDLEVELBASE
            scite.RunAsync(function()
                FormatLinesDEF(FoldParentLevel(line, foldLevelNow) + 1, line)
            end)
        end
    end
end)
AddEventHandler("Format_Block", function()
    if not CurMap or CurMap.empty then return end
    if editor.SelectionStart == editor.SelectionEnd then IndentBlockUp(); return end
    local ls, le = editor:LineFromPosition(editor.SelectionStart), editor:LineFromPosition(editor.SelectionEnd)
    if ls ~= le then
        local l = editor.FirstVisibleLine
        editor.FirstVisibleLine = math.max(ls, le)
        editor.FirstVisibleLine = l
    end
    FormatLinesDEF(math.min(ls, le), math.max(ls, le))
end)
AddEventHandler("Format_Buffers", function()
    if CORE.Alarm4All(_TM'Format_Buffers') then return end
    DoForBuffers_Stack(function()
        OnSwitchFile_local()
        print(props['FileNameExt'])
        if not CurMap or CurMap.empty then return end
        print(props['FileNameExt'])
        local l = editor.FirstVisibleLine
        editor.FirstVisibleLine = editor.LineCount
        editor.FirstVisibleLine = l
        FormatLinesDEF(1, editor.LineCount)
    end)
end)
