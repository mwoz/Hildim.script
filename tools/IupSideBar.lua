if not shell then shell = require"shell" end
SideBar_obj = {}
LeftBar_obj = {}
SideBar_Plugins = {}
local ToolBar_obj = {}
local Splitter_CB

local win_parent --������� �������� ����
local tbs
local vbox

local hMainLayout = iup.GetLayout()
local ConsoleBar, FindRepl, FindResBar, CoEditor
local pane_curObj
local tEvents = {"OnClose","OnSendEditor","OnSwitchFile","OnOpen","OnSave","OnUpdateUI","OnDoubleClick","OnKey","OnDwellStart","OnNavigation","OnSideBarClouse", "OnMenuCommand", "OnCreate"}

local fntSize = "10"
if props['iup.defaultfontsize']~='' then if tonumber(props['iup.defaultfontsize']) > 4 then fntSize = props['iup.defaultfontsize'] end end
iup.SetGlobal("DEFAULTFONTSIZE", fntSize)
iup.SetGlobal("TXTHLCOLOR", "222 222 222")
local leftsplit, rightsplit
local vbScite = iup.GetDialogChild(hMainLayout, "SciteVB")
local bottomsplit = iup.GetDialogChild(hMainLayout, "BottomBarSplit")
local scipPannCounter = 0;

CORE.curTopSplitter = ''

function CORE.HidePannels()
    if scipPannCounter > 0 then
        scipPannCounter = scipPannCounter - 1
        return
    end
    if rightsplit and rightsplit.popupside ~= '0' and rightsplit.hidden == 'NO' then rightsplit.hidden = 'YES' end

    if leftsplit and leftsplit.popupside ~= '0' and leftsplit.hidden == 'NO' then leftsplit.hidden = 'YES' end

    if bottomsplit.popupside ~= '0' and bottomsplit.hidden == 'NO' then CORE.BottomBarSwitch('YES')end
end

function CORE.ScipHidePannel(i)
    if bottomsplit.popupside ~= '0' then
        scipPannCounter = (i or 1)
    end
end

function CORE.BottomBarHidden()
    return (bottomsplit.popupside ~= '0' and bottomsplit.hidden == 'YES')
end

iup.PassFocus =(function()
    if iup.GetGlobal("SHIFTKEY") == 'ON' then return end
    if scite.buffers.GetCurrent() >= 0 then
        editor:GrabFocus()
    else
        iup.SetFocus(iup.GetDialogChild(hMainLayout, "Source"))
    end
    CORE.HidePannels()
end)

function sidebar_Switch(n)
    if LeftBar_obj.handle then
        leftCount = tonumber(LeftBar_obj.TabCtrl.count)
        if n <= leftCount then
            if LeftBar_obj.handle.Dialog then LeftBar_obj.handle.ShowDialog() end
            LeftBar_obj.TabCtrl.valuepos = n -1
            for _,tbs in pairs(SideBar_Plugins) do
                if tbs.tabs_OnSelchange then tbs.tabs_OnSelchange{} end
                if tbs.tabs_OnSelect and LeftBar_obj.TabCtrl.value_handle.tabtitle == tbs.id then
                    LeftBar_obj.TabCtrl:getfocus_cb()
                    tbs.tabs_OnSelect()
                end
            end
        end
        n = n - leftCount
    end
    if SideBar_obj.handle and n > 0 then
        if SideBar_obj.handle.Dialog then SideBar_obj.handle.ShowDialog() end
        SideBar_obj.TabCtrl.valuepos = n -1
        for _, tbs in pairs(SideBar_Plugins) do
            if tbs.tabs_OnSelchange then tbs.tabs_OnSelchange{} end
            if tbs.tabs_OnSelect and SideBar_obj.TabCtrl.value_handle.tabtitle == tbs.id then
                SideBar_obj.TabCtrl:getfocus_cb()
                tbs.tabs_OnSelect()
            end
        end
    end
end

local function CreateToolBar()

    local v = iup.GetDialogChild(hMainLayout, "OverEditorExpander")
    local s = iup.GetParent(v)
    iup.SetAttribute(s, "HISTORIZED", "NO")
    s.valuechanged_cb = function(h) _G.iuprops["contrpls.OverEditorExpander.val"] = h.value end
    local p = iup.GetChild(v , 1)
    if p then
        iup.Detach(p)
        iup.Destroy(p)
    end
    v.state = "CLOSE"
    s.barsize = 0
    s.value = 0


    local str = _G.iuprops["settings.toolbars.layout"] or ''
    local tblVb = {gap = "1", name="ToolBar"}
    local tblHb
    --local i = 0
    local isUpper = false
    local tblBars = _G.iuprops["settings.toolbars.layout"] or {}
    local ii = 0;
    for i = 1, #tblBars do
        if #(tblBars[i]) > 0 then
            ii = ii + 1
            if ii > 1 then
                table.insert(tblVb, iup.hbox(tblHb))
                --if i > 2 or not isUpper then table.insert(tblVb, iup.label{separator = "HORIZONTAL"}) end
            end
            tblHb = {gap = "3", margin = "3x1", alignment = "ACENTER"}
            for j = 1, #(tblBars[i]) do
                local pname = tblBars[i][j]
                local bSucs, pI = pcall(dolocale, "tools\\UIPlugins\\"..pname)
                if not bSucs then
                    print(pI)
                    goto continue
                end

                if pI.destroy then table.insert(CORE.onDestroy_event, pI.destroy) end

                local bSucs, res = pcall(pI.toolbar, ToolBar_obj)
                if not bSucs then
                    print(res)
                    goto continue
                end
                ToolBar_obj.Tabs[pI.code] = res
                local id = pI.code
                if pI.hlpdevice then id = pI.hlpdevice..'::'..id end
                iup.SetAttribute(ToolBar_obj.Tabs[pI.code].handle, "HELPID", id)

                if i == 1 and pI.overeditors then
                    local v = iup.GetDialogChild(hMainLayout, "OverEditorExpander")

                    v.ShowPlugin = function(b)
                        local s = iup.GetParent(v)
                        if b then
                            v.state = "OPEN"
                            s.barsize = 5
                            s.value = _G.iuprops["contrpls.OverEditorExpander.val"] or 500
                        else
                            v.state = "CLOSE"
                            s.barsize = 0
                            s.value = 0
                        end
                    end
                    local hb = iup.hbox{ ToolBar_obj.Tabs[pI.code].handle, name = "hb", }

                    local hTmp = iup.dialog{hb}
                    local p = iup.GetChild(iup.GetDialogChild(hTmp, 'hb'),0)
                    iup.Detach(p)
                    iup.Destroy(hTmp)
                    iup.Insert(v, nil, p)
                    iup.Map(p)
                    isUpper = true

                else
                    table.insert(tblHb, ToolBar_obj.Tabs[pI.code].handle)
                end
::continue::
            end
        end
    end
    table.insert(tblVb, iup.hbox(tblHb or {gap = "3", margin = "3x0", alignment = "ACENTER"}))

    return iup.expander{barsize = 0, state = "OPEN", name = "toolbar_expander", iup.vbox(tblVb)}
end

local StatusBar_obj = {}
local function CreateStatusBar()
    local tbl = _G.iuprops["settings.status.layout"] or {}
    local tblH = {gap="3",margin="3x2", name="StatusBar", maxsize="x32", alignment = "ACENTER",}
    for i = 1, #tbl do
        local p = tbl[i]
        local bSucs, pI = pcall(dolocale, "tools\\UIPlugins\\"..p)
        if not bSucs then
            print(pI)
            goto continue
        end
        if pI.destroy then table.insert(CORE.onDestroy_event, pI.destroy) end

        local bSucs, res = pcall(pI.statusbar, StatusBar_obj)
        if not bSucs then
            print(res)
            goto continue
        end
        StatusBar_obj.Tabs[pI.code] = res

        local id = pI.code
        if pI.hlpdevice then id = pI.hlpdevice..'::'..id end
        iup.SetAttribute(StatusBar_obj.Tabs[pI.code].handle, "HELPID", id)
        table.insert(tblH, StatusBar_obj.Tabs[pI.code].handle)
        ::continue::
    end
    table.insert(tblH, iup.label{expand = 'HORIZONTAL', button_cb=function(_, but, pressed, x, y, status)
        if but == iup.BUTTON1 and pressed == 1 then
            CORE.BottomBarSwitch(Iif(iup.GetDialogChild(iup.GetLayout(), "BottomBarSplit").hidden == "YES", 'NO', "YES"))
        end
    end})
    -- table.insert(tblH, iup.fill{})
    if _tmpSidebarButtons then
        for i = 1,  #_tmpSidebarButtons do
            table.insert(tblH, _tmpSidebarButtons[i])
        end
    end
    iup.SetAttribute(bottomsplit, 'IUPUNDER', 'status_background')
    return iup.expander{barsize = 0, state = "OPEN", name = "statusbar_expander", iup.backgroundbox{iup.hbox(tblH), name = 'status_background'}}
