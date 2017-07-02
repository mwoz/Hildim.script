-- Этот файл стартует при загрузке SciTE
-- Чтобы не забивать его его огромным количеством используемых скриптов, поскольку это затрудняет работу редактора, большинство из них хранятся в обособленных файлах и грузятся только при выборе соответствующего пункта меню Tools.
-- Здесь (с помощью dofile) грузятся только скрипты, обрабатывающие события редактора.

----[[ C O M M O N ]]-------------------------------------------------------
--Загрузка имэджей

if props['script.started'] ~= 'Y' then
    iup.Load(props["SciteDefaultHome"].."\\tools\\Images.led")
    dofile (props["SciteDefaultHome"].."\\tools\\Images.lua")
end

_G.onDestroy_event = {}
dofile (props["SciteDefaultHome"].."\\tools\\COMMON.lua")
Splash_Screen()
dofile (props["SciteDefaultHome"].."\\tools\\Menus.lua")

-- SideBar: Многофункциональная боковая панель
dofile (props["SciteDefaultHome"].."\\tools\\IupSideBar.lua")

-- Установка размера символа табуляции в окне консоли
local tab_width = tonumber(props['output.tabsize'])
if tab_width ~= nil then
	output.TabWidth = tab_width
end

--local prn_ol = print
--print = function() подмена print для отлова дебажного вывода
--    prn_ol(debug.traceback())
--end

scite.RunAsync(function()
    props['session.reload'] = _G.iuprops['session.reload']
    iup.RestoreFiles()
    local hMainLayout = iup.GetLayout()
    if navigation_Unblock then navigation_Unblock() end
    local bHide
    if ((_G.iuprops['sidebar.win'] or '0')~= '0') and SideBar_obj.handle then bHide = (_G.iuprops['sidebar.win'] == '2');    SideBar_obj.handle.detachPos(not bHide) end --[[;RestoreNamedValues(SideBar_obj.handle, 'sidebarctrl')]]
    if ((_G.iuprops['leftbar.win'] or '0')~= '0') and LeftBar_obj.handle then bHide = (_G.iuprops['leftbar.win'] == '2');    LeftBar_obj.handle.detachPos(not bHide) end --[[;RestoreNamedValues(LeftBar_obj.handle, 'sidebarctrl')]]
    if (_G.iuprops['concolebar.win'] or '0')~= '0' then bHide = (_G.iuprops['concolebar.win'] == '2'); iup.GetDialogChild(hMainLayout, "ConsoleDetach").detachPos(not bHide) end
    if (_G.iuprops['findresbar.win'] or '0')~= '0' then bHide = (_G.iuprops['findresbar.win'] == '2'); iup.GetDialogChild(hMainLayout, "FindResDetach").detachPos(not bHide) end
    if (_G.iuprops['findrepl.win'] or '0')~= '0' then bHide = (_G.iuprops['findrepl.win'] == '2'); local h = iup.GetDialogChild(hMainLayout, "FindReplDetach"); h.detachPos(not bHide) end
    if (_G.iuprops['coeditor.win'] or '0')~= '0' then bHide = (_G.iuprops['coeditor.win'] == '2'); local h = iup.GetDialogChild(hMainLayout, "SourceExDetach"); h.detachPos(not bHide) end

    if _G.dialogs['findresbar'] and _G.dialogs['concolebar'] then
        iup.GetDialogChild(hMainLayout, "BottomExpander").state = 'CLOSE'
        iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize = '0'
        iup.GetDialogChild(hMainLayout, "BottomBarSplit").value = '1000'
    end

    menuhandler:RegistryHotKeys()

    local frScroll = iup.GetDialogChild(iup.GetLayout(), "FinReplScroll")

    scite.EnsureVisible()
    hMainLayout.resize_cb()
    if OnResizeSideBar then OnResizeSideBar('sidebar') end
    if OnResizeSideBar then OnResizeSideBar('leftbar') end
    if dlg_SPLASH then
        scite.RunAsync(function()
            if dlg_SPLASH then dlg_SPLASH:hide(); dlg_SPLASH:destroy(); dlg_SPLASH = nil; end
            if _G.iuprops['command.reloadprops'] then
                _G.iuprops['command.reloadprops'] = false;
                scite.RunAsync(function() scite.Perform("reloadproperties:") end)
            end
        end)
    end
    props['session.started'] = '1'
    if (_G.iuprops['dialogs.coeditor.splithorizontal'] or 0) == 0 then
        iup.GetDialogChild(hMainLayout, "SourceSplitBtm").value = '1000'

    else
        iup.GetDialogChild(hMainLayout, "SourceSplitMiddle").value = '1000'
    end
end)
