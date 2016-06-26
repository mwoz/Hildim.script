-- ���� ���� �������� ��� �������� SciTE
-- ����� �� �������� ��� ��� �������� ����������� ������������ ��������, ��������� ��� ���������� ������ ���������, ����������� �� ��� �������� � ������������ ������ � �������� ������ ��� ������ ���������������� ������ ���� Tools.
-- ����� (� ������� dofile) �������� ������ �������, �������������� ������� ���������.

----[[ C O M M O N ]]-------------------------------------------------------
--�������� �������
iup.Load(props["SciteDefaultHome"].."\\tools\\Images.led")
dofile (props["SciteDefaultHome"].."\\tools\\Images.lua")
--iup.Load(props["SciteDefaultHome"].."\\tools\\Images22.led")
-- ����������� ����� � ������ ���������, ��������������� �� ������ ��������
dofile (props["SciteDefaultHome"].."\\tools\\COMMON.lua")
Splash_Screen()
dofile (props["SciteDefaultHome"].."\\tools\\Menus.lua")

----[[ R E A D   O N L Y ]]-------------------------------------------------

-- ������ ����������� ������� "Read-Only"
-- ������ ��� ������� �� ��������� ��� �������������� � ���������� ��������� � ��������� ������
dofile (props["SciteDefaultHome"].."\\tools\\ReadOnly.lua")

-- ��� �������� ReadOnly, Hidden, System ������ �������� ����� ReadOnly � SciTE
dofile (props["SciteDefaultHome"].."\\tools\\ROCheck.lua")

-- ��������� ���������� RO ������
--dofile (props["SciteDefaultHome"].."\\tools\\ROWrite.lua")

----[[ � � � � � �   � � � � � � � � � � � ]]-------------------------------

-- ������������ ������
dofile (props["SciteDefaultHome"].."\\tools\\smartbraces.lua")

-- ������������ HTML �����
dofile (props["SciteDefaultHome"].."\\tools\\paired_tags.lua")

-- ������������� ��������������� � ������ ������������ (�� Ctrl+Q)
dofile (props["SciteDefaultHome"].."\\tools\\xComment.lua")
--~ dofile (props["SciteDefaultHome"].."\\tools\\smartcomment.lua")

----[[ � � � � � � �  � � � � ]]----------------------------------------------

-- ������ ����������� ������� SciTE "������� ���������� ����"
dofile (props["SciteDefaultHome"].."\\tools\\Open_Selected_Filename.lua")

-- ���������� ����������� ������� SciTE "������� ���������� ����" (��������� ��� ���������������� ���������)
-- � ����� ����������� ������� ���� �� �������� ����� ���� �� ��� ����� ��� ������� ������� Ctrl.
-- dofile (props["SciteDefaultHome"].."\\tools\\Select_And_Open_Filename.lua")

----[[ � � � � � � � � � � � � � ]]-------------------------------------------

-- ����������� LuaInspect <http://lua-users.org/wiki/LuaInspect>
if props["luainspect.path"] ~= '' then dofile (props["SciteDefaultHome"].."\\tools\\LuaInspectInstall.lua") end

-- ��� �������� �� �������� ������, ������������ �����, �������� ������� ������� �� ������
dofile (props["SciteDefaultHome"].."\\tools\\goto_line.lua")

-- �������� ����������� ������� SciTE "File|New" (Ctrl+N). ������� ����� ����� � ������� �������� � ����������� �������� �����
dofile (props["SciteDefaultHome"].."\\tools\\new_file.lua")

-- �������� HTML ��������� ��� ������ ��� ����������, ����������� �� ���� "�������� HTML-����" Internet Explorer
dofile (props["SciteDefaultHome"].."\\tools\\set_html.lua")

-- �������������� ������� �������, ��������� � �������� ��� ��������� �������� ������ �����.
dofile (props["SciteDefaultHome"].."\\tools\\RestoreRecent.lua")

-- ������� ��� ��������� ������
dofile (props["SciteDefaultHome"].."\\tools\\FoldText.lua")

--��������� �������� ����

dofile (props["SciteDefaultHome"].."\\tools\\precompiller.lua")

dofile (props["SciteDefaultHome"].."\\tools\\sqlObjects.lua")

dofile (props["SciteDefaultHome"].."\\tools\\InsertSpecialChar.lua")

-- ����������� ���������� ������ ����������� ��� ini, inf, reg � php ������
dofile (props["SciteDefaultHome"].."\\tools\\ChangeCommentChar.lua")

-- ����������� ����� ����� � ����� ������
dofile (props["SciteDefaultHome"].."\\tools\\CopyPathToClipboard.lua")

----[[ � � � � � � � � � � � � � �  � � � � ]]--------------------------------

-- ������� � ����������� ���� ���� (�������) ������� ��� ������ SVN
--dofile (props["SciteDefaultHome"].."\\tools\\svn_menu.lua")

-- ������� � ����������� ���� ���� (�������) ������� ��� ������ VSS
dofile (props["SciteDefaultHome"].."\\tools\\vss_showmenu.lua")

----[[ � � � � � � �  �  � � � � � � � � � � � ]]-----------------------------

-- SideBar: ������������������� ������� ������
--dofile (props["SciteDefaultHome"].."\\tools\\IupSideBar.lua")
-- �������������� �������� �� �������� � ����������
dofile (props["SciteDefaultHome"].."\\tools\\AutocompleteObject.lua")
-- �������������� �������� �� �������� � ����������
dofile (props["SciteDefaultHome"].."\\tools\\ColorSettings.lua")

-- ������� ������������ (�,�,�,�,�) �� ��������������� ������ (��� HTML ����������� �� �����������)
dofile (props["SciteDefaultHome"].."\\tools\\InsertSpecialChar.lua")

-- ����� � ��������� ���� ��������� ����������� �����
dofile (props["SciteDefaultHome"].."\\tools\\FindTextOnSel.lua")
dofile (props["SciteDefaultHome"].."\\tools\\SortControlXml.lua")
dofile (props["SciteDefaultHome"].."\\tools\\Align.lua")
-- ��������� / ������ ����� �� ������ (Bookmark) (�� �� ��� � Ctrl+F2)
-- � ������� ����� ���� ��� ������� ������� Ctrl
--dofile (props["SciteDefaultHome"].."\\tools\\BookmarkToggle.lua")

----[[ � � � � � � � � �   � � � � � � � � � � ]]-----------------------------

dofile (props["SciteDefaultHome"].."\\tools\\Autoformat.lua")
dofile (props["SciteDefaultHome"].."\\tools\\spell.lua")


-- SideBar: ������������������� ������� ������
dofile (props["SciteDefaultHome"].."\\tools\\IupSideBar.lua")

-- ��������� ������� ������� ��������� � ���� �������
local tab_width = tonumber(props['output.tabsize'])
if tab_width ~= nil then
	scite.SendOutput(SCI_SETTABWIDTH, tab_width)
end

----[[ � � � � � � �  � � � � � � � ]]-----------------------------

-- ������ ��� ��������� ������
--dofile (props["SciteDefaultHome"].."\\languages\\text.lua")


scite.PostCommand(POST_CONTINUESTARTUP,0)
