--[[ƒиалог редактировани€ гор€чих клавиш]]
local tblView = {}, tblUsers
local defpath = props["SciteDefaultHome"].."\\tools\\UIPlugins\\"

local function Show()

    local list_lex, dlg, bBlockReset, tree_right, tree_plugins
    local btn_ok = iup.button  {title="OK"}
    local btn_esc = iup.button  {title="Cancel"}
    iup.SetHandle("TOOLBARSETT_BTN_OK",btn_ok)
    iup.SetHandle("TOOLBARSETT_BTN_ESC",btn_esc)
    btn_esc.action = function()
        dlg:hide()
        dlg:postdestroy()
    end

    local function ConvertXY2WndPos(h, x, y)
        local _,_,wx,wy = h.position:find('(%d*),(%d*)')
        wx = tonumber(wx); wy = tonumber(wy)
        x = x + wx; y = y + wy
        local t = { tree_plugins, tree_right}
        for i = 1,  2 do
            _,_,wx,wy = t[i].position:find('(%d*),(%d*)')
            local _,_,dx,dy = t[i].rastersize:find('(%d*)x(%d*)')
            wx = tonumber(wx); wy = tonumber(wy); dx = tonumber(dx); dy = tonumber(dy)
            if wx <= x and x <= wx + dx and wy <= y and y <= wy + dy then
                x = x - wx; y = y - wy
                return t[i], iup.ConvertXYToPos(t[i], x, y)
            end
        end
    end

    tree_plugins = iup.text{size='100x'}

    btn_ok.action = function()
        local function SaveTree(h)
            local str = ''
            local suff = 'ђ'
            for i = 1,  iup.GetAttribute(h, "TOTALCHILDCOUNT0") do
                if iup.GetAttributeId(h, "KIND", i) == "BRANCH" then
                    suff = 'ђ'
                else
                    if str ~= '' then str = str..'¶' end
                    str = str..h:GetUserId(i)..suff
                    suff = ''
                end
            end
            return str
        end
        _G.iuprops["settings.toolbars.layout"] = SaveTree(tree_right)
        dlg:hide()
        dlg:postdestroy()
        scite.PostCommand(POST_SCRIPTRELOAD,0)
    end

    local dragName, dragPath, drag_id

    local idSrc
    local function button_cb(h, button, pressed, x, y, status)
        if button ~= 49 then return end
        if pressed == 1 then
            idSrc = iup.ConvertXYToPos(h, x, y)
        else
           local hTarget, idTarget = ConvertXY2WndPos(h, x, y)
           if hTarget and hTarget ~= h and idSrc > 0 then
                if idTarget < 0 then idTarget = tonumber(iup.GetAttribute(hTarget, 'COUNT')) - 1 end
                if iup.GetAttributeId(h, 'KIND', idSrc) == 'BRANCH' then
                    if hTarget ~= tree_plugins then
                        if iup.GetAttributeId(hTarget, 'KIND', idTarget) ~= 'BRANCH' then
                            idTarget = iup.GetAttributeId(hTarget, 'PARENT', idTarget)
                        end
                        iup.SetAttributeId(hTarget, "STATE", idTarget, 'COLLAPSED')
                        iup.SetAttributeId(hTarget, "INSERTBRANCH", idTarget, iup.GetAttributeId(h, 'TITLE', idSrc))
                    end
                    for i = 1,  iup.GetAttribute(h, "TOTALCHILDCOUNT", idSrc) do
                        iup.SetAttributeId(hTarget, "ADDLEAF", hTarget.lastaddnode or 0, iup.GetAttributeId(h, 'TITLE', idSrc + i))
                        hTarget:SetUserId(hTarget.lastaddnode, h:GetUserId(idSrc + i))
                    end
                    iup.SetAttributeId(h, 'DELNODE', idSrc, 'SELECTED')
                else
                    if idTarget == 0 and iup.GetAttributeId(hTarget, "KIND", 1) == 'BRANCH' then return end

                    iup.SetAttributeId(hTarget, "ADDLEAF", idTarget, iup.GetAttributeId(h, 'TITLE', idSrc))
                    hTarget:SetUserId(hTarget.lastaddnode, h:GetUserId(idSrc))
                    iup.SetAttributeId(h, 'DELNODE', idSrc, 'SELECTED')
                end
            end
        end
    end

    local function rightclick_cb(h, id)
        iup.menu
        {
            iup.item{title="Add Tool Bar", action=function()
                iup.SetAttributeId(h, "ADDBRANCH", 0, "<Bar>")
            end};
        }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
    end

    local function dragdrop_cb(h,drag_id, drop_id, isshift, iscontrol)
        if drop_id == 0 then drop_id = 1 end
        if iscontrol == 1 or h == tree_plugins then return -1 end
        if iup.GetAttributeId(h, 'KIND', drag_id) == 'BRANCH' then
            local iDelta = 0; mDelta = 0
            local dragCount = tonumber(iup.GetAttributeId(h, 'CHILDCOUNT', drag_id))
            if  drag_id > drop_id then iDelta = dragCount + 1; mDelta = 1 end

            if  iup.GetAttributeId(h, 'KIND', drop_id) ~= 'BRANCH' then drop_id = iup.GetAttributeId(h, 'PARENT', drop_id) end

            iup.SetAttributeId(h, "STATE", drop_id, 'COLLAPSED')
            iup.SetAttributeId(h, "INSERTBRANCH", drop_id, iup.GetAttributeId(h, 'TITLE', drag_id))

            for i = 1,  dragCount do
                iup.SetAttributeId(h, "ADDLEAF", h.lastaddnode , iup.GetAttributeId(h, 'TITLE', drag_id + i + i * mDelta))
                h:SetUserId(h.lastaddnode, h:GetUserId(drag_id + i + (i + 1) * mDelta))
            end
            iup.SetAttributeId(h, 'DELNODE', drag_id + (dragCount + 1) * mDelta, 'SELECTED')
            return -1
        end
        return -4
    end

    tree_plugins = iup.tree{size = '120x', showdragdrop = 'YES', button_cb = button_cb, dragdrop_cb = function() return -1 end}

    tree_right = iup.tree{size = '120x', showdragdrop = 'YES', button_cb = button_cb, dragdrop_cb = dragdrop_cb, rightclick_cb = rightclick_cb}

    local vbox = iup.vbox{
        iup.hbox{iup.vbox{tree_plugins},tree_right};
        iup.hbox{btn_ok, iup.fill{}, btn_esc},
        expandchildren ='YES',gap=2,margin="4x4"}
    dlg = iup.scitedialog{vbox; title="Ёлементы панелей инструментов",defaultenter="TOOLBARSETT_BTN_OK",defaultesc="TOOLBARSETT_BTN_ESC",tabsize=editor.TabWidth,
        maxbox="NO",minbox ="NO",resize ="YES",shrink ="YES",sciteparent="SCITE", sciteid="toolbarlayout", minsize='530x400'}


    dlg.show_cb=(function(h,state)
        if state == 4 then
            dlg:postdestroy()
        end
    end)

    iup.SetAttributeId(tree_right,"TITLE", 0, "ѕанели инстументов")
    iup.SetAttributeId(tree_plugins,"TITLE", 0, "Ќеиспользуемые элементы")
    iup.SetAttributeId(tree_right,"ADDBRANCH", 0, "<Bar>")

    tree_right:SetUserId(0, '')

    local table_dir = shell.findfiles(defpath..'*.lua')

    local j = 0
    local function RestoreTree(h, str)
        if str == '' then return end
        iup.SetAttributeId(h, "DELNODE", 1, "SELECTED")
        local k = 0
        local lastBr
        for p in str:gmatch('[^¶]+') do
            local _,_, pname, pf = p:find('(.-)(ђ?)$')
            if pf ~= '' or k == 0 then
                if lastBr then
                    iup.SetAttributeId(h, "INSERTBRANCH", lastBr, '<Bar>')
                else
                    iup.SetAttributeId(h, "ADDBRANCH", k, '<Bar>')
                end
                k = k + 1
                lastBr = k
            end
            local bFound = false
            for i = 1, #table_dir do
                if table_dir[i].name == pname then
                    table.remove(table_dir, i)
                    bFound = true
                    break
                end
            end
            if bFound then
                local pI = dofile(props["SciteDefaultHome"].."\\tools\\UIPlugins\\"..pname)
                iup.SetAttributeId(h, "ADDLEAF", k, pI.title)
                k = k + 1
                h:SetUserId(k, pname)
            end
        end
    end

    RestoreTree(tree_right, _G.iuprops["settings.toolbars.layout"] or '')

    for i = 1, #table_dir do
        local pI = dofile(defpath..table_dir[i].name)
        if pI and pI.toolbar then
            iup.SetAttributeId(tree_plugins, "ADDLEAF", j, pI.title)
            j = j + 1
            tree_plugins:SetUserId(j, table_dir[i].name)
        end
    end

end

Show()
