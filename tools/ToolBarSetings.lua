--[[ƒиалог редактировани€ гор€чих клавиш]]
require "menuhandler"
local tblView = {}, tblUsers
local defpath = props["scite.userhome"].."\\userMenuBars.lua"

local function viewMenu(tMnu, tView, path)
    local tN, tSub
    for i,t in ipairs(tMnu) do
        tN = {}
        local tui = {}
        if not t.link then
            if t[2] == nil then
                tN.leafname = menuhandler:get_title(t, true)
                if t.separator then
                    tN.leafname = '-----------'
                    tui.separator = true
                else
                    tui.path = path..'¶'..t[1]
                    local keyStr
                    if t.key then
                        tui.default = t.key
                        keyStr = t.key
                    end
                    if tblUsers and tblUsers[tui.path] then
                        tN.color = "92 92 255"
                        tui.user = tblUsers[tui.path]
                        keyStr = tblUsers[tui.path]
                    end
                    if keyStr then tN.leafname = tN.leafname..'  Л'..keyStr..'Ы' end
                    if t.image then tN.image = t.image; tui.image = t.image; end
                    tui.title = menuhandler:get_title(t, true)
                end
            elseif type(t[2]) == 'table' then
                --tSub = {}
                tN = {}
                tN.branchname = menuhandler:get_title(t, true)
                viewMenu(t[2], tN, path..'¶'..t[1])
            end
        end
        tN.userid = tui
        table.insert(tView, tN)
    end
end

