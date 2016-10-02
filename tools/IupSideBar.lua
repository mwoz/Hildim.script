require 'shell'
SideBar_obj = {}
LeftBar_obj = {}
SideBar_Plugins = {}
local ToolBar_obj = {}

local win_parent --создаем основное окно
local tbs
local vbox

local hMainLayout = iup.GetLayout()
local ConsoleBar, FindRepl, FindResBar
local pane_curObj
local tEvents = {"OnClose","OnSendEditor","OnSwitchFile","OnOpen","OnSave","OnUpdateUI","OnDoubleClick","OnKey","OnDwellStart","OnNavigation","OnSideBarClouse", "OnMenuCommand", "OnCreate"}

local fntSize = "10"
if props['iup.defaultfontsize']~='' then if tonumber(props['iup.defaultfontsize']) > 4 then fntSize = props['iup.defaultfontsize'] end end
iup.SetGlobal("DEFAULTFONTSIZE", fntSize)
iup.SetGlobal("TXTHLCOLOR", "222 222 222")
                               -- RGB(121, 161, 201)
iup.PassFocus=(function()
    iup.SetFocus(iup.GetDialogChild(hMainLayout, "Source"))
end)

function sidebar_Switch(n)
    if LeftBar_obj.handle then
        leftCount = tonumber(LeftBar_obj.TabCtrl.count)
        if n <= leftCount then
            if LeftBar_obj.handle.Dialog then LeftBar_obj.handle.ShowDialog() end
            LeftBar_obj.TabCtrl.valuepos = n -1
            for _,tbs in pairs(SideBar_Plugins) do
                if tbs.tabs_OnSelect and LeftBar_obj.TabCtrl.value_handle.tabtitle == tbs.id then tbs.tabs_OnSelect() end
            end
        end
        n = n - leftCount
    end
    if SideBar_obj.handle and n > 0 then
        if SideBar_obj.handle.Dialog then SideBar_obj.handle.ShowDialog() end
        SideBar_obj.TabCtrl.valuepos = n -1
        for _,tbs in pairs(SideBar_Plugins) do
            if tbs.tabs_OnSelect and SideBar_obj.TabCtrl.value_handle.tabtitle == tbs.id then tbs.tabs_OnSelect() end
        end
    end
end

local function  CreateToolBar()
    local str = _G.iuprops["settings.toolbars.layout"] or ''
    local strTbl = 'return function(h) return iup.expander{barsize = 1, state="OPEN", name = "toolbar_expander", iup.vbox{gap="1", iup.hbox{\n'
    local i = 0
    for p in str:gmatch('[^¦]+') do
        local _,_, pname, pf = p:find('(.-)(¬?)$')
        if pf == '¬' then
            strTbl = strTbl..'}, '..Iif(i > 0, 'iup.label{separator = "HORIZONTAL"}, ' ,'').. 'iup.hbox{\n'
            i = i + 1
        end
        local pI = dofile(props["SciteDefaultHome"].."\\tools\\UIPlugins\\"..pname)
        pI.toolbar(ToolBar_obj)
        local id = pI.code
        if pI.hlpdevice then id = pI.hlpdevice..'::'..id end
        iup.SetAttribute(ToolBar_obj.Tabs[pI.code].handle, "HELPID", id)
        strTbl = strTbl..'h.Tabs.'..pI.code..'.handle,\n'
    end
    strTbl = strTbl..'gap="3",margin="3x0", maxsize="x36", alignment = "ACENTER",}, name="ToolBar"}} end'
    return loadstring(strTbl)()
end

local function  CreateStatusBar()
    dofile (props["SciteDefaultHome"].."\\tools\\Status.lua")
    local tolsp1=iup.expander{barsize = 1, state="OPEN", name = "statusbar_expander",iup.hbox{
                            StatusBar_obj.Tabs.statusbar.handle,
                            gap='3',margin='3x0', name="StatusBar", maxsize="x30",
                        }}
    return tolsp1
end

