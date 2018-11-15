local lst_clip, clipboard, maxlin, colcolor, blockReselect, blockResetCB, expd, txt_live, btn
maxlin = 60
colcolor = '0 150 0'
blockReselect = false
blockResetCB = false
local droppedLin = nil
local lin0 = 10
local onDraw_cb
local bToolBar = false
local hIUpCtrl

local function renum()
    for i = 1,  lst_clip.numlin do
        iup.SetAttributeId2(lst_clip, "", i, 0, Iif(i==lin0,0,i))
    end
end

local function MarkList(i)
    iup.SetAttributeId2(lst_clip, 'MARK', i, 0, 1)
    lst_clip.FOCUSCELL = i..':1'
    lst_clip.SHOW = i..':1'
end

local function setClipboard(lin)
    if lin > 0 and lin <= tonumber(lst_clip.numlin) then
        local text =  iup.GetAttributeId2(lst_clip, "", lin, 2)
        local bCol = (iup.GetAttributeId2(lst_clip, "FGCOLOR", lin, 1) == colcolor)
        lst_clip.addlin = 0
        lst_clip:setcell(1, 1, lst_clip:getcell(lin + 1, 1))
        lst_clip:setcell(1, 2, lst_clip:getcell(lin + 1, 2))
        lst_clip["fgcolor1:1"] = lst_clip["fgcolor"..(lin + 1)..":1"]
        lst_clip.dellin = lin + 1
        lst_clip.redraw = "1"
        blockResetCB = true
        if bCol then
            clipboard.text = text
            clipboard.formatdatasize = text:len()
            clipboard.formatdata = text
        else
            clipboard.formatdata = nil
            clipboard.text = text
        end

        local h = iup.GetFocus()
        if h then h.insert = text
        elseif findres.Focus then
            findres:Paste()
        elseif output.Focus then
            output:Paste()
        else scite.MenuCommand(IDM_PASTE) end
        if onDraw_cb then onDraw_cb(text:sub(1, 200):gsub('[\n\r\t]', ' '):gsub('^ +', '')) end

        renum()
    end
end

