-- Version: 1.0
-- Author:
---------------------------------------------------
-- Description:
---------------------------------------------------


local function Init()
    local list_windows, showPopUp, editMode
    local bMenuMode = false
    local bToolBar = false
    local fillWindow
    local dlg
    local text = props['CurrentSelection']
    local curSide
    local myId = "Windows"

    WINDOWS = {}


    local table_bookmarks = {}

    fillWindow = function(side)
        curSide = side
        local function windowsList()
            local Li, Ri = 0, 0
            local t = {}
            local maxN = scite.buffers.GetCount() - 1
            local hMainLayout = iup.GetLayout()
            for i = 0, maxN do
                if not side or side == scite.buffers.GetBufferSide(i) then
                    local row = {}
                    local _, _, p, n = scite.buffers.NameAt(i):from_utf8(1251):find('(.-)([^\\]*)$')
                    row.order = n:upper()
                    n = n..Iif(scite.buffers.SavedAt(i), '', '*')

                    row.name = n
                    row.path = p
                    row.side = scite.buffers.GetBufferSide(i)
                    row.num = i
                    if (_G.iuprops['menus.show.icons'] or 0) == 1 then
                        if scite.buffers.GetBufferSide(i) == 1 then
                            row.bgcolor = iup.GetAttributeId(iup.GetDialogChild(hMainLayout, 'TabCtrlRight'), "TABBACKCOLOR", Ri)
                            Ri = Ri + 1
                        else
                            row.bgcolor = iup.GetAttributeId(iup.GetDialogChild(hMainLayout, 'TabCtrlLeft'), "TABBACKCOLOR", Li)
                            Li = Li + 1
                        end
                    end
                    t[#t + 1] = row
                end
            end
            table.sort(t, function(a, b)
                return a.order < b.order
            end)
            return t
        end
        local t = windowsList()
        iup.SetAttribute(list_windows, "DELLIN", "1-"..list_windows.numlin)
        iup.SetAttribute(list_windows, "ADDLIN", "1-"..#t)
        for i = 1,  #t do
            list_windows:setcell(i, 2, Iif(t[i].side == 0, "Left", "Right"))
            list_windows:setcell(i, 3, t[i].name)
            list_windows:setcell(i, 4, t[i].path)
            list_windows:setcell(i, 5, t[i].num)
            list_windows:setcell(i, 6, t[i].side)
            if (_G.iuprops['menus.show.icons'] or 0) == 1 then
                iup.SetAttribute(list_windows, "BGCOLOR"..i..":*", t[i].bgcolor)
            end
        end
    end

    list_windows = iup.matrix{
        numcol = 6, numcol_visible = 4, cursor = "ARROW", alignment = 'ALEFT', heightdef = 6, markmode = 'LIN', flatscrollbar = "VERTICAL" ,
        readonly = "NO"  , markmultiple = "NO" , height0 = 4, expand = "YES", framecolor = "255 255 255", resizematrix = "YES", propagatefocus = 'YES'  ,
    rasterwidth0 = 0 , rasterwidth1 = 20, rasterwidth2 = 20, rasterwidth3 = 120, rasterwidth4 = 500, rasterwidth5 = 0, rasterwidth6 = 0,}

	list_windows:setcell(0, 1, "")         -- ,size="400x400"
	list_windows:setcell(0, 2, "Side")
	list_windows:setcell(0, 3, "Name")
	list_windows:setcell(0, 4, "Path")

    list_windows.dropcheck_cb = function(h, lin, col)
        if col == 1 then return iup.CONTINUE else return iup.IGNORE end
    end
    list_windows.edition_cb = function(c, lin, col, mode, update)
        return iup.IGNORE
    end
    list_windows.click_cb = function(h, lin, col, status)
        if iup.isdouble(status) and iup.isbutton1(status) then
            scite.buffers.SetDocumentAt(tonumber(iup.GetAttributeId2(list_windows, '', lin, 5)))
        end
    end


    local droppedLin = nil
    local clickPos = ""
    function list_windows:leavewindow_cb()
        if bMenuMode then return end
        list_windows.marked = nil

        list_windows.redraw = 'ALL'
        list_windows.cursor = "ARROW"
        droppedLin = nil;
    end

    function WINDOWS.BySide(side, h)
        fillWindow(side)
        local _, _, x, y = h.screenposition:find('(%d*),(%d*)')
        local _, _, w, h = h.rastersize:find('(%d*)x(%d*)')
        local _, _, w2, _ = dlg.rastersize:find('(%d*)x(%d*)')
        scite.RunAsync(function() iup.ShowXY(dlg, x + w - w2, y + h) end) --
    end
    local function createDlg()
        local function MoveSet()
            for i = 1, tonumber(iup.GetAttribute(list_windows, "NUMLIN")) do
                if iup.GetAttributeId2(list_windows, 'TOGGLEVALUE', i, 1) == '1' then
                    scite.buffers.SetDocumentAt(tonumber(iup.GetAttributeId2(list_windows, '', i, 5)))
                    scite.MenuCommand(IDM_CHANGETAB)
                end
            end
            fillWindow(curSide)
            list_windows.redraw = 'ALL'
        end

        local blockClose
        local function CloseSet()
            blockClose = true
            local tForClose = {}
            for i = 1, tonumber(iup.GetAttribute(list_windows, "NUMLIN")) do
                tForClose[tonumber(iup.GetAttributeId2(list_windows, '', i, 5))] = (iup.GetAttributeId2(list_windows, 'TOGGLEVALUE', i, 1) == '1')
            end
            iup.CloseFilesSet(9132, tForClose)
            fillWindow(curSide)
            list_windows.redraw = 'ALL'
            iup.SetFocus(list_windows)
            blockClose = nil
        end

        dlg = iup.scitedialog{iup.vbox{
            list_windows,
            iup.hbox{
                iup.flatbutton{title = "Close", expand = 'NO', padding = '9x', flat_action = CloseSet, propagatefocus = 'YES' },
                iup.flatbutton{title = "Move...", expand = 'NO', padding = '9x', flat_action = MoveSet, propagatefocus = 'YES'},
                --iup.flatbutton{title = "Cancel", expand = 'NO', padding = '9x', flat_action = function() dlg:hide() end, propagatefocus = 'YES'},
        scrollbar = 'NO', minsize = 'x22', maxsize = 'x22', expand = "HORIZONTAL", margin = "20x", gap = "20"};};
        sciteparent = "SCITE", sciteid = "windows", dropdown = true, shrink = "YES",
        maxbox = 'NO', minbox = 'NO', menubox = 'NO', minsize = '100x200', bgcolor = '255 255 255', customframedraw = 'NO'}

        dlg.resize_cb = function(h)
            list_windows.rasterwidth4 = nil
            list_windows.fittosize = 'COLUMNS'
        end
        dlg.show_cb = function(h, state)
            if state == 0 then
                list_windows.rasterwidth4 = nil
                list_windows.fittosize = 'COLUMNS'
            end
        end
        dlg.focus_cb = function(h, focus)
            if h.activewindow == 'NO' and not blockClose then dlg:hide() end
        end
        menuhandler:InsertItem('MainWindowMenu', 'Buffers¦s3',
            {'Buffers...', ru = 'Вкладки...', action = function() fillWindow(); iup.ShowInMouse(dlg) end, }
        )
        bIsList = true
        return dlg
    end
    return createDlg();
end



local function Tab_Init(h)
    local onselect = Init()
    AddEventHandler("OnResizeSideBar", function(sciteid)
        if h.abbreviations.Bar_obj.sciteid == sciteid then
            list_windows.rasterwidth2 = nil
            list_windows.fittosize = 'COLUMNS'
        end
    end)
    return {
        handle = list_windows;
        on_SelectMe = onselect
        }
end

local function Hidden_Init(h)
    bToolBar = true
    local dlg = Init()
    showPopUp = function() iup.ShowInMouse(dlg) end
end

return {
    title = 'Windows',
    code = 'windows',
--[[    sidebar = Tab_Init,
    toolbar = ToolBar_Init,
    statusbar = ToolBar_Init,]]
    hidden = Hidden_Init,
    tabhotkey = "Alt+Shift+A",
    description = [[Список сокращений. По нажатию горячей клавиши
перед курсором ищется сокращение из списка
и заменяется на соответствующий фрагмент текста]]
}
