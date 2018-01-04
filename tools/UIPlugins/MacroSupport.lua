local tSet, onDestroy
local function Init_hidden()

    MACRO = {}

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

    local SavedState, MC, pCurBlock, positions_t, lines_t, recordet_macros, started_overtype, macro_list, caret_fore
    local params, params_cnt

    local function nextMC(force)
        if force or MC.typ then
            table.insert(pCurBlock, MC)
            local prevSel = editor.SelectionStart
            local prevSelEnd = editor.SelectionEnd
            local col = editor.Column[prevSelEnd] + editor.SelectionNAnchorVirtualSpace[0]
            MC = {Start = editor.SelectionStart, End = editor.SelectionEnd,
                  Anchor = editor.SelectionNAnchorVirtualSpace[0],
                  Caret = editor.SelectionNCaretVirtualSpace[0]}
        end
    end

    local prevCol
    local function local_OnMacro(typ, fname, w, l, s)
        if not MACRO.Record then return end
        -- print(typ, fname, w, l, s)
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

        nextMC(true)
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
            nextMC()

            newBlock = {typ = 'for', id = #params, pUpper = pCurBlock}
            table.insert(pCurBlock, newBlock)
            pCurBlock = newBlock
        end
    end

    local function do_PasteHist()
        local tItems = {'<Fixed>'}
        local tId = {}
        local pB = pCurBlock
        while pB.pUpper do
            if params[pB.id].typ == 'for' then
                table.insert(tId, pB.id)
                table.insert(tItems, params[pB.id].caption)
            end
            pB = pB.pUpper
        end

        local ret, num, fix, reverce =
        iup.GetParam("Вставка из истории",
            nil,
            'Параметр повтора%l|'..table.concat(tItems, '|')..'|\n'..
            'Фиксированный%i[1,100,1]\n'..
            'Переместить вверх списка%b\n'
            ,
            0, 0, 0
        )
        if ret then
            local id
            if num == 0 then
                id = fix
            else
                id = Iif(reverce == 1, 'par', 'j')..tId[num]
            end

            MACRO.Record = false
            if num == 0 then
                MACRO.ReplaceSel(CLIPHISTORY.GetClip(id, reverce == 1) or "")
            elseif reverce == 1 then
                MACRO.ReplaceSel(CLIPHISTORY.GetClip(params[tId[num]].num, true) or "")
            else
                MACRO.ReplaceSel(CLIPHISTORY.GetClip(1) or "")
            end
            MACRO.Record = true

            nextMC()

            MC.typ = 'L'; MC.fname = 'MACRO.ReplaceSel(CLIPHISTORY.GetClip('..id..', '..Iif(reverce == 1, 'true', 'false')..') or "")'
            nextMC()
        end
    end

    local function ClearSciKeys()
        if CLIPHISTORY then
            editor:ClearCmdKey(string.byte'Y', SCMOD_CTRL)
            editor:ClearCmdKey(string.byte'Z', SCMOD_CTRL)
            editor:ClearCmdKey(string.byte'C', SCMOD_CTRL)
            editor:ClearCmdKey(string.byte'V', SCMOD_CTRL)
            editor:ClearCmdKey(string.byte'X', SCMOD_CTRL)
            editor:ClearCmdKey(SCK_INSERT, SCMOD_CTRL)
            editor:ClearCmdKey(SCK_INSERT, SCMOD_SHIFT)
        end
    end
    local function ReassignSciKeys()
        if CLIPHISTORY then
            editor:AssignCmdKey(string.byte'Y', SCMOD_CTRL, SCI_REDO)
            editor:AssignCmdKey(string.byte'Z', SCMOD_CTRL, SCI_UNDO)
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
            nextMC()

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
            nextMC()

            MACRO.Record = false
            MACRO.ReplaceSel(val)
            MACRO.Record = true

            MC.typ = 'L'; MC.fname = 'MACRO.ReplaceSel(par'..#params..')'
            nextMC()

        end
    end

    local function insert_string(id)
            nextMC()

            local val = params[id].str

            MACRO.Record = false
            MACRO.ReplaceSel(val)
            MACRO.Record = true

            MC.typ = 'L'; MC.fname = 'MACRO.ReplaceSel(par'..id..')'
            nextMC()
    end

    local function insert_iffor_block(id, typ)
        nextMC()

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

        local sOut, sVal = '', ''

        sOut = ''
        for i = 1, #positions_t do
            if i == 1 then
                sOut = sOut..'\nlocal '
            else
                sOut = sOut..', '
                if MACRO.Record then sVal = sVal..', ' end
            end
            sOut = sOut..'column'..i
            if MACRO.Record then sVal = sVal..positions_t[i].pos end
        end
        if MACRO.Record then sOut = sOut..' = '..sVal end

        if MACRO.Record then
            for i = 1,  #params do
                sOut = sOut..'\nlocal par'..i..' = '..params[i].num
            end
        else
            if #params > 0 then
                local strUp = '\nlocal ret'
                local strParams = ''
                local strValues = ''
                for i = 1,  #params do
                    strUp = strUp..', par'..i
                    strParams = strParams..'\n"'..params[i].caption..params[i].suff..'\\n"..'
                    if params[i].typ == 'for' then
                        strValues = strValues..',\n'..params[i].num
                    elseif params[i].typ == 'if' then
                        strValues = strValues..',\n'..params[i].default
                    elseif params[i].typ == 'str' then
                        strValues = strValues..',\n"'..Iif(params[i].default == 1, params[i].str, '')..'"'
                    end

                end
                sOut = sOut..strUp..
                    ' = \niup.GetParam("Параметры макроса", nil,'..strParams..
                    '\n"" '..strValues..")\nif not ret then return end"
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
                    local jStart = 1
                    if MACRO.Record then if pCurBlock == block[i] then jStart = 2 end end
                    sOut = sOut..'\n'..line..'for j'..block[i].id..' = '..jStart..', par'..block[i].id..' do'
                    get_block_script(block[i], nTab + 1)
                    line = line..'end\n'
                elseif block[i].typ == 'if' then
                    sOut = sOut..'\n'..line..'if par'..block[i].id..' == 1 then'
                    get_block_script(block[i], nTab + 1)
                    line = line..'end\n'
                end
                sOut = sOut..'\n'..line
                --sOut = sOut..';'..line
            end
        end

        get_block_script(b, 1)

        return sOut
    end

    local function do_StopBlock()
        nextMC()
        local par = params[pCurBlock.id]

        if par.typ == 'for' and par.num > 1 then
            --par.num = par.num - 1
            local scr = GetBlock({pCurBlock}, num)
            MACRO.Record = false

            local bOk, msg = pcall(dostring, scr)
            if not bOk then
                print(msg, scr)
            end
            MACRO.Record = true
            --par.num = par.num + 1
        end
        pCurBlock = pCurBlock.pUpper
    end

    local function do_Undo()
        if MC.typ then
            if MC.fname == 'ReplaceSel' then
                MC.s = MC.s:gsub('.$', '')
                MACRO.Record = false
                editor:DeleteBack()
                MACRO.Record = true
                if MC.s ~= '' then return end
            end
            if MC.fname == 'NewLine' then
                MACRO.Record = false
                editor:DeleteBack()
                MACRO.Record = true
            end
            editor.SelectionStart = MC.Start
            editor.SelectionEnd = MC.End
            editor.SelectionNAnchorVirtualSpace[0] = MC.Anchor
            editor.SelectionNCaretVirtualSpace[0] = MC.Caret
            if #pCurBlock > 0 then
                MC = pCurBlock[#pCurBlock]
                pCurBlock[#pCurBlock] = nil
            else
                --
            end
        end
    end

    local function GetScript()

        return GetBlock(recordet_macros)
    end

    OnMacroBlockedEvents = function(msg, wParam, lParam)
        if msg == 516 then
            menuhandler:PopUp('MainWindowMenu|Macros')
        end
        if not editor.Focus then iup.PassFocus() end
        return 1
    end

    local function SaveState()

        SavedState = {}
        if true then
            SavedState.bMenuBar = iup.GetDialogChild(iup.GetLayout(), "MenuBar").isOpen()
            SavedState.bToolBar = iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").isOpen()
            SavedState.bStatusBar = iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").isOpen()
            SavedState.bTabBar = iup.GetDialogChild(iup.GetLayout(), "TabbarExpander").state == 'OPEN'
            if SavedState.bMenuBar then iup.GetDialogChild(iup.GetLayout(), "MenuBar").switch() end
            if SavedState.bToolBar then iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").switch() end
            if SavedState.bStatusBar then iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").switch() end
            if SavedState.bTabBar then iup.GetDialogChild(iup.GetLayout(), "TabbarExpander").state = 'CLOSE' end

            if ((_G.iuprops['sidebar.win'] or '0')~= '2') and SideBar_obj.handle then SavedState.SideBar = _G.iuprops['sidebar.win']        end
            if ((_G.iuprops['leftbar.win'] or '0')~= '2') and LeftBar_obj.handle then SavedState.LeftBar = _G.iuprops['leftbar.win']        end
            if (_G.iuprops['concolebar.win'] or '0')~= '2'                       then SavedState.consoleBar =  _G.iuprops['concolebar.win'] end
            if (_G.iuprops['findresbar.win'] or '0')~= '2'                       then SavedState.FindResBar =  _G.iuprops['findresbar.win'] end
            if (_G.iuprops['findrepl.win'] or '0')~= '2'                         then SavedState.FindRepl = _G.iuprops['findrepl.win']      end
            if (_G.iuprops['coeditor.win'] or '0')~= '2'                         then SavedState.Coeditor = _G.iuprops['coeditor.win']      end


            if SavedState.SideBar    then SideBar_obj.handle.detachPos(false)                                end
            if SavedState.LeftBar    then LeftBar_obj.handle.detachPos(false)                                end
            if SavedState.consoleBar then iup.GetDialogChild(iup.GetLayout(), "ConsoleDetach").detachPos(false)  end
            if SavedState.FindRepl   then iup.GetDialogChild(iup.GetLayout(), "FindReplDetach").detachPos(false) end
            if SavedState.FindResBar then iup.GetDialogChild(iup.GetLayout(), "FindResDetach").detachPos(false)  end
            if SavedState.Coeditor   then iup.GetDialogChild(iup.GetLayout(), "SourceExDetach").detachPos(false) end

        end

        started_overtype = editor.Overtype
        caret_fore = editor.CaretFore
        editor.CaretFore = 255
        scite.RegistryHotKeys({})

        BlockEventHandler"OnUpdateUI"
        BlockEventHandler"OnChar"
        BlockEventHandler"OnKey"
        if CLIPHISTORY then BlockEventHandler"OnDrawClipboard" end
        ClearSciKeys()
    end

    local function RestoreState()

        if SavedState.bMenuBar then    iup.GetDialogChild(iup.GetLayout(), "MenuBar").switch()   end
        if SavedState.bToolBar then    iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").switch()   end
        if SavedState.bStatusBar then  iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").switch() end
        if SavedState.bTabBar then     iup.GetDialogChild(iup.GetLayout(), "TabbarExpander").state = 'OPEN' end

        if SavedState.SideBar    then if SavedState.SideBar    == '0' then SideBar_obj.handle.Attach()                                    else SideBar_obj.handle.detachPos(true)                                    end end
        if SavedState.LeftBar    then if SavedState.LeftBar    == '0' then LeftBar_obj.handle.Attach()                                    else LeftBar_obj.handle.detachPos(true)                                    end end
        if SavedState.consoleBar then if SavedState.consoleBar == '0' then iup.GetDialogChild(iup.GetLayout(), "ConsoleDetach").Attach()  else iup.GetDialogChild(iup.GetLayout(), "ConsoleDetach").detachPos(true)  end end
        if SavedState.FindResBar then if SavedState.FindResBar == '0' then iup.GetDialogChild(iup.GetLayout(), "FindResDetach").Attach()  else iup.GetDialogChild(iup.GetLayout(), "FindResDetach").detachPos(true)  end end
        if SavedState.Coeditor   then if SavedState.Coeditor   == '0' then iup.GetDialogChild(iup.GetLayout(), "SourceExDetach").Attach() else iup.GetDialogChild(iup.GetLayout(), "SourceExDetach").detachPos(true) end end
        if SavedState.FindRepl   then if SavedState.FindRepl   == '0' then iup.GetDialogChild(iup.GetLayout(), "FindReplDetach").Attach() else iup.GetDialogChild(iup.GetLayout(), "FindReplDetach").detachPos(true) end end

        editor.Overtype = started_overtype
        editor.CaretFore = caret_fore
        menuhandler:RegistryHotKeys()

        UnBlockEventHandler"OnUpdateUI"
        UnBlockEventHandler"OnChar"
        UnBlockEventHandler"OnKey"
        if CLIPHISTORY then UnBlockEventHandler"OnDrawClipboard" end
        ReassignSciKeys()
    end

    local function StartRecord()

        SaveState()
        MACRO.Record = true
        MC = nil
        params = {}
        params_cnt = 1
        recordet_macros = {}
        pCurBlock = recordet_macros

        positions_t, lines_t = {}, {}

        OnMacro = local_OnMacro
        scite.MenuCommand(IDM_MACRORECORD)

        do_KeepPosition()
    end

    local function StopRecord()
        OnMacro = nil
        scite.MenuCommand(IDM_MACROSTOPRECORD)
        prevCol = nil
        if #recordet_macros == 0 then recordet_macros = nil end
        if MC.typ then table.insert(pCurBlock, MC) end

        RestoreState()
        MACRO.Record = nil

    end

    local function play_scr(scr)
        local cnt = 1
        if not scr:find('iup%.GetParam%("') then
            local ret
            ret, cnt =
            iup.GetParam("Число повторов", nil,
                "Повторить, раз: %i[1,100,1]\n",
            1)
            if not ret then return end
        end
        BlockEventHandler"OnUpdateUI"
        BlockEventHandler"OnChar"
        BlockEventHandler"OnKey"
        local curOverype = editor.Overtype
        editor:BeginUndoAction()
        local bOk, msg
        for i = 1, cnt do
            bOk, msg = pcall(dostring, scr)
            if not bOk then break end
        end
        editor:EndUndoAction()
        editor.Overtype = curOverype
        UnBlockEventHandler"OnUpdateUI"
        UnBlockEventHandler"OnChar"
        UnBlockEventHandler"OnKey"

        if not bOk then
            print(msg, scr)
        end
    end


    local function PlayCurrent()
        play_scr(GetScript())
    end

    local function RunMacroFile(strPath)
        local f = io.open(strPath)
        if f then
            local scr = f:read('*a')
            f:close()
            play_scr(scr)
        end
    end

    function MACRO.PlayMacro(strPath)
        if not strPath:find('%.') then strPath = strPath..'.macro' end
        if not strPath:find('\\') then strPath = props["SciteDefaultHome"].."\\data\\Macros\\"..strPath end
        RunMacroFile(strPath)
    end

    local function SaveCurrent()
        local dir = props["SciteDefaultHome"].."\\data\\Macros\\"
        shell.greateDirectory(dir)
        local d = iup.filedlg{dialogtype = 'SAVE', parentdialog = 'SCITE', extfilter = 'Macros|*.macro;', directory = dir}
        d:popup()
        local filename = d.value
        d:destroy()
        if filename then
            filename = filename:gsub('%.macro$', '')..'.macro'
            local scr = GetScript()
            local f = io.open(filename, "w")
            if f then
                f:write(scr)
                f:flush()
                f:close()
            end
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

    local function get_macro_list()
        if not macro_list then
            local t = shell.findfiles(props["SciteDefaultHome"].."\\data\\Macros\\*.macro")
            macro_list = {}
            local mnu_i
            for i = 1,  #t do
                mnu_i = {t[i].name, action = function() RunMacroFile(props["SciteDefaultHome"]..'\\data\\Macros\\'..t[i].name) end}
                table.insert(macro_list, mnu_i)
            end
            if FILEMAN then
                table.insert(macro_list, {'s2', separator = 1})
                table.insert(macro_list, {'Open Macro Folder', ru = 'Открыть папку с макросами', action = function() FILEMAN.OpenFolder(props["SciteDefaultHome"]..'\\data\\Macros\\') end, image = 'folder_search_result_µ'})
            end
        end
        return macro_list
    end

    local function do_Copy()
        CLIPHISTORY.Copy(1, editor:GetSelText())

        nextMC()

        MC.typ = 'L'; MC.fname = 'CLIPHISTORY.Copy(1, editor:GetSelText())'
        nextMC()
    end
    local function do_Paste()
        MACRO.Record = false
        MACRO.ReplaceSel(CLIPHISTORY.GetClip(1) or "")
        MACRO.Record = true

        nextMC()

        MC.typ = 'L'; MC.fname = 'MACRO.ReplaceSel(CLIPHISTORY.GetClip(1) or "")'
        nextMC()
    end
    local function do_Cut()
        CLIPHISTORY.Copy(1, editor:GetSelText())
        MACRO.Record = false
        MACRO.ReplaceSel('')
        MACRO.Record = true

        nextMC()

        MC.typ = 'L'; MC.fname = 'CLIPHISTORY.Copy(1, editor:GetSelText())'
        nextMC()

        MC.typ = 'L'; MC.fname = 'MACRO.ReplaceSel("")'
        nextMC()
    end
    local function do_FindNextWrd(arg)
        CORE.FindNextWrd(arg)
        nextMC()
        MC.typ = 'L'; MC.fname = 'CORE.FindNextWrd('..arg..')'
        nextMC()
    end
    local function do_Find_FindInDialog(arg)
        CORE.Find_FindInDialog(arg)
        nextMC()
        MC.typ = 'L'; MC.fname = 'CORE.Find_FindInDialog('..Iif(arg, 'true', 'false')..')'
        nextMC()
    end
    local function do_FindNextBack(arg)
        CORE.FindNextBack(arg)
        nextMC()
        MC.typ = 'L'; MC.fname = 'CORE.FindNextBack('..Iif(arg, 'true', 'false')..')'
        nextMC()
    end

    local item = {'Macros', ru = 'Макросы', {
		{'Start Record', ru = 'Начать запись', action = StartRecord, visible = function() return not MACRO.Record and not recordet_macros end, image = "control_record_µ"},
		{'Play Current', ru = 'Воспроизвести текущий', action = PlayCurrent, visible = function() return not MACRO.Record and recordet_macros end, image = "control_µ"},
		{'Delete Current', ru = 'Удалить текущий', action = function() if iup.Alarm("Macros", 'Удалить макрос?', 'Да', 'Нет') == 1 then recordet_macros = nil end end, visible = function() return not MACRO.Record and recordet_macros end, image = "cross_script_µ"},
		{'Save Current', ru = 'Сохранить текущий', action = SaveCurrent, visible = function() return not MACRO.Record and recordet_macros  end, image = "disk_µ" },
		{'View Current', ru = 'Просмотреть текущий', action = function() print(GetScript()) end, visible = function() return not MACRO.Record and recordet_macros  end },
		{'Stop Record', ru = 'Остановить запись', action = StopRecord, visible = function() return MACRO.Record end, image = "control_stop_square_µ" },
        {'s1', separator = 1},
        {'macrolist', plane = 1,  visible = function() return not MACRO.Record end , get_macro_list},
        {'OnRecord', plane = 1, visible = function() return MACRO.Record end, {
            {'Keep Position in line', ru = 'Запомнить позицию в строке', action = do_KeepPosition, image = "marker_µ"},
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
                {'Завершить блок "'..params[pCurBlock.id].caption..'"', action = do_StopBlock, image='control_double_µ'}
            }
        end},
        {'Insert string', ru = 'Вставить строку...', plane = 1, visible = function() return MACRO.Record end, {
            {'Copy', ru = 'Копировать', action = do_Copy, visible = function() return CLIPHISTORY end, image = 'document_copy_µ'},
            {'Cut', ru = 'Вырезать', action = do_Cut, visible = function() return CLIPHISTORY end, image = 'scissors_µ'},
            {'Paste', ru = 'Вставить', action = do_Paste, visible = function() return CLIPHISTORY end, image = 'clipboard_paste_µ'},
            {'Paste from History', ru = 'Вставить из истории клипов', action = do_PasteHist, visible = function() return CLIPHISTORY end, image = "clipboard_list_µ"},
            {'Find &Next', ru = 'Найти далее', action = function() do_FindNextBack(false) end},
            {'Find &Back', ru = 'Найти предыдущее', action = function() do_FindNextBack(true) end},
            {'Find Next Word/Selection', ru = 'Слово/выделение - (через диалог)', action = function() do_Find_FindInDialog(true) end, image = "IMAGE_search" },
            {'Find Prev Word/Selection', ru = 'Предыдущее слово/выделение - (через диалог)', action = function() do_Find_FindInDialog(false) end, image = "IMAGE_search"},
            {'Next Word/Selection', ru = 'Следующее слово/выделение', action = function() do_FindNextWrd(1) end, image = "IMAGE_search"},
            {'Prevous Word/Selection', ru = 'Предыдущее слово/выделение', action = function() do_FindNextWrd(2) end, image = "IMAGE_search"} ,
            {'Undo', ru = 'Отменить', active = function() return MC and (MC.typ == "F" or MC.typ == "P") end, action = do_Undo, image = "arrow_return_270_left_µ"} ,
        }},
    }}
    menuhandler:AddMenu(item)

end
return {
    title = 'Поддержка макросов',
    destroy = onDestroy,
    hidden = Init_hidden,
}
