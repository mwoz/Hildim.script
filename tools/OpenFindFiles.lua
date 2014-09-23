--[[--------------------------------------------------
OpenFindFiles.lua
Author: mozers�
Version: 1.4.0
------------------------------------------------------
����� ���������� ������� "����� � ������..."
������� ����� � ����������� ���� ������� - "������� ��������� �����"
------------------------------------------------------
�����������:
� ���� SciTEStartup.lua �������� ������:
  dofile (props["SciteDefaultHome"].."\\tools\\OpenFindFiles.lua")
--]]--------------------------------------------------

local user_outputcontext_menu           -- �������� ����������� ���� �������
local outputcontextmenu_changed = false -- ������� ����������� ������������ ����
local command_num                       -- ����� ������� "OpenFindFiles" � ���� Tools
local IDM_TOOLS = 9000
require 'shell'

--------------------------------------------------
-- ����� ���������� ������ ���� Tools
local function GetFreeCommandNumber()
	for i = 20, 299 do
		if props["command."..i..".*"] == "" then return i end
	end
end

--------------------------------------------------
-- �������� ������� � ���� Tools � ������� �� � ����������� ���� �������
local function CreateMenu()
	local command_name = shell.to_utf8(scite.GetTranslation("Open Find Files"))
	command_num = GetFreeCommandNumber()

	-- ����� � � ����������� ���� �������
	user_outputcontext_menu = props["user.outputcontext.menu.*"]
	props["user.outputcontext.menu.*"] = command_name.."|"..(IDM_TOOLS+command_num).."|||"..user_outputcontext_menu
	outputcontextmenu_changed = true

	-- ������� � ���� Tools
	props["command."..command_num..".*"] = "OpenFindFiles"
	props["command.mode."..command_num..".*"] = "subsystem:lua,savebefore:no,clearbefore:no"

end

--------------------------------------------------
-- �������� ������� �� ���� Tools � �������������� ��������� ������������ ���� �������
local function RemoveMenu()
	props["user.outputcontext.menu.*"] = user_outputcontext_menu
	outputcontextmenu_changed = false
	props["command."..command_num..".*"] = ""
end

--------------------------------------------------
-- �������� ������, ������������� � �������
function OpenFindFiles()
	local output_text = output:GetText()
	local str, path = output_text:match('"(.-)" in "(.-)"')
	path = path:match('^.+\\')
	local filename_prev = ''
	for filename in output_text:gmatch('([^\r\n:]+):%d+:[^\r\n]+') do
		filename = filename:gsub('^%.\\', path)
		if filename ~= filename_prev then
			scite.Open(shell.to_utf8(filename))
			local pos = editor:findtext(str)
			if pos ~= nil then editor:GotoPos(pos) end
			filename_prev = filename
		end
	end
	RemoveMenu()
end

--------------------------------------------------
AddEventHandler("OnMenuCommand", function(msg, source)
	if outputcontextmenu_changed then
		if msg ~= IDM_TOOLS+command_num and msg ~= IDM_FINDINFILES then RemoveMenu() end
	else
		if msg == IDM_FINDINFILES then CreateMenu() end
	end
end)
