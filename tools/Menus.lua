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
            local s = scite.buffers.NameAt(i):from_utf8(1251):gsub('(.+)[\\]([^\\]*)$', '%2\t%1')
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

local function ResetWrapProps()
	local ret, style, flag, loc, mode, indent, keys =
                    iup.GetParam("Настройки переноса по словам^WrapSettings",
					nil,
					'Переносить:%l|По границам слов|По любому символу|По пробелам|\n'..
					'Символы переноса-отображать:%l|Нет|В конце|В начале|В конце и в начале|В нумерации|В нумерации и в конце|В нумерации и в начале|Все|\n'..
					'Символы переноса-в тексте:%l|По границам окна|В конце - по тексту|В начале - по тексту|Оба по тексту|\n'..
					'Выравнивание после переноса%l|Отступ от края|По Предыдущей строке|Отступ от пред. строки|\n'..
					'Величина отступа:%i[1,10,1]\n'..
					'<Home>,<End> до ближайшего переноса %b\n',
                   (tonumber(props['wrap.style']) or 1) - 1,
                    tonumber(props['wrap.visual.flags']) or 0,
                    tonumber(props['wrap.visual.flags.location']) or 0,
                    tonumber(props['wrap.indent.mode']) or 0,
                    tonumber(props['wrap.visual.startindent']) or 0,
                    tonumber(props['wrap.aware.home.end.keys']) or 0
    )
	if ret then
        props['wrap.style'] = style + 1
        props['wrap.visual.flags'] = flag
        props['wrap.visual.flags.location'] = loc
        props['wrap.indent.mode'] = mode
        props['wrap.visual.startindent'] = indent
        props['wrap.aware.home.end.keys'] = keys
        iup.SaveChProps(true)
        editor.WrapMode = style + 1
	end
end

local function ResetTabbarProps()
    if props["tab.oldstile"] == '' then
        local oldClr = props['tabctrl.readonly.color']
        if oldClr == '' then oldClr = '120 120 120' end
        local ret, ondbl, buff, zord, newpos, setbegin, coloriz, illum, satur, cEx, cPref, ROColor =
        iup.GetParam("Свойства панели закладок^TabbarProperties",
            nil,
            'Закрывать по DblClick%b\n'..
            'Максимальное количество вкладок:%i[10,500,1]\n'..
            'Переключать в порядке использования%b\n'..
            'Открывать новую вкладку%l|В конце списка|Следующей за текущей|В начале списка|%b\n'..
            'Активный таб - в начало%b\n'..
            'Подсветка по расширению%b\n'..
            'Освещенность вкладки:%i[10,99,1]\n'..
            'Насыщенность вкладки:%i[10,99,1]\n'..
            'Не показывать расширение%b\n'..
            'Не показывать префикс%b\n'..
            'Цвет шрифта Read-Only вкладки%c\n'
            ,
            tonumber(props['tabbar.tab.close.on.doubleclick']) or 0,
            tonumber(props['buffers']) or 100,
            tonumber(props['buffers.zorder.switching']) or 0,
            tonumber(props['buffers.new.position']) or 0,
            ((tonumber(props['tabctrl.alwayssavepos']) or 0) + 1) % 2,
            tonumber(props['tabctrl.colorized']) or 0,
            tonumber(props['tabctrl.cut.illumination']) or 90,
            tonumber(props['tabctrl.cut.saturation']) or 50,
            tonumber(props['tabctrl.cut.ext']) or 0,
            tonumber(props['tabctrl.cut.prefix']) or 0,
            oldClr
        )
        if ret then
            props['tabbar.tab.close.on.doubleclick'] = ondbl
            props['buffers'] = buff
            props['buffers.zorder.switching'] = zord
            props['buffers.new.position']    = newpos
            props['tabctrl.alwayssavepos']   = (setbegin + 1) % 2
            props['tabctrl.colorized']       = coloriz
            props['tabctrl.cut.illumination']= illum
            props['tabctrl.cut.saturation']  = satur
            props['tabctrl.cut.ext']         = cEx
            props['tabctrl.cut.prefix']      = cPref
            props['tabctrl.readonly.color'] = ROColor

            iup.GetDialogChild(iup.GetLayout(), 'TabCtrlLeft').showclose = Iif((tonumber(props['tabbar.tab.close.on.doubleclick']) or 0) == 1, 'NO', 'YES')
            iup.GetDialogChild(iup.GetLayout(), 'TabCtrlRight').showclose = Iif((tonumber(props['tabbar.tab.close.on.doubleclick']) or 0) == 1, 'NO', 'YES')
            iup.Redraw(iup.GetDialogChild(iup.GetLayout(), 'TabCtrlRight'), 1)
            iup.Redraw(iup.GetDialogChild(iup.GetLayout(), 'TabCtrlLeft'), 1)
        end
    else
        local ret, mult, maxlen, ondbl, buff, zord, newpos =
        iup.GetParam("Свойства панели закладок",
            nil,
            'Многострочная%b\n'..
            'Максимальная ширина(0- не задана)%i[0,100,10]\n'..
            'Закрывать по DblClick%b\n'..
            'Максимальное количество вкладок:%i[10,500,1]\n'..
            'Переключать в порядке использования%b\n'..
            'Открывать новую вкладку%l|В конце списка|Следующей за текущей|В начале списка|%b\n',
            tonumber(props['tabbar.multiline']) or 1,
            tonumber(props['tabbar.title.maxlength']) or 0,
            tonumber(props['tabbar.tab.close.on.doubleclick']) or 0,
            tonumber(props['buffers']) or 100,
            tonumber(props['buffers.zorder.switching']) or 0,
            tonumber(props['buffers.new.position']) or 0
        )
        if ret then
            props['tabbar.multiline'] = mult
            props['tabbar.title.maxlength'] = maxlen
            props['tabbar.tab.close.on.doubleclick'] = ondbl
            props['buffers'] = buff
            props['buffers.zorder.switching'] = zord
            iup.Alarm('Свойства панели закладок', 'Изменения будут применены после перезапуска программы', 'OK')
        end
	end
