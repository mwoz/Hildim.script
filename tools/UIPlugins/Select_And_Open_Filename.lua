--[[----------------------------------------------------------------------------
Select_And_Open_Filename.lua
Author: VladVRO
version 1.4.4

���������� ������� "������� ���������� ����" ��� ������ ����� ��������� ���.
� ����� ����������� ������� ���� �� �������� ����� ���� �� ��� ����� ��� �������
������� Ctrl.
������ �������� ���������� ������� ����� � �������� � �������� ����� ��������
����� � �������� ������� ��� � ������� �����, ���� ���� �� ������, �� ������
�������� ��������� ��������� �� ����� + ���� � ��������� ������� �������, �
������ ������� ������� ��������� ��������� ������������ �� ��� ���, ���� ��
����� ������� ���� ���� �� �����, � ���� ���� ��� ��� �� ������, �� �����
������������ � ����� �� ������� ���� � �.�. �� �����.

�������� select.and.open.include - ���������� ������ �������������� ����� ���
������, ����� ������������� ����� ������ ;

!!!TODO!!! ������� ������ ��������
--]]----------------------------------------------------------------------------
require 'shell'
local function init()
    local function isFilenameChar(ch)
        if
            ch < 0 or
            ( ch > 32
                and ch ~= 34  -- "
                and ch ~= 39  -- '
                and ch ~= 42  -- *
                and ch ~= 47  -- /
                and ch ~= 58  -- :
                and ch ~= 60  -- <
                and ch ~= 62  -- >
                and ch ~= 63  -- ?
                and ch ~= 92  -- \
                and ch ~= 124 -- |
            )
            then
            return true
        end
        return false
    end

    local includes = {}
    local function loadIncludes(str)
        while #includes > 0 do
            table.remove(includes)
        end
        for path in str:gmatch('([^;]*);') do
            local ch = path:sub(path:len())
            if ch ~= '\\' or ch ~= '/' then
                path = path..'\\'
            end
            table.insert(includes, path)
        end
    end

    local for_open
    local function launch_open()
        if for_open then
            scite.Open(shell.to_utf8(for_open))
            for_open = nil
        end
    end

    local function Select_And_Open_File(immediately)
        local sci
        if findres.Focus then
            sci = findres
        elseif output.Focus then
            sci = output
        else
            sci = editor
        end
        local filename = sci:GetSelText()
        local isFile, foropen

        if filename ~= '' then
            local pattern_full = '^[A-Za-z]:'
            foropen = filename
            if not string.find(filename, pattern_full) then
                foropen = props['FileDir']..'\\'..filename
            end
            isFile = shell.fileexists(foropen)
        else
            loadIncludes(props['select.and.open.include'])

            -- try to select file name near current position
            local cursor = sci.CurrentPos
            local s = cursor
            local e = s
            while isFilenameChar(sci.CharAt[s - 1]) do -- find start
                s = s - 1
            end
            while isFilenameChar(sci.CharAt[e]) do -- find end
                e = e + 1
            end

            if s ~= e then
                -- set selection and try to find file
                sci:SetSel(s, e)
                local dir = props["FileDir"].."\\"
                filename = string.gsub(sci:GetSelText(), '\\\\', '\\')
                foropen = dir..filename
                isFile = shell.fileexists(foropen)

                -- look at includes
                if not isFile then
                    for _, path in ipairs(includes) do
                        foropen = path..filename
                        isFile = shell.fileexists(foropen)
                        if isFile then
                            break
                        end
                    end
                end

                while not isFile do
                    ch = sci.CharAt[s - 1]
                    if ch == 92 or ch == 47 then -- \ /
                        -- expand selection start
                        s = s - 1
                        while isFilenameChar(sci.CharAt[s - 1]) do
                            s = s - 1
                        end
                        sci:SetSel(s, e)
                        filename = string.gsub(sci:GetSelText(), '\\\\', '\\')
                        foropen = dir..filename
                    elseif string.len(dir) > 3 then
                        -- up to parent dir
                        dir = string.gsub(dir, "(.*)\\([^\\]+)\\", "%1\\")
                        foropen = dir..filename
                    else
                        break
                    end
                    isFile = shell.fileexists(foropen)
                end
            end
        end
        if isFile then
            for_open = foropen
            if immediately then
                launch_open()
            end
            return true
        end
    end

    AddEventHandler("OnMouseButtonUp", launch_open)

    AddEventHandler("OnDoubleClick", function(shift, ctrl, alt)
        if ctrl --[[and props["select.and.open.by.click"] == "1"]] then
            local sci
            if editor.Focus then
                sci = editor
            else
                sci = output
            end
            local s = sci.CurrentPos
            sci:SetSel(s, s)
            return Select_And_Open_File(false)
        end
    end)
    menuhandler:InsertItem('MainWindowMenu', 'File|Reopen File',
    {'Select And Open Filename', ru = _T'Select And Open Filename', action = function() Select_And_Open_File(true) end, key = 'Ctrl+Shift+O',})

end

return {
    title = _T'Select And Open Filename',
    hidden = init,
    description = [[���������� ������� "������� ���������� ����" ��� ������ ����� ��������� ���.]]
}
