require "menuhandler"

local function Init(h)

    local tBar = {margin = "5", alignment='ACENTER'}
    local str = _G.iuprops["settings.user.toolbar"] or ''
    local id = 0
    for p in str:gmatch('[^‡]+') do

        if p == '---' then
            table.insert(tBar, iup.label{separator = "VERTICAL",maxsize='x22'})
        else
            local tItem = menuhandler:GetMenuItem(p)
            --debug_prnArgs(tItem)
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
        end
    end

    ToolBar_obj = h
    ToolBar_obj.Tabs.usertb = {
    handle = iup.hbox(tBar)
    }

    --AddEventHandler("OnUpdateUI", function() print(234) end)

end

return {
    title = 'Пользовательская панель',
    code = 'usertb',
    toolbar = Init,
}