local function SaveNamedValues(h, root)
    if not h then return end
    local child = nil
    repeat
        child = iup.GetNextChild(h, child)
        if child then
            if (child.value or child.valuepos or child.focusitem or child.size) and child.name and (iup.GetAttribute(child, 'HISTTORIZED') ~= 'NO') then
                local _,_,cType = tostring(child):find('IUP%((%w+)')
                local val = child.value
                if cType == 'list' and child.dropdown == "YES" then
                    local hist = {}
                    for i = 1, child.count do
                        if i > tonumber(child.visibleitems  or 15) then break end
                        table.insert(hist,iup.GetAttributeId(child, '', i))
                    end
                    _G.iuprops[root..'.'..child.name..'.hist'] = table.concat(hist,'¤')
                elseif cType == 'zbox' or cType == 'tabs' then
                    val = child.valuepos
                elseif cType == 'matrixlist' then
                    val = child.focusitem
                elseif cType == 'sbox' then
                    val = child.size
                elseif cType == 'split' then
                    if "0" == child.barsize then val = nil end
                end
                if val then _G.iuprops[root..'.'..child.name..'.value'] = val end
            end
            SaveNamedValues(child, root)
        end
    until not child
end

local function  CreateBox()
    -- Creates boxes
    local sb_elements = {}
    local function Pane(t)
        for i = 1, #t do
            if type(t[i])=='string' then
                table.insert(sb_elements, SideBar_Plugins[t[i]])
                SideBar_Plugins[t[i]].Bar_obj = pane_curObj
                t[i] = SideBar_Plugins[t[i]].handle
            end
        end
        if t.tabtitle then
            for i = 1, #sb_elements do sb_elements[i].id = t.tabtitle end
            sb_elements = {}
        end
        local b
        if t.type == "VBOX" then
            l = iup.vbox(t)
        elseif t.type == "SPLIT" then
            t.layoutdrag = 'NO'
            l = iup.split(t)
        elseif t.type == "FIND" then
            SideBar_Plugins.findrepl.Bar_obj = pane_curObj
            table.insert(sb_elements, SideBar_Plugins.findrepl)
           l =iup.expander{iup.scrollbox{SideBar_Plugins.findrepl.handle, name='FinReplScroll',expand="HORIZONTAL",scrollbar='NO',size='x108'}, barsize = '0', name="FinReplExp"}
        elseif t.type == nil then
            l = t[1]
        else print('Unsupported type:'..t.type) end
        l.tabtitle = t.tabtitle
        return l
    end

    local function SideBar(t, Bar_Obj, sciteid)
        if not t then return end
        t.tip= 'Ctrl+Alt+1,2,3,4...'
        t.name = 'sidebartab_'..sciteid
        Bar_Obj.sciteid = sciteid
        local brObj = Bar_Obj
        t.map_cb = (function(h)
            h.size="1x1"
        end)
        t.tabchange_cb = (function(_,new_tab, old_tab)
            --сначала найдем активный таб и установим его в SideBar_ob
            for _,tbs in pairs(SideBar_Plugins) do
                if tbs["tabs_OnSelect"] then tbs.tabs_OnSelect() end
                if tbs.id == new_tab.tabtitle then
                    if tbs["on_SelectMe"] then tbs.on_SelectMe() end
                end
            end
        end)
        t.k_any= (function(h,c) if c == iup.K_ESC then iup.PassFocus() end end)

        t.rightclick_cb=(function()
            menuhandler:PopUp('MainWindowMenu¦View¦'..sciteid)
        end)
        return iup.tabs(t)
    end

    local function SidePane(hVbox,sName,sSciteId,sSplit,sExpander,sSplit_CloseVal, Bar_obj, sSide, buttonImage)
        local h = iup.scitedetachbox{
            hVbox; orientation="HORIZONTAL";barsize=5;minsize="100x100";name=sName; shrink="yes"; buttonImage=buttonImage;
            sciteid = sSciteId;Split_h = iup.GetDialogChild(hMainLayout, sSplit);Split_CloseVal = sSplit_CloseVal;
            Dlg_Title = sSide.." Side Bar"; Dlg_Show_Cb = nil;
            On_Detach = (function(h, hNew, x, y)
                iup.GetDialogChild(iup.GetLayout(), sExpander).state="CLOSE";
                --h.visible
            end);
            Dlg_Close_Cb = (function(h)
                iup.GetDialogChild(iup.GetLayout(), sExpander).state="OPEN";
            end);
            Dlg_Show_Cb=(function(h,state)
                if state == 4 then
                    for _,tbs in pairs(SideBar_Plugins) do
                        if tbs["OnSideBarClouse"] then tbs.OnSideBarClouse() end
                    end
                end
            end);
            k_any=(function(_,key)
                if key == 65307 then iup.PassFocus() end
            end);

        }
        h.SaveValues = (function()
            for _,tbs in pairs(SideBar_Plugins) do
                if tbs.OnSaveValues then tbs.OnSaveValues() end
            end
            SaveNamedValues(hMainLayout,'sidebarctrl')
            SaveNamedValues(hVbox,'sidebarctrl')
        end)
        return h
    end

    local function settings2tbl(str, side)
        local defpath = props["SciteDefaultHome"].."\\tools\\UIPlugins\\"
        local function piCode(pI)
            if pI.code == 'findrepl' then
                return 'P{type = "FIND"}'
            else
                return '"'..pI.code..'"'
            end
            return pI.code
        end
        if str == '' then
            return 'return function() return nil end'
        end
        local tSide = {}
        local tCur

        for p in str:gmatch('[^¦]+') do
            local _, _, pname, pf = p:find('(.-)(¬?)$')
            if pf ~= '' then
                tCur = {title = pname}
                table.insert(tSide, tCur)
            else
                table.insert(tCur, pname)
            end
        end
        local strTabs = 'return function(P) return{\n'

        for i = 1, #tSide do
            tCur = tSide[i]
            if tCur[1] then
                local pI = dofile(defpath..tCur[1])
                pI.sidebar(defpath..tCur[1])
                --debug_prnArgs()
                local id = pI.code
                if pI.hlpdevice then id = pI.hlpdevice..'::'..id end
                iup.SetAttribute(SideBar_Plugins[pI.code].handle, "HELPID", id)
                local tabName = tCur.title
                if #tCur == 1 then
                    strTabs = strTabs..'P{"'..pI.code..'", tabtitle = "'..tabName..'"},\n'
                else
                    local strPrev = piCode(pI)
                    local bfixedheigth = pI.fixedheigth
                    for j = 2, #tCur do
                        pI = dofile(defpath..tCur[j])
                        pI.sidebar()
                        local id = pI.code
                        if pI.hlpdevice then id = pI.hlpdevice..'::'..id end
                        iup.SetAttribute(SideBar_Plugins[pI.code].handle, "HELPID", id)
                        strPrev = 'P{'..strPrev..', '..piCode(pI)..', '
                        if bfixedheigth or pI.fixedheigth then
                            strPrev = strPrev..'type="VBOX", '
                        else
                            strPrev = strPrev..' orientation="HORIZONTAL", type="SPLIT", name = "split'..pI.code..'", '
                        end
                        if j == #tCur then
                            strPrev = strPrev..'tabtitle = "'..tabName..'", '
                        end
                        strPrev = strPrev..'}'
                    end
                    strTabs = strTabs..strPrev..',\n'
                end
            end
        end
        --print(strTabs.."} end")
        return strTabs.."} end"
    end

    local tbArgLeft = assert(loadstring(settings2tbl(_G.iuprops["settings.user.leftbar"] or '',"tbArgLeft")))()
    local tbArgRight = assert(loadstring(settings2tbl(_G.iuprops["settings.user.rightbar"] or '',"tbArgRight")))()

    pane_curObj = SideBar_obj
    local tabs =  SideBar(tbArgRight(Pane), SideBar_obj, 'sidebar')

    if tabs then
        SideBar_obj.TabCtrl = tabs

        vbox = iup.vbox{tabs}
        SideBar_obj.handle = SidePane(vbox, 'SideBarSB','sidebar','SourceSplitRight', 'RightBarExpander', '1000', SideBar_obj, 'Right', 'application_sidebar_right_µ' )
    end

    pane_curObj = LeftBar_obj
    tabs =  SideBar(tbArgLeft(Pane), LeftBar_obj, 'leftbar')

    if tabs then
        LeftBar_obj.TabCtrl = tabs

        vbox = iup.vbox{tabs}       --SideBar_Plugins.livesearch.handle,
        LeftBar_obj.handle = SidePane(vbox, 'LeftBarSB','leftbar','SourceSplitLeft', 'LeftBarExpander', '0', LeftBar_obj, 'Left', 'application_sidebar_left_µ' )
    end

