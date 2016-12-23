--[[
������ ���� - ���������� ��������� � ����������(� ������ �������) �������������
��� ������� ������ ���� - ������� �� �������� �������, ������� � ������������. ��� �������, ������������ ����� �������. ������� �������, �������������� ���� - ������� �������
��������:
	- <nls> - ��������� �� �����
	- key - �����������
	- key_external - ����������� �� ����� ��������������
	��� �������, ����������� �� ��������
	plane - ������ ����������� � �������� ����
	����������� �������
	- active - ������ � ���������� ����������, ������������ true ��� false
	���������
	- visible  - ������ � ���������� ����������, ������������ true ��� false
	- visible_ext - ������ ���������� ������, ��� ������� ����� �������
	��������
	- check_idm prop, ������� ����� �������� � idm
	- check  - ������ � ���������� ����������, ������������ true ��� false
	- check_prop
	- check_iuprops
	- check_boolean
	��������
	- idm - ������������� ���� ������
	- action
	- action_lua
	- action_cmd
]]
require 'shell'
local function windowsList()
	local t = {}
	local maxN = scite.buffers.GetCount() - 1
	for i = 0,maxN do
		local row = {}
		local s = scite.buffers.NameAt(i):gsub('(.+)[\\]([^\\]*)$', '%2(%1)')
		local md = Iif(scite.buffers.SavedAt(i), '', '*') .. Iif(i < 9, '&'..((i + 1) % 10)..'. ','')

		row[1] = md..s
		row.order = s:upper()
		row.action = "scite.buffers.SetDocumentAt("..i..")"
		t[i + 1] = row
	end
	table.sort(t, function(a, b)
		return a.order < b.order
	end)
	return t
end

local function ResetFontSize()
	local ret, size = iup.GetParam("����� �������� � ��������� ����������",
					function(h,i) if i == -1 and tonumber(iup.GetParamParam(h,0).value) < 5 then return 0 end return 1 end,
					'������%i[1,19,1]\n', tonumber(props['iup.defaultfontsize']) or 9)
	if ret then
		props['iup.defaultfontsize'] = size
		iup.Alarm('����� ���������', '��������� ����� ��������� ����� ����������� ���������', 'OK')
	end
end

local function SetFindresCount()
	local ret, size = iup.GetParam("������� ����������� ������",
					function(h,i) if i == -1 and tonumber(iup.GetParamParam(h,0).value) < 3 then return 0 end return 1 end,
					'�� �����%i[1,30,1]\n', tonumber(_G.iuprops['findres.maxresultcount']) or 10)
	if ret then
		_G.iuprops['findres.maxresultcount'] = size
	end
end

local function ChangeCode(newcmd)
    return function()
        local s = editor:GetText()
        if newcmd == IDM_ENCODING_DEFAULT then
            s = s:from_utf8(1251)
        elseif props['editor.unicode.mode'] == ''..IDM_ENCODING_DEFAULT then
            s = s:to_utf8(1251)
        end
        scite.MenuCommand(newcmd)
        editor:SetText(s)
        editor:EmptyUndoBuffer()
    end
end

local function CopyPathToClipboard(what)
	local str
	if what == 'name' then
		str=string.from_utf8(props['FileNameExt'],1251)
	elseif what == 'path' then
		str=string.from_utf8(props['FileDir'],1251)
	elseif what=="text" then
		str = string.from_utf8(editor:GetText(),editor.CodePage)
	elseif what=="all" then
		str=string.from_utf8(props['FileDir']..'\\'..props['FileNameExt'],1251)
	end
	shell.set_clipboard(str)
end

local tHilight, tLangs = {},{}

_G.sys_Menus = {}
local function scintilla()
	if editor.Focus then return editor end
	if output.Focus then return output end
	return findres
end
local function IsSelection()
	return scintilla().SelectionStart<scintilla().SelectionEnd
end

local function ResetReadOnly()
	local attr = shell.getfileattr(props['FilePath'])
	if shell.bit_and(attr, 1) == 1 then
		attr = attr - 1
	else
		attr = attr + 1
	end
	shell.setfileattr(props['FilePath'], attr)
	scite.MenuCommand(IDM_REVERT)
end

local function RunSettings()
    for s, _ in pairs(dialogs) do
        if s == 'commandsplugin' or s == 'sidebarlayout' or s == 'LexersSetup' or s == 'toolbarlayout' or s == 'usertb' or s == 'HotkeysSetup' then return false end
    end
    return true
