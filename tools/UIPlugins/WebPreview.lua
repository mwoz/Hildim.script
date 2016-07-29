require "luacom"

local web

local function init()
    local body_events = {}
        local strEmpty = [[<html><head></head>
<body><h1>Html preview</h1></body>
</html>]]
    local events_obj
    require "seacher"
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
    function body_events:oncontextmenu(e)
        print(web.com.event)
        return true
    end

    function body_events:ondblclick()
        if editor.LexerLanguage ~= "hypertext" then return end
        local _, _, xC, yC = iup.GetGlobal('CURSORPOS'):find('(%d+)x(%d+)')
        local _, _, xP, yP = web.screenposition:find('(%d+),(%d+)')
        local z = 100.0 / tonumber(web.zoom)
        local el = web.com.document:elementFromPoint((tonumber(xC) - tonumber(xP)) * z, (tonumber(yC) - tonumber(yP)) * z)
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
        end
        endPosition = editor:findtext('</', SCFIND_REGEXP, startPosition + 1, endPosition) + 2
        editor:SetSel(startPosition, startPosition)
        editor:SetSel(startPosition, endPosition)
        web.com.document:ExecCommand("Unselect", false, nil);
        iup.PassFocus()
        return true
    end

    local function OnUpdateUI_local(bModified, bSelection, flag)
        if editor.LexerLanguage ~= "hypertext" or (bModified == 0 and bSelection == 0) then return end
        local startBodyOpen = editor:findtext('<body[ /]', SCFIND_REGEXP, 0 , editor.Length)
        if not startBodyOpen then pBody = nil; return end
        local startBodyClose = editor:findtext('>', 0, startBodyOpen, editor.Length)
        if not startBodyClose then pBody = nil; return end
        local endBodyOpen = editor:findtext('</body>', 0, startBodyClose, editor.Length)
        if not endBodyOpen then pBody = nil; return end
        local cp = editor.SelectionStart
        if cp < startBodyClose or cp > endBodyOpen then pBody = nil; return end

        local str = editor:textrange(startBodyClose + 1, editor.SelectionStart)..Iif(editor.StyleAt[editor.SelectionStart] == 0, '<span style="background-color:black" id="cursor___">|</span>', '')..editor:textrange(editor.SelectionStart, endBodyOpen)
        if not pBody then
            web.html = editor:textrange(0, startBodyClose + 1)..editor:textrange(endBodyOpen, editor.Length)
            pBody = web.com.document.body
            events_obj = luacom.Connect(web.com.document, body_events)
            iup.PassFocus()
        end
        pBody.innerHtml = string.to_utf8(str, 1251)

        local cur = web.com.document:getElementById('cursor___')
        if not cur then return end
        cur:scrollIntoView(true)
        pBody.scrollTop = pBody.scrollTop - 50
    end

    local function onSwitchLocal()
        pBody = nil
        if editor.LexerLanguage ~= "hypertext" then
            web.html = strEmpty
        else
            web.html = editor:GetText()
            pBody = web.com.document.body
            events_obj = luacom.Connect(pBody, body_events)
            -- events_obj = luacom.Connect(web.com.document, body_events)

--[[        elseif scite.buffers.SavedAt(scite.buffers.GetCurrent()) then
            web.value = props['FilePath']
            pBody = web.com.document.body]]
        end
    end

    local function onOpenLocal()
        pBody = nil
        if editor.LexerLanguage ~= "hypertext" then
            web.html = strEmpty
        end
    end


    web = iup.webbrowser{}

    CreateLuaCOM(web)
    iup.SetAttribute(web, "TOPMARGIN", 50)
    --iup.SetAttribute(web, "INVOKEFLAG", 268435456)
    iup.SetAttribute(web, "INVOKEFLAG", 400)

    AddEventHandler("OnUpdateUI", OnUpdateUI_local)
    AddEventHandler("OnSwitchFile", onSwitchLocal)
    AddEventHandler("OnOpen", onSwitchLocal)

    local function bHt() return editor.LexerLanguage == "hypertext" end

    local function tagAround(st)
        editor:ReplaceSel('<'..st..'>'..editor:GetSelText()..'</'..st..'>')
    end
    local function setItalics() tagAround"i" end
    local function setBold() tagAround"b" end
    local function setStrike() tagAround"s" end
    local function setUnderlined() tagAround"u" end
    local function setSpan() local s = editor.SelectionStart + 5; tagAround"span"; editor:SetSel(s, s) end
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


    menuhandler:InsertItem('MainWindowMenu', 'Edit¦s1',
        {'Html', ru = 'Html', visible = bHt ,{
            {'Italics', ru = 'Курсив', action = setItalics, key = 'Alt+I', active = bHt, },
            {'Bold', ru = 'Жирный', action = setBold, key = 'Alt+B', active = bHt, },
            {'Strike', ru = 'Зачеркнутый', action = setStrike, key = 'Alt+S', active = bHt, },
            {'Underlined', ru = 'Подчеркнутый', action = setUnderlined, key = 'Alt+U', active = bHt, },
            {'Span', ru = 'Интервал', action = setSpan, key = 'Alt+P', active = bHt, },
            {'New Line', ru = 'Новая строка', action = newLine, key = 'Alt+Enter', active = bHt, },
        }}
    )

    menuhandler:PostponeInsert('MainWindowMenu', '_HIDDEN_¦Fileman_sidebar¦sxxx',   --TODO переместить в SideBar\FindRepl.lua вместе с функциями
        {'Web', plane = 1,{
            {'s_web', separator = 1},
            {"Link", ru = "Вставить как ссылку", action = function()
                local strSel = editor:GetSelText()
                editor:ReplaceSel('<a href="'..FILEMAN.RelativePath()..'">'..strSel..'</a>');
                iup.PassFocus()
            end},
            {"Image", ru = "Вставить как изображение", action = function()
            editor:ReplaceSel('<img src="'..FILEMAN.RelativePath()..'"/>')
                iup.PassFocus()
            end},
    }})
end

local function Sidebar_Init()

    init()
    SideBar_Plugins.htmlpreview = {
        handle = web;
    }
end

local function Toolbar_Init(h)
    init()
    local box = iup.sc_sbox{ web, maxsize = "x590", shrink = 'YES', direction = 'SOUTH'}

    function web:map_cb()
        local bar = iup.GetParent(box)
        bar.maxsize = 'x600'
        local sb = iup.GetChild(box, 0)
        sb.cursor = "RESIZE_NS"
        box.value = _G.iuprops["htmlpreview.webwidth"] or "200"
    end
    function web:unmap_cb(h)
        _G.iuprops["htmlpreview.webwidth"] = box.value
    end

    h.Tabs.htmlpreview =  {
        handle = box
    }

end

return {
    title = 'Html Preview',
    code = 'htmlpreview',
    sidebar = Sidebar_Init,
    toolbar = Toolbar_Init

}
