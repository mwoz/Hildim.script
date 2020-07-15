local sys_KeysToMenus, labels, tPostponed
local waited_mnu, w_x, w_y = nil,nil, nil
local activeLabel = nil
local reselectedItem = nil
local clr_hgl = props['layout.txthlcolor']

local clr_select = props['layout.txtinactivcolor']
local clr_normal = props['layout.fgcolor']
local s = class()
local r_button
local bListenmouseHook = true
local mnemoShow = false

function s:Init()
    sys_KeysToMenus = {}
    labels = {}
    tPostponed = {}
    waited_mnu, w_x, w_y = nil,nil, nil
    activeLabel = nil
    reselectedItem = nil
end

function s:get_title(t, bShort, bStayAmp)
    local c = t.cpt or _TM(t[1])
    if not bShort and (t.user_hk or t.key) then c = c..'\t'..(t.user_hk or t.key) end
    if bStayAmp then return c end
    return c:gsub('&([^& ])', '%1')
end

local function getParam(p, bDef)
    local v,tp = bDef, type(p)
    if tp == 'boolean' then v = p
    elseif tp == 'function' then v = p()
    elseif tp == 'string' then v = assert(load('return '..p))() end
    return v
end

local function GetAction(mnu, bForse, bHotKey)
    local function doGetAction(mnu, bForse, bHotKey)
        if bForse or getParam(mnu.active, true) then
            local rez
            if mnu.action then
                local tp = type(mnu.action)
                if tp == 'number' then rez = function() scite.MenuCommand(mnu.action) end end
                if tp == 'string' then rez = assert(load('return '..mnu.action)) end
                if tp == 'function' then rez = mnu.action end
            end
            if mnu.check_idm then
            elseif mnu.check_prop then
                return assert(load("CheckChange('"..mnu.check_prop.."', true)"))
            elseif mnu.check_iuprops then
                local rez2 = assert(load("_G.iuprops['"..mnu.check_iuprops.."'] = "..Iif(tonumber(_G.iuprops[mnu.check_iuprops]) == 1 or _G.iuprops[mnu.check_iuprops] == true or _G.iuprops[mnu.check_iuprops] == 'ON' , 0, 1)))
                if rez then return function() rez2(); rez() end end
                return rez2
            elseif mnu.check_boolean then
                return assert(load("_G.iuprops['"..mnu.check_boolean.."'] = not _G.iuprops['"..mnu.check_boolean.."']"))
            elseif not rez then
                return function() debug_prnArgs('Error in menu format!!', mnu) end
            end
            return rez
        else
            return function() end
        end
    end
    local r = doGetAction(mnu, bForse, bHotKey)
    if not bHotKey then iup.PassFocus() end
    return r
end

local function FindMenuItem(path)
    local strFld
    local function DropDown(path, mnu)
        _,_, strFld = path:find('^([^|]+)|')
        for i = 1, #mnu do
            if strFld then
                if mnu[i][1]:gsub('&([^& ])', '%1') == strFld then
                    return DropDown(path:gsub('^[^|]+|', ''), mnu[i][2])
                end
            elseif mnu[i][1]:gsub('&([^& ])', '%1') == path then
                return mnu[i]
            end
        end
    end
    _,_, strFld = path:find('^([^|]+)|')
    return DropDown(path:gsub('^[^|]+|', ''), sys_Menus[strFld])
end

local function r_button_state()
    local rez = r_button or 0
    r_button = 0
    return rez
end

function s:CheckIUProps(p)
    return tonumber(_G.iuprops[p]) == 1 or _G.iuprops[p] == true or _G.iuprops[p] == 'ON'
end

