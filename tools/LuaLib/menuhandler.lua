local sys_KeysToMenus, labels, tPostponed
local waited_mnu, w_x, w_y = nil,nil, nil
local activeLabel = nil
local reselectedItem = nil
local clr_hgl = '15 60 195'

local clr_select = '0 0 0'
local clr_normal = '70 70 70'
local s = class()
local r_button

function s:Init()
    sys_KeysToMenus = {}
    labels = {}
    tPostponed = {}
    waited_mnu, w_x, w_y = nil,nil, nil
    activeLabel = nil
    reselectedItem = nil
end

function s:get_title(t, bShort)
    local s = t['ru'] or t[1]
    if not bShort and (t.user_hk or t.key) then s = s..'\t'..(t.user_hk or t.key) end
    return s
end

local function getParam(p, bDef)
    local v,tp = bDef, type(p)
    if tp == 'boolean' then v = p
    elseif tp == 'function' then v = p()
    elseif tp == 'string' then v = assert(load('return '..p))() end
    return v
end

local function GetAction(mnu, bForse)
    if bForse or getParam(mnu.active, true) then
        if mnu.action then
            local tp = type(mnu.action)
            if tp == 'number' then return function() scite.MenuCommand(mnu.action) end end
            if tp == 'string' then return assert(load('return '..mnu.action)) end
            return mnu.action
        elseif mnu.check_idm then
        elseif mnu.check_prop then
            return assert(load("CheckChange('"..mnu.check_prop.."', true)"))
        elseif mnu.check_iuprops then
            return assert(load("_G.iuprops['"..mnu.check_iuprops.."'] = "..Iif(tonumber(_G.iuprops[mnu.check_iuprops]) == 1,0,1)))
        elseif mnu.check_boolean then
            return assert(load("_G.iuprops['"..mnu.check_boolean.."'] = not _G.iuprops['"..mnu.check_boolean.."']"))
        else
            return function() debug_prnArgs('Error in menu format!!',mnu) end
        end
    else
        return function() end
    end
end

local function FindMenuItem(path)
    local strFld
    local function DropDown(path, mnu)
        _,_, strFld = path:find('^([^|]+)|')
        for i = 1, #mnu do
            if strFld then
                if mnu[i][1] == strFld then
                    return DropDown(path:gsub('^[^|]+|', ''), mnu[i][2])
                end
            elseif mnu[i][1] == path then
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

function s:PopMnu(smnu, x, y, bToolBar)
--debug_prnArgs(smnu)
    local CreateMenu, CreateItems
    local bPrevSepar = false
    local bShoIcons = (_G.iuprops['menus.show.icons'] == 1)
    CreateItems = function(m,t)
        for i = 1, #m do
            local itm
            if m[i].link then itm = FindMenuItem('MainWindowMenu|'..m[i].link)
            else itm = m[i] end

            if getParam(itm.visible,true) and
               (not itm.visible_ext or string.find(','..itm.visible_ext..',',','..props["FileExt"]..',')) then
                if itm[2] then

                    if type(itm[2]) == 'table' then
                        if itm.plane and (not m[i].plane or m[i].plane ~= 0) then
                            CreateItems(itm[2],t)
                        else
                            table.insert(t, iup.submenu{title = s:get_title(itm), CreateMenu(itm[2], itm.radio)})
                        end
                    elseif type(itm[2]) == 'function' then
                        if itm.plane and (not m[i].plane or m[i].plane ~= 0) then
                            CreateItems(itm[2](),t)
                        else
                            local t2 = itm[2]()
                            table.insert(t, iup.submenu{title = s:get_title(itm), CreateMenu(t2)})
                            if #t2 == 0 then t[#t].active = 'NO' end
                        end
                    end
                    if itm.bottom then
                        local tBtm = {itm.bottom[1], ru = itm.bottom.ru, {}}
                        for j = i + 1,  #m do
                            table.insert(tBtm[2], m[j])
                        end

                        table.insert(t, iup.submenu{title = s:get_title(tBtm), CreateMenu(tBtm[2])})
                        break
                    end
                elseif itm.separator then
                    if not bPrevSepar and i > 1 and i < #m then table.insert(t, iup.separator{}) end
                else --вставка пункта меню - только видимые

                    local titem = {title = s:get_title(itm)} --заголовок
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
                        if tonumber(_G.iuprops[itm.check_iuprops]) == 1 then titem.value = 'ON' end
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

                    if not titem.active then --'экшны обрабатываем только для активных меню
                        titem.action = function()
                            if r_button_state() > 0 then
                                if shell.fileexists(props['SciteDefaultHome']..'/help/HildiM.chm') then
                                    scite.ExecuteHelp((props['SciteDefaultHome']..'/help/HildiM.chm::ui/Menues.html#'..itm[1]):to_utf8(1251), 0)
                                else
                                    local url = '"file:///'..props['SciteDefaultHome']..'/help/HildiM/ui/Menues.html#'..itm[1]..'"'
                                    print(url)
                                    shell.exec(url)
                                end
                            else
                                GetAction(itm)()
                            end
                        end
                    end
                    --debug_prnArgs(titem)
                    table.insert(t, iup.item(titem))
                end
                bPrevSepar = (itm.separator ~= nil)
            end
        end
    end
    CreateMenu = function(m)
        local t = {}
        CreateItems(m,t)
        if m.radio then t.radio = 'YES' end
        return iup.menu(t)
    end

    if bToolBar then
        waited_mnu, w_x, w_y = CreateMenu(smnu),x,y
        scite.RunAsync(function() s:ContinuePopUp() end)
    else
        CreateMenu(smnu):popup(x,y)
    end
