--[[Диалог редактирования горячих клавиш]]
require "menuhandler"
local tblView = {}, tblUsers
local defpath = props["SciteDefaultHome"].."\\tools\\ToolBar\\"


local function Show()

    local list_tb, dlg, bBlockReset, tree_btns
    local btn_ok = iup.button  {title="OK"}
    iup.SetHandle("HK_BTN_OK",btn_ok)
    btn_ok.action = function()
        local str = ''
        for i = 1,  tonumber(list_tb.numlin) do
            if iup.GetAttributeId2(list_tb, 'TOGGLEVALUE', i, 2) == '1' then
                if str ~= '' then str = str..'¦' end
                str = str..list_tb:getcell(i, 1)
                if iup.GetAttributeId2(list_tb, 'TOGGLEVALUE', i, 3) == '1' then str = str..'¬' end
            end
        end
        _G.iuprops["settings.toolbars.layout"] = str
        dlg:hide()
        dlg:postdestroy()
    end

    list_tb = iup.matrix{
    numcol=3, numcol_visible=3,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', scrollbar="YES" ,
    resizematrix = "YES"  ,markmultiple="NO" ,height0 = 4, expand = "YES", framecolor="255 255 255", --togglecentered = 'YES',
    width0 = 0 ,rasterwidth1 = 200,rasterwidth2= 70,rasterwidth3= 130, }
    list_tb:setcell(0, 1, "Панель")
    list_tb:setcell(0, 2, "Показать")
    list_tb:setcell(0, 3, "С новой строки")

    list_tb.dropcheck_cb = function(h, lin, col)
        if col > 1 then return -4
        else return false end
    end
    list_tb.edition_cb = function()  return -1 end

    local droppedLin = nil
    list_tb.mousemove_cb = function(h, lin, col)
        if lin == 0 then return end
        local lBtn = (shell.async_mouse_state() < 0)
        if (droppedLin == nil) and lBtn then
            droppedLin = lin;
            h.cursor = "RESIZE_NS"
        end
        if lBtn and lin ~= droppedLin then
            local curL = list_tb:getcell(lin, 1)
            local cur2 = iup.GetAttributeId2(h, 'TOGGLEVALUE', lin, 2)
            local cur3 = iup.GetAttributeId2(h, 'TOGGLEVALUE', lin, 3)

            list_tb:setcell(lin, 1,list_tb:getcell(droppedLin, 1))
            iup.SetAttributeId2(h, 'TOGGLEVALUE', lin, 2, iup.GetAttributeId2(h, 'TOGGLEVALUE', droppedLin, 2))
            iup.SetAttributeId2(h, 'TOGGLEVALUE', lin, 3, iup.GetAttributeId2(h, 'TOGGLEVALUE', droppedLin, 3))

            list_tb:setcell(droppedLin, 1,curL)
            iup.SetAttributeId2(h, 'TOGGLEVALUE', droppedLin, 2, cur2)
            iup.SetAttributeId2(h, 'TOGGLEVALUE', droppedLin, 3, cur3)

            droppedLin = lin
            list_tb.redraw = "ALL"
        end
    end


    list_tb.leavewindow_cb = function()  droppedLin = nil; list_tb.cursor = "ARROW" end
    list_tb.button_cb = function(h, button, pressed, x, y, status)
        local id = iup.ConvertXYToPos(h, x, y)
        local lin = math.floor(id/4)
        local col = id % 4
        if button == 49 and pressed == 0 and col ==1 then droppedLin = nil; h.cursor = "ARROW"
        elseif col == 2 and pressed == 0 then
            iup.SetAttributeId2(h, 'TOGGLEVALUE', lin, 2, Iif(iup.GetAttributeId2(h, 'TOGGLEVALUE', lin, 2) == '1', '0','1'))
            if iup.GetAttributeId2(h, 'TOGGLEVALUE', lin, 2) ~= '1' then iup.SetAttributeId2(h, 'TOGGLEVALUE', lin, 3, 0) end
            iup.SetAttribute(h, 'REDRAW', 'ALL')
        elseif col == 3 and pressed == 0 and iup.GetAttributeId2(h, 'TOGGLEVALUE', lin, 2) == '1' then
            iup.SetAttributeId2(h, 'TOGGLEVALUE', lin, 3, Iif(iup.GetAttributeId2(h, 'TOGGLEVALUE', lin, 3) == '1', 0,1))
            list_tb.redraw = "ALL"
        end
    end

    local vbox = iup.vbox{
        iup.hbox{list_tb};
        iup.hbox{btn_ok},
        expandchildren ='YES',gap=2,margin="4x4"}
    dlg = iup.scitedialog{vbox; title="Панели инструментов",defaultenter="HK_BTN_OK",defaultesc="LEX_BTN_ESC",tabsize=editor.TabWidth,
        maxbox="NO",minbox ="NO",resize ="YES",shrink ="YES",sciteparent="SCITE", sciteid="LexersSetup", minsize='300x200'}


    dlg.show_cb=(function(h,state)
        if state == 4 then
            dlg:postdestroy()
        end
    end)


    local table_dir = shell.findfiles(defpath..'*.lua')
    iup.SetAttribute(list_tb, "ADDLIN", "1-"..(#table_dir))
    str = _G.iuprops["settings.toolbars.layout"]
    local j = 1
    for p in str:gmatch('[^¦]*') do
        for i = 1, #table_dir do
            local bNewLine = p:find('¬$')
            p = p:gsub('¬$', '')
            if table_dir[i].name == p then
                table.remove(table_dir, i)
                list_tb:setcell(j, 1, p)
                iup.SetAttributeId2(list_tb, 'TOGGLEVALUE', j, 2, '1')
                if bNewLine then iup.SetAttributeId2(list_tb, 'TOGGLEVALUE', j, 3, '1') end
                j = j + 1
                break
            end
        end
    end

    for i = 1, #table_dir do
        list_tb:setcell(j, 1, table_dir[i].name)
        j = j + 1
    end
    list_tb.redraw = "ALL"
end

Show()
