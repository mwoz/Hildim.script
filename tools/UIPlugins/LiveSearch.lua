require "seacher"
local findSettings = seacher{
wholeWord = false
,matchCase = false
,wrapFind = true
,backslash = false
,regExp = false
,style = nil
,searchUp = false
,replaceWhat = ''
}

local txt_search
local btn_search
local function sidebar_Find()
    iup.SetFocus(txt_search)
    txt_search.selection = '1:100'
end
local needCoding = false

local function Find_onFocus(setfocus)
    if not setfocus then
        local a = findres:findtext('^</\\', SCFIND_REGEXP, 0)
        if a then
            findres.TargetStart = a
            findres.TargetEnd = a+3
            findres:ReplaceTarget('<')
        end
    end
end

local function OnSwitch()
    needCoding = (scite.SendEditor(SCI_GETCODEPAGE) ~= 0)
end

local function Init(ToolBar_obj)
    local tm = iup.timer{time=300}
    local tmConsole = iup.timer{time=600000}
    tmConsole.action_cb = (function()
        if output.LineCount > 200 then
            output.TargetStart = 0
            output.TargetEnd = output:PositionFromLine(output.LineCount-200)
            output:ReplaceTarget('')
        end
    end)
    tmConsole.run="YES"
    txt_search = iup.text{name='livesearch_bar', expand='YES', tip='"Живой" поиск(Alt+F)\nСтрелки "вверх"/"вниз" - перемещение по списку результаов\nEnter - переход к найденному\nEsc - вернуться'}
    iup.SetAttribute(txt_search, 'HISTTORIZED', "NO")
    local function Find_onTimer()
        tm.run="NO"
        local a = findres:findtext('^</\\', SCFIND_REGEXP, 0)
        if a then
            findres.TargetStart = 0
            findres.TargetEnd = findres.LineEndPosition[findres:LineFromPosition(a)]+1
            findres:ReplaceTarget('')
        end
        local str = txt_search.value
        if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then str = str:to_utf8(1251) end
        findSettings.findWhat = str
        findSettings:FindAll(50,true)
    end
    tm.action_cb = (Find_onTimer)
    local function Find_onChange()
        btn_search.active = Iif(#txt_search.value == 0, 'NO', 'YES')
        tm.run="NO"
        tm.run="YES"
    end

    txt_search.valuechanged_cb = (Find_onChange)
    txt_search.killfocus_cb = (function(h)
        local a = findres:findtext('^</\\', SCFIND_REGEXP, 0)
        if a then
            findres.TargetStart = a
            findres.TargetEnd = a+3
            findres:ReplaceTarget('<')
        end
    end)
    txt_search.k_any = (function(c, key)
        if key == 65364 then  --down
            local line = findres:LineFromPosition(findres.CurrentPos) + 1
            findres:SetSel(findres:PositionFromLine(line), findres.LineEndPosition[line])
        elseif key == 65362 then --up
            local line = findres:LineFromPosition(findres.CurrentPos) - 1
            findres:SetSel(findres:PositionFromLine(line), findres.LineEndPosition[line])

        elseif key == 13 then  --enter
            local _,_, n = string.find(findres:GetSelText(), '^%s*(%d+):')
            if n==nil then n = string.find(findres:GetSelText(), ':(%d+):') end
            if n==nil then
                Find_onChange(c)
                return
            end
            editor:SetSel(editor:PositionFromLine(n-1), editor.LineEndPosition[n-1])
            iup.PassFocus()
        elseif key == 65307 then  --esc
            iup.PassFocus()
        end
    end)
    btn_search = iup.flatbutton{image = 'IMAGE_search',active='NO', padding = '4x4', flat_action=(function() Find_onTimer(txt_search);Find_onFocus(false);iup.PassFocus() end), tip='Повторить поиск по введенному слову'}
    ToolBar_obj.Tabs.livesearch = {
        handle = iup.hbox{
                -- iup.button{image = 'IMAGE_AlignObjectsLeft', action=(function() iup.PassFocus();do_Align() end), tip='Диалог выравнивания кода(Alt+A)'};
                btn_search,
                txt_search,
                expand='HORIZONTAL', minsize='200x'
        };
        tab = tab3;
		OnSave = OnSwitch;
        OnSwitchFile = OnSwitch;
        OnOpen = OnSwitch;
        OnKey = _OnKey;
        }

    menuhandler:InsertItem('MainWindowMenu', 'Search¦s0',   --TODO переместить в SideBar\FindRepl.lua вместе с функциями
    {'Live Search', ru="Живой поиск", key='Alt+F', action=sidebar_Find, image = 'binocular__pencil_µ',})

end

return {
    title = 'Live Search',
    code = 'livesearch',
    toolbar = Init,
    description = [[Поиск текста по мере набора с выводом
найденных строк в результатах поиска]]
}



