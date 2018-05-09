local currentItem = 0
local list_navigation
local on_nav_cb, walk_Navigation

local function internal_Init()

    local navigation_blockUpdate = true
    local m_lastLin = -2

    local bToolBar = false

    function navigation_Unblock()
        navigation_blockUpdate = false
    end

    local function OnNavigate(item)
        if navigation_blockUpdate then return end
        if item:find('^_') then return end

        while currentItem > 1 do
            list_navigation.dellin = 0
            currentItem = currentItem - 1
        end
        local path_ = props['FilePath']

        if path_ == '' then return end
        local line_ = editor:LineFromPosition((editor.CurrentPos))

        local _, _, fName = path_:find('([^\\]*)$')
        fName = fName:from_utf8()

        if tonumber(list_navigation.numlin) > 1 then
            if path_:lower() == list_navigation:getcell(1, 5):lower() and math.abs(line_ - tonumber(list_navigation:getcell(1, 4) - 1)) < 1 then return end -- то есть не вносим метки с одинаковыми позициями
        end

        local line_text = editor:GetLine(line_)
        if line_text == nil then line_text = '' end
        line_text = line_text:gsub('^%s+', ''):gsub('%s+', ' ')
        if line_text == '' then
            line_text = ' - empty line - '
        end

        list_navigation.addlin = 0
        list_navigation:setcell(1, 1, line_text)
        list_navigation:setcell(1, 2, fName)
        list_navigation:setcell(1, 3, item)
        list_navigation:setcell(1, 4,(line_ + 1))
        list_navigation:setcell(1, 5, path_)
        m_lastLin = -2
        while tonumber(list_navigation.numlin) > 100 do
            list_navigation.dellin = tonumber(list_navigation.numlin) - 1
        end

        list_navigation.marked = nil
        iup.SetAttributeId2(list_navigation, "MARK", currentItem + 1, 0, "0")
        iup.SetAttributeId2(list_navigation, "MARK", 1, 0, "1")
        list_navigation.redraw = "L1-100"
        currentItem = 1
        if on_nav_cb then on_nav_cb() end
    end

    AddEventHandler("OnScriptReload", function(bSave, t)
        if bSave then
            t.navigation = {}
            for i = 1, list_navigation.numlin do
                t.navigation[i] = {}
                for j = 1, 5 do
                    t.navigation[i][j] = list_navigation:getcell(i, j)
                end
            end
            t.navigation.currentItem = currentItem
        else
            if t.navigation then
                list_navigation.addlin = '0-'..#t.navigation
                for i = 1, #t.navigation do
                    for j = 1, 5 do
                        list_navigation:setcell(i, j, t.navigation[i][j])
                    end
                end
                list_navigation.redraw = 'ALL'
                currentItem = t.navigation.currentItem or Iif(#t.navigation > 0, 1, 0)
            end
        end
    end)

    local function Navigation_Go(item)
        local path = list_navigation:getcell(item, 5)
        if not path then return end
        local lin = tonumber(list_navigation:getcell(item, 4))

        navigation_blockUpdate = true
        if props['FilePath'] ~= path then scite.Open(path) end

        editor:SetSel(editor:PositionFromLine(lin - 1), editor:PositionFromLine(lin))
        iup.PassFocus()
        navigation_blockUpdate = false

        iup.SetAttributeId2(list_navigation, "MARK", currentItem , 0, "0")
        iup.SetAttributeId2(list_navigation, "MARK", item, 0, "1")
        list_navigation.redraw = "L1-100"
        currentItem = item
        if on_nav_cb then on_nav_cb() end
    end

    walk_Navigation = function(bBack)
        local newItem
        if bBack then -- '<'
            if currentItem >= tonumber(list_navigation.numlin) then return end
            newItem = currentItem + 1
        else
            if currentItem == 1 then return end
            newItem = currentItem - 1
        end
        Navigation_Go(newItem)
    end
    --++++++++++++++++++++++

	local list_func_height = tonumber(props['sidebar.list_navigation.height']) or 200


    list_navigation = iup.matrix{name='list_navigation',
        numcol = 5, numcol_visible = 4, cursor = "ARROW", alignment = 'ALEFT', heightdef = 6, markmode = 'LIN', flatscrollbar = "YES" ,
        resizematrix = "YES"  , readonly = "YES"  , markmultiple = "NO" , height0 = 4, expand = "YES", framecolor = iup.GetLayout().txtbgcolor,
        map_cb = (function(h) h.size = "1x1" end), width0 = 0 ,
        rasterwidth1 = 250 , rasterwidth2 = 90 , rasterwidth3 = 50 , rasterwidth4 = 40 , rasterwidth5 = 0,
    }

	list_navigation:setcell(0, 1, "Text")
	list_navigation:setcell(0, 2, "File")
	list_navigation:setcell(0, 3, "Item")
	list_navigation:setcell(0, 4, "Line")

    list_navigation.mousemove_cb = function(_, lin, col)
        if m_lastLin ~= lin then
            m_lastLin = lin
            if list_navigation:getcell(lin, 5) then
                list_navigation.tip = list_navigation:getcell(lin, 1)..'\n\n File: '..list_navigation:getcell(lin, 5)..'\nLine:  '..list_navigation:getcell(lin, 4)
            else
                list_navigation.tip = 'История\n(Alt+<)/(Alt+>) - Назад/Вперед'
            end
        end
    end

    iup.drop_cb_to_list(list_navigation, Navigation_Go)
    menuhandler:InsertItem('MainWindowMenu', 'Search|s1',
        {'Navigation', ru = 'Навигация', plane = 1,{
            {'s_Navigation', separator = 1,},
            {'Navigate Backward', ru = 'Навигация: Назад', action = function() walk_Navigation(true) end, key = 'Alt+<', active = function() return currentItem ~= 0 and currentItem < tonumber(list_navigation.numlin) end, image = 'navigation_180_µ',},
            {'Navigate Forward', ru = 'Навигация: Вперед', action = function() walk_Navigation(false) end, key = 'Alt+>', active = function() return currentItem > 1 end, image = 'navigation_µ',},
        }}
    )
    AddEventHandler("OnMenuCommand", function(msg) if msg == 2316 then OnNavigation("Home") elseif msg == 2318 then OnNavigation("End") end end)
    AddEventHandler("OnNavigation", OnNavigate)
end

local function Tab_Init(h)
    internal_Init()
    AddEventHandler("OnResizeSideBar", function(sciteid)
        if h.navigation.Bar_obj.sciteid == sciteid then
            list_navigation.rasterwidth1 = nil
            list_navigation.fittosize = 'COLUMNS'
        end
    end)
    return {
        handle = iup.backgroundbox{list_navigation, bgcolor = iup.GetLayout().txtbgcolor};
        }

end

local function createDlg()
    local dlg = iup.scitedialog{list_navigation, sciteparent = "SCITE", sciteid = "navigation", dropdown = true, shrink="YES",
                maxbox='NO', minbox='NO', menubox='NO', minsize = '100x200',  bgcolor=iup.GetLayout().txtbgcolor,}
    list_navigation.killfocus_cb = function()
        dlg:hide()
    end
    dlg.resize_cb = function(h)
        list_navigation.rasterwidth1 = nil
        list_navigation.fittosize = 'COLUMNS'
    end
    dlg.show_cb = function(h, state)
        if state == 0 then
            list_navigation.rasterwidth1 = nil
            list_navigation.fittosize = 'COLUMNS'
        end
    end
    menuhandler:InsertItem('MainWindowMenu', 'Search|s1',
        {'Navigation History...', ru = 'История навигации...', action = function() iup.ShowInMouse(dlg) end, key = "Alt+Shift+N"}
    )
    return dlg
end

local function ToolBar_Init(h)
    bToolBar = true
    internal_Init()

    local dlg = createDlg()

    local btnForward = iup.flatbutton{image = 'navigation_180_µ', padding = '4x4', active = 'NO',
        flat_action=function()
            walk_Navigation(true)
        end}
    local btnBackward = iup.flatbutton{image = 'navigation_µ', padding = '4x4', active = 'NO',
        flat_action=(function() walk_Navigation(false) end)}

    on_nav_cb = function()
        btnForward.active = Iif(currentItem ~= 0, 'YES', 'NO')
        btnBackward.active = Iif(currentItem > 1, 'YES', 'NO')
    end

    local box = iup.hbox{
            btnForward,
            iup.flatbutton{title = 'Навигация', flat_action =(function(h)
                local _, _, left, top = h.screenposition:find('(-*%d+),(-*%d+)')
                if iup.GetParent(iup.GetParent(h)).name == 'StatusBar' then
                    local _, _, _, dy = dlg.rastersize:find('(%d*)x(%d*)')
                    top = top - dy
                end
                dlg:showxy(left, top)
            end), },
            btnBackward,
            iup.canvas{ maxsize = 'x18', rastersize = '1x', bgcolor = props['layout.bordercolor'], expand = 'NO', border = 'NO'},
            expand='HORIZONTAL', alignment='ACENTER', margin = '3x',
    };
    return {
        handle = box;
        }
end

local function Hidden_Init(h)
    bToolBar = true
    internal_Init()
    local dlg = createDlg()
end

return {
    title = 'Navigation',
    code = 'navigation',
    sidebar = Tab_Init,
    toolbar = ToolBar_Init,
    statusbar = ToolBar_Init,
    tabhotkey = "Alt+Shift+N",
    hidden = Hidden_Init,
    description = [[Ведет историю ваших перемещений по открытым
файлам и позволяет быстро перемещаться по ней]]
}