end

local function RestoreNamedValues(h, root)
    if not h then return end
    local child = nil
    repeat
        child = iup.GetNextChild(h, child)
        if child then
            -- print(child.name, (iup.GetAttribute(child, 'HISTTORIZED') ~= 'NO'))
            if child.name and (iup.GetAttribute(child, 'HISTTORIZED') ~= 'NO') then
                local _,_,cType = tostring(child):find('IUP%((%w+)')
                local val = _G.iuprops[root..'.'..child.name..'.value']
                if cType == 'list' and child.dropdown == "YES" then
                    local s = _G.iuprops[root..'.'..child.name..'.hist']
                    if s then
                        local i = 1
                        for w in s:gmatch('([^¤]+)') do
                            if i > tonumber(child.visibleitems  or 15) then break end
                            iup.SetAttributeId(child, 'INSERTITEM', i, w)
                            i = i + 1
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
            RestoreNamedValues(child, root)
        end
    until not child
end

local function InitSideBar()
    if tonumber(props['sidebar.hide']) == 1 then return end
    -- SideBar_obj.win = false --если установить true - панель будет показана отдельным окном
    SideBar_Plugins = {}
    SideBar_obj.Active = true
    LeftBar_obj.Active = true

    CreateBox();

    if SideBar_obj.handle then
        iup.Append(iup.GetDialogChild(hMainLayout, "RightBarPH"),SideBar_obj.handle)
        iup.Map(SideBar_obj.handle)
    end

    if LeftBar_obj.handle then
        iup.Append(iup.GetDialogChild(hMainLayout, "LeftBarPH"),LeftBar_obj.handle)
        iup.Map(LeftBar_obj.handle)
    end

    local bs2 = iup.GetDialogChild(hMainLayout, "BottomSplit2")
    local bFindInSide
    if  not SideBar_Plugins.findrepl then
        dofile(props["SciteDefaultHome"].."\\tools\\UIPlugins\\FindRepl.lua").sidebar()
        local hTmp= iup.dialog{SideBar_Plugins.findrepl.handle}
        local hBx = iup.GetDialogChild(hTmp, 'FindReplDetach')
        iup.Detach(hBx)
        iup.Insert(iup.GetDialogChild(hMainLayout, "FindPlaceHolder"), nil, hBx)
        iup.Map(hBx)
        iup.Destroy(hTmp)
        bs2.barsize="3"
        if tonumber(bs2.value) > 980 then bs2.value = 800 end
        iup.GetDialogChild(hMainLayout, "FindPlaceHolder").yautohide = 'NO'
        iup.Refresh(iup.GetDialogChild(hMainLayout, "FindPlaceHolder"))
        iup.SetAttribute(hBx, "HELPID", 'findrepl')
    else
        bs2.barsize="0"
        bs2.value = 1000
        bFindInSide = true
    end
    SideBar_Plugins.findrepl.OnCreate()

    for i = 1, #tEvents do
        for _,tbs in pairs(SideBar_Plugins) do
            if tbs[tEvents[i]] then AddEventHandler(tEvents[i],tbs[tEvents[i]]) end
        end
    end

    local bSplitter = iup.GetDialogChild(hMainLayout, "BottomSplit")

    local function toggleOf()
        if iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize == '3' then
           iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize = '0'
           iup.GetDialogChild(hMainLayout, "BottomExpander").state = 'CLOSE'
           _G.iuprops["sidebarctrl.BottomBarSplit.value"] = iup.GetDialogChild(hMainLayout, "BottomBarSplit").value
            iup.GetDialogChild(hMainLayout, "BottomBarSplit").value = '1000'
        end
    end
    local function toggleOn()
        if iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize == '0' then
           iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize = '3'
           iup.GetDialogChild(hMainLayout, "BottomExpander").state = 'OPEN'
           iup.GetDialogChild(hMainLayout, "BottomBarSplit").value = _G.iuprops["sidebarctrl.BottomBarSplit.value"] or '900'
        end
    end

    ConsoleBar = iup.scitedetachbox{
        HANDLE = iup.GetDialogChild(hMainLayout, "ConsoleDetach"); buttonImage='terminal_µ';
        sciteid = 'concolebar';Split_h = bSplitter;Split_CloseVal = "0";
        Dlg_Title = "Console"; Dlg_Show_Cb = nil; MenuEx = "OUTPUT";
        Dlg_Close_Cb = (function(h)
        end);
        Dlg_Resize_Cb = (function(h,width, height)
        end);
        Dlg_Show_Cb = (function(h, state)
            if state == 0 and (_G.iuprops['findresbar.win'] or '0')~='0' then
                if (_G.iuprops['findrepl.win'] or '0')=='0' and not SideBar_Plugins.findrepl.Bar_obj then
                    SideBar_Plugins.findrepl.handle_deattach.detachPos(false)
                    _G.iuprops['findrepl.visible.state'] = "1"
                end
                 _G.iuprops['dialogs.concolebar.splitvalue'] =  _G.iuprops['dialogs.findresbar.splitvalue']
                toggleOf()
             end
        end);
        Dlg_BeforeAttach = (function()
            if _G.iuprops['findresbar.win']~='0' then
                toggleOn()
                _G.iuprops['dialogs.concolebar.splitvalue'] = '1000'
            end
        end);
    }

    FindResBar = iup.scitedetachbox{
        HANDLE = iup.GetDialogChild(hMainLayout, "FindResDetach"); buttonImage='binocular__pencil_µ';
        sciteid = 'findresbar';Split_h = bSplitter;Split_CloseVal = "1000";
        Dlg_Title = "Find Results"; Dlg_Show_Cb = nil; MenuEx = "FINDRES";
        Dlg_Close_Cb = (function(h)
        end);
        Dlg_Resize_Cb = (function(h,width, height)
        end);
        Dlg_Show_Cb = (function(h, state)
            if state == 0 and (_G.iuprops['concolebar.win'] or '0')~='0' then
                if (_G.iuprops['findrepl.win'] or '0')=='0' and not SideBar_Plugins.findrepl.Bar_obj then
                    SideBar_Plugins.findrepl.handle_deattach.detachPos(false)
                    _G.iuprops['findrepl.visible.state'] = "1"
                end
                _G.iuprops['dialogs.findresbar.splitvalue'] =  _G.iuprops['dialogs.concolebar.splitvalue']
                toggleOf()
            end
        end);
        Dlg_BeforeAttach = (function(h, state)
            if _G.iuprops['concolebar.win']~='0' then
                toggleOn()
                _G.iuprops['dialogs.findresbar.splitvalue'] = '0'
            end
        end);
    }

