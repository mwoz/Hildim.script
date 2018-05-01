require 'shell'
SideBar_obj = {}
LeftBar_obj = {}
SideBar_Plugins = {}
local ToolBar_obj = {}
local Splitter_CB

local win_parent --создаем основное окно
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
                               -- RGB(121, 161, 201)
local vbScite = iup.GetDialogChild(hMainLayout, "SciteVB")

iup.PassFocus =(function()
    if scite.buffers.GetCurrent() >= 0 then
        editor:GrabFocus()
    else
        iup.SetFocus(iup.GetDialogChild(hMainLayout, "Source"))
    end
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
    local tblVb = {gap = "1", name="ToolBar"}
    local tblHb
    --local i = 0
    local isUpper = false
    local tblBars = _G.iuprops["settings.toolbars.layout"] or {}
    for i = 1, #tblBars do
        if #(tblBars[i]) > 0 then
            if i > 1 then
                table.insert(tblVb, iup.hbox(tblHb))
                if i > 2 or not isUpper then table.insert(tblVb, iup.label{separator = "HORIZONTAL"}) end
            end
            tblHb = {gap = "3", margin = "3x1", alignment = "ACENTER"}
            for j = 1, #(tblBars[i]) do
                local pname = tblBars[i][j]
                local bSucs, pI = pcall(dofile, props["SciteDefaultHome"].."\\tools\\UIPlugins\\"..pname)
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

                if i == 1 and pI.undermenu then
                    local tTlb = {iup.expander{barsize = 0, state = "OPEN", name = "toolbar_expander_upper", iup.vbox{
                        iup.hbox{gap = "3", margin = "3x0", alignment = "ACENTER", ToolBar_obj.Tabs[pI.code].handle}
                    }}}

                    local hTmp = iup.dialog(tTlb)

                    local hBx = iup.GetDialogChild(hTmp, 'toolbar_expander_upper')
                    iup.Detach(hBx)
                    iup.Destroy(hTmp)
                    local ttt = iup.Insert(vbScite, nil, hBx)
                    iup.Map(hBx)
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
        local bSucs, pI = pcall(dofile, props["SciteDefaultHome"].."\\tools\\UIPlugins\\"..p)
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
    table.insert(tblH, iup.fill{})
    if _tmpSidebarButtons then
        for i = 1,  #_tmpSidebarButtons do
            table.insert(tblH, _tmpSidebarButtons[i])
        end
    end
    return iup.expander{barsize = 0, state = "OPEN", name = "statusbar_expander", iup.hbox(tblH)}
end

function iup.SaveNamedValues(h, root)
    if not h then return end
    local child = nil
    repeat
        child = iup.GetNextChild(h, child)
        if child then
            if (child.value or child.valuepos or child.focusitem or child.size) and child.name and (iup.GetAttribute(child, 'HISTORIZED') ~= 'NO') then
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
        local b
        if t.type == "VBOX" then
            l = iup.vbox(t)
        elseif t.type == "SPLIT" then
            t.layoutdrag = 'NO'
            l = iup.split(t)
        elseif t.type == "FIND" then
            SideBar_Plugins.findrepl.Bar_obj = pane_curObj
            table.insert(sb_elements, SideBar_Plugins.findrepl)
            l = iup.backgroundbox{iup.expander{iup.scrollbox{SideBar_Plugins.findrepl.handle, name = 'FinReplScroll', expand = "HORIZONTAL", scrollbar = 'NO', size = 'x108'}, barsize = '0', name = "FinReplExp"}}
        elseif t.type == nil then
            l = t[1]
        else print('Unsupported type:'..t.type) end
        l.tabtitle = t.tabtitle
        table.insert(tbl_hotkeys, t.tabhotkey or '')
        return l
    end

    local hk_pointer
    local function SideBar(t, Bar_Obj, sciteid)
        if not t then return end
        t.name = 'sidebartab_'..sciteid
        Bar_Obj.sciteid = sciteid
        local brObj = Bar_Obj
        t.map_cb = (function(h)
            h.size = "1x1"
        end)
        t.tabchange_cb = (function(_, new_tab, old_tab)
            --сначала найдем активный таб и установим его в SideBar_ob
            for _, tbs in pairs(SideBar_Plugins) do
                if tbs["tabs_OnSelect"] then tbs.tabs_OnSelect() end
                if tbs.id == new_tab.tabtitle then
                    if tbs["on_SelectMe"] then tbs.on_SelectMe() end
                end
            end
        end)
        t.k_any = (function(h, c) if c == iup.K_ESC then iup.PassFocus() end end)
        t.extrabuttons = 1
        t.extraimage1 = "property_µ"
        t.extrapresscolor1 = iup.GetGlobal("DLGBGCOLOR")
        t.extrabutton_cb = function(h, button, state) if state == 1 then menuhandler:PopUp('MainWindowMenu|View|'..sciteid) end end

        local j = 1
        local s = 'Hotkeys for Tab Activation:'
        for i = hk_pointer,  #tbl_hotkeys do
            s = s..'\n Tab'..(i - hk_pointer + 1)..' - <'..Iif(tbl_hotkeys[i] == '', '', tbl_hotkeys[i])..'>'
        end
        hk_pointer =  #tbl_hotkeys + 1
        t.tip = s
        t.tabspadding = '10x3'
        t.forecolor = '0 0 0'
        t.highcolor = '15 60 195'
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
            hVbox; orientation = "HORIZONTAL";barsize = 5;minsize = "100x100";name = sName; shrink = "yes"; buttonImage = buttonImage;
            sciteid = sSciteId;Split_h = spl_h;Split_CloseVal = sSplit_CloseVal;
            Dlg_Title = sSide.." Side Bar"; Dlg_Show_Cb = nil;
            On_Detach = (function(h, hNew, x, y)
                iup.GetDialogChild(iup.GetLayout(), sExpander).state = "CLOSE";
                --h.visible
            end);
            Dlg_Close_Cb = (function(h)
                iup.GetDialogChild(iup.GetLayout(), sExpander).state = "OPEN";
            end);
            Dlg_Show_Cb =(function(h, state)
                if state == 4 then
                    for _, tbs in pairs(SideBar_Plugins) do
                        if tbs["OnSideBarClouse"] then tbs.OnSideBarClouse() end
                    end
                end
            end);
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
        local defpath = props["SciteDefaultHome"].."\\tools\\UIPlugins\\"
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
        for i = 1, #tSide do
            tCur = tSide[i]
            if tCur[1] then
                local bSucs, pI = pcall(dofile, defpath..tCur[1])
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
                        bSucs, pI = pcall(dofile, defpath..tCur[j])
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
                        if j == #tCur then

                            tSub.tabtitle = tabName
                            tSub.tabhotkey = (tabhotkey or '')
                        end

                        tSub = Pane(tSub)
                    end

                    table.insert(tArg, tSub)

                end
                ::continue::
            end
        end
        return tArg
    end
    hk_pointer = 1
    pane_curObj = LeftBar_obj
    local tbArgLeft = settings2tbl(_G.iuprops["settings.user.leftbar"] or {}, "tbArgLeft")
    pane_curObj = SideBar_obj
    local tbArgRight = settings2tbl(_G.iuprops["settings.user.rightbar"] or {}, "tbArgRight")

    tabs = SideBar(tbArgLeft, LeftBar_obj, 'leftbar')

    if tabs then
        LeftBar_obj.TabCtrl = tabs

        vbox = iup.vbox{tabs}       --SideBar_Plugins.livesearch.handle,
        LeftBar_obj.handle = SidePane(vbox, 'LeftBarSB','leftbar','SourceSplitLeft', 'LeftBarExpander', '0', LeftBar_obj, 'Left', 'application_sidebar_left_µ' )
    end

    local tabs =  SideBar(tbArgRight, SideBar_obj, 'sidebar')

    if tabs then
        SideBar_obj.TabCtrl = tabs

        vbox = iup.vbox{tabs}
        SideBar_obj.handle = SidePane(vbox, 'SideBarSB','sidebar','SourceSplitRight', 'RightBarExpander', '1000', SideBar_obj, 'Right', 'application_sidebar_right_µ' )
    end

    local tblMenus = {}
    for i = 1,  #tbl_hotkeys do
        local t = {}
        table.insert(t, 'Tab'..i)
        if tbl_hotkeys[i] ~= '' then t.key = tbl_hotkeys[i] end
        t.action = function() sidebar_Switch(i) end
        table.insert(tblMenus, t)
    end

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
        SideBar_Plugins.findrepl = dofile(props["SciteDefaultHome"].."\\tools\\UIPlugins\\FindRepl.lua").sidebar(SideBar_Plugins)
        local hTmp= iup.dialog{SideBar_Plugins.findrepl.handle}
        local hBx = iup.GetDialogChild(hTmp, 'FindReplDetach')
        iup.Detach(hBx)
        iup.Insert(iup.GetDialogChild(hMainLayout, "FindPlaceHolder"), nil, hBx)
        iup.Map(hBx)
        iup.Destroy(hTmp)
        bs2.barsize='5'
        if tonumber(bs2.value) > 980 then bs2.value = 800 end
        iup.GetDialogChild(hMainLayout, "FindPlaceHolder").yautohide = 'NO'
        iup.Refresh(iup.GetDialogChild(hMainLayout, "FindPlaceHolder"))
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
        HANDLE = iup.GetDialogChild(hMainLayout, "ConsoleDetach"); buttonImage='terminal_µ';
        sciteid = 'concolebar';Split_h = bSplitter;Split_CloseVal = "0";
        Dlg_Title = "Console"; Dlg_Show_Cb = nil; MenuEx = "OUTPUT";
        Dlg_Close_Cb = (function(h)
        end);
        Dlg_Show_Cb = (function(h, state)
            if state == 0 and (_G.iuprops['findresbar.win'] or '0')~='0' then
                if (_G.iuprops['findrepl.win'] or '0')=='0' and not SideBar_Plugins.findrepl.Bar_obj then
                    SideBar_Plugins.findrepl.handle_deattach.detachPos(false)
                    _G.iuprops['findrepl.visible.state'] = "0"
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
    if props['session.reload'] ~= '1' and (_G.iuprops['dialogs.coeditor.splithorizontal'] or 0) == 1 then

        local hBx = iup.GetDialogChild(hMainLayout, 'SourceExDetach')
        iup.Reparent(hBx, iup.GetDialogChild(hMainLayout, "CoSourceExpanderBtm"), nil)
        iup.GetDialogChild(hMainLayout, "SourceSplitBtm").barsize = '5'
        CORE.RemapTab(false)
        iup.Refresh(iup.GetDialogChild(hMainLayout, "SourceSplitBtm"))
    end

    CoEditor = iup.scitedetachbox{
        HANDLE = iup.GetDialogChild(hMainLayout, "SourceExDetach"); buttonImage='edit_µ';
        sciteid = 'coeditor';Split_h = bSplitter;Split_CloseVal = "1000";
        Dlg_Title = "Second Editior"; Dlg_Show_Cb = nil; MenuEx = 'EDITOR';
        Dlg_Close_Cb = (function(h)
            if tonumber(_G.iuprops['dialogs.coeditor.splitvalue']) > 980 then _G.iuprops['dialogs.coeditor.splitvalue'] = 900
            elseif tonumber(_G.iuprops['dialogs.coeditor.splitvalue']) < 20 then _G.iuprops['dialogs.coeditor.splitvalue'] = 100 end
        end);
        Dlg_Show_Cb = (function(h, state)
            if state == 0 then CORE.RemapTab(false); iup.Refresh(h)
            elseif state == 4 then scite.RunAsync(Splitter_CB) end
        end);
        Dlg_BeforeAttach = (function(h, state)
            if (_G.iuprops['dialogs.coeditor.splithorizontal'] or 0) == 0 then CORE.RemapTab(true) end
        end);
        MenuVisible = (function() return scite.buffers.SecondEditorActive() == 1 end);
        MenuVisibleEx = (function() return scite.buffers.SecondEditorActive() == 1 and scite.ActiveEditor() == 1 end);
    }
    _G.g_session['coeditor'] = CoEditor

    iup.GetDialogChild(hMainLayout, "SourceSplitMiddle").valuechanged_cb = function(h)
        if h.value == '1000' then
            CoEditor.cmdHide()
        end
    end
    iup.GetDialogChild(hMainLayout, "SourceSplitBtm").valuechanged_cb = function(h)
        if h.value == '1000' then
            CoEditor.cmdHide()
        end
    end


end

local tabSwitch = false
local function InitTabbar()
    local SSL = iup.GetDialogChild(hMainLayout, 'SourceSplitLeft')
    local SSR = iup.GetDialogChild(hMainLayout, 'SourceSplitRight')
    local SSM = iup.GetDialogChild(hMainLayout, 'SourceSplitMiddle')
    local TBS = iup.GetDialogChild(hMainLayout, 'TabBarSplit')
    local Exp = iup.GetDialogChild(hMainLayout, 'CoSourceExpander')
    Splitter_CB = function(h)
        if h then
            if tonumber(SSM.value) > 999 and SSM.barsize ~= '0' then SSM.value = "999"
            elseif tonumber(SSM.value) < 1 then SSM.value = "1" end
        end
        if (_G.iuprops['coeditor.win'] or '0') == '0' and Exp.state == 'OPEN' and ((_G.iuprops['dialogs.coeditor.splithorizontal'] or 0) == 0) then
            TBS.value = ''..math.floor(tonumber(SSL.value) + (tonumber(SSM.value) / 1000) * (tonumber(SSR.value) / 1000) * (1000 - tonumber(SSL.value)))
        end
    end
    local vc_SSL = SSL.valuechanged_cb
    local vc_SSR = SSR.valuechanged_cb
    local vc_SSM = SSM.valuechanged_cb

    SSL.valuechanged_cb = function(h) Splitter_CB(h) if vc_SSL then vc_SSL(h) end end
    SSR.valuechanged_cb = function(h) Splitter_CB(h) if vc_SSR then vc_SSR(h) end end
    SSM.valuechanged_cb = function(h) Splitter_CB(h) if vc_SSM then vc_SSM(h) end end


    local function onButton(h, hNew, button, pressed, x, y, tab, tabDrag, status)
        local ts = false
        if pressed == 1 and tab == tonumber(h.valuepos) then
            if ((h.name == 'TabCtrlLeft') and (scite.ActiveEditor() == 1)) or ((h.name == 'TabCtrlRight') and (scite.ActiveEditor() == 0)) then
                coeditor.Focus = true
            end
        end
        if button == iup.BUTTON1 and pressed == 0 then
            local clr = props['tabctrl.active.bakcolor']
            if clr == '' then clr = '255 255 255' end
            iup.SetAttribute(h, "BGCOLOR", clr)
            h.cursor = 'ARROW'
            iup.Update(h)
            if (tabDrag > -1 and tab == -4) or (hNew and (hNew.name == 'TabCtrlRight' or hNew.name == 'TabCtrlLeft' )) then
                scite.MenuCommand(IDM_CHANGETAB)
            end
        elseif (button == iup.BUTTON1 and iup.isdouble(status)) or (button == iup.BUTTON2 and pressed == 0 ) then
            if tab > - 1 and (tonumber(props['tabbar.tab.close.on.doubleclick']) or 0) == 1 then scite.MenuCommand(IDM_CLOSE)
            elseif tab == -1 then scite.MenuCommand(IDM_NEW) end
        elseif button == iup.BUTTON3 and pressed == 1 and tab >= -1 then
            menuhandler:ContextMenu(iup.MOUSEPOS, iup.MOUSEPOS, 'TABBAR')
        end
        if pressed == 0 then scite.RunAsync(function() iup.PassFocus() end) end
    end

    local function onTabClose(h, tab)
        scite.MenuCommand(IDM_CLOSE)
    end

    local function onMotion(h, hNew, x, y, tab, tabDrag, start, status)
        if start == 2 then
            local clr = props['tabctrl.moved.color']
            if clr == '' then clr = '208 231 255' end
            iup.SetAttribute(h, "BGCOLOR", clr)
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
        --print(h, hNew, x, y, tab, tabDrag, start)
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
        tab.showclose = Iif((tonumber(props['tabbar.tab.close.on.doubleclick']) or 0) == 1, 'NO', 'YES')
        tab.tab_button_cb = onButton
        tab.extraimage1 = "property_µ"
        tab.extrapresscolor1 = iup.GetGlobal("DLGBGCOLOR")
        tab.highcolor = '15 60 195'
        tab.tab_motion_cb = onMotion
        tab.extrabutton_cb = onExButton
        tab.tabclose_cb  = onTabClose
    end

    SetTab(iup.GetDialogChild(hMainLayout, 'TabCtrlLeft'))
    SetTab(iup.GetDialogChild(hMainLayout, 'TabCtrlRight'))
end

function CORE.RemapTab(bIsH)
    local tab = iup.GetDialogChild(hMainLayout, 'RightTabExpander')
    local splitT = iup.GetDialogChild(hMainLayout, "TabBarSplit")
    local bIsHNow = (iup.GetParent(tab).name == 'coeditor_vbox')
    --print(iup.GetParent(tab).name, iup.GetParent(tab).name == 'TabBarSplit', bIsH)
    if (bIsH and bIsHNow) or (not bIsH and not bIsHNow) then
        if bIsH then
            iup.Reparent(tab, splitT, nil)
            scite.RunAsync(Splitter_CB)
            --iup.Reparent(tab, iup.GetDialogChild(hMainLayout, "RightTabExpander"), nil)
        else
            iup.Reparent(tab, iup.GetDialogChild(hMainLayout, "coeditor_vbox"), iup.GetDialogChild(hMainLayout, 'CoSource'))
            tab.state = "OPEN"
            splitT.value = '1000'
        end
    end
end

function CORE.RemapCoeditor()
    local bIsH = (iup.GetChild(iup.GetDialogChild(iup.GetLayout(), 'CoSourceExpanderBtm'), 1) ~= nil)
    local hBx = iup.GetDialogChild(hMainLayout, 'SourceExDetach')
    local hPrOld = iup.GetDialogChild(hMainLayout, Iif(bIsH, "SourceSplitBtm", "SourceSplitMiddle"))
    local hPr = iup.GetDialogChild(hMainLayout, Iif(bIsH, "SourceSplitMiddle", "SourceSplitBtm"))
    hPr.value = hPrOld.value
    hPr.barsize = '5'

    iup.Reparent(hBx, iup.GetDialogChild(hMainLayout, Iif(bIsH, "CoSourceExpander", "CoSourceExpanderBtm")), nil)

    CORE.RemapTab(bIsH)

    hPrOld.barsize = '0'
    hPrOld.value = '1000'

    iup.Refresh(iup.GetDialogChild(hMainLayout, "SourceSplitBtm"))
    _G.iuprops['dialogs.coeditor.splithorizontal'] = Iif(bIsH, 0, 1)

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

require "menuhandler"
local function InitMenuBar()
    menuhandler:Init()
    if not _G.sys_Menus then return end
    local vbScite = iup.GetDialogChild(hMainLayout, "SciteVB")
    MenuBar_obj = {}
    MenuBar_obj.Tabs = {}

    local mnu = sys_Menus.MainWindowMenu

    local hb = { alignment = 'ACENTER', expand = 'HORIZONTAL', name = 'Hildim_MenuBar'}
    for i = 1, #mnu do
        if mnu[i][1] ~='_HIDDEN_' then
            table.insert(hb,menuhandler:GreateMenuLabel(mnu[i]))
            if i == #mnu - 1 then table.insert(hb,iup.fill{name = 'menu_fill'})
            elseif i < #mnu - 1 then table.insert(hb, iup.label{separator = "VERTICAL",maxsize='x18'}) end
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
    iup.SetAttributeId2(sb, "COLORID", 1, MARKER_NOTSAVED, Iif(props["marker.notsaved.back"]~= '', CORE.Rgb2Str(props["marker.notsaved.back"]), '255 112 112', 0))
    iup.SetAttributeId2(sb, "COLORID", 1, MARKER_SAVED, Iif(props["marker.saved.back"]~= '', CORE.Rgb2Str(props["marker.saved.back"]), '112 255 112', 0))
end

resetSBColors(iup.GetDialogChild(iup.GetLayout(), 'Source'))
resetSBColors(iup.GetDialogChild(iup.GetLayout(), 'CoSource'))

InitMenuBar()
--Автозагрузка скрытых плагинов
local tbl = _G.iuprops["settings.hidden.plugins"] or {}
local strTbl = 'return function(h) return iup.expander{barsize = 0, state="OPEN", name = "toolbar_expander", iup.vbox{gap="1", iup.hbox{\n'
local i = 0
for i = 1, #tbl do
    local p = tbl[i]
    local bSucs, pI = pcall(dofile, props["SciteDefaultHome"].."\\tools\\UIPlugins\\"..p)
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
    local bSucs, pI = pcall(dofile, props["SciteDefaultHome"].."\\tools\\Commands\\"..p)
    if not bSucs then
        print(pI)
        goto continue
    end
    if pI and pI.run then
        local t = {}
        t[1] = pI.title
        t.visible = pI.visible
        if pI.key then t.key = pI.key end
        t.action = function() dofile(props["SciteDefaultHome"].."\\tools\\Commands\\"..p).run() end

        menuhandler:InsertItem('MainWindowMenu', pI.path or 'Tools|xxx', t)
    end
::continue::
end

InitSideBar()
InitTabbar()
InitToolBar()
InitStatusBar()
RestoreNamedValues(hMainLayout, 'sidebarctrl')
RestoreNamedValues(hMainLayout, 'findreplace')
iup.Refresh(hMainLayout)
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

try{
    function() dofile(props["SciteDefaultHome"]..'\\tools\\BuffersList.lua') end,
    catch{
        print
    }
}

menuhandler:DoPostponedInsert()

local bMenu,bToolBar,bStatusBar
local bSideBar,bLeftBar,bconsoleBar,bFindResBar,bFindRepl

AddEventHandler("OnSwitchFile", function(file)
    if scite.ActiveEditor() == 1 then
        if (_G.iuprops['coeditor.win'] or '0') == '2' and scite.buffers.SecondEditorActive() == 1 then CoEditor.Switch();
        elseif (_G.iuprops['coeditor.win'] or '0') == '1' then  local b = iup.GetDialogChild(CoEditor, "Title"); b.title = props['FileNameExt']:from_utf8(); iup.Redraw(b, 1) end
    end
end)

AddEventHandler("OnRightEditorVisibility", function(show)
    if (show == 0 and ((_G.iuprops['coeditor.win'] or '0') ~= '2')) or
      (show == 1 and ((_G.iuprops['coeditor.win'] or '0') == '2')) then
        CoEditor.Switch()
        local expand = iup.GetDialogChild(hMainLayout, "RightTabExpander")
        local split = iup.GetDialogChild(hMainLayout, "TabBarSplit")
        if show == 1 then
            editor.Zoom = coeditor.Zoom
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
        if (_G.iuprops['concolebar.win'] or '0')=='1' or (_G.iuprops['concolebar.autoshow'] or 0) == 0 then return end
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
            if (_G.iuprops['findresbar.win'] or '0') == '1' then FindResBar.Switch()
            else iup.PassFocus() end
        end
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
    if not editor.Modify or (iup.Alarm('Перезагрузка файла', 'Изменения не сохранены.\nПродолжить?', 'Да', 'Нет') == 1) then
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
    if cp ~= codepage then
        if not editor.Modify or (iup.Alarm('Перезагрузка файла', 'Изменения не сохранены.\nПродолжить?', 'Да', 'Нет') == 1) then
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
