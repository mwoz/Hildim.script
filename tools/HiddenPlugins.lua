--[[Диалог редактирования горячих клавиш]]
--[[Диалог редактирования списка подгружаемых плагинов(комманд)]]

local function Run(flag)
    local tPlugins = {}
    local tblView = {}
    local tblUsers, defpath, settName, sTitle, fCond
    local checkItems, checkTitle
    local clrUsed = '255 0 0'
    if flag == 'Commands' then
        defpath = props["SciteDefaultHome"].."\\tools\\Commands\\"
        settName = "settings.commands.plugins"
        sTitle = "Загрузка команд"
        fCond = function() return true end
    elseif flag == 'Status' then
        defpath = props["SciteDefaultHome"].."\\tools\\UIPlugins\\"
        settName = "settings.status.layout"
        sTitle = "Загрузка плагинов строки состояния"
        fCond = function(pI) return pI.statusbar end
        checkItems = 'settings.hidden.plugins'
        checkTitle = 'Hidden Plugin'
    else
        defpath = props["SciteDefaultHome"].."\\tools\\UIPlugins\\"
        settName = "settings.hidden.plugins"
        sTitle = "Загрузка фоновых плагинов"
        fCond = function(pI) return pI.hidden end
        checkItems = 'settings.status.layout'
        checkTitle = 'Status Bar'
    end

    local function Show()

        local list_lex, dlg, bBlockReset, tree_right, tree_plugins
        local btn_ok = iup.button  {title = "OK"}
        local btn_esc = iup.button  {title = "Cancel"}
        iup.SetHandle("TOOLBARSETT_BTN_OK", btn_ok)
        iup.SetHandle("TOOLBARSETT_BTN_ESC", btn_esc)
        btn_esc.action = function()
            dlg:hide()
            dlg:postdestroy()
        end

        local function onTip(h, x, y)
            local l = iup.ConvertXYToPos(h, x, y)
            local t = tPlugins[h:GetUserId(l)]
            if t then h.tip = t.description
            else h.tip = "" end
        end

        local function CheckInstall(strUi, bUnInstoll)
            local tPoints = {["settings.toolbars.layout"] = "Tool Bar",
                ["settings.user.rightbar"] = "Right User Bar",
                ["settings.user.leftbar"] = "Left User Bar",
                [checkItems] = checkTitle,
            }
            for s, m in pairs(tPoints) do
                local tUp = _G.iuprops[s] or {}
                if s == "settings.status.layout" or s == "settings.hidden.plugins" then tUp = {tUp} end
                for i = 1, #tUp do
                    for j = 1,  #(tUp[i]) do
                        if tUp[i][j] == strUi then
                            if bUnInstoll then
                                table.remove(tUp[i], j)
                                if s == "settings.status.layout"  or s == "settings.hidden.plugins" then
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
            local t = { tree_plugins, tree_right}
            for i = 1, 2 do
                _, _, wx, wy = t[i].position:find('(%d*),(%d*)')
                local _, _, dx, dy = t[i].rastersize:find('(%d*)x(%d*)')
                wx = tonumber(wx); wy = tonumber(wy); dx = tonumber(dx); dy = tonumber(dy)
                if wx <= x and x <= wx + dx and wy <= y and y <= wy + dy then
                    x = x - wx; y = y - wy
                    return t[i], iup.ConvertXYToPos(t[i], x, y)
                end
            end
        end

        btn_ok.action = function()
            local function SaveTree(h)
                local tbl = {}
                for i = 1, iup.GetAttribute(h, "TOTALCHILDCOUNT0") do
                    table.insert(tbl, h:GetUserId(i))
                    if checkItems then CheckInstall(h:GetUserId(i), true) end
                end
                return tbl
            end
            _G.iuprops[settName] = SaveTree(tree_right)
            dlg:hide()
            dlg:postdestroy()
            scite.RunAsync(iup.ReloadScript)
        end

        local dragName, dragPath, drag_id

        local idSrc
        local helpid
        local function help_cb(h)
            local _, _, xC, yC = iup.GetGlobal('CURSORPOS'):find('(%d+)x(%d+)')
            local _, _, xO, yO = dlg.clientoffset:find('(%d+)x(%d+)')
            local _, _, xH, yH = h.position:find('(%d+),(%d+)')

            local itm = iup.ConvertXYToPos(h, tonumber(xC) - tonumber(dlg.x) - tonumber(xO) - tonumber(xH),
                                  tonumber(yC) - tonumber(dlg.y) - tonumber(yO) - tonumber(yH))
            local plg = tPlugins[h:GetUserId(tonumber(itm))]
            if plg then
                helpid = plg.code or h:GetUserId(tonumber(itm)):gsub('%..*$','')
                if plg.hlpdevice then helpid = plg.hlpdevice..'::'..helpid end
            end
        end

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
                    if iup.GetAttributeId(h, 'KIND', idSrc) ~= 'BRANCH' then
                        local pPlase, uId
                        if flag ~= 'Commands' then
                            uId = h:GetUserId(idSrc)
                            pPlase = CheckInstall(uId, false)
                        end
                        if idTarget == 0 and iup.GetAttributeId(hTarget, "KIND", 1) == 'BRANCH' then return end

                        iup.SetAttributeId(hTarget, "ADDLEAF", idTarget, iup.GetAttributeId(h, 'TITLE', idSrc))
                        hTarget:SetUserId(hTarget.lastaddnode, h:GetUserId(idSrc))

                        iup.SetAttributeId(hTarget, "COLOR", hTarget.lastaddnode, iup.GetAttributeId(h, 'COLOR', idSrc))

                        iup.SetAttributeId(h, 'DELNODE', idSrc, 'SELECTED')
                        if pPlase and hTarget ~= tree_plugins then
                            print("Plugin '"..uId.."' is already connected to "..pPlase..". Will be reconnected if you continue")
                        end
                    end
                end
            end
        end

        tree_plugins = iup.tree{size = '120x', showdragdrop = 'YES', button_cb = button_cb, tips_cb = onTip, tip = 'xxx', dragdrop_cb = function() return - 1 end; help_cb = help_cb}

        tree_right = iup.tree{size = '120x', showdragdrop = 'YES', button_cb = button_cb, tips_cb = onTip, tip = 'xxx'; help_cb = help_cb}

        local vbox = iup.vbox{
            iup.hbox{iup.vbox{tree_plugins}, tree_right};
            iup.hbox{btn_ok, iup.fill{}, btn_esc},
        expandchildren = 'YES', gap = 2, margin = "4x4"}
        dlg = iup.scitedialog{vbox; title = sTitle, defaultenter = "TOOLBARSETT_BTN_OK", defaultesc = "TOOLBARSETT_BTN_ESC", tabsize = editor.TabWidth,
        maxbox = "NO", minbox = "NO", resize = "YES", shrink = "YES", sciteparent = "SCITE",
        sciteid = "commandsplugin", minsize = '530x400', helpbutton = Iif(flag ~= 'Commands', 'YES', 'NO')}

        dlg.show_cb =(function(h, state)
            if state == 4 then
                dlg:postdestroy()
            end
        end)

        iup.SetAttributeId(tree_right, "TITLE", 0, "Загружаемые элементы")
        iup.SetAttributeId(tree_plugins, "TITLE", 0, "Неиспользуемые элементы")

        tree_right:SetUserId(0, '')

        local table_dir = shell.findfiles(defpath..'*.lua')

        local j = 0
        local function RestoreTree(h, tbl)
            if #tbl == 0 then return end
            iup.SetAttributeId(h, "DELNODE", 1, "SELECTED")
            local k = 0
            local lastBr
            for i = 0, #tbl do
                p = tbl[i]
                local bFound = false
                for i = 1, #table_dir do
                    if table_dir[i].name == p then
                        table.remove(table_dir, i)
                        bFound = true
                        break
                    end
                end
                if bFound then
                    local r, err = pcall( function()
                        local pI = dofile(defpath..p)
                        if pI then tPlugins[p] = pI end
                        iup.SetAttributeId(h, "ADDLEAF", k, pI.title)
                        k = k + 1
                        h:SetUserId(k, p)
                    end)
                end
            end
        end

        RestoreTree(tree_right, _G.iuprops[settName] or {})

        for i = 1, #table_dir do
            local r, err = pcall( function()
                local pI = dofile(defpath..table_dir[i].name)
                if type(pI) == 'table'then
                    if pI then tPlugins[table_dir[i].name] = pI end

                    if pI and fCond(pI) then
                        iup.SetAttributeId(tree_plugins, "ADDLEAF", j, pI.title)
                        j = j + 1
                        tree_plugins:SetUserId(j, table_dir[i].name)
                        if flag ~= 'Commands' and CheckInstall(table_dir[i].name, false) then
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
end

return Run


