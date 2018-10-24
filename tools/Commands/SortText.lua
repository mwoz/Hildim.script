--[[--------------------------------------------------
SortText.lua
Authors: Tugarinov Sergey, mozers™, Tymur Gubayev
version 2.1.1
------------------------------------------------------
--]]--------------------------------------------------
local function Run()
    local lines_tbl = {} -- Таблица со строками нашего текста

    local ret, pDirect, position, pIgnore = iup.GetParam(_T"Sorting",
        nil,
        _T'Order%o|Direct|Reverse|\n'..
        _T'Starting from Position'..'%i[1,100,1]\n'..
        _T'Ignore%o|Spaces and Quotes|+all Operators|Nothing|\n'
        ,
        0, 1, 0
    )

    if not ret then return end
    local patt = '^'
    if position > 1 then
        patt = patt..string.rep('.', position - 1)
    end
    if pIgnore == 0 then
        patt = patt..[[[%s'"`«]*]]
    elseif pIgnore == 1 then
        patt = patt..'%W*'
    end

    local sort_direction_decreasing = (pDirect == 1)
    -- сравниваем две строки
    local function CompareTwoLines(line1, line2)
        if patt ~= '^' then
            line1 = line1:gsub(patt, '')
            line2 = line2:gsub(patt, '')
        end
        if sort_direction_decreasing then
            return (line1 > line2)
        else
            return (line1 < line2)
        end
    end
    local function CompareTwoLines2(line1, line2)
        line1 = line1:gsub(patt, '')
        line2 = line2:gsub(patt, '')
        if sort_direction_decreasing then
            return (line1:lower() > line2:lower())
        else
            return (line1:lower() < line2:lower())
        end
    end

    local sel_text = editor:GetSelText()
    local sel_start = editor.SelectionStart
    local sel_end = editor.SelectionEnd
    if sel_text ~= '' then
        -- разделяем на строки и загоняем их в таблицу
        for current_line in sel_text:gmatch('[^\n]+') do
            lines_tbl[#lines_tbl + 1] = current_line
        end
        if #lines_tbl > 1 then
            --sort_direction_decreasing = GetSortDirection()
            -- сортируем строки в таблице
            table.sort(lines_tbl, CompareTwoLines)
            -- соединяем все строки из таблицы вместе
            local out_text = table.concat(lines_tbl, '\n')..'\n'
            editor:ReplaceSel(out_text)
        end
    end
    -- восстанавливаем выделение
    editor:SetSel(sel_start, sel_end)
end

return {
    title = _T'Sort Lines A...z/z...A',
    title_utf = true,
    run = Run,
    path = 'Edit|s2',
    description = [[Sorting selected lines_tbl alphabetically and vice versa
Сортировка выделенных строк по алфавиту и наоборот]]
}
