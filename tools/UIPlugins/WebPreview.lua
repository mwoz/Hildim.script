require "luacom"

local web

local function init()
    local body_events = {}

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

    function body_events.onclick(q, b, c, r, t)
        local _, _, xC, yC = iup.GetGlobal('CURSORPOS'):find('(%d+)x(%d+)')
        local _, _, xP, yP = web.screenposition:find('(%d+),(%d+)')
        local el = web.com.document:elementFromPoint(tonumber(xC) - tonumber(xP), tonumber(yC) - tonumber(yP))

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
            editor.SelectionStart = 0
            editor.SelectionEnd = 0
        for i = 0, counter do
            findSettings:FindNext(true)
        end
    end

    local function OnChar_local(char)
        if editor.LexerLanguage ~= "hypertext" then return end

        local str
        if editor.StyleAt[editor.SelectionStart] == 0 then
            editor.TargetStart = 0
            editor.TargetEnd = editor.SelectionStart
            str = editor:textrange(0, editor.SelectionStart)..'<span style="color:red" id="cursor___">|</span>'..editor:textrange(editor.SelectionStart + 1, editor.Length)
        else
            str = editor:GetText()
        end
        iup.SetAttribute(web, "HTMLSMAPT", str)
        iup.PassFocus()

        luacom.Connect(web.com.document.body, body_events)
        -- print(CreateLuaCOM(ih)web.com:document())

        --web.htmlsmart = str
        --iup.PassFocus()
    end

    -- web = iup.webbrowser{}
    web = iup.webbrowser{}

    CreateLuaCOM(web)
    iup.SetAttribute(web, "TOPMARGIN", 50)
    iup.SetAttribute(web, "INVOKEFLAG", 400)
    AddEventHandler("OnChar", OnChar_local)
end

local function Sidebar_Init()

    init()
    SideBar_Plugins.htmlpreview = {
        handle = web;
    }
end

local function Toolbar_Init(h)


end
return {
    title = 'Html Preview',
    code = 'htmlpreview',
    sidebar = Sidebar_Init

}
