require 'shell'
SideBar_obj = {}
TabBar_obj = {}

local win_parent --������� �������� ����
local tbs
local vbox
local vFuncNav
local vAbbrev
local vSys
local vFileMan
local vFindRepl
local oDeatt
local hMainLayout = iup.GetLayout()
local BottomBar, ConsoleBar, FindRepl

iup.SetGlobal("DEFAULTFONTSIZE", Iif(props['iup.defaultfontsize']=='', "10", props['iup.defaultfontsize']))
iup.SetGlobal("TXTHLCOLOR", "200 200 200")
                               -- RGB(121, 161, 201)
iup.PassFocus=(function()
    iup.SetFocus(iup.GetDialogChild(hMainLayout, "Source"))
end)

function sidebar_Switch(n)
    SideBar_obj.TabCtrl.valuepos = n -1
    local v
    for _,tbs in pairs(SideBar_obj.Tabs) do
        if tbs.tabs_OnSelect and SideBar_obj.TabCtrl.value_handle.tabtitle == tbs.id then tbs.tabs_OnSelect() end
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
                table.insert(sb_elements, SideBar_obj.Tabs[t[i]])
                t[i] = SideBar_obj.Tabs[t[i]].handle
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
        elseif t.type == "EXPANDER" then
            t.barsize = '0'
            l = iup.expander(t)
        elseif t.type == "SCROLLBOX" then
            t.expand="HORIZONTAL"
            t.scrollbar='NO'
            t.minsize='x250'
            l = iup.scrollbox(t)--iup.expander{, barsize='0', barposition="LEFT",minsize="0x0"}
        elseif t.type == nil then
            l = t[1]
        else print('Unsupported type:'..t.type) end
        l.tabtitle = t.tabtitle
        return l
    end
    local function SideBar(t)
        t.name="tabMain"
        t.tip= 'Ctrl+1,2,3,4'
        t.map_cb = (function(h)
            h.size="1x1"
        end)
        return iup.tabs(t)
    end
    tbArg = function()
        return {
            Pane{'functions', Pane{Pane{'findrepl', type="SCROLLBOX"}, type='EXPANDER', name="FinReplExp"}, tabtitle = "Func/Find", type='VBOX'},
            Pane{'abbreviations', Pane{'bookmark','navigation', orientation="HORIZONTAL", name="splitFuncNav",  type='SPLIT'}, orientation="HORIZONTAL", name="splitAbbrev", tabtitle = "Abbrev/Bmk/Nav", type="SPLIT"},
            Pane{'fileman', tabtitle = "FileMan"},
            Pane{'atrium', tabtitle = "Atrium", type= "VBOX"},
        }
    end
    local plugin = props["SciteDefaultHome"].."\\data\\home\\SideBarLayout.lua"
    if shell.fileexists(plugin) then dofile(plugin) end

    local tabs =  SideBar(tbArg())
    tbArg = nil
    tabs.tabchange_cb = (function(_,new_tab, old_tab)
        --������� ������ �������� ��� � ��������� ��� � SideBar_obj

        for _,tbs in pairs(SideBar_obj.Tabs) do
            if tbs["tabs_OnSelect"] then tbs.tabs_OnSelect() end
            if tbs.id == new_tab.tabtitle then
                if tbs["on_SelectMe"] then tbs.on_SelectMe() end
            end
        end
    end)
    tabs.k_any= (function(h,c) if c == iup.K_ESC then iup.PassFocus() end end)

    tabs.rightclick_cb=(function()
        if _G.iuprops['sidebar.win'] == '0' then
            local mnu = iup.menu
            {
              iup.item{title="Deattach Sidebar",action=(function()
                  oDeatt.DetachRestore = true;
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
    tbArg = nil

    vbox = iup.vbox{tabs}       --SideBar_obj.Tabs.livesearch.handle,
    oDeatt = iup.scitedetachbox{
        vbox; orientation="HORIZONTAL";barsize=5;minsize="100x100";name='SideBarSB'; shrink="yes";
        sciteid = 'sidebar';Split_h = iup.GetDialogChild(hMainLayout, "SourceSplit");Split_CloseVal = "1000";
        Dlg_Title = "SideBar /Close For Attach/"; Dlg_Show_Cb = nil;
        Dlg_Close_Cb = (function(h)
            if _G.iuprops['findrepl.win']=='1' then
                _G.FindReplDialog.close_cb(_G.FindReplDialog)
            end
        end);
    }
    return oDeatt
end
local tEvents = {"OnClose","OnSendEditor","OnSwitchFile","OnOpen","OnSave","OnUpdateUI","OnDoubleClick","OnKey","OnDwellStart","OnNavigation","OnSideBarClouse", "OnMenuCommand", "OnCreate"}

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
                        table.insert(hist,iup.GetAttributeId(child, '', i))
                    end
                    _G.iuprops[root..'.'..child.name..'.hist'] = table.concat(hist,'�')
                elseif cType == 'zbox' or cType == 'tabs' then
                    val = child.valuepos
                elseif cType == 'matrixlist' then
                    val = child.focusitem
                elseif cType == 'sbox' then
                    val = child.size
                end
                _G.iuprops[root..'.'..child.name..'.value'] = val
            end
            SaveNamedValues(child, root)
        end
    until not child
end

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
                        for w in s:gmatch('([^�]+)') do
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
    --hMainLayout = iup.GetLayout()
--SideBar_obj._DEBUG = true --�������� ����� ���������� ����������
-- ����������� ������/���������� �� ���������:
    if tonumber(props['sidebar.hide']) == 1 then return end
    -- SideBar_obj.win = false --���� ���������� true - ������ ����� �������� ��������� �����
    SideBar_obj.win = (_G.iuprops['sidebar.win']=='1') --���� ���������� true - ������ ����� �������� ��������� �����
    SideBar_obj.Tabs = {}
    SideBar_obj.Active = true

    local dlg
    --if true then return end
    local tDlg = CreateBox();
    --local tDlg = {CreateBox(); title="SideBar", maxbox="NO",minbox ="NO",resize ="YES", menubox="NO", shrink='YES', minsize="100x100"}
    tDlg.show_cb=(function(h,state)
        if state == 0 then
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

    tDlg.SaveValues = (function()
        for _,tbs in pairs(SideBar_obj.Tabs) do
            if tbs.OnSaveValues then tbs.OnSaveValues() end
        end
        SaveNamedValues(hMainLayout,'sidebarctrl')
    end)

    SideBar_obj.handle = tDlg
    local rightBarPH = iup.GetDialogChild(hMainLayout, "RightBarPH")
    iup.Append(rightBarPH,tDlg)
    iup.Map(tDlg)

    RestoreNamedValues(hMainLayout, 'sidebarctrl')

    for i = 1, #tEvents do
        for _,tbs in pairs(SideBar_obj.Tabs) do
            if tbs[tEvents[i]] then AddEventHandler(tEvents[i],tbs[tEvents[i]]) end
        end
    end
    SideBar_obj.OnCreate()

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
iup.Refresh(hMainLayout)

AddEventHandler("OnSendEditor", function(id_msg, wp, lp)
    if id_msg == SCN_NOTYFY_ONPOST then
        if wp == 3 then  --����� ��������� ����� ����������� ����� ����, ����� ����� ������ ����������
            props['session.reload'] = _G.iuprops['session.reload']
            if _G.iuprops['buffers'] ~= nil and _G.iuprops['session.reload'] == '1' then
                local bNew = (props['FileName'] ~= '')
                local t,p,bk = {},{},{}
                for f in _G.iuprops['buffers']:gmatch('[^�]+') do
                    table.insert(t, f)
                end
                local bki
                if _G.iuprops['buffers.pos'] then
                    for f in _G.iuprops['buffers.pos']:gmatch('[^�]+') do
                        local i = 0
                        for g in f:gmatch('[^�]+') do
                            if i==0 then
                                table.insert(p, g)
                                bki = {}
                                table.insert(bk, bki)
                            else table.insert(bki, g) end
                            i = 1
                        end
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
                end
                if bNew then
                    scite.buffers.SetDocumentAt(0)
                else
                    local b = tonumber(_G.iuprops['buffers.current'] or -1)
                    if b >= 0 then scite.buffers.SetDocumentAt(b) end
                end
            end
            SideBar_obj.blockUpdate = false
            if SideBar_obj.win then oDeatt.DetachRestore = true; oDeatt.detach = 1 end
            if _G.iuprops['bottombar.win']=='1' then BottomBar.DetachRestore = true;BottomBar.detach = 1 end
            if _G.iuprops['concolebar.win']=='1' then ConsoleBar.DetachRestore = true;ConsoleBar.detach = 1 end
            if _G.iuprops['findrepl.win']=='1' then FindRepl.DetachRestore = true;FindRepl.detach = 1 end
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

