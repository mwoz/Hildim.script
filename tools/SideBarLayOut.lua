--[[Диалог редактирования горячих клавиш]]
local tblView = {}, tblUsers
local defpath = props["SciteDefaultHome"].."\\tools\\UIPlugins\\"

local function Show()

    local list_lex, dlg, bBlockReset, tree_right, tree_left, tree_plugins
    local btn_ok = iup.button  {title = _TH"OK"}
    local btn_esc = iup.button  {title = _TH"Cancel"}
    local clrUsed = '255 0 0'
    local tPlugins = {}
    iup.SetHandle("SIDEBARSETT_BTN_OK", btn_ok)
    iup.SetHandle("SIDEBARSETT_BTN_ESC", btn_esc)
    btn_esc.action = function()
        dlg:hide()
        dlg:postdestroy()
    end

    local function CheckInstall(strUi, bUnInstoll)
        local tPoints = {["settings.toolbars.layout"] = "Tool Bar",
            ["settings.hidden.plugins"] = "Hidden Plugins",
            ["settings.status.layout"] = "Status Bar",
        }
        for s, m in pairs(tPoints) do
            local tUp = _G.iuprops[s] or {}
            if s == "settings.status.layout" or s == "settings.hidden.plugins"  then tUp = {tUp} end
            for i = 1, #tUp do
                for j = 1,  #(tUp[i]) do
                    if tUp[i][j] == strUi then
                        if bUnInstoll then
                            table.remove(tUp[i], j)
                            if s == "settings.status.layout" or s == "settings.hidden.plugins" then
                                _G.iuprops[s] = tUp[i]
                            else
                                _G.iuprops[s] = tUp
                            end
                        end
                        return m
                    end
                end
            end
        end
    end

    local function ConvertXY2WndPos(h, x, y)
        local _, _, wx, wy = h.position:find('(%d*),(%d*)')
        wx = tonumber(wx); wy = tonumber(wy)
        x = x + wx; y = y + wy
        local t = {tree_left, tree_plugins, tree_right}
        for i = 1, 3 do
            _, _, wx, wy = t[i].position:find('(%d*),(%d*)')
            local _, _, dx, dy = t[i].rastersize:find('(%d*)x(%d*)')
            wx = tonumber(wx); wy = tonumber(wy); dx = tonumber(dx); dy = tonumber(dy)
            if wx <= x and x <= wx + dx and wy <= y and y <= wy + dy then
                x = x - wx; y = y - wy
                return t[i], iup.ConvertXYToPos(t[i], x, y)
            end
        end
    end

    local function onTip(h, x, y)
        local l = iup.ConvertXYToPos(h, x, y)
        local t = tPlugins[h:GetUserId(l)]
        if t then h.tip = t.description
        else h.tip = "" end
    end

    local helpid
    local function help_cb(h)
        local _, _, xC, yC = iup.GetGlobal('CURSORPOS'):find('(%d+)x(%d+)')
        local _, _, xO, yO = dlg.clientoffset:find('(%d+)x(%d+)')
        local _, _, xH, yH = h.position:find('(%d+),(%d+)')

        local itm = iup.ConvertXYToPos(h, tonumber(xC) - tonumber(dlg.x) - tonumber(xO) - tonumber(xH),
        tonumber(yC) - tonumber(dlg.y) - tonumber(yO) - tonumber(yH))
        local plg = tPlugins[h:GetUserId(tonumber(itm))]
        if plg then
            helpid = plg.code or h:GetUserId(tonumber(itm)):gsub('%..*$', '')
            if plg.hlpdevice then helpid = plg.hlpdevice..'::'..helpid end
        end
    end

    btn_ok.action = function()
        local function SaveTree(h)
            local tbl = {}
            local tblB
            for i = 1, iup.GetAttribute(h, "TOTALCHILDCOUNT0") do
                if iup.GetAttributeId(h, "KIND", i) == "BRANCH" then
                    tblB = {title = iup.GetAttributeId(h, "TITLE", i)}
                    table.insert(tbl, tblB)
                else
                    table.insert(tblB, h:GetUserId(i))
                    CheckInstall(h:GetUserId(i), true)
                end

            end
            return tbl
        end
        _G.iuprops["settings.user.leftbar"] = SaveTree(tree_left)
        _G.iuprops["settings.user.rightbar"] = SaveTree(tree_right)

        dlg:hide()
        dlg:postdestroy()
        scite.RunAsync(iup.ReloadScript)
    end

    local dragName, dragPath, drag_id

    local idSrc
    local function button_cb(h, button, pressed, x, y, status)
        if button ~= 49 then return end
        if pressed == 1 then
            idSrc = iup.ConvertXYToPos(h, x, y)
        elseif helpid then
            CORE.HelpUI(helpid, nil)
            helpid = nil
        else
            local hTarget, idTarget = ConvertXY2WndPos(h, x, y)
            if hTarget and hTarget ~= h and idSrc > 0 then
                if idTarget < 0 then idTarget = tonumber(iup.GetAttribute(hTarget, 'COUNT')) - 1 end
                if iup.GetAttributeId(h, 'KIND', idSrc) == 'BRANCH' then
                    if hTarget ~= tree_plugins then
                        if iup.GetAttributeId(hTarget, 'KIND', idTarget) ~= 'BRANCH' then
                            idTarget = iup.GetAttributeId(hTarget, 'PARENT', idTarget)
                        end
                        if tonumber(idTarget) > 0 then
                            iup.SetAttributeId(hTarget, "STATE", idTarget, 'COLLAPSED')
                            iup.SetAttributeId(hTarget, "INSERTBRANCH", idTarget, iup.GetAttributeId(h, 'TITLE', idSrc))
                        else
                            iup.SetAttributeId(hTarget, "ADDBRANCH", idTarget, iup.GetAttributeId(h, 'TITLE', idSrc))
                        end

                    end
                    for i = 1, iup.GetAttribute(h, "TOTALCHILDCOUNT", idSrc) do
                        iup.SetAttributeId(hTarget, "ADDLEAF", hTarget.lastaddnode or 0, iup.GetAttributeId(h, 'TITLE', idSrc + i))
                        hTarget:SetUserId(hTarget.lastaddnode, h:GetUserId(idSrc + i))
                    end
                    iup.SetAttributeId(h, 'DELNODE', idSrc, 'SELECTED')
                else
                    local pPlase = CheckInstall(h:GetUserId(idSrc), false)
                    if idTarget == 0 and iup.GetAttributeId(hTarget, "KIND", 1) == 'BRANCH' then return end

                    iup.SetAttributeId(hTarget, "ADDLEAF", idTarget, iup.GetAttributeId(h, 'TITLE', idSrc))
                    hTarget:SetUserId(hTarget.lastaddnode, h:GetUserId(idSrc))
                    if pPlase and h == tree_plugins then
                        print("Plugin '"..h:GetUserId(idSrc).."' is already connected to "..pPlase..". Will be reconnected if you continue")
                    end
                    iup.SetAttributeId(h, 'DELNODE', idSrc, 'SELECTED')
                end
            end
        end
    end

    local function showrename_cb(h, id)
        if iup.GetAttributeId(h, "KIND", id) == "BRANCH" and not h:GetUserId(id) then return true end
        return - 1
    end

    local function rightclick_cb(h, id)
        iup.menu
        {
            iup.item{title = "Add Tab", action = function()
                iup.SetAttributeId(h, "ADDBRANCH", 0, "<New Tab>")
            end};
        }:popup(iup.MOUSEPOS, iup.MOUSEPOS)
    end

    local function dragdrop_cb(h, drag_id, drop_id, isshift, iscontrol)
        if iscontrol == 1 or h == tree_plugins or (drop_id == 0 and iup.GetAttributeId(h, 'KIND', drag_id) == 'LEAF') then return - 1 end

        if iup.GetAttributeId(h, 'KIND', drag_id) == 'BRANCH' then
            local iDelta = 0; mDelta = 0
            local dragCount = tonumber(iup.GetAttributeId(h, 'CHILDCOUNT', drag_id))
            if drag_id > drop_id then iDelta = dragCount + 1; mDelta = 1 end

            if iup.GetAttributeId(h, 'KIND', drop_id) ~= 'BRANCH' then drop_id = iup.GetAttributeId(h, 'PARENT', drop_id) end

            if drop_id == 0 then
                iup.SetAttributeId(h, "ADDBRANCH", drop_id, iup.GetAttributeId(h, 'TITLE', drag_id))
            else
                iup.SetAttributeId(h, "STATE", drop_id, 'COLLAPSED')
                iup.SetAttributeId(h, "INSERTBRANCH", drop_id, iup.GetAttributeId(h, 'TITLE', drag_id))
            end

            for i = 1, dragCount do
                iup.SetAttributeId(h, "ADDLEAF", h.lastaddnode , iup.GetAttributeId(h, 'TITLE', drag_id + i + i * mDelta))
                h:SetUserId(h.lastaddnode, h:GetUserId(drag_id + i + (i + 1) * mDelta))
            end
            iup.SetAttributeId(h, 'DELNODE', drag_id + (dragCount + 1) * mDelta, 'SELECTED')
            return - 1
        elseif drop_id == 0 then drop_id = 1
        end
        if iup.GetAttributeId(h, 'KIND', drop_id) == 'BRANCH' then
            mDelta = Iif(drag_id > drop_id, 1, 0)
            iup.SetAttributeId(h, "STATE", drop_id, 'EXPANDED')
            iup.SetAttributeId(h, "ADDLEAF", drop_id , iup.GetAttributeId(h, 'TITLE', drag_id))
            h:SetUserId(h.lastaddnode, h:GetUserId(drag_id + mDelta))
            iup.SetAttributeId(h, 'DELNODE', drag_id + mDelta, 'SELECTED')
            return - 1
        end
        return - 4
    end

    tree_plugins = iup.tree{size = '120x', showdragdrop = 'YES', button_cb = button_cb, dragdrop_cb = function() return - 1 end, tips_cb = onTip, tip = 'xxx'; help_cb = help_cb}

    tree_right = iup.tree{size = '120x', showrename = 'YES', showdragdrop = 'YES', button_cb = button_cb, dragdrop_cb = dragdrop_cb, rightclick_cb = rightclick_cb, showrename_cb = showrename_cb, tips_cb = onTip, tip = 'xxx'; help_cb = help_cb}

    tree_left = iup.tree{size = '120x', showrename = 'YES', showdragdrop = 'YES', button_cb = button_cb, dragdrop_cb = dragdrop_cb, rightclick_cb = rightclick_cb, showrename_cb = showrename_cb, tips_cb = onTip, tip = 'xxx'; help_cb = help_cb}

    local vbox = iup.vbox{
        iup.hbox{tree_left, iup.vbox{tree_plugins}, tree_right};
        iup.hbox{btn_ok, iup.fill{}, btn_esc},
    expandchildren = 'YES', gap = 2, margin = "4x4"}
    dlg = iup.scitedialog{vbox; title = _T"Sidebars Settings", defaultenter = "SIDEBARSETT_BTN_OK", defaultesc = "SIDEBARSETT_BTN_ESC", tabsize =editor.TabWidth,
    maxbox = "NO", minbox = "NO", resize = "YES", shrink = "YES", sciteparent = "SCITE", sciteid = "sidebarlayout", minsize = '800x400', helpbutton = 'YES'}


    dlg.show_cb =(function(h, state)
        if state == 4 then
            dlg:postdestroy()
        end
    end)

    iup.SetAttributeId(tree_left, "TITLE", 0, _T"Left Bar")
    iup.SetAttributeId(tree_right, "TITLE", 0, _T"Right Bar")
    iup.SetAttributeId(tree_plugins, "TITLE", 0, _T"Available Plugins")
    iup.SetAttributeId(tree_left, "ADDBRANCH", 0, "<New Tab>")
    iup.SetAttributeId(tree_right, "ADDBRANCH", 0, "<New Tab>")

    tree_left:SetUserId(0, '')
    tree_right:SetUserId(0, '')

    local table_dir = shell.findfiles(defpath..'*.lua')

    local j = 0
    local function RestoreTree(h, tbl)
        if #tbl == '' then return end
        iup.SetAttributeId(h, "DELNODE", 1, "SELECTED")
        local k = 0
        local lastBr

        for i = 1,  #tbl do
            if i > 1 then
                iup.SetAttributeId(h, "INSERTBRANCH", lastBr, tbl[i].title)
            else
                iup.SetAttributeId(h, "ADDBRANCH", k, tbl[i].title)
            end
            k = k + 1
            lastBr = k
            for j = 1,  #(tbl[i]) do
                local bFound = false
                local pname = tbl[i][j]
                for k = 1, #table_dir do
                    if table_dir[k].name == pname then
                        table.remove(table_dir, k)
                        bFound = true
                        break
                    end
                end
                if bFound then
                    local pI = dofile(props["SciteDefaultHome"].."\\tools\\UIPlugins\\"..pname)
                    if pI then tPlugins[pname] = pI end
                    iup.SetAttributeId(h, "ADDLEAF", k, pI.title)
                    k = k + 1
                    h:SetUserId(k, pname)
                end
            end
        end
    end

    RestoreTree(tree_right, _G.iuprops["settings.user.rightbar"] or {})
    RestoreTree(tree_left, _G.iuprops["settings.user.leftbar"] or {})

    for i = 1, #table_dir do
        local r, err = pcall( function()
            local pI = dofile(defpath..table_dir[i].name)
            if type(pI) == 'table'then
                if pI then tPlugins[table_dir[i].name] = pI end
                if pI and pI.sidebar then
                    iup.SetAttributeId(tree_plugins, "ADDLEAF", j, pI.title)
                    j = j + 1
                    tree_plugins:SetUserId(j, table_dir[i].name)
                    if CheckInstall(table_dir[i].name, false) then
                        iup.SetAttributeId(tree_plugins, "COLOR", j, clrUsed)
                    end
                end
            end
        end)
        if not r then
            print(err)
            print(defpath..table_dir[i].name)
        end
    end

end

Show()