function s:PopMnu(smnu, x, y, bToolBar)
    bListenmouseHook = bToolBar
    local CreateMenu, CreateItems
    local bPrevSepar = false
    local bShoIcons = (_G.iuprops['menus.show.icons'] == 1)
    CreateItems = function(m, t, bPl)
        if not m then return end
        for i = 1, #m do
            local itm
            if m[i].link then itm = FindMenuItem('MainWindowMenu|'..m[i].link)
            else itm = m[i] end

            if itm and getParam(itm.visible,true) and
              (not itm.visible_ext or string.find(','..itm.visible_ext..',', ','..props["FileExt"]..',')) and
              not (bPrevSepar and itm.separator) then
                if bPrevSepar then
                    table.insert(t, iup.separator{})
                end
                bPrevSepar = false
                if itm[2] then

                    if type(itm[2]) == 'table' then
                        if itm.plane and (not m[i].plane or m[i].plane ~= 0) then
                            CreateItems(itm[2],t)
                        else
                            table.insert(t, iup.submenu{title = s:get_title(itm, false, true), image = itm.image, CreateMenu(itm[2], itm.radio)})
                        end
                    elseif type(itm[2]) == 'function' then
                        if itm.plane and (not m[i].plane or m[i].plane ~= 0) then
                            CreateItems(itm[2](), t, true)
                        else
                            local t2 = itm[2]()
                            table.insert(t, iup.submenu{title = s:get_title(itm, false, true), image = itm.image, CreateMenu(t2)})
                            if #t2 == 0 then t[#t].active = 'NO' end
                        end
                    end
                    if itm.bottom then
                        local tBtm = {itm.bottom[1], cpt = itm.bottom.cpt, {}}
                        for j = i + 1,  #m do
                            table.insert(tBtm[2], m[j])
                        end

                        table.insert(t, iup.submenu{title = s:get_title(tBtm, false, true), image = itm.image, CreateMenu(tBtm[2])})
                        break
                    end
                elseif itm.separator then
                    if bPl or i > 1 then bPrevSepar = true end
                else --вставка пункта меню - только видимые

                    local titem = {title = s:get_title(itm, false, true)} --заголовок
                    if bShoIcons and itm.image then
                        -- if itm.check_iuprops or itm.check_boolean or itm.check_prop or itm.check_idm or itm.check then
                            -- titem.titleimage = itm.image
                        -- else        -- пока не работает
                            titem.image = itm.image
                        -- end
                    end
                    --доступность
                    if not getParam(itm.active, true) then titem.active = 'NO' end

                    if itm.check_iuprops then
                        titem.radio = 'YES'
                        if tonumber(_G.iuprops[itm.check_iuprops]) == 1 or _G.iuprops[itm.check_iuprops] == true or _G.iuprops[itm.check_iuprops] == 'ON' then titem.value = 'ON' end
                    elseif itm.check_boolean then
                        if _G.iuprops[itm.check_boolean] then titem.value = 'ON' end
                    elseif itm.check_prop then
                        if props[itm.check_prop] == '1' then titem.value = 'ON' end
                    elseif m.check_idm then
                        if tonumber(props[m.check_idm]) == itm.action then
                            titem.value = 'ON'
                        end
                    elseif getParam(itm.check, false) then
                        titem.value = 'ON'
                    end

                    if not titem.active then --'экшны обрабатываем только дл€ активных меню
                        titem.action = function()
                            if r_button_state() ~= 0 then
                                local chm, path = "HildiM", "ui/Menues.html"
                                if itm.hlp then
                                    _, _, chm, path = itm.hlp:find('^([^/]*)/(.*)')
                                end
                                local anc = itm[1]:gsub("&", "")
                                if shell.fileexists(props['SciteDefaultHome']..'/help/'..chm..'.chm') then
                                    scite.ExecuteHelp((props['SciteDefaultHome']..'/help/'..chm..'.chm::'..path..'#'..anc):to_utf8(), 0)
                                else
                                    local url = '"file:///'..props['SciteDefaultHome']..'/help/'..chm..'/'..path..'#'..anc..'"'
                                    print(url)
                                    shell.exec(url)
                                end
                            else
                                GetAction(itm)()
                            end
                            scite.SwitchMouseHook(false) --на вс€кий случай
                        end
                    end
                    --debug_prnArgs(titem)
                    table.insert(t, iup.item(titem))
                end
                -- bPrevSepar = (itm.separator ~= nil)
            end
        end
    end
    CreateMenu = function(m)
        local t = {}
        CreateItems(m,t)
        if m.radio then t.radio = 'YES' end
        return iup.menu(t)
    end

    waited_mnu, w_x, w_y = CreateMenu(smnu),x,y
    scite.RunAsync(function() s:ContinuePopUp() end)
end

