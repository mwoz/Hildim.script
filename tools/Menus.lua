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
    local ret, size = iup.GetParam("Шрифт диалогов и элементов интерфейса",
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

local tHilight, tLangs = {},{}
if shell.fileexists(props["SciteDefaultHome"].."\\data\\home\\HilightMenu.lua") then tHilight, tLangs = assert(loadfile(props["SciteDefaultHome"].."\\data\\home\\HilightMenu.lua"))() end

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

local bCanPaste = true
AddEventHandler("OnDrawClipboard", function(flag)
    bCanPaste = (flag > 0)
end)

_G.sys_Menus.TABBAR = {
    {link='File¦&Close'},
    {link='File¦C&lose All'},
    {'Close All But Curent',  ru = 'Зарыть все, кроме текущей', action=function() iup.CloseFilesSet(9132) end, },
    {'Close All Temporally',  ru = 'Зарыть все временные', action=function() iup.CloseFilesSet(9134) end, },
    {'s1', separator=1},
    {link='File¦&Save'},
    {link='Buffers¦&Save All'},
    {link='File¦Save &As...'},
    {link='File¦Save a Cop&y...'},
    {'s1', separator=1},
    {'Move Tab Left', ru = 'Переместить влево', action = IDM_MOVETABLEFT,},
    {'Move Tab Right', ru = 'Переместить вправо', action = IDM_MOVETABRIGHT,},
    {'Copy to Clipboard', ru='Копировать в буфер',{
        {'All Text', ru='Весь текст', action = function() CopyPathToClipboard("text") end,},
        {'Path/FileName', ru='Путь/Имя файла', action = function() CopyPathToClipboard("all") end,},
        {'Path', ru='Путь', action = function() CopyPathToClipboard("path") end,},
        {'FileName', ru='Имя файла', action = function() CopyPathToClipboard("name") end,},
    }},
    {link='File¦Encoding'},
    {link='Options¦&Read-Only'},
    {'slast', separator=1},
}
_G.sys_Menus.OUTPUT = {
    {link='Edit¦Conventional¦Cu&t'},
    {link='Edit¦Conventional¦&Copy'},
    {link='Edit¦Conventional¦&Paste'},
    {link='Edit¦Conventional¦&Delete'},
    {'s1', separator=1},
    {link='Tools¦Clear &Output'},
    {link='Tools¦&Previous Message'},
    {link='Tools¦&Next Message'},
    {'s2', separator=1},
    {'Input Mode', ru = 'Режим ввода', {
        {'Display Mode', ru = 'Отобразить(press Enter)', action = function() output:DocumentEnd();output:ReplaceSel('\\n###?') end},
        {'Command Line Mode', ru = 'Режим командной строки', action = function() output:DocumentEnd();output:ReplaceSel('\\n###c') end},
        {'LUA Mode', ru = 'Режим консоли LUA', action = function() output:DocumentEnd();output:ReplaceSel('\\n###l') end},
        {'IDM command Mode', ru = 'Режим команд IDM', action = function() output:DocumentEnd();output:ReplaceSel('\\n###i') end},
        {'Switch OFF', ru = 'Отключить', action = function() output:DocumentEnd();output:ReplaceSel('\\n####') end},
    }},
    {'slast', separator=1},
}

_G.sys_Menus.FINDRES = {
    {link='Edit¦Conventional¦Cu&t'},
    {link='Edit¦Conventional¦&Copy'},
    {link='Edit¦Conventional¦&Paste'},
    {link='Edit¦Conventional¦&Delete'},
    {'s1', separator=2},
    {link='Tools¦Clear &Find Result'},
    {'DblClick Only On Number', ru='DblClick только по номеру', check_boolean='findres.clickonlynumber'},
    {'Group By Name', ru='Группировать по имени файла', check_boolean='findres.groupbyfile'},
    {'Number Of Find Results...', ru='Результатов поиска не более....', action=SetFindresCount},
    {'slast', separator=1},

}

_G.sys_Menus.EDITOR = {
    {'s0', link='Edit¦Conventional¦&Undo'},
    {link='Edit¦Conventional¦&Redo'},
    {'s1', separator=1},
    {link='Edit¦Conventional¦Cu&t'},
    {link='Edit¦Conventional¦&Copy'},
    {link='Edit¦Conventional¦&Paste'},
    {link='Edit¦Conventional¦&Delete'},
    {link='Edit¦Conventional¦Duplicat&e'},
    {'s1', separator=2},
    {link='Edit¦Conventional¦Select &All'},
    {link='Search¦Search', plane=0},
    {link='View¦Folding', plane=0},
    {link='Search¦Toggle Bookmar&k'},
    {link='Search¦&Go to definition(Shift+Click)'},
}

_G.sys_Menus.MainWindowMenu = {
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
    {'File', ru='Файл',{
        {'New', ru='Создать', key = 'Ctrl+N', action = IDM_NEW, image = 'document__plus_µ'},
        {'&Open...', ru = 'Открыть', key = 'Ctrl+O', action = IDM_OPEN, image = 'folder_open_document_µ'},
        {'Open Selected &Filename', ru = 'Открыть выделенный файл', key = 'Ctrl+Shift+O', action = IDM_OPENSELECTED, active = function() return editor:GetSelText():find('%w:[\\/][^"\n\r\t]') end,},
        {'Recent Files', ru = 'Недавние файлы', visible="iuprops['resent.files.list']~=nil", function() return iuprops['resent.files.list']:GetMenu() end},
        {'&Revert', ru = 'Перезагрузить файл', key = 'Ctrl+R', action = IDM_REVERT},
        {'&Close', ru = 'Закрыть', key = 'Ctrl+W', action = IDM_CLOSE},
        {'C&lose All', ru = 'Закрыть все', action = IDM_CLOSEALL},
        {'&Save', ru = 'Сохранить', key = 'Ctrl+S', action = IDM_SAVE, active = function() return editor.Modify end, image = 'disk_µ'},
        {'Save &As...', ru = 'Сохранить как...', key = 'Ctrl+Shift+S', action = IDM_SAVEAS, image = 'disk__pencil_µ'},
        {'Save a Cop&y...', ru = 'Сохранить копию...', key = 'Ctrl+Shift+P', action = IDM_SAVEACOPY, image = 'disk__plus_µ'},
        --[[{'Copy Pat&h',  action = IDM_COPYPATH},]]
        {'Encoding', ru='Кодировка',{check_idm='editor.unicode.mode', radio = 1,
            {'&Code Page Property', ru='Заданная настройкой codepage', action = IDM_ENCODING_DEFAULT},
            {'UTF-16 &Big Endian',  action = IDM_ENCODING_UCS2BE},
            {'UTF-16 &Little Endian',  action = IDM_ENCODING_UCS2LE},
            {'UTF-8 &with BOM', ru='UTF-8 с заголовком', action = IDM_ENCODING_UTF8},
            {'&UTF-8',  action = IDM_ENCODING_UCOOKIE},
        },},
        {'&Export', ru='Экспорт',{
            {'As &HTML...' , ru = 'В &HTML..', action = IDM_SAVEASHTML},
            {'As &RTF...'  , ru = 'В &RTF...', action = IDM_SAVEASRTF},
            {'As &PDF...'  , ru = 'В &PDF...', action = IDM_SAVEASPDF},
            {'As &LaTeX...', ru = 'В &LaTeX...', action = IDM_SAVEASTEX},
            {'As &XML...'  , ru = 'В &XML...', action = IDM_SAVEASXML},
        },},
        {'s1', separator=1},
        {'Save Session...', ru = 'Сохранить сессию', action = iup.SaveSession,},
        {'Load Session...', ru = 'Загрузить сессию', action = iup.LoadSession,},
        {'s2', separator=1},
        {'Page Set&up...', ru = 'Параметры страницы', action = IDM_PRINTSETUP, image = 'layout_design_µ'},
        {'&Print...', ru = 'Печать...', key = 'Ctrl+P', action = IDM_PRINT, image = 'printer_µ'},
        {'s3', separator=1},
        {'Exit', ru='Выход', action = IDM_QUIT},
    },},
    {'Edit', ru='Правка',{
        {'Conventional',  ru = 'Стандартные', {
            {'&Undo', ru = 'Отменить', key = 'Ctrl+Z',key_external = 1, action = IDM_UNDO, active=function() return scintilla():CanUndo() end, image = 'arrow_return_270_left_µ'},
            {'&Redo', ru = 'Повторить', key = 'Ctrl+Y',key_external = 1, action = IDM_REDO, active=function() return scintilla():CanRedo() end, image = 'arrow_return_270_µ'},
            {'s1',  separator=1},
            {'Cu&t', ru = 'Вырезать', key = 'Ctrl+X',key_external = 1, action = IDM_CUT, active=IsSelection, image = 'scissors_µ'},
            {'&Copy', ru = 'Копировать', key = 'Ctrl+C',key_external = 1, action = IDM_COPY, active=IsSelection, image = 'document_copy_µ'},
            {'&Paste', ru = 'Вставить', key = 'Ctrl+V',key_external = 1, action = IDM_PASTE, image = 'clipboard_paste_µ', active=function() return bCanPaste end,},
            {'Duplicat&e', ru = 'Дублировать', key = 'Ctrl+D',key_external = 1, action = IDM_DUPLICATE, image = 'yin_yang_µ'},
            {'&Delete', ru = 'Удалить', key = 'Del',key_external = 1, action = IDM_CLEAR, image = 'cross_script_µ'},
            {'Select &All', ru = 'Выбрать все', key = 'Ctrl+A',key_external = 1, action = IDM_SELECTALL},
            {'Copy as RT&F', ru = 'Копировать в формате RTF', action = IDM_COPYASRTF, active=IsSelection},
        }},
        {'Xml',  ru ='Xml', visible_ext='xml,form,rform,cform',{
            {'Format Xml', ru='Форматировать Xml', action="dofile(props['SciteDefaultHome']..'\\\\tools\\\\FormatXml.lua')", image = 'broom_code_µ',},
        }},
        {'s1', separator=1},
        {'Match &Brace', ru = 'Найти парную скобку', key = 'Ctrl+E', action = IDM_MATCHBRACE},
        {'Select t&o Brace', ru = 'Выделить до парноий скобки', key = 'Ctrl+Shift+E', action = IDM_SELECTTOBRACE},
        {'Insert Special Char', ru = 'Вставить спецсимвол', action = function() SpecialChar() end, image = 'edit_symbol_µ'},
        {'Sorting of lines A… z / z… A', ru = 'Сортировать строки A… z / z… A', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\SortText.lua')"},

        {'S&how Calltip', ru = 'Показать подсказку', key = 'Ctrl+?', action = function() ShowTipManualy() end, image = 'ui_tooltip_balloon_bottom_µ',},
        -- {'Complete S&ymbol', ru = 'Завершить слово(из API и текста)', key = 'Ctrl+I', action = IDM_COMPLETE},
        {'Complete S&ymbol', ru = 'Завершить слово(из API)', key = 'Ctrl++', action= function() ShowListManualy() end},
        {'Complete &Word', ru = 'Завершить слово(из текста)', key = 'Ctrl+Enter', action = IDM_COMPLETEWORD},
        {'Expand Abbre&viation', ru = 'Вставить сокращение (%SEL%=выделение)', key = 'Ctrl+B', action = IDM_ABBREV, image = 'key_µ'},
        {'Expand Abbre&viation', ru = 'Вставить сокращение (%SEL%=клипбоард)', key = 'Ctrl+Alt+B', action = IDM_INS_ABBREV, image = 'key__plus_µ'},
        --[[{'&Insert Abbreviation', ru = 'Расшифровать сокращение', key = 'Ctrl+Shift+R', action = IDM_INS_ABBREV},]]
        {'Block Co&mment or Uncomment', ru = 'Закомментировать и раскомментировать текст', key = 'Ctrl+Q', action = IDM_BLOCK_COMMENT, image = 'edit_signiture_µ'},
        {'Bo&x Comment', ru = 'Блочный комментарий', key = 'Ctrl+Shift+B', action = IDM_BOX_COMMENT},
        {'Stream Comme&nt', ru = 'Потоковый комментарий', key = 'Ctrl+Shift+Q', action = IDM_STREAM_COMMENT},
        {'Make &Selection Uppercase', ru = 'Перевести в верхний регистр', key = 'Ctrl+Shift+U', action = IDM_UPRCASE, image = 'edit_uppercase_µ'},
        {'Make Selection &Lowercase', ru = 'Перевести в нижний регистр', key = 'Ctrl+U', action = IDM_LWRCASE, image = 'edit_lowercase_µ'},
    },},
    {'Search', ru='Поиск',{
        {'&Find...', ru = 'Найти', key = 'Ctrl+F', action = IDM_FIND, image = 'IMAGE_search'},
        {'Find &Next', ru = 'Найти далее', key = 'F3', action = IDM_FINDNEXT},
        {'Find Previou&s', ru = 'Предыдущее совпадение', key = 'Shift+F3', action = IDM_FINDNEXTBACK},
        {'F&ind in Files...', ru = 'Найти в файлах', key = 'Ctrl+Shift+F', action = IDM_FINDINFILES, image = 'folder_search_result_µ'},
        {'R&eplace...', ru = 'Заменить', key = 'Ctrl+H', action = IDM_REPLACE, image = 'IMAGE_Replace'},
        {'s0', separator=1},
        {'s1', separator=1},
        {'&Go to definition(Shift+Click)', ru = 'Перейти к описанию(Shift+Click)', key = 'F12', action = "menu_GoToObjectDefenition()"},
        {'&Go to...', ru = 'Перейти на позицию...', key = 'Ctrl+G', action = IDM_GOTO},
        {'Next Book&mark', ru = 'Следующая закладка', key = 'F2', action = IDM_BOOKMARK_NEXT, image = 'bookmark__arrow_µ'},
        {'Pre&vious Bookmark', ru = 'Предыдущая закладка', key = 'Shift+F2', action = IDM_BOOKMARK_PREV, image = 'bookmark__arrow_left_µ'},
        {'Toggle Bookmar&k', ru = 'Добавить/Удалить закладку', key = 'Ctrl+F2', action = IDM_BOOKMARK_TOGGLE, image = 'bookmark_µ'},
        {'&Clear All Bookmarks', ru = 'Очистить все закладки', action = IDM_BOOKMARK_CLEARALL},
    },},
    {'View', ru='Вид',{
        {'Folding', ru='Складка', plane=1, {
            {'Toggle &current fold', ru = 'Свернуть/Развернуть текущий блок', action = IDM_EXPAND},
            {'Toggle &all folds', ru = 'Свернуть/Развернуть все блоки', action = IDM_TOGGLE_FOLDALL},
            {'Toggle &recurse current fold', ru = 'Свернуть/Развернуть рекурсивно текущий блок', action = IDM_TOGGLE_FOLDRECURSIVE},
            {'Collapse Subfolders', ru = 'Свернуть подблоки', key='Ctrl+Shift+-', action = "Toggle_ToggleSubfolders(false)"},
            {'Expand Subfolders', ru = 'Развернуть подблоки', key='Ctrl+Shift++', action = "Toggle_ToggleSubfolders(true)"},
        }},
        {'s2', separator=1},
        {'Full Scree&n', ru = 'Полноэкранный режим', key = 'F11', action = IDM_FULLSCREEN},
        {'&Menu Bar', ru = 'Панель меню', action = function() iup.GetDialogChild(iup.GetLayout(), "MenuBar").switch() end, check = function() return iup.GetDialogChild(iup.GetLayout(), "MenuBar").isOpen() end},
        {'&Tool Bar', ru = 'Панель инструментов', action = function() iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").switch() end, check = function() return iup.GetDialogChild(iup.GetLayout(), "toolbar_expander").isOpen() end},
        {'Status Bar', ru = 'Панель статуса', action = function() iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").switch() end, check = function() return iup.GetDialogChild(iup.GetLayout(), "statusbar_expander").isOpen() end},
        {'Tab &Bar', ru = 'Вкладки', action = IDM_VIEWTABBAR, check = "props['tabbar.visible']=='1'"},
        {'s2', separator=1},
        {'&Whitespace', ru = 'Пробелы', key = 'Ctrl+Shift+8', action = IDM_VIEWSPACE, check = "props['view.whitespace']=='1'"},
        {'&End of Line', ru = 'Символы перевода строк', key = 'Ctrl+Shift+9', action = IDM_VIEWEOL, check = "editor.ViewEOL"},
        {'&Indentation Guides', ru = 'Направляющие отступа', action = IDM_VIEWGUIDES, check = "props['view.indentation.guides']=='1'"},
        {'&Line Numbers', ru = 'Нумера строк', action = IDM_LINENUMBERMARGIN, check = "props['line.margin.visible']=='1'"},
        {'&Margin', ru = 'Закладки', action = IDM_SELMARGIN, check = "scite.SendEditor(SCI_GETMARGINWIDTHN,1)>0"},
        {'&Fold Margin', ru = 'Поле сворачивания блоков текста', action = IDM_FOLDMARGIN, check = "scite.SendEditor(SCI_GETMARGINWIDTHN,2)>0"},
        {'s3', separator=1},
        {'slast', separator=1},

    },},
    {'Tools', ru='Инструменты',{
        {'&Compile', ru = 'Компилировать', key = 'Ctrl+F7', action = IDM_COMPILE, image = 'compile_µ'},
        {'&Build', ru = 'Собрать', key = 'F7', action = IDM_BUILD, image = 'building__arrow_µ'},
        {'&Go', ru = 'Выполнить', key = 'F5', action = IDM_GO, image = 'control_µ'},
        {'&Stop Executing', ru = 'Остановить выполнение', key = 'Ctrl+Break', action = IDM_STOPEXECUTE},
        {'Script', ru='Скрипт автозагрузки',{
            {'Reload', ru = 'Перезагрузить', key = 'Alt+Ctrl+Shift+R', action = function() scite.PostCommand(POST_SCRIPTRELOAD,0) end,},
        },},
        {'s1', separator=1},
        {'Utils', ru='Утилиты',{
            {'Lpeg Tester', action="dofile(props['SciteDefaultHome']..'\\\\tools\\\\lpegTester.lua')",},
            {'Replace spaces (TABs <-> Spaces)', ru ='Заменить табы на пробелы', action="dofile(props['SciteDefaultHome']..'\\\\tools\\\\IndentTabToSpace.lua')",},
            {'4->3 Tab size Indent', ru ='Отступ 4->3', action=function() For2ThreeTabIndent() end,},
            {'LayOut Dialog', action=(function()
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
                        local _,_, fName = strLua:find("function (create_dialog_[_%w]+)")
                        strLua = strLua..'\n testHandle = '..fName..'()'
                        dostring(strLua)
                    end
                    local dlg = iup.LayoutDialog(testHandle)
                    iup.Show(dlg)
                  end),
            },
        },},
        {'ASCII Table', ru = 'Таблица ASCII символов', action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\ASCIITable.lua')"},
        {'s2', separator=1},
        {'&Next Message', ru = 'Следующее сообщение', key = 'F4', action = IDM_NEXTMSG},
        {'&Previous Message', ru = 'Предыдущее сообщение', key = 'Shift+F4', action = IDM_PREVMSG},
        {'Clear &Output', ru = 'Очистить окно консоли', key = 'Shift+F5', action = IDM_CLEAROUTPUT},
        {'Clear &Find Result', ru = 'Очистить результаты поиска', action = "findres:SetText('')"},
        {'&Switch Pane', ru = 'Редактирование/Консоль', key = 'Ctrl+F6', action = IDM_SWITCHPANE},
    },},
    {'Options', ru='Настройки',{

        {'&Wrap', ru = 'Перенос по словам', action = IDM_WRAP, check = "props['wrap']=='1'"},
        {'Wrap Find &Result', ru = 'Перенос по словам в результатах поиска', action = IDM_WRAPFINDRES, check = "props['findres.wrap']=='1'"},
        {'&Read-Only', ru = 'Только для чтения', action = ResetReadOnly, check = "shell.bit_and(shell.getfileattr(props['FilePath']), 1) == 1"},
        {'s2', separator=1},
        {'Line End Characters', ru='Символы перевода строк',{radio = 1,
            {'CR &+ LF',  action = IDM_EOL_CRLF, check = "editor.EOLMode==SC_EOL_CRLF"},
            {'&CR',  action = IDM_EOL_CR, check = "editor.EOLMode==SC_EOL_CR"},
            {'&LF',  action = IDM_EOL_LF, check = "editor.EOLMode==SC_EOL_LF"},
        },},
        {'Output', ru='Окно консоли',{
            {'Wrap Out&put', ru = 'Перенос по словам в консоли', action = IDM_WRAPOUTPUT, check = "props['output.wrap']=='1'"},
            {'Clear Before Execute', ru = 'Очищать перед выполнением', check_prop = "clear.before.execute"},
            {'Recode OEM to ANSI', ru = 'Перекодировать OEM в ANSI', check_prop = "output.code.page.oem2ansi"},
        },},
        {'&Convert Line End Characters', ru = 'Конвертировать символы перевода строк', action = IDM_EOL_CONVERT},
        {'s1', separator=1},
        {'Change Inden&tation Settings...', ru = 'Изменить настройки отступа', action = IDM_TABSIZE},
        {'Use &Monospaced Font', ru = 'Использовать моноширинные шрифты', action = IDM_MONOFONT},
        {'s2', separator=1},
        {'Reload Session', ru = 'Восстанавливать открытые файлы', action = "CheckChange('session.reload', true)", check="props['session.reload']=='1'"},
        {'Show Menu Icons', ru = 'Отображать иконки в меню', check_iuprops = 'menus.show.icons'},
        {'Interface Font Size', ru = 'Размер шрифта интерфейса', action = ResetFontSize},

        {'s3', separator=1},
        {'Hotkeys Settings', ru = 'Настройка горячих клавиш...', action="dofile(props['SciteDefaultHome']..'\\\\tools\\\\HotkeysSettings.lua')"},
        {'User Toolbar...', ru = 'Пользовательская панель инстументов...', action="dofile(props['SciteDefaultHome']..'\\\\tools\\\\ToolBarSetings.lua')"},
        {'Toolbars Layout', ru = 'Раскладка панелей инстументов...', action="dofile(props['SciteDefaultHome']..'\\\\tools\\\\ToolBarsLayout.lua')"},
        {'SideBars Settings', ru = 'Настройка боковых панелей...', action="dofile(props['SciteDefaultHome']..'\\\\tools\\\\SideBarLayOut.lua')"},
        {'s3', separator=1},
        {'Save Configuration', ru = 'Сохранить конфигурацию', action=iup.SaveIuprops},
        {'Load Configuration', ru = 'Загрузить конфигурацию', action=iup.LoadIuprops},
        {'s5', separator=1},
        {'Windows Integration', ru = 'Настройка интеграции с Windows', action="shell.exec(props['SciteDefaultHome']..'\\\\tools\\\\SciTE_WinIntegrator.hta')"},
        {'Open &User Options File', ru = 'Открыть файл пользовательских настроек', action = IDM_OPENUSERPROPERTIES},
        {'Open &Global Options File', ru = 'Открыть файл глобальных настроек', action = IDM_OPENGLOBALPROPERTIES},
        {'Open Lua Startup Scr&ipt', ru = 'Открыть файл автозагрузки скрипта', action = IDM_OPENLUAEXTERNALFILE},
        {'Change Lexer Colors', ru = 'Изменить цвета лексера...', action = function() do_LexerColors() end},
        {"Lexers properties", ru = 'Свойства лексеров', {
            {'Lexers properties', ru='Свойства лексеров', plane=1 ,tLangs},
            {'s2', separator=1},
            {"Select lexers", ru = "Используемые языки", action = "dofile(props['SciteDefaultHome']..'\\\\tools\\\\UsedLexers.lua')"},
        },},
    },},
    {'Language', ru='Подсветка', {
        {'tHilight', tHilight, plane = 1,},
        {'s1', separator=1},
    },},
    {'Buffers', ru='Вкладки',{
        {'&Previous', ru = 'Предыдущая', key = 'Shift+F6', action = IDM_PREVFILE},
        {'&Next', ru = 'Следующая', key = 'F6', action = IDM_NEXTFILE},
        {'Move Tab &Left', ru = 'Переместить влево', action = IDM_MOVETABLEFT},
        {'Move Tab &Right', ru = 'Переместить вправо', action = IDM_MOVETABRIGHT},
        {'&Close All', ru = 'Закрыть все', action = IDM_CLOSEALL},
        {'&Save All', ru = 'Сохранить все', key = 'Ctrl+Alt+S', action = IDM_SAVEALL, image = 'disks_µ'},
        {'s2', separator=1},
        {'l1', windowsList, plane = 1},
    },},
    {'Help', ru='Справка',{
        {'&Help', ru = 'Справка по LUA', key = 'F1', action = IDM_HELP},
        {'&SciTE Help', ru = 'Справка по SciTE', action = IDM_HELP_SCITE},
        {'&About SciTE', ru = 'О программе', action = IDM_ABOUT},
    },},
}