end

local function IsOpenTemporaly()
    local maxN = scite.buffers.GetCount() - 1
    for i = 0, maxN do
        if scite.buffers.NameAt(i):find('\\%^[^\\]+$') then return true end
    end
    return false
end

local bCanPaste = true
AddEventHandler("OnDrawClipboard", function(flag)
	bCanPaste = (flag > 0)
end)

local t = {}
if _G.iuprops['settings.lexers'] then
	for w in _G.iuprops['settings.lexers']:gmatch('[^�]+') do
		local _,_, p1,p2,p3,p4 = w:find('([^�]*)�([^�]*)�([^�]*)�([^�]*)')
		t[p4] = true
		table.insert(tHilight,{p1, action = function() scite.SetLexer(p2) end, check=function() return editor_LexerLanguage() == p3 end})
	end
	for n,_ in pairs(t) do
		table.insert(tLangs, {"Open "..n, action =function() scite.Open(props["SciteDefaultHome"].."\\languages\\"..n) end})
	end
end


_G.sys_Menus.TABBAR = { title = "����������� ���� ��������",
	{link='File�&Close'},
	{link='File�C&lose All'},
	{'Close All But Curent',  ru = '������ ���, ����� �������', action=function() iup.CloseFilesSet(9132) end, },
	{'Close All Temporally',  ru = '������ ��� ���������', action=function() iup.CloseFilesSet(9134) end, visible=IsOpenTemporaly },
	{'s1', separator=1},
	{link='File�&Save'},
	{link='Buffers�&Save All'},
	{link='File�Save &As...'},
	{link='File�Save a Cop&y...'},
	{'s1', separator=1},
	{'Move Tab Left', ru = '����������� �����', action = IDM_MOVETABLEFT,},
	{'Move Tab Right', ru = '����������� ������', action = IDM_MOVETABRIGHT,},
	{'Copy to Clipboard', ru='���������� � �����',{
		{'All Text', ru='���� �����', action = function() CopyPathToClipboard("text") end,},
		{'Path/FileName', ru='����/��� �����', action = function() CopyPathToClipboard("all") end,},
		{'Path', ru='����', action = function() CopyPathToClipboard("path") end,},
		{'FileName', ru='��� �����', action = function() CopyPathToClipboard("name") end,},
	}},
	{link='File�Encoding'},
	{link='Options�&Read-Only'},
	{'slast', separator=1},
}
_G.sys_Menus.OUTPUT = {title = "����������� ���� �������",
	{link = 'Edit�Conventional�Cu&t'},
	{link = 'Edit�Conventional�&Copy'},
	{link = 'Edit�Conventional�&Paste'},
	{link = 'Edit�Conventional�&Delete'},
	{'s1', separator = 1},
	{link = 'Tools�Clear &Output'},
	{link = 'Tools�&Previous Message'},
	{link = 'Tools�&Next Message'},
	{'s2', separator = 1},
	{'Input Mode', ru = '����� �����', {
		{'Display Mode', ru = '����������(press Enter)', action = function() output:DocumentEnd();output:ReplaceSel('###?\n') end},
		{'Command Line Mode', ru = '����� ��������� ������', action = function() output:DocumentEnd();output:ReplaceSel('###c') end},
		{'LUA Mode', ru = '����� ������� LUA', action = function() output:DocumentEnd();output:ReplaceSel('###l') end},
		{'LUA Mode', ru = '�������� ��������� LUA', action = function() output:DocumentEnd();output:ReplaceSel('###p') end},
		{'IDM command Mode', ru = '����� ������ IDM', action = function() output:DocumentEnd();output:ReplaceSel('###i') end},
		{'Switch OFF', ru = '���������', action = function() output:DocumentEnd();output:ReplaceSel('####') end},
	}},
    {'Settings', ru = '���������',{
        {'Wrap Out&put', ru = '������� �� ������ � �������', action = IDM_WRAPOUTPUT, check = "props['output.wrap']=='1'"},
        {'Clear Before Execute', ru = '������� ����� �����������', check_prop = "clear.before.execute"},
        {'Recode OEM to ANSI', ru = '�������������� OEM � ANSI', check_prop = "output.code.page.oem2ansi"},
        {'Autoshow By Output', ru = '��������� ��� ������', check_iuprops = "concolebar.autoshow"},
    },},
	{'slast', separator = 1},
}

