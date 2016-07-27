--[[--------------------------------------------------
new_file.lua
mozers�, VladVRO
version 3.3.0
----------------------------------------------
�������� ����������� ������� SciTE "File|New" (Ctrl+N)
������� ����� ����� � ������� �������� � ����������� �������� �����
��������� �����, ����� �� ���������� ��� ���� ������� (���������, ��������� � ��.)
----------------------------------------------
�����������:
� ���� SciTEStartup.lua �������� ������:
  dofile (props["SciteDefaultHome"].."\\tools\\new_file.lua")

������� � ����� .properties ���������� ������ ������� ����� ����������� � ��������� UTF-8
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

props["untitled.file.number"] = 0
local unsaved_files = {}

-- ���������� ���� �� ���� � ������� ����������� ��������� � ��������� � UTF-8
local function isMakeUTF8()
	local create_utf8_ext = props['file.make.as.utf8']:lower()
	local current_ext = props['FileExt']:lower()
	for ext in create_utf8_ext:gmatch("%w+") do
		if current_ext == ext then return true end
	end
	return false
end

-- ������� ����� ����� � ������� �������� � ����������� �������� �����
local function CreateUntitledFile()
	local file_ext = "."..props["FileExt"]
	if file_ext == "." then file_ext = props["default.file.ext"] end
    local fName = props['scite.new.file']
    if fName == '' then
        local unNum = 0 --tonumber(props["untitled.file.number"])
        local maxN = scite.buffers.GetCount() - 1
        local bNew
        repeat
            fName = scite.GetTranslation("Untitled"):to_utf8(1251)..unNum
            unNum = unNum + 1
            bNew = true
            for i = 1, maxN do
                local _, _, sN = scite.buffers.NameAt(1):from_utf8(1251):find('([^\\]*)$')
                if sN:gsub('%.[^%.]*$', '') == fName:from_utf8(1251) then
                    bNew = false
                    break
                end
            end
            fName = fName..file_ext
        until bNew and not shell.fileexists(props["FileDir"].."\\".. fName:from_utf8(1251))
        props["untitled.file.number"] = unNum
    end
	props['scite.new.file'] = ''
    local file_path = props["FileDir"].."\\".. fName
    local warning_couldnotopenfile_disable = props['warning.couldnotopenfile.disable']
    props['warning.couldnotopenfile.disable'] = 1
    scite.Open(file_path)
    if isMakeUTF8() then scite.MenuCommand(IDM_ENCODING_UCOOKIE) end
    unsaved_files[file_path:upper()] = true --��������� ���� � ���������� ������ � �������
    props['warning.couldnotopenfile.disable'] = warning_couldnotopenfile_disable
    return true
end

AddEventHandler("OnMenuCommand", function(msg, source)
	if msg == IDM_NEW then
		return CreateUntitledFile()
	elseif msg == IDM_SAVE then
        if props["FileNameExt"]:find'^%^' and not shell.fileexists(props["FilePath"]) then
            scite.MenuCommand(IDM_SAVEAS)
            return true
        end
	elseif msg == IDM_SAVEAS then
		unsaved_files[props["FilePath"]:upper()] = nil --������� ������ � ������ �� �������
	end
end)

-- ����� �����, ��������� �������� CreateUntitledFile ����� ������ ���, ������� ��� ���������� SciTE ����� ��������� ��� ����� �� ��������� ���� (��� ������ ����������� ���� "SaveAs")
-- ���������� ������� OnBeforeSave ��� ���������� ������ ������ ������� ���������� ���� "SaveAs"
AddEventHandler("OnBeforeSave", function(file)
	if isMakeUTF8() and tonumber(props["editor.unicode.mode"]) == IDM_ENCODING_DEFAULT then
		editor.TargetStart = 0
		editor.TargetEnd = editor.Length
		local txt_in = editor:GetText()
		editor:ReplaceTarget(shell.to_utf8(txt_in))
		scite.MenuCommand(IDM_ENCODING_UCOOKIE)
	end
	if unsaved_files[file:upper()] then -- ���� ��� ��������� ���� ������������� �����
		scite.MenuCommand(IDM_SAVEAS)
		return true
	end
end)
