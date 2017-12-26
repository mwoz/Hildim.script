local function InitIndicDialog()
    local list_indic, showPopUp, editMode, hbTitle
    local bMenuMode = false
    local bToolBar = false
    local fillWindow
    local dlg
    local cur_lin = -1
    local text = props['CurrentSelection']
    --local ttt = {[INDIC_PLAIN]  = 'rr'}
    local value2string = {
        [INDIC_BOX] = 'BOX'     ,
        [INDIC_COMPOSITIONTHICK] = 'COMPOSITIONTHICK',
        [INDIC_COMPOSITIONTHIN] = 'COMPOSITIONTHIN',
        [INDIC_DASH] = 'DASH',
        [INDIC_DIAGONAL] = 'DIAGONAL',
        [INDIC_DOTBOX] = 'DOTBOX',
        [INDIC_DOTS] = 'DOTS',
        [INDIC_FULLBOX] = 'FULLBOX',
        [INDIC_HIDDEN] = 'HIDDEN'  ,
        [INDIC_PLAIN] = 'PLAIN'   ,
        [INDIC_POINTCHARACTER] = 'POINTCHARACTER',
        [INDIC_POINT] = 'POINT',
        [INDIC_ROUNDBOX] = 'ROUNDBOX',
        [INDIC_SQUIGGLELOW] = 'SQUIGGLELOW',
        [INDIC_SQUIGGLEPIXMAP] = 'SQUIGGLEPIXMAP',
        [INDIC_SQUIGGLE] = 'SQUIGGLE',
        [INDIC_STRAIGHTBOX] = 'STRAIGHTBOX',
        [INDIC_STRIKE] = 'STRIKE'  ,
        [INDIC_TEXTFORE] = 'TEXTFORE',
        [INDIC_TT] = 'TT'      ,

    }
    local sX, sY, bMoved, bRecurs

    local function rgb2HStr(rgb)
        local function v2s(v)
            return string.format ('%02x', v)
        end
        return '#'..v2s(rgb & 255)..v2s((rgb >> 8) & 255)..v2s((rgb >> 16) & 255)
    end

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

    local c_clr = iup.colorbrowser{
        bgcolor = "255 255 255",
        rastersize = "181x181",
        border = "NO",
        name = "colour"
    }
    function c_clr:valuechanged_cb()
        local rgb = CORE.Str2Rgb(c_clr.rgb, 0)
        list_indic:setcell(cur_lin, 2, rgb2HStr(rgb))
        list_indic:setcell(cur_lin, 6, rgb)
        list_indic.redraw = cur_lin..'x2'
    end

    local c_lbl = iup.label{expand = 'HORIZONTAL'}

    local c_alfa = iup.text{ spin = 'YES', spinmin = 0, spinmax = 255, mask = '^/d/d?/d?'}

    function c_alfa:valuechanged_cb()
        if math.tointeger(c_alfa.value) > math.tointeger(c_alfa.spinvalue) then c_alfa.value = c_alfa.spinvalue end
        list_indic:setcell(cur_lin, 3, math.tointeger(c_alfa.spinvalue))
        list_indic.redraw = cur_lin..'x3'
    end

    c_style = iup.list{dropdown = "YES", visibleitems = "25", size = '60x0'}
    local i = 1
    for _, v in pairs(value2string) do
        c_style[i] = v
        i = i + 1
    end
    function c_style:valuechanged_cb()
        list_indic:setcell(cur_lin, 4, c_style.valuestring)
        list_indic.redraw = cur_lin..'x4'
        for i, v in pairs(value2string) do
            if c_style.valuestring == v then
                list_indic:setcell(cur_lin, 7, i)
            end
        end
    end

    list_indic = iup.matrix{
        numcol = 8,numcol_visible = 0, cursor = "ARROW", alignment = 'ALEFT', heightdef = 6, markmode = 'LIN', flatscrollbar = "VERTICAL" ,
        readonly = "NO"  , markmultiple = "NO" , height0 = 4, expand = "YES", framecolor = "255 255 255", resizematrix = "YES", propagatefocus = 'YES'  ,
        rasterwidth0 = 0 ,
        rasterwidth1 = 300,
        rasterwidth2 = 40,
        rasterwidth3 = 100,
        rasterwidth4 = 115,
    rasterwidth5 = 0, rasterwidth6 = 0, rasterwidth7 = 0,}
    iup.SetAttribute(list_indic, "TYPE*:2", "COLOR")

	list_indic:setcell(0, 1, "Индикатор")         -- ,size="400x400"
	list_indic:setcell(0, 2, "Цвет")
	list_indic:setcell(0, 3, "Прозрачность")
	list_indic:setcell(0, 4, "Стиль")

    local droppedLin = nil
    local clickPos = ""
    function list_indic:leavewindow_cb()
        if bMenuMode then return end
        list_indic.marked = nil

        list_indic.redraw = 'ALL'
        list_indic.cursor = "ARROW"
        droppedLin = nil;
    end

    local function fillDlg()
        local t = _G.iuprops['INDICATORS']
        local tblInd = {}
        i = 0
        local tSort = {}
        for id, tProp in pairs(t) do
            i = i + 1
            table.insert(tSort,{
                tProp.rem,
                rgb2HStr(tProp.f),
                tProp.a,
                value2string[tProp.s],
                id,
                tProp.f,
                tProp.s,
            })
        end
        list_indic.numlin = #tSort
        table.sort(tSort, function(a, b)
            return a[1] < b[1]
        end)

        for i = 1,  #tSort do
            for j = 1, 7 do
                list_indic:setcell(i, j, tSort[i][j])
            end
        end

        list_indic.redraw = 'ALL'
    end

    function list_indic:enteritem_cb(lin, col)
        if lin ~= cur_lin then
            cur_lin = lin
            c_lbl.title = list_indic:getcell(lin, 1)
            c_clr.rgb = CORE.Rgb2Str(list_indic:getcell(lin, 6))
            c_alfa.value = list_indic:getcell(lin, 3)
            c_style.valuestring = list_indic:getcell(lin, 4)
        end
    end

    local function applySettings()
        local t
        for i = 1, list_indic.numlin do
            t = _G.iuprops['INDICATORS'][list_indic:getcell(i, 5)]
            t.a = math.tointeger(list_indic:getcell(i, 3))
            t.f = math.tointeger(list_indic:getcell(i, 6))
            t.s = math.tointeger(list_indic:getcell(i, 7))
        end
        CORE.InitMarkStyles()
    end

    local function createDlg()

        dlg = iup.scitedialog{iup.vbox{
            list_indic,
            iup.hbox{
                c_clr,
                iup.vbox{
                    c_lbl,
                    iup.hbox{iup.label{title = 'Прозрачность: '}, c_alfa},
                    iup.hbox{iup.label{title = 'Стиль: '}, c_style},
                    iup.hbox{
                        iup.flatbutton{title = "Применить", expand = 'NO', padding = '9x', flat_action = applySettings, propagatefocus = 'YES'},
                    }
                },
        scrollbar = 'NO', expand = "HORIZONTAL", margin = "20x", gap = "20"};};
        sciteparent = "SCITE", sciteid = "indiccolors",
        size = '300x280', bgcolor = '255 255 255', resize = 'NO', title = 'Свойства индикаторов',
        show_cb = function(h, state)
            if state == 4 then
                dlg:postdestroy()
            elseif state == 0 then
                fillDlg()
            end
        end}


        dlg.resize_cb = function(h)
            list_indic.rasterwidth4 = nil
            list_indic.fittosize = 'COLUMNS'
        end

        dlg.k_any = function(h, k)
            if k == iup.K_ESC then h:hide(); _G.iuprops['dialogs.bufferslist.state'] = 0 end
        end
        bIsList = true
        return dlg
    end

    dlg = createDlg()
end

InitIndicDialog()