end

local function InitToolBar()
    --if true then return end
    local vbScite = iup.GetDialogChild(hMainLayout, "SciteVB")
    ToolBar_obj.Tabs = {}

    tTlb = {CreateToolBar()(ToolBar_obj)}
    tTlb.control = "YES"
    tTlb.sciteid="iuptoolbar"
    tTlb.show_cb=(function(h,state)
        if state == 0 and props['iuptoolbar.visible'] == '1' and props['iuptoolbar.restarted'] ~= '1' then
           scite.MenuCommand(IDM_VIEWTLBARIUP)
        elseif state == 4 then
            for _,tbs in pairs(ToolBar_obj.Tabs) do
                if tbs["OnSideBarClouse"] then tbs.OnSideBarClouse() end
            end
            for i = 1, #tEvents do
                for _,tbs in pairs(ToolBar_obj.Tabs) do
                   if tbs[tEvents[i]] then RemoveEventHandler(tEvents[i],tbs[tEvents[i]]) end
                end
            end
            props['iuptoolbar.restarted'] = '1'
        end
    end)

    tTlb.resize_cb=(function(_,x,y) if ToolBar_obj.handle ~= nil then ToolBar_obj.size = ToolBar_obj.handle.size end end)
    --ToolBar_obj.handle = iup.scitedialog(tTlb)
    local hTmp= iup.dialog(tTlb)
    local hBx = iup.GetDialogChild(hTmp, 'toolbar_expander')
    iup.Detach(hBx)
    iup.Destroy(hTmp)
    ToolBar_obj.handle = iup.Insert(vbScite, iup.GetDialogChild(vbScite, 'TabbarExpander'), hBx)
    iup.Map(hBx)
    for i = 1, #tEvents do
        for _,tbs in pairs(ToolBar_obj.Tabs) do
            if tbs[tEvents[i]] then AddEventHandler(tEvents[i],tbs[tEvents[i]]) end
        end
    end
    hBx.state = (_G.iuprops["layout.toolbar_expander"] or 'OPEN')
    ToolBar_obj.size = ToolBar_obj.handle.size
    iup.PassFocus()