end

function iup.SaveNamedValues(h, root)
    if not h then return end
    local child = nil
    repeat
        child = iup.GetNextChild(h, child)
        if child then
            if (child.value or child.valuepos or child.focusitem or child.size or child.state) and child.name and (iup.GetAttribute(child, 'HISTORIZED') ~= 'NO') then
                local _,_,cType = tostring(child):find('IUP%((%w+)')
                local val = child.value
                if cType == 'list' and (child.dropdown == "YES" or iup.GetAttribute(child, 'HISTORIZED') == 'YES') then
                    local hist = {}
                    for i = 1, child.count do
                        if i > tonumber(child.visibleitems  or 15) then break end
                        table.insert(hist,iup.GetAttributeId(child, '', i))
                    end
                    _G.iuprops[root..'.'..child.name..'.hist'] = hist
                elseif cType == 'list' and vai == '0' then
                    goto continue
                elseif cType == 'zbox' or cType == 'tabs' or cType == 'flattabs' then
                    val = child.valuepos
                elseif cType == 'matrixlist' then
                    val = child.focusitem
                elseif cType == 'sbox' then
                    val = child.size
                elseif cType == 'split' then
                    if "0" == child.barsize then val = nil end
                elseif cType == 'expander' and iup.GetAttribute(child, 'HISTORIZED') == 'YES' then
                    val = child.state
                end
                if val then _G.iuprops[root..'.'..child.name..'.value'] = val end
            end
::continue::
            iup.SaveNamedValues(child, iup.GetAttribute(child, 'SAVEPREFIX') or root)
        end
    until not child
end

local function CreateBox()
    -- Creates boxes
    local sb_elements = {}
    local tbl_hotkeys = {}
    local strTip = _TH'Hotkeys for Tab Activation:'
    local function Pane(t)
        for i = 1, #t do
            if type(t[i]) == 'string' then
                table.insert(sb_elements, SideBar_Plugins[t[i]])
                SideBar_Plugins[t[i]].Bar_obj = pane_curObj
                t[i] = SideBar_Plugins[t[i]].handle
            end
        end
        if t.tabtitle then
            for i = 1, #sb_elements do sb_elements[i].id = t.tabtitle end
            sb_elements = {}
        end
        local b, l
        if t.type == "VBOX" then
            l = iup.vbox(t)
        elseif t.type == "SPLIT" then
            t.color = props['layout.splittercolor']
            t.showgrip = 'LINES'
            l = iup.split(t)
        elseif t.type == "FIND" then
            SideBar_Plugins.findrepl.Bar_obj = pane_curObj
            table.insert(sb_elements, SideBar_Plugins.findrepl)
            l = iup.backgroundbox{iup.expander{iup.scrollbox{SideBar_Plugins.findrepl.handle, name = 'FinReplScroll', expand = "HORIZONTAL", scrollbar = 'NO', size = '0x118'}, barsize = '0', name = "FinReplExp"}}
        elseif t.type == nil then
            l = t[1]
        else print('Unsupported type:'..t.type) end
        l.tabtitle = t.tabtitle
        if t.tabhotkey then
            table.insert(tbl_hotkeys, t.tabhotkey or '')
            strTip = strTip..'\n'..t.tabtitle..' - < '..t.tabhotkey..' > '
        end
        return l
    end

    local hk_pointer
    local function SideBar(t, Bar_Obj, sciteid, splitter)
        if not t then return end
        t.name = 'sidebartab_'..sciteid
        Bar_Obj.sciteid = sciteid
        Bar_Obj.splitter = splitter
        local brObj = Bar_Obj
        t.map_cb = (function(h)
            h.size = "1x1"
        end)
        t.tabchange_cb = (function(h, new_tab, old_tab)
            --������� ������ �������� ��� � ��������� ��� � SideBar_ob
            --h.ONMOVE = true
            for _, tbs in pairs(SideBar_Plugins) do
                if tbs.tabs_OnSelchange then tbs.tabs_OnSelchange{} end
                if tbs.id == new_tab.tabtitle then
                    if tbs["tabs_OnSelect"] then tbs.tabs_OnSelect() end
                end
            end
        end)
        t.k_any = (function(h, c) if c == iup.K_ESC then iup.PassFocus() end end)
        t.extrabuttons = 1
        t.extraimage1 = "property_�"
        t.extrapresscolor1 = props["layout.splittercolor"]
        t.extrabutton_cb = function(h, button, state) if state == 1 then menuhandler:PopUp('MainWindowMenu|View|'..sciteid) end end

        hk_pointer =  #tbl_hotkeys + 1
        t.tip = strTip
        t.tabspadding = '10x3'
        t.forecolor = props['layout.fgcolor']
        t.highcolor = props['layout.txthlcolor']
        t.showlines = 'NO'
        t.forecolor = iup.GetLayout().fgcolor
        t.tabsforecolor = props['layout.fgcolor']
        t.bgcolor = iup.GetLayout().bgcolor
        t.tabsbackcolor = props["layout.splittercolor"]
        t.getfocus_cb = function(h)
            local s = iup.GetDialogChild(hMainLayout, splitter)
            if s.popupside ~= "0" then
                s.hidden = 'NO'; CORE.curTopSplitter = sciteid
            else
                CORE.HidePannels()
            end
        end

        return iup.flattabs(t)
    end

    local function SidePane(hVbox, sName, sSciteId, sSplit, sExpander, sSplit_CloseVal, Bar_obj, sSide, buttonImage)
        local tmr_Resize = iup.timer{time = 100; run = 'NO';action_cb = function(h)
            if shell.async_mouse_state() >= 0 then
                h.run = 'NO'
                OnResizeSideBar(sSciteId)
            end
        end}
        local spl_h = iup.GetDialogChild(hMainLayout, sSplit)

        spl_h.valuechanged_cb = function(h) if OnResizeSideBar and tmr_Resize.run == 'NO' then tmr_Resize.run = 'YES' end end;
        local h = iup.scitedetachbox{
            hVbox; orientation = "HORIZONTAL";barsize = 5;--[[minsize = "1x100";]]name = sName; shrink = "yes"; buttonImage = buttonImage;
            sciteid = sSciteId;Split_h = spl_h;Split_CloseVal = sSplit_CloseVal;
            Dlg_Title = _TH(sSide.." Side Bar"); Dlg_Show_Cb = nil;
            On_Detach = (function(h, hNew, x, y)
                iup.GetDialogChild(iup.GetLayout(), sExpander).state = "CLOSE";
                scite.RunAsync(Splitter_CB)
            end);
            Dlg_Close_Cb = (function(h)
                iup.GetDialogChild(iup.GetLayout(), sExpander).state = "OPEN";
                local tmr = iup.timer{time = 300, run = 'NO', action_cb = function(h)
                   h.run = 'NO'
                   Splitter_CB()
                end}
                tmr.run = 'YES'
            end);
            Dlg_Show_Cb =(function(h, state)
                if state == 4 then
                    for _, tbs in pairs(SideBar_Plugins) do
                        if tbs["OnSideBarClouse"] then tbs.OnSideBarClouse() end
                    end
                end
            end);
            focus_cb = function(h, f)
                if CORE.curTopSplitter ~= sSciteId and spl_h.popupside ~= "0" then
                    spl_h.hidden = 'NO'; CORE.curTopSplitter = sSciteId
                elseif spl_h.popupside == "0" then
                    CORE.HidePannels()
                end
            end;
            k_any =(function(_, key)
                if key == iup.K_ESC then iup.PassFocus() end
            end);
        }
        h.SaveValues = (function()
            for _, tbs in pairs(SideBar_Plugins) do
                if tbs.OnSaveValues then tbs.OnSaveValues() end
            end
            iup.SaveNamedValues(hMainLayout, 'sidebarctrl')
            iup.SaveNamedValues(hVbox, 'sidebarctrl')
        end)
        h.OnMyDestroy = function() spl_h.valuechanged_cb = nil end

        return h
    end

    local function settings2tbl(tSide, side)
        local defpath = "tools\\UIPlugins\\"
        local function piCode(pI)
            if pI.code == 'findrepl' then
                return Pane{type = "FIND"}
            else
                return pI.code
            end
            return pI.code
        end
        if #tSide == 0 then
            return nil
        end

        local tCur

        local tArg = {}
        --debug_prnArgs{tSide}
        for i = 1, #tSide do
            tCur = tSide[i]
            if tCur[1] then
                local bSucs, pI = pcall(dolocale, defpath..tCur[1])
                if not bSucs then
                    print(pI)
                    goto continue
                end
                if pI.destroy then table.insert(CORE.onDestroy_event, pI.destroy) end

                local bSucs, res = pcall(pI.sidebar, SideBar_Plugins)
                if not bSucs then
                    print(res)
                    goto continue
                end
                SideBar_Plugins[pI.code] = res

                local id = pI.code
                if pI.hlpdevice then id = pI.hlpdevice..'::'..id end
                iup.SetAttribute(SideBar_Plugins[pI.code].handle, "HELPID", id)
                local tabName = tCur.title
                local tabhotkey = pI.tabhotkey
                if #tCur == 1 then
                    table.insert(tArg, Pane{pI.code, tabtitle = tabName, tabhotkey = (tabhotkey or '')})
                else
                    local bfixedheigth = pI.fixedheigth
                    local tSub = piCode(pI)
                    for j = 2, #tCur do
                        tSub = {tSub}
                        bSucs, pI = pcall(dolocale, defpath..tCur[j])
                        if not bSucs then
                            print(pI)
                            goto continue
                        end
                        if pI.destroy then table.insert(CORE.onDestroy_event, pI.destroy) end

                        local bSucs, res = pcall(pI.sidebar, SideBar_Plugins)
                        if not bSucs then
                            print(res)
                            goto continue
                        end
                        SideBar_Plugins[pI.code] = res

                        local id = pI.code
                        if pI.hlpdevice then id = pI.hlpdevice..'::'..id end
                        if not tabhotkey and pI.tabhotkey then tabhotkey = pI.tabhotkey end
                        iup.SetAttribute(SideBar_Plugins[pI.code].handle, "HELPID", id)

                        table.insert(tSub, piCode(pI))
                        if bfixedheigth or pI.fixedheigth then

                            tSub.type = "VBOX"
                        else

                            tSub.name = 'split'..pI.code
                            tSub.type = "SPLIT"
                            tSub.orientation = "HORIZONTAL"
                        end
                        bfixedheigth = pI.fixedheigth and bfixedheigth
                        if j == #tCur then

                            tSub.tabtitle = tabName
                            tSub.tabhotkey = (tabhotkey or '')
                        end

                        tSub = Pane(tSub)
                    end

                    table.insert(tArg, tSub)
                    -- table.insert(tArg, iup.scrollbox{tSub, scrollbar = 'NO', expand = "YES"})

                end
                ::continue::
            end
        end
        --debug_prnArgs(tArg)
        return tArg
    end
    hk_pointer = 1
    pane_curObj = LeftBar_obj
    local tbArgLeft = settings2tbl(_G.iuprops["settings.user.leftbar"] or {}, "tbArgLeft")
    pane_curObj = SideBar_obj
    local tbArgRight = settings2tbl(_G.iuprops["settings.user.rightbar"] or {}, "tbArgRight")

    local tabs = SideBar(tbArgLeft, LeftBar_obj, 'leftbar', 'SourceSplitLeft')

    if tabs then
        LeftBar_obj.TabCtrl = tabs

        vbox = iup.vbox{tabs}       --SideBar_Plugins.livesearch.handle,
        LeftBar_obj.handle = SidePane(vbox, 'LeftBarSB','leftbar','SourceSplitLeft', 'LeftBarExpander', '0', LeftBar_obj, 'Left', 'application_sidebar_left_�' )
        leftsplit = iup.GetDialogChild(hMainLayout, 'SourceSplitLeft')
    end

    local tabs = SideBar(tbArgRight, SideBar_obj, 'sidebar', 'SourceSplitRight')

    if tabs then
        SideBar_obj.TabCtrl = tabs

        vbox = iup.vbox{tabs}
        SideBar_obj.handle = SidePane(vbox, 'SideBarSB','sidebar','SourceSplitRight', 'RightBarExpander', '1000', SideBar_obj, 'Right', 'application_sidebar_right_�' )
        rightsplit = iup.GetDialogChild(hMainLayout, 'SourceSplitRight')
    end

    local tblMenus = {}
    for i = 1,  #tbl_hotkeys do
        local t = {}
        table.insert(t, 'Tab'..i)
        if tbl_hotkeys[i] ~= '' then t.key = tbl_hotkeys[i] end
        t.action = function() sidebar_Switch(i) end
        table.insert(tblMenus, t)
    end

    AddEventHandler("OnChangeFocus", function(src, focus)
        if focus == 1   and (src == IDM_COSRCWIN or src == IDM_SRCWIN) then
            scite.RunAsync(function()
                CORE.HidePannels();
                CORE.curTopSplitter = ''
            end)
        end
    end)

    AddEventHandler("OnUpdateUI", function(bModified, bSelection, flag, bSwitch)
        if (bSelection == 1 or bModified == 1) and bSwitch == 0 then CORE.HidePannels(); CORE.curTopSplitter = '' end
    end)
    AddEventHandler("PaneOnUpdateUI", function(bModified, bSelection, flag, bSwitch)
        if (output.Focus and (_G.iuprops['concolebar.win'] or '0') == '1') or (findres.Focus and (_G.iuprops['findresbar.win'] or '0') == '1') then return end
        if (bSelection == 1 ) then
            local s = iup.GetDialogChild(hMainLayout, "BottomBarSplit")
            if CORE.curTopSplitter ~= "BottomBar" and s.popupside ~= 0 then  s.hidden = 'NO'; CORE.curTopSplitter = "BottomBar" end
        end
    end)

    menuhandler:InsertItem('MainWindowMenu', '_HIDDEN_|xxx', {'Sidebar', tblMenus})

