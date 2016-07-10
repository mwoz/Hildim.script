--[[--------------------------------------------------
ROCheck.lua
Authors: Midas, VladVRO
Version: 1.1.1
------------------------------------------------------
Скрипт для автоматической установки R/O режима для файлов
с установленными атрибутами RHS
--]]--------------------------------------------------

function Init()
    local function ROCheck()
        -- Получим атрибуты файла
        local FileAttr = props['FileAttr']
        -- Если среди атрибутов ReadOnly/Hidden/System, и НЕ установлен режим R/O
        if string.find(FileAttr, "[RHS]") and not editor.ReadOnly then
            -- то установим режим R/O
            scite.MenuCommand(IDM_READONLY)
        end
    end

    -- Добавляем свой обработчик события OnOpen
    AddEventHandler("OnOpen", ROCheck)
end
return {
    title = 'Автоматическая установки Read-Only режима для файлов',
    hidden = Init,
}
