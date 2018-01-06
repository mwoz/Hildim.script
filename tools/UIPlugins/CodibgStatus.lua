
local function Init(h)
    local lblCode
    local function UpdateStatusCodePage(mode)
        if mode == nil then mode = props["editor.unicode.mode"] end
        mode = tonumber(mode)
        if mode == IDM_ENCODING_UCS2BE then
            return 'UTF-16 BE'
        elseif mode == IDM_ENCODING_UCS2LE then
            return 'UTF-16 LE'
        elseif mode == IDM_ENCODING_UTF8 then
            return 'UTF-8 BOM'
        elseif mode == IDM_ENCODING_UCOOKIE then
            return 'UTF-8'
        else
            local cp = scite.buffers.EncodingAt(scite.buffers.GetCurrent())
            if cp == 0 or cp == math.tointeger(props['system.code.page']) then
                if props["character.set"] == '255' then
                    return 'DOS-866'
                elseif props["character.set"] == '204' then
                    return 'WIN-1251'
                elseif tonumber(props["character.set"]) == 0 then
                    return 'CP1252'
                elseif props["character.set"] == '238' then
                    return 'CP1250'
                elseif props["character.set"] == '161' then
                    return 'CP1253'
                elseif props["character.set"] == '162' then
                    return 'CP1254'
                else
                    return '???'
                end
            else
                if     cp == 28595 then return 'ISO-8859-5'
                elseif cp == 20866 then return 'KOI8_R'
                elseif cp == 21866 then return 'KOI8_U'
                elseif cp == 10007 then return 'Macintosh'
                elseif cp == 855   then return 'OEM855'
                elseif cp == 856   then return 'OEM856'
                else
                end
            end
        end
    end
    local function OnSwitch()
        lblCode.title = UpdateStatusCodePage()
    end

    AddEventHandler("OnSwitchFile", OnSwitch)
    AddEventHandler("OnOpen", OnSwitch)

    AddEventHandler("OnMenuCommand", function(cmd)
        if cmd >= 150 and cmd <= 154 then
            lblCode.title = UpdateStatusCodePage(cmd)
        end
    end)

    lblCode = iup.label{size = '50x'}

    return {
        handle = lblCode
    }
end

return {
    title = 'Вывод информации о кодировке файла в строке статуса',
    code = 'filecoding',
    statusbar = Init,
}
