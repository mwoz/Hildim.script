--[[ƒиалог редактировани€ гор€чих клавиш]]
require "menuhandler"
local tblView = {}, tblUsers
local defpath = props["scite.userhome"].."\\userHotKeys.lua"

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
                    tui.disabled = true
                else
                    tui.path = path..'|'..t[1]
                    local keyStr
                    if t.key_external then
                        tui.disabled = true
                        tN.color = "255 92 92"
                    end
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
                    if t.image then tN.image = t.image end
                    tui.title = menuhandler:get_title(t, true)
                end
            elseif type(t[2]) == 'table' then
                --tSub = {}
                tN = {}
                tN.branchname = menuhandler:get_title(t, true)
                viewMenu(t[2], tN, path..'|'..t[1])
                ---tN[1] = tSub
                tui.disabled = true
            end
        end
        tN.userid = tui
        table.insert(tView, tN)
    end
end

local function Show()

    local list_lex, dlg, bBlockReset
    local btn_ok = iup.button  {title="OK", help_cb = help_cb}
    local btn_esc = iup.button  {title="Cancel", help_cb = help_cb}
    iup.SetHandle("HK_BTN_OK",btn_ok)
    iup.SetHandle("HK_BTN_ESC",btn_esc)
    btn_esc.action = function()
        bBlockReset = true
        dlg:hide()
        dlg:postdestroy()
    end

    local function help_cb()
        CORE.HelpUI("HotkeysSetup", nil)
    end

    local edit_hk, tree_hk, edit_find

    local function findMenu(start, val)
        local v = StringLower(val, 1251)
        for i = start, iup.GetAttribute(tree_hk, "TOTALCHILDCOUNT0") do
            local title = iup.GetAttributeId(tree_hk, 'TITLE', i)
            if StringLower(title, 1251):find('^'..v) then
                edit_hk.value = ''
                tree_hk.value = i
                tree_hk.selection_cb(tree_hk, i, 1)
                return true
            end
        end
        if start == 1 then
            edit_hk.value = ''
            tree_hk.value = 0
            tree_hk.selection_cb(tree_hk, 0, 1)
        else
            findMenu(1, val)
        end
    end

    edit_hk = iup.text{size='100x', help_cb = help_cb}
    edit_find = iup.text{expand = 'HORIZONTAL'; action = function(h, c, new_val)
        if c ~= 27 then
            findMenu(1, new_val)
        end
    end;
    k_any = function(h, k)
        if k == iup.K_F3 then
            findMenu(tonumber(tree_hk.value) + 1, h.value)
            return -1
        end
    end}

    btn_ok.action = function()
        local str = ''
        for i = 1,  iup.GetAttribute(tree_hk, "TOTALCHILDCOUNT0") do
            local tuid = tree_hk:GetUserId(i)
            if tuid and tuid.user and tuid.default ~= tuid.user then
                str = str..'["'..tuid.path..'"] = "'..tuid.user..'";\n'
            end
        end
        str = 'return {\n'..str..'}'
        local f = io.open(defpath, "w")
        f:write(str)
        f:flush()
        f:close()
        bBlockReset = true
        dlg:hide()
        dlg:postdestroy()
        menuhandler:RegistryHotKeys()
    end

    local function resetVal()
        if tonumber(tree_hk.value) > 0 then
            local id = tonumber(tree_hk.value)
            if iup.GetAttributeId(tree_hk, 'KIND', id) == 'BRANCH' then return end
            local tuid = tree_hk:GetUserId(id)
            local t = tuid.title
            if edit_hk.value ~= '' then t = t..' Л'..edit_hk.value..'Ы' end
            if edit_hk.value ~= (tuid.default or '') then
                tuid.user = edit_hk.value
                iup.SetAttributeId(tree_hk, 'COLOR', id, '92 92 255')
            else
                tuid.user = nil
                iup.SetAttributeId(tree_hk, 'COLOR', id, '0 0 0')
            end
            tree_hk:SetUserId(id,tuid)
            iup.SetAttributeId(tree_hk, 'TITLE', id, t)
        end
    end

    edit_hk.k_any = function(h,k)
        local modif = iup.GetGlobal('MODKEYSTATE')--,iup.KeyCodeToName(k))
        local val = ''
        local bMod = false
        if modif:find('A') then val = 'Alt+'; bMod = true end
        if modif:find('C') then val = val..'Ctrl+'; bMod = true end
        if modif:find('S') then val = val..'Shift+' end
        local kStr = iup.KeyCodeToName(k):gsub('^K_', ''):gsub('^[mcs]?([A-Z0-9])', '%1')
        kStr = kStr:lower():gsub('^(.)', function(s) return s:upper() end)
        if kStr == 'Pgdn' then kStr = 'PageDown'
        elseif kStr == 'Pgup' then kStr = 'PageUp'
        elseif kStr == 'Bracketright' then kStr = ']'
        elseif kStr == 'Bracketleft' then kStr = '['
        elseif kStr == 'Period' then kStr = '>'
        elseif kStr == 'Comma' then kStr = '<'
        elseif kStr == 'Backslash' then kStr = '\\'
        elseif kStr == 'Slash' then kStr = '?'
        elseif kStr == 'Minus' then kStr = '-'
        elseif kStr == 'Equal' then kStr = '+'  --??
        elseif kStr == 'Parentright' then kStr = '0'
        elseif kStr == 'Parentleft' then kStr = '9'
        elseif kStr == 'Exclam' then kStr = '1'
        elseif kStr == 'At' then kStr = '2'
        elseif kStr == 'Numbersign' then kStr = '3'
        elseif kStr == 'Dollar' then kStr = '4'
        elseif kStr == 'Percent' then kStr = '5'
        elseif kStr == 'Circum' then kStr = '6'
        elseif kStr == 'Ampersand' then kStr = '7'
        elseif kStr == 'Asterisk' then kStr = '8'
        elseif kStr == 'Bs' or kStr == 'Del' or kStr == 'Sp' or kStr == 'Esc' then kStr = ''

        end
        local bSet
        if not string.find(',Lshift,Rshift,Lctrl,Rctrl,Lalt,Ralt,', ','..kStr..',', 1, true ) then val = val..kStr; bSet = true end
        if not bMod and #kStr == 1 then h.value = ''; return -1 end
        h.value = val
        h.caretpos = #val
        if bSet then iup.NextField(h) end
        return -1
    end

    local btn_default
    edit_hk.killfocus_cb = function(h)
        if h.value:sub(#h.value) == '+' then h.value = '' end
        if not bBlockReset then
            for i = 1,  iup.GetAttribute(tree_hk, "TOTALCHILDCOUNT0") do
                local title = iup.GetAttributeId(tree_hk, 'TITLE', i)
                if title:find('Л'..h.value..'Ы', 1, true) then
                    if tree_hk.value == i..'' then return end
                    result = iup.Alarm(' оманда "'..title..'" уже использует данный акселератор',
                        'ѕерейти к "'..title:gsub('Л.*', '')..'"?\n'..
                        'ѕереопределить '..h.value..', а дл€ "'..title:gsub('Л.*', '')..'" сбросить акселератор?\n'..
                        'ќтменить ввод?',
                        'ѕерейти',
                        'ѕереопределить',
                        'ќтменить')
                    if result == 1 then
                        tree_hk.value = i
                        tree_hk.selection_cb(tree_hk, i, 1)
                    elseif result == 2 then
                        local tuid = tree_hk:GetUserId(i)
                        tuid.user = nil
                        iup.SetAttributeId(tree_hk, 'TITLE', i, tuid.title)
                        iup.SetAttributeId(tree_hk, 'COLOR', i, Iif(tuid.default, '92 92 255', '0 0 0'))

                        resetVal()
                    else
                        btn_default.action()
                    end

                    return
                end
            end
            resetVal()
        end
        bBlockReset = false
    end

    btn_default = iup.button  {title="Default"}
    btn_default.action = function()
        if tonumber(tree_hk.value) > 0 then
            local id = tonumber(tree_hk.value)
            if iup.GetAttributeId(tree_hk, 'KIND', id) == 'BRANCH' then return end
            local tuid = tree_hk:GetUserId(id)
            local t = tuid.title
            if tuid.default then
                for i = 1, iup.GetAttribute(tree_hk, "TOTALCHILDCOUNT0") do
                    local title = iup.GetAttributeId(tree_hk, 'TITLE', i)
                    if title:find('Л'..tuid.default..'Ы', 1, true) then
                        if tree_hk.value == i..'' then return end
                        result = iup.Alarm(' оманда "'..title..'" уже использует акселератор '..tuid.default,
                            'ѕерейти к "'..title:gsub('Л.*', '')..'"?\n'..
                            '¬осстановить '..tuid.default..', а дл€ "'..title:gsub('Л.*', '')..'" сбросить акселератор?\n'..
                            'ќтменить операцию?',
                            'ѕерейти',
                            '¬осстановить',
                        'ќтменить')
                        if result == 1 then
                            tree_hk.value = i
                            tree_hk.selection_cb(tree_hk, i, 1)
                            return
                        elseif result == 2 then
                            local tuid2 = tree_hk:GetUserId(i)
                            tuid2.user = nil
                            iup.SetAttributeId(tree_hk, 'TITLE', i, tuid2.title)
                            iup.SetAttributeId(tree_hk, 'COLOR', i, Iif(tuid2.default, '92 92 255', '0 0 0'))

                            resetVal()
                        else
                            return
                        end
                    end
                end
                t = t..' Л'..tuid.default..'Ы'
                edit_hk.value = tuid.default
            else
                edit_hk.value = ''
            end
            tuid.user = nil
            iup.SetAttributeId(tree_hk, 'TITLE', id, t)
            iup.SetAttributeId(tree_hk, 'COLOR', id, '0 0 0')
        end
    end

    tree_hk = iup.tree{minsize = '0x5', size=_G.iuprops["sidebar.functions.tree_sol.size"],imageexpanded0 = 'tree_µ',
                            branchclose_cb = function(h) if h.value == '0' then return - 1 end end, help_cb = help_cb}
    tree_hk.selection_cb = function(h,id, status)
        if status == 1 then
            bBlockReset = false
            local _,_,k = iup.GetAttributeId(tree_hk, "TITLE", id):find('Л(.*)Ы')
            local tuid = tree_hk:GetUserId(id)
            if not tuid or tuid.disabled then
                edit_hk.active = 'NO'
                btn_default.active = 'NO'
            else
                edit_hk.active = 'YES'
                btn_default.active = 'YES'
            end
            if k then edit_hk.value = k end
        else
            bBlockReset = true
            edit_hk.value = ''
            edit_hk.active = 'NO'
            btn_default.active = 'NO'
        end
    end
    tree_hk.button_cb = function(h,button, pressed, x, y, status)
        if iup.isbutton1(status) and pressed == 0 then
            local id = iup.ConvertXYToPos(h,x,y)
            if iup.GetAttributeId(tree_hk, 'KIND', id) ~= 'BRANCH' then  iup.SetFocus(edit_hk);edit_hk.caretpos = #edit_hk.value end
        end
    end

    local vbox = iup.vbox{
        iup.hbox{iup.label{title="ѕоиск:"}, edit_find,iup.label{title="<F3> - следующий результат"}, gap=15};
        iup.hbox{iup.vbox{tree_hk}};
        iup.hbox{edit_hk, btn_default, gap='15'},
        iup.hbox{btn_ok, iup.fill{}, btn_esc},
        expandchildren ='YES',gap=2,margin="4x4"}
    dlg = iup.scitedialog{vbox; title="Ќастройка гор€чих клавиш",defaultenter="HK_BTN_OK",defaultesc="HK_BTN_ESC",tabsize=editor.TabWidth,
        maxbox="NO",minbox ="NO",resize ="YES",shrink ="YES",sciteparent="SCITE", sciteid="HotkeysSetup", minsize='300x600', helpbutton = 'YES'}

    dlg.show_cb=(function(h,state)
        if state == 4 then
            dlg:postdestroy()
            menuhandler:RegistryHotKeys()
        end
    end)
    if shell.fileexists(defpath) then tblUsers = assert(loadfile(defpath))() end
    scite.RegistryHotKeys{}
    tblView.branchname = 'Menus'
    --viewMenu(sys_Menus.MainWindowMenu, tblView, 'MainWindowMenu')

    for ups,submnu in pairs(sys_Menus) do
        local tb = {}
        tb.branchname = submnu.title --ups
        table.insert(tblView, 1, tb)
        viewMenu(submnu, tb, ups)
    end
    tree_hk.autoredraw = 'NO'
    iup.TreeAddNodes(tree_hk, tblView)
    tree_hk.autoredraw = 'YES'

end

Show()