end


local function InitStatusBar()
     local vbScite = iup.GetDialogChild(hMainLayout, "SciteVB")
    StatusBar_obj = {}
    StatusBar_obj.Tabs = {}

    local tTlb = {CreateStatusBar()}
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
    local hTmp= iup.dialog(tTlb)
    local hBx = iup.GetDialogChild(hTmp, 'statusbar_expander')
    iup.Detach(hBx)
    iup.Destroy(hTmp)
    StatusBar_obj.handle = iup.Append(vbScite, hBx)
    iup.Map(hBx)
    hBx.state = (_G.iuprops["layout.statusbar_expander"] or 'OPEN')

    for i = 1, #tEvents do
        for _,tbs in pairs(StatusBar_obj.Tabs) do
            if tbs[tEvents[i]] then AddEventHandler(tEvents[i],tbs[tEvents[i]]) end
        end
    end
    if ToolBar_obj.handle then
        StatusBar_obj.handle.size = ToolBar_obj.handle.size
        StatusBar_obj.size = StatusBar_obj.handle.size
    end
    iup.PassFocus()
end

require "menuhandler"
local function InitMenuBar()
    if not _G.sys_Menus then return end
    local vbScite = iup.GetDialogChild(hMainLayout, "SciteVB")
    MenuBar_obj = {}
    MenuBar_obj.Tabs = {}

    local mnu = sys_Menus.MainWindowMenu

    local hb = { alignment = 'ACENTER',expand ='HORIZONTAL' }
    for i = 1, #mnu do
        if mnu[i][1] ~='_HIDDEN_' then
            table.insert(hb,menuhandler:GreateMenuLabel(mnu[i]))
            if i == #mnu - 1 then table.insert(hb,iup.fill{})
            elseif i < #mnu - 1 then table.insert(hb, iup.label{separator = "VERTICAL",maxsize='x18'}) end
        end
    end


    local tTlb = {iup.expander{barsize = 1, state="OPEN", name = "MenuBar",iup.vbox{expandchildren ='YES', iup.hbox(hb),iup.label{separator = "HORIZONTAL"}}}};

    tTlb.control = "YES"
    tTlb.sciteid="iupmenubar"

    local hTmp= iup.dialog(tTlb)

    local hBx = iup.GetDialogChild(hTmp, 'MenuBar')
    iup.Detach(hBx)
    iup.Destroy(hTmp)
    MenuBar_obj.handle = iup.Insert(vbScite,nil, hBx)
    iup.Map(hBx)


    iup.PassFocus()
