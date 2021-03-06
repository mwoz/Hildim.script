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
    if editor.SelectionStart ~= editor.SelectionEnd and editor:LineFromPosition(editor.SelectionStart) == editor:LineFromPosition(editor.SelectionEnd) then
        txt_search.value = editor:GetSelText():to_utf8()
        txt_search.valuechanged_cb()
    end
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

AddEventHandler("OnSwitchFile", function()
    scite.RunAsync(function() txt_search.Selection = "1:1"end)
end)

local function Init(ToolBar_obj)
    local function GetHotKey()
        local strKey = menuhandler:GetHotKey('MainWindowMenu|Search|Live Search')
        if strKey ~= '' then strKey = ' ('..strKey..')' end
        return strKey
    end
    local tm = iup.timer{time = 300}
    local noVal = true

    txt_search = iup.list{name = 'livesearch_bar', expand = 'YES', editbox = "YES", dropdown = "YES",
        bgcolor = props['layout.splittercolor'], bordercolor = props['layout.splittercolor'], fgcolor = props['layout.txtinactivcolor'],
        txtbgcolor = props['layout.splittercolor'], txtfgcolor = props['layout.fgcolor'], visibleitems = '15',
        bgcolorlist = props['layout.txtbgcolor'], fgcolorlist = props['layout.txtfgcolor'], emptylisttext = _T'Live Search',
    }
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
        if tonumber(props["editor.unicode.mode"]) == IDM_ENCODING_DEFAULT then str = str:from_utf8() end
        findSettings.findWhat = str
        CORE.FindMarkAll(findSettings, 50, true, Iif(#str > 1, 10, nil))
    end
    tm.action_cb = (Find_onTimer)
    local function Find_onChange()
        btn_search.active = Iif(#txt_search.value == 0, 'NO', 'YES')
        tm.run="NO"
        tm.run = "YES"
        noVal = false
    end

    txt_search.valuechanged_cb = (Find_onChange)
    txt_search.getfocus_cb = function(h)
        CORE.ClearLiveFindMrk()
        if noVal then
            txt_search.value = ''
            txt_search.fgcolor = props['layout.fgcolor']
        end
    end
    txt_search.killfocus_cb = (function(h)
        local a = findres:findtext('^</\\', SCFIND_REGEXP, 0)
        if a then
            findres.TargetStart = a
            findres.TargetEnd = a+3
            findres:ReplaceTarget('<')
        end

        if txt_search.value == '' then
            txt_search.fgcolor = props['layout.txtinactivcolor']
            txt_search.value = _T'Live Search'..GetHotKey()
            noVal = true
        else
            txt_search:SaveHist()
        end
    end)
    txt_search.k_any = (function(c, key)
        if key == iup.K_PGDN then --down
            CORE.FindResult(1)
            iup.SetFocus(c)
            return iup.IGNORE
        elseif key == iup.K_PGUP then --up
            CORE.FindResult(-1)
            iup.SetFocus(c)
            return iup.IGNORE
        elseif key == iup.K_ESC or key == iup.K_CR then  --esc
            iup.PassFocus()
            CORE.ClearLiveFindMrk()
        end
    end)
    btn_search = iup.flatbutton{image = 'IMAGE_search',active='NO', padding = '4x4', flat_action=(function() Find_onTimer(txt_search);Find_onFocus(false);CORE.ScipHidePannel(2);iup.PassFocus() end), tip=_T'Repeat search by selected word'}

    menuhandler:InsertItem('MainWindowMenu', 'Search|s0',   --TODO ����������� � SideBar\FindRepl.lua ������ � ���������
    {'Live Search', key = 'Alt+F3', action = sidebar_Find, image = 'binocular__pencil_�',}, "hildim/ui/livesearch.html", _T)
    txt_search.value = _T'Live Search'..GetHotKey()
    txt_search.tip = _FMT(_T'"Live" Search%1\nArrow Up/Down - movement through the results list\nEnter - Go to search result\nEsc - exit search', GetHotKey())
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
    description = [[����� ������ �� ���� ������ � �������
��������� ����� � ����������� ������]]
}



