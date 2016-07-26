local function refControlPos(findSt, findEnd, s, dInd, replAbbr)
    local function lpegCtrlParser()
        --@todo: переписать с использованием lpeg.Cf
        local P, V, Cg, Ct, Cc, S, R, C, Carg, Cf, Cb, Cp, Cmt = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.S, lpeg.R, lpeg.C, lpeg.Carg, lpeg.Cf, lpeg.Cb, lpeg.Cp, lpeg.Cmt

        local PosToLine = function (pos) return editor:LineFromPosition(pos - 1) end

        --v------- common patterns -------v--
        -- basics
        local EOF = P(-1)
        local BOF = P(function(s, i) return (i == 1) and 1 end)
        local NL = P"\n"-- + P"\f" -- pattern matching newline, platform-specific. \f = page break marker
        local AZ = R('AZ', 'az') + "_"
        local N = R'09'
        local ANY = P(1)
        -- simple tokens
        local IDENTIFIER = AZ * (AZ + N)^0 -- simple identifier, without separators


        local cp = Cp() -- pos capture, Carg(1) is the shift value, comes from start_code_pos
        local cl = cp / PosToLine -- line capture, uses editor:LineFromPosition
        --^------- common patterns -------^--
        local function addAny(p, l)
            return p * S(l:lower()..l:upper())
        end
        local toAny = Cf(C(P'') * C(P(1))^1, addAny)
        local function AnyCase(str)
            return toAny:match(str)
        end



		-- redefine common patterns
		local SPACE = (S(" \t"))^1
		local SC = SPACE
		local NL = (P"\r\n")^1 * SC^0

        local dig = C(N^1)
        local pos = Ct(Cg(dig, 'x') * P';' * Cg(dig, 'y') * P';' * Cg(dig, 'w') * P';' * Cg(dig, 'h'))

        local attr = Cg(Cmt(SC^1 * C(IDENTIFIER) * P'="' * C(P(1 - P'"')^0) * P'"',
            function(i, a, p, v)
                if p == 'position' then
                    return true, p, pos:match(v, 1)
                elseif p == 'tag' then
                    return true, 'isref', v:find('ddx_ContainerType=Ref')
                else
                    return true, p, v
                end end
        ))
        local attrs = Cf(Ct("") * attr^1 * Cg(Cc('isAttr') * Cc(true)) * Cg(Cc('inLine') * cl), rawset)
        local attrsl = Cf(Ct("") * attr^1, rawset)
        local cont = SC^0 * AnyCase"<control"
        local ce = Cf(Ct("") * SC^0 * AnyCase"</control" * Cg(Cc('inLine') * cl), rawset)
        local ctrl = cont * attrsl * P'/>' * NL

        local def = P{Ct(cont * attrs * SC^0 * P'>' *(V(1) + (-ce) *(1 - NL)^1 + NL)^0 * ce) + ctrl}
        -- resulting pattern, which does the work

        local patt = (def + (1 - NL)^1 + NL)^0 * EOF
        return lpeg.Ct(patt)
    end

    local containers = {}
    local function Ctrl(s)
        return iup.GetDialogChild(containers[2], s)
    end

    local function create_dialog_Ref()

        containers[4] = iup.hbox{
            iup.label{
                size = "60x0", title = "Left",
            },
            iup.label{
                size = "60x0", title = "Top",
            },
            iup.label{
                size = "60x0", title = "Height",
            },
            iup.label{
                size = "60x0", title = "Dh",
            },
            gap = "20",
            alignment = "ACENTER",
        }

        containers[5] = iup.hbox{
            iup.list{
                visibleitems = "15", size = "60x0", editbox = "YES", name = "cmbX", mask = "/d+", dropdown = "YES",
            },
            iup.text{
                size = "60x0", name = "numY", mask = "/d+",
            },
            iup.text{
                size = "60x0", name = "numH", mask = "/d+",
            },
            iup.text{
                size = "60x11", name = "numDh", mask = "/d+",
            },
            gap = "20",
            alignment = "ACENTER",
        }

        containers[6] = iup.hbox{
            iup.toggle{
                title = "btn1", name = "chkBtn1", size = "60x0",
            },
            iup.list{
                visibleitems = "15", size = "60x0", editbox = "YES", name = "cmbBtn1", mask = "/d+", dropdown = "YES",
            },
            iup.toggle{
                title = "Code", name = "chkCode", size = "60x0",
            },
            iup.list{
                visibleitems = "15", size = "60x0", editbox = "YES", name = "cmbCode", mask = "/d+", dropdown = "YES",
            },
            gap = "20",
        }

        containers[8] = iup.hbox{
            iup.toggle{
                title = "Name", name = "chkName", size = "60x0",
            },
            iup.list{
                visibleitems = "15", size = "60x0", editbox = "YES", name = "cmbName", mask = "/d+", dropdown = "YES",
            },
            iup.toggle{
                title = "btn2", name = "chkBtn2", size = "60x0",
            },
            iup.toggle{
                title = "Info", name = "chkInfo",
            },
            gap = "20",
        }

        containers[9] = iup.hbox{
            iup.button{
                title = "OK",
                name = "btnOK"
            },
            iup.fill{
            },
            iup.button{
                title = "Clear",
                action = function()
                    Ctrl("cmbBtn1").value = ""
                    Ctrl("cmbX").value = ""
                    Ctrl("cmbCode").value = ""
                    Ctrl("cmbName").value = ""
                    Ctrl("numDh").value = ""
                    Ctrl("numH").value = ""
                    Ctrl("numY").value = ""
                end
            },
            iup.button{
                title = "Cancel",
                name = "btnEsc"
            },
        }
        containers[2] = iup.vbox{
            containers[4],
            containers[5],
            containers[6],
            containers[8],
            containers[9],
            margin = "4x4",
            gap = "2",
        }
        return containers[2]
    end

    tblXml = lpegCtrlParser():match(editor:GetText(), 1)
    local icL = editor:LineFromPosition(editor.CurrentPos)
    --debug_prnTb(tblXml,0)
    local Lines = {}
    for w in s:gmatch("[^\n]+") do
        table.insert(Lines, w)
    end
    local defSizes = {}
    for i = 1, 6 do
        defSizes[i] = {}
        _, _, defSizes[i].x, defSizes[i].w, defSizes[i].h = Lines[i]:find('position="(%d+);%d+;(%d+);(%d+)"')
    end

    --debug_prnTb(defSizes, 1)
    local CtrlX, CtrlBtn1W, CtrlCodeW, CtrlNameW = {},{},{},{}
    local CtrlX1, CtrlBtn1W1, CtrlCodeW1, CtrlNameW1 = {},{},{},{}
    CtrlX[defSizes[1].x] = defSizes[1].x
    CtrlBtn1W[defSizes[2].w] = defSizes[2].w
    CtrlCodeW[defSizes[3].w] = defSizes[3].w
    CtrlNameW[defSizes[4].w] = defSizes[4].w

    local iPl, iPY, iPpY, iPX = 0, 0, 0, 0
    local iTmpX, iTmpY, iTmpYp = 0, 0, 0

    for k, v in pairs(tblXml) do
        if v.inLine then
            local l = tonumber(v.inLine)
            if l > iPl and l < icL then
                iPX = v.position.x + v.position.w
                iPY = v.position.y + v.position.h
                iPpY = v.position.y
                iPl = l
            end
        end
        if v.position then
            CtrlX[''..v.position.x] = v.position.x
        end
        for ind, arg in pairs(v) do

            if arg.inLine and arg.isAttr ~= true then
                local l = tonumber(arg.inLine)
                if l > iPl and l < icL then
                    iPX = iTmpX
                    iPY = iTmpY
                    iPpY = iTmpYp
                    iPl = l
                end
            end
            if arg.position then
                if arg.isAttr == true then
                    iTmpX = arg.position.x + arg.position.w
                    iTmpY = arg.position.y + arg.position.h
                    iTmpYp = arg.position.y
                    CtrlX[''..arg.position.x] = arg.position.x
                elseif arg.name == 'btn1' then
                    CtrlBtn1W[''..arg.position.w] = tonumber(arg.position.w)
                elseif arg.name == 'Code' then
                    CtrlCodeW[''..arg.position.w] = arg.position.w
                elseif arg.name == 'Name' then
                    CtrlNameW[''..arg.position.w] = arg.position.w
                end
            end
        end
    end
    for s, i in pairs(CtrlX) do table.insert(CtrlX1,(i)) end
    for s, i in pairs(CtrlBtn1W) do table.insert(CtrlBtn1W1,(i)) end
    for s, i in pairs(CtrlCodeW) do table.insert(CtrlCodeW1,(i)) end
    for s, i in pairs(CtrlNameW) do table.insert(CtrlNameW1,(i)) end

    table.sort(CtrlX1)
    table.sort(CtrlBtn1W1)
    table.sort(CtrlCodeW1)
    table.sort(CtrlNameW1)

    local templ = create_dialog_Ref()

    Ctrl('chkBtn1').value = _G.iuprops['abbrev.refdlg.b1'] or 'ON'
    Ctrl('chkCode').value = _G.iuprops['abbrev.refdlg.b2'] or 'ON'
    Ctrl('chkName').value = _G.iuprops['abbrev.refdlg.b3'] or 'ON'
    Ctrl('chkBtn2').value = _G.iuprops['abbrev.refdlg.b4'] or 'ON'
    Ctrl('chkInfo').value = _G.iuprops['abbrev.refdlg.b5'] or 'ON'
    Ctrl('numH').value = _G.iuprops['abbrev.refdlg.h'] or 12
    Ctrl('numDh').value = _G.iuprops['abbrev.refdlg.dh'] or 2

    local bInPrev = (iPl + 1 == icL)
    iPY = iPY + Ctrl('numDh').value
    iPX = iPX + 10

    local iNewX = -1
    local l = 1
    for i, s in pairs(CtrlX1) do if tonumber(s) > 0
        then iup.SetAttribute(Ctrl("cmbX"), l, s);l = l + 1 end
        if iNewX < 0 and iPX <= tonumber(s) then iNewX = tonumber(s) end
    end
    if iNewX < 0 then iNewX = iPX end
    l = 1
    for i, s in pairs(CtrlBtn1W1) do if tonumber(s) > 0 then iup.SetAttribute(Ctrl("cmbBtn1"), l, s);l = l + 1 end end
    l = 1
    for i, s in pairs(CtrlCodeW1) do if tonumber(s) > 0 then iup.SetAttribute(Ctrl("cmbCode"), l, s);l = l + 1 end end
    l = 1
    for i, s in pairs(CtrlNameW1) do if tonumber(s) > 0 then iup.SetAttribute(Ctrl("cmbName"), l, s);l = l + 1 end end

    Ctrl("cmbX").value = 1; Ctrl("cmbBtn1").value = CtrlBtn1W1[1]..''; Ctrl("cmbCode").value = CtrlCodeW1[1]; Ctrl("cmbName").value = CtrlNameW1[1]
    if bInPrev then
        Ctrl('cmbX').value = iPX..''
        Ctrl('numY').value = iPpY..''
    else

        Ctrl('cmbX').value = '10'
        Ctrl('numY').value = iPY..''
    end
    iup.SetHandle("RG_BTN_ESC", Ctrl('btnEsc'))
    iup.SetHandle("RG_BTN_OK", Ctrl('btnOK'))

    local dlg = iup.scitedialog{templ; title = "–еф √ритер", defaultenter = "RG_BTN_OK", defaultesc = "RG_BTN_ESC", tabsize = editor.TabWidth,
    maxbox = "NO", minbox = "NO", resize = "YES", shrink = "YES", sciteparent = "SCITE", sciteid = "abbreveditor"}

    dlg.show_cb =(function(h, state)
        if state == 4 then
            dlg:postdestroy()
        end
    end)
    Ctrl("btnEsc").action = function()
        dlg:postdestroy()
    end

    Ctrl("btnOK").action = function()
        local s = ''
        local x = 0
        local h = tonumber(Ctrl('numH').value)
        if Ctrl('chkBtn1').value == 'ON' then
            s = s..Lines[2]:gsub('position="(%d+);(%d+);%d+;(%d+)"', 'position="%1;%2;'..Ctrl('cmbBtn1').value..';'..h..'"', 1)
            x = x + tonumber(Ctrl('cmbBtn1').value)
        end
        if Ctrl('chkCode').value == 'ON' then
            s = s..Lines[3]:gsub('position="(%d+);(%d+);%d+;(%d+)"', 'position="'..x..';%2;'..Ctrl('cmbCode').value..';'..h..'"', 1)
            x = x + tonumber(Ctrl('cmbCode').value)
        end
        if Ctrl('chkName').value == 'ON' then
            x = x + defSizes[4].x - defSizes[3].x - defSizes[3].w
            s = s..Lines[4]:gsub('position="(%d+);(%d+);%d+;(%d+)"', 'position="'..x..';%2;'..Ctrl('cmbName').value..';'..h..'"', 1)
            x = x + tonumber(Ctrl('cmbName').value)
        end
        if Ctrl('chkBtn2').value == 'ON' then
            x = x + defSizes[5].x - defSizes[4].x - defSizes[4].w
            s = s..Lines[5]:gsub('position="%d+;(%d+);(%d+);(%d+)"', 'position="'..x..';%1;'..h..';'..h..'"', 1)
            x = x + h
        end
        if Ctrl('chkInfo').value == 'ON' then
            x = x + defSizes[6].x - defSizes[5].x - defSizes[5].w
            s = s..Lines[6]:gsub('position="%d+;(%d+);(%d+);(%d+)"', 'position="'..x..';%1;%2;'..h..'"', 1)
            x = x + defSizes[6].w + defSizes[6].x - defSizes[5].x - defSizes[5].w
        end
        s = s..Lines[7]:gsub('ЛREFCTLЫ', '')

        s = Lines[1]:gsub('position="%d+;%d+;%d+;%d+"', 'position="'..Ctrl('cmbX').value..';'..Ctrl('numY').value..';'..x..';'..Ctrl('numH').value..'"', 1)..'\n'..s
        _G.iuprops['abbrev.refdlg.b1'] = Ctrl('chkBtn1').value
        _G.iuprops['abbrev.refdlg.b2'] = Ctrl('chkCode').value
        _G.iuprops['abbrev.refdlg.b3'] = Ctrl('chkName').value
        _G.iuprops['abbrev.refdlg.b4'] = Ctrl('chkBtn2').value
        _G.iuprops['abbrev.refdlg.b5'] = Ctrl('chkInfo').value
        _G.iuprops['abbrev.refdlg.h'] = Ctrl('numH').value
        _G.iuprops['abbrev.refdlg.dh'] = Ctrl('numDh').value

        replAbbr(findSt, findEnd, s, dInd)
        dlg:postdestroy()
    end
end

return refControlPos
