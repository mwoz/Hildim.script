require 'shell'
SideBar_obj = {}
LeftBar_obj = {}
SideBar_Plugins = {}
TabBar_obj = {}

local win_parent --создаем основное окно
local tbs
local vbox
local vFuncNav
local vAbbrev
local vSys
local vFileMan
local vFindRepl
local hMainLayout = iup.GetLayout()
local BottomBar, ConsoleBar, FindRepl
local pane_curObj

iup.SetGlobal("DEFAULTFONTSIZE", Iif(props['iup.defaultfontsize']=='', "10", props['iup.defaultfontsize']))
iup.SetGlobal("TXTHLCOLOR", "200 200 200")
                               -- RGB(121, 161, 201)
iup.PassFocus=(function()
    iup.SetFocus(iup.GetDialogChild(hMainLayout, "Source"))
end)

function sidebar_Switch(n)
    if LeftBar_obj.handle then
        leftCount = tonumber(LeftBar_obj.TabCtrl.count)
        if n <= leftCount then
            LeftBar_obj.TabCtrl.valuepos = n -1
            for _,tbs in pairs(SideBar_Plugins) do
                if tbs.tabs_OnSelect and LeftBar_obj.TabCtrl.value_handle.tabtitle == tbs.id then tbs.tabs_OnSelect() end
            end
        end
        n = n - leftCount
    end
    if SideBar_obj.handle and n > 0 then
        SideBar_obj.TabCtrl.valuepos = n -1
        for _,tbs in pairs(SideBar_Plugins) do
            if tbs.tabs_OnSelect and SideBar_obj.TabCtrl.value_handle.tabtitle == tbs.id then tbs.tabs_OnSelect() end
        end
    end


end
--[[function sidebar_Focus()
    iup.SetFocus(SideBar_obj.TabCtrl)
end]]
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
                            gap='3',margin='3x0', name="ToolBar", maxsize="x36",
                        }
    return tolsp1
end
local function  CreateStatusBar()
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\Status.lua")
    local tolsp1=iup.hbox{
                            StatusBar_obj.Tabs.statusbar.handle,
                            gap='3',margin='3x0', name="StatusBar", maxsize="x30",
                        }
    return tolsp1
end

