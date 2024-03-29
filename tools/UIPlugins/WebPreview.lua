require "luacom"

local web, onSwitchBar

local function init()
    local body_events = {}
        local strEmpty = [[<html><head></head>
<body><h1>Html preview</h1></body>
</html>]]
    local events_obj
    require "seacher"
    if not lpeg then lpeg = require"lpeg" end
    local findSettings = seacher{
    wholeWord = false
    ,matchCase = false
    ,wrapFind = false
    ,backslash = false
    , regExp = true
    ,style = 1
    ,searchUp = false
    ,replaceWhat = ''
    }
    local pt_up = lpeg.P'..\\'^0
    local function repl(a, b)
        local d = props['FileDir']..'\\'
        local nUp = (pt_up:match(b, 1) - 1) / 3
        for i = 1, nUp do
            d = d:gsub('[^\\]+\\$', "")
        end
        return a..'file:///'..d..b:sub(nUp * 3 + 1)..'"'
    end
    local pt_h = lpeg.Cs((lpeg.P' href="' + lpeg.P' src="')) * lpeg.Cs((1 - lpeg.P'"')^1) * lpeg.P'"'
    local pt_tg =  (lpeg.P"<a " * ((1 - lpeg.P'>'))^0 * lpeg.P">") + (lpeg.P"<" *((pt_h / repl + (1 - lpeg.P'>'))^0) * lpeg.P">")
    local pt_all = lpeg.Cs(((1 - lpeg.P"<")^1 + pt_tg)^0)

    local TAG = (1 - lpeg.S'<>' - (lpeg.P"name" + "id"))^0
    local SPS = lpeg.S'\n \t\r\f'^0
    local ANC = lpeg.P'<' * lpeg.S('aA') * TAG * (lpeg.P"name" + "id") * SPS * "=" * SPS * '"' * (lpeg.C((1 - lpeg.P'"')^1))
    local tmPl = lpeg.Ct(lpeg.P{ANC + 1 * lpeg.V(1)}^1)
    local function GetAnchors(strTxt)
        return tmPl:match(strTxt, 1)
    end

    local function CreateLuaCOM(ih)
        -- if luacom is loaded, use it to access methods and properties
        -- of the control
        if luacom then
            local punk = ih.iunknown
            if punk then
                ih.com = luacom.CreateLuaCOM(luacom.ImportIUnknown(punk))
            end
        end
    end

	local pBody
    local function doCopy()
        local text = web.com.document:getSelection():toString():to_utf8()

        if text ~= '' then
            local clipboard = iup.clipboard{}
            clipboard.text = text
        end
    end

    function body_events:oncontextmenu(e)
            local mnu = iup.menu
            {
              iup.item{title = _TM"Help", action = function() CORE.HelpUI("htmlpreview", nil) end},
              iup.item{title = _TM"Copy", action = doCopy},
              iup.item{title = _TM"Search", action = function() CORE.ActivateFindDialog(web.com.document:getSelection():toString()) end}
            }
            mnu:popup(iup.MOUSEPOS, iup.MOUSEPOS)
        return true
    end

    function body_events:onkeypress()
        local e = web.com.document.parentWindow.event
        if e.keyCode == 3 and not e.altKey and e.ctrlKey and not e.shiftKey then doCopy() end
    end
    function body_events:onclick()
        CORE.HidePannels()
    end
    function body_events:ondblclick()
        OnNavigation("Html")
        if editor.LexerLanguage ~= "hypertext" then return end

        local e = web.com.document.parentWindow.event
        local el = e.srcElement

        local tblPath = {}
        table.insert(tblPath, el)
        local findTag = el.tagName
        local el1
        local counter = 0
        local function counterTag(e)
            if not e then return end
            local ec = e.firstChild
            while ec do
                if ec.tagName == findTag then counter = counter + 1 end
                if ec.nodeType == 1 then counterTag(ec) end
                ec = ec.NextSibling
            end
        end
        while el and el.tagName ~= 'BODY' do
            el1 = el.previousSibling
            if el1 then
                el = el1
                if el.nodeType == 1 then  counterTag(el) end
            else
                el = el.parentNode
            end
            if el and findTag == el.tagName then counter = counter + 1 end
            if el.nodeType == 1  and el.tagName ~= 'BODY' then  end
        end
        findSettings.findWhat = '<'..findTag..'[> ]'
        local lenFind = #findTag + 2
        local endPosition = editor.Length
        local startPosition = 0
        for i = 0, counter do
            startPosition = editor:findtext(findSettings.findWhat, SCFIND_REGEXP, startPosition + 1, endPosition)
            startPosition = editor:findtext('>', 0, startPosition + 1, endPosition) + 1
        end
        endPosition = editor:findtext('</', SCFIND_REGEXP, startPosition + 1, endPosition)
        editor:SetSel(startPosition, startPosition)
        editor:SetSel(startPosition, endPosition)
        OnNavigation("Html-")
        web.com.document:ExecCommand("Unselect", false, nil);
        iup.PassFocus()
        return true
    end
 local bRefresh
    OnUpdateUI_local = function(bModified, bSelection, flag)
        --if flag == 14 then return end

        if editor.LexerLanguage ~= "hypertext" or (bModified == 0 and bSelection == 0) then return end
        local startBodyOpen = editor:findtext('<body[ /]', SCFIND_REGEXP, 0 , editor.Length)
        if not startBodyOpen then bRefresh = true; return end
        local startBodyClose = editor:findtext('>', 0, startBodyOpen, editor.Length)
        if not startBodyClose then bRefresh = true; return end
        local endBodyOpen = editor:findtext('</body>', 0, startBodyClose, editor.Length)
        if not endBodyOpen then bRefresh = true; return end
        local cp = editor.SelectionStart
        if cp < startBodyClose or cp > endBodyOpen then bRefresh = true; return end

        local str = (editor:textrange(startBodyClose + 1, editor.SelectionStart) or '')..Iif(editor:ustyle(editor.SelectionStart) == 0 or (editor:ustyle(editor.SelectionStart) == 1 and editor.CharAt[editor.SelectionStart] == 60), '<span style="background-color:black" id="cursor___">|</span>', '')..editor:textrange(editor.SelectionStart, endBodyOpen)
        if bRefresh then
            web.html = pt_all:match(editor:textrange(0, startBodyClose + 1)..editor:textrange(endBodyOpen, editor.Length), 1)
            web.new = 'Y'
            web.editable = 'NO'
            web.com.document:write(editor:GetText():to_utf8())
            docum = web.com.document
            pBody = web.com.document.body
            events_obj = luacom.Connect(pBody, body_events)
            bRefresh = nil
        end
        pBody.innerHtml = pt_all:match(string.to_utf8(str, 1251), 1)

        local cur = web.com.document:getElementById('cursor___')
        if not cur then return end
        cur:scrollIntoView(false)
        if cur:getClientRects():item(0).top > 120 then pBody.scrollTop = pBody.scrollTop + 100 end
        local w = web.rastersize:gsub('x.*', '')
        if tonumber(w) - 100 > cur:getClientRects():item(0).left then pBody.scrollLeft = pBody.scrollLeft - 50 end
    end

    local function onSwitchLocal()
        if onSwitchBar then onSwitchBar() end
        if editor.LexerLanguage ~= "hypertext" then
            web.new = 'Y'
            web.editable = 'NO'
            web.com.document:write(strEmpty)
            luacom.Connect(web.com.document, body_events)
            pBody = nil
        else
            --web.html = editor:GetText()
            web.com.document:write(editor:GetText():to_utf8())
            pBody = web.com.document.body
            events_obj = luacom.Connect(pBody, body_events)
        end
    end



    web = iup.webbrowser{help_cb = function()  end}

    CreateLuaCOM(web)

    web.new = 'Y'
    web.editable = 'NO'

    iup.SetAttribute(web, "TOPMARGIN", 50)
    iup.SetAttribute(web, "INVOKEFLAG", 400)

    function web:navigate_cb(url)
        if url:find('^about:') then
            url = url:gsub('^about:', props['FileDir']..'\\')
            local fName, strAnc
            if url:find('#') then
                _, _, fName, strAnc = url:find('(.-)#([^#]*)')
            else
                fName = url
                strAnc = ''
            end
            while fName:find('[^\\]+\\%.%.%.\\') do
                fName = fName:gsub('[^\\]+\\%.%.%.\\', '')
            end

            scite.Open(fName)
            if strAnc ~= '' then
                local s = editor:findtext('<a[^<>]+name="'..strAnc..'"', SCFIND_REGEXP, 0, editor.Length)
                if s then editor:SetSel(s, s + 5) end
            end
            iup.PassFocus()
        end
        return iup.IGNORE
    end

    AddEventHandler("OnUpdateUI", OnUpdateUI_local)
    AddEventHandler("OnSwitchFile", onSwitchLocal)
    AddEventHandler("OnOpen", onSwitchLocal)

    local function bHt() return editor.LexerLanguage == "hypertext" end

    local function tagAround(st)
        local isEmpty = editor.SelectionEmpty
        local vs = editor.SelectionNCaretVirtualSpace[0]
        local sPos = editor.SelectionStart
        editor:ReplaceSel(string.rep(' ', vs)..'<'..st..'>'..editor:GetSelText()..'</'..st..'>')
        if not isEmpty then return end
        local s = sPos + vs + #st + 2
        editor:SetSel(s, s)
    end
    local function setItalics() tagAround"i" end
    local function setBold() tagAround"b" end
    local function setStrike() tagAround"s" end
    local function setUnderlined() tagAround"u" end
    local function setPar() tagAround"p" end
    --local function setSpan() local s = editor.SelectionStart + 5; tagAround"span"; editor:SetSel(s, s) end
    local function setSpan() tagAround"span"; end
    local function newLine()
        local cur = web.com.document:getElementById('cursor___')
        if not cur then return end
        local parent = cur.parentNode
        local tn = parent.tagName
        if tn == 'P' or tn == 'DIV' or tn == 'LI' then
            local curS = editor.SelectionStart
            editor:SearchAnchor()
            local tB = editor:SearchPrev(SCFIND_REGEXP, '<'..tn..'[ >]')
            local curInd = editor.SelectionStart - editor:PositionFromLine(editor:LineFromPosition(editor.SelectionStart))
            editor:SearchAnchor()
            local tE = editor:SearchNext(0, '>')
            local str = '</'..tn:lower()..'>'..CORE.EOL()..editor:textrange(tB, tE + 1)
            editor:SetSel(curS, curS)
            editor:ReplaceSel(str)
            curS = curS + #str
            editor:SetSel(curS, curS)
            editor.LineIndentation[editor:LineFromPosition(editor.SelectionStart)] = curInd
        else
            editor:ReplaceSel('<br>')
        end
    end


    menuhandler:InsertItem('MainWindowMenu', 'Edit|s1',
        {'Html', visible = bHt ,{
            {'Italics', action = setItalics, key = 'Alt+I', active = bHt, },
            {'Bold', action = setBold, key = 'Alt+B', active = bHt, },
            {'Strike', action = setStrike, key = 'Alt+S', active = bHt, },
            {'Underlined', action = setUnderlined, key = 'Alt+U', active = bHt, },
            {'Span', action = setSpan, key = 'Alt+N', active = bHt, },
            {'Paragraph', action = setPar, key = 'Alt+P', active = bHt, },
            {'H1', action = function() tagAround"h1" end, key = 'Alt+1', active = bHt, },
            {'H2', action = function() tagAround"h2" end, key = 'Alt+2', active = bHt, },
            {'H3', action = function() tagAround"h3" end, key = 'Alt+3', active = bHt, },
            {'H4', action = function() tagAround"h4" end, key = 'Alt+4', active = bHt, },
            {'H5', action = function() tagAround"h5" end, key = 'Alt+5', active = bHt, },
            {'H6', action = function() tagAround"h6" end, key = 'Alt+6', active = bHt, },
            {'Reference', action = function() tagAround"a" end, key = 'Alt+Shift+A', active = bHt, },
            {'Anchor', action = function() editor:ReplaceSel'<a id=""/>'; for i = 1, 3 do editor:CharLeft() end end, key = 'Ctrl+Shift+A', active = bHt, },
            {'New Paragraph', action = newLine, key = 'Alt+Enter', active = bHt, },
            {'Line Break', action = function() editor:ReplaceSel('<br>') end, key = 'Alt+Ctrl+Enter', active = bHt, },
        }} , "hildim/ui/htmlpreview.html", _T
    )
    menuhandler:PostponeInsert('MainWindowMenu', '_HIDDEN_|Fileman_sidebar|sxxx',   --TODO ����������� � SideBar\FindRepl.lua ������ � ���������
        {'Web', plane = 1, visible = bHt ,{
            {'s_web', separator = 1},
            {"Insert as Link", action = function()
                local anc = ''
                local strSel = editor:GetSelText()
                local strPath = FILEMAN.FullPath()
                local _,_, strExt = strPath:find('([^%.]*)$')
                strExt = strExt:lower()
                if strExt == 'htm' or strExt == 'html' then
                    local f = io.open(strPath)
                    local tblAnc = GetAnchors(f:read('*a'))
                    f:close()
                    if tblAnc then
                        local bok, res = iup.GetParam('Ahchors',
                            nil,
                            "Ahchors: %l|"..table.concat(tblAnc, '|').."|\n", 0
                        )
                        if bok then anc = '#'..tblAnc[res + 1] end
                    end
                end
                local vs = editor.SelectionNCaretVirtualSpace[0]
                local strTg1 = string.rep(' ', vs)..'<a href="'..FILEMAN.RelativePath()..anc..'">'
                local nPos = editor.SelectionStart + #strTg1

                editor:ReplaceSel(strTg1..strSel..'</a>');
                if strSel == "" then editor:SetSel(nPos, nPos) end

                iup.PassFocus()
            end},
            {"Insert as Image", action = function()
            editor:ReplaceSel('<img src="'..FILEMAN.RelativePath()..'"/>')
                iup.PassFocus()
            end},
    }}, "hildim/ui/htmlpreview.html", _T)
    local TAG = (1 - lpeg.S'<>' - lpeg.P"name")^0
    local SPS = lpeg.S'\n \t\r\f'^0
    local ANC = lpeg.P'<' * lpeg.S('aA') * TAG * "name" * SPS * "=" * SPS * '"' * (lpeg.C((1 - lpeg.P'"')^1) / '#%0')
    local tmPl = lpeg.Ct(lpeg.P{ANC + 1 * lpeg.V(1)}^1)
    local function href()
        local tClr = tmPl:match(editor:GetText(), 1)
        if not tClr then return '' end
        return table.concat(tClr, '|')
    end
    WEBPREVIEW = {}
    function WEBPREVIEW.Ref(flag)
        return function()
            local d = iup.filedlg{dialogtype = 'OPEN', parentdialog = 'SCITE',
                extfilter = Iif(flag == 'H', 'All|*.*;', 'Images|*.bmp;*.gif;*.jpg;*.jpeg;*.png;'),
                directory = props["FileDir"]
            }
            d:popup()
            local filename = d.value or ''
            d:destroy()
            local rel = ""
            local res = ""
            if filename ~= '' then
                local _, _, path, name, ext = filename:find('^(.+)([^\\%.]+%.)([^%.]*)$')
                rel = CORE.RelativePath(path)..name..ext
                ext = ext:lower()
                if ext == 'htm' or ext == 'html' then
                    local f = io.open(filename)
                    local tblAnc = GetAnchors(f:read('*a'))
                    f:close()
                    res = ''
                    if tblAnc then res = rel..'#'..table.concat(tblAnc, '|'..rel..'#') end
                end
                if res ~= '' then res = '|'..res end
                res = rel..res
            else
                local tblAnc = GetAnchors(editor:GetText())
                if tblAnc then res = table.concat(tblAnc, '|#') end
                if res ~= '' then res = '#'..res end
            end
            iup.PassFocus()
            return res
        end
    end
end

local function Sidebar_Init(h)

    init()
    return {
        handle = web;
    }
end

local function Toolbar_Init(h)
    init()
    onSwitchBar = function()
        iup.GetParent(web).ShowPlugin(editor_LexerLanguage() == 'hypertext')
    end
    return {
        handle = web
    }
end

return {
    title = 'Html Preview',
    code = 'htmlpreview',
    sidebar = Sidebar_Init,
    toolbar = Toolbar_Init,
    tabhotkey = "Alt+Shift+H",
    overeditors = true,
    destroy = function() WEBPREVIEW = nil end,
    description = [[������������ HTML ���� �� ���� ������
�������������� ����������� �� ������ � HTML]]

}
