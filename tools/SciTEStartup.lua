-- ���� ���� �������� ��� �������� SciTE
-- ����� �� �������� ��� ��� �������� ����������� ������������ ��������, ��������� ��� ���������� ������ ���������, ����������� �� ��� �������� � ������������ ������ � �������� ������ ��� ������ ���������������� ������ ���� Tools.
-- ����� (� ������� dofile) �������� ������ �������, �������������� ������� ���������.

----[[ C O M M O N ]]-------------------------------------------------------
--�������� �������

if props['script.started'] ~= 'Y' then
    iup.Load(props["SciteDefaultHome"].."\\tools\\Images.led")
    dofile (props["SciteDefaultHome"].."\\tools\\Images.lua")
end
--iup.Load(props["SciteDefaultHome"].."\\tools\\Images22.led")
-- ����������� ����� � ������ ���������, ��������������� �� ������ ��������
_G.onDestroy_event = {}
dofile (props["SciteDefaultHome"].."\\tools\\COMMON.lua")
Splash_Screen()
dofile (props["SciteDefaultHome"].."\\tools\\Menus.lua")
----[[ R E A D   O N L Y ]]-------------------------------------------------


dofile (props["SciteDefaultHome"].."\\tools\\precompiller.lua")

dofile (props["SciteDefaultHome"].."\\tools\\sqlObjects.lua")

-- SideBar: ������������������� ������� ������
dofile (props["SciteDefaultHome"].."\\tools\\IupSideBar.lua")

-- ��������� ������� ������� ��������� � ���� �������
local tab_width = tonumber(props['output.tabsize'])
if tab_width ~= nil then
	scite.SendOutput(SCI_SETTABWIDTH, tab_width)
end

scite.PostCommand(POST_CONTINUESTARTUP,0)
