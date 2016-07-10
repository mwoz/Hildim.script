local function Init()
    local function Align()
        local nSelection = scite.SendEditor(SCI_GETSELECTIONS)
        local tbl_lines = {}
        local tbl_pos = {}
        local maxPos = 0
        for i = 0, nSelection - 1 do
            local selStart = scite.SendEditor(SCI_GETSELECTIONNSTART, i, i)
            if selStart ~= scite.SendEditor(SCI_GETSELECTIONNEND, i, i) then return end
            local line = editor:LineFromPosition(selStart)
            local posInLine = selStart - editor:PositionFromLine(line)
            if tbl_lines[line] ~= nil then return end
            tbl_lines[line] = posInLine
            table.insert(tbl_pos, line)
            if maxPos < posInLine then maxPos = posInLine end
        end
        -- tbl_pos:sort()
        editor:BeginUndoAction()
        for i = 1, nSelection do
            local line = tbl_pos[i]
            local posInLine = tbl_lines[line]
            local dPos = maxPos - posInLine

            local selStart = editor:PositionFromLine(line) + posInLine
            if dPos > 0 then
                local strIns = ""
                for j = 1, dPos do strIns = strIns.." " end
                editor:InsertText(selStart, strIns)
            end
        end
        editor:EndUndoAction()

        for i = 1, nSelection do
            local line = tbl_pos[i]
            local posInLine = tbl_lines[line]

            local selStart = editor:PositionFromLine(line) + maxPos
            if i == 1 then
                scite.SendEditor(SCI_SETSELECTION, selStart, selStart)
            else
                scite.SendEditor(SCI_ADDSELECTION, selStart, selStart)
            end
        end
    end

    local function TRyAlignByString()
        local dlg = _G.dialogs["align"]
        if dlg == nil then
            local txt_search = iup.text{size = '50x0'}
            local txt_num = iup.text{value = "1", size = "20x0", mask = "/d+"}
            local btn_ok = iup.button  {title = "OK"}
            iup.SetHandle("ALIGN_BTN_OK", btn_ok)

            local btn_esc = iup.button  {title = "Cancel"}
            iup.SetHandle("ALIGN_BTN_ESC", btn_esc)

            local vbox = iup.vbox{ iup.hbox{iup.label{title = "���������:", gap = 3}, txt_search, iup.fill{}, iup.label{title = "�������:"}, txt_num, alignment = 'ACENTER'}, iup.hbox{btn_ok, iup.fill{}, btn_esc}, gap =2,margin="4x4" }
            local result = false
            dlg = iup.scitedialog{vbox; title = "������������", defaultenter = "ALIGN_BTN_OK", defaultesc = "ALIGN_BTN_ESC", maxbox = "NO", minbox = "NO", resize = "NO", sciteparent = "SCITE", sciteid="align" }

            function dlg:show_cb(h, state)
                if state == 0 then
                    txt_search.value = ''
                end
            end

            function btn_ok:action()
                local val = txt_search.value
                local nm = txt_num.value * 1
                local linestart = editor:LineFromPosition(editor.SelectionStart)
                local lineend = editor:LineFromPosition(editor.SelectionEnd)
                if val == ''or lineend == linestart then
                    dlg:hide()
                    return
                end
                local j = 1

                for i = linestart, lineend do
                    local str = editor:GetLine(i)
                    local n = nm
                    local pos = 1
                    while n > 0 do
                        if not str then break end
                        pos = str:find(val:gsub('\\r', '\r'):gsub('\\n', '\n'), pos, 1, true)
                        n = n - 1
                        if pos == nil then break end
                        pos = pos + 1
                    end
                    if pos ~= nil then
                        pos = pos - 2 + editor:PositionFromLine(i)
                        if j == 1 then
                            scite.SendEditor(SCI_SETSELECTION, pos, pos)
                        else
                            scite.SendEditor(SCI_ADDSELECTION, pos, pos)
                        end
                        j = j + 1
                    end
                end
                if j > 2 then result = true end
                Align()
                dlg:hide()
                return IUP_CLOSE
            end

            function btn_esc:action()
                dlg:hide()
            end
        else
            dlg:show()
        end

    end

    function do_Align()
        local nSelection = scite.SendEditor(SCI_GETSELECTIONS)
        if nSelection <= 1 then
            TRyAlignByString()
            return
        end
        Align()
    end

    menuhandler:InsertItem('MainWindowMenu', 'Edit�xxx',
    {'Alignment...', ru = '��������� ������ �� �������...', action = do_Align, key = 'Alt+A', active = 'editor:LineFromPosition(editor.SelectionStart) ~= editor:LineFromPosition(editor.SelectionEnd)', image = 'edit_column_�'})

end
return {
    title = '������������ ����� �� �������',
    hidden = Init,
}
