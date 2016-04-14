local sys_KeysToMenus = {}
local labels = {}
local waited_mnu, w_x, w_y = nil,nil, nil
local activeLabel = nil
local reselectedItem = nil
local clr_hgl = '15 60 195'
-- local clr_hgl = '206 206 00'
--local clr_select = '205 43 202'
local clr_select = '0 0 0'
local clr_normal = '70 70 70'

local s = class()

function s:get_title(t)
    local s = t['ru'] or t[1]
    if t.key then s = s..'\t'..t.key end
    return s
end


local function GetAction(mnu)
    if mnu.action then
        local tp = type(mnu.action)
        if tp == 'number' then return function() scite.MenuCommand(mnu.action) end end
        if tp == 'string' then return assert(loadstring('return '..mnu.action)) end
        return mnu.action
    elseif mnu.check_idm then
    elseif mnu.check_prop then
        return "CheckChange('"..mnu.check_prop.."', true)"
    elseif mnu.check_iuprops then
        return "_G.iuprops['"..mnu.check_iuprops.."'] = "..Iif(tonumber(_G.iuprops[mnu.check_iuprops]) == 1,0,1)
    elseif mnu.check_boolean then
        return "_G.iuprops['"..mnu.check_boolean.."'] = not _G.iuprops['"..mnu.check_boolean.."']"
    else
        return function() debug_prnArgs('Error in menu format!!',mnu) end
    end
end

local function FindMenuItem(path)
    local strFld
    local function DropDown(path, mnu)
        _,_, strFld = path:find('^([^¦]+)¦')
        for i = 1, #mnu do
            if strFld then
                if mnu[i][1] == strFld then
                    return DropDown(path:gsub('^[^¦]+¦', ''), mnu[i][2])
                end
            elseif mnu[i][1] == path then
                return mnu[i]
            end
        end
    end
    _,_, strFld = path:find('^([^¦]+)¦')
    return DropDown(path:gsub('^[^¦]+¦', ''), sys_Menus[strFld])
end

function s:PopMnu(smnu, x, y, bToolBar)
    local CreateMenu, CreateItems
    local bPrevSepar = false
    CreateItems = function(m,t)
        local function getParam(p, bDef)
            local v,tp = bDef, type(p)
            if tp == 'boolean' then v = p
            elseif tp == 'function' then v = p()
            elseif tp == 'string' then v = assert(loadstring('return '..p))() end
            return v
        end
        for i = 1, #m do
            local itm
            if m[i].link then itm = FindMenuItem('MainWindowMenu¦'..m[i].link)
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
                else --âñòàâêà ïóíêòà ìåíş - òîëüêî âèäèìûå

                    local titem = {title = s:get_title(itm)} --çàãîëîâîê
                    --äîñòóïíîñòü
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

                    if not titem.active then --'ıêøíû îáğàáàòûâàåì òîëüêî äëÿ àêòèâíûõ ìåíş
                        titem.action = GetAction(itm)
                    end

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
        scite.PostCommand(POST_CONTINUESHOWMENU,0)
    else
        CreateMenu(smnu):popup(x,y)
    end
end

function s:OnMouseHook(x,y)
    for i = 1, #labels do
        local _, _,left, top = iup.GetAttribute(labels[i],'SCREENPOSITION'):find('(%d+),(%d+)')
        local _, _,width, height = iup.GetAttribute(labels[i],'NATURALSIZE'):find('(%d+)x(%d+)')
        left, top, width, height = tonumber(left), tonumber(top), tonumber(width), tonumber(height)
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
    waited_mnu:popup(w_x , w_y)
    scite.SwitchMouseHook(false)
    if activeLabel then iup.SetAttribute(activeLabel, 'FGCOLOR', clr_normal) end
    activeLabel, waited_mnu, w_x, w_y = nil,nil, nil, nil
    if reselectedItem then
        activeLabel = labels[reselectedItem.id]
        s:PopMnu(_G.sys_Menus.MainWindowMenu[reselectedItem.id +1][2],reselectedItem.x,reselectedItem.y, true)
        reselectedItem = nil
    end
end

function s:ContextMenu(x, y, element)
    s:PopMnu(_G.sys_Menus[element], x, y, false)
end

local function InsertItem(mnu, path, t)
    local _,_, sItm = path:find('^([^¦]+)¦')
    if sItm then
        for i = 1, #mnu do
            if mnu[i][1]==sItm then
                if mnu[i][2] then
                    InsertItem(mnu[i][2], path:gsub('^[^¦]+¦', ''), t)
                end
                return
            end
        end
        table.insert(mnu, {})
        table.insert(mnu[#mnu], sItm)
        table.insert(mnu[#mnu], {})
        InsertItem(mnu[#mnu][2], path:gsub('^[^¦]+¦', ''), t)
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
            path = '*¦'..path
            InsertItem({{'*', sys_Menus[id]}}, path, t)
        end
    end
end

function s:RegistryHotKeys()

    if not sys_Menus then return end
    local idm_loc = IDM_GENERATED
    local tKeys = {}
    sys_KeysToMenus = {}

    local function DropDown(path, mnu)
        for i = 1, #mnu do
            if not mnu[i].link then
                local lp = path..'¦'..mnu[i][1]
                if mnu[i].key and not mnu[i].key_external then
                    local id = Iif(type(mnu[i].action) == 'number', mnu[i].action, idm_loc)
                    tKeys[mnu[i].key] = id
                    if not id then print(mnu[i].key) end
                    sys_KeysToMenus[id] = lp
                    if type(mnu[i].action) ~= 'number' then idm_loc = idm_loc + 1 end
                end
                if mnu[i][2] and type(mnu[i][2]) == 'table' then DropDown(lp, mnu[i][2])end
            end
        end

    end
--debug_prnArgs(sys_Menus)
    for ups,submnu in pairs(sys_Menus) do
        DropDown(ups,submnu)
    end
--debug_prnArgs(tKeys)
   scite.RegistryHotKeys(tKeys)
end

function s:OnHotKey(cmd)
    GetAction(FindMenuItem(sys_KeysToMenus[cmd]))()
end

function s:GreateMenuLabel(item)
    local l =  iup.label{title = menuhandler:get_title(item), padding = '11x3', font= fnt,fgcolor = clr_normal, button_cb=
            function(h,but, pressed, x, y, status)
                if but == 49 and pressed == 0 then
                    activeLabel = h
                    local pos = loadstring('return {'..iup.GetAttribute(h, "SCREENPOSITION")..'}')()
                    local sz = loadstring('return {'..iup.GetAttribute(h, "RASTERSIZE"):gsub('x', ',')..'}')()
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
    table.insert(labels, l)
    return l
end

function event_MenuHotKey(cmd)
    menuhandler:OnHotKey(cmd)
end

function event_MenuMouseHook(x, y)
    menuhandler:OnMouseHook(x, y)
end

_G.menuhandler = s

