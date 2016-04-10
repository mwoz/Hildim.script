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

local tHilight, tLangs = {},{}
if shell.fileexists(props["SciteDefaultHome"].."\\tools\\SideBar\\LanguagesMenu.lua") then tLangs = assert(loadfile(props["SciteDefaultHome"].."\\tools\\SideBar\\LanguagesMenu.lua")) end
if shell.fileexists(props["SciteDefaultHome"].."\\tools\\SideBar\\HilightMenu.lua") then tHilight = assert(loadfile(props["SciteDefaultHome"].."\\tools\\SideBar\\HilightMenu.lua")) end

_G.sys_Menus = {}
local function IsSelection()
    return editor.SelectionStart<editor.SelectionEnd
end

_G.sys_Menus.MainWindowMenu = {
    {'_HIDDEN_', {
        {'Ctrl+Tab', key = 'Ctrl+Tab', action = IDM_NEXTFILESTACK},
        {'Ctrl+Shift+Tab', key = 'Ctrl+Shift+Tab', action = IDM_PREVFILESTACK},
    },},
    {'File', ru='����',{
        {'New', ru='�������', key = 'Ctrl+N', action = IDM_NEW},
        {'&Open...', ru = '�������', key = 'Ctrl+O', action = IDM_OPEN, active = function() return editor.Modify end},
        {'Open Selected &Filename', ru = '������� ���������� ����', key = 'Ctrl+Shift+O', action = IDM_OPENSELECTED},
        {'Recent Files', ru = '�������� �����', visible="iuprops['resent.files.list']~=nil", function() return iuprops['resent.files.list']:GetMenu() end},
        {'&Revert', ru = '������������� ����', key = 'Ctrl+R', action = IDM_REVERT},
        {'&Close', ru = '�������', key = 'Ctrl+W', action = IDM_CLOSE},
        {'&Save', ru = '���������', key = 'Ctrl+S', action = IDM_SAVE},
        {'Save &As...', ru = '��������� ���...', key = 'Ctrl+Shift+S', action = IDM_SAVEAS},
        {'Save a Cop&y...', ru = '��������� �����...', key = 'Ctrl+Shift+P', action = IDM_SAVEACOPY},
        {'Copy Pat&h',  action = IDM_COPYPATH},
        {'Encoding', ru='���������',{
            {'&Code Page Property', ru='�������� ���������� codepage', action = IDM_ENCODING_DEFAULT, check_idm='editor.unicode.mode'},
            {'UTF-16 &Big Endian',  action = IDM_ENCODING_UCS2BE, check_idm='editor.unicode.mode', check='tonumber(props["editor.unicode.mode"])==IDM_ENCODING_UCS2BE'},
            {'UTF-16 &Little Endian',  action = IDM_ENCODING_UCS2LE},
            {'UTF-8 &with BOM', ru='UTF-8 � ����������', action = IDM_ENCODING_UTF8},
            {'&UTF-8',  action = IDM_ENCODING_UCOOKIE},
        },},
        {'&Export', ru='�������',{
            {'As &HTML...' , ru = '� &HTML..', action = IDM_SAVEASHTML},
            {'As &RTF...'  , ru = '� &RTF...', action = IDM_SAVEASRTF},
            {'As &PDF...'  , ru = '� &PDF...', action = IDM_SAVEASPDF},
            {'As &LaTeX...', ru = '� &LaTeX...', action = IDM_SAVEASTEX},
            {'As &XML...'  , ru = '� &XML...', action = IDM_SAVEASXML},
        },},
        {'s1', separator=1},
        {'Page Set&up...', ru = '��������� ��������', action = IDM_PRINTSETUP},
        {'&Print...', ru = '������...', key = 'Ctrl+P', action = IDM_PRINT},
        {'s2', separator=1},
        -- {'&Load Session...', ru = '��������� ������...', action = IDM_LOADSESSION},
        -- {'Sa&ve Session...', ru = '��������� ������...', action = IDM_SAVESESSION},
        {'s3', separator=1},
        {'Exit', ru='�����', action = IDM_QUIT},
    },},
    {'Edit', ru='������',{
        {'Conventional',  ru = '�����������', {
            {'&Undo', ru = '��������', key = 'Ctrl+Z',key_external = 1, action = IDM_UNDO, active=function() return editor:CanUndo() end},
            {'&Redo', ru = '���������', key = 'Ctrl+Y',key_external = 1, action = IDM_REDO, active=function() return editor:CanRedo() end},
            {'s1',  separator=1},
            {'Cu&t', ru = '��������', key = 'Ctrl+X',key_external = 1, action = IDM_CUT, active=IsSelection},
            {'&Copy', ru = '����������', key = 'Ctrl+C',key_external = 1, action = IDM_COPY, active=IsSelection},
            {'&Paste', ru = '��������', key = 'Ctrl+V',key_external = 1, action = IDM_PASTE},
            {'Duplicat&e', ru = '�����������', key = 'Ctrl+D',key_external = 1, action = IDM_DUPLICATE},
            {'&Delete', ru = '�������', key = 'Del',key_external = 1, action = IDM_CLEAR},
            {'Select &All', ru = '������� ���', key = 'Ctrl+A',key_external = 1, action = IDM_SELECTALL, active=IsSelection},
            {'Copy as RT&F', ru = '���������� � ������� RTF', action = IDM_COPYASRTF, active=IsSelection},
        }},
        {'Xml',  ru ='Xml', visible_ext='xml,form,rform,cform',{
            {'Format Xml', ru='������������� Xml', action="dofile(props['SciteDefaultHome']..'\\\\tools\\\\FormatXml.lua')",},
        }},
        {'s1', separator=1},
        {'Match &Brace', ru = '����� ������ ������', key = 'Ctrl+E', action = IDM_MATCHBRACE},
        {'Select t&o Brace', ru = '�������� �� ������� ������', key = 'Ctrl+Shift+E', action = IDM_SELECTTOBRACE},
        {'Insert Special Char', ru = '�������� ����������', action = function() SpecialChar() end},
        {'Sorting of lines A� z / z� A', ru = '����������� ������ A� z / z� A', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\SortText.lua')"},

        {'S&how Calltip', ru = '���������� ���������', key = 'Ctrl+Shift+Space', action = IDM_SHOWCALLTIP},
        -- {'Complete S&ymbol', ru = '��������� �����(�� API � ������)', key = 'Ctrl+I', action = IDM_COMPLETE},
        {'Complete S&ymbol', ru = '��������� �����(�� API)', key = 'Ctrl++', action= function() ShowListManualy() end},
        {'Complete &Word', ru = '��������� �����(�� ������)', key = 'Ctrl+Enter', action = IDM_COMPLETEWORD},
        {'Expand Abbre&viation', ru = '�������� ����������', key = 'Ctrl+B', action = IDM_ABBREV},
        {'&Insert Abbreviation', ru = '������������ ����������', key = 'Ctrl+Shift+R', action = IDM_INS_ABBREV},
        {'Block Co&mment or Uncomment', ru = '���������������� � ����������������� �����', key = 'Ctrl+Q', action = IDM_BLOCK_COMMENT},
        {'Bo&x Comment', ru = '������� �����������', key = 'Ctrl+Shift+B', action = IDM_BOX_COMMENT},
        {'Stream Comme&nt', ru = '��������� �����������', key = 'Ctrl+Shift+Q', action = IDM_STREAM_COMMENT},
        {'Make &Selection Uppercase', ru = '��������� � ������� �������', key = 'Ctrl+Shift+U', action = IDM_UPRCASE},
        {'Make Selection &Lowercase', ru = '��������� � ������ �������', key = 'Ctrl+U', action = IDM_LWRCASE},
    },},
    {'Search', ru='�����',{
        {'&Find...', ru = '�����', key = 'Ctrl+F', action = IDM_FIND},
        {'Find &Next', ru = '����� �����', key = 'F3', action = IDM_FINDNEXT},
        {'Find Previou&s', ru = '���������� ����������', key = 'Shift+F3', action = IDM_FINDNEXTBACK},
        {'F&ind in Files...', ru = '����� � ������', key = 'Ctrl+Shift+F', action = IDM_FINDINFILES},
        {'R&eplace...', ru = '��������', key = 'Ctrl+H', action = IDM_REPLACE},
        {'s1', separator=1},
        {'&Go to...', ru = '������� �� �������...', key = 'Ctrl+G', action = IDM_GOTO},
        {'Next Book&mark', ru = '��������� ��������', key = 'F2', action = IDM_BOOKMARK_NEXT},
        {'Pre&vious Bookmark', ru = '���������� ��������', key = 'Shift+F2', action = IDM_BOOKMARK_PREV},
        {'Toggle Bookmar&k', ru = '��������/������� ��������', key = 'Ctrl+F2', action = IDM_BOOKMARK_TOGGLE},
        {'&Clear All Bookmarks', ru = '�������� ��� ��������', action = IDM_BOOKMARK_CLEARALL},
    },},
    {'View', ru='���',{
        {'Toggle &current fold', ru = '��������/���������� ������� ���� ������', action = IDM_EXPAND},
        {'Toggle &all folds', ru = '��������/���������� ��� ����� ������', action = IDM_TOGGLE_FOLDALL},
        {'s2', separator=1},
        --[[{'Full Scree&n', ru = '������������� �����', key = 'F11', action = IDM_FULLSCREEN},]]
        --[[{'&Tool Bar', ru = '������ ������������', action = IDM_VIEWTOOLBAR,},]]
        {'Tab &Bar', ru = '�������', action = IDM_VIEWTABBAR, check = "props['tabbar.visible']=='1'"},
        --[[{'&Status Bar', ru = '������ ���������', action = IDM_VIEWSTATUSBAR},]]
        {'s2', separator=1},
        {'&Whitespace', ru = '�������', key = 'Ctrl+Shift+8', action = IDM_VIEWSPACE, check = "props['view.whitespace']=='1'"},
        {'&End of Line', ru = '������� �������� �����', key = 'Ctrl+Shift+9', action = IDM_VIEWEOL, check = "editor.ViewEOL"},
        {'&Indentation Guides', ru = '������������ �������', action = IDM_VIEWGUIDES, check = "props['view.indentation.guides']=='1'"},
        {'&Line Numbers', ru = '������ �����', action = IDM_LINENUMBERMARGIN, check = "props['line.margin.visible']=='1'"},
        {'&Margin', ru = '��������', action = IDM_SELMARGIN, check = "scite.SendEditor(SCI_GETMARGINWIDTHN,1)>0"},
        {'&Fold Margin', ru = '���� ������������ ������ ������', action = IDM_FOLDMARGIN, check = "scite.SendEditor(SCI_GETMARGINWIDTHN,2)>0"},
        {'&Output', ru = '���� �������', key = 'F8', action = IDM_TOGGLEOUTPUT, check = "iup.GetDialogChild(iup.GetLayout(), 'BottomBarSplit').barsize ~= '0'"},
        --[[{'&Parameters', ru = '���������', key = 'Shift+F8', action = IDM_TOGGLEPARAMETERS},]]
    },},
    {'Tools', ru='�����������',{
        {'&Compile', ru = '�������������', key = 'Ctrl+F7', action = IDM_COMPILE},
        {'&Build', ru = '�������', key = 'F7', action = IDM_BUILD},
        {'&Go', ru = '���������', key = 'F5', action = IDM_GO},
        {'&Stop Executing', ru = '���������� ����������', key = 'Ctrl+Break', action = IDM_STOPEXECUTE},
        {'Script', ru='������ ������������',{
            {'Reload', ru = '�������������', key = 'Alt+Ctrl+Shift+R', action = function() scite.PostCommand(POST_SCRIPTRELOAD,0) end,},
        },},
        {'s1', separator=1},
        {'&Next Message', ru = '��������� ���������', key = 'F4', action = IDM_NEXTMSG},
        {'&Previous Message', ru = '���������� ���������', key = 'Shift+F4', action = IDM_PREVMSG},
        {'Clear &Output', ru = '�������� ���� �������', key = 'Shift+F5', action = IDM_CLEAROUTPUT},
        {'&Switch Pane', ru = '��������������/�������', key = 'Ctrl+F6', action = IDM_SWITCHPANE},
    },},
    {'Options', ru='���������',{
        --[[{'{'&Always On Top', ru = '������ ���� ����', action = IDM_ONTOP},
        {'Open Files &Here', ru = '��������� ���� ����� ���������', action = IDM_OPENFILESHERE},
        Vertical &Split',  action = IDM_SPLITVERTICAL},]]
        {'&Wrap', ru = '������� �� ������', action = IDM_WRAP, check = "props['wrap']=='1'"},
        {'Wrap Find &Result', ru = '������� �� ������ � ����������� ������', action = IDM_WRAPFINDRES, check = "props['findrez.wrap']=='1'"},
        {'&Read-Only', ru = '������ ��� ������', action = IDM_READONLY},
        {'s2', separator=1},
        {'Line End Characters', ru='������� �������� �����',{
            {'CR &+ LF',  action = IDM_EOL_CRLF, check = "editor.EOLMode==SC_EOL_CRLF"},
            {'&CR',  action = IDM_EOL_CR, check = "editor.EOLMode==SC_EOL_CR"},
            {'&LF',  action = IDM_EOL_LF, check = "editor.EOLMode==SC_EOL_LF"},
        },},
        {'Output', ru='���� �������',{
            {'Wrap Out&put', ru = '������� �� ������ � �������', action = IDM_WRAPOUTPUT, check = "props['output.wrap']=='1'"},
            {'Clear Before Execute', ru = '������� ����� �����������', check_prop = "clear.before.execute"},
            {'Recode OEM to ANSI', ru = '�������������� OEM � ANSI', check_prop = "output.code.page.oem2ansi"},
        },},
        {'&Convert Line End Characters', ru = '�������������� ������� �������� �����', action = IDM_EOL_CONVERT},
        {'s1', separator=1},
        {'Change Inden&tation Settings...', ru = '�������� ��������� �������', action = IDM_TABSIZE},
        {'Use &Monospaced Font', ru = '������������ ������������ ������', action = IDM_MONOFONT},
        {'s2', separator=1},
        {'Reload Session', ru = '��������������� �������� �����', action = "CheckChange('session.reload', true)", check="props['session.reload']=='1'"},
        {'s3', separator=1},
        -- {'Open Local &Options File', ru = '������� ���� ��������� ��������', action = IDM_OPENLOCALPROPERTIES},
        -- {'Open &Directory Options File', ru = '������� ���� �������� ��������', action = IDM_OPENDIRECTORYPROPERTIES},
        {'Windows Integration', ru = '��������� ���������� � Windows', action="shell.exec(props['SciteDefaultHome']..'\\\\tools\\\\SciTE_WinIntegrator.hta')"},
        {'Open &User Options File', ru = '������� ���� ���������������� ��������', action = IDM_OPENUSERPROPERTIES},
        {'Open &Global Options File', ru = '������� ���� ���������� ��������', action = IDM_OPENGLOBALPROPERTIES},
        --[[{'Open A&bbreviations File', ru = '������� ���� �������� ����������', action = IDM_OPENABBREVPROPERTIES},]]
        {'Open Lua Startup Scr&ipt', ru = '������� ���� ������������ �������', action = IDM_OPENLUAEXTERNALFILE},
        {'Edit properties', ru='�������� �������',tLangs},
    },},
    {'Language', ru='���������',{
        {'tHilight', tHilight, plane = 1},
        {'s1', separator=1},
    },},
    {'Buffers', ru='�������',{
        {'&Previous', ru = '����������', key = 'Shift+F6', action = IDM_PREVFILE},
        {'&Next', ru = '���������', key = 'F6', action = IDM_NEXTFILE},
        {'Move Tab &Left', ru = '����������� �����', action = IDM_MOVETABLEFT},
        {'Move Tab &Right', ru = '����������� ������', action = IDM_MOVETABRIGHT},
        {'&Close All', ru = '������� ���', action = IDM_CLOSEALL},
        {'&Save All', ru = '��������� ���', action = IDM_SAVEALL},
        {'s2', separator=1},
        {'l1', windowsList, plane = 1},
    },},
    {'Help', ru='�������',{
        {'&Help', ru = '������� �� LUA', key = 'F1', action = IDM_HELP},
        {'&SciTE Help', ru = '������� �� SciTE', action = IDM_HELP_SCITE},
        {'&About SciTE', ru = '� ���������', action = IDM_ABOUT},
    },},
}

