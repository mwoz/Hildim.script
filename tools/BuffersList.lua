local function InitWndDialog()
    local list_windows, showPopUp, editMode, hbTitle, cmb_Sort, curSide
    local bMenuMode = false
    local bToolBar = false
    local fillWindow
    local dlg
    local text = props['CurrentSelection']

    local sX, sY, bMoved, bRecurs
    local function button_cb(h, button, pressed, x, y, status)
        h.value = 0
        if button == 49 then
            bMoved = pressed; sX = x; sY = y
            if bMoved == 0 then
                _G.iuprops['dialogs.bufferslist.xv'] = dlg.x
                _G.iuprops['dialogs.bufferslist.yv'] = dlg.y
            end
        end
    end

    local function motion_cb(h, x, y, status)
        h.value = 1
        if bMoved == 1 and sX and sY and not bRecurs then
            local _, _, wx, wy = dlg.screenposition:find('(%-?%d*),(%-?%d*)')
            local nX, nY = tonumber(wx) + (x - sX), tonumber(wy) + (y - sY)
            bRecurs = true
            if nX ~= wx or nY ~= wy then CORE.old_iup_ShowXY(dlg, nX, nY) end
            bRecurs = false
        end
    end

    local table_bookmarks = {}

    local fillWindow = function(side)
        curSide = side
        list_windows.rasterwidth2 = Iif(side, 0, _G.iuprops['list_buffers.rw2'])
        hbTitle.state = Iif(side, 'CLOSE', 'OPEN')
        local function windowsList()
            local Li, Ri = 0, 0
            local t = {}
            local maxN = scite.buffers.GetCount() - 1
            local hMainLayout = iup.GetLayout()
            for i = 0, maxN do
                if not side or side == scite.buffers.GetBufferSide(i) then
                    local row = {}
                    local _, _, p, n = scite.buffers.NameAt(i):from_utf8():find('(.-)([^\\]*)$')
                    if cmb_Sort.value == '1' then
                        row.order = i
                    elseif cmb_Sort.value == '2' then
                        row.order = n:upper()
                    elseif cmb_Sort.value == '3' then
                        local _, _, ext = n:find('([^%.]*)$')
                        row.order = (ext..n):upper()
                    elseif cmb_Sort.value == '4' then
                        row.order = p:upper()..' '..n:upper()
                    elseif cmb_Sort.value == '5' then
                        row.order = scite.buffers.GetBufferOrder(i)
                    else
                        row.order = -scite.buffers.GetBufferModTime(i)
                    end
                    n = n..Iif(scite.buffers.SavedAt(i), '', '*')

                    row.name = n
                    row.path = p
                    row.side = scite.buffers.GetBufferSide(i)
                    row.num = i
                    if (props['tabctrl.colorized'] or '') == '1' then
                        if scite.buffers.GetBufferSide(i) == 1 then
                            row.bgcolor = iup.GetAttributeId(iup.GetDialogChild(hMainLayout, 'TabCtrlRight'), "TABBACKCOLOR", Ri)
                            Ri = Ri + 1
                        else
                            row.bgcolor = iup.GetAttributeId(iup.GetDialogChild(hMainLayout, 'TabCtrlLeft'), "TABBACKCOLOR", Li)
                            Li = Li + 1
                        end
                        if i == scite.buffers.GetCurrent() then row.active = true end
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
        list_windows.fgcolor = Iif((tonumber(props['tabctrl.colorized']) or 0) == 1, props['tabctrl.forecolor'], props['layout.txtfgcolor'])
        list_windows['fgcolor0:*'] = iup.GetLayout().txtfgcolor
        iup.SetAttribute(list_windows, "ADDLIN", "1-"..#t)
        for i = 1,  #t do
            list_windows:setcell(i, 2, Iif(t[i].side == 0, _T"Main", _T"Additional"))
            list_windows:setcell(i, 3, t[i].name)
            list_windows:setcell(i, 4, t[i].path)
            list_windows:setcell(i, 5, t[i].num)
            list_windows:setcell(i, 6, t[i].side)
            if (tonumber(props['tabctrl.colorized']) or 0) == 1 then
                iup.SetAttribute(list_windows, "BGCOLOR"..i..":*", t[i].bgcolor)
                if t[i].active then
                    iup.SetAttribute(list_windows, "BGCOLOR"..i..":1", props['layout.txtbgcolor'])
                    iup.SetAttribute(list_windows, "FGCOLOR"..i..":1", props['layout.txtfgcolor'])
                end
            end
        end
    end

    list_windows = iup.matrix{ name = 'list_buffers', fgcolor = props["tabctrl.forecolor"],
        numcol = 6, numcol_visible = 4, cursor = "ARROW", alignment = 'ALEFT', heightdef = 6, markmode = 'LIN', flatscrollbar = "VERTICAL" ,
        readonly = "NO"  , markmultiple = "NO" , height0 = 4, expand = "YES", framecolor = "255 255 255", resizematrix = "YES", propagatefocus = 'YES'  ,
        rasterwidth0 = 0 ,
        rasterwidth1 = _G.iuprops['list_buffers.rw1'] or 20,
        rasterwidth2 = _G.iuprops['list_buffers.rw2'] or 20,
        rasterwidth3 = _G.iuprops['list_buffers.rw3'] or 120,
        rasterwidth4 = _G.iuprops['list_buffers.rw4'] or 500,
    rasterwidth5 = 0, rasterwidth6 = 0,}

	list_windows:setcell(0, 1, "")         -- ,size="400x400"
	list_windows:setcell(0, 2, _T"View")
	list_windows:setcell(0, 3, _T"Name")
	list_windows:setcell(0, 4, _T"Path")

    list_windows.colresize_cb = list_windows.FitColumns(4, true)
    list_windows.dropcheck_cb = function(h, lin, col)
        if col == 1 then return iup.CONTINUE else return iup.IGNORE end
    end
    list_windows.edition_cb = function(c, lin, col, mode, update)
        return iup.IGNORE
    end
    local multisheck
    list_windows.keypress_cb = function(h, c, press)
        if c == iup.K_LSHIFT and press==0 then multisheck = nil end
        return iup.MatKeyPressCb(h, c, press)
    end
    list_windows.click_cb = function(h, lin, col, status)
        if iup.isshift(status) and iup.isbutton1(status) and col == 1 and not iup.isdouble(status) then
            if multisheck then
                local up, down
                if multisheck > lin then
                    up = lin + 1
                    down = multisheck
                else
                    up = multisheck
                    down = lin - 1
                end
                local newVal = (iup.GetAttributeId2(h, 'TOGGLEVALUE', multisheck, 1) or '0')
                for i = up, down do
                    iup.SetAttributeId2(h, 'TOGGLEVALUE', i, 1, newVal)
                end
                multisheck = nil
            else
                multisheck = lin
            end
        elseif iup.isdouble(status) and iup.isbutton1(status) and lin > 0 then
            scite.buffers.SetDocumentAt(tonumber(iup.GetAttributeId2(list_windows, '', lin, 5)))
            fillWindow(curSide)
            list_windows.redraw = 'ALL'
        elseif iup.isbutton3(status) and lin > 0 then
            menuhandler:PopUp('MainWindowMenu|_HIDDEN_|Window_bar')
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

    local blockClose
    function CORE.WndBySide(side, h)
        fillWindow(side)
        local _, _, x, y = h.screenposition:find('(-?%d*),(-?%d*)')
        local _, _, w, h = h.rastersize:find('(%d*)x(%d*)')
        local _, _, w2, _ = dlg.rastersize:find('(%d*)x(%d*)')
        blockClose = true;
        scite.RunAsync(function() iup.ShowXY(dlg, x + w - w2, y + h) end) --
    end
    local function createDlg()
        local function MoveSet()
            local t = {}
            for i = 1, tonumber(iup.GetAttribute(list_windows, "NUMLIN")) do
                if iup.GetAttributeId2(list_windows, 'TOGGLEVALUE', i, 1) == '1' then
                    table.insert(t, {i, tonumber(iup.GetAttributeId2(list_windows, '', i, 5))})
                end
            end
            for i = 1, #t do
                scite.buffers.SetDocumentAt(t[i][2])
                scite.MenuCommand(IDM_CHANGETAB)
            end
            fillWindow(curSide)
            list_windows.redraw = 'ALL'
        end


        local function CloseFileSet(t) iup.CloseFilesSet(9132, t, true) end

        function CORE.DoForFileSet(s, f)
            return function()
                blockClose = true
                local tForClose = {}
                for i = 1, tonumber(iup.GetAttribute(list_windows, "NUMLIN")) do
                    tForClose[tonumber(iup.GetAttributeId2(list_windows, '', i, 5))] = ((iup.GetAttributeId2(list_windows, 'TOGGLEVALUE', i, 1) or '0') == s)
                end
                f(tForClose)
                fillWindow(curSide)
                list_windows.redraw = 'ALL'
                iup.SetFocus(list_windows)
                blockClose = nil
            end
        end

        local function OrderTab()

            local tOrder, tI, tV = {}, {}, {}
            for i = 1, tonumber(iup.GetAttribute(list_windows, "NUMLIN")) do
                --tOrder[i - 1] = math.tointeger(list_windows:getcell(i, 5))
                table.insert(tI, math.tointeger(list_windows:getcell(i, 5)))
                table.insert(tV, math.tointeger(list_windows:getcell(i, 5)))
            end

            table.sort(tI)

            for i = 1,  #tI do
                tOrder[tI[i]] = tV[i]
            end
            scite.OrderTab(tOrder)
        end

        local flat_title = iup.flatbutton{title = _T'Windows', name = 'Title', image = 'property_µ', maxsize = 'x20', fontsize = '9', flat = 'YES', border = 'NO', padding = '3x', alignment='ALEFT',
            canfocus='NO', expand = 'HORIZONTAL', size = '100x20', button_cb = button_cb, motion_cb = motion_cb, enterwindow_cb=function() end,
            leavewindow_cb=function() end,}
        hbTitle = iup.expander{iup.hbox{ alignment = 'ACENTER', bgcolor = iup.GetGlobal('DLGBGCOLOR'), name = 'bufferslist_title_hbox', fontsize = iup.GetGlobal("DEFAULTFONTSIZE"), gap = 5,
            flat_title,
            btn_attach,
            iup.flatbutton{image = 'cross_button_µ', tip='Hide', canfocus='NO', flat_action = function() dlg:hide(); _G.iuprops['dialogs.bufferslist.state'] = 0 end},
        }, barsize = 0, state = 'CLOSE', name = 'bufferslist_expander'}
        cmb_Sort = iup.list{name = 'cmb_Sort', dropdown = "YES", size = '70x0',visibleitems=10, expand = 'NO', propagatefocus = 'YES', action = function() fillWindow(curSide) end, tip = _T'List Sorting'}
        iup.SetAttribute(cmb_Sort, 1, _TH"Íåò")
        iup.SetAttribute(cmb_Sort, 2, _T"Name")
        iup.SetAttribute(cmb_Sort, 3, _T"Extension")
        iup.SetAttribute(cmb_Sort, 4, _T"Path")
        iup.SetAttribute(cmb_Sort, 5, _T"Last View")
        iup.SetAttribute(cmb_Sort, 6, _T"Last Modified")
        cmb_Sort.value = _G.iuprops['buffers.sortorder'] or '2'
        dlg = iup.scitedialog{iup.vbox{
            hbTitle,
            iup.backgroundbox{list_windows, bgcolor = iup.GetLayout().txtbgcolor},
            iup.hbox{
                iup.flatbutton{expand = 'NO', padding = '9x', flat_action = CORE.DoForFileSet('1', CloseFileSet), propagatefocus = 'YES', image = 'cross_script_µ', tip = _T"Close All Checked" },
                iup.flatbutton{title = _T"except", expand = 'NO', padding = '9x', fgcolor = props['layout.fgcolor'], flat_action = CORE.DoForFileSet('0', CloseFileSet), propagatefocus = 'YES', image = 'cross_script_µ', tip = _T'Close All NOT Checked'  },
                iup.flatbutton{expand = 'NO', padding = '9x', flat_action = MoveSet, propagatefocus = 'YES', image = 'navigation_µ', tip = _T'Move Checked to Another View' }, cmb_Sort,
                iup.flatbutton{expand = 'NO', padding = '9x', flat_action = OrderTab, propagatefocus = 'YES', image = 'IMAGE_FormRun'},
        scrollbar = 'NO', minsize = 'x35', maxsize = 'x35', expand = "HORIZONTAL", margin = "5x0", gap = "1", alignment='ACENTER'};};
        sciteparent = "SCITE", sciteid = "bufferslist", dropdown = true, shrink = "YES",
        maxbox = 'NO', minbox = 'NO', menubox = 'NO', minsize = '100x200', bgcolor = '255 255 255',
        customframedraw = Iif(props['layout.standard.decoration'] == '1', 'NO', 'YES'), customframecaptionheight = -1, customframedraw_cb = CORE.paneldraw_cb, customframeactivate_cb = CORE.panelactivate_cb(flat_title)}

        menuhandler:InsertItem('MainWindowMenu', '_HIDDEN_|s1',
            {'Window_bar', plane = 1,{
                {"Close Checked", ru = _T"Close All Checked", action = CORE.DoForFileSet('1', CloseFileSet)},
                {"Read Only", ru = _T"Close All NOT Checked", action = CORE.DoForFileSet('0', CloseFileSet)},
                {"Move Checked", ru = _T"Move Checked to Another View", action = MoveSet},
        }})
        dlg.bgcolor = iup.GetLayout().bgcolor
        dlg.txtbgcolor = iup.GetLayout().txtbgcolor
        dlg.txtfgcolor = iup.GetLayout().txtfgcolor
        dlg.borderhlcolor = iup.GetLayout().borderhlcolor
        dlg.hlcolor = iup.GetLayout().hlcolor
        dlg.bordercolor = iup.GetLayout().bordercolor
        dlg.flat = 'YES'
        dlg.resize_cb = function(h)
            list_windows.rasterwidth4 = nil
            list_windows.fittosize = 'COLUMNS'
        end
        dlg.show_cb = function(h, state)
            if state == 0 then
                list_windows.rasterwidth4 = nil
                list_windows.fittosize = 'COLUMNS'
                blockClose = false
            elseif state == 4 then
                _G.iuprops['buffers.sortorder'] = cmb_Sort.value
            end
        end
        dlg.focus_cb = function(h, focus)
            if h.activewindow == 'NO' and not blockClose and hbTitle.state == 'CLOSE' then scite.RunAsync(function() dlg:hide(); _G.iuprops['dialogs.bufferslist.state'] = 0 end)  end
        end
        dlg.k_any = function(h, k)
            if k == iup.K_ESC then h:hide(); _G.iuprops['dialogs.bufferslist.state'] = 0 end
        end
        bIsList = true
        return dlg
    end

    local function OnSwitch_Local()
        if dlg.visible == 'YES' then fillWindow(curSide) end
    end

    AddEventHandler("OnOpen", OnSwitch_Local)
    AddEventHandler("OnSwitchFile", OnSwitch_Local)
    AddEventHandler("OnClose", OnSwitch_Local)
    AddEventHandler("OnCloseFileset", OnSwitch_Local)

    dlg = createDlg()
    CORE.visibleWndDialog = function() return dlg.visible == 'YES' end
    CORE.showWndDialog = function() fillWindow(); iup.ShowXY(dlg, _G.iuprops['dialogs.bufferslist.xv'] or 100, _G.iuprops['dialogs.bufferslist.yv'] or 100); _G.iuprops['dialogs.bufferslist.state'] = 1 end;

    if (_G.iuprops['dialogs.bufferslist.state'] or 0) == 1 then CORE.showWndDialog() end
end

InitWndDialog()