end

InitMenuBar()
--Автозагрузка скрытых плагинов
local str = _G.iuprops["settings.hidden.plugins"] or ''
local strTbl = 'return function(h) return iup.expander{barsize = 1, state="OPEN", name = "toolbar_expander", iup.vbox{gap="1", iup.hbox{\n'
local i = 0
for p in str:gmatch('[^¦]+') do
    local pI = dofile(props["SciteDefaultHome"].."\\tools\\UIPlugins\\"..p)
    if pI then
        pI.hidden()
    else
        pritn('Hidden plugin "'..p..'" not found')
    end
end
local str = _G.iuprops["settings.commands.plugins"] or ''
for p in str:gmatch('[^¦]+') do
    local pI = dofile(props["SciteDefaultHome"].."\\tools\\Commands\\"..p)
    if pI and pI.run then
        local t = {}
        t[1] = pI.title
        if pI.key then t.key = pI.key end
        t.action = function() dofile(props["SciteDefaultHome"].."\\tools\\Commands\\"..p).run() end

        menuhandler:InsertItem('MainWindowMenu', pI.path or 'Tools¦Utils¦xxx', t)
    end
end

InitSideBar()
InitToolBar()

InitStatusBar()
RestoreNamedValues(hMainLayout, 'sidebarctrl')
iup.Refresh(hMainLayout)
if not LeftBar_obj.handle then iup.GetDialogChild(hMainLayout, "LeftBarExpander").state='CLOSE'; iup.GetDialogChild(hMainLayout, "SourceSplitLeft").barsize = '0' ; iup.GetDialogChild(hMainLayout, "SourceSplitLeft").value = '0'
else iup.GetDialogChild(hMainLayout, "LeftBarExpander").state='OPEN'; iup.GetDialogChild(hMainLayout, "SourceSplitLeft").barsize = '3'   end
if not SideBar_obj.handle then iup.GetDialogChild(hMainLayout, "RightBarExpander").state='CLOSE'; iup.GetDialogChild(hMainLayout, "SourceSplitRight").barsize = '0' ; iup.GetDialogChild(hMainLayout, "SourceSplitRight").value = '1000'
else iup.GetDialogChild(hMainLayout, "RightBarExpander").state='OPEN'; iup.GetDialogChild(hMainLayout, "SourceSplitRight").barsize = '3'   end
if iup.GetDialogChild(hMainLayout, "BottomSplit2").barsize=="0" then iup.GetDialogChild(hMainLayout, "BottomSplit2").value="1000" end


