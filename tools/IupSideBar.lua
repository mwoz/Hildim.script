require "gui"
SideBar_obj = {}
TabBar_obj = {}
StatusBar_obj = {}
local win_parent --создаем основное окно
local tbs
local vbox
local vFuncNav
local vAbbrev
local vSys
local vFileMan
local vFindRepl
local oDeatt

function sidebar_Switch(n)
    SideBar_obj.TabCtrl.valuepos = n -1
    if SideBar_obj.TabCtrl.value.tabs_OnSelect ~= nil --[[and props["FilePath"] ~= '']] then
        SideBar_obj.TabCtrl.value.tabs_OnSelect()
    end
end
function sidebar_Focus()
    iup.SetFocus(SideBar_obj.TabCtrl)
end
local function  CreateToolBar()
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\LiveSearch.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\m4.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\mb.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\templates.lua")
    --local tolsp2=iup.split{TabBar_obj.Tabs.m4.handle, TabBar_obj.Tabs.mb.handle, orientation="VERTICAL",minmax="300:700"}
    local tolsp1=iup.hbox{
                            TabBar_obj.Tabs.mb.handle,
                            TabBar_obj.Tabs.m4.handle,
                            TabBar_obj.Tabs.template.handle,
                            TabBar_obj.Tabs.livesearch.handle,
                            gap='3',margin='3x0'
                        }
    return tolsp1
end
local function  CreateStatusBar()
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\Status.lua")
    local tolsp1=iup.hbox{
                            StatusBar_obj.Tabs.statusbar.handle,
                            gap='3',margin='3x0'
                        }
    return tolsp1
end
local function  CreateBox()

    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\Abbrev.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\Bookmark.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\FileMan.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\Functions.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\Navigation.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\FindRepl.lua")

    -- Creates boxes
    vFuncNav = iup.split{SideBar_obj.Tabs.functions.handle, SideBar_obj.Tabs.navigation.handle, orientation="HORIZONTAL", name="splitFuncNav"}
    vFuncNav.tabtitle = "Func/Nav"
    SideBar_obj.Tabs.functions.id = vFuncNav.tabtitle
    SideBar_obj.Tabs.navigation.id = vFuncNav.tabtitle

    vAbbrev = iup.split{SideBar_obj.Tabs.abbreviations.handle, SideBar_obj.Tabs.bookmark.handle, orientation="HORIZONTAL", name="splitAbbrev"}

    -- Sets titles of the vboxes Navigation
    vAbbrev.tabtitle = "Abbrev/Bmk"
    SideBar_obj.Tabs.abbreviations.id = vAbbrev.tabtitle

    -- vSys = iup.vbox{SideBar_obj.Tabs.m4.handle, SideBar_obj.Tabs.mb.handle , SideBar_obj.Tabs.template.handle }
    -- vSys.tabtitle = "Sys"

    vFileMan = SideBar_obj.Tabs.fileman.handle
    vFileMan.tabtitle = "FileMan"
    SideBar_obj.Tabs.fileman.id = vFileMan.tabtitle

    vFindRepl = SideBar_obj.Tabs.findrepl.handle
    vFindRepl.tabtitle = "Find"
    SideBar_obj.Tabs.findrepl.id = vFindRepl.tabtitle

    -- Creates tabs
    local tabs = iup.tabs{vFuncNav, vAbbrev, vFileMan, vFindRepl, name="tabMain"}

    tabs.tabchange_cb = (function(_,new_tab, old_tab)
        --сначала найдем активный таб и установим его в SideBar_obj

        for _,tbs in pairs(SideBar_obj.Tabs) do
            if tbs["tabs_OnSelect"] then tbs.tabs_OnSelect() end
            if tbs.id == new_tab.tabtitle then
                if tbs["on_SelectMe"] then tbs.on_SelectMe() end
            end
        end
    end)

    tabs.rightclick_cb=(function()
        if _G.iuprops['sidebar.win'] == '0' then
            local mnu = iup.menu
            {
              iup.item{title="Deattach Sidebar",action=(function()
                  oDeatt.detach = 1
              end)};
              iup.item{title="LayOut Dialog",action=(function()
                local f = iup.filedlg{}
                iup.SetNativeparent(f, "SCITE")
                f:popup()
                local path = f.value
                f:destroy()
                 testHandle = nil
                if path ~= nil then
                    local l = io.open(path)
                    local strLua = l:read('*a')
                    l:close()
                    local _,_, fName = strLua:find("function (create_dialog_[_%w]+)")
                    strLua = strLua..'\n testHandle = '..fName..'()'
                    dostring(strLua)
                end
                local dlg = iup.LayoutDialog(testHandle)
                iup.Show(dlg)
              end)};

            }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
        end
    end)

    SideBar_obj.TabCtrl = tabs

    vbox = iup.vbox{tabs}       --SideBar_obj.Tabs.livesearch.handle,
    oDeatt = iup.detachbox{
        vbox; orientation="HORIZONTAL";barsize=5;minsize="100x100";
        detached_cb=(function(h, hNew, x, y)
            hNew.resize ="YES"
            hNew.shrink ="YES"
            hNew.minsize="100x100"
            hNew.maxbox="NO"
            hNew.minbox="NO"
            hNew.toolbox="YES"
            hNew.title="SideBar /Close For Attach/"
            hNew.x=10
            hNew.y=10
            x=10;y=10
            hNew.rastersize = _G.iuprops['dialogs.sidebar.rastersize']
            _G.iuprops['sidebar.win']=1
            _G.iuprops['dialogs.sidebarp.rastersize'] = h.rastersize

            hNew.close_cb =(function(h)
                if _G.dialogs['sidebar'] ~= nil then

                    _G.iuprops['sidebar.win']=0
                    local w = _G.iuprops['dialogs.sidebarp.rastersize']:gsub('x%d*', '')
                    iup.ShowSideBar(tonumber(w))
                    oDeatt.restore = 1
                    _G.dialogs['sidebar'] = nul
                    return -1
                end
            end)

            hNew.show_cb=(function(h,state)
                if state == 0 then
                    _G.dialogs['sidebar'] = oDeatt
                elseif state == 4 then
                    _G.iuprops["dialogs.sidebar.x"]= h.x
                    _G.iuprops["dialogs.sidebar.y"]= h.y
                    _G.iuprops['dialogs.sidebar.rastersize'] = h.rastersize
                end
            end)
            iup.ShowSideBar(-1)
            if tonumber(_G.iuprops["dialogs.sidebar.x"])== nil or tonumber(_G.iuprops["dialogs.sidebar.y"]) == nil then _G.iuprops["dialogs.sidebar.x"]=0;_G.iuprops["dialogs.sidebar.y"]=0 end
            return tonumber(_G.iuprops["dialogs.sidebar.x"])*2^16+tonumber(_G.iuprops["dialogs.sidebar.y"])
        end)
        }
    return oDeatt
