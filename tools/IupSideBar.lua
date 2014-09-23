require "gui"
SideBar_obj = {}
TabBar_obj = {}
local win_parent --������� �������� ����
local tbs
local vbox
local vFuncNav
local vAbbrev
local vSys
local vFileMan

function sidebar_Switch(n)
    SideBar_obj.TabCtrl.valuepos = n -1
    if SideBar_obj.TabCtrl.value.tabs_OnSelect ~= nil --[[and props["FilePath"] ~= '']] then
        SideBar_obj.TabCtrl.value.tabs_OnSelect()
    end
end
function sidebar_Focus()
    iup.SetFocus(SideBar_obj.TabCtrl)
end
local function  CreateTab()
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
                            gap='3'
                        }
    return tolsp1
end
local function  CreateBox()

    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\Abbrev.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\Bookmark.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\FileMan.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\Functions.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\SideBar\\Navigation.lua")

    -- Creates boxes
    vFuncNav = iup.split{SideBar_obj.Tabs.functions.handle, SideBar_obj.Tabs.navigation.handle, orientation="HORIZONTAL", value=props["sidebar.funcnav.split.value"]}
    vFuncNav.tabtitle = "Func/Nav"
    SideBar_obj.Tabs.functions.id = vFuncNav.tabtitle
    SideBar_obj.Tabs.navigation.id = vFuncNav.tabtitle

    vAbbrev = iup.split{SideBar_obj.Tabs.abbreviations.handle, SideBar_obj.Tabs.bookmark.handle, orientation="HORIZONTAL", value=props["sidebar.abbrevbmk.split.value"]}

    -- Sets titles of the vboxes Navigation
    vAbbrev.tabtitle = "Abbrev/Bmk"
    SideBar_obj.Tabs.abbreviations.id = vAbbrev.tabtitle

    -- vSys = iup.vbox{SideBar_obj.Tabs.m4.handle, SideBar_obj.Tabs.mb.handle , SideBar_obj.Tabs.template.handle }
    -- vSys.tabtitle = "Sys"

    vFileMan = SideBar_obj.Tabs.fileman.handle
    vFileMan.tabtitle = "FileMan"
    SideBar_obj.Tabs.fileman.id = vFileMan.tabtitle

    -- Creates tabs
    local tabs = iup.tabs{vFuncNav, vAbbrev, vFileMan}
    tabs.map_cb = (function(_) tabs.valuepos = props["sidebar.tabctrl.value"] end)

    tabs.tabchange_cb = (function(_,new_tab, old_tab)
        --������� ������ �������� ��� � ��������� ��� � SideBar_obj
        props["sidebar.activetab"] = tabs.valuepos

        for _,tbs in pairs(SideBar_obj.Tabs) do
            if tbs["tabs_OnSelect"] then tbs.tabs_OnSelect() end
            if tbs.id == new_tab.tabtitle then
                if tbs["on_SelectMe"] then tbs.on_SelectMe() end
            end
        end
    end)

    SideBar_obj.TabCtrl = tabs

    vbox = iup.vbox{tabs}       --SideBar_obj.Tabs.livesearch.handle,
    return vbox
end

local function InitSideBar()
--SideBar_obj._DEBUG = true --�������� ����� ���������� ����������
-- ����������� ������/���������� �� ���������:
    if tonumber(props['sidebar.hide']) == 1 then return end
    -- SideBar_obj.win = false --���� ���������� true - ������ ����� �������� ��������� �����
    SideBar_obj.win = (props['sidebar.win']=='1') --���� ���������� true - ������ ����� �������� ��������� �����
    SideBar_obj.Tabs = {}
    SideBar_obj.Active = true

    local dlg
    local tEvents = {"OnClose","OnSendEditor","OnSwitchFile","OnOpen","OnSave","OnUpdateUI","OnDoubleClick","OnKey","OnDwellStart","OnNavigation","OnSideBarClouse"}
    local tDlg = {CreateBox(); title="SideBar", maxbox="NO",minbox ="NO",resize ="YES", menubox="NO", shrink='YES', minsize="100x100"}
    tDlg.show_cb=(function(h,state)
        if state == 0 then

           iup.Refresh(h)
           h.size = '1x1'
        elseif state == 4 then
            props["sidebar.funcnav.split.value"] = vFuncNav.value
            props["sidebar.abbrevbmk.split.value"] = vAbbrev.value
            props["sidebar.tabctrl.value"] = SideBar_obj.TabCtrl.valuepos
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

    if SideBar_obj.win then
        tDlg.sciteparent="SCITE"
        tDlg.sciteid="sidebar"
    else
        tDlg.sciteparent="SIDEBAR"
        tDlg.control = "YES"
        tDlg.sciteid="sidebarp"
    end
    dlg = iup.scitedialog(tDlg)

    for i = 1, #tEvents do
        for _,tbs in pairs(SideBar_obj.Tabs) do
            if tbs[tEvents[i]] then AddEventHandler(tEvents[i],tbs[tEvents[i]]) end
        end
    end


    TabBar_obj.Tabs = {}
                     --iup.hbox{iup.text{expand='YES', expand='HORIZONTAL'}}
    local tTlb = {CreateTab();expand='YES', maxbox="NO",minbox ="NO",resize ="YES", menubox="NO", shrink='YES', minsize="10x10"}
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

function FillCombo(cmb,pathmask, strSel)
    local current_path = props["sys.calcsybase.dir"]..pathmask

	local files = gui.files(current_path)
	local table_files = {}
	if files then
        local i, filename
		for i, filename in ipairs(files) do
			table_files[i] = {filename, {filename}}
		end
	end
	table.sort(table_files, function(a, b) return a[1]:lower() < b[1]:lower() end)

    local itSel = 0
	for i = 1, #table_files do
        local strIt = table_files[i][1]
        iup.SetAttribute(cmb, i, strIt)
        if strIt == strSel then cmb.value = i end
	end
end

function SideBar_ShowHide(mode)
    if mode=="hide" then
        props['sidebar.hide']=1
        props['sidebar.win']=0
        props['sidebar.pan']=0
    elseif mode=="win" then
        props['sidebar.hide']=0
        props['sidebar.win']=1
        props['sidebar.pan']=0
    else
        props['sidebar.hide']=0
        props['sidebar.win']=0
        props['sidebar.pan']=1
    end
    DestroyDialogs()
    scite.ReloadStartupScript()

end

InitSideBar()