AddEventHandler("OnSendEditor", function(id_msg, wp, lp)
    if id_msg == SCN_NOTYFY_ONPOST then
        if wp == POST_CONTINUESTARTUP then  --Показ отдельным окном развязываем через пост, иначе плохо иконки показывает
            props['session.reload'] = _G.iuprops['session.reload']
            iup.RestoreFiles()

            if navigation_Unblock then navigation_Unblock() end
            local bHide
            if ((_G.iuprops['sidebar.win'] or '0')~='0') and SideBar_obj.handle then bHide = (_G.iuprops['sidebar.win']=='2');    SideBar_obj.handle.detachPos(not bHide) end ;RestoreNamedValues(SideBar_obj.handle, 'sidebarctrl')
            if ((_G.iuprops['leftbar.win'] or '0')~='0') and LeftBar_obj.handle then bHide = (_G.iuprops['leftbar.win']=='2');    LeftBar_obj.handle.detachPos(not bHide) end ;RestoreNamedValues(LeftBar_obj.handle, 'sidebarctrl')
            if (_G.iuprops['concolebar.win'] or '0')~='0'                       then bHide = (_G.iuprops['concolebar.win']=='2'); ConsoleBar.detachPos(not bHide) end
            if (_G.iuprops['findresbar.win'] or '0')~='0'                       then bHide = (_G.iuprops['findresbar.win']=='2'); FindResBar.detachPos(not bHide)end
            if (_G.iuprops['findrepl.win'] or '0')~='0'                         then bHide = (_G.iuprops['findrepl.win']=='2');   local h = iup.GetDialogChild(hMainLayout, "FindReplDetach"); h.detachPos(not bHide) end

            if _G.dialogs['findresbar'] and _G.dialogs['concolebar'] then
                iup.GetDialogChild(hMainLayout, "BottomExpander").state = 'CLOSE'
                iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize = '0'
                iup.GetDialogChild(hMainLayout, "BottomBarSplit").value = '1000'
            end

            menuhandler:RegistryHotKeys()

            local frScroll = iup.GetDialogChild(iup.GetLayout(), "FinReplScroll")

            scite.EnsureVisible()
            if dlg_SPLASH then scite.PostCommand(POST_CONTINUESTARTUP2, 0) end

            props['session.started'] = '1'
            if _G.iuprops['command.reloadprops'] then _G.iuprops['command.reloadprops'] = false; scite.PostCommand(POST_RELOADPROPS,0) end
        elseif wp == POST_CONTINUESTARTUP2 then
            if dlg_SPLASH then dlg_SPLASH:postdestroy()end
        elseif wp == POST_CONTINUESHOWMENU then
            menuhandler:ContinuePopUp()
        end
    end
end)

local bMenu,bToolBar,bStatusBar
local bSideBar,bLeftBar,bconsoleBar,bFindResBar,bFindRepl

