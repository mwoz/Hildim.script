-- Этот файл стартует при загрузке SciTE
-- Чтобы не забивать его его огромным количеством используемых скриптов, поскольку это затрудняет работу редактора, большинство из них хранятся в обособленных файлах и грузятся только при выборе соответствующего пункта меню Tools.
-- Здесь (с помощью dofile) грузятся только скрипты, обрабатывающие события редактора.

----[[ C O M M O N ]]-------------------------------------------------------
--Загрузка имэджей

if props['script.started'] ~= 'Y' then
    iup.Load(props["SciteDefaultHome"].."\\tools\\Images.led")
    dofile (props["SciteDefaultHome"].."\\tools\\Images.lua")
end
--iup.Load(props["SciteDefaultHome"].."\\tools\\Images22.led")
-- Подключение файла с общими функциями, использующимися во многих скриптах
_G.onDestroy_event = {}
dofile (props["SciteDefaultHome"].."\\tools\\COMMON.lua")
Splash_Screen()
dofile (props["SciteDefaultHome"].."\\tools\\Menus.lua")
----[[ R E A D   O N L Y ]]-------------------------------------------------


dofile (props["SciteDefaultHome"].."\\tools\\precompiller.lua")

dofile (props["SciteDefaultHome"].."\\tools\\sqlObjects.lua")

-- SideBar: Многофункциональная боковая панель
dofile (props["SciteDefaultHome"].."\\tools\\IupSideBar.lua")

-- Установка размера символа табуляции в окне консоли
local tab_width = tonumber(props['output.tabsize'])
if tab_width ~= nil then
	scite.SendOutput(SCI_SETTABWIDTH, tab_width)
end

scite.PostCommand(POST_CONTINUESTARTUP,0)