end
local tEvents = {"OnClose","OnSendEditor","OnSwitchFile","OnOpen","OnSave","OnUpdateUI","OnDoubleClick","OnKey","OnDwellStart","OnNavigation","OnSideBarClouse", "OnMenuCommand"}

local function InitSideBar()
--SideBar_obj._DEBUG = true --включает вывод отладочной информации
-- отображение флагов/параметров по умолчанию:
    if tonumber(props['sidebar.hide']) == 1 then return end
    -- SideBar_obj.win = false --если установить true - панель будет показана отдельным окном
    SideBar_obj.win = (_G.iuprops['sidebar.win']=='1') --если установить true - панель будет показана отдельным окном
    SideBar_obj.Tabs = {}
    SideBar_obj.Active = true

    local dlg
    local tDlg = {CreateBox(); title="SideBar", maxbox="NO",minbox ="NO",resize ="YES", menubox="NO", shrink='YES', minsize="100x100"}
    tDlg.show_cb=(function(h,state)
        if state == 0 then

           iup.Refresh(h)
           h.size = '1x1'
        elseif state == 4 then
            for _,tbs in pairs(SideBar_obj.Tabs) do
                if tbs["OnSideBarClouse"] then tbs.OnSideBarClouse() end
            end
            for i = 1, #tEvents do
                for _,tbs in pairs(SideBar_obj.Tabs) do
                   if tbs[tEvents[i]] then RemoveEventHandler(tEvents[i],tbs[tEvents[i]]) end
                end
            end
            SideBar_obj.Active = false
        end
    end)
    tDlg.k_any=(function(_,key)
        if key == 65307 then iup.PassFocus() end
    end)

    local function SaveNamedValues(h)
        if not h then return end
        local child = nil
        repeat
            child = iup.GetNextChild(h, child)
            if child then
                if (child.value or child.valuepos or child.focusitem) and child.name then
                    local _,_,cType = tostring(child):find('IUP%((%w+)')

                    local val = child.value
                    if cType == 'list' and child.dropdown == "YES" then
                        local hist = {}
                        for i = 1, child.count do
                            table.insert(hist,iup.GetAttributeId(child, '', i))
                        end
                        _G.iuprops['sidebarctrl.'..child.name..'.hist'] = table.concat(hist,'¤')
                    elseif cType == 'zbox' or cType == 'tabs' then
                        val = child.valuepos
                    elseif cType == 'matrixlist' then
                        val = child.focusitem
                    end
                    _G.iuprops['sidebarctrl.'..child.name..'.value'] = val
                end
                SaveNamedValues(child)
            end
        until not child
    end

    local function RestoreNamedValues(h)
        if not h then return end
        local child = nil
        repeat
            child = iup.GetNextChild(h, child)
            if child then
                if child.name then
                    local _,_,cType = tostring(child):find('IUP%((%w+)')
                    local val = _G.iuprops['sidebarctrl.'..child.name..'.value']
                    if cType == 'list' and child.dropdown == "YES" then
                        local s = _G.iuprops['sidebarctrl.'..child.name..'.hist']
                        if s then
                            for w in s:gmatch('([^¤]+)') do
                                iup.SetAttributeId(child, 'INSERTITEM', 1, w)
                            end
                        end
                        if val then child.value = val end
                    elseif cType == 'zbox' or cType == 'tabs' then
                        if val then child.valuepos = val end
                    elseif cType == 'matrixlist' then
                        if val then
                            child.focusitem = val
                            child["show"] = val..":*"
                            child.redraw = 1
                        end
                    else
                        if val then child.value = val end
                    end
                end
                RestoreNamedValues(child)
            end
        until not child
    end

    tDlg.SaveValues = (function()
        SaveNamedValues(tDlg[1])
    end)

    tDlg.sciteparent="SIDEBAR"
    tDlg.control = "YES"
    tDlg.sciteid="sidebarp"
    -- end
    dlg = iup.scitedialog(tDlg)
    RestoreNamedValues(tDlg[1])
    if SideBar_obj.win then oDeatt.detach = 1 end

    for i = 1, #tEvents do
        for _,tbs in pairs(SideBar_obj.Tabs) do
            if tbs[tEvents[i]] then AddEventHandler(tEvents[i],tbs[tEvents[i]]) end
        end
    end
