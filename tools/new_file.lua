--[[--------------------------------------------------
new_file.lua
mozers™, VladVRO
version 3.3.0
----------------------------------------------
Заменяет стандартную команду SciTE "File|New" (Ctrl+N)
Создает новый буфер в текущем каталоге с расширением текущего файла
Благодаря этому, сразу же включаются все фичи лексера (подсветка, подсказки и пр.)
----------------------------------------------
Подключение:
В файл SciTEStartup.lua добавьте строку:
  dofile (props["SciteDefaultHome"].."\\tools\\new_file.lua")

Задайте в файле .properties расширения файлов которые будут создаваться в кодировке UTF-8
  file.make.as.utf8=htm,html

-------------------------------------------------------------------
Replaces SciTE command "File|New" (Ctrl+N)
Creates new buffer in the current folder with current file extension
----------------------------------------------
Connection:
In file SciTEStartup.lua add a line:
  dofile (props["SciteDefaultHome"].."\\tools\\new_file.lua")

Set in a file .properties:
  file.make.as.utf8=htm,html

--]]----------------------------------------------------
require 'shell'

local unsaved_files = {}

-- Определяет надо ли файл с текущим расширением создавать и сохранять в UTF-8
local function isMakeUTF8()
	local create_utf8_ext = props['file.make.as.utf8']:lower()
	local current_ext = props['FileExt']:lower()
	for ext in create_utf8_ext:gmatch("%w+") do
		if current_ext == ext then return true end
	end
	return false
end

-- Создает новый буфер в текущем каталоге с расширением текущего файла
local function CreateUntitledFile()
	local file_ext = "."..props["FileExt"]
	if file_ext == "." then file_ext = props["default.file.ext"] end
    local unicode_mode = props['editor.unicode.mode']
    local fName1 = props['scite.new.file']
    local bPreset = false
    if fName1 == '' then
        fName1 = scite.GetTranslation("Untitled"):to_utf8()
    elseif fName1:find('(.*)(%.[^.]*)$') then
        bPreset = true
        _, _, fName1, file_ext = fName1:find('(.*)(%.[^.]*)$')
    end

    local unNum = 0
    local maxN = scite.buffers.GetCount() - 1
    local bNew
    local fName
    repeat
        fName = fName1..Iif(unNum>0, unNum, '')
        unNum = unNum + 1
        bNew = true
        for i = 0, maxN do
            local _, _, sN = scite.buffers.NameAt(i):from_utf8():find('([^\\]*)$')
            if sN:gsub('%.[^%.]*$', '') == fName:from_utf8() then
                if bPreset then
                    scite.Open(scite.buffers.NameAt(i):from_utf8())
                    return true
                end
                bNew = false
                break
            end
        end
        fName = fName..file_ext
    until bNew and not shell.fileexists(props["FileDir"].."\\".. fName:from_utf8())

	props['scite.new.file'] = ''

    local file_path = props["FileDir"].."\\".. fName
    props['warning.couldnotopenfile.disable'] = 1
    scite.Open(file_path)
    if isMakeUTF8() then scite.MenuCommand(IDM_ENCODING_UCOOKIE) end
    unsaved_files[file_path:upper()] = true --сохраняем путь к созданному буферу в таблице
    props['warning.couldnotopenfile.disable'] = 0
    scite.MenuCommand(unicode_mode)
    scite.RunAsync(function() editor.Focus = true  end)
    return true
end
local scipped, bscip
AddEventHandler("OnMenuCommand", function(msg, source)
	bscip = false
    if msg == IDM_NEW then
		return CreateUntitledFile()
    elseif msg == IDM_SAVE then
        if props["FileNameExt"]:find'^%^' and not shell.fileexists(props["FilePath"]:from_utf8()) then
            scite.MenuCommand(IDM_SAVEAS)
            return true
        end
    elseif msg == IDM_SAVEAS then
        bscip = true
    else
    end
end)

-- Новый буфер, созданный функцией CreateUntitledFile имеет полное имя, поэтому при сохранении SciTE будет сохранять его молча по заданному пути (без вывода диалогового окна "SaveAs")
-- Обработчик события OnBeforeSave при сохранении такого буфера выводит диалоговое окно "SaveAs"

AddEventHandler("OnBeforeSave", function(file)
	if isMakeUTF8() and tonumber(props["editor.unicode.mode"]) == IDM_ENCODING_DEFAULT then
		editor.TargetStart = 0
		editor.TargetEnd = editor.Length
		local txt_in = editor:GetText()
		editor:ReplaceTarget(shell.to_utf8(txt_in))
		scite.MenuCommand(IDM_ENCODING_UCOOKIE)
	end
	-- if unsaved_files[file:upper()] then -- если это созданный нами несохраненный буфер
	if not shell.fileexists(props["FilePath"]:from_utf8()) and scipped ~= props["FilePath"]:from_utf8() and not bscip then -- если это созданный нами несохраненный буфер
        scipped = props["FilePath"]:from_utf8()
        scite.MenuCommand(IDM_SAVEAS)
        scipped = nil
		return true
	end
    bscip = false
end)

AddEventHandler("OnSave", function(file)
	unsaved_files[file:upper()] = nil --удаляем запись о буфере из таблицы
end)
