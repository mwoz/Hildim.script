--[[--------------------------------------------------
Paired Tags (логическое продолжение скриптов highlighting_paired_tags.lua и HTMLFormatPainter.lua)
Version: 2.5.0
Author: mozers™, VladVRO, TymurGubayev, nail333
------------------------------
Подсветка парных и непарных тегов в HTML и XML
В файле настроек задается цвет подсветки парных и непарных тегов

Скрипт позволяет копировать и удалять (текущие подсвеченные) теги, а также
вставлять в нужное место ранее скопированные (обрамляя тегами выделенный текст)

Внимание:
В скрипте используются функции из COMMON.lua (EditorMarkText, EditorClearMarks)

------------------------------
Подключение:
Добавить в SciTEStartup.lua строку:
	dofile (props["SciteDefaultHome"].."\\tools\\paired_tags.lua")
Добавить в файл настроек параметр:
	hypertext.highlighting.paired.tags=1
Дополнительно можно задать стили используемых маркеров (11 и 12):
	indic.style.11=#0099FF
	indic.style.22=#FF0000 (если этот параметр не задан, то непарные теги не подсвечиваются)

Команды копирования, вставки, удаления тегов добавляются в меню Tools обычным порядком:
	tagfiles=$(file.patterns.html);$(file.patterns.xml)

	command.name.5.$(tagfiles)=Copy Tags
	command.5.$(tagfiles)=CopyTags
	command.mode.5.$(tagfiles)=subsystem:lua,savebefore:no
	command.shortcut.5.$(tagfiles)=Alt+C

	command.name.6.$(tagfiles)=Paste Tags
	command.6.$(tagfiles)=PasteTags
	command.mode.6.$(tagfiles)=subsystem:lua,savebefore:no
	command.shortcut.6.$(tagfiles)=Alt+P

	command.name.7.$(tagfiles)=Delete Tags
	command.7.$(tagfiles)=DeleteTags
	command.mode.7.$(tagfiles)=subsystem:lua,savebefore:no
	command.shortcut.7.$(tagfiles)=Alt+D

	command.name.8.$(tagfiles)=Goto Paired Tag
	command.8.$(tagfiles)=GotoPairedTag
	command.mode.8.$(tagfiles)=subsystem:lua,savebefore:no
	command.shortcut.8.$(tagfiles)=Alt+B

	command.name.9.$(tagfiles)=Select With Tags
	command.9.$(tagfiles)=SelectWithTags
	command.mode.9.$(tagfiles)=subsystem:lua,savebefore:no
	command.shortcut.9.$(tagfiles)=Alt+S

Для быстрого включения/отключения подсветки можно добавить команду:
	command.separator.10.$(tagfiles)=1
	command.checked.10.$(tagfiles)=$(hypertext.highlighting.paired.tags)
	command.name.10.$(tagfiles)=Highlighting Paired Tags
	command.10.$(tagfiles)=highlighting_paired_tags_switch
	command.mode.10.$(tagfiles)=subsystem:lua,savebefore:no
--]]----------------------------------------------------

local t = {}
-- t.tag_start, t.tag_end, t.paired_start, t.paired_end  -- positions
-- t.begin, t.finish  -- contents of tags (when copying)
local old_current_pos
local blue_indic, red_indic = 24, 23 -- номера используемых маркеров

local bEnable, styleSpace, styleBracket = false, 0, 1

function CopyTags()
	if not t.tag_start then
		print("Error : "..scite.GetTranslation("Move the cursor on a tag to copy it!"))
		return
	end
	local tag = editor:textrange(t.tag_start, t.tag_end+1)
	if t.paired_start then
		local paired = editor:textrange(t.paired_start, t.paired_end+1)
		if t.tag_start < t.paired_start then
			t.begin = tag
			t.finish = paired
		else
			t.begin = paired
			t.finish = tag
		end
	else
		t.begin = tag
		t.finish = nil
	end
end