end

local function GetItemPos(i)
    local _, _,left, top = iup.GetAttribute(labels[i],'SCREENPOSITION'):find('(-*%d+),(-*%d+)')
    local _, _,width, height = iup.GetAttribute(labels[i],'NATURALSIZE'):find('(-*%d+)x(-*%d+)')
    return tonumber(left), tonumber(top), tonumber(width), tonumber(height)
end

function s:OnMouseHook(x,y)
--вызывается при активированном меню:
--при движении мыши - x,y - координаты курсора
--при нажатии кнопок влево.вправо y - -1/1, x = -70000
--при нажатии кнопки Alt - оба параметра - -70000
    local left, top, width, height
    if x>-65536 and y>-65536 then
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
    elseif y >- 65536 then
        for i = 1, #labels do
            if activeLabel == labels[i] then
                i = i + y
                if i <=0 then i = #labels
                elseif i > #labels then i = 1 end
                    left, top, width, height = GetItemPos(i)
                    scite.SwitchMouseHook(false)
                    reselectedItem = {id = i, x = left, y = top + height}
                return
            end
        end
    elseif not waited_mnu then   --нажали Alt
        left, top, width, height = GetItemPos(1)

        reselectedItem = {id = 1, x = left, y = top + height}
        activeLabel = labels[reselectedItem.id]
        scite.RunAsync(function() s:ContinuePopUp() end)
    end
end

function s:ContinuePopUp()
    if activeLabel then iup.SetAttribute(activeLabel, 'FGCOLOR', clr_select) end
    scite.SwitchMouseHook(true)
    if waited_mnu then waited_mnu:popup(w_x , w_y) end
    scite.SwitchMouseHook(false)
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
        s:PopMnu(_G.sys_Menus[element], x, y, false)
    else
        s:PopMnu(element, x, y, false)
    end
end

local function InsertItem(mnu, path, t)
    local _,_, sItm = path:find('^([^|]+)|')
    if sItm then
        for i = 1, #mnu do
            if mnu[i][1]==sItm then
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
            if mnu[i][1]==path then
                table.insert(mnu, i, t)
                return
            end
        end
        table.insert(mnu, t)
    end
end

function s:InsertItem(id, path, t)
    if sys_Menus then
        if id == 'MainWindowMenu' then
            InsertItem(sys_Menus[id], path, t)
        else
            path = '*|'..path
            InsertItem({{'*', sys_Menus[id]}}, path, t)
        end
    end
end

function s:PostponeInsert(id, path, t)
    table.insert(tPostponed, {id, path, t})
end

function s:DoPostponedInsert(id, path, t)
    for _, t in ipairs(tPostponed) do
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
            if not mnu[i].link then
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
                    sys_KeysToMenus[id] = lp
                    if type(mnu[i].action) ~= 'number' then idm_loc = idm_loc + 1 end
                end

                if mnu[i][2] and type(mnu[i][2]) == 'table' then DropDown(lp, mnu[i][2])end
            end
        end

    end

    for ups, submnu in pairs(sys_Menus) do
        DropDown(ups,submnu)
    end
--debug_prnArgs(tKeys)
   scite.RegistryHotKeys(tKeys)
end

function s:OnHotKey(cmd)
    GetAction(FindMenuItem(sys_KeysToMenus[cmd]))()
end

function s:GreateMenuLabel(item, ind)
    local l =  iup.label{title = menuhandler:get_title(item), padding = '11x3', font= fnt,fgcolor = clr_normal, button_cb=
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
function s:AddMenu(item)
    local hMainLayout = iup.GetLayout()
    local hMainMenu = iup.GetDialogChild(hMainLayout, "Hildim_MenuBar")
    local hWinMenu = iup.GetDialogChild(hMainMenu, "menu_fill")
    local l = iup.label{separator = "VERTICAL", maxsize = 'x18'}
    iup.Insert(hMainMenu, hWinMenu, l)
    iup.Map(l)
    local n = #labels
    table.insert(_G.sys_Menus.MainWindowMenu, n + 1, item)
    l = menuhandler:GreateMenuLabel(item, n)
    iup.Insert(hMainMenu, hWinMenu, l)
    iup.Map(l)
end

function event_MenuHotKey(cmd)
    menuhandler:OnHotKey(cmd)
end

function event_MenuMouseHook(x, y)
    menuhandler:OnMouseHook(x, y)
    _, _, r_button = shell.async_mouse_state()
end

function s:PopUp(strPath)
--Показывает сабменю в позиции мыши
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
                if mnu[i][1] == strFld then
                    if mnu[i].visible then
                        table.insert(tblConditions, getActVis(mnu[i].visible))
                    elseif mnu[i].visible_ext then
                        table.insert(tblConditions, function() return string.find(','..mnu[i].visible_ext..',',','..props["FileExt"]..',') end)
                    end
                    return DropDown(path:gsub('^[^|]+|', ''), mnu[i][2])
                end
            elseif mnu[i][1] == path then
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
_G.menuhandler = s

