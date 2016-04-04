--[[
������ ���� - ���������� ��������� � ����������(� ������ �������) �������������
��� ������� ������ ���� - ������� �� �������� �������, ������� � ������������. ������� �������, �������������� ���� - ������� �������
��������:
    - <nls> - ��������� �� �����
    - key - �����������
    - key_external - ��� �� ����� ��������������
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
_G.sys_Menus = {}
_G.sys_Menus.MainWindowMenu = {
    {'File', ru='����',{
        {'New', ru='�������', key = 'Ctrl+N', idm = IDM_NEW},
        {'&Open...', ru = '�������', key = 'Ctrl+O', idm = IDM_OPEN},
        {'Open Selected &Filename', ru = '������� ���������� ����', key = 'Ctrl+Shift+O', idm = IDM_OPENSELECTED},
        {'&Revert', ru = '������������� ����', key = 'Ctrl+R', idm = IDM_REVERT},
        {'&Close', ru = '�������', key = 'Ctrl+W', idm = IDM_CLOSE},
        {'&Save', ru = '���������', key = 'Ctrl+S', idm = IDM_SAVE},
        {'Save &As...', ru = '��������� ���...', key = 'Ctrl+Shift+S', idm = IDM_SAVEAS},
        {'Save a Cop&y...', ru = '��������� �����...', key = 'Ctrl+Shift+P', idm = IDM_SAVEACOPY},
        {'Copy Pat&h', ru = '', idm = IDM_COPYPATH},
        {'Encoding', ru='���������',{
            {'&Code Page Property', ru='�������� ���������� codepage', idm = IDM_ENCODING_DEFAULT, check_idm='editor.unicode.mode'},
            {'UTF-16 &Big Endian', ru = '', idm = IDM_ENCODING_UCS2BE, check_idm='editor.unicode.mode', check='tonumber(props["editor.unicode.mode"])==IDM_ENCODING_UCS2BE'},
            {'UTF-16 &Little Endian', ru = '', idm = IDM_ENCODING_UCS2LE},
            {'UTF-8 &with BOM', ru='UTF-8 � ����������', idm = IDM_ENCODING_UTF8},
            {'&UTF-8', ru = '', idm = IDM_ENCODING_UCOOKIE},
        },},
        {'&Export', ru='�������',{
            {'As &HTML...', ru = '', idm = IDM_SAVEASHTML},
            {'As &RTF...', ru = '', idm = IDM_SAVEASRTF},
            {'As &PDF...', ru = '', idm = IDM_SAVEASPDF},
            {'As &LaTeX...', ru = '', idm = IDM_SAVEASTEX},
            {'As &XML...', ru = '', idm = IDM_SAVEASXML},
        },},
        {'s1', separator=1},
        {'Page Set&up...', ru = '��������� ��������', idm = IDM_PRINTSETUP},
        {'&Print...', ru = '������...', key = 'Ctrl+P', idm = IDM_PRINT},
        {'s2', separator=1},
        {'&Load Session...', ru = '��������� ������...', idm = IDM_LOADSESSION},
        {'Sa&ve Session...', ru = '��������� ������...', idm = IDM_SAVESESSION},
        {'s3', separator=1},
        {'Exit', ru='�����', idm = IDM_QUIT},
    },},
    {'Edit', ru='������',{
        {'&Undo', ru = '��������', key = 'Ctrl+Z',key_external = 1, idm = IDM_UNDO},
        {'&Redo', ru = '���������', key = 'Ctrl+Y',key_external = 1, idm = IDM_REDO},
        {'s1',  separator=1},
        {'Cu&t', ru = '��������', key = 'Ctrl+X',key_external = 1, idm = IDM_CUT, active="editor.SelectionStart<editor.SelectionEnd"},
        {'&Copy', ru = '����������', key = 'Ctrl+C',key_external = 1, idm = IDM_COPY, active="editor.SelectionStart<editor.SelectionEnd"},
        {'&Paste', ru = '��������', key = 'Ctrl+V',key_external = 1, idm = IDM_PASTE},
        {'Duplicat&e', ru = '�����������', key = 'Ctrl+D',key_external = 1, idm = IDM_DUPLICATE},
        {'&Delete', ru = '�������', key = 'Del',key_external = 1, idm = IDM_CLEAR},
        {'Select &All', ru = '������� ���', key = 'Ctrl+A',key_external = 1, idm = IDM_SELECTALL, active="editor.SelectionStart<editor.SelectionEnd"},
        {'Copy as RT&F', ru = '���������� � ������� RTF', idm = IDM_COPYASRTF, active="editor.SelectionStart<editor.SelectionEnd"},
        {'s2', separator=1},
        {'Match &Brace', ru = '����� ������ ������', key = 'Ctrl+E', idm = IDM_MATCHBRACE},
        {'Select t&o Brace', ru = '�������� �� ������ ������', key = 'Ctrl+Shift+E', idm = IDM_SELECTTOBRACE},
        {'S&how Calltip', ru = '���������� ���������', key = 'Ctrl+Shift+Space', idm = IDM_SHOWCALLTIP},
        {'Complete S&ymbol', ru = '��������� �����(�� API � ������)', key = 'Ctrl+I', idm = IDM_COMPLETE},
        {'Complete &Word', ru = '��������� �����(�� ������)', key = 'Ctrl+Enter', idm = IDM_COMPLETEWORD},
        {'Expand Abbre&viation', ru = '�������� ����������', key = 'Ctrl+B', idm = IDM_ABBREV},
        {'&Insert Abbreviation', ru = '������������ ����������', key = 'Ctrl+Shift+R', idm = IDM_INS_ABBREV},
        {'Block Co&mment or Uncomment', ru = '��������������� � ���������������� �����', key = 'Ctrl+Q', idm = IDM_BLOCK_COMMENT},
        {'Bo&x Comment', ru = '������� �����������', key = 'Ctrl+Shift+B', idm = IDM_BOX_COMMENT},
        {'Stream Comme&nt', ru = '��������� �����������', key = 'Ctrl+Shift+Q', idm = IDM_STREAM_COMMENT},
        {'Make &Selection Uppercase', ru = '��������� � ������� �������', key = 'Ctrl+Shift+U', idm = IDM_UPRCASE},
        {'Make Selection &Lowercase', ru = '��������� � ������ �������', key = 'Ctrl+U', idm = IDM_LWRCASE},
    },},
    {'Search', ru='�����',{
        {'&Find...', ru = '�����', key = 'Ctrl+Alt+Shift+F', idm = IDM_FIND},
        {'Find &Next', ru = '����� �����', key = 'F3', idm = IDM_FINDNEXT},
        {'Find Previou&s', ru = '���������� ����������', key = 'Shift+F3', idm = IDM_FINDNEXTBACK},
        {'F&ind in Files...', ru = '����� � ������', key = 'Ctrl+Shift+F', idm = IDM_FINDINFILES},
        {'R&eplace...', ru = '��������', key = 'Ctrl+H', idm = IDM_REPLACE},
        {'s1', separator=1},
        {'&Go to...', ru = '������� �� �������...', key = 'Ctrl+G', idm = IDM_GOTO},
        {'Next Book&mark', ru = '��������� ��������', key = 'F2', idm = IDM_BOOKMARK_NEXT},
        {'Pre&vious Bookmark', ru = '���������� ��������', key = 'Shift+F2', idm = IDM_BOOKMARK_PREV},
        {'Toggle Bookmar&k', ru = '��������/������� ��������', key = 'Ctrl+F2', idm = IDM_BOOKMARK_TOGGLE},
        {'&Clear All Bookmarks', ru = '�������� ��� ��������', idm = IDM_BOOKMARK_CLEARALL},
    },},
    {'View', ru='���',{
        {'Toggle &current fold', ru = '��������/���������� ������� ���� ������', idm = IDM_EXPAND},
        {'Toggle &all folds', ru = '��������/���������� ��� ����� ������', idm = IDM_TOGGLE_FOLDALL},
        {'s2', separator=1},
        {'Full Scree&n', ru = '������������� �����', key = 'F11', idm = IDM_FULLSCREEN},
        {'&Tool Bar', ru = '������ ������������', idm = IDM_VIEWTOOLBAR},
        {'Tab &Bar', ru = '�������', idm = IDM_VIEWTABBAR},
        {'&Status Bar', ru = '������ ���������', idm = IDM_VIEWSTATUSBAR},
        {'s2', separator=1},
        {'&Whitespace', ru = '�������', key = 'Ctrl+Shift+8', idm = IDM_VIEWSPACE},
        {'&End of Line', ru = '������� �������� �����', key = 'Ctrl+Shift+9', idm = IDM_VIEWEOL},
        {'&Indentation Guides', ru = '������������ �������', idm = IDM_VIEWGUIDES},
        {'&Line Numbers', ru = '������ �����', idm = IDM_LINENUMBERMARGIN},
        {'&Margin', ru = '��������', idm = IDM_SELMARGIN},
        {'&Fold Margin', ru = '���� ������������ ������ ������', idm = IDM_FOLDMARGIN},
        {'&Output', ru = '���� �������', key = 'F8', idm = IDM_TOGGLEOUTPUT},
        {'&Parameters', ru = '���������', key = 'Shift+F8', idm = IDM_TOGGLEPARAMETERS},
    },},
    {'Tools', ru='�����������',{
        {'&Compile', ru = '�������������', key = 'Ctrl+F7', idm = IDM_COMPILE},
        {'&Build', ru = '�������', key = 'F7', idm = IDM_BUILD},
        {'&Go', ru = '���������', key = 'F5', idm = IDM_GO},
        {'&Stop Executing', ru = '���������� ����������', key = 'Ctrl+Break', idm = IDM_STOPEXECUTE},
        {'Script', ru='������ ������������',{
            {'Reload', ru = '�������������', key = 'Alt+Ctrl+Shift+R', --[[idm = 9117]] action = function() scite.PostCommand(5,0) end,},
        },},
        {'s1', separator=1},
        {'&Next Message', ru = '��������� ���������', key = 'F4', idm = IDM_NEXTMSG},
        {'&Previous Message', ru = '���������� ���������', key = 'Shift+F4', idm = IDM_PREVMSG},
        {'Clear &Output', ru = '�������� ���� �������', key = 'Shift+F5', idm = IDM_CLEAROUTPUT},
        {'&Switch Pane', ru = '��������������/�������', key = 'Ctrl+F6', idm = IDM_SWITCHPANE},
    },},
    {'Options', ru='���������',{
        {'&Always On Top', ru = '������ ���� ����', idm = IDM_ONTOP},
        {'Open Files &Here', ru = '��������� ���� ����� ���������', idm = IDM_OPENFILESHERE},
        --[[{'Vertical &Split', ru = '', idm = IDM_SPLITVERTICAL},]]
        {'&Wrap', ru = '������� �� ������', idm = IDM_WRAP},
        {'Wrap Out&put', ru = '������� �� ������ � �������', idm = IDM_WRAPOUTPUT},
        {'Wrap Find &Result', ru = '������� �� ������ � ���� �����������', idm = IDM_WRAPFINDRES},
        {'&Read-Only', ru = '������ ��� ������', idm = IDM_READONLY},
        {'s2', separator=1},
        {'Line End Characters', ru='������� �������� �����',{
            {'CR &+ LF', ru = '', idm = IDM_EOL_CRLF},
            {'&CR', ru = '', idm = IDM_EOL_CR},
            {'&LF', ru = '', idm = IDM_EOL_LF},
        },},
        {'&Convert Line End Characters', ru = '�������������� ������� �������� �����', idm = IDM_EOL_CONVERT},
        {'s1', separator=1},
        {'Change Inden&tation Settings...', ru = '�������� ��������� �������', idm = IDM_TABSIZE},
        {'Use &Monospaced Font', ru = '������������ ������������ ������', idm = IDM_MONOFONT},
        {'s2', separator=1},
        {'Open Local &Options File', ru = '������� ���� ��������� ��������', idm = IDM_OPENLOCALPROPERTIES},
        {'Open &Directory Options File', ru = '������� ���� �������� ��������', idm = IDM_OPENDIRECTORYPROPERTIES},
        {'Open &User Options File', ru = '������� ���� ���������������� ��������', idm = IDM_OPENUSERPROPERTIES},
        {'Open &Global Options File', ru = '������� ���� ���������� ��������', idm = IDM_OPENGLOBALPROPERTIES},
        --[[{'Open A&bbreviations File', ru = '������� ���� �������� ����������', idm = IDM_OPENABBREVPROPERTIES},]]
        {'Open Lua Startup Scr&ipt', ru = '������� ���� ������������ �������', idm = IDM_OPENLUAEXTERNALFILE},
        {'Edit properties', ru='�������� �������',{
            {'s1', separator=1},
        },},
    },},
    {'Language', ru='���������',{
        {'s1', separator=1},
    },},
    {'Buffers', ru='�������',{
        {'&Previous', ru = '����������', key = 'Shift+F6', idm = IDM_PREVFILE},
        {'&Next', ru = '���������', key = 'F6', idm = IDM_NEXTFILE},
        {'Move Tab &Left', ru = '����������� �����', idm = IDM_MOVETABLEFT},
        {'Move Tab &Right', ru = '����������� ������', idm = IDM_MOVETABRIGHT},
        {'&Close All', ru = '������� ���', idm = IDM_CLOSEALL},
        {'&Save All', ru = '��������� ���', idm = IDM_SAVEALL},
    },},
    {'Help', ru='�������',{
        {'&Help', ru = '������� �� LUA', key = 'F1', idm = IDM_HELP},
        {'&SciTE Help', ru = '������� �� SciTE', idm = IDM_HELP_SCITE},
        {'&About SciTE', ru = '� ���������', idm = IDM_ABOUT},
    },},
    {'_HIDDEN_', {
        {'Ctrl+Tab', key = 'Ctrl+Tab', idm = IDM_NEXTFILESTACK},
        {'Ctrl+Shift+Tab', key = 'Ctrl+Shift+Tab', idm = IDM_PREVFILESTACK},
    },},
}