AddEventHandler("OnLayOutNotify", function(cmd)
    if cmd == "SHOW_FINDRES" then
        if (_G.iuprops['findresbar.win'] or '0')=='1' then return end
        if (_G.dialogs and _G.iuprops['findresbar.win'] or '0')=='2' then
            local h = iup.GetFocus()
            _G.dialogs['findresbar'].Switch();
            if h and h.name == 'livesearch_bar' then iup.SetFocus(h); end
            return
        end
        if tonumber(iup.GetDialogChild(hMainLayout, "BottomSplit").value) > 990 then iup.GetDialogChild(hMainLayout, "BottomSplit").value = "667" end
    elseif cmd == "SHOW_OUTPUT" then
        if (_G.iuprops['concolebar.win'] or '0')=='1' then return end
        if _G.dialogs and (_G.iuprops['concolebar.win'] or '0')=='2' and _G.dialogs['concolebar'] then _G.dialogs['concolebar'].Switch(); return end
        if _G.dialogs and tonumber(iup.GetDialogChild(hMainLayout, "BottomSplit").value) < 10 then iup.GetDialogChild(hMainLayout, "BottomSplit").value = "333" end
    elseif cmd == "FULLSCREEN_ON" then
        bMenu      = iup.GetDialogChild(iup.GetLayout(), "MenuBar").isOpen()
        bToolBar   = iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").isOpen()
        bStatusBar = iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").isOpen()
        if bMenu then       iup.GetDialogChild(iup.GetLayout(), "MenuBar").switch()            end
        if bToolBar then    iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").switch()   end
        if bStatusBar then  iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").switch() end

        bSideBar   = ((_G.iuprops['sidebar.win'] or '0')=='0') and SideBar_obj.handle
        bLeftBar   = ((_G.iuprops['leftbar.win'] or '0')=='0') and LeftBar_obj.handle
        bconsoleBar=  (_G.iuprops['concolebar.win'] or '0')=='0'
        bFindResBar=  (_G.iuprops['findresbar.win'] or '0')=='0'
        bFindRepl  =  (_G.iuprops['findrepl.win'] or '0')=='0' and not SideBar_Plugins.findrepl.Bar_obj

        if bSideBar    then SideBar_obj.handle.detachPos(false); end
        if bLeftBar    then LefrBar_obj.handle.detachPos(false); end
        if bFindRepl   then iup.GetDialogChild(hMainLayout, "FindReplDetach").detachPos(false); end
        if bconsoleBar then ConsoleBar.detachPos(false); end
        if bFindResBar then FindResBar.detachPos(false); end

    elseif cmd == "FULLSCREEN_OFF" then
        if bMenu then       iup.GetDialogChild(iup.GetLayout(), "MenuBar").switch()            end
        if bToolBar then    iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").switch()   end
        if bStatusBar then  iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").switch() end

        if bSideBar    then SideBar_obj.handle.Attach() end
        if bLeftBar    then LefrBar_obj.handle.Attach() end
        if bconsoleBar then ConsoleBar.Attach() end
        if bFindResBar then FindResBar.Attach() end
        if bFindRepl   then iup.GetDialogChild(hMainLayout, "FindReplDetach").Attach() end
    end
end)

AddEventHandler("OnKey", function(key, shift, ctrl, alt, char)
    if key ==  27 and not shift and not ctrl and not alt then
        if output.Focus then
            if (_G.iuprops['concolebar.win'] or '0') == '1' then ConsoleBar.Switch() end
        elseif findres.Focus then
            if (_G.iuprops['findresbar.win'] or '0') == '1' then FindResBar.Switch() end
        end
    end
end)

menuhandler:InsertItem('MainWindowMenu', '_HIDDEN_¦xxx',
{'Sidebar', {
    {'Tab1', key = 'Ctrl+Alt+1',  action=function() sidebar_Switch(1) end, },
    {'Tab2', key = 'Ctrl+Alt+2',  action=function() sidebar_Switch(2) end, },
    {'Tab3', key = 'Ctrl+Alt+3',  action=function() sidebar_Switch(3) end, },
    {'Tab4', key = 'Ctrl+Alt+4',  action=function() sidebar_Switch(4) end, },
    {'Tab5', key = 'Ctrl+Alt+5',  action=function() sidebar_Switch(5) end, },
    {'Tab6', key = 'Ctrl+Alt+6',  action=function() sidebar_Switch(6) end, },
    {'Tab7', key = 'Ctrl+Alt+7',  action=function() sidebar_Switch(7) end, },
}})

menuhandler:DoPostponedInsert()
