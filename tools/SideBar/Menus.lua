--[[
первое поле - английский заголовок и уникальный(в данном подменю) идентификатор
для подменю второе поле - таблица со строками итемами, подменю и сепараторами. Наличие второго, неименованного поля - признак саюменю
атрибуты:
    - <nls> - заголовок на языке
    - key - акселератор
    - key_external - его не нужно регистрировать
    Доступность пунктов
    - active - строка с логическим выражением, возвращающим true или false
    Видимость
    - visible  - строка с логическим выражением, возвращающим true или false
    - visible_ext - список расширений файлов, для которых пункт видимый
    отмечено
    - check_idm prop, который нужно сравнить с idm
    - check  - строка с логическим выражением, возвращающим true или false
    действие
    - idm - идентификатор меню скайта
    - action
    - action_lua
    - action_cmd
]]
_G.sys_Menus = {}
_G.sys_Menus.MainWindowMenu = {
    {'File', ru='Файл',{
        {'New', ru='Создать', key = 'Ctrl+N', idm = IDM_NEW},
        {'&Open...', ru = 'Открыть', key = 'Ctrl+O', idm = IDM_OPEN},
        {'Open Selected &Filename', ru = 'Открыть выделенный файл', key = 'Ctrl+Shift+O', idm = IDM_OPENSELECTED},
        {'&Revert', ru = 'Перезагрузить файл', key = 'Ctrl+R', idm = IDM_REVERT},
        {'&Close', ru = 'Закрыть', key = 'Ctrl+W', idm = IDM_CLOSE},
        {'&Save', ru = 'Сохранить', key = 'Ctrl+S', idm = IDM_SAVE},
        {'Save &As...', ru = 'Сохранить как...', key = 'Ctrl+Shift+S', idm = IDM_SAVEAS},
        {'Save a Cop&y...', ru = 'Сохранить копию...', key = 'Ctrl+Shift+P', idm = IDM_SAVEACOPY},
        {'Copy Pat&h', ru = '', idm = IDM_COPYPATH},
        {'Encoding', ru='Кодировка',{
            {'&Code Page Property', ru='Заданная настройкой codepage', idm = IDM_ENCODING_DEFAULT, check_idm='editor.unicode.mode'},
            {'UTF-16 &Big Endian', ru = '', idm = IDM_ENCODING_UCS2BE, check_idm='editor.unicode.mode', check='tonumber(props["editor.unicode.mode"])==IDM_ENCODING_UCS2BE'},
            {'UTF-16 &Little Endian', ru = '', idm = IDM_ENCODING_UCS2LE},
            {'UTF-8 &with BOM', ru='UTF-8 с заголовком', idm = IDM_ENCODING_UTF8},
            {'&UTF-8', ru = '', idm = IDM_ENCODING_UCOOKIE},
        },},
        {'&Export', ru='Экспорт',{
            {'As &HTML...', ru = '', idm = IDM_SAVEASHTML},
            {'As &RTF...', ru = '', idm = IDM_SAVEASRTF},
            {'As &PDF...', ru = '', idm = IDM_SAVEASPDF},
            {'As &LaTeX...', ru = '', idm = IDM_SAVEASTEX},
            {'As &XML...', ru = '', idm = IDM_SAVEASXML},
        },},
        {'s1', separator=1},
        {'Page Set&up...', ru = 'Параметры страницы', idm = IDM_PRINTSETUP},
        {'&Print...', ru = 'Печать...', key = 'Ctrl+P', idm = IDM_PRINT},
        {'s2', separator=1},
        {'&Load Session...', ru = 'Загрузить сессию...', idm = IDM_LOADSESSION},
        {'Sa&ve Session...', ru = 'Сохранить сессию...', idm = IDM_SAVESESSION},
        {'s3', separator=1},
        {'Exit', ru='Выход', idm = IDM_QUIT},
    },},
    {'Edit', ru='Правка',{
        {'&Undo', ru = 'Отменить', key = 'Ctrl+Z',key_external = 1, idm = IDM_UNDO},
        {'&Redo', ru = 'Повторить', key = 'Ctrl+Y',key_external = 1, idm = IDM_REDO},
        {'s1',  separator=1},
        {'Cu&t', ru = 'Вырезать', key = 'Ctrl+X',key_external = 1, idm = IDM_CUT, active="editor.SelectionStart<editor.SelectionEnd"},
        {'&Copy', ru = 'Копировать', key = 'Ctrl+C',key_external = 1, idm = IDM_COPY, active="editor.SelectionStart<editor.SelectionEnd"},
        {'&Paste', ru = 'Вставить', key = 'Ctrl+V',key_external = 1, idm = IDM_PASTE},
        {'Duplicat&e', ru = 'Дублировать', key = 'Ctrl+D',key_external = 1, idm = IDM_DUPLICATE},
        {'&Delete', ru = 'Удалить', key = 'Del',key_external = 1, idm = IDM_CLEAR},
        {'Select &All', ru = 'Выбрать все', key = 'Ctrl+A',key_external = 1, idm = IDM_SELECTALL, active="editor.SelectionStart<editor.SelectionEnd"},
        {'Copy as RT&F', ru = 'Копировать в формате RTF', idm = IDM_COPYASRTF, active="editor.SelectionStart<editor.SelectionEnd"},
        {'s2', separator=1},
        {'Match &Brace', ru = 'Найти парную скобку', key = 'Ctrl+E', idm = IDM_MATCHBRACE},
        {'Select t&o Brace', ru = 'Выделить до парний сокбки', key = 'Ctrl+Shift+E', idm = IDM_SELECTTOBRACE},
        {'S&how Calltip', ru = 'Подсказать подсказку', key = 'Ctrl+Shift+Space', idm = IDM_SHOWCALLTIP},
        {'Complete S&ymbol', ru = 'Завершить слово(из API и текста)', key = 'Ctrl+I', idm = IDM_COMPLETE},
        {'Complete &Word', ru = 'Завершить слово(из текста)', key = 'Ctrl+Enter', idm = IDM_COMPLETEWORD},
        {'Expand Abbre&viation', ru = 'Вставить сокращение', key = 'Ctrl+B', idm = IDM_ABBREV},
        {'&Insert Abbreviation', ru = 'Расшифровать сокращение', key = 'Ctrl+Shift+R', idm = IDM_INS_ABBREV},
        {'Block Co&mment or Uncomment', ru = 'Закоментировать и раскоментировать текст', key = 'Ctrl+Q', idm = IDM_BLOCK_COMMENT},
        {'Bo&x Comment', ru = 'Блочный комментарий', key = 'Ctrl+Shift+B', idm = IDM_BOX_COMMENT},
        {'Stream Comme&nt', ru = 'Потоковый комментарий', key = 'Ctrl+Shift+Q', idm = IDM_STREAM_COMMENT},
        {'Make &Selection Uppercase', ru = 'Перевести в верхний регистр', key = 'Ctrl+Shift+U', idm = IDM_UPRCASE},
        {'Make Selection &Lowercase', ru = 'Перевести в нижний регистр', key = 'Ctrl+U', idm = IDM_LWRCASE},
    },},
    {'Search', ru='Поиск',{
        {'&Find...', ru = 'Найти', key = 'Ctrl+Alt+Shift+F', idm = IDM_FIND},
        {'Find &Next', ru = 'Найти далее', key = 'F3', idm = IDM_FINDNEXT},
        {'Find Previou&s', ru = 'Предыдущее совпадение', key = 'Shift+F3', idm = IDM_FINDNEXTBACK},
        {'F&ind in Files...', ru = 'Найти в файлах', key = 'Ctrl+Shift+F', idm = IDM_FINDINFILES},
        {'R&eplace...', ru = 'Заменить', key = 'Ctrl+H', idm = IDM_REPLACE},
        {'s1', separator=1},
        {'&Go to...', ru = 'Перейти на позицию...', key = 'Ctrl+G', idm = IDM_GOTO},
        {'Next Book&mark', ru = 'Следующая закладка', key = 'F2', idm = IDM_BOOKMARK_NEXT},
        {'Pre&vious Bookmark', ru = 'Предыдущая закладка', key = 'Shift+F2', idm = IDM_BOOKMARK_PREV},
        {'Toggle Bookmar&k', ru = 'Добавить/Удалить закладку', key = 'Ctrl+F2', idm = IDM_BOOKMARK_TOGGLE},
        {'&Clear All Bookmarks', ru = 'Очистить все закладки', idm = IDM_BOOKMARK_CLEARALL},
    },},
    {'View', ru='Вид',{
        {'Toggle &current fold', ru = 'Свернуть/Развернуть текущий блок текста', idm = IDM_EXPAND},
        {'Toggle &all folds', ru = 'Свернуть/Развернуть все блоки текста', idm = IDM_TOGGLE_FOLDALL},
        {'s2', separator=1},
        {'Full Scree&n', ru = 'Полноэкранный режим', key = 'F11', idm = IDM_FULLSCREEN},
        {'&Tool Bar', ru = 'Панель инструментов', idm = IDM_VIEWTOOLBAR},
        {'Tab &Bar', ru = 'Вкладки', idm = IDM_VIEWTABBAR},
        {'&Status Bar', ru = 'Строка состояния', idm = IDM_VIEWSTATUSBAR},
        {'s2', separator=1},
        {'&Whitespace', ru = 'Пробелы', key = 'Ctrl+Shift+8', idm = IDM_VIEWSPACE},
        {'&End of Line', ru = 'Символы перевода строк', key = 'Ctrl+Shift+9', idm = IDM_VIEWEOL},
        {'&Indentation Guides', ru = 'Направляющие отступа', idm = IDM_VIEWGUIDES},
        {'&Line Numbers', ru = 'Нумера строк', idm = IDM_LINENUMBERMARGIN},
        {'&Margin', ru = 'Закладки', idm = IDM_SELMARGIN},
        {'&Fold Margin', ru = 'Поле сворачивания блоков текста', idm = IDM_FOLDMARGIN},
        {'&Output', ru = 'Окно консоли', key = 'F8', idm = IDM_TOGGLEOUTPUT},
        {'&Parameters', ru = 'Параметры', key = 'Shift+F8', idm = IDM_TOGGLEPARAMETERS},
    },},
    {'Tools', ru='Инструменты',{
        {'&Compile', ru = 'Компилировать', key = 'Ctrl+F7', idm = IDM_COMPILE},
        {'&Build', ru = 'Собрать', key = 'F7', idm = IDM_BUILD},
        {'&Go', ru = 'Выполнить', key = 'F5', idm = IDM_GO},
        {'&Stop Executing', ru = 'Остановить выполнение', key = 'Ctrl+Break', idm = IDM_STOPEXECUTE},
        {'Script', ru='Скрипт автозагрузки',{
            {'Reload', ru = 'Перезагрузить', key = 'Alt+Ctrl+Shift+R', --[[idm = 9117]] action = function() scite.PostCommand(5,0) end,},
        },},
        {'s1', separator=1},
        {'&Next Message', ru = 'Следующее сообщение', key = 'F4', idm = IDM_NEXTMSG},
        {'&Previous Message', ru = 'Предыдущее сообщение', key = 'Shift+F4', idm = IDM_PREVMSG},
        {'Clear &Output', ru = 'Очистить окно консоли', key = 'Shift+F5', idm = IDM_CLEAROUTPUT},
        {'&Switch Pane', ru = 'Редактирование/Консоль', key = 'Ctrl+F6', idm = IDM_SWITCHPANE},
    },},
    {'Options', ru='Настройки',{
        {'&Always On Top', ru = 'Поверх всех окон', idm = IDM_ONTOP},
        {'Open Files &Here', ru = 'Открывать одна копия программы', idm = IDM_OPENFILESHERE},
        --[[{'Vertical &Split', ru = '', idm = IDM_SPLITVERTICAL},]]
        {'&Wrap', ru = 'Перенос по словам', idm = IDM_WRAP},
        {'Wrap Out&put', ru = 'Перенос по словам в консоли', idm = IDM_WRAPOUTPUT},
        {'Wrap Find &Result', ru = 'Перенос по словам в окне результатов', idm = IDM_WRAPFINDRES},
        {'&Read-Only', ru = 'Только для чтения', idm = IDM_READONLY},
        {'s2', separator=1},
        {'Line End Characters', ru='Символы перевода строк',{
            {'CR &+ LF', ru = '', idm = IDM_EOL_CRLF},
            {'&CR', ru = '', idm = IDM_EOL_CR},
            {'&LF', ru = '', idm = IDM_EOL_LF},
        },},
        {'&Convert Line End Characters', ru = 'Конвертировать символы перевода строк', idm = IDM_EOL_CONVERT},
        {'s1', separator=1},
        {'Change Inden&tation Settings...', ru = 'Изменить настройки отступа', idm = IDM_TABSIZE},
        {'Use &Monospaced Font', ru = 'Использовать моноширинные шривты', idm = IDM_MONOFONT},
        {'s2', separator=1},
        {'Open Local &Options File', ru = 'Открыть файл локальных настроек', idm = IDM_OPENLOCALPROPERTIES},
        {'Open &Directory Options File', ru = 'Открыть файл настроек каталога', idm = IDM_OPENDIRECTORYPROPERTIES},
        {'Open &User Options File', ru = 'Открыть файл пользовательских настроек', idm = IDM_OPENUSERPROPERTIES},
        {'Open &Global Options File', ru = 'Открыть файл глобальных настроек', idm = IDM_OPENGLOBALPROPERTIES},
        --[[{'Open A&bbreviations File', ru = 'Открыть файл настроек сокращений', idm = IDM_OPENABBREVPROPERTIES},]]
        {'Open Lua Startup Scr&ipt', ru = 'Открыть файл автозагрузки скрипта', idm = IDM_OPENLUAEXTERNALFILE},
        {'Edit properties', ru='Свойства лексера',{
            {'s1', separator=1},
        },},
    },},
    {'Language', ru='Подсветка',{
        {'s1', separator=1},
    },},
    {'Buffers', ru='Вкладки',{
        {'&Previous', ru = 'Предыдущая', key = 'Shift+F6', idm = IDM_PREVFILE},
        {'&Next', ru = 'Следующая', key = 'F6', idm = IDM_NEXTFILE},
        {'Move Tab &Left', ru = 'Переместить влево', idm = IDM_MOVETABLEFT},
        {'Move Tab &Right', ru = 'Переместить вправо', idm = IDM_MOVETABRIGHT},
        {'&Close All', ru = 'Закрыть все', idm = IDM_CLOSEALL},
        {'&Save All', ru = 'Сохранить все', idm = IDM_SAVEALL},
    },},
    {'Help', ru='Справка',{
        {'&Help', ru = 'Справка по LUA', key = 'F1', idm = IDM_HELP},
        {'&SciTE Help', ru = 'Справка по SciTE', idm = IDM_HELP_SCITE},
        {'&About SciTE', ru = 'О программе', idm = IDM_ABOUT},
    },},
    {'_HIDDEN_', {
        {'Ctrl+Tab', key = 'Ctrl+Tab', idm = IDM_NEXTFILESTACK},
        {'Ctrl+Shift+Tab', key = 'Ctrl+Shift+Tab', idm = IDM_PREVFILESTACK},
    },},
}