function PasteTags()
	if t.begin then
		if t.finish then
			local sel_text = editor:GetSelText()
			editor:ReplaceSel(t.begin..sel_text..t.finish)
			if sel_text == '' then
				editor:GotoPos(editor.CurrentPos - #t.finish)
			end
		else
			editor:ReplaceSel(t.begin)
		end
	end
end

function DeleteTags()
	if t.tag_start then
		editor:BeginUndoAction()
		if t.paired_start~=nil then
			if t.tag_start < t.paired_start then
				editor:SetSel(t.paired_start, t.paired_end+1)
				editor:DeleteBack()
				editor:SetSel(t.tag_start, t.tag_end+1)
				editor:DeleteBack()
			else
				editor:SetSel(t.tag_start, t.tag_end+1)
				editor:DeleteBack()
				editor:SetSel(t.paired_start, t.paired_end+1)
				editor:DeleteBack()
			end
		else
			editor:SetSel(t.tag_start, t.tag_end+1)
			editor:DeleteBack()
		end
		editor:EndUndoAction()
	else
		print("Error : "..scite.GetTranslation("Move the cursor on a tag to delete it!"))
	end
end

function GotoPairedTag()
	if t.paired_start then -- the paired tag found
		editor:GotoPos(t.paired_start+1)
	end
end

function SelectWithTags()
	if t.tag_start and t.paired_start then -- the paired tag found
		if t.tag_start < t.paired_start then
			editor:SetSel(t.paired_end+1, t.tag_start)
		else
			editor:SetSel(t.tag_end+1, t.paired_start)
		end
	end
end

function highlighting_paired_tags_switch()
	local prop_name = 'hypertext.highlighting.paired.tags'
	props[prop_name] = 1 - tonumber(props[prop_name])
	EditorClearMarks(blue_indic)
	EditorClearMarks(red_indic)
end

local function FindPairedTag(tag)
	local count = 1
	local find_start, find_end, dec

	if editor.CharAt[t.tag_start+1] ~= 47 then -- [/]
		-- поиск вперед (закрывающего тега)
		find_start = t.tag_start + 1
		find_end = editor.Length
		dec = -1
	else
		-- поиск назад (открывающего тега)
		find_start = t.tag_start
		find_end = 0
		dec = 1
	end
	repeat
		local paired_start, paired_end = editor:findtext("</?"..tag.."[ >]", SCFIND_REGEXP, find_start, find_end)
        if paired_end and editor.CharAt[paired_end - 1] ~= 62 then
            if dec == -1 then
            _, paired_end = editor:findtext(".*?>", SCFIND_REGEXP, paired_end, find_end)
            else
            _, paired_end = editor:findtext(".*?>", SCFIND_REGEXP, paired_end, find_start)
            end
        end
        if not paired_end or not paired_end then return end
        if paired_end and editor.CharAt[paired_end-2] ~= 47 then
            if not paired_start then break end
            if editor.CharAt[paired_start+1] == 47 then -- [/]
                count = count + dec
            else
                count = count - dec
            end
            if count == 0 then
                t.paired_start = paired_start
                t.paired_end = paired_end - 1
                break
            end
		end
		find_start = (dec==1) and paired_start or paired_end
	until false
end

local function PairedTagsFinder()
    if styleSpace == 49 and cmpobj_GetFMDefault() ~= SCE_FM_X_DEFAULT then return end
	local current_pos = editor.CurrentPos
	if current_pos == old_current_pos then return end
	old_current_pos = current_pos
	local tag_start = editor:findtext("[<>]", SCFIND_REGEXP, current_pos, 0)

	if tag_start == nil
		or editor.CharAt[tag_start] ~= 60 -- [<]
		or (editor.StyleAt[tag_start] ~= styleBracket and editor.StyleAt[tag_start] ~= styleBracket )
		then
			t.tag_start = nil
			t.tag_end = nil
			EditorClearMarks(blue_indic)
			EditorClearMarks(red_indic)
			return
	end
	if tag_start == t.tag_start then return end
	t.tag_start = tag_start

	local tag_end = editor:findtext("[<>]", SCFIND_REGEXP, current_pos, editor.Length)
	if tag_end == nil
		or editor.CharAt[tag_end] ~= 62 -- [>]
		or editor.CharAt[tag_end - 1] == 47 -- [/]
		then
            if editor.CharAt[tag_end - 1] then EditorClearMarks(red_indic); EditorClearMarks(blue_indic) end
        return
	end

	t.tag_end = tag_end

	t.paired_start = nil
	t.paired_end = nil
	if editor.CharAt[t.tag_end-1] ~= 47 then -- не ищем парные теги для закрытых тегов, типа <BR >
		local tag = editor:textrange(editor:findtext("[\\w\\.:]+", SCFIND_REGEXP, t.tag_start, t.tag_end))
		FindPairedTag(tag)
	end

	EditorClearMarks(blue_indic)
	EditorClearMarks(red_indic)

	if t.paired_start then
		-- paint in Blue
		EditorMarkText(t.tag_start + 1, t.tag_end - t.tag_start - 1, blue_indic)
		EditorMarkText(t.paired_start + 1, t.paired_end - t.paired_start - 1, blue_indic)
	else
		if props["indic.style."..red_indic] ~= '' then
			-- paint in Red
			EditorMarkText(t.tag_start + 1, t.tag_end - t.tag_start - 1, red_indic)
		end
	end
end

local function CloseTag(nUnbodyScipped)
    local pos = editor.CurrentPos
    if (editor.StyleAt[pos] == styleSpace or editor.StyleAt[pos - 1] == styleSpace) or
       (editor.StyleAt[pos] == styleBracket and editor.CharAt[pos - 1] == 62 and editor.CharAt[pos] == 60)
    then
        local tg_end, find_start = nil,pos
        repeat
            find_start = editor:findtext("<[\\w\\.:]+", SCFIND_REGEXP, find_start, 0)
            if not find_start then break end

            local tag_end = editor:findtext("[<>]", SCFIND_REGEXP, find_start + 1, editor.Length)

            if not(tag_end == nil or editor.CharAt[tag_end] ~= 62) then -- [>]
                t.tag_start = find_start
                t.tag_end = tag_end

                t.paired_start = nil
                t.paired_end = nil
                local tag = editor:textrange(editor:findtext("[\\w\\.:]+", SCFIND_REGEXP, t.tag_start, t.tag_end))
                if not tag then break end
                if editor.CharAt[tag_end - 1] == 47 then -- [/]
                    nUnbodyScipped = nUnbodyScipped - 1
                    if nUnbodyScipped == 0 then
                        editor:BeginUndoAction()
                        editor:ReplaceSel('</'..tag..'>')
                        editor:SetSel(tag_end - 1, tag_end)
                        editor:ReplaceSel('')
                        editor:SetSel(pos - 1, pos - 1)
                        editor:EndUndoAction()
                        break
                    end
                else
                    FindPairedTag(tag)
                    if not t.paired_start then
                        editor:ReplaceSel('</'..tag..'>')
                        return
                    end
                    if t.paired_start > pos then break end
                end
            end
        until false
    end
end

local function OnSwitchFile_local()
    if editor.Lexer == SCLEX_FORMENJINE then
        bEnable, styleSpace, styleBracket = true, 49, 50
    elseif editor.Lexer == SCLEX_XML then
        bEnable, styleSpace, styleBracket = true, 0, 1
    else
        bEnable = false
    end
end

function CloseIncompleteTag()
    CloseTag(0)
end

function CloseUnbodyTag()
    -- iup.GetParam("sdfsd",(function(h, ind) print((iup.GetParamParam(h,0)).value); return 1 end), "Tag%i[1,100,1]{}\n", 1)
    CloseTag(1)
end

AddEventHandler("OnUpdateUI", function()
    if bEnable and (tonumber(_G.iuprops['pariedtag.on']) == 1) then PairedTagsFinder() end
end)
AddEventHandler("OnSwitchFile", OnSwitchFile_local)
AddEventHandler("OnOpen", OnSwitchFile_local)

require "menuhandler"
menuhandler:InsertItem('MainWindowMenu', 'Edit/s1',
    {'Xml Tags',  ru ='Теги Xml', visible_ext='xml,form,rform,cform',{
        {'Close Incomplete Tag', ru='Закрыть незакрытый тэг', action=CloseIncompleteTag, key='Alt+Shift+>',},
        {'Close Unpaired Tag', ru='Закрыть непарный тэг', action=CloseUnbodyTag, key='Alt+Shift+W',},
        {'Tag Highlighting', ru='Подсветка тэгов', check_iuprops='pariedtag.on'},
    }}
)
