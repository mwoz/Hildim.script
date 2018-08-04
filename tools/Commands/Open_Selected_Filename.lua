--[[--------------------------------------------------
Open_Selected_Filename.lua
Authors: mozers™, VladVRO
Version: 1.3.0
------------------------------------------------------
Замена команды "Открыть выделенный файл"
В отличии от встроенной команды SciTE, понимающей только явно заданный путь и относительные пути
обрабатывает переменные SciTE, переменные окружения, конструкции LUA
-------------------------------------
Подключение:
Добавьте в SciTEStartup.lua строку
dofile (props["SciteDefaultHome"].."\\tools\\Open_Selected_Filename.lua")
-------------------------------------
Connection:
In file SciTEStartup.lua add a line:
dofile (props["SciteDefaultHome"].."\\tools\\Open_Selected_Filename.lua")
--]]--------------------------------------------------
require 'shell'
------------------------------------------------------
local function OpenSelectedFilename()
    local function GetOpenFilePath(text)
        -- Example: $(SciteDefaultHome)\tools\RestoreRecent.js
        local pattern_sci = '^$[(](.-)[)]'
        local _, _, scite_var = string.find(text, pattern_sci)
        if scite_var ~= nil then
            return string.gsub(text, pattern_sci, props[scite_var])
        end

        -- Example: %APPDATA%\Opera\Opera\profile\opera6.ini
        local pattern_env = '^[%%](.-)[%%]'
        local _, _, os_env = string.find(text, pattern_env)
        if os_env ~= nil then
            return string.gsub(text, pattern_env, os.getenv(os_env))
        end

        -- Example: props["SciteDefaultHome"].."\\tools\\Zoom.lua"
        local pattern_props = '^props%[%p(.-)%p%]%.%.%p(.*)%p'
        local _, _, scite_prop1, scite_prop2 = string.find(text, pattern_props)
        if scite_prop1 ~= nil then
            return props[scite_prop1]..scite_prop2
        end
        -- Example: props["SciteDefaultHome"].."\\tools\\ascii.lua"   f:\Program Files (x86)\HildiM\api\csstags.api
        local pattern_full = '^[A-Za-z]:'
        if string.find(text, pattern_full) then
            return text
        end
        return props['FileDir']..'\\'..text
    end

    local function GetSelText()
        local text
        if findres.Focus then
            text = findres:GetSelText()
        elseif output.Focus then
            text = output:GetSelText()
        else
            text = editor:GetSelText()
        end
        if tonumber(props["editor.unicode.mode"]) == IDM_ENCODING_DEFAULT then
            return text
        else
            return text:from_utf8()
        end
    end

	local text = GetSelText()
	if #text < 5 then return end
	local filename = GetOpenFilePath(text)
	if filename == nil then return end
	filename = string.gsub(filename, '\\\\', '\\')
    if not shell.fileexists(filename) then print('Файл не найден: '..filename); return end
	scite.Open (filename:to_utf8())
	return true
end

return {
    title = _T'Open Selected Filename',
    run = OpenSelectedFilename,
    path = 'File|Reopen File',
    description = [[Обрабатывает явно заданный путь и относительные пути
переменные SciTE, переменные окружения, конструкции LUA]]
}
