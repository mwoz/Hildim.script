
local onDestroy
local function Latex_Init(h)
    LATEX = {}
    if not lpeg then lpeg = require"lpeg" end
    if not lanes then
        lanes = require("lanes").configure()
    end
    local linda = lanes.linda()
    local cmb_size
    local bFillCells = 1
    -- local function runAsync(cmd, key, dir)
    local function MimeLoop(mimePath)
        shell = require"shell"
        lpeg = require"lpeg"
        local patt, patCyr
        do
            local tCyr = {[("À"):byte()] = "A", [("à"):byte()] = "a", [("Á"):byte()] = "B", [("á"):byte()] = "b", [("Â"):byte()] = "V", [("â"):byte()] = "v",
                [("Ã"):byte()] = "G", [("ã"):byte()] = "g", [("Ä"):byte()] = "D", [("ä"):byte()] = "d", [("Å"):byte()] = "E", [("å"):byte()] = "e",
                [("¨"):byte()] = '\\\\\\"E',[("¸"):byte()] = '\\\\\\"e',[("Æ"):byte()] = "ZH", [("æ"):byte()] = "zh", [("Ç"):byte()] = "Z",
                [("ç"):byte()] = "z", [("È"):byte()] = "I", [("è"):byte()] = "i", [("É"):byte()] = "\\u I", [("é"):byte()] = "\\u\\i",
                [("Ê"):byte()] = "K", [("ê"):byte()] = "k", [("Ë"):byte()] = "L", [("ë"):byte()] = "l", [("Ì"):byte()] = "M", [("ì"):byte()] = "m",
                [("Í"):byte()] = "N", [("í"):byte()] = "n", [("Î"):byte()] = "O", [("î"):byte()] = "o", [("Ï"):byte()] = "P", [("ï"):byte()] = "p",
                [("Ð"):byte()] = "R", [("ð"):byte()] = "r", [("Ñ"):byte()] = "S", [("ñ"):byte()] = "s", [("Ò"):byte()] = "T", [("ò"):byte()] = "t",
                [("Ó"):byte()] = "U", [("ó"):byte()] = "u", [("Ô"):byte()] = "F", [("ô"):byte()] = "f", [("Õ"):byte()] = "KH", [("õ"):byte()] = "kh",
                [("Ö"):byte()] = "TS", [("ö"):byte()] = "ts", [("×"):byte()] = "CH", [("÷"):byte()] = "ch", [("Ø"):byte()] = "SH",
                [("ø"):byte()] = "sh", [("Ù"):byte()] = "SHCH", [("ù"):byte()] = "shch", [("Ú"):byte()] = "\\Cdprime",
                [("ú"):byte()] = "\\cdprime", [("Û"):byte()] = "Y", [("û"):byte()] = "y", [("Ü"):byte()] = "\\Cprime",
                [("ü"):byte()] = "\\cprime", [("Ý"):byte()] = "\\`E", [("ý"):byte()] = "\\`e", [("Þ"):byte()] = "YU",[("þ"):byte()] = "yu",
            [("ß"):byte()] = "Ya", [("ß"):byte()] = "YA", [("ÿ"):byte()] = "ya", [("¹"):byte()] = "N0", [("«"):byte()] = "<", [("»"):byte()] = ">"}
            local cyrSym = lpeg.R'àÿ' + lpeg.R'Àß' + lpeg.S'¨¸¹«»'
            local cyr = lpeg.C(cyrSym *((lpeg.P' ') + cyrSym)^0) / function(c)
                -- local cyr = lpeg.C(cyrSym^1) / function(c)
                local t = {}
                for i = 1,  #c do
                    table.insert(t, tCyr[c:byte(i, i)] or ' ')
                end
                return '{\\cyr '..table.concat(t, '')..'}'
            end
            patCyr = lpeg.Cs((lpeg.C'\r\n'/' ' + lpeg.C'\t'/' ' + lpeg.C'\\"' / '^\\"' + lpeg.C'"' / '\\"' + cyr + 1)^0)
            local space = lpeg.S'\r\n '^1
            local capNum = lpeg.C(lpeg.R'09'^1)
            local p = lpeg.P'P2' * space * capNum * space * capNum * space * lpeg.P'255' * space
            local cell = (capNum * space) / function(d)
                d = tonumber(d)
                if d > 239 then return 15         -- 255
                elseif d > 223 then return 14     -- 238
                elseif d > 207 then return 13     -- 221
                elseif d > 191 then return 12     -- 204
                elseif d > 175 then return 11     -- 187
                elseif d > 159 then return 10     -- 170
                elseif d > 143 then return 9      -- 153
                elseif d > 127 then return 8      -- 138
                elseif d > 111 then return 7      -- 110
                elseif d > 95 then return 6       -- 102
                elseif d > 79 then return 5       -- 85
                elseif d > 63 then return 4       -- 88
                elseif d > 47 then return 3       -- 51
                elseif d > 31 then return 2       -- 34
                elseif d > 15 then return 1       -- 16
                else return 0                     -- 0
                end
            end
            patt = lpeg.Ct(p * lpeg.Ct(cell^1))
        end
        local function getImage(formula, nrep, size, collback)
            local cmd = mimePath..' -g2 -d " '..formula..' " -s '..size

            local ierr, strerr
            local proc, err, errdesc = shell.startProc(cmd)
            local out
            if proc then
                while true do
                    local c, msg, exitcode = proc:Continue()
                    if c == "C" then
                        if out then
                            table.insert(out, msg)
                        else
                            out = {}
                            table.insert(out, msg)
                        end
                    else
                        local val = math.tointeger(exitcode)
                        if val == 0 then
                            local strOut = table.concat(out, '')
                            local t = patt:match(strOut, 1)
                            if t then
                                linda:send( "MimetexView", {data = t, nrepeat = nrep, clb = collback})
                            else
                                linda:send( "MimetexView", {err = "Match Error", out = strOut, clb = collback})
                            end
                        else
                            linda:send( "MimetexView", {err = "MimetexView Process Exit Code: "..val, clb = collback})
                        end
                        break
                    end
                end
            else
                linda:send( "MimetexView", {err = "Error: Command "..cmd..' '..err..' '..(errdesc or ''), clb = collback})
            end
        end

        while true do
            local key, val = linda:receive( 100, "_MimetexView")
            if val ~= nil then
                repeat
                    local k, v = linda:receive( 0.1, "_MimetexView")
                    if v then val = v end
                until not v
                if val.cmd == "GET" then
                    local formula = patCyr:match((val.formula or ''), 1)
                    getImage(formula, val.nrepeat, val.size, val.clb)
                elseif val.cmd == "EXIT" then
                    break;
                end
            end
        end


    end

    local lanesgen = lanes.gen("package,io,string,math,table", {required = {"shell", "lpeg"}}, MimeLoop)('"'..props["SciteDefaultHome"]..'\\tools\\LuaLib\\mimetex.exe"')

    local gray = {
        '255 255 255',
        '238 238 238',
        '221 221 221',
        '204 204 204',
        '187 187 187',
        '170 170 170',
        '153 153 153',
        '138 138 138',
        '110 110 110',
        '102 102 102',
        '85 85 85',
        '88 88 88',
        '51 51 51',
        '34 34 34',
        '16 16 16',
        '0 0 0',
    }
    onDestroy = function() linda:send("_Functions", {cmd = 'EXIT',}) end


    local imgEmpty = iup.image{width = 1, height = 1, pixels = {1}}
    local lImage = iup.label{image = imgEmpty}
    local pane

    local nRepeat = 0
    AddEventHandler("OnLindaNotify", function(key)
        if key == 'MimetexView' then
            local key, val = linda:receive( 1.0, "MimetexView")    -- timeout in seconds
            if val.clb then
                val.clb(val)
                return
            end
            if val.data then
                if nRepeat ~= val.nrepeat then return end
                local t = val.data
                iup.GetParent(lImage).margin = '5x5'
                lImage.image = iup.image{width = tonumber(t[1]), height = tonumber(t[2]), pixels = t[3], colors = gray}
                iup.RefreshChildren(pane)
            elseif val.err then
                print(val.err)
            end
        end
    end)

    function LATEX.ShowFormula(text, collback)
        nRepeat = nRepeat + 1
        linda:send("_MimetexView", {formula = text, cmd = 'GET', nrepeat = nRepeat, size =(tonumber(cmb_size.value) - 1), clb = collback})
    end

    local fstart, fend
    AddEventHandler("OnUpdateUI", function(bModified, bSelection, flag)
        if editor_LexerLanguage() == 'script_wiki' then
            if bSelection then
                if editor:ustyle(editor.CurrentPos) == 22 then
                    local s = editor.CurrentPos
                    local e = s
                    while s > 0 and editor:ustyle(s - 1) == 22 do s = s - 1 end
                    if s == fstart and bModified == 0 then return end
                    fstart = s
                    while e <= editor.Length and editor:ustyle(e + 1) == 22 do e = e + 1 end
                    fend = e
                    LATEX.ShowFormula(editor:textrange(s, e))
                else
                    if fstart then
                        iup.GetParent(lImage).margin = '0x0'
                        lImage.image = imgEmpty
                        iup.RefreshChildren(pane)
                        fstart = nil
                    end
                    return
                end
            end
        else
            fstart = nil
        end
    end)

    local function on_btn_click(h)
        local s = h.tip
        local sel = editor:GetSelText()
        if sel ~= '' then s = s:gsub('{[sS]+}', '{'..sel..'}') end
        editor:ReplaceSel(s)
        iup.PassFocus()
    end

    function LATEX.do_style(h)
        local s = h.tip
        local sel = editor:GetSelText()
        if sel ~= '' then
            s = '{'..s:gsub('{[^}]+}', ' '..sel..'}')
        else
            s = s:gsub('{[^}]+}', '')
        end
        editor:ReplaceSel(s)
        iup.PassFocus()
    end

    local function openclose_cb(h, state)
        if state == 0 then return end
        local hP = iup.GetParent(h)
        local hCh = iup.GetNextChild(hP, nil)
        repeat
            if iup.GetClassName(hCh) == 'expander' and hCh ~= h then hCh.state = 'CLOSE' end
            hCh = iup.GetNextChild(hP, hCh)
        until not hCh
        scite.RunAsync(function() iup.RefreshChildren(iup.GetParent(iup.GetParent(h))) end)
        if state == 2 then
            h.state = 'OPEN'
            return iup.IGNORE
        end
    end

    local function Run()
        local t = editor:GetSelText()
        LATEX.ShowFormula(t)
    end

    function LATEX.do_size()
        local ret, nSz = iup.GetParam("Size^latex",
            function(h, id)
                if id == iup.GETPARAM_INIT then
                    iup.GetParamParam(h, 0).control.visibleitems = 15
                end
                return 1
            end,
            _T'Font size:'..' %l|tiny|small|normalsize|large|Large|LARGE|huge|Huge|\n'..
            '',
            3
        )
        if ret then
            local tMap = {"tiny", "normalsize", "small", "large", "Large", "huge", "LARGE", "Huge"}
            local sel = editor:GetSelText()
            if sel ~= '' then
                sel = '{\\'..tMap[nSz + 1]..' '..sel..'}'
            else
                sel = '\\'..tMap[nSz + 1]
            end
            editor:ReplaceSel(sel)
        end
        iup.PassFocus()
    end

    function LATEX.do_align(h)
        local _, _, tag = h.tip:find('{([^}]+)}')
        local ret, nCS, nRS, bFC = iup.GetParam('{'..tag.."}^latex",
            nil,
            _T'Columns:'..' %i[1,64,1]\n'..
            _T'Rows:'..' %i[1,64,1]\n'..
            _T'Fill Cells:'..' %b\n'..
            '',
            2, 2, bFillCells
        )
        if ret then
            bFillCells = bFC
            local t = {}
            for i = 1, nRS do
                local tR = {}
                for j = 1, nCS do
                    table.insert(tR, Iif(bFC == 1, 'a^'..i..'_'..j, ' '))
                end
                table.insert(t, table.concat(tR, ' & '))
            end
            editor:ReplaceSel('\\begin{'..tag..'}\r\n'..
              table.concat(t, ' \\\\\r\n')..'\r\n\\end{'..tag..'}' )
        end
        iup.PassFocus()
    end

    function LATEX.do_matrix()
        local ret, nMat, nCS, nRS, bFC = iup.GetParam(_T"Matrix".."^latex",
            function(h, id)
                if id == iup.GETPARAM_INIT then
                    iup.GetParamParam(h, 0).control.visibleitems = 15
                end
                return 1
            end,
            _T'Type:'..' %l|âˆ·|×€âˆ·×€|×€×€âˆ·×€×€|(âˆ·)|{âˆ·}|{âˆ·|[âˆ·]|\n'..
            _T'Columns:'..' %i[1,64,1]\n'..
            _T'Rows:'..' %i[1,64,1]\n'..
            _T'Fill Cells:'..' %b\n'..
            '',
            0, 2, 2, bFillCells
        )
        if ret then
            bFillCells = bFC
            local matrix = {'matrix', 'vmatrix', 'Vmatrix', 'pmatrix', 'Bmatrix', 'cases' , 'bmatrix',}
            local t = {}
            for i = 1, nRS do
                local tR = {}
                for j = 1, nCS do
                    table.insert(tR, Iif(bFC == 1, 'a^'..i..'_'..j, ' '))
                end
                table.insert(t, table.concat(tR, ' & '))
            end
            editor:ReplaceSel('\\begin{'..matrix[nMat + 1]..'}\r\n'..
              table.concat(t, ' \\\\\r\n')..'\r\n\\end{'..matrix[nMat+1]..'}' )
        end
        iup.PassFocus()
    end

    function LATEX.do_array()
        local ret, nCS, nRS, typeVl, nVl, typeHl, nHl, bFC = iup.GetParam(_T"Array".."^latex",
            function(h, id)
                if id == iup.GETPARAM_INIT then
                    iup.GetParamParam(h, 2).control.visibleitems = 15
                    iup.GetParamParam(h, 4).control.visibleitems = 15
                    iup.GetParamParam(h, 3).auxcontrol.active = 'NO'
                    iup.GetParamParam(h, 3).control.active = 'NO'
                    iup.GetParamParam(h, 5).auxcontrol.active = 'NO'
                    iup.GetParamParam(h, 5).control.active = 'NO'
                elseif id == 0 or id == 1 then
                    local id2 = Iif(id == 0, 3, 5)
                    iup.GetParamParam(h, id2).auxcontrol.max = tonumber(iup.GetParamParam(h, id).value) - 1
                elseif id == 2 or id == 4 then
                    iup.GetParamParam(h, id + 1).auxcontrol.active = Iif(iup.GetParamParam(h, id).value == '0', 'NO', 'YES')
                    iup.GetParamParam(h, id + 1).control.active = Iif(iup.GetParamParam(h, id).value == '0', 'NO', 'YES')
                elseif id == 3 or id == 5 then
                    if tonumber(iup.GetParamParam(h, id).value) > 0 then
                        iup.GetParamParam(h, id).label.title = _T'Only After Line:'
                    else
                        iup.GetParamParam(h, id).label.title = _T'All lines'
                    end
                end
                return 1
            end,
            _T'Columns:'..' %i[1,64,1]\n'..
            _T'Rows:'..' %i[1,64,1]\n'..
            _T'Vertical lines:'..' %l|<none>|dots|line|\n'..
            _T'All lines'..' %i[0,1,1]\n'..
            _T'Horizontal lines:'..' %l|<none>|dots|line|\n'..
            _T'All lines:'..' %i[0,1,1]\n'..
            _T'Fill Cells:'..' %b\n'..
            '',
            2, 2, 0, 0, 0, 0, bFillCells
        )
        if ret then
            bFillCells = bFC
            local matrix = {'matrix', 'vmatrix', 'Vmatrix', 'pmatrix', 'Bmatrix', 'cases' , 'bmatrix',}
            local t = {}
            local cols = ''
            if typeVl ~= 0 then cols = '{' end
            for i = 1, nRS do
                local tR = {}
                for j = 1, nCS do
                    if i == 1 and cols ~= '' then
                        cols = cols..'c'
                        if j == nCS then cols = cols..'}'
                        elseif nVl == 0 or nVl == j then
                            cols = cols..Iif(typeVl == 1, '.', '|')
                        else
                            cols = cols..' '
                        end
                    end
                    table.insert(tR, Iif(bFC == 1, 'a^'..i..'_'..j, ' '))
                end
                local brk = ''
                if i ~= nRs then
                    brk = ' \\\\'
                    if typeHl ~= 0 and i ~= nRS and (nHl == 0 or nHl == i) then
                        brk = brk..Iif(typeHl == 1, '\\hdash', '\\hline')
                    end
                end
                table.insert(t, table.concat(tR, ' & ')..brk)
            end
            editor:ReplaceSel('\\begin{array}'..cols..'\r\n'..
              table.concat(t, '\r\n')..'\r\n\\end{array}' )
        end
        iup.PassFocus()
    end

    function LATEX.do_arrow()
        local ret, nArInd, nLength, tUp, tDown = iup.GetParam(_T"Long Arrow".."^latex",
            function(h, id)

                if id == iup.GETPARAM_INIT then
                    iup.GetParamParam(h, 0).control.visibleitems = 20
                elseif id == 0 then
                    if tonumber(iup.GetParamParam(h, id).control.value) % 2 == 1 then
                        iup.GetParamParam(h, 2).label.title = _T'Upper text:'
                        iup.GetParamParam(h, 3).label.title = _T'Lower text:'
                    else
                        iup.GetParamParam(h, 2).label.title = _T'Left text:'
                        iup.GetParamParam(h, 3).label.title = _T'Right text:'
                    end
                end
                return 1
            end,
            _T'Arrow:'..' %l|  â†|  â†‘|  â†’|  â†“|  â†”|  â†•|  â‡|  â‡‘|  â‡’|  â‡“|  â‡”|  â‡•|\n'..
            _T'Length:'..' %i[1,300,1]\n'..
            _T'Upper text:'..' %s\n'..
            _T'Lower text:'..' %s\n'..
            '',
            0, 50, 'a', 'b'
        )
        if ret then
            nArInd = nArInd + 1
            local ind = Iif(nArInd > 6, nArInd - 6, nArInd)
            local l = Iif(nArInd > 6, "L", "l")
            local arrow = {'left', 'up', 'right', 'down', 'leftrigh', 'updown' }
            local s = ''
            if nLength > 0 then s = s..'['..nLength..']' end
            if tUp ~= '' then s = s..'^'..tUp end
            if tDown ~= '' then s = s..'_'..tDown end
            editor:ReplaceSel('\\'..l..'ong'..arrow[ind]..'arrow'..s)
        end
        iup.PassFocus()
    end

    function LATEX.do_middle()
        local ret, nSt = iup.GetParam(_T"Hight Bracket - Inside the line".."^latex",
            function(h, id)

                if id == iup.GETPARAM_INIT then
                    iup.GetParamParam(h, 0).control.visibleitems = 15
                end
                return 1
            end,
            _T'Symbol:'..' %l| ×€|  ×€×€|  (|  {|  [|  <|  )|  }|  ]|  >|\n'..
            '',
            0, 8
        )
        if ret then
            local bracket = {'|', '\\|', '(', '\\{', '[', '<', ')', '\\}', ']', '>' }
            editor:ReplaceSel('\\middle'..bracket[nSt+1])
        end
        iup.PassFocus()
    end

    function LATEX.do_brackets()
        local ret, nLeft, nRight = iup.GetParam(_T"Hight Brackets - Around the selection".."^latex",
            function(h, id)

                if id == iup.GETPARAM_INIT then
                    iup.GetParamParam(h, 0).control.visibleitems = 15
                    iup.GetParamParam(h, 1).control.visibleitems = 15
                elseif id == 0 then
                    local v = tonumber(iup.GetParamParam(h, 0).control.value)
                    local v2 = v
                    if v > 7 then return 1
                    elseif v >= 4 then v2 = v + 4
                    elseif v == 1 then v2 = 9
                    end
                    iup.GetParamParam(h, 1).value = v2 - 1
                    iup.GetParamParam(h, 1).control.value = v2
                end
                return 1
            end,
            _T'Right symbol:'..' %l| |  ×€|  ×€×€|  (|  {|  [|  <|  )|  }|  ]|  >|\n'..
            _T'Left symbol:'..' %l| |  ×€|  ×€×€|  (|  {|  [|  <|  )|  }|  ]|  >|\n'..
            '',
            0, 8
        )
        if ret then
            local bracket = {'.', '|', '\\|', '(', '\\{', '[', '<', ')', '\\}', ']', '>' }
            local s = editor:GetSelText()
            if s == '' then s = 'S' end
            editor:ReplaceSel('\\left'..bracket[nLeft+1]..s..'\\right'..bracket[nRight+1])
        end
        iup.PassFocus()
    end

    cmb_size = iup.list{name = 'cmb_size', dropdown = "YES", visibleitems = "9", size = '17x0', expand = 'NO',
        ['1'] = '0', ['2'] = '1', ['2'] = '1', ['3'] = '2', ['4'] = '3', ['5'] = '4', ['6'] = '5', ['7'] = '6', ['8'] = '7',
        action = function()
            if fstart then LATEX.ShowFormula(editor:textrange(fstart, fend)) end
        end
    }

    local btn_run = iup.flatbutton{image = 'IMAGE_FormRun', flat_action = Run, tip = _T'Run Query'}
    local tPane = {
        iup.hbox{
            iup.label{title = _T'Font size:'}, cmb_size, btn_run,
            alignment = "ACENTER", gap = "3", margin = "3x7"
        },
        iup.backgroundbox{iup.hbox{
            lImage,
            gap = "3",
        }, bgcolor = "255 255 255", expand = 'NO'},

    }

    do
        local tblIcons = dofile(props["SciteDefaultHome"].."\\tools\\Etc\\LatexFormulasIcons.lua")
        for j = 1, #tblIcons do
            local t_lower_greek = {expand = 'NO'}

            local t = tblIcons[j]
            -- debug_prnArgs(t[1][2])

            local y = 10
            local tRstrSize = {}

            for i = 1,  #t do
                if y < t[i][2][2] then y = t[i][2][2] end
                if i == #t or t[i][2].linebreak == 'Y' then
                    table.insert(tRstrSize, 'x'..(y + 4))
                    y = 10
                end
            end

            local szInd = 1

            for i = 1,  #t do
                local f = nil
                if t[i][2].action then
                    f = dostring('return LATEX.'..t[i][2].action)
                end
                local tip = t[i][2].tip
                if tip then tip = _T(tip) end
                local btn = iup.flatbutton{image = iup.image{width = t[i][2][1], height = t[i][2][2], pixels = t[i][2][3], colors = gray},
                    flat_action = (f or on_btn_click), tip = (tip or t[i][1]), rastersize = tRstrSize[szInd], bgcolor = '255 255 255', }
                if t[i][2].linebreak then
                    iup.SetAttribute(btn, "LINEBREAK", 'YES')
                    szInd = szInd + 1
                end
                table.insert(t_lower_greek, btn)
            end
            --t_lower_greek.expand = 'NO'
            table.insert(tPane, iup.expander{iup.hbox{iup.multibox(t_lower_greek),
                    expand = "HORIZONTAL", },
                title = _T(t.title),
                forecolor = iup.GetLayout().fgcolor, state = 'CLOSE',
            openclose_cb = openclose_cb, autoshow = 'YES'})
        end
        tblIcons = nil
    end



    pane = iup.vbox{iup.scrollbox{iup.vbox(tPane), scrollbar = 'NO', minsize = 'x66', expand = "YES", bgcolor = iup.GetLayout().bgcolor}};

    return {
        handle = pane;
        OnSwitchFile = Initialize,
        OnOpen = Initialize,
    }

end

return {
    title = 'Latex Formula',
    code = 'MimetexView',
    sidebar = Latex_Init,
    description = [['Latex Formula Viewer]],
    destroy = function() onDestroy() end,
}