_G.sys_Menus.FINDRES = {title = "����������� ���� ����������� ������",
	{link = 'Edit�Conventional�Cu&t'},
	{link = 'Edit�Conventional�&Copy'},
	{link = 'Edit�Conventional�&Paste'},
	{link = 'Edit�Conventional�&Delete'},
	{'s1', separator = 2},
	{link = 'Tools�Clear &Find Result'},
    {'Settings', ru = "���������" ,{
        {'DblClick Only On Number', ru = 'DblClick ������ �� ������', check_boolean = 'findres.clickonlynumber'},
        {'Group By Name', ru = '������������ �� ����� �����', check_boolean = 'findres.groupbyfile'},
        {'Wrap Find &Result', ru = '������� �� ������ � ����������� ������', action = IDM_WRAPFINDRES, check = "props['findres.wrap']=='1'"},
        {'Number Of Find Results...', ru = '����������� ������ �� �����....', action = SetFindresCount},
    }},
	{'Open Files', plane = 1, visible = "findres.StyleAt[findres.CurrentPos] == SCE_SEARCHRESULT_SEARCH_HEADER" ,{
		{'s_OpenFiles', separator = 1},
		{'Open Files', ru = '������� �����', action = function() CORE.OpenFoundFiles(1) end, },
		{'Close Files', ru = '������� �����', action = function() CORE.OpenFoundFiles(2) end, },
		{'Close If Not Found', ru = '������� �� ���������', action = function() CORE.OpenFoundFiles(3) end, },
	}},
	{'slast', separator = 1},

}

_G.sys_Menus.EDITOR = {title = "����������� ���� ���� ���������",
	{'s0', link='Edit�Conventional�&Undo'},
	{link='Edit�Conventional�&Redo'},
	{'s1', separator=1},
	{link='Edit�Conventional�Cu&t'},
	{link='Edit�Conventional�&Copy'},
	{link='Edit�Conventional�&Paste'},
	{link='Edit�Conventional�&Delete'},
	{link='Edit�Conventional�Duplicat&e'},
	{'s1', separator=2},
	{link='Edit�Conventional�Select &All'},
	{link='Search�Search', plane=0},
	{link='View�Folding', plane=0},
	{link='Search�Toggle Bookmar&k'},
	{link='Search�&Go to definition(Shift+Click)'},
}