local function Show()

    local list_lex, dlg, bBlockReset, tree_btns, tree_hk
    local btn_ok = iup.button  {title="OK"}
    local btn_esc = iup.button  {title="Cancel"}
    iup.SetHandle("TOOLBARSETT_BTN_OK",btn_ok)
    iup.SetHandle("TOOLBARSETT_BTN_ESC",btn_esc)
    btn_esc.action = function()
        dlg:hide()
        dlg:postdestroy()
    end

    btn_ok.action = function()
        local str = ''
        for i = 1,  iup.GetAttribute(tree_btns, "TOTALCHILDCOUNT0") do
            local p = tree_btns:GetUserId(i) or '---'
            if str ~= '' then str = str..'З' end
            str = str..p
        end
        _G.iuprops["settings.user.toolbar"] = str
        dlg:hide()
        dlg:postdestroy()
        scite.RunAsync(iup.ReloadScript)
    end

    local function ConvertXY2WndPos(h, x, y)
        local _,_,wx,wy = h.position:find('(%d*),(%d*)')
        wx = tonumber(wx); wy = tonumber(wy)
        x = x + wx; y = y + wy
        local t = {tree_hk, tree_btns}
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

    tree_hk = iup.tree{minsize = '0x5', size='200x', showdragdrop = 'YES', dragdrop_cb = function() return -1 end,imageexpanded0 = 'tree_µ',
                            branchclose_cb = function(h) if h.value=='0' then return -1 end end}

    local idSrc
    tree_hk.button_cb = function(h, button, pressed, x, y, status)
        if button ~= 49 then return end
        if pressed == 1 then
            idSrc = iup.ConvertXYToPos(h, x, y)
        else
           local hTarget, idTarget = ConvertXY2WndPos(h, x, y)
           if hTarget and hTarget ~= h and idSrc > 0 then
                if idTarget < 0 then idTarget = tonumber(iup.GetAttribute(hTarget, 'COUNT')) - 1 end
                if iup.GetAttributeId(h, "KIND", idSrc) == 'BRANCH' then return end
                local tui = tree_hk:GetUserId(idSrc)
                if tui.added then return end

                iup.SetAttributeId(hTarget, "ADDLEAF", idTarget, iup.GetAttributeId(h, 'TITLE', idSrc))
                iup.SetAttributeId(hTarget, "IMAGE", hTarget.lastaddnode, tui.image)

                if not tui.separator then
                    hTarget:SetUserId(hTarget.lastaddnode, tui.path)
                    iup.SetAttributeId(h, 'COLOR', idSrc, '92 92 255')
                    tui.added = true
                    tree_hk:GetUserId(idSrc, tui)
                end
            end
        end
    end


    tree_btns = iup.tree{minsize = '0x5', size='200x', showdragdrop = 'YES', imageexpanded0 = 'tree_µ',
                            title0 = "User Tool Bar",
                            branchclose_cb = function(h) if h.value=='0' then return -1 end end}
    tree_btns.button_cb = function(h, button, pressed, x, y, status)
        if button ~= 49 then return end
        if pressed == 1 then
            idSrc = iup.ConvertXYToPos(h, x, y)
        else
            local hTarget, idTarget = ConvertXY2WndPos(h, x, y)
            if hTarget and hTarget ~= h and idSrc > 0 then
                if h:GetUserId(idSrc) then
                    for i = 1,  iup.GetAttribute(tree_hk, "TOTALCHILDCOUNT0") do
                        local tui = tree_hk:GetUserId(i)
                        if tui and h:GetUserId(idSrc) == tui.path then
                            iup.SetAttributeId(tree_hk, 'COLOR', i, '0 0 0')
                            tui.added = false
                            tree_hk:SetUserId(i, tui)
                            break
                        end
                    end
                end
                iup.SetAttributeId(h, "DELNODE", idSrc, "SELECTED")
            end
        end
    end

    local vbox = iup.vbox{
        iup.hbox{iup.vbox{tree_hk},tree_btns};
        iup.hbox{btn_ok, iup.fill{}, btn_esc},
        expandchildren ='YES',gap=2,margin="4x4"}
    dlg = iup.scitedialog{vbox; title="Ќастройка пользовательской панели инструментов",defaultenter="TOOLBARSETT_BTN_OK",defaultesc="TOOLBARSETT_BTN_ESC",tabsize=editor.TabWidth,
        maxbox="NO",minbox ="NO",resize ="YES",shrink ="YES",sciteparent="SCITE", sciteid="usertb", minsize='300x600'}

    dlg.show_cb=(function(h,state)
        if state == 4 then
            dlg:postdestroy()
        end
    end)
    if shell.fileexists(defpath) then tblUsers = assert(loadfile(defpath))() end
    tblView.branchname = 'Menus'
    --viewMenu(sys_Menus.MainWindowMenu, tblView, 'MainWindowMenu')

    for ups,submnu in pairs(sys_Menus) do
        local tb = {}
        tb.branchname = ups
        table.insert(tblView, 0, tb)
        viewMenu(submnu, tb, ups)
    end

    tree_hk.autoredraw = 'NO'
    iup.TreeAddNodes(tree_hk, tblView)
    tree_hk.autoredraw = 'YES'

    local str = _G.iuprops["settings.user.toolbar"] or ''
    local id = 0
    for p in str:gmatch('[^З]*') do
        if p == '---' then
            iup.SetAttributeId(tree_btns,"ADDLEAF", id, '-----------')
            id = iup.GetAttribute(tree_btns, 'LASTADDNODE')
        else
            for i = 1,  iup.GetAttribute(tree_hk, "TOTALCHILDCOUNT0") do
                local tui = tree_hk:GetUserId(i)
                if tui and tui.path == p then
                    iup.SetAttributeId(tree_hk, 'COLOR', i, '92 92 255')
                    tui.added = true
                    tree_hk:SetUserId(i, tui)


                    iup.SetAttributeId(tree_btns,"ADDLEAF", id, iup.GetAttributeId(tree_hk, 'TITLE', i))
                    id = iup.GetAttribute(tree_btns, 'LASTADDNODE')
                    iup.SetAttributeId(tree_btns,"IMAGE", id, tui.image)

                    tree_btns:SetUserId(id, tui.path)

                    break
                end
            end
        end
    end

end

Show()
