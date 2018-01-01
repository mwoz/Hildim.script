local tSet, onDestroy
local function Init_hidden()

    MACRO = {}
    function MACRO.Copy()
    end
    function MACRO.Cut()
    end
    function MACRO.Paste()
    end
    function MACRO.RestoreColumn(col)
        local line = editor:LineFromPosition(editor.CurrentPos)
        local lineStart = editor:PositionFromLine(line)
        local ln = editor.LineEndPosition[line] - lineStart
        if ln > col then
            editor:SetSel(lineStart + col, lineStart + col )
        else
            editor:SetSel(lineStart + ln, lineStart + ln)
            editor.SelectionNAnchorVirtualSpace[0] = col - ln
            editor.SelectionNCaretVirtualSpace[0] = col - ln
        end
    end
    function MACRO.ReplaceSel(s)
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

    local SavedState, MC, pCurBlock, positions_t, lines_t, recordet_macros, started_overtype
    local params, params_cnt

    local prevCol
    local function local_OnMacro(typ, fname, w, l, s)
        if not MACRO.Record then return end
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
        --новая функция или сформированная строка
        if CLIPHISTORY and (MC.fname == 'Copy' or MC.fname == 'Paste' or MC.fname == 'Cut') then
            typ = 'P'
        end
        table.insert(pCurBlock, MC)
        MC = {}
        MC.typ = typ; MC.fname = fname; MC.w = w; MC.l = l; MC.s = s; MC.count = 1
    end

    local function do_KeepPosition()
        table.insert(positions_t, {name = 'Position '..(#positions_t + 1), pos = editor.Column[editor.CurrentPos] + editor.SelectionNAnchorVirtualSpace[0]})
        local_OnMacro('L', 'column'..#positions_t..' = editor.Column[editor.CurrentPos] + editor.SelectionNAnchorVirtualSpace[0]')
    end

    local function do_BeginFor()
        local ret, num, cap =
        iup.GetParam("Новый повтор ввода",
            function(h, id)
                if id == iup.GETPARAM_BUTTON1 then
                    local cap = iup.GetParamParam(h, 1).value
                    for i = 1, #params do
                        if params[i].caption == cap then
                            print('Caption "'..cap..'" is already in use')
                            return 0
                        end
                    end
                end
                return 1
            end,
            'Число повторений%i[1,100,1]\n'..
            'Заголовок%s\n'
            ,
            2,
            '<New>'
        )
        if ret then
            table.insert(params, {caption = cap, typ = 'for', suff = '%i[1,100,1]', id = #params + 1, num = num})
            if MC.typ then
                table.insert(pCurBlock, MC)
                MC = {}
            end

            newBlock = {typ = 'for', id = #params, pUpper = pCurBlock}
            table.insert(pCurBlock, newBlock)
            pCurBlock = newBlock
        end
    end

    local function ClearSciKeys()
        if CLIPHISTORY then
            editor:ClearCmdKey(string.byte'C', SCMOD_CTRL)
            editor:ClearCmdKey(string.byte'V', SCMOD_CTRL)
            editor:ClearCmdKey(string.byte'X', SCMOD_CTRL)
            editor:ClearCmdKey(SCK_INSERT, SCMOD_CTRL)
            editor:ClearCmdKey(SCK_INSERT, SCMOD_SHIFT)
        end
    end
    local function ReassignSciKeys()
        if CLIPHISTORY then
            editor:AssignCmdKey(string.byte'C', SCMOD_CTRL, SCI_COPY)
            editor:AssignCmdKey(string.byte'V', SCMOD_CTRL, SCI_PASTE)
            editor:AssignCmdKey(string.byte'X', SCMOD_CTRL, SCI_CUT)
            editor:AssignCmdKey(SCK_INSERT, SCMOD_CTRL    , SCI_COPY)
            editor:AssignCmdKey(SCK_INSERT, SCMOD_SHIFT   , SCI_PASTE)

        end
    end

    local function do_BeginIf()
        local ret, def, cap =
        iup.GetParam("Новое условие",
            function(h, id)
                if id == iup.GETPARAM_BUTTON1 then
                    local cap = iup.GetParamParam(h, 1).value
                    for i = 1, #params do
                        if params[i].caption == cap then
                            print('Caption "'..cap..'" is already in use')
                            return 0
                        end
                    end
                end
                return 1
            end,
            'По умолчанию%b\n'..
            'Заголовок%s\n'
            ,
            0,
            '<New>'
        )
        if ret then
            table.insert(params, {caption = cap, typ = 'if', suff = '%b', id = #params + 1, num = 1, default = def})
            if MC.typ then
                table.insert(pCurBlock, MC)
                MC = {}
            end

            newBlock = {typ = 'if', id = #params, pUpper = pCurBlock}
            table.insert(pCurBlock, newBlock)
            pCurBlock = newBlock
        end
    end

    local function do_NewStringPar()
        local ret, val, def, cap =
        iup.GetParam("Новый строковый параметр",
            function(h, id)
                if id == iup.GETPARAM_BUTTON1 then
                    local cap = iup.GetParamParam(h, 1).value
                    for i = 1, #params do
                        if params[i].caption == cap then
                            print('Caption "'..cap..'" is already in use')
                            return 0
                        end
                    end
                end
                return 1
            end,
            'Значение%s\n'..
            'Использовать по умолчанию%b\n'..
            'Заголовок%s\n'
            ,
            '',
            0,
            '<New>'
        )
        if ret then
            table.insert(params, {caption = cap, typ = 'str', suff = '%s', id = #params + 1, str = val, default = def})
            if MC.typ then
                table.insert(pCurBlock, MC)
                MC = {}
            end

            MACRO.Record = false
            MACRO.ReplaceSel(val)
            MACRO.Record = true

            MC.typ = 'L'; MC.fname = 'MACRO.ReplaceSel(par'..#params..')'
            table.insert(pCurBlock, MC)
            MC = {}

        end
    end

    local function insert_string(id)
            if MC.typ then
                table.insert(pCurBlock, MC)
                MC = {}
            end
            local val = params[id].str

            MACRO.Record = false
            MACRO.ReplaceSel(val)
            MACRO.Record = true

            MC.typ = 'L'; MC.fname = 'MACRO.ReplaceSel(par'..id..')'
            table.insert(pCurBlock, MC)
            MC = {}
    end

    local function insert_iffor_block(id, typ)
        if MC.typ then
            table.insert(pCurBlock, MC)
            MC = {}
        end
        newBlock = {typ = typ, id = id, pUpper = pCurBlock}
        table.insert(pCurBlock, newBlock)
        pCurBlock = newBlock
    end

    local function do_RestoreColumn(p)
        local_OnMacro('P', 'RestoreColumn', 'column'..p)
        MACRO.RestoreColumn(positions_t[p].pos)
    end

    local function submenu_positions()
        local t = {}
        for i = 1, #positions_t do
            table.insert(t, {positions_t[i].name, action = function() do_RestoreColumn(i) end})
        end
        return t
    end

    local function GetBlock(b)

        local sOut = ''

        sOut = 'local overtype = editor.Overtype\r\neditor.Overtype = '..Iif(started_overtype, 'true', 'false')
        for i = 1, #positions_t do
            if i == 1 then
                sOut = sOut..'\r\nlocal '
            else
                sOut = sOut..', '
            end
            sOut = sOut..'column'..i
        end

        if MACRO.Record then
            for i = 1,  #params do
                sOut = sOut..'\r\nlocal par'..i..' = '..params[i].num
            end
        else
            if #params > 0 then
                local strUp = '\r\nlocal ret'
                local strParams = ''
                local strValues = ''
                for i = 1,  #params do
                    strUp = strUp..', par'..i
                    strParams = '\r\n"'..params[i].caption..params[i].suff..'\\n"..'
                    if params[i].typ == 'for' then
                        strValues = strValues..',\r\n'..params[i].num
                    elseif params[i].typ == 'if' then
                        strValues = strValues..',\r\n'..params[i].default
                    elseif params[i].typ == 'str' then
                        strValues = strValues..',\r\n"'..Iif(params[i].default == 1, params[i].str, '')..'"'
                    end

                end
                sOut = sOut..strUp..
                    ' = \r\niup.GetParam("Параметры макроса", nil,'..strParams..
                    '\r\n"" '..strValues..")"
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
                    sOut = sOut..'\r\n'..line..'for j'..block[i].id..' = 1, par'..block[i].id..' do'
                    get_block_script(block[i], nTab + 1)
                    line = line..'end\r\n'
                elseif block[i].typ == 'if' then
                    sOut = sOut..'\r\n'..line..'if par'..block[i].id..' == 1 then'
                    get_block_script(block[i], nTab + 1)
                    line = line..'end\r\n'
                end
                sOut = sOut..'\r\n'..line
                --sOut = sOut..';'..line
            end
        end

        get_block_script(b, 1)

        sOut = sOut..'\r\neditor.Overtype = overtype'
        return sOut
    end

    local function do_StopBlock()
        if MC.typ then
            table.insert(pCurBlock, MC)
            MC = {}
        end
        local par = params[pCurBlock.id]

        if par.typ == 'for' and par.num > 1 then
            par.num = par.num - 1
            local scr = GetBlock({pCurBlock}, num)
            MACRO.Record = false

            local bOk, msg = pcall(dostring, scr)
            if not bOk then
                print(msg, scr)
            end
            MACRO.Record = true
            par.num = par.num + 1
        end
        pCurBlock = pCurBlock.pUpper
    end

    local function GetScript()

        return GetBlock(recordet_macros)
    end

    OnShowMainMenu = function(smnu)
        return MACRO.Record and smnu[1][1] ~= 'MacrosItem'
    end

    OnMacroBlockedEvents = function(msg, wParam, lParam)
        if not editor.Focus then iup.PassFocus() end
        return 1
    end

    local function SaveState()

        SavedState = {}
        if false then
            SavedState.bToolBar = iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").isOpen()
            SavedState.bStatusBar = iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").isOpen()
            SavedState.bTabBar = iup.GetDialogChild(iup.GetLayout(), "TabbarExpander").state == 'OPEN'
            if SavedState.bToolBar then iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").switch() end
            if SavedState.bStatusBar then iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").switch() end
            if SavedState.bTabBar then iup.GetDialogChild(iup.GetLayout(), "TabbarExpander").state = 'CLOSE' end

            SavedState.bSideBar = ((_G.iuprops['sidebar.win'] or '0')~= '2') and SideBar_obj.handle
            SavedState.bLeftBar = ((_G.iuprops['leftbar.win'] or '0')~= '2') and LeftBar_obj.handle
            SavedState.bconsoleBar =  (_G.iuprops['concolebar.win'] or '0')~= '2'
            SavedState.bFindResBar =  (_G.iuprops['findresbar.win'] or '0')~= '2'

            if SavedState.bSideBar then SideBar_obj.handle.detachPos(false); end
            if SavedState.bLeftBar then LefrBar_obj.handle.detachPos(false); end
            if SavedState.bFindRepl then iup.GetDialogChild(iup.GetLayout(), "FindReplDetach").detachPos(false); end
            if SavedState.bconsoleBar then iup.GetDialogChild(iup.GetLayout(), "ConsoleDetach").detachPos(false); end
        end

        scite.RegistryHotKeys({})

        BlockEventHandler"OnUpdateUI"
        BlockEventHandler"OnChar"
        BlockEventHandler"OnKey"
        ClearSciKeys()
    end

    local function RestoreState()

        if SavedState.bToolBar then    iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").switch()   end
        if SavedState.bStatusBar then  iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").switch() end

        if SavedState.bSideBar    then SideBar_obj.handle.Attach() end
        if SavedState.bLeftBar then LefrBar_obj.handle.Attach() end
        if SavedState.bTabBar then iup.GetDialogChild(iup.GetLayout(), "TabbarExpander").state = 'OPEN' end
        if SavedState.bconsoleBar then iup.GetDialogChild(iup.GetLayout(), "ConsoleDetach").Attach() end
        if SavedState.bFindResBar then iup.GetDialogChild(iup.GetLayout(), "FindResDetach").Attach() end

        menuhandler:RegistryHotKeys()

        UnBlockEventHandler"OnUpdateUI"
        UnBlockEventHandler"OnChar"
        UnBlockEventHandler"OnKey"
        ReassignSciKeys()
    end

    local function StartRecord()

        SaveState()
        MACRO.Record = true
        MC = {}
        params = {}
        params_cnt = 1
        recordet_macros = {}
        pCurBlock = recordet_macros

        positions_t, lines_t = {}, {}
        started_overtype = editor.Overtype

        OnMacro = local_OnMacro
        scite.MenuCommand(IDM_MACRORECORD)

        do_KeepPosition()
    end

    local function StopRecord()
        OnMacro = nil
        scite.MenuCommand(IDM_MACROSTOPRECORD)
        prevCol = nil

        if MC.typ then table.insert(pCurBlock, MC) end

        RestoreState()
        MACRO.Record = nil

        print(GetScript())
    end
    local function PlayCurrent()
        BlockEventHandler"OnUpdateUI"
        BlockEventHandler"OnChar"
        BlockEventHandler"OnKey"
        local scr = GetScript()
        local bOk, msg = pcall(dostring, scr)
        UnBlockEventHandler"OnUpdateUI"
        UnBlockEventHandler"OnChar"
        UnBlockEventHandler"OnKey"

        if not bOk then
            print(msg, scr)
        end
    end

    local function for_block_content()
        local t = {}
        for i = 1,  #params do
            if params[i].typ == 'for' then
                table.insert(t, {params[i].caption..'\tраз', action = function() insert_iffor_block(i, "for") end})
            end
        end
        return t
    end

    local function if_block_content()
        local t = {}
        for i = 1,  #params do
            if params[i].typ == 'if' then
                table.insert(t, {params[i].caption, action = function() insert_iffor_block(i, "if") end})
            end
        end
        return t
    end

    local function string_block_content()
        local t = {}
        for i = 1,  #params do
            if params[i].typ == 'str' then
                table.insert(t, {params[i].caption, action = function() insert_string(i) end})
            end
        end
        return t
    end
    local function do_Copy()
        print(345)
    end
    local function do_Paste()
        print(345)
    end
    local function do_Cut()
        print(345)
    end

    local item = {'Macros', ru = 'Макросы', {
		{'MacrosItem',  action = function() end, visible = 'false'},
		{'Start Record', ru = 'Начать запись', action = StartRecord, visible = function() return not MACRO.Record and not recordet_macros end},
		{'Play Current', ru = 'Воспроизвести текущий', action = PlayCurrent, visible = function() return not MACRO.Record and recordet_macros end},
		{'Delete Current', ru = 'Удалить текущий', action = function() if iup.Alarm("Macros", 'Удалить макрос?', 'Да', 'Нет') == 1 then recordet_macros = nil end end, visible = function() return not MACRO.Record and recordet_macros end},
		{'Stop Record', ru = 'Остановить запись', action = StopRecord, visible = function() return MACRO.Record end },
        {'s1', separator = 1},
        {'OnRecord', plane = 1, visible = function() return MACRO.Record end, {
            {'Keep Position in line', ru = 'Запомнить позицию в строке', action = do_KeepPosition},
            {'Restore position', ru = 'Перейти на позицию в строке', visible = function() return #positions_t > 0 end, submenu_positions},
        },},
        {'Insert string', ru = 'Вставить строку...', visible = function() return MACRO.Record end, {
            {'StringList', plane = 1, string_block_content},
            {'New String Parameter', ru = 'Задать новый строковый параметр', action = do_NewStringPar}
        }},
        {'Repeat Next Block', ru = 'Повторить следующий блок...', visible = function() return MACRO.Record end, {
            {'ForList', plane = 1, for_block_content},
            {'New Repeat Parameter', ru = 'Задать новый параметр повторений', action = do_BeginFor}
        }},
        {'Call By Condition...', ru = 'Выполнить при условии...', visible = function() return MACRO.Record end, {
            {'IfList', plane = 1, if_block_content},
            {'New Condition', ru = 'Задать новое условие', action = do_BeginIf}
        }},
        {'StopRecordBlock', plane = 1, visible = function() return MACRO.Record and pCurBlock.id end, function()
            return {
                {'Завершить блок "'..params[pCurBlock.id].caption..'"', action = do_StopBlock}
            }
        end},
        {'Copy', ru = 'Копировать', action = do_Copy, visible = function() return MACRO.Record and CLIPHISTORY end, image = 'document_copy_µ'},
        {'Cut', ru = 'Вырезать', action = do_Cut, visible = function() return MACRO.Record and CLIPHISTORY end, image = 'scissors_µ'},
        {'Paste', ru = 'Вставить', action = do_Paste, visible = function() return MACRO.Record and CLIPHISTORY end, image = 'clipboard_paste_µ'},

    }}
    menuhandler:AddMenu(item)

end
return {
    title = 'Поддержка макросов',
    destroy = onDestroy,
    hidden = Init_hidden,
}