local function GetItemPos(i)
    local _, _,left, top = iup.GetAttribute(labels[i],'SCREENPOSITION'):find('(-*%d+),(-*%d+)')
    local _, _,width, height = iup.GetAttribute(labels[i],'NATURALSIZE'):find('(-*%d+)x(-*%d+)')
    return tonumber(left), tonumber(top), tonumber(width), tonumber(height)
end

function s:OnMenuChar(flag, key)
    local function acivateItem(i)
        left, top, width, height = GetItemPos(i)

        reselectedItem = {id = i, x = left, y = top + height}
        activeLabel = labels[reselectedItem.id]
        scite.RunAsync(function() s:ContinuePopUp() end)
    end

    if flag == 0 then
        key = '&'..key:upper()
        for i = 1,  #labels do
            if labels[i].title:upper():find(key) then
                acivateItem(i)
                return 1
            end
        end
    elseif flag == 1 then
        acivateItem(1) --показ меню по отпусканию alt
    elseif flag == 2 then
        local delta = tonumber(key)
        for i = 1, #labels do
            if activeLabel == labels[i] then
                i = i + delta
                if i <= 0 then i = #labels
                elseif i > #labels then i = 1 end
                left, top, width, height = GetItemPos(i)
                scite.SwitchMouseHook(false)
                reselectedItem = {id = i, x = left, y = top + height}
                return
            end
        end
    elseif flag == 3 then --переключение alt
        if (key == 'YES') ~= mnemoShow then
            mnemoShow = (key == 'YES')
            for i = 1, #labels do
                iup.SetAttribute(labels[i], 'FORCEMNEMONIC', key)
            end
            iup.Redraw(iup.GetDialogChild(iup.GetLayout(), "Hildim_MenuBar"), 1)
        end
    end
end

function s:OnMouseHook(x,y)
--вызываетс€ при активированном меню:
--при движении мыши - x,y - координаты курсора
--при нажатии кнопок влево.вправо y - -1/1, x = -70000
--при нажатии кнопки Alt - оба параметра - -70000
    if not bListenmouseHook then return end
    local left, top, width, height
    for i = 1, #labels do
        left, top, width, height = GetItemPos(i)
        if i == 1 and (top > y or y > top + height) then return end
        if left <= x and x <= left + width then
            if activeLabel ~= labels[i] then
                scite.SwitchMouseHook(false)
                reselectedItem = {id = i, x = left, y = top + height}
            end
            return
        end
    end
end

function s:ContinuePopUp()
    if activeLabel then iup.SetAttribute(activeLabel, 'FGCOLOR', clr_select) end
    scite.SwitchMouseHook(true)
    if waited_mnu then waited_mnu:popup(w_x , w_y) end
    scite.SwitchMouseHook(false)
    bListenmouseHook = true
    if activeLabel then iup.SetAttribute(activeLabel, 'FGCOLOR', clr_normal) end
    activeLabel, waited_mnu, w_x, w_y = nil, nil, nil, nil
    if reselectedItem then
        activeLabel = labels[reselectedItem.id]
        s:PopMnu(_G.sys_Menus.MainWindowMenu[reselectedItem.id +1][2],reselectedItem.x,reselectedItem.y, true)
        reselectedItem = nil
    end
end

function s:ContextMenu(x, y, element)
    if type(element) == 'string' then
        if _G.sys_Menus[element] then s:PopMnu(_G.sys_Menus[element], x, y, false) end
    else
        s:PopMnu(element, x, y, false)
    end
end