local function init()
    CLIPHISTORY = {}
    CLIPHISTORY.GetClip = function(lin, bShift)
        if not bShift then
            return iup.GetAttributeId2(lst_clip, "", lin, 2)
        elseif lin > 0 and lin <= tonumber(lst_clip.numlin) then
            local text = iup.GetAttributeId2(lst_clip, "", lin, 2)

            lst_clip.addlin = 0
            lst_clip:setcell(1, 1, lst_clip:getcell(lin + 1, 1))
            lst_clip:setcell(1, 2, lst_clip:getcell(lin + 1, 2))
            lst_clip["fgcolor1:1"] = lst_clip["fgcolor"..(lin + 1)..":1"]
            lst_clip.dellin = lin + 1
            lst_clip.redraw = "1"

            if onDraw_cb then onDraw_cb(text:sub(1, 200):gsub('[\n\r\t]', ' '):gsub('^ +', '')) end

            renum()
            return text
        end
        return ''
    end
    clipboard = iup.clipboard{}
    clipboard.format = 'MSDEVColumnSelect'

    --lst_clip = iup.list{expand='YES',}

    lst_clip = iup.matrix{
    numcol=2, numcol_visible=2,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', flatscrollbar="VERTICAL" ,
    resizematrix = "YES"  ,readonly="YES"  ,markmultiple="NO" ,height0 = 0, expand = "YES", framecolor=iup.GetLayout().txtbgcolor;
    rasterwidth0 = 15 ,rasterwidth1 = 600 ,rasterwidth2 = 0 ,bgcolor=iup.GetLayout().txtbgcolor;}

    function lst_clip:map_cb(lin, col, status)
        lst_clip.size="1x1"
    end
    function lst_clip:leavewindow_cb()
        if blockReselect then return end
        lst_clip.marked = nil
        if clipboard.textavailable == 'YES'  then
            --iup.PassFocus()
            MarkList(1)
        end
        lst_clip.redraw = 'ALL'
        lst_clip.cursor = "ARROW"
        droppedLin = nil;
    end

    local function PassFocus()
        if hIUpCtrl then
            iup.SetFocus(hIUpCtrl)
        else
            iup.PassFocus()
        end
        hIUpCtrl = nil
    end

    local function contextMenu(lin)
        blockReselect = true

        iup.menu{
            iup.item{title = _T"Delete", action =(function()
                lst_clip.dellin = lin
                if lin == 1 then clipboard.text = lst_clip:getcell(1, 2) end
            end)},
            iup.item{title = _T"Insert Upper List as Block", action =(function()
                local text = ''
                for i = 1, lin do
                    text = text..lst_clip:getcell(i, 2)
                    if i < lin then text = text..'\n' end
                end
                blockResetCB = false
                clipboard.text = text
                clipboard.formatdatasize = text:len()
                clipboard.formatdata = text
                OnDrawClipboard(2)
                scite.MenuCommand(IDM_PASTE)
                blockReselect = false
                PassFocus()
            end)},
            iup.item{title = _T"Insert Upper List via Separator", action =(function()
                local bok, res, bside = iup.GetParam(_T'Insert via Separator',
                    nil,
                    _T"Separator"..": %s\n"..
                    _T"Join Upside Down".." %b\n"
                    , ', ', 0
                )
                iup.SetFocus(lst_clip)
                if bok then
                    local text = ''
                    local I, I1, S = lin, 1, -1
                    if bside == 0 then I, I1, S = 1, lin, 1 end
                    res = res:gsub('\\n', '\n'):gsub('\\r', '\r'):gsub('\\t', '\t')
                    for i = I, I1, S do
                        if text ~= '' then text = text..res end
                        text = text..lst_clip:getcell(i, 2)
                    end
                    blockResetCB = false
                    clipboard.formatdatasize = 0
                    clipboard.formatdata = nil
                    clipboard.text = text
                    OnDrawClipboard(1)
                    scite.MenuCommand(IDM_PASTE)
                    blockReselect = false
                    PassFocus()
                end
            end)},
            iup.separator{},
            iup.item{title = _T"Upper List Upside Down", action = function()
                if lin == 1 then return end
                for i = 2, lin do
                    lst_clip.addlin = 0
                    lst_clip:setcell(1, 1, lst_clip:getcell(i + 1, 1))
                    lst_clip:setcell(1, 2, lst_clip:getcell(i + 1, 2))
                    iup.SetAttributeId2(lst_clip, 'FGCOLOR', 1, 1, iup.GetAttributeId2(lst_clip, 'FGCOLOR', i + 1, 1))
                    lst_clip.dellin = i + 1
                end
                lst_clip.redraw = 'ALL'

                if iup.GetAttributeId2(lst_clip, "FGCOLOR", 1, 1) == colcolor then
                    clipboard.text = nil
                    clipboard.formatdatasize = 0
                    clipboard.formatdata = nil
                    clipboard.text = lst_clip:getcell(1, 2)
                else
                    local text = lst_clip:getcell(1, 2)
                    clipboard.text = text
                    clipboard.formatdatasize = text:len()
                    clipboard.formatdata = text
                end
            end,
            active = Iif(lin > 1, 'YES', 'NO'),},
            iup.item{title = _T"Insert with Ctrl+0", action = function()
                lin0 = lin
                for i = 1, lst_clip.numlin do
                    lst_clip:setcell(i, 0, Iif(i == lin0, 0, i))
                end
                lst_clip.redraw = 'ALL'
                blockReselect = false
            end,
            active = Iif(lin >= 10, 'YES', 'NO')},
            iup.item{title = _T"Split on Separator", action = function()
                local bok, res, bside = iup.GetParam(_T'Split Clip into Several',
                    nil,
                    _T"Separator"..": %s\n"..
                    _T"Insert Upside Down".." %b\n"
                    , '\\n', 1
                )
                if bok and res ~= '' then
                    local p = lpeg.C((1 - lpeg.P(res:gsub('\\n', '\n'):gsub('\\r', '\r'):gsub('\\t', '\t')))^1)
                    local tclp = lpeg.Ct(lpeg.P{p + 1 * lpeg.V(1)}^1)
                    local str = lst_clip:getcell(lin, 2)
                    local t = tclp:match(str, 1)
                    if iup.Alarm(_T"Splitting clip", _FMT(_T'Clip will be split into %1 fragments. Continue?', #t), _TH'Yes', _TH'No') == 1 then
                        local I, I1, S = #t, 1, -1
                        if bside == 1 then I, I1, S = 1, #t, 1 end
                        lst_clip.marked = nil
                        for i = I, I1, S do
                            lst_clip.addlin = 0
                            lst_clip["1:1"] = t[i]:sub(1, 200):gsub('[\n\r\t]', ' '):gsub('^ +', '')
                            lst_clip["1:2"] = t[i]
                        end
                        renum()
                        MarkList(1)
                        lst_clip.redraw = 'ALL'
                        if onDraw_cb then onDraw_cb(lst_clip:getcell(1, 1)) end
                        blockResetCB = true
                        clipboard.text = lst_clip:getcell(1, 2)
                    end
                end
                iup.SetFocus(lst_clip)
            end};
            iup.item{title = _T"Convert Format: Block < - > Text", action = function()
                local bCol = (iup.GetAttributeId2(lst_clip, "FGCOLOR", lin, 1) == colcolor)

                if bCol then
                    iup.SetAttributeId2(lst_clip, "FGCOLOR", lin, 1, '0 0 0')
                    if lin == 1 then
                        clipboard.text = nil
                        clipboard.formatdatasize = 0
                        clipboard.formatdata = nil
                        clipboard.text = lst_clip:getcell(1, 2)
                    end
                else
                    iup.SetAttributeId2(lst_clip, "FGCOLOR", lin, 1, colcolor)
                    if lin == 1 then
                        local text = lst_clip:getcell(1, 2)
                        clipboard.text = text
                        clipboard.formatdatasize = text:len()
                        clipboard.formatdata = text
                    end
                end
            end},
        }:popup(iup.MOUSEPOS, iup.MOUSEPOS)
        blockReselect = false
        lst_clip.leavewindow_cb()
    end

    function lst_clip:k_any(k)
        if k == iup.K_Menu then
            contextMenu(tonumber(lst_clip.marked:find('1') or '0') - 1)
        elseif k == iup.K_DOWN then
            local l = 1
            if lst_clip.marked then l = tonumber(lst_clip.marked:find('1') or '1') end
            if l <= tonumber(lst_clip.numlin) then
                lst_clip.marked = nil
                MarkList(l)
                lst_clip.redraw = 'ALL'
                return iup.IGNORE
            end
        elseif k == iup.K_UP then
            local l = tonumber(lst_clip.numlin)
            if lst_clip.marked then l = tonumber(lst_clip.marked:find('1') or lst_clip.numlin) - 2 end
            if l >= 1 then
                lst_clip.marked = nil
                MarkList(l)
                lst_clip.redraw = 'ALL'
                return iup.IGNORE
            end
        elseif k == iup.K_CR or k == iup.K_TAB then
            local l = tonumber(lst_clip.marked:find('1') or '0') - 1
            if l > 0 then
                PassFocus()
                setClipboard(l)
            end
        elseif k == iup.K_ESC then
            PassFocus()
        elseif k == iup.K_PGDN and txt_live then
            if expd.state == 'OPEN' then
                txt_live:valuechanged_cb()
                return iup.IGNORE
            end
        elseif tonumber(k) > 31 and tonumber(k) < 256 and txt_live and not blockReselect then
            if expd.state == 'CLOSE' then
                expd.state = 'OPEN'
                blockReselect = true
                iup.SetFocus(txt_live)
                iup.SetGlobal('KEY', k)
                blockReselect = false
            end
        end
    end

    function lst_clip:button_cb(button, pressed, x, y, status)
        if button == iup.BUTTON1 and ((iup.isdouble(status) and not bToolBar) or (bToolBar and pressed == 0 and lst_clip.cursor == "ARROW")) then
            PassFocus(); setClipboard(math.floor(iup.ConvertXYToPos(lst_clip, x, y) / 3))
        elseif button == iup.BUTTON1 and pressed == 0 then
            droppedLin = nil; lst_clip.cursor = "ARROW"
        elseif button == iup.BUTTON3 and pressed == 0 then
            local lin = math.floor(iup.ConvertXYToPos(lst_clip, x, y) / 3)
            contextMenu(lin)
        end
    end

    function lst_clip:mousemove_cb(lin, col)
        if lin == 0 then return end

        if iup.GetAttributeId2(lst_clip, 'MARK', lin, 0) ~= '1' then

            lst_clip.marked = nil
            MarkList(lin)
            lst_clip.redraw = 'ALL'
        end

        local lBtn = (shell.async_mouse_state() < 0)

        if (droppedLin == nil) and lBtn then
            droppedLin = lin;
            lst_clip.cursor = "RESIZE_NS"
        end
        if lBtn and lin ~= droppedLin then
            local bReset = (lin == 1 or droppedLin == 1)
            local cur1 = lst_clip:getcell(lin, 1)
            local cur2 = lst_clip:getcell(lin, 2)
            local clr = iup.GetAttributeId2(lst_clip, 'FGCOLOR',lin,1)

            lst_clip:setcell(lin, 1,lst_clip:getcell(droppedLin, 1))
            lst_clip:setcell(lin, 2,lst_clip:getcell(droppedLin, 2))
            iup.SetAttributeId2(lst_clip, 'FGCOLOR',lin,1, iup.GetAttributeId2(lst_clip, 'FGCOLOR',droppedLin,1))

            lst_clip:setcell(droppedLin, 1,cur1)
            lst_clip:setcell(droppedLin, 2,cur2)
            iup.SetAttributeId2(lst_clip, 'FGCOLOR',droppedLin,1, clr)

            droppedLin = lin
            if bReset then
                blockResetCB = true
                clipboard.text = lst_clip:getcell(1, 2)
                if onDraw_cb then onDraw_cb(lst_clip:getcell(1, 1)) end
            end
            lst_clip.redraw = 'ALL'
        end
    end

    AddEventHandler("OnScriptReload", function(bSave, t)
        if bSave then
            t.cliphist = {}
            for i = 1, lst_clip.numlin do
                t.cliphist[i] = {}
                for j = 1, 2 do
                    t.cliphist[i][j] = lst_clip:getcell(i, j)
                end
                if (iup.GetAttributeId2(lst_clip, "FGCOLOR", i, 1) == colcolor) then t.cliphist[i].mult = true end
            end
            t.cliphist.lin0 = lin0
        else
            if t.cliphist then
                lst_clip.addlin = '0-'..#t.cliphist
                lin0 = t.cliphist.lin0 or 10
                for i = 1, #t.cliphist do
                    lst_clip:setcell(i, 0, Iif(i==lin0,0,i))
                    for j = 1, 2 do
                        lst_clip:setcell(i, j, t.cliphist[i][j])
                    end
                    if t.cliphist[i].mult then iup.SetAttributeId2(lst_clip, "FGCOLOR", i, 1, colcolor) end
                end
                lst_clip.redraw = 'ALL'
                if clipboard.textavailable == 'YES' then
                    if btn then btn.title = lst_clip:getcell(1, 1) or '' end
                    MarkList(1)
                end
            end
        end
    end)

    function CLIPHISTORY.Copy(flag, strIn)
        lst_clip.marked = nil
        local caption = ''
        if flag > 0 and not blockResetCB then
            local text = strIn or clipboard.text
            if not text then return end
            if not lst_clip["1:2"] or lst_clip["1:2"] ~= text or strIn then
                lst_clip.addlin = 0
                caption = text:sub(1, 200):gsub('[\n\r\t]', ' '):gsub('^ +', '')
                lst_clip["1:1"] = caption
                lst_clip["1:2"] = text
                if flag == 2 then iup.SetAttributeId2(lst_clip, 'FGCOLOR', 1, 1, colcolor) end
                for i = lst_clip.numlin,  2, -1 do
                    if i > maxlin or text == iup.GetAttributeId2(lst_clip, "", i, 2) then lst_clip.dellin = i end
                end
            elseif lst_clip["1:2"] and lst_clip["1:2"] == text then
                blockResetCB = true
            end

            renum()

            MarkList(1)
            lst_clip.redraw = 'ALL'
        end
        if onDraw_cb and not blockResetCB then onDraw_cb(caption) end
        blockResetCB = false
    end

    AddEventHandler("OnDrawClipboard", function(flag)
        CLIPHISTORY.Copy(flag)
    end)

    menuhandler:InsertItem('MainWindowMenu', '_HIDDEN_|xxx',
    {'Clipboard History', {
        {'C1', key = 'Ctrl+1',  action=function() setClipboard(1) end, },
        {'C2', key = 'Ctrl+2',  action=function() setClipboard(2) end, },
        {'C3', key = 'Ctrl+3',  action=function() setClipboard(3) end, },
        {'C4', key = 'Ctrl+4',  action=function() setClipboard(4) end, },
        {'C5', key = 'Ctrl+5',  action=function() setClipboard(5) end, },
        {'C6', key = 'Ctrl+6',  action=function() setClipboard(6) end, },
        {'C7', key = 'Ctrl+7',  action=function() setClipboard(7) end, },
        {'C8', key = 'Ctrl+8',  action=function() setClipboard(8) end, },
        {'C9', key = 'Ctrl+9',  action=function() setClipboard(9) end, },
        {'C0', key = 'Ctrl+0',  action=function() setClipboard(lin0) end, },
    }})
end

local function Sidebar_Init(h)
    init()
    AddEventHandler("OnResizeSideBar", function(sciteid)
        if h.cliphistory.Bar_obj.sciteid == sciteid then
            lst_clip.rasterwidth1 = nil
            lst_clip.fittosize = 'COLUMNS'
        end
    end)
    return {
        handle = iup.backgroundbox{lst_clip, bgcolor = iup.GetLayout().txtbgcolor}; }
end

local function createDlg()
    txt_live = iup.text{size = '25x', k_any = lst_clip.k_any, expand = 'HORIZONTAL'}
    expd = iup.expander{iup.hbox{txt_live, iup.label{title = '<PgDn>-Next'},iup.label{}, gap = 10, alignment='ACENTER'}, barposition = 'BOTTOM', barsize = '0', state = 'CLOSE', visible = 'NO'}

    local dlg = iup.scitedialog{iup.vbox{expd, lst_clip}, sciteparent = "SCITE", sciteid = "cliphistory", dropdown = true, shrink = "YES",
                maxbox = 'NO', minbox = 'NO', menubox = 'NO', minsize = '100x200', bgcolor = '255 255 255',
                customframedraw = Iif(props['layout.standard.decoration'] == '1', 'NO', 'YES') , customframecaptionheight = -1, customframedraw_cb = CORE.paneldraw_cb, customframeactivate_cb = CORE.panelactivate_cb(nil)}

    local tmr = iup.timer{time = 10, run = 'NO', action_cb = function(h)
        expd.state = 'CLOSE'
        txt_live.value = ''
        h.run = 'NO'
        dlg:hide()
    end}

    lst_clip.killfocus_cb = function()
        if blockReselect then return end
        tmr.run = 'YES'
    end
    txt_live.killfocus_cb = lst_clip.killfocus_cb

    lst_clip.getfocus_cb = function()
        tmr.tun = 'NO'
    end
    txt_live.getfocus_cb = lst_clip.getfocus_cb
    txt_live.valuechanged_cb = function(h)
        local lStart = 1
        if h.value == '' then MarkList(1); lst_clip.redraw = 'ALL'; return end
        if lst_clip.marked then lStart = tonumber(lst_clip.marked:find('1') or '0') - 1 end
        for i = 0, lst_clip.numlin - 1 do
            local j = (i + lStart) % (lst_clip.numlin) + 1
            if StringLower(lst_clip:getcell(j, 1),1251):find('^'..StringLower(h.value,1251)) then
                lst_clip.marked = nil
                MarkList(j)
                lst_clip.redraw = 'ALL'
                return
            end
        end
        MarkList(1); lst_clip.redraw = 'ALL'
    end

    dlg.resize_cb = function(h)
        lst_clip.rasterwidth1 = nil
        lst_clip.fittosize = 'COLUMNS'
    end
    dlg.show_cb = function(h, state)
        if state == 0 then
            lst_clip.rasterwidth1 = nil
            lst_clip.fittosize = 'COLUMNS'
        end
    end
    menuhandler:InsertItem('MainWindowMenu', 'Tools|s2',
        {'Clipboard History...', action = function() hIUpCtrl = iup.ShowInMouse(dlg, true) end, key = "Alt+Shift+C", image = "clipboard_list_µ"}
    , nil, _T)
    return dlg
end

local function Toolbar_Init(h)
    bToolBar = true
    btn = iup.flatbutton{title = "      ", expand = 'HORIZONTAL', padding='5x', alignment = "ALEFT:ATOP", tip='Clipboard History: Ctrl+1, Ctrl+2, Ctrl+3...'}
    local box = iup.sc_sbox{iup.scrollbox{btn, scrollbar = 'NO', expand = 'HORIZONTAL', minsize='100x22', bgcolor = iup.GetLayout().bgcolor}, maxsize = "900x22",shrink='YES'}
    onDraw_cb = function(s)
        btn.title = s
        iup.Redraw(box, 1)
    end

    function btn:map_cb(h)
        local sb = iup.GetChild(box, 0)
        sb.cursor = "RESIZE_WE"
        box.value = _G.iuprops["cliphistory.bntwidth"] or "200"
    end
    function btn:unmap_cb(h)
        _G.iuprops["cliphistory.bntwidth"] = box.value
    end

    init()

    local dlg = createDlg()

    btn.flat_action = function(h)
        local _, _,left, top = btn.screenposition:find('(-*%d+),(-*%d+)')
        local _,_,dx,dy = dlg.rastersize:find('(%d*)x(%d*)')
        if tonumber(dx) < tonumber(box.value) then
            dlg.rastersize = box.value..'x'..dy
        end
        if iup.GetParent(iup.GetParent(iup.GetParent(h))).name =='StatusBar' then top = top - dy end
        dlg:showxy(left,top)
    end

    return {
        handle = box
    }
end

local function Hidden_Init(h)
    bToolBar = true
    init()
    local dlg = createDlg()
end

return {
    title = 'Clipboard History',
    code = 'cliphistory',
    sidebar = Sidebar_Init,
    toolbar = Toolbar_Init,
    statusbar = Toolbar_Init,
    hidden = Hidden_Init,
    tabhotkey = "Alt+Shift+C",
    destroy = function() CLIPHISTORY = nil end,
    description = [[Автоматическое запоминание текстовых данных
из буфера обмена в стек с возможностью их последующей
быстой вставки в текст]]

}
