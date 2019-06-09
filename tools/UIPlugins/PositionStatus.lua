
local function Init(h)
    local txtCol, txtLine, txtSel

    local function GoToPos()
        OnNavigation("Go")
        local line = (tonumber(txtLine.value) or 0) - 1
        local col = (tonumber(txtCol.value) or 0) - 1
        local lineStart = editor:PositionFromLine(line)
        editor:EnsureVisibleEnforcePolicy(line)
        local ln = editor:PositionFromLine(line + 1) - 2 - lineStart
        if ln > col then
            editor:SetSel(lineStart + col, lineStart + col )
        else
            editor:SetSel(lineStart + ln, lineStart + ln)
            editor.SelectionNAnchorVirtualSpace[0] = col - ln
            editor.SelectionNCaretVirtualSpace[0] = col - ln
        end
        OnNavigation("Go-")
        iup.PassFocus()
    end
    menuhandler:InsertItem('MainWindowMenu', 'Search|s1',
        {'Go to...', key = 'Ctrl+G', action = IDM_GOTO}
    , "hildim/ui/positionstatus.html", _T)
    AddEventHandler("OnMenuCommand", function(cmd)
        if cmd == IDM_GOTO then
            iup.SetFocus(txtLine)
            txtLine.selectionpos = '0:'..txtLine.value:len()
            return true
        end
    end)

    AddEventHandler("OnUpdateUI", function()
        if not editor.Focus then return end

        txtCol.value = editor.Column[editor.CurrentPos] + editor.SelectionNAnchorVirtualSpace[0] + 1
        txtSel.value = editor.SelectionEnd - editor.SelectionStart
        txtLine.value = editor:LineFromPosition(editor.CurrentPos) + 1
    end)

    txtCol = iup.text{size = '25x'; mask = '[0-9]*', tip = _T'Press Enter to go to position...', killfocus_cb = GoToPos,
    k_any =(function(_, c) if c == iup.K_CR then GoToPos() elseif c == iup.K_ESC then iup.PassFocus() end end)}
    txtLine = iup.text{size = '25x'; mask = '[0-9]*', tip = _T'(Ctrl+G) Press Enter to go to line...', killfocus_cb = GoToPos,
    k_any =(function(_, c) if c == iup.K_CR then iup.PassFocus() end end)}
    txtSel = iup.text{size = '25x'; readonly = 'YES', bgcolor = iup.GetLayout().bgcolor, canfocus = "NO", border = "NO"}

    local function button_cb(_, but, pressed, x, y, status)
        if but == iup.BUTTON1 and pressed == 1 then
            CORE.BottomBarSwitch(Iif(iup.GetDialogChild(iup.GetLayout(), "BottomBarSplit").hidden == "YES", 'NO', "YES"))
        end
    end

    return {
        handle = iup.hbox{
            iup.label{title = _T'Line: '; fontstyle = 'Bold', button_cb = button_cb};
            txtLine;
            iup.label{title = _T'Column: '; fontstyle = 'Bold', button_cb = button_cb};
            txtCol;
            iup.label{title = _T'Selection: '; fontstyle = 'Bold', button_cb = button_cb};
            txtSel; alignment = 'ACENTER', gap = '8';
        };
    }
end

return {
    title = 'Отображение позиции курсора в файле и переход на новую строку',
    code = 'positionstatus',
    statusbar = Init,
}
