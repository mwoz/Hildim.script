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

--]]----------------------------------------------------
function Init()
    local t = {}
    -- t.tag_start, t.tag_end, t.paired_start, t.paired_end  -- positions
    -- t.begin, t.finish  -- contents of tags (when copying)
    local old_current_pos
    local blue_indic = CORE.InidcFactory('PariedTags.ok', 'Парные теги - найдено', INDIC_BOX, 4834854, 0) -- номера используемых маркеров
    local red_indic = CORE.InidcFactory('PariedTags.Error', 'Парные теги - ошибка', INDIC_STRIKE, 13311, 0)

    local bEnable, styleSpace, styleBracket = false, 0, 1

    function CopyTags()
        if not t.tag_start then
            print("Error : "..scite.GetTranslation("Move the cursor on a tag to copy it!"))
            return
        end
        local tag = editor:textrange(t.tag_start, t.tag_end + 1)
        if t.paired_start then
            local paired = editor:textrange(t.paired_start, t.paired_end + 1)
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
            if t.paired_start~= nil then
                if t.tag_start < t.paired_start then
                    editor:SetSel(t.paired_start, t.paired_end + 1)
                    editor:DeleteBack()
                    editor:SetSel(t.tag_start, t.tag_end + 1)
                    editor:DeleteBack()
                else
                    editor:SetSel(t.tag_start, t.tag_end + 1)
                    editor:DeleteBack()
                    editor:SetSel(t.paired_start, t.paired_end + 1)
                    editor:DeleteBack()
                end
            else
                editor:SetSel(t.tag_start, t.tag_end + 1)
                editor:DeleteBack()
            end
            editor:EndUndoAction()
        else
            print("Error : "..scite.GetTranslation("Move the cursor on a tag to delete it!"))
        end
    end

    function GotoPairedTag()
        if t.paired_start then -- the paired tag found
            editor:GotoPos(t.paired_start + 1)
        end
    end

    function SelectWithTags()
        if t.tag_start and t.paired_start then -- the paired tag found
            if t.tag_start < t.paired_start then
                editor:SetSel(t.paired_end + 1, t.tag_start)
            else
                editor:SetSel(t.tag_end + 1, t.paired_start)
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

        if editor.CharAt[t.tag_start + 1] ~= 47 then -- [/]
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
            if paired_end and editor.CharAt[paired_end - 2] ~= 47 then
                if not paired_start then break end
                if editor.CharAt[paired_start + 1] == 47 then -- [/]
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
            find_start = (dec == 1) and paired_start or paired_end
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
            or editor.CharAt[tag_start + 1] == 63 --[?]
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
        if editor.CharAt[t.tag_end - 1] ~= 47 then -- не ищем парные теги для закрытых тегов, типа <BR >
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
            local tg_end, find_start = nil, pos
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
menuhandler:InsertItem('MainWindowMenu', 'Edit|Xml|l1',
    {'Xml', plane = 1,{
        {'Close Incomplete Node', ru = 'Закрыть незавершенную ноду', action = CloseIncompleteTag, key = 'Ctrl+>', image = 'node_insert_µ',},
        {'Close Unpaired Tag', ru = 'Превратить одиночную ноду в двойную', action = CloseUnbodyTag, key = 'Ctrl+Shift+>', image = 'node_insert_next_µ',},
        {'Tag Highlighting', ru = 'Подсветка тэгов', check_iuprops = 'pariedtag.on'},
}}
)
end

return {
    title = 'Подсветка парных и непарных тегов в HTML и XML',
    hidden = Init,
}
