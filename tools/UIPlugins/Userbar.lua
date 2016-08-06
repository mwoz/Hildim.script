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
    local str = _G.iuprops["settings.user.toolbar"] or ''
    local id = 0
    for p in str:gmatch('[^З]+') do

        if p == '---' then
            table.insert(tBar, iup.label{separator = "VERTICAL",maxsize='x22'})
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
                hBtn.flat_action = menuhandler:GetAction(tItem)
                table.insert(tBar, hBtn)

                if #tCond > 0 then tAllConditions[hBtn] = tCond end
            end
        end
    end

    ToolBar_obj = h
    ToolBar_obj.Tabs.usertb = {
    handle = iup.hbox(tBar)
    }

    AddEventHandler("OnUpdateUI"  , mnuEvenHandler)
    AddEventHandler("OnOpen"      , mnuEvenHandler)
    AddEventHandler("OnSwitchFile", mnuEvenHandler)
    AddEventHandler("OnBeforeSave", mnuEvenHandler)
end

return {
    title = 'ѕользовательска€ панель',
    code = 'usertb',
    toolbar = Init,
    description = [[ѕользовательска€ (настраиваема€)
панель инструментов]]
}
