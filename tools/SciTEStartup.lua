-- Этот файл стартует при загрузке SciTE
-- Чтобы не забивать его его огромным количеством используемых скриптов, поскольку это затрудняет работу редактора, большинство из них хранятся в обособленных файлах и грузятся только при выборе соответствующего пункта меню Tools.
-- Здесь (с помощью dofile) грузятся только скрипты, обрабатывающие события редактора.

----[[ C O M M O N ]]-------------------------------------------------------

_G.g_session = {}
local reloaded_config
while props['hildim.command.line']:find('^ *[-/]%w+') do
    local _, l, s, cl = props['hildim.command.line']:find('^ *[-/](%w+)(.*)')
    if s == 'cmd' then
        break
    elseif s == 'nP' then
        _G.g_session['scip.plugins'] = true
    elseif s == 'h' then
        _G.g_session['scip.show'] = true
    elseif s == 'nRF' then
        _G.g_session['scip.restore.files'] = true
    elseif s == 'nSes' then
        _G.g_session['scip.save.session'] = true
    elseif s == 'nSet' then
        _G.g_session['scip.save.settings'] = true
    elseif s == 'props' then
        _, _, cl = cl:find'^="[^"]+"(.*)'
    elseif s == 'config' then
        _, _, props['config.restore'], cl = cl:find'^="([^"]+)"(.*)'
        reloaded_config = props['config.restore']:gsub('^(.-)_?([^\\]-%.[^\\.]+)$', '%1%2')
    end
    props['hildim.command.line'] = cl
end
props['hildim.command.line'] = props['hildim.command.line']:gsub('^ +', '')

--Загрузка имэджей
if props['script.started'] ~= 'Y' then
    --iup.Load(props["SciteDefaultHome"].."\\tools\\Images.led")
    dofile (props["SciteDefaultHome"].."\\tools\\Images.lua")
end

dofile (props["SciteDefaultHome"].."\\tools\\COMMON.lua")

--Расширения, загружаемые в любом случае
require"lpeg"

if not _G.g_session['scip.plugins'] then
    require "menuhandler"
    dofile (props["SciteDefaultHome"].."\\tools\\xComment.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\new_file.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\AutocompleteObject.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\defAutoformat.lua")
    dofile (props["SciteDefaultHome"].."\\tools\\FindTextOnSel.lua")

    Splash_Screen()
    if reloaded_config then _G.iuprops['current.config.restore'] = reloaded_config end
    dofile (props["SciteDefaultHome"].."\\tools\\Menus.lua")

-- SideBar: Многофункциональная боковая панель
    dofile (props["SciteDefaultHome"].."\\tools\\IupSideBar.lua")
end
-- Установка размера символа табуляции в окне консоли
local tab_width = tonumber(props['output.tabsize'])
if tab_width ~= nil then
	output.TabWidth = tab_width
end


