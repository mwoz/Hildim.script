--[[������ �������������� ������ ������]]
local function Show()

    local list_lex, dlg
    local btn_ok = iup.button  {title="OK"}
    iup.SetHandle("LEX_BTN_OK",btn_ok)
    btn_ok.action = function()
        local t = ''
        local maxL = tonumber(iup.GetAttribute(list_lex, 'NUMLIN'))
        local f
        local tFiles, tLng = {},{}
        for i = 0, maxL - 1 do
            if iup.GetAttributeId2(list_lex, 'TOGGLEVALUE', i, 1) == '1' then
                local fName = list_lex:getcell(i,4)
                tFiles[fName] = true
                t = t.."{'"..list_lex:getcell(i,2).."', action = function() scite.SetLexer('"..list_lex:getcell(i,5).."') end, check=function() return editor.LexerLanguage == '"..list_lex:getcell(i,3).."' end,},\n"
            end
        end
        t = "return {\n"..t.."},\n{\n"
        for n,_ in pairs(tFiles) do
            n = n:gsub('%.[^.]*$', '')..'.properties'
            t = t..'{"Open '..n..'", action =function() scite.Open(props["SciteDefaultHome"].."\\\\languages\\\\'..n..'") end},\n'
        end
        t = t..'}'
        f = io.open(props['SciteDefaultHome']..'\\data\\home\\HilightMenu.lua',"w")
        f:write(t)
        f:close()
        t = ''
        for n,_ in pairs(tFiles) do
            t = t..'import $(SciteDefaultHome)\\languages\\'..n:gsub('%.[^.]*$', '')..'.properties\n'
        end
        f = io.open(props['SciteDefaultHome']..'\\data\\home\\Languages.properties',"w")
        f:write(t)
        f:close()
        scite.Perform("reloadproperties:")

        dlg:hide()
        dlg:postdestroy()
        scite.PostCommand(POST_SCRIPTRELOAD,0)
    end

    list_lex = iup.matrix{
    numcol=5, numcol_visible=2,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', scrollbar="YES" ,
    resizematrix = "YES"  ,readonly="NO"  ,markmultiple="NO" ,height0 = 4, expand = "YES", framecolor="255 255 255",
    width0 = 0 ,rasterwidth1 = 18,rasterwidth2= 200,rasterwidth3= 100,rasterwidth3= 100,rasterwidth4= 100}

    list_lex.dropcheck_cb = function(h, lin, col)
        if col == 1 then return -4 else return 0 end
    end

    list_lex.edition_cb = function(h, lin, col, mode, update)
        if col == 2 then return -1 end
    end

    local vbox = iup.vbox{
        iup.hbox{iup.vbox{list_lex}};

        iup.hbox{btn_ok},
        expandchildren ='YES',gap=2,margin="4x4"}
    dlg = iup.scitedialog{vbox; title="������ ������������ ������",defaultenter="LEX_BTN_OK",defaultesc="LEX_BTN_ESC",tabsize=editor.TabWidth,
        maxbox="NO",minbox ="NO",resize ="YES",shrink ="YES",sciteparent="SCITE", sciteid="LexersSetup", minsize='300x600'}

    dlg.show_cb=(function(h,state)
        if state == 4 then
            dlg:postdestroy()
        end
    end)

    local tbl_lex = {}
    local table_dir = shell.findfiles(props['SciteDefaultHome']..'\\languages\\*.properties')
    for i = 1, #table_dir do
        local f = io.open(props['SciteDefaultHome']..'\\languages\\'..table_dir[i].name)
        local s = f:read('*a')
        f:close()
        for filePtrn, lexLng in s:gmatch('\n? *lexer%.%$%(file%.patterns%.([%w_]+)%)=(%w+)') do
            local tbl_l = {}
            tbl_l.name = table_dir[i].name
            tbl_l.lexer = lexLng
            local _,_,fExt = s:find('\n? *file%.patterns%.'..filePtrn..'=[^\n]*%.(%w+)')
            tbl_l.ext = fExt or filePtrn
            local _,_,fView = s:find('\n? *filter%.'..filePtrn..'=([^%(\r\n]*)')
            tbl_l.view = fView or filePtrn
            table.insert(tbl_lex, tbl_l)
        end
    end

    iup.SetAttribute(list_lex, "ADDLIN", "1-"..(#tbl_lex))
    table.sort(tbl_lex, function(a, b)
        return a.view:upper() < b.view:upper()
    end)
    for i = 1, #tbl_lex do
        list_lex:setcell(i, 2, tbl_lex[i].view)
        list_lex:setcell(i, 3, tbl_lex[i].lexer)
        list_lex:setcell(i, 4, tbl_lex[i].name)
        list_lex:setcell(i, 5, tbl_lex[i].ext)

    end

    if shell.fileexists(props["SciteDefaultHome"].."\\data\\home\\HilightMenu.lua") then
        local tHilight = assert(loadfile(props["SciteDefaultHome"].."\\data\\home\\HilightMenu.lua"))()
        for j = 1, #tHilight do
            for i = 1, #tbl_lex do
                if tbl_lex[i].view == tHilight[j][1] then
                    tbl_lex[i].checked = true
                    break
                end
            end
        end
    end

    for i = 1, #tbl_lex do
        --list_lex:setcell(i, 2, tbl_lex[i].name)
        if tbl_lex[i].checked then
            iup.SetAttributeId2(list_lex, 'TOGGLEVALUE', i, 1, '1')
        end
    end

end

Show()