end

local function ResetFontSize()
	local ret, size = iup.GetParam("Шрифт диалогов и элементов интерфейса^InterfaceFontSize",
					function(h,i) if i == -1 and tonumber(iup.GetParamParam(h,0).value) < 5 then return 0 end return 1 end,
					'Размер%i[1,19,1]\n', tonumber(props['iup.defaultfontsize']) or 9)
	if ret then
		props['iup.defaultfontsize'] = size
		iup.Alarm('Шрифт интефейса', 'Изменения будут применены после перезапуска программы', 'OK')
	end
end

local function SetFindresCount()
	local ret, size = iup.GetParam("Хранить результатов поиска",
					function(h,i) if i == -1 and tonumber(iup.GetParamParam(h,0).value) < 3 then return 0 end return 1 end,
					'Не более%i[1,30,1]\n', tonumber(_G.iuprops['findres.maxresultcount']) or 10)
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

local function switchCase(cmd)
    if scintilla().SelectionStart == scintilla().SelectionEnd then editor:WordLeftExtend() end
    scite.MenuCommand(cmd)
end

local function ResetReadOnly()
	local attr = shell.getfileattr(props['FilePath'])
	if (attr & 1) == 1 then
		attr = attr - 1
	else
		attr = attr + 1
	end
	shell.setfileattr(props['FilePath'], attr)
	scite.MenuCommand(IDM_REVERT)
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


_G.sys_Menus.TABBAR = { title = "Контекстное меню закладок",
	{link='File|&Close'},
	{link='File|C&lose All'},
	{'Close All But Curent',  ru = 'Зарыть все, кроме текущей', action=function() iup.CloseFilesSet(9132) end, },
	{'Close All Temporally',  ru = 'Зарыть все временные', action=function() iup.CloseFilesSet(9134) end, visible=IsOpenTemporaly },
	{'s1', separator=1},
	{link='File|&Save'},
	{link='Buffers|&Save All'},
	{link='File|Save &As...'},
	{link='File|Save a Cop&y...'},
    {'s1', separator = 1},
    {link= 'File|Move to another window'},
    {link='File|Clone to another window'},
	{'s2', separator=1},
	{'Move Tab Left', ru = 'Переместить влево', action = IDM_MOVETABLEFT,},
	{'Move Tab Right', ru = 'Переместить вправо', action = IDM_MOVETABRIGHT,},
	{'Copy to Clipboard', ru='Копировать в буфер',{
		{'All Text', ru='Весь текст', action = function() CopyPathToClipboard("text") end,},
		{'Path/FileName', ru='Путь/Имя файла', action = function() CopyPathToClipboard("all") end,},
		{'Path', ru='Путь', action = function() CopyPathToClipboard("path") end,},
		{'FileName', ru='Имя файла', action = function() CopyPathToClipboard("name") end,},
	}},
    {link='Options|Tabbar Settings'},
	{link='File|Encoding'},
	{link = 'Options|&Read-Only'},

	{'slast', separator=1},
}
_G.sys_Menus.OUTPUT = {title = "Контекстное меню консоли",
	{link = 'Edit|Conventional|Cu&t'},
	{link = 'Edit|Conventional|&Copy'},
	{link = 'Edit|Conventional|&Paste'},
	{link = 'Edit|Conventional|&Delete'},
	{'s1', separator = 1},
	{link = 'Tools|Clear &Output'},
	{link = 'Tools|&Previous Message'},
	{link = 'Tools|&Next Message'},
	{'s2', separator = 1},
	{'Input Mode', ru = 'Режим ввода', {
		{'Display Mode', ru = 'Отобразить(press Enter)', action = function() output:DocumentEnd();output:ReplaceSel('###?\n') end},
		{'Command Line Mode', ru = 'Режим командной строки', action = function() output:DocumentEnd();output:ReplaceSel('###c') end},
		{'LUA Mode', ru = 'Режим консоли LUA', action = function() output:DocumentEnd();output:ReplaceSel('###l') end},
		{'LUA Mode', ru = 'Значение выражения LUA', action = function() output:DocumentEnd();output:ReplaceSel('###p') end},
		{'IDM command Mode', ru = 'Режим команд IDM', action = function() output:DocumentEnd();output:ReplaceSel('###i') end},
		{'Switch OFF', ru = 'Отключить', action = function() output:DocumentEnd();output:ReplaceSel('####') end},
	}},
    {'Settings', ru = 'Настройки',{
        {'Wrap Out&put', ru = 'Перенос по словам в консоли', action = IDM_WRAPOUTPUT, check = "props['output.wrap']=='1'"},
        {'Clear Before Execute', ru = 'Очищать перед выполнением', check_prop = "clear.before.execute"},
        {'Recode OEM to ANSI', ru = 'Перекодировать OEM в ANSI', check_prop = "output.code.page.oem2ansi"},
        {'Autoshow By Output', ru = 'Автопоказ при выводе', check_iuprops = "concolebar.autoshow"},
    },},
	{'slast', separator = 1},
}