end

local function RestoreNamedValues(h, root)
    if not h then return end
    local child = nil
    repeat
        child = iup.GetNextChild(h, child)
        if child then
            if child.name and (iup.GetAttribute(child, 'HISTORIZED') ~= 'NO') then
                local _,_,cType = tostring(child):find('IUP%((%w+)')
                local val = _G.iuprops[root..'.'..child.name..'.value']
                if cType == 'list' and child.dropdown == "YES" and (child.editbox == "YES" or iup.GetAttribute(child, 'HISTORIZED') == 'YES') then
                    local s = _G.iuprops[root..'.'..child.name..'.hist']
                    if s then
                        for i = 1, #s do
                            if i == 1 and child.editbox == "YES" then val = s[i] end
                            if i > tonumber(child.visibleitems  or 15) then break end
                            iup.SetAttributeId(child, 'INSERTITEM', i, s[i])
                        end
                    end
                    if val then child.value = val end
                elseif cType == 'zbox' or cType == 'tabs' or cType == 'flattabs' then
                    if val then child.valuepos = val end
                elseif cType == 'matrixlist' then
                    if val then
                        child.focusitem = val
                        child["show"] = val..":*"
                        child.redraw = 1
                    end
                elseif cType == 'expander' and val and child.historized == 'YES' then
                    if val then child.state = val end

                elseif val then
                    if cType == 'split' and child.barsize == '0' and child.value ~= '0' and child.value ~= '1000' then child.barsize = '5' end
                    child.value = val
                end
            end
            RestoreNamedValues(child, root)
        end
    until not child
end

