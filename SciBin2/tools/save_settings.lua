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
--[[    local vs = output.LinesOnScreen*output:TextHeight(1)
    if vs < 200 then vs = 200 end
    props['output.vertical.size']=vs]]
	local file = props["scite.userhome"]..'\\SciTEEx.session'
    text = ''
	if pcall(io.input, file) then
        text = io.read('*a')
    end
	SaveKey('autoformat.line') -- Автоформатирование в лексере формэнджина


	SaveKey('spell.autospell')
	SaveKey('pariedtag.on')


	if pcall(io.output, file) then
		io.write(text)
 	end
	io.close()
end

local function ToggleProp(prop_name)
    if props[prop_name] == '' then props[prop_name] = '0' end
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

if cmd == IDM_QUIT and tonumber(props['save.settings']) == 1 then
		SaveSettings()  --Поскольку закрытие окна мы в любом случае выполняем  через IDM_QUIT
        --SaveIup()
	end
end)