scite.RunAsync(function()
    props['session.reload'] = _G.iuprops['session.reload']

    iup.RestoreFiles()
    if not _G.g_session['scip.plugins'] then
        local hMainLayout = iup.GetLayout()
        if navigation_Unblock then navigation_Unblock() end
        local bHide
        if ((_G.iuprops['sidebar.win'] or '0')~= '0') and SideBar_obj.handle then bHide = (_G.iuprops['sidebar.win'] == '2');    SideBar_obj.handle.detachPos(not bHide) end --[[;RestoreNamedValues(SideBar_obj.handle, 'sidebarctrl')]]
        if ((_G.iuprops['leftbar.win'] or '0')~= '0') and LeftBar_obj.handle then bHide = (_G.iuprops['leftbar.win'] == '2');    LeftBar_obj.handle.detachPos(not bHide) end --[[;RestoreNamedValues(LeftBar_obj.handle, 'sidebarctrl')]]
        if (_G.iuprops['concolebar.win'] or '0')~= '0' then bHide = (_G.iuprops['concolebar.win'] == '2'); iup.GetDialogChild(hMainLayout, "ConsoleDetach").detachPos(not bHide) end
        if (_G.iuprops['findresbar.win'] or '0')~= '0' then bHide = (_G.iuprops['findresbar.win'] == '2'); iup.GetDialogChild(hMainLayout, "FindResDetach").detachPos(not bHide) end
        if (_G.iuprops['findrepl.win'] or '0')~= '0' then bHide = (_G.iuprops['findrepl.win'] == '2'); local h = iup.GetDialogChild(hMainLayout, "FindReplDetach"); h.detachPos(not bHide) end
        if (_G.iuprops['coeditor.win'] or '0')~= '0' then bHide = (_G.iuprops['coeditor.win'] == '2'); local h = iup.GetDialogChild(hMainLayout, "SourceExDetach"); h.detachPos(not bHide) end

        if (_G.iuprops['findresbar.win'] or '0') == '0' and _G.iuprops['concolebar.win'] or '0' == '0' then iup.GetDialogChild(hMainLayout, "BottomSplit").barsize = '5' end
        if (_G.iuprops['findresbar.win'] or '0') == '0' and _G.iuprops['findrepl.win'] or '0' == '0' then iup.GetDialogChild(hMainLayout, "BottomSplit2").barsize = '5' end

        if _G.dialogs['findresbar'] and _G.dialogs['concolebar'] then
            iup.GetDialogChild(hMainLayout, "BottomExpander").state = 'CLOSE'
            iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize = '0'
            iup.GetDialogChild(hMainLayout, "BottomBarSplit").value = '1000'
        end

        menuhandler:RegistryHotKeys()

        local frScroll = iup.GetDialogChild(iup.GetLayout(), "FinReplScroll")

        hMainLayout.resize_cb()
        if OnResizeSideBar then scite.RunAsync(function() OnResizeSideBar('sidebar') end) end
        if OnResizeSideBar then scite.RunAsync(function() OnResizeSideBar('leftbar') end) end
        if dlg_SPLASH then
            scite.RunAsync(function()
                if props['script.installed'] == 'Y' then
                    props['script.installed'] = ''
                    scite.RunAsync(function() scite.MenuCommand(IDM_REBOOT) end)
                    return
                else
                    scite.RunAsync(function() if dlg_SPLASH then dlg_SPLASH:hide(); dlg_SPLASH:destroy(); dlg_SPLASH = nil; end end)
                    if _G.iuprops['command.reloadprops'] then
                        _G.iuprops['command.reloadprops'] = false;
                        scite.RunAsync(function() scite.ReloadProperties() end)
                    end
                    if props['hildim.command.line'] ~= '' then
                        scite.RunAsync(function() OnCommandLine(props['hildim.command.line']); props['hildim.command.line'] = '' end)
                    end
                end
            end)
        end
        props['session.started'] = '1'

        if (_G.iuprops['dialogs.coeditor.splithorizontal'] or 0) == 0 then
            iup.GetDialogChild(hMainLayout, "SourceSplitBtm").value = '1000'
            if iup.GetDialogChild(hMainLayout, 'CoSourceExpanderBtm').state == 'OPEN' and props["tab.oldstile"] == '' then
                iup.GetDialogChild(hMainLayout, "TabBarSplit").value = Iif((_G.iuprops['coeditor.win'] or '0') == '0', '500', '1000')
                iup.GetDialogChild(hMainLayout, 'RightTabExpander').state = 'OPEN'
                iup.GetDialogChild(hMainLayout, "SourceSplitMiddle").barsize = Iif((_G.iuprops['coeditor.win'] or '0') == '0', '5', '0')
            end
        else
            iup.GetDialogChild(hMainLayout, "SourceSplitMiddle").value = '1000'
            iup.GetDialogChild(hMainLayout, "TabBarSplit").value = '1000'
        end
    end
    if not dlg_SPLASH and props['hildim.command.line'] ~= '' then
        scite.RunAsync(function() OnCommandLine(props['hildim.command.line']); props['hildim.command.line'] = '' end)
    end
    if not _G.g_session['scip.show'] then
        scite.EnsureVisible()
        iup.Refresh(iup.GetLayout())
    end
    if OnInitHildiM then OnInitHildiM() end
    _G.g_session['LOADED'] = true
end)
