
local lst_clip, clipboard, maxlin, colcolor, blockReselect, blockResetCB
maxlin = 30
colcolor = '0 150 0'
blockReselect = false
blockResetCB = false
local droppedLin = nil
local lin0 = 10
local onDraw_cb
local bToolBar = false

local function renum()
    for i = 1,  lst_clip.numlin do
        iup.SetAttributeId2(lst_clip, "", i, 0, Iif(i==lin0,0,i))
    end
end

CLIPHISTORY = {}
CLIPHISTORY.GetClip = function(i)
    return iup.GetAttributeId2(lst_clip, "", i, 2)
end

local function setClipboard(lin)
    if lin> 0 and lin <= tonumber(lst_clip.numlin) then
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
            clipboard.text = text
        end

        local h = iup.GetFocus()
        if h then h.insert= text
        else scite.MenuCommand(IDM_PASTE) end
        if onDraw_cb then onDraw_cb(text:sub(1, 200):gsub('[\n\r\t]', ' '):gsub('^ +', '')) end

        renum()
    end
end

local function init()
    clipboard = iup.clipboard{}
    clipboard.format = 'MSDEVColumnSelect'

    lst_clip = iup.list{expand='YES',}

    lst_clip = iup.matrix{
    numcol=2, numcol_visible=2,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', scrollbar="YES" ,
    resizematrix = "YES"  ,readonly="YES"  ,markmultiple="NO" ,height0 = 0, expand = "YES", framecolor="255 255 255",
    rasterwidth0 = 15 ,rasterwidth1 = 600 ,rasterwidth2 = 0 ,}

    function lst_clip:map_cb(lin, col, status)
        lst_clip.size="1x1"
    end
    function lst_clip:leavewindow_cb()
        if blockReselect then return end
        lst_clip.marked = nil
        if clipboard.textavailable == 'YES'  then
            --iup.PassFocus()
            iup.SetAttributeId2(lst_clip, 'MARK',1,0, 1)
        end
        lst_clip.redraw = 'ALL'
        lst_clip.cursor = "ARROW"
        droppedLin = nil;
    end

    function lst_clip:k_any(k)
        if k == iup.K_DOWN then
            local l = 1
            if lst_clip.marked then l = tonumber(lst_clip.marked:find('1') or '1') end
            if l <= tonumber(lst_clip.numlin) then
                lst_clip.marked = nil
                iup.SetAttributeId2(lst_clip, 'MARK', l, 0, 1)
                lst_clip.redraw = 'ALL'
            end
        elseif k == iup.K_UP then
            local l = tonumber(lst_clip.numlin)
            if lst_clip.marked then l = tonumber(lst_clip.marked:find('1') or lst_clip.numlin) - 2 end
            if l >= 1 then
                lst_clip.marked = nil
                iup.SetAttributeId2(lst_clip, 'MARK',l,0, 1)
                lst_clip.redraw = 'ALL'
            end
        elseif k == iup.K_CR then
            local l = tonumber(lst_clip.marked:find('1') or '0') - 1
            if l > 0 then
                iup.PassFocus()
                setClipboard(l)
            end
        elseif k == iup.K_ESC then
            iup.PassFocus()
        end
    end

    function lst_clip:button_cb(button, pressed, x, y, status)
        if button == iup.BUTTON1 and (iup.isdouble(status) or (bToolBar and pressed == 0 and lst_clip.cursor == "ARROW")) then
            iup.PassFocus(); setClipboard(math.floor(iup.ConvertXYToPos(lst_clip, x, y)/3))
        elseif button == iup.BUTTON1 and pressed == 0 then
            droppedLin = nil; lst_clip.cursor = "ARROW"
        elseif button == iup.BUTTON3 and pressed == 0 then
            local lin = math.floor(iup.ConvertXYToPos(lst_clip, x, y)/3)
            blockReselect = true

            iup.menu{
                iup.item{title = "Удалить", action =(function()
                    lst_clip.dellin = lin
                    if lin == 1 then clipboard.text = lst_clip:getcell(1, 2) end
                end)},
                iup.item{title="Вставить верх списка как блок",action=(function()
                    local text = ''
                    for i = 1,  lin do
                        text = text..lst_clip:getcell(i, 2)
                        if i < lin then text = text..'\n' end
                    end
                    clipboard.text = text
                    clipboard.formatdatasize = text:len()
                    clipboard.formatdata = text
                    scite.MenuCommand(IDM_PASTE)
                    blockReselect = false
                    iup.PassFocus()
                end)},
                iup.item{title="Вставлять по Ctrl+0",action=(function()
                    lin0 = lin
                end), active = Iif(lin >=10, 'YES', 'NO')},

            }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
            blockReselect = false
            lst_clip.leavewindow_cb()
        end
    end

    function lst_clip:mousemove_cb(lin, col)
        if lin == 0 then return end

        if iup.GetAttributeId2(lst_clip, 'MARK', lin, 0) ~= '1' then

            lst_clip.marked = nil
            iup.SetAttributeId2(lst_clip, 'MARK', lin, 0, 1)
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

    AddEventHandler("OnDrawClipboard", function(flag)
        lst_clip.marked = nil
        local caption = ''
        if flag > 0 and not blockResetCB then
            local text = clipboard.text
            if not text then return end
            if not lst_clip["1:2"] or lst_clip["1:2"] ~= text then
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

            iup.SetAttributeId2(lst_clip, 'MARK',1,0, 1)
            lst_clip.redraw = 'ALL'
        end
        if onDraw_cb and not blockResetCB then onDraw_cb(caption) end
        blockResetCB = false
    end)

    menuhandler:InsertItem('MainWindowMenu', '_HIDDEN_¦xxx',
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
    h.cliphistory = {
        handle = lst_clip; }
end

local function createDlg()
    local dlg = iup.scitedialog{iup.scrollbox{lst_clip}, sciteparent = "SCITE", sciteid = "cliphistory", dropdown = true,
                maxbox='NO', minbox='NO', menubox='NO', minsize = '100x200', bgcolor='255 255 255',}
    lst_clip.killfocus_cb = function()
        if blockReselect then return end
        dlg:hide()
    end
    return dlg
end

local function Toolbar_Init(h)
    bToolBar = true
    local btn = iup.flatbutton{title = "      ", expand = 'HORIZONTAL', padding='5x', alignment = "ALEFT:ATOP", tip='Clipboard History: Ctrl+1, Ctrl+2, Ctrl+3...'}
    local box = iup.sc_sbox{ iup.scrollbox{btn, scrollbar = 'NO', expand = 'HORIZONTAL', minsize='100x22'}, maxsize = "900x22",shrink='YES'}
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
        dlg:showxy(left,top)
    end

    menuhandler:InsertItem('MainWindowMenu', 'Edit¦s1',
        {'Clibboard History', ru = 'История буфера обмена', key = 'Alt+V',  action=btn.flat_action, }
    )

    h.Tabs.cliphistory =  {
        handle = box
    }
end

local function Hidden_Init(h)
    bToolBar = true
    init()
    local dlg = createDlg()
    menuhandler:InsertItem('MainWindowMenu', 'Tools¦s2',
        {'Clipboard History', ru = 'История буфера обмена', action = function() iup.ShowInMouse(dlg) end,}
    )
end

return {
    title = 'Clipboard History',
    code = 'cliphistory',
    sidebar = Sidebar_Init,
    toolbar = Toolbar_Init,
    hidden = Hidden_Init,
    description = [[Автоматическое запоминание текстовых данных
из буфера обмена в стек с возможностью их последующей
быстой вставки в текст]]

}
