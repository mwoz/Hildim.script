-- Этот файл стартует при загрузке SciTE
-- Чтобы не забивать его его огромным количеством используемых скриптов, поскольку это затрудняет работу редактора, большинство из них хранятся в обособленных файлах и грузятся только при выборе соответствующего пункта меню Tools.
-- Здесь (с помощью dofile) грузятся только скрипты, обрабатывающие события редактора.

----[[ C O M M O N ]]-------------------------------------------------------
--Загрузка имэджей
iup.Load(props["SciteDefaultHome"].."\\tools\\Images.led")
dofile (props["SciteDefaultHome"].."\\tools\\Images.lua")
--iup.Load(props["SciteDefaultHome"].."\\tools\\Images22.led")
-- Подключение файла с общими функциями, использующимися во многих скриптах
dofile (props["SciteDefaultHome"].."\\tools\\COMMON.lua")
Splash_Screen()
dofile (props["SciteDefaultHome"].."\\tools\\Menus.lua")

----[[ R E A D   O N L Y ]]-------------------------------------------------

-- Замена стандартной команды "Read-Only"
-- Красит фон вкладки не доступной для редактирования и показывает состояние в статусной строке
dofile (props["SciteDefaultHome"].."\\tools\\ReadOnly.lua")

-- При открытии ReadOnly, Hidden, System файлов включает режим ReadOnly в SciTE
dofile (props["SciteDefaultHome"].."\\tools\\ROCheck.lua")

-- Поддержка сохранения RO файлов
--dofile (props["SciteDefaultHome"].."\\tools\\ROWrite.lua")

----[[ С К О Б К И   К О М М Е Н Т А Р И И ]]-------------------------------

-- Автозакрытие скобок
dofile (props["SciteDefaultHome"].."\\tools\\smartbraces.lua")

-- Автозакрытие HTML тегов
dofile (props["SciteDefaultHome"].."\\tools\\paired_tags.lua")

-- Универсальное комментирование и снятие комментариев (по Ctrl+Q)
dofile (props["SciteDefaultHome"].."\\tools\\xComment.lua")
--~ dofile (props["SciteDefaultHome"].."\\tools\\smartcomment.lua")

----[[ О Т К Р Ы Т Ь  Ф А Й Л ]]----------------------------------------------

-- Замена стандартной команды SciTE "Открыть выделенный файл"
dofile (props["SciteDefaultHome"].."\\tools\\Open_Selected_Filename.lua")

-- Расширение стандартной команды SciTE "Открыть выделенный файл" (открывает без предварительного выделения)
-- А также возможность открыть файл по двойному клику мыши на его имени при нажатой клавише Ctrl.
-- dofile (props["SciteDefaultHome"].."\\tools\\Select_And_Open_Filename.lua")

----[[ А В Т О М А Т И З А Ц И Я ]]-------------------------------------------

-- Подключение LuaInspect <http://lua-users.org/wiki/LuaInspect>
if props["luainspect.path"] ~= '' then dofile (props["SciteDefaultHome"].."\\tools\\LuaInspectInstall.lua") end

-- При переходе на заданную строку, прокручивает текст, сохраняя позицию курсора на экране
dofile (props["SciteDefaultHome"].."\\tools\\goto_line.lua")

-- Заменяет стандартную команду SciTE "File|New" (Ctrl+N). Создает новый буфер в текущем каталоге с расширением текущего файла
dofile (props["SciteDefaultHome"].."\\tools\\new_file.lua")

-- Включает HTML подсветку для файлов без расширения, открываемых из меню "просмотр HTML-кода" Internet Explorer
dofile (props["SciteDefaultHome"].."\\tools\\set_html.lua")

-- Восстановление позиции курсора, букмарков и фолдинга при повторном открытии ЛЮБОГО файла.
dofile (props["SciteDefaultHome"].."\\tools\\RestoreRecent.lua")

-- Фолдинг для текстовых файлов
dofile (props["SciteDefaultHome"].."\\tools\\FoldText.lua")

--Обработка шаблонов форм

dofile (props["SciteDefaultHome"].."\\tools\\precompiller.lua")

dofile (props["SciteDefaultHome"].."\\tools\\sqlObjects.lua")

dofile (props["SciteDefaultHome"].."\\tools\\InsertSpecialChar.lua")

-- Подставляет адекватный символ комментария для ini, inf, reg и php файлов
dofile (props["SciteDefaultHome"].."\\tools\\ChangeCommentChar.lua")

-- Копирование имени файла в буфер Обмена
dofile (props["SciteDefaultHome"].."\\tools\\CopyPathToClipboard.lua")

----[[ Д О П О Л Н И Т Е Л Ь Н Ы Е  М Е Н Ю ]]--------------------------------

-- Создает в контекстном меню таба (вкладки) подменю для команд SVN
--dofile (props["SciteDefaultHome"].."\\tools\\svn_menu.lua")

-- Создает в контекстном меню таба (вкладки) подменю для команд VSS
dofile (props["SciteDefaultHome"].."\\tools\\vss_showmenu.lua")

----[[ У Т И Л И Т Ы  И  И Н С Т Р У М Е Н Т Ы ]]-----------------------------

-- SideBar: Многофункциональная боковая панель
--dofile (props["SciteDefaultHome"].."\\tools\\IupSideBar.lua")
-- Автодополнение объектов их методами и свойствами
dofile (props["SciteDefaultHome"].."\\tools\\AutocompleteObject.lua")
-- Автодополнение объектов их методами и свойствами
dofile (props["SciteDefaultHome"].."\\tools\\ColorSettings.lua")

-- Вставка спецсимволов (©,®,§,±,…) из раскрывающегося списка (для HTML вставляются их обозначения)
dofile (props["SciteDefaultHome"].."\\tools\\InsertSpecialChar.lua")

-- Поиск и подсветка всех вхождений выделенного слова
dofile (props["SciteDefaultHome"].."\\tools\\FindTextOnSel.lua")
dofile (props["SciteDefaultHome"].."\\tools\\SortControlXml.lua")
dofile (props["SciteDefaultHome"].."\\tools\\Align.lua")
-- Установка / снятие меток на строку (Bookmark) (то же что и Ctrl+F2)
-- с помощью клика мыши при нажатой клавише Ctrl
--dofile (props["SciteDefaultHome"].."\\tools\\BookmarkToggle.lua")

----[[ Н А С Т Р О Й К И   И Н Т Е Р Ф Е Й С А ]]-----------------------------

dofile (props["SciteDefaultHome"].."\\tools\\Autoformat.lua")
dofile (props["SciteDefaultHome"].."\\tools\\spell.lua")


-- SideBar: Многофункциональная боковая панель
dofile (props["SciteDefaultHome"].."\\tools\\IupSideBar.lua")

-- Установка размера символа табуляции в окне консоли
local tab_width = tonumber(props['output.tabsize'])
if tab_width ~= nil then
	scite.SendOutput(SCI_SETTABWIDTH, tab_width)
end

----[[ В Н Е Ш Н И Е  Л Е К С Е Р Ы ]]-----------------------------

-- Лексер для текстовых файлов
--dofile (props["SciteDefaultHome"].."\\languages\\text.lua")


scite.PostCommand(POST_CONTINUESTARTUP,0)
