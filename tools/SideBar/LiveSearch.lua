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
function sidebar_Find()
    iup.SetFocus(txt_search)
    txt_search.selection = '1:100'
end
local needCoding = false
local function Find_onKey(key)
    if key == 40 then  --down
        local line = findrez:LineFromPosition(findrez.CurrentPos) + 1
        findrez:SetSel(findrez:PositionFromLine(line), findrez.LineEndPosition[line])
    elseif key == 38 then
        local line = findrez:LineFromPosition(findrez.CurrentPos) - 1
        findrez:SetSel(findrez:PositionFromLine(line), findrez.LineEndPosition[line])

    elseif key == 13 then  --enter
        local _,_, n = string.find(findrez:GetSelText(), ':(%d+):')
        if n==nil then
            Find_onChange()
            return
        end
        editor:SetSel(editor:PositionFromLine(n-1), editor.LineEndPosition[n-1])
        iup.PassFocus()
    elseif key == 27 then
        iup.PassFocus()
    end
end

local function Find_onFocus(setfocus)
    if not setfocus then
        local a = findrez:findtext('^</\\', SCFIND_REGEXP, 0)
        if a then
            findrez.TargetStart = a
            findrez.TargetEnd = a+3
            findrez:ReplaceTarget('<')
        end
    end
end

local function OnSwitch()
    needCoding = (scite.SendEditor(SCI_GETCODEPAGE) ~= 0)
end

local function FindTab_Init()

    txt_search = iup.text{expand='YES', tip='"Живой" поиск(Alt+F)\nСтрелки "вверх"/"вниз" - перемещение по списку результаов\nEnter - переход к найденному\nEsc - вернуться'}
    local function Find_onChange(c)
        btn_search.active = Iif(#c.value == 0, 'NO', 'YES')
        local a = findrez:findtext('^</\\', SCFIND_REGEXP, 0)
        if a then
            findrez.TargetStart = 0
            findrez.TargetEnd = findrez.LineEndPosition[findrez:LineFromPosition(a)]+1
            findrez:ReplaceTarget('')
        end
        findSettings.findWhat = c.value
        findSettings:FindAll(50,true)
    end


    txt_search.valuechanged_cb = (Find_onChange)
    txt_search.killfocus_cb = (function(h)
        local a = findrez:findtext('^</\\', SCFIND_REGEXP, 0)
        if a then
            findrez.TargetStart = a
            findrez.TargetEnd = a+3
            findrez:ReplaceTarget('<')
        end
    end)
    txt_search.k_any = (function(c, key)
        if key == 65364 then  --down
            local line = findrez:LineFromPosition(findrez.CurrentPos) + 1
            findrez:SetSel(findrez:PositionFromLine(line), findrez.LineEndPosition[line])
        elseif key == 65362 then --up
            local line = findrez:LineFromPosition(findrez.CurrentPos) - 1
            findrez:SetSel(findrez:PositionFromLine(line), findrez.LineEndPosition[line])

        elseif key == 13 then  --enter
            local _,_, n = string.find(findrez:GetSelText(), ':(%d+):')
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
    btn_search = iup.button{image = 'IMAGE_search',active='NO', action=(function() Find_onChange(txt_search);Find_onFocus(false);iup.PassFocus() end), tip='Повторить поиск по введенному слову'}
    TabBar_obj.Tabs.livesearch = {
        handle = iup.hbox{
                iup.button{image = 'IMAGE_AlignObjectsLeft', action=(function() iup.PassFocus();do_Align() end), tip='Диалог выравнивания кода(Alt+A)'};
                btn_search,
                txt_search,
                expand='HORIZONTAL', minsize='200x'
        };
        tab = tab3;
		OnSave = OnSwitch;
        OnSwitchFile = OnSwitch;
        OnOpen = OnSwitch;
        OnKey = _OnKey;
		tabs_OnSelect = OnSwitch;
        on_SelectMe = function() cmb_listCalc:set_focus() end
        }

end

FindTab_Init()


