local sys_KeysToMenus

local waited_mnu, w_x, w_y = nil,nil, nil
function class()
    local c = {}
    c.__index = c
    c.__gc = function()
        if c.destroy then
            c.destroy()
        end
    end
    local mt = {}
    mt.__call = function(_, ...)
        self = setmetatable({}, c)
        if c.init then
            c.init(self, ...)
        end
        return self
    end
    return setmetatable(c, mt)
end

local s = class()

function s:get_title(t)
    local s = t['ru'] or t[1]
    if t.key then s = s..'\t'..t.key end
    return s
end


local function GetAction(mnu)

    if mnu.idm then return function() scite.MenuCommand(mnu.idm) end
    elseif mnu.action then return mnu.action
    else
        return function() debug_prnArgs('Error in menu format!!',mnu) end
    end
end

function s:PopMnu(smnu, x, y)
    --debug_prnArgs(smnu)
    local CreateMenu, CreateItems

    CreateItems = function(m,t)
        for i = 1, #m do
            if (not m[i].visible or assert(loadstring('return '..m[i].visible))()) and
               (not m[i].visible_ext or string.find(','..m[i].visible_ext..',',','..props["FileExt"]..',')) then
                if m[i][2] then
                    if type(m[i][2]) == 'table' then
                        table.insert(t, iup.submenu{title = s:get_title(m[i]), CreateMenu(m[i][2])})
                    elseif type(m[i][2]) == 'function' then
                        if m[i].plane then
                            CreateItems(m[i][2](),t)
                        else
                            local t2 = m[i][2]()
                            table.insert(t, iup.submenu{title = s:get_title(m[i]), CreateMenu(t2)})
                            if #t2 == 0 then t[#t].active = 'NO' end
                        end
                    end
                elseif m[i].separator then
                    table.insert(t, iup.separator{})
                elseif not m[i].visible or assert(loadstring('return '..m[i].visible))() then --вставка пункта меню - только видимые

                    local titem = {title = s:get_title(m[i])} --заголовок
                    if m[i].active then --доступность
                        if not m[i].active() then titem.active = 'NO' end
                    end

                    if m[i].check then  --отметки. по выражению
                        if assert(loadstring('return '..m[i].check))() then titem.value = 'ON' end
                    elseif m[i].check_idm then
                        if tonumber(props[m[i].check_idm]) == m[i].idm then
                            titem.value = 'ON'
                            titem.active = 'NO'
                            titem.image = 'IMAGE_PinPush'
                        end
                    end

                    if not titem.active then --'экшны обрабатываем только для активных меню
                        titem.action = GetAction(m[i])
                    end
                    table.insert(t, iup.item(titem))
                end
            end
        end
    end
    CreateMenu = function(m)
        local t = {}
        CreateItems(m,t)
        return iup.menu(t)
    end

    waited_mnu, w_x, w_y = CreateMenu(smnu),x,y
    scite.PostCommand(POST_CONTINUESHOWMENU,0)
end

function s:ContinuePopUp()
    waited_mnu:popup(w_x, w_y)
    waited_mnu, w_x, w_y = nil,nil, nil
end

local function InsertItem(mnu, path, t)
    local _,_, sItm = path:find('^([^/]+)/')
    if sItm then
        for i = 1, #mnu do
            if mnu[i][1]==sItm then
                if mnu[i][2] then
                    InsertItem(mnu[i][2], path:gsub('^[^/]+/', ''), t)
                end
                return
            end
        end
        table.insert(mnu, {})
        table.insert(mnu[#mnu], sItm)
        table.insert(mnu[#mnu], {})
        InsertItem(mnu[#mnu][2], path:gsub('^[^/]+/', ''), t)
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
        InsertItem(sys_Menus[id], path, t)
    end
end

function s:RegistryHotKeys()
    if not sys_Menus then return end

    local idm_loc = 28000
    local tKeys = {}
    sys_KeysToMenus = {}

    local function DropDown(path, mnu)
        for i = 1, #mnu do
            local lp = path..'/'..mnu[i][1]
            if mnu[i].key and not mnu[i].key_external then
                local id = mnu[i].idm or idm_loc
                tKeys[mnu[i].key] = id
                sys_KeysToMenus[id] = lp
                if not mnu[i].idm then idm_loc = idm_loc + 1 end
            end
            if mnu[i][2] and type(mnu[i][2]) == 'table' then DropDown(lp, mnu[i][2])end
        end

    end

    for ups,submnu in pairs(sys_Menus) do
        DropDown(ups,submnu)
    end
   scite.RegistryHotKeys(tKeys)
end

function s:OnHotKey(cmd)
    local path = sys_KeysToMenus[cmd]

    local strFld
    local function DropDown(path, mnu)
        _,_, strFld = path:find('^([^/]+)/')
        for i = 1, #mnu do
            if strFld then
                if mnu[i][1] == strFld then
                    DropDown(path:gsub('^[^/]+/', ''), mnu[i][2])
                    return
                end
            else
                if mnu[i][1] == path then
                    GetAction(mnu[i])()
                end
            end
        end
    end

    _,_, strFld = path:find('^([^/]+)/')
    DropDown(path:gsub('^[^/]+/', ''), sys_Menus[strFld])

end

_G.menuhandler = s

