--[[
первое поле - английский заголовок и уникальный(в данном подменю) идентификатор
для подменю второе поле - таблица со строками итемами, подменю и сепараторами. Или функция, возвращающая такую таблицу. Наличие второго, неименованного поля - признак саюменю
атрибуты:
	- <nls> - заголовок на языке
	- key - акселератор
	- key_external - акселератор не нужно регистрировать
	Для подменю, построенных по функциям
	plane - пункты добавляются в основное меню
	Доступность пунктов
	- active - строка с логическим выражением, возвращающим true или false
	Видимость
	- visible  - строка с логическим выражением, возвращающим true или false
	- visible_ext - список расширений файлов, для которых пункт видимый
	отмечено
	- check_idm prop, который нужно сравнить с idm
	- check  - строка с логическим выражением, возвращающим true или false
	- check_prop
	- check_iuprops
	- check_boolean
	действие
	- idm - идентификатор меню скайта
	- action
	- action_lua
	- action_cmd
]]
require 'shell'
function CORE.windowsList(side)
	local t = {}
	local maxN = scite.buffers.GetCount() - 1
	for i = 0, maxN do
        if not side or (scite.buffers.GetBufferSide(i) == side) then
            local row = {}
            local s = scite.buffers.NameAt(i):gsub('(.+)[\\]([^\\]*)$', '%2\t%1')
            local md = Iif(scite.buffers.SavedAt(i), '', '*')

            row[1] = md..s
            row.order = s:upper()
            row.action = "scite.buffers.SetDocumentAt("..i..")"
            t[#t + 1] = row
        end
	end
	table.sort(t, function(a, b)
		return a.order < b.order
	end)
	return t
end

local function DoSett(strMethod, ...)
    dolocale("tools\\SettingDialogs.lua")[strMethod](...)
end

function CORE.ResetGlobalColors()
    DoSett('ResetGlobalColors')
end
function CORE.OpenNewInstance(f)
    DoSett('OpenNewInstance', f)
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
    local s = scintilla()

	return s.SelectionStart < s.SelectionEnd
end

local function switchCase(cmd)
    if scintilla().SelectionStart == scintilla().SelectionEnd then editor:WordLeftExtend() end
    scite.MenuCommand(cmd)
end

local function ResetReadOnly()
    BlockEventHandler"OnSwitchFile"
	local attr = shell.getfileattr(props['FilePath'])
	if (attr & 1) == 1 then
		attr = attr - 1
	else
		attr = attr + 1
	end
	shell.setfileattr(props['FilePath'], attr)
	CORE.DoRevert()
    UnBlockEventHandler"OnSwitchFile"
end

local function RunSettings()
    for s, _ in pairs(dialogs) do
        if s == 'commandsplugin' or s == 'sidebarlayout' or s == 'LexersSetup' or
           s == 'toolbarlayout' or s == 'usertb' or s == 'HotkeysSetup' or
           s == 'lexerColors' then return false end
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

local function checkEncoding(e, cp)
    return function()
        if e ~= IDM_ENCODING_DEFAULT then
            return math.tointeger(props['editor.unicode.mode']) == e
        end
        return (scite.buffers.EncodingAt(scite.buffers.GetCurrent()) == cp) or
                (scite.buffers.EncodingAt(scite.buffers.GetCurrent()) == 0 and math.tointeger(props['system.code.page']) == cp)
    end
end

local function SetCP(u, cp)
    return function() CORE.SetCP(u, cp) end
end

local function SetLocale(l)
    return function()
        props['locale'] = l
        scite.RunAsync(iup.ReloadScript)
    end
end

local function activeRecoding(e, cp)
    return function()
        if cp == math.tointeger(props['system.code.page']) then cp = 0 end
        return (props['editor.unicode.mode'] ~= ''..e) or
            (cp ~= scite.buffers.EncodingAt(scite.buffers.GetCurrent()))
    end
end

local function ChangeCode(e, cp)
    return function() CORE.ChangeCode(e, cp) end
end

local function CanToggle()
    local lStart = editor:LineFromPosition(editor.SelectionStart)
    local baseLevel = (editor.FoldLevel[lStart] & SC_FOLDLEVELNUMBERMASK)
    return (baseLevel > SC_FOLDLEVELBASE and (baseLevel & SC_FOLDLEVELHEADERFLAG) == 0)
end

local bCanPaste = true
AddEventHandler("OnDrawClipboard", function(flag)
	bCanPaste = (flag > 0)
end)

local t = {}
if _G.iuprops['settings.lexers'] then
    local t = _G.iuprops['settings.lexers']
    for i = 1, #t do
        table.insert(tHilight,{t[i].view, action = function() scite.SetLexer(t[i].ext) end, check = function() return editor_LexerLanguage() == t[i].name end})
        table.insert(tLangs, {"Open "..t[i].file, action = function() scite.Open(props["SciteDefaultHome"].."\\languages\\"..t[i].file) end})
    end
end

_G.sys_Menus.TABBAR = { title = _TM"Tabbar Context Menu",
	{link='File|Close'},
	{link='File|Close All'},
	{'Close All But Current',   action=function() iup.CloseFilesSet(9132, nil, true); OnSwitchFile(props['FilePath']) end, },
	{'Close All Temporally',   action=function() iup.CloseFilesSet(9134) end, visible=IsOpenTemporaly },
	{'s1', separator=1},
	{link='File|Save'},
	{link='Window|Save All'},
	{link='File|Save As...'},
	{link='File|Save Copy...'},
    {'s1', separator = 1},
    {link='File|Move to another view'},
    {link = 'File|Clone to another view'},
    {'Open in New HildiM Instance', action = function() DoSett('OpenNewInstance', props['FilePath']) end,},
	{'s2', separator=1},
	{'Copy to Clipboard', {
		{'All Text', action = function() CopyPathToClipboard("text") end,},
		{'Path/File Name', action = function() CopyPathToClipboard("all") end,},
		{'Path', action = function() CopyPathToClipboard("path") end,},
		{'File Name',  action = function() CopyPathToClipboard("name") end,},
	}},
    {link='Options|Tabbar Settings'},
	{link='File|Encoding'},
	{link = 'Options|Read-Only'},
    {'Open File Folder', action = function()
        shell.exec(Iif(not _G.iuprops['settings.tabmenu.opencmd'], 'explorer "'..props['FileDir']..'"', (_G.iuprops['settings.tabmenu.opencmd'] or ''):gsub('%%P', props['FileDir'])))  end},

	{'slast', separator=1},
}

_G.sys_Menus.OUTPUT = {title = _TM"Console Context Menu",
	{link = 'Edit|Regular|Cut'},
	{link = 'Edit|Regular|Copy'},
	{link = 'Edit|Regular|Paste'},
	{link = 'Edit|Regular|Delete'},
	{'s1', separator = 1},
	{link = 'Tools|Output|Clear Output'},
	{link = 'Tools|Output|Previous Message'},
	{link = 'Tools|Output|Next Message'},
	{'s2', separator = 1},
	{'Input Mode',  {
		{'Display Mode',  action = function() output:DocumentEnd();output:ReplaceSel('###?\n') end},
		{'Command Line Mode',  action = function() output:DocumentEnd();output:ReplaceSel('###c') end},
		{'LUA Mode',  action = function() output:DocumentEnd();output:ReplaceSel('###l') end},
		{'LUA Expressions Mode',  action = function() output:DocumentEnd();output:ReplaceSel('###p') end},
		{'IDM command Mode',  action = function() output:DocumentEnd();output:ReplaceSel('###i') end},
		{'Switch OFF',  action = function() output:DocumentEnd();output:ReplaceSel('####') end},
	}},
    {'Settings', {
        {'Wrap Output',  action = IDM_WRAPOUTPUT, check = "props['output.wrap']=='1'"},
        {'Clear Before Execute',  check_prop = "clear.before.execute"},
        {'Recode OEM to ANSI',  check_prop = "output.code.page.oem2ansi"},
        {'Autoshow When Output',  check_iuprops = "concolebar.autoshow"},
    },},
	{'slast', separator = 1},
}

_G.sys_Menus.FINDRES = {title = _TM"Find Results Context Menu",
	{link = 'Edit|Regular|Cut'},
	{link = 'Edit|Regular|Copy'},
	{link = 'Edit|Regular|Paste'},
	{link = 'Edit|Regular|Delete'},
	{'s1', separator = 2},
	{link = 'Tools|Output|Clear Find Result'},
    {'Settings', {
        {'DblClick By Line Number Only',  check_boolean = 'findres.clickonlynumber'},
        {'Group By Name',  check_boolean = 'findres.groupbyfile'},
        {'Wrap Find Result',  action = IDM_WRAPFINDRES, check = "props['findres.wrap']=='1'"},
        {'Number Of Find Results...',  action = function() DoSett('SetFindresCount') end},
    }},
	{'Open Files', plane = 1, visible = "findres.StyleAt[findres.CurrentPos] == SCE_SEARCHRESULT_SEARCH_HEADER" ,{
		{'s_OpenFiles', separator = 1},
		{'Open Files',  action = function() CORE.OpenFoundFiles(1) end, },
		{'Close Files',  action = function() CORE.OpenFoundFiles(2) end, },
		{'Close If Not Found',  action = function() CORE.OpenFoundFiles(3) end, },
	}},
	{'slast', separator = 1},

}

_G.sys_Menus.EDITMARGIN = {title = _TM"Editor Margin Context Menu",
    {'Toggle &all folds', action = IDM_TOGGLE_FOLDALL},
    {'Toggle &current fold', action = IDM_EXPAND, active = CanToggle},
    {'Toggle &Recursively current fold', action = IDM_TOGGLE_FOLDRECURSIVE, active = CanToggle},
    {'&Collapse...', key = 'Ctrl+Shift+-', action = "CORE.ToggleSubfolders(false)"},
    {'&Expand...', key = 'Ctrl+Shift++', action = "CORE.ToggleSubfolders(true)"},
    {'s1', separator = 1},
    {'Go to def&inition(Ctrl+Click)', key = 'F12', action = "menu_GoToObjectDefenition()"},
    {'Next &Bookmark', key = 'F2', action = IDM_BOOKMARK_NEXT, image = 'bookmark__arrow_µ'},
    {'Previous Boo&kmark', key = 'Shift+F2', action = IDM_BOOKMARK_PREV, image = 'bookmark__arrow_left_µ'},
    {'To&ggle Bookmark',  key = 'Ctrl+F2', action = IDM_BOOKMARK_TOGGLE, image = 'bookmark_µ'},
    {'Clear All Bookmark&s', action = IDM_BOOKMARK_CLEARALL},
    {'slast', separator = 1},

}

_G.sys_Menus.EDITOR = {title = _TM"Editor Context Menu",
	{'s0', link='Edit|Regular|Undo'},
	{link='Edit|Regular|Redo'},
	{'s1', separator=1},
	{link='Edit|Regular|Cut'},
	{link='Edit|Regular|Copy'},
	{link='Edit|Regular|Paste'},
	{link='Edit|Regular|Delete'},
	{link='Edit|Regular|Duplicate'},
	{'s1', separator=2},
	{link='Edit|Regular|Select All'},
	{link='Search|Search', plane=0},
	--{link='View|Folding', plane=0},
	{link='Search|Toggle Bookmark'},
	{link='Search|Go to definition(Ctrl+Click)'},
}

_G.sys_Menus.MainWindowMenu = {title = _TM"Main Window Menu",
	{'_HIDDEN_', {
		{'Next Tab', key = 'Ctrl+Tab', action = function() if iup.GetFocus() then iup.PassFocus() end scite.MenuCommand(IDM_NEXTFILESTACK) end},
		{'Previouse Tab', key = 'Ctrl+Shift+Tab', action = function() if iup.GetFocus() then iup.PassFocus() end scite.MenuCommand(IDM_PREVFILESTACK) end},
		{'Block Home', key = 'Alt+Home', action = function() editor:VCHomeRectExtend() end},
		{'Block End', key = 'Alt+End', action = function() editor:LineEndRectExtend() end},
		{'Block Page Up', key = 'Alt+PageUp', action = function() editor:PageUpRectExtend() end},
		{'Block Page Down', key = 'Alt+PageDown', action = function() editor:PageDownRectExtend() end},
		{'EditVScroll', {
            {link = 'Search|Search|Clear Live Search Markers'},
            {'Scroll Here', action = function() _SCROLLTO() end},
		},},
		{'AllScroll', {
            {'Scroll Here', action = function() _SCROLLTO() end},
		},},
	},},
	{'&File', {
		{'&New', key = 'Ctrl+N', action = IDM_NEW, image = 'document__plus_µ'},
		{'&Open...',  key = 'Ctrl+O', action = IDM_OPEN, image = 'folder_open_document_µ'},
		{'Open New HildiM Instan&ce', action = function() DoSett('OpenNewInstance','') end, },
		{'&Recent Files', visible = "(_G.iuprops['resent.files.list.location'] or 0) == 0", function() if (_G.iuprops['resent.files.list.location'] or 0) == 0 then return iuprops['resent.files.list']:GetMenu() else return {} end end},
		{'R&eopen File', key = 'Ctrl+Shift+O', action = function() CORE.Revert() end},
		{'&Close', key = 'Ctrl+F4', action = IDM_CLOSE},
		{'Close &All',  action = IDM_CLOSEALL},
		{'&Save', key = 'Ctrl+S', action = IDM_SAVE, active = function() return editor.Modify end, image = 'disk_µ'},
		{'Sa&ve As...', key = 'Ctrl+Shift+S', action = IDM_SAVEAS, image = 'disk__pencil_µ'},
		{'Save Cop&y...',  key = 'Ctrl+Shift+P', action = IDM_SAVEACOPY, image = 'disk__plus_µ'},
		--[[{'Copy Pat&h',  action = IDM_COPYPATH},]]
		{'Encod&ing', { radio = 1,
			{'ISO-8859-5', action = SetCP(IDM_ENCODING_DEFAULT, 28595), check = checkEncoding(IDM_ENCODING_DEFAULT, 28595)},
			{'KOI8_R', action = SetCP(IDM_ENCODING_DEFAULT, 20866), check = checkEncoding(IDM_ENCODING_DEFAULT, 20866)},
			{'KOI8_U', action = SetCP(IDM_ENCODING_DEFAULT, 21866), check = checkEncoding(IDM_ENCODING_DEFAULT, 21866)},
			{'Macintosh', action = SetCP(IDM_ENCODING_DEFAULT, 10007), check = checkEncoding(IDM_ENCODING_DEFAULT, 10007)},
			{'OEM855', action = SetCP(IDM_ENCODING_DEFAULT, 855), check = checkEncoding(IDM_ENCODING_DEFAULT, 855)},
			{'OEM866', action = SetCP(IDM_ENCODING_DEFAULT, 866), check = checkEncoding(IDM_ENCODING_DEFAULT, 866)},
			{'WIN-1251', action = SetCP(IDM_ENCODING_DEFAULT, 1251), check = checkEncoding(IDM_ENCODING_DEFAULT, 1251)},
			{'UTF-16 Big Endian', action = SetCP(IDM_ENCODING_UCS2BE), check = checkEncoding(IDM_ENCODING_UCS2BE)},
			{'UTF-16 Little Endian', action = SetCP(IDM_ENCODING_UCS2LE), check = checkEncoding(IDM_ENCODING_UCS2LE)},
			{'UTF-8 with BOM',  action = SetCP(IDM_ENCODING_UTF8), check = checkEncoding(IDM_ENCODING_UTF8)},
			{'UTF-8', action = SetCP(IDM_ENCODING_UCOOKIE), check = checkEncoding(IDM_ENCODING_UCOOKIE)},
		},},
		{'Expor&t',{
			{'As HTML...' ,  action = IDM_SAVEASHTML},
			{'As RTF...'  ,  action = IDM_SAVEASRTF},
			{'As PDF...'  ,  action = IDM_SAVEASPDF},
			{'As LaTeX...',  action = IDM_SAVEASTEX},
			{'As XML...'  ,  action = IDM_SAVEASXML},
		},},
		{'s1', separator = 1},
		{'Save Session&...',  action = iup.SaveSession,},
		{'&Load Session...', action = iup.LoadSession,},
		{'s2', separator = 1},
		{'Pa&ge Setup...',  action = IDM_PRINTSETUP, image = 'layout_design_µ'},
		{'&Print...', key = 'Ctrl+P', action = IDM_PRINT, image = 'printer_µ'},
		{'s3', separator = 1},
        {'&Move to another view', action = IDM_CHANGETAB, visible = "scite.buffers.IsCloned(scite.buffers.GetCurrent())==0"},
        {'Clone to another vie&w', action = IDM_CLONETAB, visible = "scite.buffers.IsCloned(scite.buffers.GetCurrent())==0" },
        {'s4', separator = 1},
		{'E&xit',  action = function() scite.RunAsync(function() scite.MenuCommand(IDM_QUIT) end) end },
        {'sLast', separator = 1},
        {'Recent Files1', plane = 1, visible = "(_G.iuprops['resent.files.list.location'] or 0) == 1", function() if (_G.iuprops['resent.files.list.location'] or 0) == 1 then return iuprops['resent.files.list']:GetMenu() else return {} end end},
	},},
	{'&Edit', {
		{'&Regular',  {
			{'&Undo',  key = 'Ctrl+Z', key_external = 1, action = IDM_UNDO, active = function() return scintilla():CanUndo() end, image = 'arrow_return_270_left_µ'},
			{'&Redo',  key = 'Ctrl+Y', key_external = 1, action = IDM_REDO, active = function() return scintilla():CanRedo() end, image = 'arrow_return_270_µ'},
			{'s1', separator = 1},
			{'C&ut',  key = 'Ctrl+X', key_external = 1, action = IDM_CUT, active = IsSelection, image = 'scissors_µ'},
			{'&Copy',  key = 'Ctrl+C', key_external = 1, action = IDM_COPY, active = IsSelection, image = 'document_copy_µ'},
			{'&Paste',  key = 'Ctrl+V', key_external = 1, action = IDM_PASTE, image = 'clipboard_paste_µ', active = function() return bCanPaste end,},
			{'Du&plicate',  key = 'Ctrl+D', key_external = 1, action = IDM_DUPLICATE, image = 'yin_yang_µ'},
			{'&Delete',  key = 'Del', key_external = 1, action = IDM_CLEAR, image = 'cross_script_µ'},
			{'Select &All',  key = 'Ctrl+A', key_external = 1, action = IDM_SELECTALL},
			{'Copy as &RTF',  action = IDM_COPYASRTF, active = IsSelection},
		}},
		{'&Xml',  visible_ext = 'xml,form,rform,cform,wform,xsd',{
			{'Format Xml',  action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\FormatXml.lua')", image = 'broom_code_µ',},
		}},
		{'s1', separator = 1},
		{'Auto&format',  {
			{'Format &Block',  action = function() if Format_Block then Format_Block() end end, key = 'Ctrl+]'},
			{'Format &Line',  action = function() if Format_String then Format_String() end end, key = 'Ctrl+['},
			{'Auto &Indent',  check_iuprops = 'autoformat.indent', key = 'Ctrl+Shift+]'},
			{'&Autoformat Lines',  check_iuprops = 'autoformat.line', key = 'Ctrl+Shift+['},
 			{'Autoformat &with Indent',  check_iuprops = 'autoformat.indent.force', active = function() return (_G.iuprops['autoformat.indent'] or 1) == 1 end},
        }},
		{'Matc&h Brace',  key = 'Ctrl+E', action = IDM_MATCHBRACE},
		{'Select to &Brace',  key = 'Ctrl+Shift+E', action = IDM_SELECTTOBRACE},
		{'s2', separator = 1},
		{'Show Ca&lltip',  key = 'Ctrl+?', action = function() ShowTipManualy() end, image = 'ui_tooltip_balloon_bottom_µ',},
		{'Complete Word(from AP&I)',  key = 'Ctrl++', action = function() ShowListManualy() end},
		{'Complete Word(from &Text)',  key = 'Ctrl+Enter', action = IDM_COMPLETEWORD},
		{'Autocomplete List Autodispla&y',  check_prop = 'autocompleteword.automatic'},
		{'s2', separator = 1},
        {('&Expand Abbreviation (‹‡›=selection)'):to_utf8(), key = 'Ctrl+B', action = IDM_ABBREV, image = 'key_µ'},
		{('Ex&pand Abbreviation (‹‡›=Clipboard)'):to_utf8(), key = 'Ctrl+Alt+B', action = IDM_INS_ABBREV, image = 'key__plus_µ'},
		{'s3', separator = 1},
        {'Comment or &Uncomment',  key = 'Ctrl+Q', action = CORE.xComment, image = 'edit_signiture_µ'},
		{'Bloc&k Comment',  action = IDM_BLOCK_COMMENT, visible = "props['comment.stream.start.'..editor_LexerLanguage()]~='' and props['comment.block.'..editor_LexerLanguage()]~=''"},
		{'Strea&m Comment',  key = 'Ctrl+Shift+Q', action = IDM_STREAM_COMMENT, visible = "props['comment.stream.start.'..editor_LexerLanguage()]~='' and props['comment.block.'..editor_LexerLanguage()]~=''"},
		{'B&ox Comment',  key = 'Ctrl+Shift+B', action = IDM_BOX_COMMENT, visible = "props['comment.box.start.'..editor_LexerLanguage()]~=''"},
        {'&Decode  to', {
			{'ISO-8859-5', action = ChangeCode(IDM_ENCODING_DEFAULT, 28595), active = activeRecoding(IDM_ENCODING_DEFAULT, 28595)},
			{'KOI8_R', action = ChangeCode(IDM_ENCODING_DEFAULT, 20866), active = activeRecoding(IDM_ENCODING_DEFAULT, 20866)},
			{'KOI8_U', action = ChangeCode(IDM_ENCODING_DEFAULT, 21866), active = activeRecoding(IDM_ENCODING_DEFAULT, 21866)},
			{'Macintosh', action = ChangeCode(IDM_ENCODING_DEFAULT, 10007), active = activeRecoding(IDM_ENCODING_DEFAULT, 10007)},
			{'OEM855', action = ChangeCode(IDM_ENCODING_DEFAULT, 855), active = activeRecoding(IDM_ENCODING_DEFAULT, 855)},
			{'OEM866', action = ChangeCode(IDM_ENCODING_DEFAULT, 866), active = activeRecoding(IDM_ENCODING_DEFAULT, 866)},
			{'WIN-1251', action = ChangeCode(IDM_ENCODING_DEFAULT, 1251), active = activeRecoding(IDM_ENCODING_DEFAULT, 1251)},
			{'UTF-16 Big Endian', action = ChangeCode(IDM_ENCODING_UCS2BE), active = activeRecoding(IDM_ENCODING_UCS2BE)},
			{'UTF-16 Little Endian', action = ChangeCode(IDM_ENCODING_UCS2LE), active = activeRecoding(IDM_ENCODING_UCS2LE)},
			{'UTF-8 with BOM',  action = ChangeCode(IDM_ENCODING_UTF8), active = activeRecoding(IDM_ENCODING_UTF8)},
			{'UTF-8', action = ChangeCode(IDM_ENCODING_UCOOKIE), active = activeRecoding(IDM_ENCODING_UCOOKIE)},
        },},
		{'Con&vert Selection to UPPERCASE',  key = 'Ctrl+U', action = function() switchCase(IDM_UPRCASE) end, image = 'edit_uppercase_µ'},
		{'Convert Selection to lo&wercase',  key = 'Ctrl+Shift+U', action = function() switchCase(IDM_LWRCASE) end, image = 'edit_lowercase_µ'},
	},},
	{'&Search', {
		{'&Find...',  key = 'Ctrl+F', action = IDM_FIND, image = 'IMAGE_search'},
		{'Find &Next', key = 'F3', action = IDM_FINDNEXT},
		{'Find &Previous', key = 'Shift+F3', action = IDM_FINDNEXTBACK},
		{'Find in Fi&les...', key = 'Ctrl+Shift+F', action = IDM_FINDINFILES, image = 'folder_search_result_µ'},
		{'&Replace...', key = 'Ctrl+H', action = IDM_REPLACE, image = 'IMAGE_Replace'},
		{'Replace Ne&xt...', key = 'Ctrl+Shift+H', action = function() CORE.ReplaceNext() end},
		{'&Marks', action = function() CORE.ActivateFind(3) end, key = 'Ctrl+M', image = 'marker_µ',},
		{'s0', separator = 1},
		{'&Search',  plane = 1,{
			{'s_FindTextOnSel', separator = 1},
			{'Find Next Word/Selection',  action = function() CORE.Find_FindInDialog(true) end, key = 'Ctrl+F3',},
			{'Find Prev Word/Selection',  action = function() CORE.Find_FindInDialog(false) end, key = 'Ctrl+Shift+F3',},
			{'Next Word/Selection', action = function() CORE.FindNextWrd(1) end, key = 'Alt+F4',},
			{'Previous Word/Selection', action = function() CORE.FindNextWrd(2) end, key = 'Alt+F2',},
			{'Find All Words/Selections(Ctrl+Alt+Click)',  action = function() if scite.buffers.SecondEditorActive() == 1 then CORE.FindCoSelToConcole() else CORE.FindSelToConcole() end end, key = 'Alt+Shift+F',},
			{'Clear Live Search Markers',  action = function() CORE.ClearLiveFindMrk() end, key = 'Ctrl+Alt+Shift+F',},
		}},
        {'s11', separator = 1},
		{'Next Find Res&ult', action = function() CORE.FindResult(1) end, key = 'Ctrl+R',},
		{'Pre&vious Find Result', action = function() CORE.FindResult(-1) end, key = 'Ctrl+Shift+R', },
		{'Next &Change', visible = "(_G.iuprops['changes.mark.line'] or 0) == 1", action = function() CORE.CoToChange(1) end, key = 'Ctrl+W',},
		{'Previous C&hange', visible = "(_G.iuprops['changes.mark.line'] or 0) == 1", action = function() CORE.CoToChange(-1) end, key = 'Ctrl+Shift+W', },

		{'s1', separator = 1},
	},},
	{'&View', {
		{'s2', separator = 1},
		{'F&ull Screen', key = 'F11', action = IDM_FULLSCREEN},
		{'&Menu Bar', action = function() iup.GetDialogChild(iup.GetLayout(), "MenuBar").switch() end, check = function() return iup.GetDialogChild(iup.GetLayout(), "MenuBar").isOpen() end},
		{'&Tool Bar', action = function() iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").switch() end, check = function() return iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").isOpen() end},
		{'&Status Bar', action = function() iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").switch() end, check = function() return iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").isOpen() end},
		{'T&ab Bar', action = function() local h = iup.GetDialogChild(iup.GetLayout(), "TabbarExpander"); if h.state == 'OPEN' then h.state = 'CLOSE' else h.state = 'OPEN' end end, check = function() return iup.GetDialogChild(iup.GetLayout(), "TabbarExpander").state == 'OPEN' end},
		{'&Bottom Bar', key = 'F10', action = IDM_TOGGLEOUTPUT, check = function() return (tonumber(iup.GetDialogChild(iup.GetLayout(), "BottomBarSplit").barsize) ~= 0) end},
		{'s2', separator = 1},
		{'&White Space and TAB', key = 'Ctrl+Shift+8', action = IDM_VIEWSPACE, check = "props['view.whitespace']=='1'"},
		{'En&d of Line', key = 'Ctrl+Shift+9', action = IDM_VIEWEOL, check = "editor.ViewEOL"},
		{'Indentation G&uides', action = IDM_VIEWGUIDES, check = "props['view.indentation.guides']=='1'"},
		{'L&ine Numbers', action = IDM_LINENUMBERMARGIN, check = "props['line.margin.visible']=='1'"},
		{'Mar&gin', action = IDM_SELMARGIN, check = "editor.MarginWidthN[1]>0"},
		{'Fo&ld Margin',  action = IDM_FOLDMARGIN, check = "editor.MarginWidthN[2]>0"},
        {'s3', separator = 1},
		{'slast', separator = 1},
		{'Show &Menu Icons', check_iuprops = 'menus.show.icons'},
        {'Mark Chan&ged Lines', check_iuprops = "changes.mark.line"},
		{'&Word Wrap', action = IDM_WRAP, check = "props['wrap']=='1'"},
		{'Wr&ap settings', action = function() DoSett('ResetWrapProps') end, image = 'settings_µ'},

	},},
	{'&Tools', {
		{'&Compile', key = 'Ctrl+F7', action = IDM_COMPILE, image = 'compile_µ', visible = 'props["command.compile$"]~=""'},
		{'&Build', key = 'F7', action = IDM_BUILD, image = 'building__arrow_µ', visible = 'props["command.build$"]~=""'},
		{'&Run', key = 'F5', action = IDM_GO, image = 'control_µ', visible = 'props["command.go$"]~=""'},
		{'Stop E&xecuting', key = 'Ctrl+Break', action = IDM_STOPEXECUTE},
		{'&Script', {
			{'&Reload', key = 'Alt+Ctrl+Shift+R', action = function() scite.RunAsync(iup.ReloadScript) end,},
			{'&Show error traceback',  check_prop = "ext.lua.debug.traceback"},
		},},
		{'s1', separator = 1},
		{'&Utils', {
			{'LayOut &Dialog', action =(function()
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
            {'&Output', {
            {'&Next Message', key = 'F4', action = IDM_NEXTMSG},
            {'&Previous Message', key = 'Shift+F4', action = IDM_PREVMSG},
            {'Clear O&utput', key = 'Shift+F5', action = IDM_CLEAROUTPUT},
            {'Clear &Find Result', action = "findres:SetText('')"},
            {'S&witch Pane', key = 'Ctrl+F6', action = function() CORE.SwitchPane(true) end},
            {'Switc&h Pane Back', key = 'Ctrl+Shift+F6', action = function() CORE.SwitchPane(false) end},
        },},
        {'s2', separator = 1},
    },},
	{'&Options', {
		{'Read-Onl&y', action = ResetReadOnly, check = "(shell.getfileattr(props['FilePath']) & 1) == 1"},
		{'s2', separator = 1},
		{'Line End C&haracters', {radio = 1,
			{'CR + LF', action = IDM_EOL_CRLF, check = "editor.EOLMode==SC_EOL_CRLF"},
			{'CR', action = IDM_EOL_CR, check = "editor.EOLMode==SC_EOL_CR"},
			{'LF', action = IDM_EOL_LF, check = "editor.EOLMode==SC_EOL_LF"},
		},},
		{'Co&nvert Line End Characters', action = IDM_EOL_CONVERT},
		{'s1', separator = 1},
		{'Change &Indentation Settings...', action = function() DoSett('CurrentTabSettings') end, image = 'edit_indent_µ'},
		{'Use &Monospaced Font', action = IDM_MONOFONT},
		{'s2', separator = 1},
		{'&Reload Session', action = "CheckChange('session.reload', true)", check = "props['session.reload']=='1'"},
		{'Show A&PI Tool Tip', check_iuprops = 'menus.tooltip.show', visible = "props['apii$']~='' or props['apiix$']~=''"},
		{'Go &To Definition By Ctrl+Click', check = 'not _G.iuprops["menus.not.ctrlclick"]', action =function() _G.iuprops["menus.not.ctrlclick"] = not _G.iuprops["menus.not.ctrlclick"] end, visible = "menu_GoToObjectDefenition ~= nil"},
		{'Interface Font Si&ze', action = function() DoSett('ResetFontSize') end},
        {'Ta&bbar Settings',  action = function() DoSett('ResetTabbarProps') end, image='ui_tab__pencil_µ'},

		{'s3', separator = 1},
		{'&Localization', { radio = 1,
			{'&EN', action = SetLocale('en'), check = 'props["locale"]=="en" or props["locale"] == ""'},
			{'&RU', action = SetLocale('ru'), check = 'props["locale"]=="ru"'},
		},},
		{'Hot&keys Settings', action = "dolocale('tools\\\\HotkeysSettings.lua')", active = RunSettings, image = "keyboards_µ"},
		{'&Plugins', visible = RunSettings,{
            {'&Toolbars Layout', action = "dolocale('tools\\\\ToolBarsLayout.lua')", image = "ui_toolbar__arrow_µ"},
            {'&SideBars Settings', action = "dolocale('tools\\\\SideBarLayOut.lua')", image = "application_sidebar_right_µ"},
            {'Status &Bar Plugins', action = "dolocale('tools\\\\HiddenPlugins.lua')('Status')", image = "ui_status_bar_blue_µ"},
            {'&Hidden Plugins', action = "dolocale('tools\\\\HiddenPlugins.lua')('Hidden')"},
            {'&Commands Plugins', action = "dolocale('tools\\\\HiddenPlugins.lua')('Commands')", image = 'terminal_µ'},
            {'s1', separator = 1},
            {'&User Toolbar...', action = "dolocale('tools\\\\ToolBarSetings.lua')"},
		},},
		{'L&oad Configuration...', iup.ConfigList},
		{'S&ave Configuration...', action = iup.SaveIuprops, image = 'disk__pencil_µ'},
		{'Save Current Configuration', cpt = _TM'Save &Current Configuration'..':\t'..(iuprops['current.config.restore'] or ''):gsub('^.-([^\\]-)%.[^\\.]+$', '%1'), action = iup.SaveCurIuprops, visible = "iuprops['current.config.restore']~=nil", image = 'disk_µ'},
		{'s5', separator = 1},
		{'W&indows Integration', action = "dolocale('tools\\\\WinAssoc.lua')", image = 'windows_µ'},
		{'Open &User Options File', action = IDM_OPENUSERPROPERTIES},
		{'&Indicators', action = "dolocale('tools\\\\ColorIndicators.lua')", active = RunSettings, image = 'color_µ'},
		{'Main window &colors', action = CORE.ResetGlobalColors, image = 'color_µ'},
        {'Color &Scheme', visible = RunSettings,{
            {'Default(gray)',  action = function() DoSett('Colors_Default') end, },
            {'Atrium',  action = function() DoSett('Colors_Atrium') end, },
            {'Dark Blue',  action = function() DoSett('Colors_Darkblue') end, },
            {'Work',  action = function() DoSett('Colors_Work') end, },
            {'s5', separator = 1},
            {'Save Scheme',  action = function() DoSett('CreateColorSettings') end, },
            {'Load Scheme',  action = function() DoSett('ApplyColorsSettings') end, },
        },},
		{'Colo&r Selection && Caret', action = function() DoSett('ResetSelColors') end, image = 'color_µ'},
		{'Autoscro&ll Settings', action = function() DoSett('AutoScrollingProps') end, image = 'settings_µ'},
		{'Le&xer Colors and Fonts', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\ColorSettings.lua')", active = RunSettings, image = 'settings_µ'},
		{"&Lexer properties",  {
			{'&Lexer properties', plane = 1 , tLangs},
			{'s2', separator = 1},
			{"&Select lexers", action = "dolocale('tools\\\\UsedLexers.lua')", active = RunSettings},
		},},
	},},
	{'&Language',  {
		{'tHilight', tHilight, plane = 1,},
		{'s1', separator = 1},
	},},
	{'&Window', {
		{'&Previous', action = IDM_PREVFILE},
		{'&Next',  action = IDM_NEXTFILE},
		{'&Switch to Another View', key = 'F6', action = function() coeditor:GrabFocus() end, active = function() return scite.buffers.SecondEditorActive() == 1 end},
		{'Move Tab &Left', action = IDM_MOVETABLEFT},
		{'Move Tab &Right', action = IDM_MOVETABRIGHT},
        {'&Tabbar Settings', action = function() DoSett('ResetTabbarProps') end, image = 'ui_tab__pencil_µ'},
		{'&Close All', action = IDM_CLOSEALL, image = 'cross_script_µ'},
		{'&Save All', key = 'Ctrl+Alt+S', action = function() props['save.scip.alert'] = 1; DoForBuffers_Stack(function() scite.MenuCommand(IDM_SAVE); CORE.fixMarks(true) end); props['save.scip.alert'] = 0 end, image = 'disks_µ'},
		{'Save All with &Event Processing', action = IDM_SAVEALL, image = 'disks_µ'},
		{'s2', separator = 1},
		{'l1', CORE.windowsList, plane = 1},
        {'s2', separator = 1},
        {'&Windows...', action = function() CORE.showWndDialog() end, image = 'property_µ' },

	},},
	{'&Help', {
		{'Context Help',  key = 'F1', action = IDM_HELP},
		{'HildiM Help',  action = function() scite.ExecuteHelp(props['SciteDefaultHome']..'/help/HildiM.chm::ui/Menues.html', 0) end},
		{'slast', separator = 1},
        {'About HildiM',  action = function() dolocale('tools\\AboutBox.lua') end},
	},},
}

