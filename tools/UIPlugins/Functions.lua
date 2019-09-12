
local onDestroy
local function Func_Init(h)
    require "lpeg"

    local _isXform = false
    local _show_flags = tonumber(_G.iuprops['sidebar.functions.flags']) == 1
    local _show_params = tonumber(_G.iuprops['sidebar.functions.params']) == 1

    local _group_by_flags = tonumber(_G.iuprops['sidebar.functions.group']) == 1
    local _sort = _G.iuprops['sidebar.functions.sort']
    if _sort == '' then _sort = 'name' end
    local i
    local _Plugins

    local tree_func, txt_live, expd

    local currentLine = -1
    local currFuncId = -1

    local currentItem = 0

    local _backjumppos -- store position if jumping
    local line_count = 0
    local layout --имена полей - имена бранчей, значения - true/false, если отсутствует - значит открыто
 layout = {}
    if not lanes then
        lanes = require("lanes").configure()
    end
    local lane_h
    local linda = lanes.linda()
    local tmr = iup.timer{time = 3000, run = 'NO', action_cb = function(h)
        h.run = 'NO'
        lane_h:cancel()
        print('Canceled Functions Tree Lane ')
        lane_h = nil
    end}
    local mark = CORE.InidcFactory('Function.GoToDef', _T'Link for Go To Definition', INDIC_COMPOSITIONTHICK, 255<<16, 0)

    local function Functions_GetNames()
        if not lane_h then return end
        table_functions = {}
        if editor.Length == 0 then return end
        local val = {}

        linda:send("_Functions", {textAll = editor:GetText(), cmd = 'UPD', lex = props['lexer$'],
            fileExt = props['FileExt'], funcExt = props['functions.lpeg.'..props['lexer$']],
            funcExt2 = props['functions.lpeg.'..props['FileExt']], funcName = props['FileNameExt'],
            grp = _group_by_flags, srt = _sort, shp = _show_params, layout = layout})
        tmr.run = 'NO'
        tmr.run = 'YES'
    end

    local function LanesLoop()

        -- local function debug_prnTb(tb, n)
        --     local s = string.rep('    ', n)
        --     for k, v in pairs(tb) do
        --         if type(v) == 'table' then
        --             print(s..k..'->  Table')
        --             --debug_prnTb(v, n + 1)
        --             if k ~= 'Next' then debug_prnTb(v, n + 1) else print(s..'NextId->'..v.Id) end
        --         else
        --             print(s..k..'->  ', v)
        --         end
        --     end
        -- end

        -- local function debug_prnArgs(...)
        --     print('-------------')
        --     local arg = table.pack(...)
        --     for i = 1, #arg do
        --         if type(arg[i]) == 'table' then
        --             print(i..'->  Table')
        --             debug_prnTb(arg[i], 1)
        --         else
        --             print(i..'->  ', arg[i])
        --         end
        --     end
        -- end

        local lpExt = {}
        local Lang2lpeg = {}
        local fnTryGroupName
        do
            lpExt._G = _G
            lpExt.m__CLASS = '~~ROOT'
            lpExt._isXform = false
            lpExt.print = print
            lpExt._group_by_flags = false
            local P, V, Cg, Ct, Cc, S, R, C, Carg, Cf, Cb, Cp, Cmt = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.S, lpeg.R, lpeg.C, lpeg.Carg, lpeg.Cf, lpeg.Cb, lpeg.Cp, lpeg.Cmt
            lpExt.P, lpExt.V, lpExt.Cg, lpExt.Ct, lpExt.Cc, lpExt.S, lpExt.R, lpExt.C, lpExt.Carg, lpExt.Cf, lpExt.Cb, lpExt.Cp, lpExt.Cmt = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.S, lpeg.R, lpeg.C, lpeg.Carg, lpeg.Cf, lpeg.Cb, lpeg.Cp, lpeg.Cmt
            function lpExt.AnyCase(str)
                local res = P'' --empty pattern to start with
                local ch, CH
                for i = 1, #str do
                    ch = str:sub(i, i):lower()
                    CH = ch:upper()
                    res = res * S(CH..ch)
                end
                assert(res:match(str))
                return res
            end
            --v------- common patterns -------v--
            -- basics
            lpExt.EOF = P(-1)
            lpExt.BOF = P(function(s, i) return (i == 1) and 1 end)
            lpExt.NL = P"\n"-- + P"\f" -- pattern matching newline, platform-specific. \f = page break marker
            lpExt.AZ = R('AZ', 'az') + "_"
            lpExt.N = R'09'
            lpExt.ANY = P(1)
            lpExt.ESCANY = P'\\' * lpExt.ANY + lpExt.ANY
            lpExt.SINGLESPACE = S'\n \t\r\f'
            lpExt.SPACE = lpExt.SINGLESPACE^1

            -- simple tokens
            lpExt.IDENTIFIER = lpExt.AZ * (lpExt.AZ + lpExt.N)^0 -- simple identifier, without separators

            lpExt.Str1 = P'"' * ( lpExt.ESCANY - (S'"' + lpExt.NL) )^0 * (P'"' + lpExt.NL)--NL == error'unfinished string')
            lpExt.Str2 = P"'" * ( lpExt.ESCANY - (S"'" + lpExt.NL) )^0 * (P"'" + lpExt.NL)--NL == error'unfinished string')
            lpExt.STRING = lpExt.Str1 + lpExt.Str2

            -- c-like-comments
            lpExt.line_comment = '//' * (lpExt.ESCANY - lpExt.NL)^0 * lpExt.NL
            lpExt.block_comment = '/*' * (lpExt.ESCANY - P'*/')^0 * (P('*/') + lpExt.EOF)
            lpExt.COMMENT = (lpExt.line_comment + lpExt.block_comment)^1

            lpExt.SC = lpExt.SPACE + lpExt.COMMENT
            lpExt.IGNORED = lpExt.SPACE + lpExt.COMMENT + lpExt.STRING
            -- special captures
            lpExt.cp = Cp() -- pos capture, Carg(1) is the shift value, comes from start_code_pos
            lpExt.cl = lpeg.Cl() -- line capture, uses editor:LineFromPosition
            lpExt.par = C(P"(" *(1 - P")")^0 * P")") -- captures parameters in parentheses

            do --v----- * ------v--
                -- redefine common patterns
                local NL = P"\r\n" + P"\n" + P"\f"
                local SC = S" \t\160" -- без понятия что за символ с кодом 160, но он встречается в SciTEGlobal.properties непосредственно после [Warnings] 10 раз.
                local COMMENT = P'#' *(lpExt.ANY - NL)^0 * NL
                -- define local patterns
                local somedef = S'fFsS' * S'uU' * S'bBnN' * lpExt.AZ^0 --пытаемся поймать что-нибудь, похожее на определение функции...
                local section = P'[' *(lpExt.ANY - P']')^1 * P']'
                -- create flags
                local somedef = Cg(somedef, '')
                -- create additional captures
                local I = C(lpExt.IDENTIFIER) * lpExt.cl
                section = C(section) * lpExt.cl
                local tillNL = C((lpExt.ANY - NL)^0)
                -- definitions to capture:
                local def1 = Ct(somedef * SC^1 * I * SC^0 *(lpExt.par + tillNL))
                local def2 = (NL + lpExt.BOF) * Ct(section * SC^0 * tillNL) * NL

                -- resulting pattern, which does the work
                local patt = (def2 + def1 + COMMENT + lpExt.IDENTIFIER + 1)^0 * lpExt.EOF
                -- local patt = (def2 + def1 + IDENTIFIER + 1)^0 * EOF -- чуть медленнее

                Lang2lpeg['*'] = {pattern = lpeg.Ct(patt)}
            end --^----- * ------^--

        end

        local function getNames(textAll, lex, fileExt, funcExt, funcExt2, tPar)
            lpExt.m__CLASS = '~~ROOT'
            table_functions = {}

            local l = lex
            if funcExt2 == '' then funcExt2 = nil end
            if funcExt2 then l = lex..'.'..fileExt end


            if not Lang2lpeg[l] then
                local strOut = funcExt2 or funcExt or ''

                if strOut ~= '' then
                    Lang2lpeg[l] = load(strOut, 'func_lpeg', 't', lpExt)()
                else
                    Lang2lpeg[l] = Lang2lpeg['*']
                end
            end

            local function GetTypeItem (funcitem)
                local res = ''
                for flag, value in pairs(funcitem) do
                    if type(flag) == 'string' then
                        if type(value) == 'boolean' then
                            if value then
                                res = flag
                                break
                            end
                        end
                    end
                end
                return res
            end

            local function GetFlags (funcitem)
                if not _show_flags then return '' end
                local res = ''
                local add = ''
                local res2 = ''
                for flag, value in pairs(funcitem) do
                    if type(flag) == 'string' and not flag:find('^_') then
                        if type(value) == 'boolean' then	if value then add = flag else res2 = res2..flag; add = '' end
                        elseif type(value) == 'string' then	add = flag .. value
                        elseif type(value) == 'number' then add = flag..':'..value
                        else add = flag end
                        res = res .. add
                    end
                end

                --if res~='' then res = res .. ' ' end
                return (res or ''), res2
            end

            local tblAllUI ={}
            local function prepareTree(tOut, tIn, lay, lMask)
                local isBranch = type(tIn[#tIn]) == 'table'
                if not isBranch and tIn._uiId then
                    tOut.userid = tblAllUI[tIn._uiId]
                else
                    tOut.userid = {}
                end

                local imgId, flag = GetFlags(tIn)
                if type(tIn[2]) == 'number' then tOut.userid.start = tIn[2] end

                if isBranch then
                    local tOutNew
                    tOut._order = tIn._order
                    if lay then  end
                    if type(tIn[1]) == 'string' then
                        if lMask and lMask[tIn[1]] then
                            if not lay then lay = {} end
                            lay[1] = 'COLLAPSED'
                        end
                        if lay and lay[1] == 'COLLAPSED' then tOut.state = 'COLLAPSED' end
                    end
                    for i = 1, #tIn do
                        if type(tIn[i]) == 'table' then
                            tOutNew = {}
                            local tLast
                            local layNew
                            if not lMask and type(tIn[i][1]) == 'string' and lay then
                                layNew = lay[tIn[i][1]]
                            end
                            table.insert(tOut, tOutNew)
                            layNew = prepareTree(tOutNew, tIn[i], layNew, lMask)
                            if lMask and layNew then
                                if not lay then lay = {} end
                                lay[tIn[i][1]] = layNew
                            end
                        end
                    end

                    table.sort(tOut, function(a, b)
                        if (a._order or 0) ~= (b._order or 0) then
                            return (a._order or 0) < (b._order or 0)
                        elseif tPar.srt == 'name' or (not a.userid.start and not b.userid.start) then
                            return (a.leafname or a.branchname):lower() < (b.leafname or b.branchname):lower()
                        else
                            return (a.userid.start or 9999999) < (b.userid.start or 9999999)
                        end
                    end)

                    if type(tIn[2]) == 'number' then
                        --дубль папки - метка в верхней части, по которой можно кликнуть
                        local tt = {}
                        tt.leafname = '^'..tIn[1]..flag
                        tt.image = "IMAGE_"..imgId
                        if tPar.shp and type(tIn[3]) == 'string' then
                            tt.leafname = tt.leafname..' '..tIn[3]
                        end
                        if tIn._uiId then
                            tt.userid = tblAllUI[tIn._uiId]
                        else
                            tt.userid = {}
                        end
                        tt.userid.start = tIn[2]
                        tt.userid._name = tIn[1]
                        table.insert(tOut, 1, tt)
                    end

                else
                    if imgId:find('_$') then
                        tOut.image = imgId..'µ'
                    else
                        tOut.image = "IMAGE_"..imgId
                    end
                end

                if type(tIn[1]) == 'string' then
                    if isBranch then
                        tOut.branchname = tIn[1]
                    else
                        tOut.leafname = (tIn[1]..flag)
                        if tPar.shp and type(tIn[3]) == 'string' then
                            tOut.leafname = tOut.leafname..' '..tIn[3]
                        end
                    end
                end
                if type(tIn[1]) == 'string' then tOut.userid._name = tIn[1] or '' end
                return lay
            end

            local function countFunctions(tblLevel)
                for i = 1,  #tblLevel do
                    if type(tblLevel[i]) == 'table' then
                        if type(tblLevel[i][2]) == 'number' then
                            local tNewUI = {}
                            table.insert(tblAllUI, tNewUI)
                            tblLevel[i]._uiId = #tblAllUI
                            if #tblAllUI > 1 then tblAllUI[#tblAllUI - 1].Next = tNewUI end
                        end
                        countFunctions(tblLevel[i])
                    end
                end
            end

            local iCounter = 1
            local function countTree(tbl)
                for i = 1,  #tbl do
                    if type(tbl[i]) == 'table' then
                        tbl[i].userid.Id = iCounter
                        iCounter = iCounter + 1
                        countTree(tbl[i])
                    end
                end
            end

            local function groupFunctions(tbl)
                local tblFld = {}
                for i = #tbl, 1, -1 do
                    if type(tbl[i]) == 'table' then
                        local fldName = fnTryGroupName(GetTypeItem(tbl[i]), tbl[i][4])
                        if fldName ~= '' and fldName ~= '~~ROOT' then
                            if not tblFld[fldName] then
                                tblFld[fldName] = {}
                                tblFld[fldName]._order = (tbl[i]._order or 0)
                            end
                            table.insert(tblFld[fldName], 1, tbl[i])
                            table.remove(tbl, i)
                        end
                    end
                end

                for i = 1,  #tbl do
                    if type(tbl[i]) == 'table' and type(tbl[i][#(tbl[i])]) == 'table' then
                        groupFunctions(tbl[i])
                    end
                end

                for capt, tIn in pairs(tblFld) do
                    local t = {}
                    t[1] = capt
                    t._order = tIn._order
                    for i = 1, #tIn do
                        table.insert(t, tIn[i])
                    end
                    table.insert(tbl, t)
                end
            end

            local out = Lang2lpeg[l]
            if not out then
                print('Lang2lpeg error!')
                linda:send("Functions", {{}, nil, {}})
                return
            end

            lpExt.m__CLASS = '~~ROOT'
            table_functions = {}

            local start_code = out.start_code

            local lpegPattern = out.pattern
            fnTryGroupName = out.GroupName or (function(s) return s end)

            local start_code_pos = start_code and textAll:find(start_code) or 0

            table_functions = lpegPattern:match(textAll, start_code_pos + 1) or {} -- 2nd arg is the symbol index to start with
            --debug_prnArgs(table_functions)

            countFunctions(table_functions)

            if lpExt._group_by_flags then groupFunctions(table_functions) end --группировка

            --debug_prnArgs(table_functions)
            local tblOut = {}
            tblOut.branchname = tPar.funcName

            local lOut, lMask = tPar.layout
            if not lOut then
                lMask = out.collapsed_branches
                lOut = {}
            end
            --debug_prnArgs(tPar.layout)

            prepareTree(tblOut, table_functions, lOut, lMask)
            tblOut.userid.Next = tblAllUI[1]
            tblOut.userid.Id = 0
            tblOut.userid.start = 0
            countTree(tblOut)

            --debug_prnArgs(lOut)
            linda:send("Functions", {tblOut, lOut, out.options or {}})
            textAll = nil
            tblOut = nil
            collectgarbage("collect")
        end

        while true do
            local key, val = linda:receive( 100, "_Functions")
            if val ~= nil then
                if val.cmd == "UPD" then
                    lpExt._isXform = val.fileExt:lower():find('.form')
                    lpExt._group_by_flags = val.grp
                    getNames(val.textAll, val.lex, val.fileExt, val.funcExt, val.funcExt2, val)
                elseif val.cmd == "EXIT" then
                    break;
                end
            end
        end
    end

    lane_h = lanes.gen( "package,string,table", {required = {"lpeg"}}, LanesLoop)()

    onDestroy = function() linda:send("_Functions", {cmd = 'EXIT',}) end

    local function Functions_ListFILL(table_functions)
        tree_func.autoredraw = 'NO'
        tree_func.delnode0 = "CHILDREN"
        iup.TreeAddNodes(tree_func, table_functions)
        tree_func.resetscroll = 1
        tree_func.autoredraw = 'YES'
    end

    local function Functions_SortByOrder()
        _sort = 'order'
        _G.iuprops['sidebar.functions.sort'] = _sort
        Functions_GetNames()
    end

    local function Functions_SortByName()
        _sort = 'name'
        _G.iuprops['sidebar.functions.sort'] = _sort
        Functions_GetNames()
    end

    local function Functions_ToggleParams ()
        _show_params = not _show_params
        _G.iuprops['sidebar.functions.params'] = Iif(_show_params, 1, 0)
        Functions_GetNames()
    end

    local function ShowCompactedLine(line_num)
        local function GetFoldLine(ln)
            while editor.FoldExpanded[ln] do ln = ln - 1 end
            return ln
        end
        while not editor.LineVisible[line_num] do
            local x = GetFoldLine(line_num)
            editor:ToggleFold(x)
            line_num = x - 1
        end
    end

    local function Functions_GotoLine()
        local t, pos = iup.TreeGetUserId(tree_func, tree_func.value)
        if t then pos = t.start end
        if pos then
            OnNavigation("Func")
            ShowCompactedLine(pos)
            editor:GotoLine(pos)
            OnNavigation("Func-")
        end
        return pos
    end

    -- По имени функции находим строку с ее объявлением (инфа берется из table_functions)
    local function Func2Line(funcname)
        local t = iup.TreeGetUserId(tree_func, 0)
        while t do
            if t._name == funcname then
                return tonumber(t.start)
            end
            t = t.Next
        end
    end

    -- Переход на строку с объявлением функции
    local function JumpToFuncDefinition(funcname, bInfo)
        local line = Func2Line(funcname)
        if line then
            local rFunc = function()
                OnNavigation("Def")
                editor:GotoLine(line)
                OnNavigation("Def-")
            end
            if bInfo then
                return true, rFunc
            end
            rFunc()
            return true
        end
    end

    local function OnSwitch(bForce, bSaveLay)
        if (bForce ~= 'Y') and (editor.Length > 10^(_G.iuprops['sidebar.functions.maxsize'] or 7)) then
            tree_func.delnode0 = "CHILDREN"
            tree_func.title0 = props['FileName']..' (Autoufill disabled by size)'
            return
        end
        if not bSaveLay then layout = nil end
        Functions_GetNames()
        line_count = editor.LineCount
        curSelect = -1
    end

    local curSelect
    curSelect = -1

    local function _OnUpdateUI()
        if _Plugins.functions.Bar_obj.TabCtrl.value_handle.tabtitle == _Plugins.functions.id then
            if editor.Focus then
                local line_count_new = editor.LineCount
                local def_line_count = line_count_new - line_count
                if def_line_count ~= 0 then --С прошлого раза увеличилось количество строк в файле
                    local cur_line = editor:LineFromPosition(editor.CurrentPos)
                    local tUid = iup.TreeGetUserId(tree_func, 0)
                    local startPrev = 0
                    while tUid do
                        if (tUid.start or 0) > cur_line then
                            -- print(tUid.start, def_line_count, startPrev)
                            -- if tUid.start + def_line_count <= startPrev then
                            --     --Functions_GetNames()
                            --     --return
                            -- end
                            break
                        end
                        startPrev = tUid.start
                        tUid = tUid.Next
                    end
                    while tUid do
                        tUid.start = tUid.start + def_line_count
                        tUid = tUid.Next
                    end

                    line_count = line_count_new
                end
            end

            local l = editor:LineFromPosition(editor.SelectionStart)
            if currentLine ~= l then
                local i, tb, fData , t,f
                fData = -1
                local tUid = iup.TreeGetUserId(tree_func, 0)
                local idPrev = 0
                while tUid do
                    if (tUid.start or 0) > l then break end
                    idPrev = tUid.Id
                    tUid = tUid.Next
                end

                if idPrev ~= currFuncId then
                    -- выяснилось, что с прошлого раза мы переместились в другую функцию
                    if currFuncId > - 1 then
                        iup.SetAttributeId(tree_func, "COLOR", currFuncId, "0 0 0")
                    end
                    tree_func.flat_topitem = idPrev
                    iup.SetAttributeId(tree_func, "MARKED", idPrev, "YES")
                    iup.SetAttributeId(tree_func, "COLOR", idPrev, "0 0 255")
                    currFuncId = idPrev
                end
                return
            end
        end
    end

    AddEventHandler("OnLindaNotify", function(key)
        if key == 'Functions' then
            local key, val = linda:receive( 1.0, "Functions")    -- timeout in seconds
            tmr.run = 'NO'
            if val[2] and not layout then layout = val[2] end
            if val[3].toutf8 then
                local function toutf8(t)
                    if t.branchname then t.branchname = t.branchname:to_utf8() end
                    if t.leafname then t.leafname = t.leafname:to_utf8() end
                    for i = 1,  #t do
                        if type(t[i]) == 'table' then
                            toutf8(t[i])
                        end
                    end
                end
                toutf8(val[1])
            end

            Functions_ListFILL(val[1])
            currentLine = -1
            currFuncId = -1
            _OnUpdateUI()
        end
    end)

    local function OnMySave()
        OnSwitch(nil, true)
        currentLine = -1
        curSelect = -1
        _OnUpdateUI()
        --iup.PassFocus()
    end

    local function Functions_ToggleGroup()
        _group_by_flags = not _group_by_flags
        if _group_by_flags then
            _show_flags = true
            _G.iuprops['sidebar.functions.group'] = 1
            _G.iuprops['sidebar.functions.flags'] = 1
        else
            _G.iuprops['sidebar.functions.group'] = 0
        end

        Functions_GetNames()
    end

    function menu_GoToObjectDefenition()
        local handled = false
        local func
        local strFunc = GetCurrentWord()
        local current_pos = editor.CurrentPos
        editor:SetSel(editor:WordStartPosition(current_pos, true),
        editor:WordEndPosition(current_pos, true))
        if GoToObjectDefenition then
            handled, func = GoToObjectDefenition(strFunc)
        end

        if not handled then
            handled, func = JumpToFuncDefinition(strFunc)
        end
        return handled
    end

    local linked_info, linked_set, tmrCtrl, curPosTmr

    local function releaseLink()
        EditorClearMarks(mark)
        editor:CallTipCancel()
        editor.MouseDwellTime = linked_info.period
        linked_info = nil
        editor.Cursor = -1
        --editor.MultipleSelection = true
    end

    local function OnDwell_local(pos, word, ctrl)
        if _G.iuprops["menus.not.ctrlclick"] then return end
        if ctrl ~= 0 and word ~= '' and iup.GetGlobal("MODKEYSTATE") == ' C  ' then
            if linked_info then
                local p = linked_info.word:find(word)
                if not p or pos ~= linked_info.pos + p - 1 then releaseLink() end
                -- if pos~= linked_info.pos or word ~= linked_info.word then releaseLink() end
            else
                local handled, func, p, w
                if GoToObjectDefenition then
                    handled, func, p, w = GoToObjectDefenition(word, true, pos)
                end

                if not handled then
                    handled, func = JumpToFuncDefinition(word, true, pos)
                end
                if func then
                    pos = p or pos; word = w or word
                    EditorMarkText(pos, #word, mark)
                    local ct = _T"Click here for hide link\n(For Add Selection)"
                    if tonumber(props["editor.unicode.mode"]) == IDM_ENCODING_DEFAULT then ct = ct:from_utf8() end
                    editor:CallTipShow(pos, ct)
                    editor.CallTipForeHlt = 0xff0000
                    editor:CallTipSetHlt(1, ct:find('\n'))
                    linked_info = {pos = pos, word = word, period = editor.MouseDwellTime, func = func}
                    editor.MouseDwellTime = linked_info.period / 10
                    editor.Cursor = 8
                end
            end
            tmrCtrl.run = 'NO'

        elseif word == '' and linked_info and ctrl == 0 then
            releaseLink()
            tmrCtrl.run = 'NO'
        end

    end

    tmrCtrl = iup.timer{time = 350, run = 'NO', action_cb =
        function(h)
            h.run = 'NO'
            if iup.GetGlobal('CONTROLKEY') == 'ON' and curPosTmr == iup.GetGlobal('CURSORPOS') then
                local _, _, xC, yC = curPosTmr:find('(%-?%d+)x(%-?%d+)')
                local x, y, ed
                if scite.buffers.GetBufferSide(scite.buffers.GetCurrent()) == 0 then
                    ed = 'Source'
                else
                    ed = 'CoSource'
                end
                _, _, x, y = iup.GetDialogChild(iup.GetLayout(), ed).screenposition:find('(%-?%d+),(%-?%d+)')
                xC = math.tointeger(xC) - math.tointeger(x); yC = math.tointeger(yC) - math.tointeger(y)
                --print(xC,yC)
                local pos = editor:CharPositionFromPointClose(xC, yC)
                OnDwell_local(editor:WordStartPosition(pos, true), GetCurrentWord(editor, pos), true)
            end
        end
    }

    AddEventHandler("OnClick", function(shift, ctrl, alt)
        if linked_info then
            --editor.MultipleSelection = false
            EditorClearMarks(mark)
            editor:CallTipCancel()
            if not linked_info.scip then
                linked_info.func()
                linked_set = {word = linked_info.word, pos = editor.SelectionStart}
            end
        end
    end)

    AddEventHandler("OnCallTipClick", function(pos)
        if linked_info then
            EditorClearMarks(mark)
            editor:CallTipCancel()
            editor.Cursor = -1
            -- editor.MultipleSelection = true
            editor.MouseDwellTime = linked_info.period
            linked_info.scip = true
        end
    end)

    AddEventHandler("OnKey", function(key, shift, ctrl, alt, char)
        if not editor.Focus then return end
        if key == 17 and not shift and not alt and not linked_info and tmrCtrl.run == 'NO' then
            tmrCtrl.run = 'YES'
            curPosTmr = iup.GetGlobal('CURSORPOS')
        elseif alt or shift then
            tmrCtrl.run = 'NO'
        end
    end)

    AddEventHandler("OnMouseButtonUp", function()
        if linked_set then
            scite.RunAsync(function()
                local p = linked_set.pos
                local s = editor:findtext(linked_set.word,0, p, editor:PositionFromLine(editor:LineFromPosition(p) + 1))
                editor.SelectionStart = s or editor.SelectionStart
                if s then
                    editor.SelectionEnd = (s + #(linked_set.word))
                else
                    editor.SelectionEnd = editor.SelectionStart
                end
                linked_set = false
            end)
        end
    end)

    AddEventHandler("OnDwellStart", OnDwell_local)

    local function SaveLayoutToProp()
        do return end
        local i, s, prp
        prp = ""
        for i, s in pairs(layout) do
            if s == 'COLLAPSED' then prp = prp..'|'..i end
        end
        _G.iuprops['sidebar.functions.layout'] = prp
    end

    local function SetMaxSize()
        local ret, sz =
        iup.GetParam("Max Size for Autoufill",
            nil,
            _T'Characters'..' * 10 ^ %r[5,10,0.2]\n'
            ,
            (_G.iuprops['sidebar.functions.maxsize'] or 7)
        )
        if ret then
            _G.iuprops['sidebar.functions.maxsize'] = sz
        end
    end

    -----

    _Plugins = h

    local line = nil --RGB(73, 163, 83)  RGB(30,180,30)
    tree_func = iup.sc_tree{expand = 'YES', fgcolor = props['layout.txtfgcolor']}
    --Обработку нажатий клавиш производим тут, чтобы вернуть фокус редактору
    tree_func.size = nil

    tree_func.rightclick_cb = function(_, id)
        CORE.ScipHidePannel()
        menuhandler:PopUp('MainWindowMenu|_HIDDEN_|Functions_sidebar')
        iup.SetAttributeId(tree_func, "MARKED", id, "YES")
    end

    tree_func.button_cb = function(_, but, pressed, x, y, status)
        if pressed == 0 and line ~= nil then
            iup.PassFocus()
            line = nil
        end
    end
    menuhandler:InsertItem('MainWindowMenu', '_HIDDEN_|s1',
        {'Functions_sidebar', plane = 1,{
            {"Sort By", {radio = 1;
                {'Order', action = Functions_SortByOrder, check = function() return _sort == 'order' end},
                {'Name', action = Functions_SortByName, check = function() return _sort == 'name' end},
            }},
            {"Show Parameters", check = function() return _show_params end, action = Functions_ToggleParams},
            {"Group By Type", check = function() return _group_by_flags end, action = Functions_ToggleGroup},
            {"Max Size for Auto Show", action = SetMaxSize},
            {"(Max size exceeded) Display", visible = function() return editor.Length > 10^(_G.iuprops['sidebar.functions.maxsize'] or 7) end, action = function() OnSwitch('Y') end},
            {'s1', separator=1},
            {"Copy Name to Clipboard", action = function()
                local id = tree_func.markednodes:find('+') - 1;
                local cpb = iup.clipboard{};
                cpb.text = iup.TreeGetUserId(tree_func, id)._name or tree_func.title
                iup.Destroy(cpb)
            end},
    }}, "hildim/ui/functions.html", _T)

    local prevval
    tree_func.k_any = function(_, number)
        if number == iup.K_ESC then
            iup.PassFocus()
        elseif tonumber(number) > 31 and tonumber(number) < 256 and txt_live then
            prevval = tree_func.value
            if expd.state == 'CLOSE' then
                expd.state = 'OPEN'
                iup.SetFocus(txt_live)
                tree_func.flat_topitem = tree_func.value
                iup.SetGlobal('KEY', number)
                iup.RefreshChildren(iup.GetParent(expd))
            end
            return iup.IGNORE
        end
    end

    tree_func.executeleaf_cb = function(h, id)
        Functions_GotoLine()
        if iup.GetGlobal("SHIFTKEY") == "ON" then CORE.ScipHidePannel(2) end
        scite.RunAsync(iup.PassFocus)
    end

    tree_func.flat_selection_cb = function(h, i, state)
        if prevval then
            iup.SetAttributeId(tree_func, "MARKED", prevval, "YES")
            prevval = nil
        end
    end

    local function StoreState(state, number)
        local path = ''
        local t = {}
        repeat
            table.insert(t, 1, iup.GetAttributeId(tree_func, 'TITLE', number))
            number = iup.GetAttributeId(tree_func, 'PARENT', number)
        until number == '0'
        if not layout then layout = {} end
        local l = layout
        for i = 1, #t do
            if not l[t[i]] then l[t[i]] = {} end
            l = l[t[i]]
        end

        l[1] = state
    end
    tree_func.flat_branchopen_cb = function(h, number)
        StoreState('EXPANDED', number)
        SaveLayoutToProp()
    end
    tree_func.flat_branchclose_cb = function(h, number)
        if number == 0 then
            editor:GotoLine(0)
            return iup.IGNORE
        end
        StoreState('COLLAPSED', number)
        SaveLayoutToProp()
    end
    iup.SetAttributeId(tree_func, 'IMAGEEXPANDED', 0, 'tree_µ')
    AddEventHandler("OnClose",
        function() tree_func.delnode0 = "CHILDREN"; tree_func.title0 = ""
    end)
    txt_live = iup.text{size = '25x', expand = 'HORIZONTAL'}
    expd = iup.expander{iup.hbox{txt_live, iup.label{title = 'PgDn-Next'}, iup.label{}, gap = 10, alignment = 'ACENTER'}, barposition = 'BOTTOM', barsize = '0',staterefresh = 'NO', state = 'CLOSE', visible = 'NO'}
    txt_live.killfocus_cb = function(h)
        expd.state = 'CLOSE'
        iup.RefreshChildren(iup.GetParent(expd))
        h.value = ''
    end
    txt_live.action = function(h, c, newvalue, block1st)
        if newvalue == '' then return end
        local v = tonumber(tree_func.value)
        local tUid = iup.TreeGetUserId(tree_func, v)
        local curv = v
        repeat
            if not block1st and tUid._name and tUid._name:upper():find('^'..newvalue:upper()) then
                iup.SetAttributeId(tree_func, "MARKED", curv, "YES")
                tree_func.flat_topitem = curv
                return
            end
            block1st = nil
            tUid = tUid.Next or iup.TreeGetUserId(tree_func, 0)
            curv = tUid.Id
        until curv == v
        return iup.IGNORE
    end
    txt_live.k_any = function(h, k)
        if k == iup.K_ESC then
            iup.PassFocus();
        elseif k == iup.K_CR then
            Functions_GotoLine()
            iup.PassFocus()
        elseif k == iup.K_PGDN then
            h.action(h, 0, h.value, true)
        end
    end

    local bgbox = iup.scrollbox{iup.vbox{expd, iup.flatscrollbox{tree_func, border = 'NO'}}, scrollbar = 'NO', expand = "YES"};;
    return {   -- iup.vbox{   };

        handle = bgbox;
        OnSwitchFile = function() EditorClearMarks(mark)  OnSwitch() end;
        OnSave = OnMySave;
        OnOpen = OnSwitch;
        OnUpdateUI = _OnUpdateUI;
        OnDoubleClick = _OnDoubleClick;
        tabs_OnSelect = function() OnSwitch();scite.RunAsync(function() iup.SetFocus(tree_func) end) end
    }

end

return {
    title = 'Functions',
    code = 'functions',
    sidebar = Func_Init,
    destroy = function() onDestroy() end,
    tabhotkey = "Alt+Shift+U",
    description = [[Дерево функций открытого файла-test]]

}




