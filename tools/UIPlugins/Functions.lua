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

    local fnTryGroupName

    local tree_func

    local currentLine = -1
    local currFuncData = -1

    local currentItem = 0
    local lineMap  -- падает дерево на userdata(((
    lineMap = {}

    local table_functions = {}

    local _backjumppos -- store position if jumping
    local line_count = 0
    local layout --имена полей - имена бранчей, значения - true/false, если отсутствует - значит открыто

    if not lanes then
        lanes = require("lanes").configure()
    end

    local linda = lanes.linda()

    layout = {}

    local function Functions_GetNames()
        table_functions = {}
        if editor.Length == 0 then return end
        local val = {}
        linda:send("_Functions", {textAll = editor:GetText(), cmd = 'UPD', lex = props['lexer$'], fileExt = props['FileExt'], funcExt = props['functions.lpeg.'..props['lexer$']]})
    end

    local function LanesLoop()
        --lpeg = l
        --print(mblua.CreateMessage)
        local lpExt = {}
        local Lang2lpeg = {}
        local m__CLASS, fnTryGroupName, table_functions
        do
            lpExt._G = _G
            lpExt.m__CLASS = '~~ROOT'
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

            lpExt.PosToLine = function (pos) return editor:LineFromPosition(pos - 1) end
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

        local function getNames(textAll, lex, fileExt, funcExt)
            lpExt.m__CLASS = '~~ROOT'
            table_functions = {}

            if not Lang2lpeg[lex] or Lang2lpeg[lex] == Lang2lpeg['*'] then
                local strOut = funcExt
                if strOut == '' then
                    lex = fileExt
                    if not Lang2lpeg[lex] then
                        strOut = funcExt
                    else
                        strOut = nil
                    end
                end
                if strOut then
                    if strOut ~= '' then
                        Lang2lpeg[lex] = load(strOut, 'func_lpeg', 't', lpExt)()
                    else
                        Lang2lpeg[lex] = Lang2lpeg['*']
                    end
                end
            end


            local out = Lang2lpeg[lex]




            lpExt.m__CLASS = '~~ROOT'
            table_functions = {}

            local start_code = out.start_code
            local lpegPattern = out.pattern
            fnTryGroupName = out.GroupName or (function(s) return s end)

            local start_code_pos = start_code and textAll:find(start_code) or 0

            m__CLASS = '~~ROOT'
            -- lpegPattern = nil
            table_functions = lpegPattern:match(textAll, start_code_pos + 1) -- 2nd arg is the symbol index to start with

        end

        while true do
            local key, val = linda:receive( 100, "_Functions")
            if val ~= nil then
                if val.cmd == "UPD" then
                    getNames(val.textAll, val.lex, val.fileExt, val.funcExt)
                    linda:send("Functions", {table_functions, fnTryGroupName})
                elseif val.cmd == "EXIT" then
                    break;
                end
            end
        end

    end

    local a = lanes.gen( "package,string", {required = {"lpeg"}}, LanesLoop)()

    onDestroy = function() linda:send("_Functions", {cmd = 'EXIT',}) end

    local function GetFlags (funcitem)
        if not _show_flags then return '' end
        local res = ''
        local add = ''
        local res2 = ''
        for flag, value in pairs(funcitem) do
            if type(flag) == 'string' then
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

    local function GetParams (funcitem)
        if not _show_params then return '' end
        return (funcitem[3] and ' '..funcitem[3]) or ''
    end

    local function fixname (funcitem)
        local flag, flag2 = GetFlags(funcitem)
        return funcitem[1]..(flag2 or '')..GetParams(funcitem), flag
    end

    local function getPath(id)
        if iup.GetAttributeId(tree_func, 'KIND', id) == 'BRANCH' then return '' end
        local id2 = iup.GetAttributeId(tree_func, 'PARENT', id)
        if id2 == nil then return '' end
        return iup.GetAttributeId(tree_func, 'TITLE', id2)..':'..iup.GetAttributeId(tree_func, 'TITLE', id)
    end

    local function Functions_ListFILL()
        local function SortFuncList(a, b)
            if _group_by_flags then --Если установлено, сначала сортируем по флагу
                local fa = fnTryGroupName(GetFlags(a), a[4])
                local fb = fnTryGroupName(GetFlags(b), b[4])
                if fa ~= fb then return fa < fb end
            end
            if _sort == 'order' then
                return a[2] < b[2]
            else
                return a[1]:lower() < b[1]:lower()
            end
        end

        table.sort(table_functions, SortFuncList)

        -- remove duplicates
        for i = #table_functions, 2, -1 do
            if table_functions[i][2] == table_functions[i - 1][2] then
                table.remove (table_functions, i)
            end
        end
        local tbFolders = {}

        local prevFoderFlag = "_NO_FLAG_"
        local cp = editor.CodePage

        lineMap = {}
        local j = 1
        local tbBranches = {}
        tree_func.autoredraw = 'NO'
        tree_func.delnode0 = "CHILDREN"
        tree_func.title0 = props['FileName']
        local rootCount = 0
        --debug_prnArgs(table_functions)
        for i, a in ipairs(table_functions) do
            local t, f = fixname(a)

            local node = {}
            node.leafname = t
            node.imageid = f

            if _group_by_flags then

                if tbFolders[fnTryGroupName(f, a[4])] == nil then
                    j = j + 1
                    tbBranches[#tbBranches + 1] = fnTryGroupName(f, a[4])
                    if fnTryGroupName(f, a[4]) == '~~ROOT' then
                        tbFolders[fnTryGroupName(f, a[4])] = -i + 1
                    else tbFolders[fnTryGroupName(f, a[4])] = #tbBranches end
                end
            else

                iup.SetAttribute(tree_func, 'ADDLEAF'..j - 1, t)
                iup.SetAttribute(tree_func, 'IMAGE'..j, 'IMAGE_'..f)
                lineMap[getPath(j)] = a[2]
            end
            j = j + 1
        end

        if _group_by_flags then
            for i = #tbBranches, 1, -1 do
                if tbBranches[i] ~= '~~ROOT' then
                    iup.SetAttribute(tree_func, 'ADDBRANCH0', tbBranches[i])
                end
            end

            --[[local f2 = 0
        if tbFolders['~~ROOT'] ~= nil then f2 = tbFolders['~~ROOT'] + #table_functions  end]]
            for i, a in ipairs(table_functions) do
                local t, f = fixname(a)
                local node = {}
                node.leafname = t
                node.imageid = f

                local f1 = tbFolders[fnTryGroupName(f, a[4])]

                iup.SetAttribute(tree_func, 'ADDLEAF'..i + f1 - 1, t)
                iup.SetAttribute(tree_func, 'IMAGE'..i + f1, 'IMAGE_'..f)

--[[            if fnTryGroupName(f, a[4]) == '~~ROOT' then
                k = i + f1
            else
                k = i + f1 + f2
            end]]

                lineMap[getPath(i + f1)] = a[2]
            end
        end
        -- Восстановим  лэйаут
        for i = 1, tree_func.count do
            if iup.GetAttribute(tree_func, 'KIND'..i) == 'BRANCH' then
                if layout[iup.GetAttribute(tree_func, 'TITLE'..i)] == 'COLLAPSED' then
                    iup.SetAttribute(tree_func, 'STATE'..i, 'COLLAPSED')
                end
            end
        end
        tree_func.resetscroll = 1
        tree_func.autoredraw = 'YES'
        --сортируем по ордеру, чтобы удобнее искать имя по строке
        table.sort(table_functions, function(a, b) return a[2] < b[2] end)
        currFuncData = -1
    end

    local function Functions_SortByOrder()
        _sort = 'order'
        _G.iuprops['sidebar.functions.sort'] = _sort
        Functions_ListFILL()
    end

    local function Functions_SortByName()
        _sort = 'name'
        _G.iuprops['sidebar.functions.sort'] = _sort
        Functions_ListFILL()
    end

    local function Functions_ToggleParams ()
        _show_params = not _show_params
        _G.iuprops['sidebar.functions.params'] = Iif(_show_params, 1, 0)
        Functions_ListFILL()
    end

    local function Functions_ToggleFlags ()
        _show_flags = not _show_flags
        if not _show_flags then
            _group_by_flags = false
            _G.iuprops['sidebar.functions.flags'] = 0
            _G.iuprops['sidebar.functions.group'] = 1
        else
            _G.iuprops['sidebar.functions.flags'] = 1
        end
        Functions_ListFILL()
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
        local pos = lineMap[getPath(tree_func.value)]
        if pos ~= nil then
            OnNavigation("Func")
            ShowCompactedLine(pos)
            editor:GotoLine(pos)
            OnNavigation("Func-")
        end
        return pos
    end

    -- По имени функции находим строку с ее объявлением (инфа берется из table_functions)
    local function Func2Line(funcname)
        if not next(table_functions) then
            print("table_functions not found!")
            Functions_GetNames()
            return
        end
        for i = 1, #table_functions do
            if funcname == table_functions[i][1] then
                return table_functions[i][2]
            end
        end
    end

    -- Переход на строку с объявлением функции
    local function JumpToFuncDefinition(funcname)
        local line = Func2Line(funcname)
        if line then
            editor:GotoLine(line)
            return true -- обрываем дальнейшую обработку OnDoubleClick (выделение слова и пр.)
        end
    end

    local function OnSwitch(bForce)
        if (bForce ~= 'Y') and (editor.Length > 10^(_G.iuprops['sidebar.functions.maxsize'] or 7)) then
            tree_func.delnode0 = "CHILDREN"
            tree_func.title0 = props['FileName']..' (Autoufill disabled by size)'
            return
        end
        _isXform = props['FileExt']:find('.form')
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
                    for i = 1, tree_func.count - 1 do
                        --if lineMap[i] ~=nil and lineMap[i] > cur_line then
                        local iDx = getPath(i)
                        if lineMap[iDx] ~= nil and lineMap[iDx] ~= '' and lineMap[iDx] >= cur_line then
                            -- в мэпе для всех функций ниже текущей строки изменим значение на сдвиг
                            lineMap[iDx] = lineMap[iDx] + def_line_count
                        end
                    end
                    line_count = line_count_new
                end
            end

            local l = editor:LineFromPosition(editor.SelectionStart)
            if currentLine ~= l then
                currentLine = l
                local i, tb, fData , t,f
                fData = -1
                for i, f in pairs(lineMap) do
                    -- найдем ближайшую сверху функцию к текущей строке (строку, содержащую функцию)
                    if f <= currentLine and f > fData then fData = f end
                end
                if fData ~= currFuncData then
                    -- выяснилось, что с прошлого раза мы переместились в другую функцию
                    if currFuncData > - 1 then
                        iup.SetAttribute(tree_func, "MARK"..currFuncData, "NO")
                    end
                    for i = 0, tree_func.count do
                        local iDx = getPath(i)
                        if lineMap[iDx] == fData then

                            currFuncData = fData
                            tree_func.flat_topitem = i
                            iup.SetAttribute(tree_func, "MARKED"..i, "YES")
                            iup.SetAttribute(tree_func, "COLOR"..i, "0 0 255")
                            if curSelect > - 1 then iup.SetAttribute(tree_func, "COLOR"..curSelect, tree_func.fgcolor);--[[iup.SetAttribute(tree_func, "COLOR"..curSelect, "0 0 0") ]]end
                            curSelect = i
                            tree_func.topitem = "YES"
                            return
                        end
                    end
                    -- мы находимся над первой функцией - пометим корневую папку
                    iup.SetAttribute(tree_func, "MARKED0", "YES")
                    iup.SetAttribute(tree_func, "COLOR0", "0 0 255")
                    iup.SetAttribute(tree_func, "COLOR"..curSelect, tree_func.fgcolor)
                    curSelect = 0
                    currFuncData =- 1
                end
                return
            end
        end
    end

    AddEventHandler("OnLindaNotify", function(key)
        if key == 'Functions' then
            local key, val = linda:receive( 1.0, "Functions")    -- timeout in seconds
            table_functions = val[1]
            fnTryGroupName = val[2]
            Functions_ListFILL()
        end
    end)

    local function OnMySave()
        OnSwitch()
        currentLine = -1
        curSelect = -1
        _OnUpdateUI()
        iup.PassFocus()
    end

    local function Functions_ToggleGroup()
        _group_by_flags = not _group_by_flags
        if _group_by_flags then
            _show_flags = true
            _G.iuprops['sidebar.functions.group'] = 1
            _G.iuprops['sidebar.functions.flags'] = 1
        else
            _G.iuprops['sidebar.functions.group'] = 1
        end

        Functions_GetNames()
    end

    function menu_GoToObjectDefenition()    --TODO!!! - перенести в этот файл создание пункта менб!
        local handled = false
        local strFunc = GetCurrentWord()
        local current_pos = editor.CurrentPos
        editor:SetSel(editor:WordStartPosition(current_pos, true),
        editor:WordEndPosition(current_pos, true))
        if GoToObjectDefenition then
            handled = GoToObjectDefenition(strFunc)
        end
        if not handled then
            OnNavigation("Def")
            handled = JumpToFuncDefinition(strFunc)
            OnNavigation("Def-")
        end
        return handled
    end

    local function _OnDoubleClick(shift, ctrl, alt)
        if shift then
            return menu_GoToObjectDefenition()
        end
    end

    local function SaveLayoutToProp()
        local i, s, prp
        prp = ""
        for i, s in pairs(layout) do
            if s == 'COLLAPSED' then prp = prp..'|'..i end
        end
        _G.iuprops['sidebar.functions.layout'] = prp
    end

    local function Functions_Print()
        for i, v in ipairs(table_functions) do
            if type(v) == 'table' and ( v.Property or v.Function or v.Sub) then
                print(v[4]..' '..v[1]..v[3])
            elseif type(v) == 'table' then
                print(v[1])
            end
        end
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
    local prp = _G.iuprops['sidebar.functions.layout'] or ""
    local w
    for w in string.gmatch(prp, "[^|]+") do
        layout[w] = 'COLLAPSED'
    end
    local line = nil --RGB(73, 163, 83)  RGB(30,180,30)
    tree_func = iup.sc_tree{expand = 'YES', fgcolor = props['layout.txtfgcolor']}
    --Обработку нажатий клавиш производим тут, чтобы вернуть фокус редактору
    tree_func.size = nil
    tree_func.button_cb = function(_, but, pressed, x, y, status)

        if but == 51 and pressed == 0 then --right
            menuhandler:PopUp('MainWindowMenu|_HIDDEN_|Functions_sidebar')
        elseif but == 49 and iup.isdouble(status) then --dbl left
            line = Functions_GotoLine()
        end
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
            {"Display To Console", action = Functions_Print},
            {"Max Size for Auto Show", action = SetMaxSize},
            {"(Max size exceeded) Display", visible = function() return editor.Length > 10^(_G.iuprops['sidebar.functions.maxsize'] or 7) end, action = function() OnSwitch('Y') end}
    }}, "hildim/ui/functions.html", _T)

    tree_func.k_any = function(_, number)
        if number == 13 then
            Functions_GotoLine()
            iup.PassFocus()
        elseif number == iup.K_ESC then
            iup.PassFocus()
        end
    end
    tree_func.flat_branchopen_cb = function(h, number)
        layout[iup.GetAttribute(tree_func, 'TITLE'..number)] = 'EXPANDED'
        SaveLayoutToProp()
    end
    tree_func.flat_branchclose_cb = function(h, number)
        if h.value == '0' then return - 1 end
        layout[iup.GetAttribute(tree_func, 'TITLE'..number)] = 'COLLAPSED'
        SaveLayoutToProp()
    end
    iup.SetAttributeId(tree_func, 'IMAGEEXPANDED', 0, 'tree_µ')
    AddEventHandler("OnClose",
        function() tree_func.delnode0 = "CHILDREN"; tree_func.title0 = ""
    end)

    return {   -- iup.vbox{   };
        handle = iup.flatscrollbox{tree_func, border = 'NO'};
        OnSwitchFile = OnSwitch;
        OnSave = OnMySave;
        OnOpen = OnSwitch;
        OnUpdateUI = _OnUpdateUI;
        OnDoubleClick = _OnDoubleClick;
        on_SelectMe = function() OnSwitch(); iup.SetFocus(tree_func); iup.Flush();end
    }

end

return {
    title = 'Functions',
    code = 'functions',
    sidebar = Func_Init,
    tabhotkey = "Alt+Shift+U",
    destroy = function() onDestroy() end,
    description = [[Дерево функций открытого файла]]
}




