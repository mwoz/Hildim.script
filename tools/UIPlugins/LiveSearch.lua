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
    needCoding = (editor.CodePage ~= 0)
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
    iup.SetAttribute(txt_search, 'HISTORIZED', "NO")
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
        if key == iup.K_DOWN then --down
            CORE.FindResult(1)
            iup.SetFocus(c)
            return iup.IGNORE
        elseif key == iup.K_UP then --up
            CORE.FindResult(-1)
            iup.SetFocus(c)
            return iup.IGNORE
        elseif key == iup.K_ESC or key == iup.K_CR then  --esc
            iup.PassFocus()
        end
    end)
    btn_search = iup.flatbutton{image = 'IMAGE_search',active='NO', padding = '4x4', flat_action=(function() Find_onTimer(txt_search);Find_onFocus(false);iup.PassFocus() end), tip='Повторить поиск по введенному слову'}

    menuhandler:InsertItem('MainWindowMenu', 'Search¦s0',   --TODO переместить в SideBar\FindRepl.lua вместе с функциями
    {'Live Search', ru="Живой поиск", key='Alt+F', action=sidebar_Find, image = 'binocular__pencil_µ',})

    return {
        handle = iup.hbox{
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
end

return {
    title = 'Live Search',
    code = 'livesearch',
    toolbar = Init,
    statusbar = Init,
    description = [[Поиск текста по мере набора с выводом
найденных строк в результатах поиска]]
}



