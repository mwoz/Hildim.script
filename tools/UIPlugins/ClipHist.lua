
local lst_clip, clipboard, maxlin, colcolor, blockReselect, blockResetCB
maxlin = 30
colcolor = '0 150 0'
blockReselect = false
blockResetCB = false
local droppedLin = nil
local lin0 = 10

local function setClipboard(lin)
    if lin <= tonumber(lst_clip.numlin) then
        local text =  iup.GetAttributeId2(lst_clip, "", lin, 2)
        if iup.GetAttributeId2(lst_clip, "FGCOLOR", lin, 1) == colcolor then
            clipboard.text = text
            clipboard.formatdatasize = text:len()
            clipboard.formatdata = text
        else
            clipboard.text = text
        end
        lst_clip.dellin = lin
        local h = iup.GetFocus()
        if h then h.insert= text
        else scite.MenuCommand(IDM_PASTE) end
    end
end

local function Sidebar_Init()

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
            iup.PassFocus()
            iup.SetAttributeId2(lst_clip, 'MARK',1,0, 1)
        end
        lst_clip.redraw = 'ALL'
        lst_clip.cursor = "ARROW"
        droppedLin = nil;
    end

    function lst_clip:button_cb(button, pressed, x, y, status)
        if iup.isdouble(status) and button == 49 then
            iup.PassFocus(); setClipboard(math.floor(iup.ConvertXYToPos(lst_clip, x, y)/3))
        elseif button == 49 and pressed == 0 then
            droppedLin = nil; lst_clip.cursor = "ARROW"
        elseif button == 51 and pressed == 0 then
            local lin = math.floor(iup.ConvertXYToPos(lst_clip, x, y)/3)
            blockReselect = true

            iup.menu{
                iup.item{title="Delete",action=(function()
                    lst_clip.dellin = lin
                    if lin == 1 then clipboard.text = lst_clip:getcell(1, 2) end
                end)},
                iup.item{title="Paste Top",action=(function()
                    local text = ''
                    for i = 1,  lin do
                        text = text..lst_clip:getcell(i, 2)
                        if i < lin then text = text..'\n' end
                    end
                    clipboard.text = text
                    clipboard.formatdatasize = text:len()
                    clipboard.formatdata = text
                    scite.MenuCommand(IDM_PASTE)
                end)},
                iup.item{title="Set for Ctrl+0",action=(function()
                    lin0 = lin
                end), active = Iif(lin >=10, 'YES', 'NO')},

            }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
            blockReselect = false
            lst_clip.leavewindow_cb()
        end
    end

    function lst_clip:mousemove_cb(lin, col)
        if lin == 0 then return end
        local prevSel = iup.GetAttributeId2(lst_clip, 'MARK',lin,0)
        if tonumber(prevSel) ~= lin then
            lst_clip.marked = nil
            iup.SetAttributeId2(lst_clip, 'MARK',lin,0, 1)
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
                blockResetCB = false
            end
        end
    end

    AddEventHandler("OnDrawClipboard", function(flag)
        lst_clip.marked = nil
        if flag > 0 and not blockResetCB then
            local text = clipboard.text
            if not text then return end
            lst_clip.addlin = 0
            lst_clip["1:1"] = text:sub(1, 200):gsub('[\n\r\t]', ' '):gsub('^ +', '')
            lst_clip["1:2"] = text
            if flag == 2 then iup.SetAttributeId2(lst_clip, 'FGCOLOR', 1, 1, colcolor) end

            for i = lst_clip.numlin,  2, -1 do
                if i > maxlin or text == iup.GetAttributeId2(lst_clip, "", i, 2) then lst_clip.dellin = i end
            end
            for i = 1,  lst_clip.numlin do
                iup.SetAttributeId2(lst_clip, "", i, 0, Iif(i==lin0,0,i))
            end
            iup.SetAttributeId2(lst_clip, 'MARK',1,0, 1)
            lst_clip.redraw = 'ALL'
        end
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

    SideBar_Plugins.cliphistory = {
        handle = lst_clip; }
end

return {
    title = 'Clipboard History',
    code = 'cliphistory',
    sidebar = Sidebar_Init,
}