_G.sys_Menus.FINDRES = {title = "Контекстное меню результатов поиска",
	{link = 'Edit|Conventional|Cu&t'},
	{link = 'Edit|Conventional|&Copy'},
	{link = 'Edit|Conventional|&Paste'},
	{link = 'Edit|Conventional|&Delete'},
	{'s1', separator = 2},
	{link = 'Tools|Clear &Find Result'},
    {'Settings', ru = "Настройки" ,{
        {'DblClick Only On Number', ru = 'DblClick только по номеру', check_boolean = 'findres.clickonlynumber'},
        {'Group By Name', ru = 'Группировать по имени файла', check_boolean = 'findres.groupbyfile'},
        {'Wrap Find &Result', ru = 'Перенос по словам в результатах поиска', action = IDM_WRAPFINDRES, check = "props['findres.wrap']=='1'"},
        {'Number Of Find Results...', ru = 'Результатов поиска не более....', action = SetFindresCount},
    }},
	{'Open Files', plane = 1, visible = "findres.StyleAt[findres.CurrentPos] == SCE_SEARCHRESULT_SEARCH_HEADER" ,{
		{'s_OpenFiles', separator = 1},
		{'Open Files', ru = 'Открыть файлы', action = function() CORE.OpenFoundFiles(1) end, },
		{'Close Files', ru = 'Закрыть файлы', action = function() CORE.OpenFoundFiles(2) end, },
		{'Close If Not Found', ru = 'Закрыть не найденные', action = function() CORE.OpenFoundFiles(3) end, },
	}},
	{'slast', separator = 1},

}

_G.sys_Menus.EDITOR = {title = "Контекстное меню окна редактора",
	{'s0', link='Edit|Conventional|&Undo'},
	{link='Edit|Conventional|&Redo'},
	{'s1', separator=1},
	{link='Edit|Conventional|Cu&t'},
	{link='Edit|Conventional|&Copy'},
	{link='Edit|Conventional|&Paste'},
	{link='Edit|Conventional|&Delete'},
	{link='Edit|Conventional|Duplicat&e'},
	{'s1', separator=2},
	{link='Edit|Conventional|Select &All'},
	{link='Search|Search', plane=0},
	{link='View|Folding', plane=0},
	{link='Search|Toggle Bookmar&k'},
	{link='Search|&Go to definition(Shift+Click)'},
}

