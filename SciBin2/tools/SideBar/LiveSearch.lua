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
        gui.pass_focus()
    elseif key == 27 then
        gui.pass_focus()
    end
end

local function Find_onFocus(setfocus)
    if not setfocus then
        local a = findrez:findtext('^>!!/\\', SCFIND_REGEXP, 0)
        if a then
            findrez.TargetStart = a
            findrez.TargetEnd = a+5
            findrez:ReplaceTarget('>!!  ')
        end
    end
end

local function OnSwitch()
    needCoding = (scite.SendEditor(SCI_GETCODEPAGE) ~= 0)
end

local function FindTab_Init()

    txt_search = iup.text{expand='YES', tip='"Живой" поиск(Alt+S)\nСтрелки "вверх"/"вниз" - перемещение по списку результаов\nEnter - переход к найденному\nEsc - вернуться'}
    local function Find_onChange(c)
        local sText = c.value
        if needCoding then sText = sText:to_utf8(1251) end
        local a = findrez:findtext('^>!!/\\', SCFIND_REGEXP, 0)
        if a then
            findrez.TargetStart = 0
            findrez.TargetEnd = findrez.LineEndPosition[findrez:LineFromPosition(a)]+1
            findrez:ReplaceTarget('')
        end
        if #sText == 0 then
            btn_search.active = 'NO'
            return
        else
            btn_search.active = 'YES'
        end

        local flag0,flag1 = 0,0

        if props['findtext.matchcase'] == '1' then flag1 = SCFIND_MATCHCASE end
        local bookmark = props['findtext.bookmarks'] == '1'
        if props['findtext.wholeword'] == '1' then flag0 = SCFIND_WHOLEWORD end

        if string.len(sText) > 0 then
            scite.MenuCommand(IDM_FINDRESENSUREVISIBLE)
            for line = 0, editor.LineCount do
                local level = scite.SendFindRez(SCI_GETFOLDLEVEL, line)
                if (shell.bit_and(level,SC_FOLDLEVELHEADERFLAG)~=0 and SC_FOLDLEVELBASE == shell.bit_and(level,SC_FOLDLEVELNUMBERMASK))then
                    scite.SendFindRez(SCI_SETFOLDEXPANDED, line)
                    local lineMaxSubord = scite.SendFindRez(SCI_GETLASTCHILD, line,-1)
                    if line < lineMaxSubord then scite.SendFindRez(SCI_HIDELINES, line + 1, lineMaxSubord) end
                end
            end

            scite.SendFindRez(SCI_SETSEL,0,0)

            local count,lCount,line = 0,0,0
            local s,e = 0,-1
            while true do
                s,e = editor:findtext(sText, flag0 + flag1, e + 1)
                if not s then break end
                count = count + 1
                local l = editor:LineFromPosition(s)
                if l~=line then
                    lCount = lCount + 1
                    line = l
                    if lCount == 50 then
                        scite.SendFindRez(SCI_REPLACESEL, '.\\'..props["FileNameExt"]..':'..(l+1)..': ...\n')
                        break;
                    end
                    local str = editor:GetLine(l)
                    if needCoding then str = str:from_utf8(1251) end
                    scite.SendFindRez(SCI_REPLACESEL, '.\\'..props["FileNameExt"]..':'..(l+1)..': '..str )
                end
            end

            scite.SendFindRez(SCI_REPLACESEL, '>!!/\\  Occurrences: '..count..' in '..lCount..' lines\n' )
            scite.SendFindRez(SCI_SETSEL,0,0)
            scite.SendFindRez(SCI_REPLACESEL, '>??Internal search for "'..c.value..'" in "'..props["FileNameExt"]..'" (Current)\n' )
            findrez.CurrentPos = 1
            if scite.SendFindRez(SCI_LINESONSCREEN) == 0 then scite.MenuCommand(IDM_TOGGLEOUTPUT) end
        end
    end


    txt_search.valuechanged_cb = (Find_onChange)
    txt_search.killfocus_cb = (function(h)
        local a = findrez:findtext('^>!!/\\', SCFIND_REGEXP, 0)
        if a then
            findrez.TargetStart = a
            findrez.TargetEnd = a+5
            findrez:ReplaceTarget('>!!  ')
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
    btn_search = iup.button{image = 'IMAGE_search',active='NO', action=(function() Find_onChange(txt_search) end), tip='Повторить поиск по введенному слову'}
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


