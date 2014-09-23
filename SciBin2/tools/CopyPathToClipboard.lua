function CopyPathToClipboard(what)
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