_G.sys_Menus.MainWindowMenu = {title = "Главное меню программы",
	{'_HIDDEN_', {
		{'Next Tab', key = 'Ctrl+Tab', action = function() if iup.GetFocus() then iup.PassFocus() end scite.MenuCommand(IDM_NEXTFILESTACK) end},
		{'Prevouse Tab', key = 'Ctrl+Shift+Tab', action = function() if iup.GetFocus() then iup.PassFocus() end scite.MenuCommand(IDM_PREVFILESTACK) end},
		{'Block Up', key = 'Alt+Up', action = function() editor:LineUpRectExtend() end},
		{'Block Down', key = 'Alt+Down', action = function() editor:LineDownRectExtend() end},
		{'Block Left', key = 'Alt+Left', action = function() editor:CharLeftRectExtend() end},
		{'Block Right', key = 'Alt+Right', action = function() editor:CharRightRectExtend() end},
		{'Block Home', key = 'Alt+Home', action = function() editor:VCHomeRectExtend() end},
		{'Block End', key = 'Alt+End', action = function() editor:LineEndRectExtend() end},
		{'Block Page Up', key = 'Alt+PageUp', action = function() editor:PageUpRectExtend() end},
		{'Block Page Down', key = 'Alt+PageDown', action = function() editor:PageDownRectExtend() end},
	},},
	{'File', ru = 'Файл',{
		{'New', ru = 'Создать', key = 'Ctrl+N', action = IDM_NEW, image = 'document__plus_µ'},
		{'&Open...', ru = 'Открыть', key = 'Ctrl+O', action = IDM_OPEN, image = 'folder_open_document_µ'},
		--{'Open Selected &Filename', ru = 'Открыть выделенный файл', key = 'Ctrl+Shift+O', action = IDM_OPENSELECTED, active = function() return editor:GetSelText():find('%w:[\\/][^"\n\r\t]') end,},
		{'Recent Files', ru = 'Недавние файлы', visible = "(_G.iuprops['resent.files.list.location'] or 0) == 0", function() if (_G.iuprops['resent.files.list.location'] or 0) == 0 then return iuprops['resent.files.list']:GetMenu() else return {} end end},
		{'&Revert', ru = 'Перезагрузить файл', key = 'Ctrl+Shift+O', action = function() if not editor.Modify or (iup.Alarm('Перезагрузка файла', 'Изменения не сохранены.\nПродолжить?', 'Да', 'Нет') == 1) then scite.MenuCommand(IDM_REVERT) end end},
		{'&Close', ru = 'Закрыть', key = 'Ctrl+F4', action = IDM_CLOSE},
		{'C&lose All', ru = 'Закрыть все', action = IDM_CLOSEALL},
		{'&Save', ru = 'Сохранить', key = 'Ctrl+S', action = IDM_SAVE, active = function() return editor.Modify end, image = 'disk_µ'},
		{'Save &As...', ru = 'Сохранить как...', key = 'Ctrl+Shift+S', action = IDM_SAVEAS, image = 'disk__pencil_µ'},
		{'Save a Cop&y...', ru = 'Сохранить копию...', key = 'Ctrl+Shift+P', action = IDM_SAVEACOPY, image = 'disk__plus_µ'},
		--[[{'Copy Pat&h',  action = IDM_COPYPATH},]]
		{'Encoding', ru = 'Кодировка',{check_idm = 'editor.unicode.mode', radio = 1,
			{'&Code Page Property', ru = 'Заданная настройкой codepage', action = IDM_ENCODING_DEFAULT},
			{'UTF-16 &Big Endian', action = IDM_ENCODING_UCS2BE},
			{'UTF-16 &Little Endian', action = IDM_ENCODING_UCS2LE},
			{'UTF-8 &with BOM', ru = 'UTF-8 с заголовком', action = IDM_ENCODING_UTF8},
			{'&UTF-8', action = IDM_ENCODING_UCOOKIE},
		},},
		{'&Export', ru = 'Экспорт',{
			{'As &HTML...' , ru = 'В &HTML..', action = IDM_SAVEASHTML},
			{'As &RTF...'  , ru = 'В &RTF...', action = IDM_SAVEASRTF},
			{'As &PDF...'  , ru = 'В &PDF...', action = IDM_SAVEASPDF},
			{'As &LaTeX...', ru = 'В &LaTeX...', action = IDM_SAVEASTEX},
			{'As &XML...'  , ru = 'В &XML...', action = IDM_SAVEASXML},
		},},
		{'s1', separator = 1},
		{'Save Session...', ru = 'Сохранить сессию', action = iup.SaveSession,},
		{'Load Session...', ru = 'Загрузить сессию', action = iup.LoadSession,},
		{'s2', separator = 1},
		{'Page Set&up...', ru = 'Параметры страницы', action = IDM_PRINTSETUP, image = 'layout_design_µ'},
		{'&Print...', ru = 'Печать...', key = 'Ctrl+P', action = IDM_PRINT, image = 'printer_µ'},
		{'s3', separator = 1},
        {'Move to another window', ru = 'Переместить на другое окно', action = IDM_CHANGETAB, visible="scite.buffers.IsCloned(scite.buffers.GetCurrent())==0"},
        {'Clone to another window', ru = 'Клонировать в другом окне', action = IDM_CLONETAB, visible = "scite.buffers.IsCloned(scite.buffers.GetCurrent())==0" },
        {'s4', separator = 1},
		{'Exit', ru = 'Выход', action = IDM_QUIT},
        {'sLast', separator = 1},
        {'Recent Files1', plane = 1, visible = "(_G.iuprops['resent.files.list.location'] or 0) == 1", function() if (_G.iuprops['resent.files.list.location'] or 0) == 1 then return iuprops['resent.files.list']:GetMenu() else return {} end end},
	},},
	{'Edit', ru = 'Правка',{
		{'Conventional', ru = 'Стандартные', {
			{'&Undo', ru = 'Отменить', key = 'Ctrl+Z', key_external = 1, action = IDM_UNDO, active = function() return scintilla():CanUndo() end, image = 'arrow_return_270_left_µ'},
			{'&Redo', ru = 'Повторить', key = 'Ctrl+Y', key_external = 1, action = IDM_REDO, active = function() return scintilla():CanRedo() end, image = 'arrow_return_270_µ'},
			{'s1', separator = 1},
			{'Cu&t', ru = 'Вырезать', key = 'Ctrl+X', key_external = 1, action = IDM_CUT, active = IsSelection, image = 'scissors_µ'},
			{'&Copy', ru = 'Копировать', key = 'Ctrl+C', key_external = 1, action = IDM_COPY, active = IsSelection, image = 'document_copy_µ'},
			{'&Paste', ru = 'Вставить', key = 'Ctrl+V', key_external = 1, action = IDM_PASTE, image = 'clipboard_paste_µ', active = function() return bCanPaste end,},
			{'Duplicat&e', ru = 'Дублировать', key = 'Ctrl+D', key_external = 1, action = IDM_DUPLICATE, image = 'yin_yang_µ'},
			{'&Delete', ru = 'Удалить', key = 'Del', key_external = 1, action = IDM_CLEAR, image = 'cross_script_µ'},
			{'Select &All', ru = 'Выбрать все', key = 'Ctrl+A', key_external = 1, action = IDM_SELECTALL},
			{'Copy as RT&F', ru = 'Копировать в формате RTF', action = IDM_COPYASRTF, active = IsSelection},
		}},
		{'Xml', ru = 'Xml', visible_ext = 'xml,form,rform,cform,wform',{
			{'Format Xml', ru = 'Форматировать Xml', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\FormatXml.lua')", image = 'broom_code_µ',},
		}},
		{'s1', separator = 1},
		{'Autoformat', ru = 'Автоформат', {
			{'Format Block', ru = 'Форматировать блок', action = function() if Format_Block then Format_Block() end end, key = 'Ctrl+]'},
			{'Format Line', ru = 'Форматировать строку', action = function() if Format_String then Format_String() end end, key = 'Ctrl+['},
			{'Auto Indent', ru = 'Автоотступ', check_iuprops = 'autoformat.indent', key = 'Ctrl+Shift+]'},
			{'Autoformating Lines', ru = 'Автоформатирование строк', check_iuprops = 'autoformat.line', key = 'Ctrl+Shift+['},
		}},
		{'Match &Brace', ru = 'Найти парную скобку', key = 'Ctrl+E', action = IDM_MATCHBRACE},
		{'Select t&o Brace', ru = 'Выделить до парной скобки', key = 'Ctrl+Shift+E', action = IDM_SELECTTOBRACE},
		{'s2', separator = 1},
		{'S&how Calltip', ru = 'Показать подсказку', key = 'Ctrl+?', action = function() ShowTipManualy() end, image = 'ui_tooltip_balloon_bottom_µ',},
		{'Complete S&ymbol', ru = 'Завершить слово(из API)', key = 'Ctrl++', action = function() ShowListManualy() end},
		{'Complete &Word', ru = 'Завершить слово(из текста)', key = 'Ctrl+Enter', action = IDM_COMPLETEWORD},
		{'s2', separator = 1},
        {'Expand Abbre&viation', ru = 'Расшифровать сокращение (‹‡›=выделение)', key = 'Ctrl+B', action = IDM_ABBREV, image = 'key_µ'},
		{'Expand Abbre&viation', ru = 'Расшифровать сокращение (‹‡›=буфер обмена)', key = 'Ctrl+Alt+B', action = IDM_INS_ABBREV, image = 'key__plus_µ'},
		{'s3', separator = 1},
        {'Comment or Uncomment', ru = 'Закомментировать и раскомментировать текст', key = 'Ctrl+Q', action = CORE.xComment, image = 'edit_signiture_µ'},
		{'Block Co&mment', ru = 'Блочный комментарий', action = IDM_BLOCK_COMMENT, visible = "props['comment.stream.start.'..editor_LexerLanguage()]~='' and props['comment.block.'..editor_LexerLanguage()]~=''"},
		{'Stream Comme&nt', ru = 'Потоковый комментарий', key = 'Ctrl+Shift+Q', action = IDM_STREAM_COMMENT, visible = "props['comment.stream.start.'..editor_LexerLanguage()]~='' and props['comment.block.'..editor_LexerLanguage()]~=''"},
		{'Bo&x Comment', ru = 'Бокс - комментарий', key = 'Ctrl+Shift+B', action = IDM_BOX_COMMENT, visible = "props['comment.box.start.'..editor_LexerLanguage()]~=''"},
        {'Decode  ещ', ru = 'Изменить кодировку на..',{
            {'&Code Page Property', ru = 'Заданная настройкой codepage', action = ChangeCode(IDM_ENCODING_DEFAULT), active = function() return props['editor.unicode.mode'] ~= ''..IDM_ENCODING_DEFAULT end},
            {'UTF-16 &Big Endian', action = ChangeCode(IDM_ENCODING_UCS2BE), active = function() return props['editor.unicode.mode'] ~= ''..IDM_ENCODING_UCS2BE end},
            {'UTF-16 &Little Endian', action = ChangeCode(IDM_ENCODING_UCS2LE), active = function() return props['editor.unicode.mode'] ~= ''..IDM_ENCODING_UCS2LE end},
            {'UTF-8 &with BOM', ru = 'UTF-8 с заголовком', action = ChangeCode(IDM_ENCODING_UTF8), active = function() return props['editor.unicode.mode'] ~= ''..IDM_ENCODING_UTF8 end},
            {'&UTF-8', action = ChangeCode(IDM_ENCODING_UCOOKIE), active = function() return props['editor.unicode.mode'] ~= ''..IDM_ENCODING_UCOOKIE end},
        },},
		{'Make &Selection Uppercase', ru = 'Перевести в верхний регистр', key = 'Ctrl+U', action = function() switchCase(IDM_UPRCASE) end, image = 'edit_uppercase_µ'},
		{'Make Selection &Lowercase', ru = 'Перевести в нижний регистр', key = 'Ctrl+Shift+U', action = function() switchCase(IDM_LWRCASE) end, image = 'edit_lowercase_µ'},
	},},
	{'Search', ru = 'Поиск',{
		{'&Find...', ru = 'Найти', key = 'Ctrl+F', action = IDM_FIND, image = 'IMAGE_search'},
		{'Find &Next', ru = 'Найти далее', key = 'F3', action = IDM_FINDNEXT},
		{'Find Previou&s', ru = 'Предыдущее совпадение', key = 'Shift+F3', action = IDM_FINDNEXTBACK},
		{'F&ind in Files...', ru = 'Найти в файлах', key = 'Ctrl+Shift+F', action = IDM_FINDINFILES, image = 'folder_search_result_µ'},
		{'R&eplace...', ru = 'Заменить', key = 'Ctrl+H', action = IDM_REPLACE, image = 'IMAGE_Replace'},
		{'Replace Next...', ru = 'Заменить далее', key = 'Ctrl+Shift+H', action = function() CORE.ReplaceNext() end},
		{'Marks', ru = 'Метки', action = function() CORE.ActivateFind(3) end, key = 'Ctrl+M', image = 'marker_µ',},
		{'s0', separator = 1},
		{'Search', ru = 'Поиск', plane = 1,{
			{'s_FindTextOnSel', separator = 1},
			{'Find Next Word/Selection', ru = 'Слово/выделение - (через диалог)', action = function() CORE.Find_FindInDialog(true) end, key = 'Ctrl+F3',},
			{'Find Prev Word/Selection', ru = 'Предыдущее слово/выделение - (через диалог)', action = function() CORE.Find_FindInDialog(false) end, key = 'Ctrl+Shift+F3',},
			{'Next Word/Selection', ru = 'Следующее слово/выделение', action = function() CORE.FindNextWrd(1) end, key='Alt+F3',},
			{'Prevous Word/Selection', ru = 'Предыдущее слово/выделение', action = function() CORE.FindNextWrd(2) end, key ='Alt+Shift+F3',},
			{'Find All Word/Selection(Ctrl+Alt+Click)', ru = 'Найти все слова/выделения(Ctrl+Alt+Click)', action = CORE.FindSelToConcole, key = 'Alt+Shift+F',},
		}},
		{'Next Find Result', ru = 'Следующий результат поиска', action = function() CORE.FindResult(1) end, key = 'Ctrl+R',},
		{'Prevouse Find Result', ru = 'Предыдущий результат поиска', action = function() CORE.FindResult(-1) end, key = 'Ctrl+Shift+R', },

		{'s1', separator = 1},
		{'&Go to definition(Shift+Click)', ru = 'Перейти к описанию(Shift+Click)', key = 'F12', action = "menu_GoToObjectDefenition()"},
		{'Next Book&mark', ru = 'Следующая закладка', key = 'F2', action = IDM_BOOKMARK_NEXT, image = 'bookmark__arrow_µ'},
		{'Pre&vious Bookmark', ru = 'Предыдущая закладка', key = 'Shift+F2', action = IDM_BOOKMARK_PREV, image = 'bookmark__arrow_left_µ'},
		{'Toggle Bookmar&k', ru = 'Добавить/Удалить закладку', key = 'Ctrl+F2', action = IDM_BOOKMARK_TOGGLE, image = 'bookmark_µ'},
		{'&Clear All Bookmarks', ru = 'Очистить все закладки', action = IDM_BOOKMARK_CLEARALL},
	},},
	{'View', ru = 'Вид',{
		{'Folding', ru = 'Складка', plane = 1, {
			{'Toggle &current fold', ru = 'Свернуть/Развернуть текущий блок', action = IDM_EXPAND},
			{'Toggle &all folds', ru = 'Свернуть/Развернуть все блоки', action = IDM_TOGGLE_FOLDALL},
			{'Toggle &recurse current fold', ru = 'Свернуть/Развернуть рекурсивно текущий блок', action = IDM_TOGGLE_FOLDRECURSIVE},
			{'Collapse Subfolders', ru = 'Свернуть подблоки', key = 'Ctrl+Shift+-', action = "CORE.ToggleSubfolders(false)"},
			{'Expand Subfolders', ru = 'Развернуть подблоки', key = 'Ctrl+Shift++', action = "CORE.ToggleSubfolders(true)"},
		}},
		{'s2', separator = 1},
		{'Full Scree&n', ru = 'Полноэкранный режим', key = 'F11', action = IDM_FULLSCREEN},
		{'&Menu Bar', ru = 'Панель меню', action = function() iup.GetDialogChild(iup.GetLayout(), "MenuBar").switch() end, check = function() return iup.GetDialogChild(iup.GetLayout(), "MenuBar").isOpen() end},
		{'&Tool Bar', ru = 'Панель инструментов', action = function() iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").switch() end, check = function() return iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").isOpen() end},
		{'Status Bar', ru = 'Строка состояния', action = function() iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").switch() end, check = function() return iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").isOpen() end},
		{'Tab &Bar', ru = 'Вкладки', action = function() local h = iup.GetDialogChild(iup.GetLayout(), "TabbarExpander"); if h.state == 'OPEN' then h.state = 'CLOSE' else h.state = 'OPEN' end end, check = function() return iup.GetDialogChild(iup.GetLayout(), "TabbarExpander").state == 'OPEN' end},
		{'Bottom Bar', ru = 'Нижняя панель', key = 'F10', action = IDM_TOGGLEOUTPUT, check = function() return (tonumber(iup.GetDialogChild(iup.GetLayout(), "BottomBarSplit").barsize) ~= 0) end},
		{'s2', separator = 1},
		{'&Whitespace', ru = 'Пробелы', key = 'Ctrl+Shift+8', action = IDM_VIEWSPACE, check = "props['view.whitespace']=='1'"},
		{'&End of Line', ru = 'Символы перевода строк', key = 'Ctrl+Shift+9', action = IDM_VIEWEOL, check = "editor.ViewEOL"},
		{'&Indentation Guides', ru = 'Направляющие отступа', action = IDM_VIEWGUIDES, check = "props['view.indentation.guides']=='1'"},
		{'&Line Numbers', ru = 'Нумера строк', action = IDM_LINENUMBERMARGIN, check = "props['line.margin.visible']=='1'"},
		{'&Margin', ru = 'Показывать закладки', action = IDM_SELMARGIN, check = "editor.MarginWidthN[1]>0"},
		{'&Fold Margin', ru = 'Поле сворачивания блоков текста', action = IDM_FOLDMARGIN, check = "editor.MarginWidthN[2]>0"},
		{'Main Window split', ru = 'Сплиттер главного окна',visible = "(_G.iuprops['coeditor.win'] or '')=='0'",{radio = 1,
            {'Horizontal', ru = 'Горизонтальный', action = function() CORE.RemapCoeditor() end, check = "iup.GetChild(iup.GetDialogChild(iup.GetLayout(), 'CoSourceExpanderBtm'),1)", },
            {'Vertical', ru = 'Вертикальный', action = function() CORE.RemapCoeditor() end, check = "not iup.GetChild(iup.GetDialogChild(iup.GetLayout(), 'CoSourceExpanderBtm'),1)", },
		},},
        {'s3', separator = 1},
		{'slast', separator = 1},

	},},
	{'Tools', ru = 'Инструменты',{
		{'&Compile', ru = 'Компилировать', key = 'Ctrl+F7', action = IDM_COMPILE, image = 'compile_µ', visible='props["command.compile$"]~=""'},
		{'&Build', ru = 'Собрать', key = 'F7', action = IDM_BUILD, image = 'building__arrow_µ', visible = 'props["command.build$"]~=""'},
		{'&Go', ru = 'Выполнить', key = 'F5', action = IDM_GO, image = 'control_µ', visible='props["command.go$"]~=""'},
		{'&Stop Executing', ru = 'Остановить выполнение', key = 'Ctrl+Break', action = IDM_STOPEXECUTE},
		{'Script', ru = 'Скрипт автозагрузки',{
			{'Reload', ru = 'Перезагрузить', key = 'Alt+Ctrl+Shift+R', action = function() scite.RunAsync(iup.ReloadScript) end,},
		},},
		{'s1', separator = 1},
		{'Utils', ru = 'Утилиты',{
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
		{'&Next Message', ru = 'Следующее сообщение', key = 'F4', action = IDM_NEXTMSG},
		{'&Previous Message', ru = 'Предыдущее сообщение', key = 'Shift+F4', action = IDM_PREVMSG},
		{'Clear &Output', ru = 'Очистить окно консоли', key = 'Shift+F5', action = IDM_CLEAROUTPUT},
		{'Clear &Find Result', ru = 'Очистить результаты поиска', action = "findres:SetText('')"},
		{'&Switch Pane', ru = 'Редактирование/Результаты поиска/Консоль', key = 'Ctrl+F6', action = function() CORE.SwitchPane(true) end},
		{'Switch Pane Back', ru = 'Редактирование/Консоль/Результаты поиска', key = 'Ctrl+Shift+F6', action = function() CORE.SwitchPane(false) end},
	},},
	{'Options', ru = 'Настройки',{

		{'&Wrap', ru = 'Перенос по словам', action = IDM_WRAP, check = "props['wrap']=='1'"},
		{'Wrap settings', ru = 'Настройки переноса по словам...', action = ResetWrapProps, visible = "props['wrap']=='1'"},
		{'&Read-Only', ru = 'Только для чтения', action = ResetReadOnly, check = "(shell.getfileattr(props['FilePath']) & 1) == 1"},
		{'s2', separator = 1},
		{'Line End Characters', ru = 'Символы перевода строк',{radio = 1,
			{'CR &+ LF', action = IDM_EOL_CRLF, check = "editor.EOLMode==SC_EOL_CRLF"},
			{'&CR', action = IDM_EOL_CR, check = "editor.EOLMode==SC_EOL_CR"},
			{'&LF', action = IDM_EOL_LF, check = "editor.EOLMode==SC_EOL_LF"},
		},},
		{'&Convert Line End Characters', ru = 'Конвертировать символы перевода строк', action = IDM_EOL_CONVERT},
		{'s1', separator = 1},
		{'Change Inden&tation Settings...', ru = 'Изменить настройки отступа', action = IDM_TABSIZE},
		{'Use &Monospaced Font', ru = 'Использовать моноширинные шрифты', action = IDM_MONOFONT},
		{'s2', separator = 1},
		{'Reload Session', ru = 'Восстанавливать открытые файлы', action = "CheckChange('session.reload', true)", check = "props['session.reload']=='1'"},
		{'Show Menu Icons', ru = 'Отображать иконки в меню', check_iuprops = 'menus.show.icons'},
		{'Show API Tool Tip', ru = 'Подсказки из API файла', check_iuprops = 'menus.tooltip.show', visible="props['apii$']~='' or props['apiix$']~=''"},
		{'Interface Font Size', ru = 'Размер шрифта интерфейса...', action = ResetFontSize},
        {'Tabbar Settings', ru = 'Свойства панели вкладок', action = ResetTabbarProps},

		{'s3', separator = 1},
		{'Hotkeys Settings', ru = 'Настройка горячих клавиш...', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\HotkeysSettings.lua')", active = RunSettings, image = "keyboards_µ"},
		{'Plugins', ru = 'Плагины', visible = RunSettings,{
            {'Toolbars Layout', ru = 'Раскладка панелей инструментов...', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\ToolBarsLayout.lua')", image = "ui_toolbar__arrow_µ"},
            {'SideBars Settings', ru = 'Настройка боковых панелей...', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\SideBarLayOut.lua')", image="application_sidebar_right_µ"},
            {'Status Bar Plugins', ru = 'Настройка строки состояния...', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\HiddenPlugins.lua')('Status')", image="ui_status_bar_blue_µ"},
            {'Hidden Plugins', ru = 'Подключение фоновых плагинов...', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\HiddenPlugins.lua')('Hidden')"},
            {'Commands Plugins', ru = 'Подключение команд...', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\HiddenPlugins.lua')('Commands')", image = 'terminal_µ'},
            {'s1', separator = 1},
            {'User Toolbar...', ru = 'Пользовательская панель инструментов...', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\ToolBarSetings.lua')"},
		},},
		{'Load Configuration...', ru = 'Загрузить конфигурацию...', iup.ConfigList},
		{'Save Configuration...', ru = 'Сохранить конфигурацию как...', action = iup.SaveIuprops, image = 'disk__pencil_µ'},
		{'Save Current Configuration', ru = 'Сохранить текущую конфигурацию: '..(iuprops['current.config.restore'] or ''):gsub('^.-([^\\]-)%.[^\\.]+$', '%1'), action = iup.SaveCurIuprops, visible = "iuprops['current.config.restore']~=nil", image = 'disk_µ'},
		{'s5', separator = 1},
		{'Windows Integration', ru = 'Настройка интеграции с Windows', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\WinAssoc.lua')"},
		{'Open &User Options File', ru = 'Открыть файл пользовательских настроек', action = IDM_OPENUSERPROPERTIES},
		{'Open &Global Options File', ru = 'Открыть файл глобальных настроек', action = IDM_OPENGLOBALPROPERTIES},
		{'Colors and Fonts', ru = 'Цвета и шрифты...', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\ColorSettings.lua')", active = RunSettings},
		{"Lexers properties", ru = 'Свойства лексеров', {
			{'Lexers properties', ru = 'Свойства лексеров', plane = 1 , tLangs},
			{'s2', separator = 1},
			{"Select lexers", ru = "Используемые языки", action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\UsedLexers.lua')", active = RunSettings},
		},},
	},},
	{'Language', ru = 'Подсветка', {
		{'tHilight', tHilight, plane = 1,},
		{'s1', separator = 1},
	},},
	{'Buffers', ru = 'Вкладки',{
		{'&Previous', ru = 'Предыдущая', key = 'Shift+F6', action = IDM_PREVFILE},
		{'&Next', ru = 'Следующая', key = 'F6', action = IDM_NEXTFILE},
		{'Move Tab &Left', ru = 'Переместить влево', action = IDM_MOVETABLEFT},
		{'Move Tab &Right', ru = 'Переместить вправо...', action = IDM_MOVETABRIGHT},
        {'Tabbar Settings', ru = 'Свойства панели вкладок...', action = ResetTabbarProps},
		{'&Close All', ru = 'Закрыть все', action = IDM_CLOSEALL},
		{'&Save All', ru = 'Сохранить все', key = 'Ctrl+Alt+S', action = function() DoForBuffers_Stack(function() scite.MenuCommand(IDM_SAVE) end) end, image = 'disks_µ'},
		{'&Full Save All', ru = 'Сохранить все с обработкой событий',  action = IDM_SAVEALL, image = 'disks_µ'},
		{'s2', separator = 1},
		{'l1', CORE.windowsList, plane = 1},
        {'s2', separator = 1},
        {'Buffers...', ru = 'Вкладки...', action = function() CORE.showWndDialog() end, },

	},},
	{'Help', ru = 'Справка',{
		{'&Help', ru = 'Контекстная справка', key = 'F1', action = IDM_HELP},
		{'H&ildiM Help', ru = 'Справка по HildiM', action = function() scite.ExecuteHelp(props['SciteDefaultHome']..'/help/HildiM.chm::ui/Menues.html', 0) end},
		{'slast', separator = 1},
        {'&About HildiM', ru = 'О программе', action = IDM_ABOUT},
	},},
}

