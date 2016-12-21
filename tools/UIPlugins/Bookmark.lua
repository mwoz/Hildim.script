local list_bookmarks
local Bookmarks_RefreshTable

local function Init()
    local tab2
    local Abbreviations_USECALLTIPS = tonumber(props['sidebar.abbrev.calltip']) == 1
    local isEditor = false
    local m_lastLin = -2
    local bToolBar = false
    local _Plugins

    ----------------------------------------------------------
    -- tab1:list_bookmarks   Bookmarks
    ----------------------------------------------------------
    local table_bookmarks = {}
    BOOKMARK = {}

    local function GetBufferNumber()
        local buf = props['BufferNumber']
        if buf == '' then buf = 1 else buf = tonumber(buf) end
        return buf
    end

    function BOOKMARK.Add(line_number)
        local line_text = editor:GetLine(line_number)

        if line_text == nil then line_text = '' end
        line_text = line_text:gsub('^%s+', ''):gsub('%s+', ' ')
        if line_text == '' then
            line_text = ' - empty line - ('..(line_number + 1)..')'
        end
        for _, a in ipairs(table_bookmarks) do
            if a.FilePath == props['FilePath'] and a.LineNumber == line_number then
            return end
        end
        local bmk = {}
        bmk.FilePath = props['FilePath']
        bmk.BufferNumber = GetBufferNumber()
        bmk.LineNumber = line_number

        bmk.LineText = line_text
        table_bookmarks[#table_bookmarks + 1] = bmk
    end

    local function Bookmark_Delete(line_number)
        for i = #table_bookmarks, 1, -1 do
            if table_bookmarks[i].FilePath == props['FilePath'] then
                if line_number == nil then
                    table.remove(table_bookmarks, i)
                elseif table_bookmarks[i].LineNumber == line_number then
                    table.remove(table_bookmarks, i)
                    break
                end
            end
        end
    end

    local function Bookmarks_ListFILL()
        table.sort(table_bookmarks, function(a, b)
            return a.BufferNumber < b.BufferNumber or
            a.BufferNumber == b.BufferNumber and
            a.LineNumber < b.LineNumber
        end)
        iup.SetAttribute(list_bookmarks, "DELLIN", "1-"..list_bookmarks.numlin)
        iup.SetAttribute(list_bookmarks, "ADDLIN", "1-"..#table_bookmarks)
        for i, bmk in ipairs(table_bookmarks) do
            list_bookmarks:setcell(i, 1, bmk.BufferNumber)         -- ,size="400x400"
            list_bookmarks:setcell(i, 2, bmk.LineText)
            list_bookmarks:setcell(i, 3, bmk.FilePath)
            list_bookmarks:setcell(i, 4, bmk.LineNumber)
        end
        m_lastLin = -2
        list_bookmarks.redraw = "L1-100"
    end

    function BOOKMARK.SaveReload()
        return table_bookmarks
    end

    local function ResetAll()
        table_bookmarks = {}
        DoForBuffers(function(i)
            local ml = 0
            while true do
                ml = editor:MarkerNext(ml, 2)
                if (ml == -1) then break end
                BOOKMARK.Add(ml)
                ml = ml + 1
            end
        end)
        Bookmarks_ListFILL()
    end

    function BOOKMARK.Restore(bd)
        if bd then
            table_bookmarks = bd
            Bookmarks_ListFILL()
        end
    end

    Bookmarks_RefreshTable = function()
        Bookmark_Delete()
        for i = 0, editor.LineCount do
            if editor:MarkerGet(i) == 2 then
                BOOKMARK.Add(i)
            end
        end
        Bookmarks_ListFILL()
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

    local function Bookmarks_GotoLine(item)
        local path = list_bookmarks:getcell(item, 3)
        if not path then return end
        local lin = tonumber(list_bookmarks:getcell(item, 4))

        --if pos then
		OnNavigation("Bkmk")
		scite.Open(path) -- FilePath
		ShowCompactedLine(lin) -- LineNumber
		editor:GotoLine(lin)
		iup.PassFocus()
		OnNavigation("Bkmk-")
        --end
    end
    local function _OnUpdateUI()
        if _Plugins.bookmark.Bar_obj.ActiveTab == myId then
            if (editor.Focus) then
                local line_count_new = editor.LineCount
                local def_line_count = line_count_new - line_count
                if def_line_count ~= 0 then
                    if tab2:bounds() then -- visible Funk/Bmk
                        Bookmarks_RefreshTable()
                    end
                    line_count = line_count_new
                end
            end
        end
    end

    local function _OnSendEditor(id_msg, wp, lp)
        if id_msg == SCI_MARKERADD then
            if lp == 1 then BOOKMARK.Add(wp) Bookmarks_ListFILL() end
        elseif id_msg == SCI_MARKERDELETE then
            if lp == 1 then Bookmark_Delete(wp) Bookmarks_ListFILL() end
        elseif id_msg == SCI_MARKERDELETEALL then
            if wp == 1 then Bookmark_Delete() Bookmarks_ListFILL() end
        end
    end
    local function _OnClose(file)
        for i = #table_bookmarks, 1, -1 do
            if table_bookmarks[i].FilePath == file then
                table.remove(table_bookmarks, i)
            end
        end
        Bookmarks_ListFILL()
    end
    ----------------------------------------------------------

    local function OnSwitch()
        isEditor = true
        if _Plugins.bookmark.Bar_obj.ActiveTab == myId then
            Abbreviations_ListFILL()
            Bookmarks_ListFILL()
        end
    end

    --local function Init()
    list_bookmarks = iup.matrix{
        numcol = 4, numcol_visible = 2, cursor = "ARROW", alignment = 'ALEFT', heightdef = 6, markmode = 'LIN', scrollbar = "YES" ,
        scrollbar = 'VERTICAL', readonly = "YES"  , markmultiple = "NO" , height0 = 4, expand = "YES", framecolor = "255 255 255",
    rasterwidth0 = 0 , rasterwidth1 = 25 , rasterwidth2 = 25 , rasterwidth3 = 0 , rasterwidth4 = 0 }

	list_bookmarks:setcell(0, 1, "@")         -- ,size="400x400"
	list_bookmarks:setcell(0, 2, "Bookmarks")
	list_bookmarks.click_cb = function(_, lin, col, status)
        if (iup.isdouble(status) or bToolBar) and iup.isbutton1(status) then
            Bookmarks_GotoLine(lin)
        end
    end
	list_bookmarks.map_cb = function(h)
        h.size = "1x1"
    end
    list_bookmarks.mousemove_cb = function(_, lin, col)
        if lin == 0 then return end
        if iup.GetAttributeId2(list_bookmarks, 'MARK', lin, 0) ~= '1' then

            list_bookmarks.marked = nil
            iup.SetAttributeId2(list_bookmarks, 'MARK', lin, 0, 1)
            list_bookmarks.redraw = 'ALL'
        end
        if m_lastLin ~= lin then
            m_lastLin = lin
            if list_bookmarks:getcell(lin, 4) then
                list_bookmarks.tip = list_bookmarks:getcell(lin, 2)..'\n\n File: '..list_bookmarks:getcell(lin, 3)..'\nLine:  '..(tonumber(list_bookmarks:getcell(lin, 4)) + 1)
            else
                list_bookmarks.tip = 'Список букмарков'
            end
        end
    end
    function list_bookmarks:leavewindow_cb()
        -- if blockReselect then return end
        list_bookmarks.marked = nil
        list_bookmarks.redraw = 'ALL'
    end
	list_bookmarks.keypress_cb = function(_, key, press)
        if press == 0 then return end
        if key == iup.K_CR then --enter
            Bookmarks_GotoLine()
        elseif k == iup.K_ESC then
            iup.PassFocus()
        end
	end

    AddEventHandler("OnSendEditor", _OnSendEditor)
    AddEventHandler("OnClose", _OnClose)
    AddEventHandler("OnSave", Bookmarks_RefreshTable)
    AddEventHandler("OnNavigation", function(item)
        if not item:find('%-$') then Bookmarks_RefreshTable() end
    end)

    return Bookmarks_ListFILL
end

local function createDlg()
    local dlg = iup.scitedialog{iup.hbox{list_bookmarks}, sciteparent = "SCITE", sciteid = "bookmarks", dropdown = true,shrink="YES",
                resizematrix='NO'; maxbox = 'NO', minbox = 'NO', menubox = 'NO', minsize = '100x200', bgcolor = '255 255 255';  }
    list_bookmarks.killfocus_cb = function()
        dlg:hide()
    end
    dlg.resize_cb = function(h)
        list_bookmarks.rasterwidth2 = nil
        list_bookmarks.fittosize = 'COLUMNS'
    end
    dlg.show_cb = function(h, state)
        if state == 0 then
            list_bookmarks.rasterwidth2 = nil
            list_bookmarks.fittosize = 'COLUMNS'
        end
    end
    return dlg
end

local function ToolBar_Init(h)
    bToolBar = true
    local onselect = Init()
    local dlg = createDlg()

    local box = iup.hbox{
            iup.flatbutton{title = 'Закладки', flat_action=(function(h)
                local _, _,left, top = h.screenposition:find('(-*%d+),(-*%d+)')
                dlg:showxy(left,top)
            end), padding='5x2',},
            iup.label{separator = "VERTICAL",maxsize='x22', },
            expand='HORIZONTAL', alignment='ACENTER' , margin = '3x',
    };
    h.Tabs.bookmark = {
        handle = box;
        On_SelectMe = onselect
        }
end

local function Tab_Init(h)
    _Plugins = h
    local onselect = Init()
    h.bookmark = {
        handle = list_bookmarks;
        On_SelectMe = onselect
        }

    AddEventHandler("OnResizeSideBar", function(sciteid)
        if h.bookmark.Bar_obj.sciteid == sciteid then
            list_bookmarks.rasterwidth2 = nil
            list_bookmarks.fittosize = 'COLUMNS'
        end
    end)
end

local function Hidden_Init(h)
    bToolBar = true
    Init()
    local dlg = createDlg()
    menuhandler:InsertItem('MainWindowMenu', 'Tools¦s2',
        {'Bookmarks List', ru = 'Список закладок', action = function() Bookmarks_RefreshTable(); iup.ShowInMouse(dlg); end,}
    )
end

return {
    title = 'Bookmarks',
    code = 'bookmark',
    sidebar = Tab_Init,
    toolbar = ToolBar_Init,
    hidden = Hidden_Init,
    tabhotkey = "Alt+Shift+B",
    description = [[Список закладок в открытых файлах]]

}