local function InsertItem(mnu, path, t)
    local _,_, sItm = path:find('^([^|]+)|')
    if sItm then
        for i = 1, #mnu do
            if mnu[i][1] and mnu[i][1]:gsub('&([^& ])', '%1')==sItm then
                if mnu[i][2] then
                    InsertItem(mnu[i][2], path:gsub('^[^|]+|', ''), t)
                end
                return
            end
        end
        table.insert(mnu, {})
        table.insert(mnu[#mnu], sItm)
        table.insert(mnu[#mnu], {})
        InsertItem(mnu[#mnu][2], path:gsub('^[^|]+|', ''), t)
    else
        for i = 1, #mnu do
            if mnu[i][1] and mnu[i][1]:gsub('&([^& ])', '%1')==path then
                table.insert(mnu, i, t)
                return
            end
        end
        table.insert(mnu, t)
    end
end

local function prepareItems(t, helpPath, tf)
    t.hlp = helpPath
    if tf then t.cpt = tf(t[1]:gsub('&([^& ])', '%1')) end
    if type(t[2]) == 'table' then
        if tf then t[2].cpt = tf(t[2][1]) end
        for i = 1,  #(t[2]) do
            if type(t[2][i]) == 'table' then prepareItems(t[2][i], helpPath, tf) end
        end
    end
end

function s:InsertItem(id, path, t, helpPath, tf)

    if sys_Menus then
        if helpPath or tf then prepareItems(t, helpPath, tf) end

        if id == 'MainWindowMenu' then
            InsertItem(sys_Menus[id], path, t)
        else
            path = '*|'..path
            InsertItem({{'*', sys_Menus[id]}}, path, t)
        end
    end
end

function s:PostponeInsert(id, path, t, helpPath, tf)
    table.insert(tPostponed, {id, path, t, helpPath, tf})
end

function s:DoPostponedInsert(id, path, t)
    for _, t in ipairs(tPostponed) do
        if t[4] or t[5] then prepareItems(t[3], t[4], t[5]) end
        s:InsertItem(t[1], t[2], t[3])
    end
end

function s:RegistryHotKeys()

    local defpathUsr, tblUsers = props["scite.userhome"].."\\userHotKeys.lua"
    if shell.fileexists(defpathUsr) then tblUsers = assert(loadfile(defpathUsr))() end

    if not sys_Menus then return end
    local idm_loc = IDM_GENERATED
    local tKeys = {}
    sys_KeysToMenus = {}

    local function DropDown(path, mnu)
        for i = 1, #mnu do
            if type(mnu[i]) == 'table' and not mnu[i].link then
                local lp = path..'|'..mnu[i][1]
                local id = Iif(type(mnu[i].action) == 'number', mnu[i].action, idm_loc)
                local bSet
                if tblUsers then mnu[i].user_hk = tblUsers[lp] end
                if tblUsers and tblUsers[lp] then
                    if tblUsers[lp] ~= '' then
                        tKeys[tblUsers[lp]] = id
                        bSet = true
                    end
                elseif mnu[i].key and not mnu[i].key_external then
                    tKeys[mnu[i].key] = id
                    bSet = true
                end
                if bSet then
                    if not id then print(mnu[i].key) end
                    sys_KeysToMenus[id] = lp:gsub('&([^& ])', '%1')
                    if type(mnu[i].action) ~= 'number' then idm_loc = idm_loc + 1 end
                end

                if mnu[i][2] and type(mnu[i][2]) == 'table' then DropDown(lp, mnu[i][2])end
            end
        end

    end

    for ups, submnu in pairs(sys_Menus) do
        DropDown(ups,submnu)
    end
-- debug_prnArgs(tKeys)
   scite.RegistryHotKeys(tKeys)
end

local function GetHotKey(mnu, path, realPath)
    local _, _, sItm = path:find('^([^|]+)|')
    if sItm then
        for i = 1, #mnu do
            if mnu[i][1] and mnu[i][1]:gsub('&([^& ])', '%1') == sItm then
                if mnu[i][2] then
                    return GetHotKey(mnu[i][2], path:gsub('^[^|]+|', ''), realPath..'|'..mnu[i][1])
                end
            end
        end
    else
        for i = 1, #mnu do
            if mnu[i][1] and mnu[i][1]:gsub('&([^& ])', '%1') == path then
                local defpathUsr, tblUsers = props["scite.userhome"].."\\userHotKeys.lua"
                if shell.fileexists(defpathUsr) then tblUsers = assert(loadfile(defpathUsr))() end
                if tblUsers and tblUsers[realPath..'|'..mnu[i][1]] then
                    return tblUsers[realPath..'|'..mnu[i][1]]
                end
                return mnu[i].key
            end
        end
    end
end

function s:GetHotKey(path)
    local _, _, sItm = path:find('^([^|]+)|')
    if sItm then
        return GetHotKey(sys_Menus[sItm], path:gsub('^[^|]+|', ''), sItm) or ''
    end
    return ''
end

function s:OnHotKey(cmd)
    GetAction(FindMenuItem(sys_KeysToMenus[cmd]), nil, true)()
end

function s:CreateMenuLabel(item, ind)
    local l = iup.flatlabel{title = menuhandler:get_title(item, false, true), padding = '11x3', font = fnt, fgcolor = clr_normal, button_cb =
            function(h,but, pressed, x, y, status)
                if but == 49 and pressed == 0 then
                    activeLabel = h
                    local pos = load('return {'..iup.GetAttribute(h, "SCREENPOSITION")..'}')()
                    local sz = load('return {'..iup.GetAttribute(h, "RASTERSIZE"):gsub('x', ',')..'}')()
                    menuhandler:PopMnu(item[2],pos[1],pos[2] + sz[2], true)
                end
            end, enterwindow_cb =
            function(h)
                iup.SetAttribute(h, 'FGCOLOR', clr_hgl)
            end, leavewindow_cb =
            function(h)
                local cl = clr_normal
                if h == activeLabel then cl = clr_select end
                iup.SetAttribute(h, 'FGCOLOR', cl)
            end
        }
    table.insert(labels, ind or (#labels + 1), l)
    return l
end
function s:AddMenu(item, helpPath, tf)
    if helpPath or tf then prepareItems(item, helpPath, tf) end
    local hMainLayout = iup.GetLayout()
    local hMainMenu = iup.GetDialogChild(hMainLayout, "Hildim_MenuBar")
    local hWinMenu = iup.GetDialogChild(hMainMenu, "menu_find")
    local l = iup.canvas{ maxsize = 'x18', rastersize = '1x', bgcolor = props['layout.bordercolor'], expand = 'NO', border = 'NO'}
    iup.Insert(hMainMenu, hWinMenu, l)
    iup.Map(l)
    local n = #labels
    table.insert(_G.sys_Menus.MainWindowMenu, n + 1, item)
    l = menuhandler:CreateMenuLabel(item, n)
    iup.Insert(hMainMenu, hWinMenu, l)
    iup.Map(l)
end

function event_MenuHotKey(cmd)
    menuhandler:OnHotKey(cmd)
end

function event_MenuMouseHook(x, y)
    if x ==- 7000 and y ==- 7000 then
        r_button = 1
        scite.RunAsync(function() r_button = 0 end)
    else

        menuhandler:OnMouseHook(x, y)
    end
    --_, _, r_button = shell.async_mouse_state()
   ---- if r_button ~= 0 then
    --    print(r_button)
    ----end
end

function event_MenuChar(flag, key)
    return menuhandler:OnMenuChar(flag, key)
end

function s:PopUp(strPath)
--ѕоказывает сабменю в позиции мыши
    s:PopMnu(FindMenuItem(strPath)[2], iup.MOUSEPOS,iup.MOUSEPOS, false)
end

function s:GetMenuItem(path)

    local function getActVis(p)
        local tp = type(p)
        if tp == 'boolean' then return function() return p end
        elseif tp == 'function' then return p
        elseif tp == 'string' then return assert(load('return '..p)) end
    end
    local strFld
    local tblConditions = {}
    local function DropDown(path, mnu)
        _,_, strFld = path:find('^([^|]+)|')
        for i = 1, #mnu do
            if strFld then
                if mnu[i][1]:gsub('&([^& ])', '%1') == strFld then
                    if mnu[i].visible then
                        table.insert(tblConditions, getActVis(mnu[i].visible))
                    elseif mnu[i].visible_ext then
                        table.insert(tblConditions, function() return string.find(','..mnu[i].visible_ext..',',','..props["FileExt"]..',') end)
                    end
                    return DropDown(path:gsub('^[^|]+|', ''), mnu[i][2])
                end
            elseif mnu[i][1]:gsub('&([^& ])', '%1') == path then
                if mnu[i].active then

                    table.insert(tblConditions, getActVis(mnu[i].active))
                end
                return mnu[i]
            end
        end
    end
    _,_, strFld = path:find('^([^|]+)|')
    return DropDown(path:gsub('^[^|]+|', ''), sys_Menus[strFld]), tblConditions
end
function s:GetAction(mnu)
    return GetAction(mnu, true)
end
-- _G.menuhandler = s
return s
