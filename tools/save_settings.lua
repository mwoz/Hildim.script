--[[--------------------------------------------------
 Save SciTE Settings
 Version: 1.7.3
 Author: mozers™, Dmitry Maslov
---------------------------------------------------
 Save current settings on SciTE close.
 Сохраняет текущие установки при закрытии SciTE (в файле SciTE.session)
---------------------------------------------------
Connection:
In file SciTEStartup.lua add a line:
  dofile (props["SciteDefaultHome"].."\\tools\\save_settings.lua")
Set in a file .properties:
  save.settings=1
  import home\SciTE.session
--]]----------------------------------------------------

local text = ''
-- установить в text текущее значение проперти key
local function SaveKey(key)
	local value = props[key]
    local keyR = key:gsub('%.','%%.')
    local regex = '([^%w.]'..key..'=)[^\n]*'
    if text:find(regex) == nil then
        text = text..'\n'..key..'='..value
        return
    end
    text = text:gsub(regex, "%1"..value)
	return
end

local function SaveSettings()
    local vs = output.LinesOnScreen*output:TextHeight(1)
    if vs < 200 then vs = 200 end
    props['output.vertical.size']=vs
	local file = props["scite.userhome"]..'\\SciTEEx.session'
    text = ''
	if pcall(io.input, file) then
        text = io.read('*a')
    end
	SaveKey('autoformat.line') -- Автоформатирование в лексере формэнджина
	SaveKey('find.directory')
	SaveKey('find.directory.history')
	SaveKey('find.files.history')
	SaveKey('find.in.subfolders')
	SaveKey('find.what')
	SaveKey('find.what.history')
	SaveKey('find.replasewith.history')
	SaveKey('findtext.bookmarks')
	SaveKey('findtext.matchcase')
	SaveKey('findtext.wholeword')
	SaveKey('highlighting.identical.text') -- параметр изменяется в highlighting_identical_text.lua
	SaveKey('line.margin.visible')
	SaveKey('magnification') -- параметр изменяется в Zoom.lua

    SaveKey('mbTrancport.file')
	SaveKey('output.magnification') -- параметр изменяется в Zoom.lua
	SaveKey('output.vertical.size')
	SaveKey('output.wrap')
	SaveKey('precompiller.debugmode') -- включение дебагмоды радиуса
	SaveKey('precompiller.radiususername') -- имя пользователя радиус
	SaveKey('print.magnification') -- параметр изменяется в Zoom.lua
	SaveKey('sidebar.abbrevbmk.split.value')
	SaveKey('sidebar.tabctrl.value')
	SaveKey('sidebar.funcnav.split.value')
	SaveKey('sidebar.fileman.split.value')
	SaveKey('sidebar.functions.group')
	SaveKey('sidebar.functions.sort')
	SaveKey('sidebar.functions.layout')
	SaveKey('sidebar.fileman.split.value')

	SaveKey('sidebar.hide') -- параметр изменяется в SideBar.lua
	SaveKey('sidebar.pan') -- параметр изменяется в SideBar.lua
	SaveKey('sidebar.win') -- параметр изменяется в SideBar.lua
	SaveKey('dialogs.sidebarp.rastersize')
	SaveKey('dialogs.sidebar.rastersize')
	SaveKey('dialogs.sidebar.x')
	SaveKey('dialogs.sidebar.y')

    SaveKey('sidebar.mb.transport.value')
	SaveKey('sidebar.mb.subject.value')
	SaveKey('sidebar.m4.value')

	SaveKey('spell.autospell')
	SaveKey('split.vertical')
	SaveKey('sql.compile.file')  --имя выделенного файла для компиляции
	SaveKey('sql.dbcmdsubj')  --выделенный дбСабджект

    SaveKey('statusbar.visible')
	SaveKey('tabbar.visible')
	SaveKey('iuptoolbar.visible')
    SaveKey('toolbar.visible')
	SaveKey('view.eol')
	SaveKey('view.indentation.guides')
	SaveKey('view.whitespace')
	SaveKey('wrap')
	SaveKey('sqlobject.mapreloadtime')

	if pcall(io.output, file) then
		io.write(text)
 	end
	io.close()
end

local function ToggleProp(prop_name)
	local prop_value = tonumber(props[prop_name])
	if prop_value==0 then
		props[prop_name] = '1'
	elseif prop_value==1 then
		props[prop_name] = '0'
	end
end

-- Добавляем свой обработчик события OnMenuCommand
-- При изменении параметров через меню, меняются и соответствующие значения props[]
AddEventHandler("OnMenuCommand", function(cmd, source)

    if cmd == IDM_VIEWTOOLBAR then
		ToggleProp('toolbar.visible')
	elseif cmd == IDM_VIEWTABBAR then
		ToggleProp('tabbar.visible')
	elseif cmd == IDM_VIEWSTATUSBAR then
		ToggleProp('statusbar.visible')
	elseif cmd == IDM_VIEWSPACE then
		ToggleProp('view.whitespace')
	elseif cmd == IDM_VIEWEOL then
		ToggleProp('view.eol')
	elseif cmd == IDM_VIEWGUIDES then
		ToggleProp('view.indentation.guides')
	elseif cmd == IDM_LINENUMBERMARGIN then
		ToggleProp('line.margin.visible')
	elseif cmd == IDM_SPLITVERTICAL then
		ToggleProp('split.vertical')
	elseif cmd == IDM_WRAP then
		ToggleProp('wrap')
	elseif cmd == IDM_WRAPOUTPUT then
		ToggleProp('output.wrap')
	elseif cmd == IDM_QUIT and tonumber(props['save.settings']) == 1 then
		SaveSettings()  --Поскольку закрытие окна мы в любом случае выполняем  через IDM_QUIT
	end
end)