_G.sys_Menus.MainWindowMenu = {title = "������� ���� ���������",
	{'_HIDDEN_', {
		{'Next Tab', key = 'Ctrl+Tab', action = IDM_NEXTFILESTACK},
		{'Prevouse Tab', key = 'Ctrl+Shift+Tab', action = IDM_PREVFILESTACK},
		{'Block Up', key = 'Alt+Up', action = function() editor:LineUpRectExtend() end},
		{'Block Down', key = 'Alt+Down', action = function() editor:LineDownRectExtend() end},
		{'Block Left', key = 'Alt+Left', action = function() editor:CharLeftRectExtend() end},
		{'Block Right', key = 'Alt+Right', action = function() editor:CharRightRectExtend() end},
		{'Block Home', key = 'Alt+Home', action = function() editor:VCHomeRectExtend() end},
		{'Block End', key = 'Alt+End', action = function() editor:LineEndRectExtend() end},
		{'Block Page Up', key = 'Alt+PageUp', action = function() editor:PageUpRectExtend() end},
		{'Block Page Down', key = 'Alt+PageDown', action = function() editor:PageDownRectExtend() end},
	},},
	{'File', ru = '����',{
		{'New', ru = '�������', key = 'Ctrl+N', action = IDM_NEW, image = 'document__plus_�'},
		{'&Open...', ru = '�������', key = 'Ctrl+O', action = IDM_OPEN, image = 'folder_open_document_�'},
		--{'Open Selected &Filename', ru = '������� ���������� ����', key = 'Ctrl+Shift+O', action = IDM_OPENSELECTED, active = function() return editor:GetSelText():find('%w:[\\/][^"\n\r\t]') end,},
		{'Recent Files', ru = '�������� �����', visible = "(_G.iuprops['resent.files.list.location'] or 0) == 0", function() if (_G.iuprops['resent.files.list.location'] or 0) == 0 then return iuprops['resent.files.list']:GetMenu() else return {} end end},
		{'&Revert', ru = '������������� ����', key = 'Ctrl+R', action = IDM_REVERT},
		{'&Close', ru = '�������', key = 'Ctrl+F4', action = IDM_CLOSE},
		{'C&lose All', ru = '������� ���', action = IDM_CLOSEALL},
		{'&Save', ru = '���������', key = 'Ctrl+S', action = IDM_SAVE, active = function() return editor.Modify end, image = 'disk_�'},
		{'Save &As...', ru = '��������� ���...', key = 'Ctrl+Shift+S', action = IDM_SAVEAS, image = 'disk__pencil_�'},
		{'Save a Cop&y...', ru = '��������� �����...', key = 'Ctrl+Shift+P', action = IDM_SAVEACOPY, image = 'disk__plus_�'},
		--[[{'Copy Pat&h',  action = IDM_COPYPATH},]]
		{'Encoding', ru = '���������',{check_idm = 'editor.unicode.mode', radio = 1,
			{'&Code Page Property', ru = '�������� ���������� codepage', action = IDM_ENCODING_DEFAULT},
			{'UTF-16 &Big Endian', action = IDM_ENCODING_UCS2BE},
			{'UTF-16 &Little Endian', action = IDM_ENCODING_UCS2LE},
			{'UTF-8 &with BOM', ru = 'UTF-8 � ����������', action = IDM_ENCODING_UTF8},
			{'&UTF-8', action = IDM_ENCODING_UCOOKIE},
		},},
		{'&Export', ru = '�������',{
			{'As &HTML...' , ru = '� &HTML..', action = IDM_SAVEASHTML},
			{'As &RTF...'  , ru = '� &RTF...', action = IDM_SAVEASRTF},
			{'As &PDF...'  , ru = '� &PDF...', action = IDM_SAVEASPDF},
			{'As &LaTeX...', ru = '� &LaTeX...', action = IDM_SAVEASTEX},
			{'As &XML...'  , ru = '� &XML...', action = IDM_SAVEASXML},
		},},
		{'s1', separator = 1},
		{'Save Session...', ru = '��������� ������', action = iup.SaveSession,},
		{'Load Session...', ru = '��������� ������', action = iup.LoadSession,},
		{'s2', separator = 1},
		{'Page Set&up...', ru = '��������� ��������', action = IDM_PRINTSETUP, image = 'layout_design_�'},
		{'&Print...', ru = '������...', key = 'Ctrl+P', action = IDM_PRINT, image = 'printer_�'},
		{'s3', separator = 1},
		{'Exit', ru = '�����', action = IDM_QUIT},
        {'sLast', separator = 1},
        {'Recent Files1', plane = 1, visible = "(_G.iuprops['resent.files.list.location'] or 0) == 1", function() if (_G.iuprops['resent.files.list.location'] or 0) == 1 then return iuprops['resent.files.list']:GetMenu() else return {} end end},
	},},
	{'Edit', ru = '������',{
		{'Conventional', ru = '�����������', {
			{'&Undo', ru = '��������', key = 'Ctrl+Z', key_external = 1, action = IDM_UNDO, active = function() return scintilla():CanUndo() end, image = 'arrow_return_270_left_�'},
			{'&Redo', ru = '���������', key = 'Ctrl+Y', key_external = 1, action = IDM_REDO, active = function() return scintilla():CanRedo() end, image = 'arrow_return_270_�'},
			{'s1', separator = 1},
			{'Cu&t', ru = '��������', key = 'Ctrl+X', key_external = 1, action = IDM_CUT, active = IsSelection, image = 'scissors_�'},
			{'&Copy', ru = '����������', key = 'Ctrl+C', key_external = 1, action = IDM_COPY, active = IsSelection, image = 'document_copy_�'},
			{'&Paste', ru = '��������', key = 'Ctrl+V', key_external = 1, action = IDM_PASTE, image = 'clipboard_paste_�', active = function() return bCanPaste end,},
			{'Duplicat&e', ru = '�����������', key = 'Ctrl+D', key_external = 1, action = IDM_DUPLICATE, image = 'yin_yang_�'},
			{'&Delete', ru = '�������', key = 'Del', key_external = 1, action = IDM_CLEAR, image = 'cross_script_�'},
			{'Select &All', ru = '������� ���', key = 'Ctrl+A', key_external = 1, action = IDM_SELECTALL},
			{'Copy as RT&F', ru = '���������� � ������� RTF', action = IDM_COPYASRTF, active = IsSelection},
		}},
		{'Xml', ru = 'Xml', visible_ext = 'xml,form,rform,cform',{
			{'Format Xml', ru = '������������� Xml', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\FormatXml.lua')", image = 'broom_code_�',},
		}},
		{'s1', separator = 1},
		{'Autoformat', ru = '����������', {
			{'Format Block', ru = '������������� ����', action = function() if Format_Block then Format_Block() end end, key = 'Ctrl+]'},
			{'Format Line', ru = '������������� ������', action = function() if Format_String then Format_String() end end, key = 'Ctrl+['},
			{'Autformating Lines', ru = '������������������ �����', check_iuprops = 'autoformat.line', key = 'Ctrl+Shift+['},
		}},
		{'Match &Brace', ru = '����� ������ ������', key = 'Ctrl+E', action = IDM_MATCHBRACE},
		{'Select t&o Brace', ru = '�������� �� ������ ������', key = 'Ctrl+Shift+E', action = IDM_SELECTTOBRACE},
		{'s2', separator = 1},
		{'S&how Calltip', ru = '�������� ���������', key = 'Ctrl+?', action = function() ShowTipManualy() end, image = 'ui_tooltip_balloon_bottom_�',},
		{'Complete S&ymbol', ru = '��������� �����(�� API)', key = 'Ctrl++', action = function() ShowListManualy() end},
		{'Complete &Word', ru = '��������� �����(�� ������)', key = 'Ctrl+Enter', action = IDM_COMPLETEWORD},
		{'s2', separator = 1},
        {'Expand Abbre&viation', ru = '������������ ���������� (���=���������)', key = 'Ctrl+B', action = IDM_ABBREV, image = 'key_�'},
		{'Expand Abbre&viation', ru = '������������ ���������� (���=����� ������)', key = 'Ctrl+Alt+B', action = IDM_INS_ABBREV, image = 'key__plus_�'},
		{'s3', separator = 1},
        {'Comment or Uncomment', ru = '���������������� � ����������������� �����', key = 'Ctrl+Q', action = CORE.xComment, image = 'edit_signiture_�'},
		{'Block Co&mment', ru = '������� �����������', action = IDM_BLOCK_COMMENT, visible = "props['comment.stream.start.'..editor_LexerLanguage()]~='' and props['comment.block.'..editor_LexerLanguage()]~=''"},
		{'Stream Comme&nt', ru = '��������� �����������', key = 'Ctrl+Shift+Q', action = IDM_STREAM_COMMENT, visible = "props['comment.stream.start.'..editor_LexerLanguage()]~='' and props['comment.block.'..editor_LexerLanguage()]~=''"},
		{'Bo&x Comment', ru = '���� - �����������', key = 'Ctrl+Shift+B', action = IDM_BOX_COMMENT, visible = "props['comment.box.start.'..editor_LexerLanguage()]~=''"},
        {'Decode  ��', ru = '�������� ��������� ��..',{
            {'&Code Page Property', ru = '�������� ���������� codepage', action = ChangeCode(IDM_ENCODING_DEFAULT), active = function() return props['editor.unicode.mode'] ~= ''..IDM_ENCODING_DEFAULT end},
            {'UTF-16 &Big Endian', action = ChangeCode(IDM_ENCODING_UCS2BE), active = function() return props['editor.unicode.mode'] ~= ''..IDM_ENCODING_UCS2BE end},
            {'UTF-16 &Little Endian', action = ChangeCode(IDM_ENCODING_UCS2LE), active = function() return props['editor.unicode.mode'] ~= ''..IDM_ENCODING_UCS2LE end},
            {'UTF-8 &with BOM', ru = 'UTF-8 � ����������', action = ChangeCode(IDM_ENCODING_UTF8), active = function() return props['editor.unicode.mode'] ~= ''..IDM_ENCODING_UTF8 end},
            {'&UTF-8', action = ChangeCode(IDM_ENCODING_UCOOKIE), active = function() return props['editor.unicode.mode'] ~= ''..IDM_ENCODING_UCOOKIE end},
        },},
		{'Make &Selection Uppercase', ru = '��������� � ������� �������', key = 'Ctrl+U', action = IDM_UPRCASE, image = 'edit_uppercase_�'},
		{'Make Selection &Lowercase', ru = '��������� � ������ �������', key = 'Ctrl+Shift+U', action = IDM_LWRCASE, image = 'edit_lowercase_�'},
	},},
	{'Search', ru = '�����',{
		{'&Find...', ru = '�����', key = 'Ctrl+F', action = IDM_FIND, image = 'IMAGE_search'},
		{'Find &Next', ru = '����� �����', key = 'F3', action = IDM_FINDNEXT},
		{'Find Previou&s', ru = '���������� ����������', key = 'Shift+F3', action = IDM_FINDNEXTBACK},
		{'F&ind in Files...', ru = '����� � ������', key = 'Ctrl+Shift+F', action = IDM_FINDINFILES, image = 'folder_search_result_�'},
		{'R&eplace...', ru = '��������', key = 'Ctrl+H', action = IDM_REPLACE, image = 'IMAGE_Replace'},
		{'Marks', ru = '�����', action = function() CORE.ActivateFind(3) end, key = 'Ctrl+M', image = 'marker_�',},
		{'s0', separator = 1},
		{'Search', ru = '�����', plane = 1,{
			{'s_FindTextOnSel', separator = 1},
			{'Find Next Word/Selection', ru = '�����/��������� - (����� ������)', action = function() CORE.Find_FindInDialog(true) end, key = 'Ctrl+F3',},
			{'Find Prev Word/Selection', ru = '���������� �����/��������� - (����� ������)', action = function() CORE.Find_FindInDialog(false) end, key = 'Ctrl+Shift+F3',},
			{'Next Word/Selection', ru = '��������� �����/���������', action = function() CORE.FindNextWrd(1) end, key='Alt+F3',},
			{'Prevous Word/Selection', ru = '���������� �����/���������', action = function() CORE.FindNextWrd(2) end, key ='Alt+Shift+F3',},
			{'Find All Word/Selection(Ctrl+Alt+Click)', ru = '����� ��� �����/���������(Ctrl+Alt+Click)', action = CORE.FindSelToConcole, key = 'Alt+Shift+F',},
		}},
		{'s1', separator = 1},
		{'&Go to definition(Shift+Click)', ru = '������� � ��������(Shift+Click)', key = 'F12', action = "menu_GoToObjectDefenition()"},
		{'&Go to...', ru = '������� �� �������...', key = 'Ctrl+G', action = IDM_GOTO},
		{'Next Book&mark', ru = '��������� ��������', key = 'F2', action = IDM_BOOKMARK_NEXT, image = 'bookmark__arrow_�'},
		{'Pre&vious Bookmark', ru = '���������� ��������', key = 'Shift+F2', action = IDM_BOOKMARK_PREV, image = 'bookmark__arrow_left_�'},
		{'Toggle Bookmar&k', ru = '��������/������� ��������', key = 'Ctrl+F2', action = IDM_BOOKMARK_TOGGLE, image = 'bookmark_�'},
		{'&Clear All Bookmarks', ru = '�������� ��� ��������', action = IDM_BOOKMARK_CLEARALL},
	},},
	{'View', ru = '���',{
		{'Folding', ru = '�������', plane = 1, {
			{'Toggle &current fold', ru = '��������/���������� ������� ����', action = IDM_EXPAND},
			{'Toggle &all folds', ru = '��������/���������� ��� �����', action = IDM_TOGGLE_FOLDALL},
			{'Toggle &recurse current fold', ru = '��������/���������� ���������� ������� ����', action = IDM_TOGGLE_FOLDRECURSIVE},
			{'Collapse Subfolders', ru = '�������� ��������', key = 'Ctrl+Shift+-', action = "CORE.ToggleSubfolders(false)"},
			{'Expand Subfolders', ru = '���������� ��������', key = 'Ctrl+Shift++', action = "CORE.ToggleSubfolders(true)"},
		}},
		{'s2', separator = 1},
		{'Full Scree&n', ru = '������������� �����', key = 'F11', action = IDM_FULLSCREEN},
		{'&Menu Bar', ru = '������ ����', action = function() iup.GetDialogChild(iup.GetLayout(), "MenuBar").switch() end, check = function() return iup.GetDialogChild(iup.GetLayout(), "MenuBar").isOpen() end},
		{'&Tool Bar', ru = '������ ������������', action = function() iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").switch() end, check = function() return iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").isOpen() end},
		{'Status Bar', ru = '������ �������', action = function() iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").switch() end, check = function() return iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").isOpen() end},
		{'Tab &Bar', ru = '�������', action = function() local h = iup.GetDialogChild(iup.GetLayout(), "TabbarExpander"); if h.state == 'OPEN' then h.state = 'CLOSE' else h.state = 'OPEN' end end, check = function() return iup.GetDialogChild(iup.GetLayout(), "TabbarExpander").state == 'OPEN' end},
		{'Bottom Bar', ru = '������ ������', key = 'F10', action = IDM_TOGGLEOUTPUT, check = function() return (tonumber(iup.GetDialogChild(iup.GetLayout(), "BottomBarSplit").barsize) ~= 0) end},
		{'s2', separator = 1},
		{'&Whitespace', ru = '�������', key = 'Ctrl+Shift+8', action = IDM_VIEWSPACE, check = "props['view.whitespace']=='1'"},
		{'&End of Line', ru = '������� �������� �����', key = 'Ctrl+Shift+9', action = IDM_VIEWEOL, check = "editor.ViewEOL"},
		{'&Indentation Guides', ru = '������������ �������', action = IDM_VIEWGUIDES, check = "props['view.indentation.guides']=='1'"},
		{'&Line Numbers', ru = '������ �����', action = IDM_LINENUMBERMARGIN, check = "props['line.margin.visible']=='1'"},
		{'&Margin', ru = '���������� ��������', action = IDM_SELMARGIN, check = "scite.SendEditor(SCI_GETMARGINWIDTHN,1)>0"},
		{'&Fold Margin', ru = '���� ������������ ������ ������', action = IDM_FOLDMARGIN, check = "scite.SendEditor(SCI_GETMARGINWIDTHN,2)>0"},
		{'s3', separator = 1},
		{'slast', separator = 1},

	},},
	{'Tools', ru = '�����������',{
		{'&Compile', ru = '�������������', key = 'Ctrl+F7', action = IDM_COMPILE, image = 'compile_�'},
		{'&Build', ru = '�������', key = 'F7', action = IDM_BUILD, image = 'building__arrow_�'},
		{'&Go', ru = '���������', key = 'F5', action = IDM_GO, image = 'control_�'},
		{'&Stop Executing', ru = '���������� ����������', key = 'Ctrl+Break', action = IDM_STOPEXECUTE},
		{'Script', ru = '������ ������������',{
			{'Reload', ru = '�������������', key = 'Alt+Ctrl+Shift+R', action = function() scite.PostCommand(POST_SCRIPTRELOAD, 0) end,},
		},},
		{'s1', separator = 1},
		{'Utils', ru = '�������',{
			{'LayOut Dialog', action =(function()
				local f = iup.filedlg{}
				iup.SetNativeparent(f, "SCITE")
				f:popup()
				local path = f.value
				f:destroy()
				testHandle = nil
				if path ~= nil then
					local l = io.open(path)
					local strLua = l:read('*a')
					l:close()
					local _, _, fName = strLua:find("function (create_dialog_[_%w]+)")
					strLua = strLua..'\n testHandle = '..fName..'()'
					dostring(strLua)
				end
				local dlg = iup.LayoutDialog(testHandle)
				iup.Show(dlg)
			end),},
		},},
		{'s2', separator = 1},
		{'&Next Message', ru = '��������� ���������', key = 'F4', action = IDM_NEXTMSG},
		{'&Previous Message', ru = '���������� ���������', key = 'Shift+F4', action = IDM_PREVMSG},
		{'Clear &Output', ru = '�������� ���� �������', key = 'Shift+F5', action = IDM_CLEAROUTPUT},
		{'Clear &Find Result', ru = '�������� ���������� ������', action = "findres:SetText('')"},
		{'&Switch Pane', ru = '��������������/���������� ������/�������', key = 'Ctrl+F6', action = function() CORE.SwitchPane(true) end},
		{'Switch Pane Back', ru = '��������������/�������/���������� ������', key = 'Ctrl+Shift+F6', action = function() CORE.SwitchPane(false) end},
	},},
	{'Options', ru = '���������',{

		{'&Wrap', ru = '������� �� ������', action = IDM_WRAP, check = "props['wrap']=='1'"},
		{'&Read-Only', ru = '������ ��� ������', action = ResetReadOnly, check = "shell.bit_and(shell.getfileattr(props['FilePath']), 1) == 1"},
		{'s2', separator = 1},
		{'Line End Characters', ru = '������� �������� �����',{radio = 1,
			{'CR &+ LF', action = IDM_EOL_CRLF, check = "editor.EOLMode==SC_EOL_CRLF"},
			{'&CR', action = IDM_EOL_CR, check = "editor.EOLMode==SC_EOL_CR"},
			{'&LF', action = IDM_EOL_LF, check = "editor.EOLMode==SC_EOL_LF"},
		},},
		{'&Convert Line End Characters', ru = '�������������� ������� �������� �����', action = IDM_EOL_CONVERT},
		{'s1', separator = 1},
		{'Change Inden&tation Settings...', ru = '�������� ��������� �������', action = IDM_TABSIZE},
		{'Use &Monospaced Font', ru = '������������ ������������ ������', action = IDM_MONOFONT},
		{'s2', separator = 1},
		{'Reload Session', ru = '��������������� �������� �����', action = "CheckChange('session.reload', true)", check = "props['session.reload']=='1'"},
		{'Show Menu Icons', ru = '���������� ������ � ����', check_iuprops = 'menus.show.icons'},
		{'Interface Font Size', ru = '������ ������ ����������', action = ResetFontSize},

		{'s3', separator = 1},
		{'Hotkeys Settings', ru = '��������� ������� ������...', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\HotkeysSettings.lua')", active = RunSettings},
		{'Plugins', ru = '�������', visible = RunSettings,{
            {'Toolbars Layout', ru = '��������� ������� ������������...', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\ToolBarsLayout.lua')"},
            {'SideBars Settings', ru = '��������� ������� �������...', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\SideBarLayOut.lua')"},
            {'Hidden Plugins', ru = '��������� ������� �������...', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\HiddenPlugins.lua')('Status')"},
            {'Status Bar Plugins', ru = '����������� ������� ��������...', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\HiddenPlugins.lua')('Hidden')"},
            {'Commands Plugins', ru = '����������� ������...', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\HiddenPlugins.lua')('Commands')"},
            {'s1', separator = 1},
            {'User Toolbar...', ru = '���������������� ������ ������������...', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\ToolBarSetings.lua')"},
		},},
		{'Load Configuration...', ru = '��������� ������������...', action = iup.LoadIuprops},
		{'Save Configuration...', ru = '��������� ������������ ���...', action = iup.SaveIuprops},
		{'Save Current Configuration', ru = '��������� ������� ������������: '..(iuprops['current.config.restore'] or ''):gsub('^.-([^\\]-)%.[^\\.]+$', '%1'), action = iup.SaveCurIuprops, visible = "iuprops['current.config.restore']~=nil"},
		{'s5', separator = 1},
		{'Windows Integration', ru = '��������� ���������� � Windows', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\WinAssoc.lua')"},
		{'Open &User Options File', ru = '������� ���� ���������������� ��������', action = IDM_OPENUSERPROPERTIES},
		{'Open &Global Options File', ru = '������� ���� ���������� ��������', action = IDM_OPENGLOBALPROPERTIES},
		{'Change Lexer Colors', ru = '�������� ����� �������...', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\ColorSettings.lua')"},
		{"Lexers properties", ru = '�������� ��������', {
			{'Lexers properties', ru = '�������� ��������', plane = 1 ,tLangs},
			{'s2', separator = 1},
			{"Select lexers", ru = "������������ �����", action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\UsedLexers.lua')", active = RunSettings},
		},},
	},},
	{'Language', ru = '���������', {
		{'tHilight', tHilight, plane = 1,},
		{'s1', separator = 1},
	},},
	{'Buffers', ru = '�������',{
		{'&Previous', ru = '����������', key = 'Shift+F6', action = IDM_PREVFILE},
		{'&Next', ru = '���������', key = 'F6', action = IDM_NEXTFILE},
		{'Move Tab &Left', ru = '����������� �����', action = IDM_MOVETABLEFT},
		{'Move Tab &Right', ru = '����������� ������', action = IDM_MOVETABRIGHT},
		{'&Close All', ru = '������� ���', action = IDM_CLOSEALL},
		{'&Save All', ru = '��������� ���', key = 'Ctrl+Alt+S', action = IDM_SAVEALL, image = 'disks_�'},
		{'s2', separator = 1},
		{'l1', windowsList, plane = 1},
	},},
	{'Help', ru = '�������',{
		{'&Help', ru = '����������� �������', key = 'F1', action = IDM_HELP},
		{'H&ildiM Help', ru = '������� �� HildiM', action = function() scite.ExecuteHelp(props['SciteDefaultHome']..'/help/HildiM.chm::ui/Menues.html', 0) end},
		{'slast', separator = 1},
        {'&About HildiM', ru = '� ���������', action = IDM_ABOUT},
	},},
}

