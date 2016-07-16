local web

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
    --web.htmlsmart = str
    iup.PassFocus()
end

local function init()
    web = iup.webbrowser{dlcontrol_flag="400"}
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