local function SaveNamedValues(h, root)
    if not h then return end
    local child = nil
    repeat
        child = iup.GetNextChild(h, child)
        if child then
            if (child.value or child.valuepos or child.focusitem or child.size) and child.name then
                local _,_,cType = tostring(child):find('IUP%((%w+)')
                local val = child.value
                if cType == 'list' and child.dropdown == "YES" then
                    local hist = {}
                    for i = 1, child.count do
                        if i > tonumber(child.visibleitems  or 15) then break end
                        table.insert(hist,iup.GetAttributeId(child, '', i))
                    end
                    _G.iuprops[root..'.'..child.name..'.hist'] = table.concat(hist,'§')
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

    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\Abbrev.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\Bookmark.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\FileMan.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\Functions.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\Navigation.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\FindRepl.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\Atrium.lua")

    -- Creates boxes
    local sb_elements = {}
    function Pane(t)
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
            l =iup.expander{iup.scrollbox{SideBar_Plugins.findrepl.handle, name='FinReplScroll',expand="HORIZONTAL",scrollbar='NO',minsize='x250'}, barsize = '0', name="FinReplExp"}
        elseif t.type == nil then
            l = t[1]
        else print('Unsupported type:'..t.type) end
        l.tabtitle = t.tabtitle
        return l
    end
    local function SideBar(t, Bar_Obj)
        if not t then return end
        t.name="tabMain"
        t.tip= 'Ctrl+1,2,3,4'
        local brObj = Bar_Obj
        t.map_cb = (function(h)
            h.size="1x1"
        end)
        t.tabchange_cb = (function(_,new_tab, old_tab)
            --сначала найдем активный таб и установим его в SideBar_obj

            for _,tbs in pairs(SideBar_Plugins) do
                if tbs["tabs_OnSelect"] then tbs.tabs_OnSelect() end
                if tbs.id == new_tab.tabtitle then
                    if tbs["on_SelectMe"] then tbs.on_SelectMe() end
                end
            end
        end)
        t.k_any= (function(h,c) if c == iup.K_ESC then iup.PassFocus() end end)

        t.rightclick_cb=(function()
            if _G.iuprops['sidebar.win'] == '0' then
                local mnu = iup.menu
                {
                  iup.item{title="Deattach Sidebar",action=(function()
                      brObj.handle.DetachRestore = true;     --!!!
                      brObj.handle.detach = 1
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
    return iup.tabs(t)
    end

    local function SidePane(hVbox,sName,sSciteId,sSplit,sExpander,sSplit_CloseVal, Bar_obj, sSide)
        local h = iup.scitedetachbox{
            hVbox; orientation="HORIZONTAL";barsize=5;minsize="100x100";name=sName; shrink="yes";
            sciteid = sSciteId;Split_h = iup.GetDialogChild(hMainLayout, sSplit);Split_CloseVal = sSplit_CloseVal;
            Dlg_Title = sSide.." Side Bar /Close For Attach/"; Dlg_Show_Cb = nil;
            On_Detach = (function(h, hNew, x, y)
                iup.GetDialogChild(iup.GetLayout(), sExpander).state="CLOSE";
                --h.visible
            end);
            Dlg_Close_Cb = (function(h)
                if _G.iuprops['findrepl.win']=='1' then
                    _G.FindReplDialog.close_cb(_G.FindReplDialog)
                end
                iup.GetDialogChild(iup.GetLayout(), sExpander).state="OPEN";
            end);
            show_cb=(function(h,state)
                if state == 0 then
                   h.size = '1x1'
                elseif state == 4 then
                    for _,tbs in pairs(SideBar_Plugins) do
                        if tbs["OnSideBarClouse"] then tbs.OnSideBarClouse() end
                    end
                    for i = 1, #tEvents do
                        for _,tbs in pairs(SideBar_Plugins) do
                           if tbs[tEvents[i]] then RemoveEventHandler(tEvents[i],tbs[tEvents[i]]) end
                        end
                    end
                    Bar_obj.Active = false
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

    local plugin = props["SciteDefaultHome"].."\\data\\home\\SideBarLayout.lua"
    if shell.fileexists(plugin) then dofile(plugin)
    else dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\SideBarLayout.lua")
    end

    pane_curObj = SideBar_obj
    local tabs =  SideBar(tbArgRight(), SideBar_obj)
    tbArgRight = nil

    if tabs then
        SideBar_obj.TabCtrl = tabs

        vbox = iup.vbox{tabs}       --SideBar_Plugins.livesearch.handle,
        SideBar_obj.handle = SidePane(vbox, 'SideBarSB','sidebar','SourceSplitRight', 'RightBarExpander', '1000', SideBar_obj, 'Right' )
    end

    pane_curObj = LeftBar_obj
    tabs =  SideBar(tbArgLeft(), LeftBar_obj)
    tbArgLeft = nil

    if tabs then
        LeftBar_obj.TabCtrl = tabs

        vbox = iup.vbox{tabs}       --SideBar_Plugins.livesearch.handle,
        LeftBar_obj.handle = SidePane(vbox, 'LeftBarSB','leftbar','SourceSplitLeft', 'LeftBarExpander', '0', LeftBar_obj, 'Left' )
    end

end
local tEvents = {"OnClose","OnSendEditor","OnSwitchFile","OnOpen","OnSave","OnUpdateUI","OnDoubleClick","OnKey","OnDwellStart","OnNavigation","OnSideBarClouse", "OnMenuCommand", "OnCreate"}

local function RestoreNamedValues(h, root)
    if not h then return end
    local child = nil
    repeat
        child = iup.GetNextChild(h, child)
        if child then
            if child.name then
                local _,_,cType = tostring(child):find('IUP%((%w+)')
                local val = _G.iuprops[root..'.'..child.name..'.value']
                if cType == 'list' and child.dropdown == "YES" then
                    local s = _G.iuprops[root..'.'..child.name..'.hist']
                    if s then
                        local i = 1
                        for w in s:gmatch('([^§]+)') do
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
    SideBar_obj.win = (_G.iuprops['sidebar.win']=='1') --если установить true - панель будет показана отдельным окном
    SideBar_obj.Active = true
    LeftBar_obj.win = (_G.iuprops['leftbar.win']=='1') --если установить true - панель будет показана отдельным окном
    LeftBar_obj.Active = true

    --if true then return end=

    CreateBox();

    if SideBar_obj.handle then
        iup.Append(iup.GetDialogChild(hMainLayout, "RightBarPH"),SideBar_obj.handle)
        iup.Map(SideBar_obj.handle)
    end

    if LeftBar_obj.handle then
        iup.Append(iup.GetDialogChild(hMainLayout, "LeftBarPH"),LeftBar_obj.handle)
        iup.Map(LeftBar_obj.handle)
    end

    -- RestoreNamedValues(hMainLayout, 'sidebarctrl')

    for i = 1, #tEvents do
        for _,tbs in pairs(SideBar_Plugins) do
            if tbs[tEvents[i]] then AddEventHandler(tEvents[i],tbs[tEvents[i]]) end
        end
    end
    SideBar_Plugins.findrepl.OnCreate()

    BottomBar = iup.scitedetachbox{
        HANDLE = iup.GetDialogChild(hMainLayout, "BottomBar");
        sciteid = 'bottombar';Split_h = iup.GetDialogChild(hMainLayout, "BottomBarSplit");Split_CloseVal = "1000";
        Dlg_Title = "BottomBar /Close For Attach/";
        Dlg_Close_Cb = (function(h)
            if _G.iuprops['concolebar.win']=='1' then
                iup.GetDialogChild(hMainLayout, "BottomSplit").value = _G.iuprops['dialogs.concolebar.splitvalue']
                iup.GetDialogChild(hMainLayout, "BottomSplit").barsize = "3"
                iup.GetDialogChild(hMainLayout, "ConsoleExpander").state = "OPEN"
                _G.iuprops['concolebar.win']='0'
                iup.GetDialogChild(hMainLayout, "ConsoleDetach").restore = 1
                _G.dialogs['concolebar'] = nil
            end
        end);
        Dlg_Resize_Cb = (function(h,width, height)
            if _G.iuprops['concolebar.win']=='1' then iup.GetDialogChild(hMainLayout, "BottomSplit").value = "0" end
        end);
     }

    ConsoleBar = iup.scitedetachbox{
        HANDLE = iup.GetDialogChild(hMainLayout, "ConsoleDetach");
        sciteid = 'concolebar';Split_h = iup.GetDialogChild(hMainLayout, "BottomSplit");Split_CloseVal = "0";
        Dlg_Title = "ConsoleBar /Close For Attach/"; Dlg_Show_Cb = nil;
        Dlg_Close_Cb = (function(h)
        end);
        Dlg_Resize_Cb = (function(h,width, height)
        end);
     }

end

local function InitToolBar()
    local vbScite = iup.GetDialogChild(hMainLayout, "SciteVB")
    TabBar_obj.Tabs = {}
                     --iup.hbox{iup.text{expand='YES', expand='HORIZONTAL'}}
    tTlb = {CreateToolBar();expand='YES', maxbox="NO",minbox ="NO",resize ="YES", menubox="NO", shrink='YES', minsize="10x10"}
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
    --TabBar_obj.handle = iup.scitedialog(tTlb)
    local hTmp= iup.dialog(tTlb)
    local hBx = iup.GetDialogChild(hTmp, 'ToolBar')
    iup.Detach(hBx)
    iup.Destroy(hTmp)
    TabBar_obj.handle = iup.Insert(vbScite, nil, hBx)
    iup.Map(hBx)
    for i = 1, #tEvents do
        for _,tbs in pairs(TabBar_obj.Tabs) do
            if tbs[tEvents[i]] then AddEventHandler(tEvents[i],tbs[tEvents[i]]) end
        end
    end
    TabBar_obj.size = TabBar_obj.handle.size
    iup.PassFocus()
end


local function InitStatusBar()
     local vbScite = iup.GetDialogChild(hMainLayout, "SciteVB")
    StatusBar_obj = {}
    StatusBar_obj.Tabs = {}

    local tTlb = {CreateStatusBar();expand='YES', maxbox="NO",minbox ="NO",resize ="YES", menubox="NO", shrink='YES', minsize="10x10"}
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
    --tTlb.resize_cb=(function(_,x,y) if StatusBar_obj.handle ~= nil then  StatusBar_obj.size = StatusBar_obj.handle.size end end)
    --StatusBar_obj.handle = iup.scitedialog(tTlb)
    local hTmp= iup.dialog(tTlb)
    local hBx = iup.GetDialogChild(hTmp, 'StatusBar')
    iup.Detach(hBx)
    iup.Destroy(hTmp)
    StatusBar_obj.handle = iup.Append(vbScite, hBx)
    iup.Map(hBx)

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
RestoreNamedValues(hMainLayout, 'sidebarctrl')
iup.Refresh(hMainLayout)
if not LeftBar_obj.handle then iup.GetDialogChild(hMainLayout, "LeftBarExpander").state='CLOSE'; iup.GetDialogChild(hMainLayout, "SourceSplitLeft").barsize = '0' ; iup.GetDialogChild(hMainLayout, "SourceSplitLeft").value = '0'
else iup.GetDialogChild(hMainLayout, "LeftBarExpander").state='OPEN'; iup.GetDialogChild(hMainLayout, "SourceSplitLeft").barsize = '3'   end
if not SideBar_obj.handle then iup.GetDialogChild(hMainLayout, "RightBarExpander").state='CLOSE'; iup.GetDialogChild(hMainLayout, "SourceSplitRight").barsize = '0' ; iup.GetDialogChild(hMainLayout, "SourceSplitRight").value = '1000'
else iup.GetDialogChild(hMainLayout, "RightBarExpander").state='OPEN'; iup.GetDialogChild(hMainLayout, "SourceSplitRight").barsize = '3'   end
if iup.GetDialogChild(hMainLayout, "BottomSplit2").barsize=="0" then iup.GetDialogChild(hMainLayout, "BottomSplit2").value="1000" end

local function RestoreLayOut(strLay)
    strLay = strLay:gsub('^Х','')
    for n in strLay:gmatch('%d+') do
        n = tonumber(n)
        if shell.bit_and(editor.FoldLevel[n],SC_FOLDLEVELHEADERFLAG) ~=0 then
            local lineMaxSubord = editor:GetLastChild(n,-1)
            if n < lineMaxSubord then
                editor.FoldExpanded[n] = false
                editor:HideLines(n + 1, lineMaxSubord)
            end
        end
    end

end

AddEventHandler("OnSendEditor", function(id_msg, wp, lp)
    if id_msg == SCN_NOTYFY_ONPOST then
        if wp == 3 then  --ѕоказ отдельным окном разв€зываем через пост, иначе плохо иконки показывает
            props['session.reload'] = _G.iuprops['session.reload']
            if _G.iuprops['buffers'] ~= nil and _G.iuprops['session.reload'] == '1' then
                local bNew = (props['FileName'] ~= '')
                local t,p,bk,l = {},{},{},{}
                for f in _G.iuprops['buffers']:gmatch('[^Х]+') do
                    table.insert(t, f)
                end
                local bki
                if _G.iuprops['buffers.pos'] then
                    for f in _G.iuprops['buffers.pos']:gmatch('[^Х]+') do
                        local i = 0
                        for g in f:gmatch('[^¶]+') do
                            if i==0 then
                                table.insert(p, g)
                                bki = {}
                                table.insert(bk, bki)
                            else table.insert(bki, g) end
                            i = 1
                        end
                    end
                end
                if _G.iuprops['buffers.layouts'] then
                    for f in _G.iuprops['buffers.layouts']:gmatch('Х[^Х]*') do
                        table.insert(l, f)
                    end
                end
                _G.iuprops['buffers'] = nil
                for i = #t,1,-1 do
                    scite.Open(t[i])
                    if p[i] then editor.FirstVisibleLine = tonumber(p[i]) end
                    if bk and bk[i] then
                        for j = 1, #(bk[i]) do
                            editor:MarkerAdd(tonumber(bk[i][j]), 1)
                        end
                    end
                    if l and l[i] then
                        RestoreLayOut(l[i])
                    end
                end
                scite.EnsureVisible()
                if bNew then
                    scite.buffers.SetDocumentAt(0)
                else
                    local b = tonumber(_G.iuprops['buffers.current'] or -1)
                    if b >= 0 then scite.buffers.SetDocumentAt(b) end
                end
            end
            navigation_Unblock()
            if SideBar_obj.win then SideBar_obj.handle.DetachRestore = true; SideBar_obj.handle.detach = 1 end ;RestoreNamedValues(SideBar_obj.handle, 'sidebarctrl')
            if LeftBar_obj.win then LeftBar_obj.handle.DetachRestore = true; LeftBar_obj.handle.detach = 1 end ;RestoreNamedValues(LeftBar_obj.handle, 'sidebarctrl')
            if _G.iuprops['bottombar.win']=='1' then BottomBar.DetachRestore = true;BottomBar.detach = 1 end
            if _G.iuprops['concolebar.win']=='1' then ConsoleBar.DetachRestore = true;ConsoleBar.detach = 1 end
            if _G.iuprops['findrepl.win']=='1' then iup.GetDialogChild(hMainLayout, "FindReplDetach").detachPos() end
            scite.EnsureVisible()
            dlg_SPLASH:postdestroy()
        end
    end
end)

AddEventHandler("OnLayOutNotify", function(cmd)
    if cmd == "SHOW_FINDRES" then
        if tonumber(iup.GetDialogChild(hMainLayout, "BottomSplit").value) > 990 then iup.GetDialogChild(hMainLayout, "BottomSplit").value = "667" end
    elseif cmd == "SHOW_OUTPUT" then
        if tonumber(iup.GetDialogChild(hMainLayout, "BottomSplit").value) < 10 and _G.dialogs['concolebar'] == nil  then iup.GetDialogChild(hMainLayout, "BottomSplit").value = "333" end
    end
end)