local function InitSideBar()
    if tonumber(props['sidebar.hide']) == 1 then return end
    -- SideBar_obj.win = false --���� ���������� true - ������ ����� �������� ��������� �����
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
        SideBar_Plugins.findrepl = dolocale("tools\\UIPlugins\\FindRepl.lua").sidebar(SideBar_Plugins)
        local hTmp= iup.dialog{SideBar_Plugins.findrepl.handle}
        local hBx = iup.GetDialogChild(hTmp, 'FindReplDetach')
        iup.Detach(hBx)
        iup.Insert(iup.GetDialogChild(hMainLayout, "FindPlaceHolder"), nil, hBx)
        iup.Map(hBx)
        iup.Destroy(hTmp)
        bs2.barsize='5'
        if tonumber(bs2.value) > 980 then bs2.value = 800 end
        iup.GetDialogChild(hMainLayout, "FindPlaceHolder").yautohide = 'NO'
        iup.RefreshChildren(iup.GetDialogChild(hMainLayout, "FindPlaceHolder"))
        iup.SetAttribute(hBx, "HELPID", 'findrepl')
    else
        bs2.barsize="0"
        bs2.value = 1000
        bFindInSide = true
    end

    for i = 1, #tEvents do
        for _,tbs in pairs(SideBar_Plugins) do
            if tbs[tEvents[i]] then AddEventHandler(tEvents[i],tbs[tEvents[i]]) end
        end
    end

    local bSplitter = iup.GetDialogChild(hMainLayout, "BottomSplit")

    local function toggleOf()
        if iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize == '5' then
           iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize = '0'
           iup.GetDialogChild(hMainLayout, "BottomExpander").state = 'CLOSE'
           _G.iuprops["sidebarctrl.BottomBarSplit.value"] = iup.GetDialogChild(hMainLayout, "BottomBarSplit").value
            iup.GetDialogChild(hMainLayout, "BottomBarSplit").value = '1000'
        end
    end
    local function toggleOn()
        if iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize == '0' then
           iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize = '5'
           iup.GetDialogChild(hMainLayout, "BottomExpander").state = 'OPEN'
           iup.GetDialogChild(hMainLayout, "BottomBarSplit").value = _G.iuprops["sidebarctrl.BottomBarSplit.value"] or '900'
        end
    end

    ConsoleBar = iup.scitedetachbox{
        HANDLE = iup.GetDialogChild(hMainLayout, "ConsoleDetach"); buttonImage = 'terminal_�';
        sciteid = 'concolebar';Split_h = bSplitter;Split_CloseVal = "0";
        Dlg_Title = _TH"Output"; Dlg_Show_Cb = nil; MenuEx = "OUTPUT";
        Dlg_Close_Cb = (function(h)
        end);
        Dlg_Show_Cb = (function(h, state)
            if state == 0 and (_G.iuprops['findresbar.win'] or '0')~= '0' then
                if (_G.iuprops['findrepl.win'] or '0') == '0' and not SideBar_Plugins.findrepl.Bar_obj then
                    SideBar_Plugins.findrepl.handle_deattach.detachPos(false)
                    _G.iuprops['findrepl.visible.state'] = "0"
                end
                _G.iuprops['dialogs.concolebar.splitvalue'] = _G.iuprops['dialogs.findresbar.splitvalue']
                toggleOf()
            end
        end);
        Dlg_BeforeAttach = (function()
            if _G.iuprops['findresbar.win']~= '0' then
                toggleOn()
                _G.iuprops['dialogs.concolebar.splitvalue'] = '1000'
            end
        end);
    }

    FindResBar = iup.scitedetachbox{
        HANDLE = iup.GetDialogChild(hMainLayout, "FindResDetach"); buttonImage='binocular__pencil_�';
        sciteid = 'findresbar';Split_h = bSplitter;Split_CloseVal = "1000";
        Dlg_Title = _TH"Find Results"; Dlg_Show_Cb = nil; MenuEx = "FINDRES";
        Dlg_Close_Cb = (function(h)
        end);
        Dlg_Show_Cb = (function(h, state)
            if state == 0 and (_G.iuprops['concolebar.win'] or '0')~='0' then
                if (_G.iuprops['findrepl.win'] or '0')=='0' and not SideBar_Plugins.findrepl.Bar_obj then
                    SideBar_Plugins.findrepl.handle_deattach.detachPos(false)
                    _G.iuprops['findrepl.visible.state'] = "0"
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

    bSplitter.valuechanged_cb = function(h)
        if h.value == '0' then
            ConsoleBar.cmdHide()
        elseif h.value == '1000' then
            FindResBar.cmdHide()
        end
    end

    bSplitter = function() return iup.GetDialogChild(hMainLayout, Iif((_G.iuprops['dialogs.coeditor.splithorizontal'] or 0) == 1, 'SourceSplitBtm', 'SourceSplitMiddle')) end

    CoEditor = iup.scitedetachbox{
        HANDLE = iup.GetDialogChild(hMainLayout, "SourceExDetach"); buttonImage='edit_�';
        sciteid = 'coeditor';Split_h = bSplitter;Split_CloseVal = "1000";
        Dlg_Title = _TH"Additional View"; Dlg_Show_Cb = nil; MenuEx = 'EDITOR';
        Dlg_Close_Cb = (function(h)
            if tonumber(_G.iuprops['dialogs.coeditor.splitvalue']) > 980 then _G.iuprops['dialogs.coeditor.splitvalue'] = 900
            elseif tonumber(_G.iuprops['dialogs.coeditor.splitvalue']) < 20 then _G.iuprops['dialogs.coeditor.splitvalue'] = 100 end
        end);
        Dlg_Show_Cb = (function(h, state)
            if state == 0 then CORE.RemapTab(false); iup.Refresh(h) -- ��������� ������ ��� ������� ������
            elseif state == 4 then scite.RunAsync(Splitter_CB) end
        end);
        Dlg_BeforeAttach = (function(h, state)
            if (_G.iuprops['dialogs.coeditor.splithorizontal'] or 0) == 0 then CORE.RemapTab(true) end
        end);
        MenuVisible = (function() return scite.buffers.SecondEditorActive() == 1 end);
        MenuVisibleEx = (function() return scite.buffers.SecondEditorActive() == 1 and scite.ActiveEditor() == 1 end);
    }
    _G.g_session['coeditor'] = CoEditor

end

local tabSwitch = false
local function InitTabbar()
    local SSL = iup.GetDialogChild(hMainLayout, 'SourceSplitLeft')
    local SSR = iup.GetDialogChild(hMainLayout, 'SourceSplitRight')
    local SSM = iup.GetDialogChild(hMainLayout, 'SourceSplitMiddle')
    local TBS = iup.GetDialogChild(hMainLayout, 'TabBarSplit')
    local Exp = iup.GetDialogChild(hMainLayout, 'CoSourceExpander')
    if tonumber(SSM.value) < 1000 then SSM.barsize = "5" end

    Splitter_CB = function(h)
        if h then
            if tonumber(SSM.value) > 999 and SSM.barsize ~= '0' then SSM.value = "999"
            elseif tonumber(SSM.value) < 1 then SSM.value = "1" end
        end
        if (_G.iuprops['coeditor.win'] or '0') == '0' and Exp.state == 'OPEN' and ((_G.iuprops['dialogs.coeditor.splithorizontal'] or 0) == 0) then
            local vSSR = 999
            if SSR.popupside == "0" then vSSR = tonumber(SSR.value) end
            --print(vSSR, SSR.popupside)
            local vSSL = 1
            if SSL.popupside == "0" then vSSL = tonumber(SSL.value) end
            TBS.value = ''..math.floor(vSSL + (tonumber(SSM.value) / 1000) * (vSSR / 1000) * (1000 - vSSL))
        end
    end
    local vc_SSL = SSL.valuechanged_cb
    local vc_SSR = SSR.valuechanged_cb
    local vc_SSM = SSM.valuechanged_cb

    SSL.valuechanged_cb = function(h) Splitter_CB(h) if vc_SSL then vc_SSL(h) end end
    SSR.valuechanged_cb = function(h) Splitter_CB(h) if vc_SSR then vc_SSR(h) end end
    SSM.valuechanged_cb = function(h) Splitter_CB(h);_G.iuprops["sidebarctrl.SourceSplitMiddle.value"]=SSR.value if vc_SSM then vc_SSM(h) end end

    local function onButton(h, hNew, button, pressed, x, y, tab, tabDrag, status)
        local ts = false
        if pressed == 1 and tab == tonumber(h.valuepos) then
            if ((h.name == 'TabCtrlLeft') and (scite.ActiveEditor() == 1)) or ((h.name == 'TabCtrlRight') and (scite.ActiveEditor() == 0)) then
                coeditor.Focus = true
                iup.RefreshChildren(vbScite)
            end
        end
        if button == iup.BUTTON1 and pressed == 0 then
            local clr = props['tabctrl.active.bakcolor']
            if clr == '' then clr = '255 255 255' end
            iup.SetAttribute(h, "BGCOLOR", clr)
            props["tabctrl.moved"] = 0
            h.cursor = 'ARROW'
            iup.Update(h)
            if (tabDrag > -1 and tab == -4) or (hNew and (hNew.name == 'TabCtrlRight' or hNew.name == 'TabCtrlLeft' )) then
                CORE.ChangeTab()
                iup.RefreshChildren(iup.GetDialogChild(iup.GetLayout(), 'SourceSplitBtm'))
            end
        elseif (button == iup.BUTTON1 and iup.isdouble(status) ) or (button == iup.BUTTON2 and pressed == 0 ) then
            local dblFlag = (tonumber(props['tabbar.tab.close.on.doubleclick']) or 0)
            if tab > - 1 and (((dblFlag & 1) == 1 and button == iup.BUTTON1) or ((dblFlag & 2) == 2 and button == iup.BUTTON2) ) then scite.MenuCommand(IDM_CLOSE)
            elseif tab == -1 then scite.MenuCommand(IDM_NEW) end
        elseif button == iup.BUTTON3 and pressed == 1 and tab >= -1 then
            menuhandler:ContextMenu(iup.MOUSEPOS, iup.MOUSEPOS, 'TABBAR')
        end
        if pressed == 0 then scite.RunAsync(function() CORE.ScipHidePannel() iup.PassFocus() end) end
    end

    local function onTabClose(h, tab)
        scite.MenuCommand(IDM_CLOSE)
    end

    local function onMotion(h, hNew, x, y, tab, tabDrag, start, status)
        if start == 2 then
            local clr = props['tabctrl.moved.color']
            if clr == '' then clr = '208 231 255' end
            iup.SetAttribute(h, "BGCOLOR", clr)
            props["tabctrl.moved"] = 1
            iup.Update(h)
        end
        if start > 0 then
            if tab ~= -1 then
                h.cursor = 'RESIZE_WE'
            elseif hNew and (hNew.name == 'TabCtrlRight' or hNew.name == 'TabCtrlLeft' ) then
                h.cursor = 'UPARROW'
            else
                h.cursor = 'NO'
            end
        end
    end

    local function onExButton(h, button, pressed)
        local side = Iif(h.name == 'TabCtrlLeft', 0, 1)
        if pressed == 0 then
            if not CORE.visibleWndDialog() then
                CORE.WndBySide(side, h)
            else
                local _, _, wx, wy = iup.GetGlobal('CURSORPOS'):find('(%d+)x(%d+)')
                wx = tonumber(wx); wy = tonumber(wy)
                local tMnu = CORE.windowsList(side)
                if side == 1 then
                    table.insert(tMnu,
                        {'s1', separator = 1}
                    )
                    table.insert(tMnu,
                        {link = 'View|Main Window split', plane = 1}
                    )
                    table.insert(tMnu,
                        {link = 'View|coeditor', plane = 1}
                    )
                end
                menuhandler:ContextMenu(wx, wy, tMnu)
            end
        else
            if side == scite.buffers.GetBufferSide(scite.buffers.GetCurrent()) then
                editor.Focus = true
            else
                coeditor.Focus = true
            end
        end
    end

    local function SetTab(tab)
        tab.showclose = Iif((tonumber(props['tabbar.tab.close.on.doubleclick']) or 0) > 0, 'NO', 'YES')
        tab.tab_button_cb = onButton
        tab.extraimage1 = "property_�"
        tab.extrapresscolor1 = props['layout.bgcolor']
        tab.highcolor = props['layout.txthlcolor']
        tab.tab_motion_cb = onMotion
        tab.extrabutton_cb = onExButton
        tab.tabclose_cb  = onTabClose
    end

    SetTab(iup.GetDialogChild(hMainLayout, 'TabCtrlLeft'))
    SetTab(iup.GetDialogChild(hMainLayout, 'TabCtrlRight'))
    AddEventHandler("OnInitHildiM", Splitter_CB)
end

function CORE.RemapTab(bIsH)
    local tab = iup.GetDialogChild(hMainLayout, 'RightTabExpander')
    local splitT = iup.GetDialogChild(hMainLayout, "TabBarSplit")
    local bIsHNow = (iup.GetParent(tab).name == 'coeditor_vbox')
    --print(iup.GetParent(tab).name, iup.GetParent(tab).name == 'TabBarSplit', bIsH)
    if (bIsH and bIsHNow) or (not bIsH and not bIsHNow) then
        if bIsH then
            iup.Reparent(tab, splitT, nil)
            --iup.Reparent(tab, iup.GetDialogChild(hMainLayout, "RightTabExpander"), nil)
        else
            iup.Reparent(tab, iup.GetDialogChild(hMainLayout, "coeditor_vbox"), iup.GetDialogChild(hMainLayout, 'CoSource'))
            tab.state = "OPEN"
            splitT.value = '1000'
        end
    end
end

function CORE.RemapCoeditor()
    local bIsH = (iup.GetChild(iup.GetDialogChild(hMainLayout, 'CoSourceExpanderBtm'), 1) ~= nil)
    local hBx = iup.GetDialogChild(hMainLayout, 'SourceExDetach')
    local hPrOld = iup.GetDialogChild(hMainLayout, Iif(bIsH, "SourceSplitBtm", "SourceSplitMiddle"))
    local hPr = iup.GetDialogChild(hMainLayout, Iif(bIsH, "SourceSplitMiddle", "SourceSplitBtm"))
    hPr.value = hPrOld.value
    hPr.barsize = '5'

    iup.Reparent(hBx, iup.GetDialogChild(hMainLayout, Iif(bIsH, "CoSourceExpander", "CoSourceExpanderBtm")), nil)

    CORE.RemapTab(bIsH)

    hPrOld.barsize = '0'
    hPrOld.value = '1000'

    if hPrOld.flat_button_cb then hPr.flat_button_cb = hPrOld.flat_button_cb end

    iup.RefreshChildren(vbScite)
    if bIsH then
        scite.RunAsync(function() Splitter_CB(iup.GetDialogChild(hMainLayout, "TabBarSplit")) end)
    end
    _G.iuprops['dialogs.coeditor.splithorizontal'] = Iif(bIsH, 0, 1)
end

function CORE.ChangeTab(cmd)
    scite.MenuCommand(cmd or IDM_CHANGETAB)
    if scite.buffers.SecondEditorActive() == 1 then
        local cs = iup.GetDialogChild(hMainLayout, 'CoSource')
        cs.visible = 'YES'
        local bIsH = (iup.GetChild(iup.GetDialogChild(hMainLayout, 'CoSourceExpanderBtm'), 1) ~= nil)
        if bIsH then
            iup.GetDialogChild(hMainLayout, "TabBarSplit").value = iup.GetDialogChild(hMainLayout, "SourceSplitBtm").value
        end
        iup.RefreshChildren(vbScite)
    end
end

local function InitToolBar()
    --if true then return end
    ToolBar_obj.Tabs = {}

    --tTlb = {CreateToolBar()(ToolBar_obj)}
    tTlb = {CreateToolBar()}
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
    --ToolBar_obj.handle = iup.scitedialog(tTlb) cacaca
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
     _tmpSidebarButtons = nil

    tTlb.control = "YES"
    tTlb.sciteid="iupstatusbar"
    tTlb.show_cb=(function(h,state)

        if state == 0 and props['iuptoolbar.visible'] == '1' and props['iuptoolbar.restarted'] ~= '1' then
           -- scite.MenuCommand(IDM_VIEWTLBARIUP) 778899
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

function CORE.convertLayout(txtIn, bUnic)
    local tEnRu = {['`'] = '�',['1'] = '1',['2'] = '2',['3'] = '3',['4'] = '4',['5'] = '5',['6'] = '6',['7'] = '7',['8'] = '8',['9'] = '9',['0'] = '0',['-'] = '-',['='] = '=',['q'] = '�',['w'] = '�',['e'] = '�',['r'] = '�',['t'] = '�',['y'] = '�',['u'] = '�',['i'] = '�',['o'] = '�',['p'] = '�',['['] = '�',[']'] = '�',['a'] = '�',['s'] = '�',['d'] = '�',['f'] = '�',['g'] = '�',['h'] = '�',['j'] = '�',['k'] = '�',['l'] = '�',[';'] = '�',["'"] = '�',['z'] = '�',['x'] = '�',['c'] = '�',['v'] = '�',['b'] = '�',['n'] = '�',['m'] = '�',[','] = '�',['.'] = '�',['/'] = '.',['~'] = '�',['!'] = '!',['@'] = '"',['#'] = '�',['$'] = ';',['%'] = '%',['^'] = ':',['&'] = '?',['*'] = '*',['('] = '(',[')'] = ')',['_'] = '_',['+'] = '+',['Q'] = '�',['W'] = '�',['E'] = '�',['R'] = '�',['T'] = '�',['Y'] = '�',['U'] = '�',['I'] = '�',['O'] = '�',['P'] = '�',['{'] = '�',['}'] = '�',['A'] = '�',['S'] = '�',['D'] = '�',['F'] = '�',['G'] = '�',['H'] = '�',['J'] = '�',['K'] = '�',['L'] = '�',[':'] = '�',['"'] = '�',['Z']='�',['X']='�',['C']='�',['V']='�',['B']='�',['N']='�',['M']='�',['<']='�',['>']='�',['?']=',',}
    local tRuEn = {['�'] = '`',['1'] = '1',['2'] = '2',['3'] = '3',['4'] = '4',['5'] = '5',['6'] = '6',['7'] = '7',['8'] = '8',['9'] = '9',['0'] = '0',['-'] = '-',['='] = '=',['�'] = 'q',['�'] = 'w',['�'] = 'e',['�'] = 'r',['�'] = 't',['�'] = 'y',['�'] = 'u',['�'] = 'i',['�'] = 'o',['�'] = 'p',['�'] = '[',['�'] = ']',['�'] = 'a',['�'] = 's',['�'] = 'd',['�'] = 'f',['�'] = 'g',['�'] = 'h',['�'] = 'j',['�'] = 'k',['�'] = 'l',['�'] = ';',['�'] = "'",['�'] = 'z',['�'] = 'x',['�'] = 'c',['�'] = 'v',['�'] = 'b',['�'] = 'n',['�'] = 'm',['�'] = ',',['�'] = '.',['.'] = '/',['�'] = '~',['!'] = '!',['"'] = '@',['�'] = '#',[';'] = '$',['%'] = '%',[':'] = '^',['?'] = '&',['*'] = '*',['('] = '(',[')'] = ')',['_'] = '_',['+'] = '+',['�'] = 'Q',['�'] = 'W',['�'] = 'E',['�'] = 'R',['�'] = 'T',['�'] = 'Y',['�'] = 'U',['�'] = 'I',['�'] = 'O',['�'] = 'P',['�'] = '{',['�'] = '}',['�'] = 'A',['�'] = 'S',['�'] = 'D',['�'] = 'F',['�'] = 'G',['�'] = 'H',['�'] = 'J',['�'] = 'K',['�'] = 'L',['�'] = ':',['�'] = '"',['�']='Z',['�']='X',['�']='C',['�']='V',['�']='B',['�']='N',['�']='M',['�']='<',['�']='>',[',']='?',}


    if txtIn == '' then return '' end
    local txt = txtIn
    if bUnic then txt = txt:from_utf8() end

    local iE, iR = 0, 0
    local s
    for i = 1,  #(txt or '') do
        s = txt:sub(i, i)
        if tEnRu[s] then iE = iE + 1 end
        if tRuEn[s] then iR = iR + 1 end
    end
    --print(iE, iR)
    local tTarget = Iif(iE > iR, tEnRu, tRuEn)
    local res = {}
    for i = 1,  #txt do
        s = txt:sub(i, i)
        table.insert(res, (tTarget[s] or s))
    end
    if bUnic then return table.concat(res):to_utf8() end
    return table.concat(res)
end

require "menuhandler"
local function InitMenuBar()
    local dlg, mnufind, tree_mnu

    local function GetCaption()
        local hk = menuhandler:GetHotKey('MainWindowMenu|Search|Find in Menu')
        if hk ~= '' then hk = ' ('..hk..')' end
        return _TH'Find...'..hk
    end

    local tmrFocus = iup.timer{time = 1, action_cb = function(h)
        h.run = 'NO'
        if dlg.activewindow == 'NO' and dlg.visible == 'YES' then
            dlg.visible = 'NO'
            tree_mnu.delnode0 = "CHILDREN"
            iup.PassFocus()
        end
        mnufind.fgcolor = props['layout.txtinactivcolor']
        mnufind.value = GetCaption()
    end}

    local function setnextLeaf(d)
        local v = tonumber(tree_mnu.value)
        if v == 0 then v = 1 end
        while v > 0 and v < tonumber(tree_mnu.count) do
            v = v + d
            if iup.GetAttributeId(tree_mnu, "KIND", v) == "LEAF" then
                tree_mnu.value = v
                return
            end
        end
    end

    mnufind = iup.text{ size = "80", name = 'menu_find', bgcolor = props['layout.splittercolor'], bordercolor = props['layout.splittercolor'],
        fgcolor = props['layout.txtinactivcolor'], padding = '3x', value = GetCaption(),
        getfocus_cb = function()
            tmrFocus.run = 'NO'
            if dlg.visible == 'NO' then mnufind.value = '';mnufind.fgcolor = props['layout.fgcolor'] end
        end,
        killfocus_cb = function(h)
            tmrFocus.run = 'YES'
        end,
        k_any = function(h, k)
            if k == iup.K_ESC then
                tmrFocus.run = 'YES'
            elseif k == iup.K_DOWN then
                setnextLeaf(1)
            elseif k == iup.K_UP then
                setnextLeaf(-1)
            elseif k == iup.K_CR then
                if iup.GetAttributeId(tree_mnu, 'KIND', tree_mnu.value) == 'LEAF' then
                    tree_mnu.executeleaf_cb(tree_mnu, tree_mnu.value)
                end
            end
    end}
    iup.SetAttribute(mnufind, 'HISTORIZED', 'NO')
    tree_mnu = iup.flattree{expand = 'YES', fgcolor = props['layout.txtfgcolor'], hidebuttons = 'YES',
        imagebranchexpanded = '_', imagebranchcollapsed = '_',
        getfocus_cb = function() tmrFocus.run = 'NO' end, killfocus_cb = function(h)
        tmrFocus.run = 'YES'
    end}

    tree_mnu.executeleaf_cb = function(h, id)
        local tUid = iup.TreeGetUserId(tree_mnu, id)
        if type(tUid) == 'function' then tUid() end
        tmrFocus.run = 'YES'
        iup.PassFocus()
    end

    dlg = iup.scitedialog{iup.vbox{tree_mnu},
        sciteparent = "SCITE", sciteid = 'menufind', dropdown = true, shrink = "YES", --resize = 'NO',   maxsize = '800x250',
        maxbox = 'NO', minbox = 'NO', menubox = 'NO', minsize = '250x250', bgcolor = '255 255 255', shownoactivate = 'YES', shownofocus = 'YES',
        customframedraw = 'YES' , customframecaptionheight = -1, customframedraw_cb = CORE.paneldraw_cb, customframeactivate_cb =
        function(h, active)
            if active == 0 then tmrFocus.run = 'YES' end
            CORE.panelactivate_cb(nil)(h, active)
        end,
    }

    local function processCondition(cond)
        local f
        if type(cond) == "function" then
            f = cond
        elseif type(cond) == "string" then
            f = assert(load('return '..cond))
        end
        if f then return f() end
    end

    local function findCap(t, v, v2)
        local val = v:lower()
        if v2 then v2 = v2:lower() end
        local s = (t[1] or ''):gsub("&", ''):lower()
        if s:find(val) then return true end
        if v2 and s:find(v2) then return true end
        s = (t.cpt or _TM(t[1] or '') or ''):gsub("&", ''):lower()
        if s:find(val) then return true end
        if v2 and s:find(v2) then return true end
    end
    local function findMenuRecr(t, v, v2)
        local tOut, plane, tRez
        if t.title then
            for i = 1,  #t do
                tRez, plane = findMenuRecr(t[i], v, v2)
                if tRez then
                    if not tOut then
                        tOut = {_TM(t.title), {}}
                    end
                    if plane then
                        for i = 1,  #tRez[2] do
                            table.insert(tOut[2], tRez[2][i])
                        end
                    else
                        table.insert(tOut[2], tRez)
                    end
                end
            end
        elseif not t[2] then

            if not t.separator and not t.link and findCap(t, v, v2) then
                if t.active then
                    if not processCondition(t.active) then goto e end
                end
                if t.visible then
                    if not processCondition(t.visible) then goto e end
                elseif t.visible_ext then
                    if not string.find(','..t.visible_ext..',', ','..props["FileExt"]..',')  then goto e end
                end
                local act
                local suff = ''
                if t.action then
                    local tp = type(t.action)
                    if tp == 'number' then act = function() scite.MenuCommand(t.action) end end
                    if tp == 'string' then act = assert(load('return '..t.action)) end
                    if tp == 'function' then act = t.action end
                end
                if t.check_idm then
                elseif t.check_prop then
                    act = assert(load("CheckChange('"..t.check_prop.."', true)"))
                    suff = Iif(props[t.check_prop] == '1', '[x]', '[ ]')
                elseif t.check_iuprops then
                    local rez
                    if act then rez = act end
                    local rez2 = assert(load("_G.iuprops['"..t.check_iuprops.."'] = "..Iif(tonumber(_G.iuprops[t.check_iuprops]) == 1 or _G.iuprops[t.check_iuprops] == true or _G.iuprops[t.check_iuprops] == 'ON' , 0, 1)))
                    if rez then
                        act = function() rez2(); rez() end
                    else
                        act = rez2
                    end
                    suff = Iif(tonumber(_G.iuprops[t.check_iuprops]) == 1 or _G.iuprops[t.check_iuprops] == true or _G.iuprops[t.check_iuprops] == 'ON' , '[x]', '[ ]')
                elseif t.check_boolean then
                    act = assert(load("_G.iuprops['"..t.check_boolean.."'] = not _G.iuprops['"..t.check_boolean.."']"))
                    suff = Iif(_G.iuprops[t.check_boolean], '[x]', '[ ]')
                elseif t.check then
                    local f
                    if type(t.check) == "function" then
                        f = t.check
                    elseif type(t.check) == "string" then
                        f = assert(load('return '..t.check))
                    end
                    if f then suff = Iif(f(), '[x]', '[ ]') end
                end
                if not act then
                    act = function() debug_prnArgs('Error in menu format!!', t) end
                end
                if t.key then
                    suff = suff..' - '..t.key
                end

                tOut = {(t.cpt or _TM(t[1]) or t[1])..suff, action = act, image = t.image}
            end
        elseif (type(t[2]) == 'table' or type(t[2]) == 'function') and not t.scipfind then
            if t.visible then
                if not processCondition(t.visible) then goto e end
            elseif t.visible_ext then
                if not string.find(','..t.visible_ext..',', ','..props["FileExt"]..',')  then goto e end
            end
            local tX = t[2]
            if type(t[2]) == 'function' then
                local sucs
                sucs, tX = pcall(t[2])
                if not sucs then return end
            end
            for i = 1,  #tX do
                tRez, plane = findMenuRecr(tX[i], v, v2)
                if tRez then
                    if not tOut then
                        tOut = {t.cpt or _TM(t[1] or t[1]), {}}
                    end
                    if plane then
                        for i = 1,  #tRez[2] do
                            table.insert(tOut[2], tRez[2][i])
                        end
                    else
                        table.insert(tOut[2], tRez)
                    end
                end
            end
        end
::e::
        return tOut, t.plane
    end
    local function mnu2tree(t, tOut)
        if not t then return end
        local tNew = {}
        table.insert(tOut, tNew)
        if type(t[2]) == 'table' then
            tNew.branchname = t[1]
            for i = 1, #t[2] do
                mnu2tree(t[2][i], tNew)
            end
        else
            tNew.leafname = t[1]
            tNew.userid = t.action
            tNew.image = t.image or "_"
        end
    end

    local tmrFind = iup.timer{time = 300, action_cb = function(h)
        h.run = 'NO'
        local v, v1 = mnufind.value:gsub('%[', '%%['):gsub('%]', '%%]'), CORE.convertLayout(mnufind.value, true):gsub('%[', '%%['):gsub('%]', '%%]')
        local t = {}

        for s, tl in pairs(sys_Menus) do
            local tl2 = findMenuRecr(tl, v, v1)
            if tl2 and #tl2 > 0 then table.insert(t, tl2) end
        end
        local tMnu = {}
        tMnu.branchname = ''
        mnu2tree({_TH'All Menus', t}, tMnu)
        iup.ShowXY(dlg, mnufind.x, mnufind.y + tonumber(mnufind.rastersize:gsub("[^x]*x(.*)", "%1"), 10))
        tree_mnu.autoredraw = 'NO'
        tree_mnu.delnode0 = "CHILDREN"
        iup.TreeAddNodes(tree_mnu, tMnu[1])
        tree_mnu.autoredraw = 'YES'
        tree_mnu.value = 0
        setnextLeaf(1)
    end}

    CORE.StartMenuFind = function()
        iup.SetFocus(mnufind)
        mnufind.value = ''
        mnufind.fgcolor = props['layout.fgcolor']
    end

    menuhandler:Init()
    if not _G.sys_Menus then return end
    local vbScite = iup.GetDialogChild(hMainLayout, "SciteVB")
    MenuBar_obj = {}
    MenuBar_obj.Tabs = {}
    local mnu = sys_Menus.MainWindowMenu
    function mnufind:valuechanged_cb()
        tmrFind.run = 'NO'
        if #mnufind.value:from_utf8() > 1 then
            tmrFind.run = 'YES'
        else
            dlg.visible = 'NO'
        end
    end

    local hb = { alignment = 'ACENTER', expand = 'HORIZONTAL', name = 'Hildim_MenuBar'}
    for i = 1, #mnu do
        if mnu[i][1] ~='_HIDDEN_' then
            table.insert(hb, menuhandler:CreateMenuLabel(mnu[i]))
            if i == #mnu - 1 then
                table.insert(hb, mnufind)
                table.insert(hb, iup.fill{})
            elseif i < #mnu - 1 then table.insert(hb, iup.canvas{ maxsize = 'x18', rastersize = '1x', bgcolor = props['layout.bordercolor'], expand = 'NO', border = 'NO'}) end
            -- elseif i < #mnu - 1 then table.insert(hb, iup.label{separator = "VERTICAL",maxsize='x18'}) end
        end
    end

    local tTlb = {iup.expander{barsize = 0, state="OPEN", name = "MenuBar",iup.vbox{expandchildren ='YES', iup.hbox(hb)}}};

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

local function resetSBColors(sb)
    iup.SetAttributeId2(sb, "COLORID", 1, -1, "")
    iup.SetAttributeId2(sb, "COLORID", 2, -1, "")
    iup.SetAttributeId2(sb, "COLORID", 1, MARKER_BOOKMARK, Iif(props["bookmark.fore"]~= '', CORE.Rgb2Str(props["bookmark.fore"]), '0 0 255', 0))
    iup.SetAttributeId2(sb, "COLORID", 1, SC_MARKNUM_HISTORY_MODIFIED, '255 128 0')
    iup.SetAttributeId2(sb, "COLORID", 1, SC_MARKNUM_HISTORY_REVERTED_TO_MODIFIED, '64 164 191')
    iup.SetAttributeId2(sb, "COLORID", 1, SC_MARKNUM_HISTORY_REVERTED_TO_ORIGIN, '160 192 0')
    iup.SetAttributeId2(sb, "COLORID", 1, SC_MARKNUM_HISTORY_SAVED, '0 160 0')
end

local function edit_scroll_menu(h, btn, pos, scroll)
    if btn == iup.BUTTON3 then
        if scroll == 'SB_VERT' then
            _SCROLLTO = function() h.posy = pos; end
           menuhandler:PopUp("MainWindowMenu|_HIDDEN_|EditVScroll")
        else
            _SCROLLTO = function() h.posx = pos; end
           menuhandler:PopUp("MainWindowMenu|_HIDDEN_|AllScroll")
        end
    elseif btn == iup.BUTTON2 then
        if scroll == 'SB_VERT' then
            CORE.ClearLiveFindMrk()
        else
            CORE.BottomBarSwitch('NO')
        end
    end
end

local ed = iup.GetDialogChild(iup.GetLayout(), 'Source')
resetSBColors(ed)
ed.contextmenu_cb = edit_scroll_menu
local ed = iup.GetDialogChild(iup.GetLayout(), 'CoSource')
resetSBColors(ed)
ed.contextmenu_cb = edit_scroll_menu

InitMenuBar()
--������������ ������� ��������
local tbl = _G.iuprops["settings.hidden.plugins"] or {}
local strTbl = 'return function(h) return iup.expander{barsize = 0, state="OPEN", name = "toolbar_expander", iup.vbox{gap="1", iup.hbox{\n'
local i = 0
for i = 1, #tbl do
    local p = tbl[i]
    local bSucs, pI = pcall(dolocale, "tools\\UIPlugins\\"..p)
    if not bSucs then
        print(pI)
        goto continue
    end
    if pI then
        local bSucs, res = pcall(pI.hidden)
        if not bSucs then
            print(res)
            goto continue
        end
        if pI.destroy then table.insert(CORE.onDestroy_event, pI.destroy) end
    else
        print('Hidden plugin "'..p..'" not found')
    end
::continue::
end
local tbl = _G.iuprops["settings.commands.plugins"] or {}
for i = 1, #tbl do
    local p = tbl[i]
    local bSucs, pI = pcall(dolocale, "tools\\Commands\\"..p)
    if not bSucs then
        print(pI)
        goto continue
    end
    if pI and pI.run then
        local t = {}
        if pI.title_utf then
            t[1] = pI.title
        else
            t[1] = pI.title:to_utf8()
        end
        t.visible = pI.visible
        if pI.key then t.key = pI.key end
        t.action = function() dolocale("tools\\Commands\\"..p).run() end

        menuhandler:InsertItem('MainWindowMenu', pI.path or 'Tools|xxx', t)
    end
::continue::
end

InitSideBar()
InitTabbar()
InitToolBar()
InitStatusBar()
local hBx = iup.GetDialogChild(hMainLayout, 'SourceExDetach')
if (_G.iuprops['dialogs.coeditor.splithorizontal'] or 0) == 1 then          -- props['session.reload'] ~= '1' and
    if iup.GetChild(iup.GetDialogChild(hMainLayout, 'CoSourceExpanderBtm'), 1) == nil then
        CORE.RemapCoeditor()
    end
else
    if iup.GetChild(iup.GetDialogChild(hMainLayout, 'CoSourceExpanderBtm'), 1) ~= nil then
        CORE.RemapCoeditor()
    end
end
RestoreNamedValues(hMainLayout, 'sidebarctrl')
RestoreNamedValues(hMainLayout, 'findreplace')
--iup.Refresh(hMainLayout)
if not LeftBar_obj.handle then iup.GetDialogChild(hMainLayout, "LeftBarExpander").state='CLOSE'; iup.GetDialogChild(hMainLayout, "SourceSplitLeft").barsize = '0' ; iup.GetDialogChild(hMainLayout, "SourceSplitLeft").value = '0'
else iup.GetDialogChild(hMainLayout, "LeftBarExpander").state='OPEN'; iup.GetDialogChild(hMainLayout, "SourceSplitLeft").barsize = '5'   end
if not SideBar_obj.handle then iup.GetDialogChild(hMainLayout, "RightBarExpander").state='CLOSE'; iup.GetDialogChild(hMainLayout, "SourceSplitRight").barsize = '0' ; iup.GetDialogChild(hMainLayout, "SourceSplitRight").value = '1000'
else iup.GetDialogChild(hMainLayout, "RightBarExpander").state='OPEN'; iup.GetDialogChild(hMainLayout, "SourceSplitRight").barsize = '5'   end
if iup.GetDialogChild(hMainLayout, "BottomSplit2").barsize=="0" then iup.GetDialogChild(hMainLayout, "BottomSplit2").value="1000" end
hMainLayout.resize_cb = function()
    local tmr = iup.timer{time = 10, action_cb = function(h)
        h.run = 'NO'
        if iup.GetDialogChild(hMainLayout, "LeftBarExpander").state == 'CLOSE' then iup.GetDialogChild(hMainLayout, "SourceSplitLeft").value = '0' end
        if iup.GetDialogChild(hMainLayout, "RightBarExpander").state == 'CLOSE' then iup.GetDialogChild(hMainLayout, "SourceSplitRight").value = '1000' end
    end}
    tmr.run = 'YES'
end

bottomsplit.flat_button_cb = function(h, button, pressed, x, y, status)
    if button == iup.BUTTON3 and pressed == 1 then
        menuhandler:PopUp('MainWindowMenu|View|BottomBar')
    elseif button == iup.BUTTON2 and pressed ~= 1 and iup.iscontrol(status)  then
        scite.MenuCommand(IDM_TOGGLEOUTPUT)
    elseif button == iup.BUTTON1 and iup.isdouble(status) then
        CORE.switch_bottombar()
    end
end

try{
    function() dolocale('tools\\BuffersList.lua') end,
    catch{
        print
    }
}

--menuhandler:DoPostponedInsert()
scite.RunAsync(function() menuhandler:DoPostponedInsert() end)

local bMenu,bToolBar,bStatusBar
local bSideBar, bLeftBar, bconsoleBar, bFindResBar, bFindRepl

local function CheckExists()
    if props['FilePath']:find('\\') == 1 then return end
    local i = scite.buffers.GetCurrent()
    local curName = props['FilePath']
    if not shell.fileexists(props['FilePath']) and scite.buffers.FileTimeAt(i) ~= 0 then
        local msg = _TH"File \n'%1'\n is missing or not available.\nDo you wish to keep the file open in the editor?"
        if 2 == iup.Alarm('HildiM', _FMT(msg, props['FilePath']), _TH"OK", _TH"No") then
            if curName == props['FilePath'] then scite.MenuCommand(IDM_CLOSE) end --��������� ����� ������� ��� ������� ������(��������) �� ���������� ������� - ��� ���� ��� ����� ���������
        else
            if curName == props['FilePath'] then scite.buffers.ClearFileTimeAt(i) end
        end
    end
end

AddEventHandler("OnSwitchFile", function(file)
    scite.RunAsync(CheckExists)
    if scite.ActiveEditor() == 1 then
        if (_G.iuprops['coeditor.win'] or '0') == '2' and scite.buffers.SecondEditorActive() == 1 then CoEditor.Switch();
        elseif (_G.iuprops['coeditor.win'] or '0') == '1' then  local b = iup.GetDialogChild(CoEditor, "Title"); b.title = props['FileNameExt']; iup.Redraw(b, 1) end
    end
    scite.RunAsync(function() editor.VScrollBar = true end)
end)

AddEventHandler("OnRightEditorVisibility", function(show)
    if (show == 0 and ((_G.iuprops['coeditor.win'] or '0') ~= '2')) or
      (show == 1 and ((_G.iuprops['coeditor.win'] or '0') == '2')) then
        CoEditor.Switch()
        local expand = iup.GetDialogChild(hMainLayout, "RightTabExpander")
        local split = iup.GetDialogChild(hMainLayout, "TabBarSplit")
        if show == 1 then
            coeditor.Zoom = editor.Zoom
            Splitter_CB()
            expand.state = "OPEN"
        else
            split.value = "1000"
            expand.state = "CLOSE"
        end
    end
end)

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
        if (_G.iuprops['concolebar.win'] or '0') == '1' or (_G.iuprops['concolebar.autoshow'] or 0) == 0 then return end
        if (_G.iuprops['concolebar.win'] or '0') == '0' and CORE.BottomBarHidden() then CORE.BottomBarSwitch('YES') return end
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
        if bFindRepl then iup.GetDialogChild(hMainLayout, "FindReplDetach").Attach() end
        if iup.GetDialogChild(iup.GetLayout(), "BottomBarSplit").hidden == "YES" then CORE.BottomBarSwitch('YES') end
    end
end)

function CORE.OnPasteCommand()
    if not Format_Lines then return end
    CORE._PasteParams = {}
    local tmr = iup.timer{time = 1; run = 'NO';action_cb = (function(h)
        h.run = 'NO'
        if CORE._PasteParams and CORE._PasteParams.position then
            local l = editor:LineFromPosition(CORE._PasteParams.position)
            if editor:textrange(editor:PositionFromLine(l), CORE._PasteParams.position):find('%S') then
                if CORE._PasteParams.linesAdded > 0 then Format_Lines(l + 1, l + CORE._PasteParams.linesAdded) end
            else
                Format_Lines(l , l + CORE._PasteParams.linesAdded)
            end
        end
        CORE._PasteParams = nil
    end)}
    tmr.run = 'YES'
end

AddEventHandler("OnSendEditor", function(id_msg, wp, lp)
    if id_msg == SCI_PASTE then CORE.OnPasteCommand() end
end)

AddEventHandler("OnKey", function(key, shift, ctrl, alt, char)
    if key == iup.K_V and not shift and ctrl and not alt then
        CORE.OnPasteCommand()
    elseif key == 27 and not shift and not ctrl and not alt then
        if output.Focus then
            if (_G.iuprops['concolebar.win'] or '0') == '1' then ConsoleBar.Switch() end
        elseif findres.Focus then
            if (_G.iuprops['findresbar.win'] or '0') == '1' then FindResBar.Switch() end
        else
            CORE.HidePannels()
            return
        end
        iup.PassFocus()
    elseif key == iup.K_CR and findres.Focus then
        if findres:LineFromPosition(findres.SelectionStart) == findres:LineFromPosition(findres.SelectionEnd) then
            local curpos = findres:PositionFromLine(findres:LineFromPosition(findres.SelectionStart))
            local st = findres.StyleAt[curpos]
            if st == 3 then
                CORE.FindresClickPos(curpos)
            elseif st == 2 or st == 1 then
                findres:ToggleFold(findres:LineFromPosition(curpos))
            end
        end
        return true
    end
end)

function CORE.ChangeCode(unicmode, codepage)
    codepage = codepage or 0
    scite.buffers.SetEncodingAt(scite.buffers.GetCurrent(), codepage)

    if unicmode ~= math.tointeger(props['editor.unicode.mode']) then
        local s = editor:GetText()
        if unicmode == IDM_ENCODING_DEFAULT then
            s = s:from_utf8()
        elseif props['editor.unicode.mode'] == ''..IDM_ENCODING_DEFAULT then
            s = s:to_utf8()
        end
        scite.MenuCommand(unicmode)
        CORE.SetText(s)
        editor:EmptyUndoBuffer()
    end
end

function CORE.DoRevert()
    BlockEventHandler"OnTextChanged"
    scite.MenuCommand(IDM_REVERT)
    UnBlockEventHandler"OnTextChanged"
end

function CORE.Revert()
    if not editor.Modify or (iup.Alarm(_TM'Reopen File', _FMT(_TH"The file \n'%1'\n has been modified. Should it be reloaded?", props["FilePath"]:to_utf8()), _TH'Yes', _TH'No') == 1) then
        _ENCODINGCOOKIE = scite.buffers.EncodingAt(scite.buffers.GetCurrent())
        CORE.DoRevert()
        _ENCODINGCOOKIE = nil
        scite.BlockUpdate(UPDATE_FORCE)
    end
end

function CORE.SetCP(unicmode, codepage)
    if unicmode ~= math.tointeger(props['editor.unicode.mode']) then scite.MenuCommand(unicmode) end
    local cp = scite.buffers.EncodingAt(scite.buffers.GetCurrent())
    if cp == 0 then cp = math.tointeger(props['system.code.page']) end
    if cp ~= (codepage or math.tointeger(props['system.code.page']) ) then
        if not editor.Modify or (iup.Alarm(_TM'Reopen File', _FMT(_TH"The file \n'%1'\n has been modified. Should it be reloaded?", props["FilePath"]:to_utf8()), _TH'Yes', _TH'No') == 1) then
            _ENCODINGCOOKIE = codepage
            if _ENCODINGCOOKIE == math.tointeger(props['system.code.page']) then _ENCODINGCOOKIE = 0 end
            CORE.DoRevert()
            _ENCODINGCOOKIE = nil
        else
            return
        end
    end
end

AddEventHandler("OnBeforeOpen", function(file, ext)
    if _ENCODINGCOOKIE then return _ENCODINGCOOKIE end
end)

local tmConsole

function CORE.ResetConcoleTimer(bStop)
    tmConsole.run = "NO"
    if not bStop then tmConsole.run="YES" end
end

tmConsole = iup.timer{time = 60000}
tmConsole.action_cb = (function()
    if output.LineCount > 200 and output.FirstVisibleLine + 2*output.LinesOnScreen > output.LineCount then
        output.TargetStart = 0
        output.TargetEnd = output:PositionFromLine(output.LineCount-200)
        output:ReplaceTarget('')
    end
end)
tmConsole.run="YES"