end

local function InitToolBar()
    TabBar_obj.Tabs = {}
                     --iup.hbox{iup.text{expand='YES', expand='HORIZONTAL'}}
    local tTlb = {CreateToolBar();expand='YES', maxbox="NO",minbox ="NO",resize ="YES", menubox="NO", shrink='YES', minsize="10x10"}
    tTlb.sciteparent="IUPTOOLBAR"
    tTlb.control = "YES"
    tTlb.sciteid="iuptoolbar"
    tTlb.show_cb=(function(h,state)

        if state == 0 and props['iuptoolbar.visible'] == '1' and props['iuptoolbar.restarted'] ~= '1' then
           scite.MenuCommand(IDM_VIEWTLBARIUP)
        elseif state == 4 then
            for _,tbs in pairs(TabBar_obj.Tabs) do
                if tbs["OnSideBarClouse"] then tbs.OnSideBarClouse() end
            end
            for i = 1, #tEvents do
                for _,tbs in pairs(TabBar_obj.Tabs) do
                   if tbs[tEvents[i]] then RemoveEventHandler(tEvents[i],tbs[tEvents[i]]) end
                end
            end
            props['iuptoolbar.restarted'] = '1'
        end
    end)
    tTlb.resize_cb=(function(_,x,y) if TabBar_obj.handle ~= nil then TabBar_obj.size = TabBar_obj.handle.size end end)
    TabBar_obj.handle = iup.scitedialog(tTlb)
    for i = 1, #tEvents do
        for _,tbs in pairs(TabBar_obj.Tabs) do
            if tbs[tEvents[i]] then AddEventHandler(tEvents[i],tbs[tEvents[i]]) end
        end
    end
    TabBar_obj.size = TabBar_obj.handle.size
    iup.PassFocus()
end


local function InitStatusBar()
    StatusBar_obj.Tabs = {}
                     --iup.hbox{iup.text{expand='YES', expand='HORIZONTAL'}}
    local tTlb = {CreateStatusBar();expand='YES', maxbox="NO",minbox ="NO",resize ="YES", menubox="NO", shrink='YES', minsize="10x10"}
    tTlb.sciteparent="IUPSTATUSBAR"
    tTlb.control = "YES"
    tTlb.sciteid="iupstatusbar"
    tTlb.show_cb=(function(h,state)

        if state == 0 and props['iuptoolbar.visible'] == '1' and props['iuptoolbar.restarted'] ~= '1' then
           -- scite.MenuCommand(IDM_VIEWTLBARIUP)
        elseif state == 4 then
            for _,tbs in pairs(StatusBar_obj.Tabs) do
                if tbs["OnSideBarClouse"] then tbs.OnSideBarClouse() end
            end
            for i = 1, #tEvents do
                for _,tbs in pairs(StatusBar_obj.Tabs) do
                   if tbs[tEvents[i]] then RemoveEventHandler(tEvents[i],tbs[tEvents[i]]) end
                end
            end
        end
    end)
    tTlb.resize_cb=(function(_,x,y) if StatusBar_obj.handle ~= nil then  StatusBar_obj.size = StatusBar_obj.handle.size end end)
    StatusBar_obj.handle = iup.scitedialog(tTlb)
    for i = 1, #tEvents do
        for _,tbs in pairs(StatusBar_obj.Tabs) do
            if tbs[tEvents[i]] then AddEventHandler(tEvents[i],tbs[tEvents[i]]) end
        end
    end
    StatusBar_obj.handle.size = TabBar_obj.handle.size
    StatusBar_obj.size = StatusBar_obj.handle.size
    iup.PassFocus()
end

InitSideBar()
InitToolBar()
InitStatusBar()
