require "menuhandler"

local function Init(h)

    local tAllConditions = {}

    local function mnuEvenHandler()
        for hBtn, tC in pairs(tAllConditions) do
            bAct = 'YES'
            for i = 1, #tC do
                if not tC[i]() then bAct = 'NO'; break end
            end
            -- iup.SetAttribute(hBtn, b)
            hBtn.active = bAct
        end
    end


    local tBar = {margin = "5", alignment='ACENTER'}
    local tblSet = _G.iuprops["settings.user.toolbar"] or ''

    local id = 0

    for i = 1, #tblSet do
        local p = tblSet[i]
        if p == '---' then
            table.insert(tBar, iup.canvas{ maxsize = 'x18', rastersize = '1x', bgcolor = props['layout.bordercolor'], expand = 'NO', border = 'NO'})
        else
            local tItem, tCond = menuhandler:GetMenuItem(p)
            if tItem then
                local tBtn = {}
                if tItem.image then
                    tBtn.image = tItem.image
                    tBtn.tip = menuhandler:get_title(tItem, false):gsub('\t', '  ')
                    tBtn.padding = '4x4'
                else
                    local strTitle = menuhandler:get_title(tItem, false)
                    tBtn.title = strTitle:gsub('\t.*$', '')
                    tBtn.tip = strTitle:gsub('^.*\t','')
                end
                local hBtn = iup.flatbutton(tBtn)
                hBtn.flat_action = function() menuhandler:GetAction(tItem)(); iup.PassFocus() end
                table.insert(tBar, hBtn)

                if #tCond > 0 then tAllConditions[hBtn] = tCond end
            else
                print('Userbar: Item "'..p..'" not found')
            end
        end
    end

    ToolBar_obj = h

    AddEventHandler("OnUpdateUI"  , mnuEvenHandler)
    AddEventHandler("OnOpen"      , mnuEvenHandler)
    AddEventHandler("OnSwitchFile", mnuEvenHandler)
    AddEventHandler("OnBeforeSave", mnuEvenHandler)

    return {
        handle = iup.hbox(tBar)
    }
end

return {
    title = 'Пользовательская панель',
    code = 'usertb',
    toolbar = Init,
    description = [[Пользовательская (настраиваемая)
панель инструментов]]
}
