
local function Init(h)
    local lblSel

    onSetFindRes = function(what, count, sels)
        if count > 0 then
            if (scite.SendEditor(SCI_GETCODEPAGE) ~= 0) then what = what:from_utf8(1251) end
            lblSel.value = what..'   :'..Iif(sels > 1, sels..' from ', '')..count..' entry'
        else lblSel.value = ''
        end
    end

    local function ColorDlg()
        local txtCol, txtSel, lblSel, txtLine
        local t = editor:GetText()
        local tc ={};tc['0 0 0'] = true;tc['255 255 255'] = true
        for r, g, b in t:gmatch('["#](%x%x)(%x%x)(%x%x)[%W]') do
            tc[((('0x'..r) + 0)..' '..(('0x'..g) + 0)..' ' ..(('0x'..b) + 0))] = true
        end
        for r, g, b in t:gmatch('RGB%( *&H(%x%x)[, ]+&H(%x%x)[, ]+&H(%x%x)') do
            tc[((('0x'..r) + 0)..' '..(('0x'..g) + 0)..' ' ..(('0x'..b) + 0))] = true
        end
        for r, g, b in t:gmatch('RGB%( *([0-9]+)[, ]+([0-9]+)[, ]+([0-9]+)') do
            tc[r..' '..g..' '..b] = true
        end
        local tc2 ={}
        for c, _ in pairs(tc) do
            table.insert(tc2, c)
        end
        local txtSample, clp, clb, txtOutB, txtOutF, txtR, txtG, txtB
        local nTip, nCel, cB, cF = -1,0
        local function StaticControls()
            local prim, sec, r, g, b = iup.GetAttributeId(clp, 'CELL', cF), iup.GetAttributeId(clp, 'CELL',cB)
            txtSample.bgcolor = sec
            txtSample.fgcolor = prim
            local _, _, r, g, b = prim:find('([0-9]+) ([0-9]+) ([0-9]+)')
            txtOutF.value = string.format('RGB(%i, %i, %i)    #%02x%02x%02x', r, g, b, r, g,b)
            _, _, r, g, b = sec:find('([0-9]+) ([0-9]+) ([0-9]+)')
            txtOutB.value = string.format('RGB(%i, %i, %i)    #%02x%02x%02x', r, g, b, r, g,b)
            local c = Iif(nTip ==- 1, prim, sec)
        end
        local function ByTxt(h)
            local rgb =((('0x'..txtR.Value) + 0)..' '..(('0x'..txtG.Value) + 0)..' ' ..(('0x'..txtB.Value) + 0))
            clb.rgb = rgb
            iup.SetAttributeId(clp, 'CELL', nCel, rgb )
            StaticControls()
        end

        clb = iup.colorbrowser{}

        txtSample = iup.text{readonly = 'YES', value = 'some text some text some text ';expand = 'HORIZONTAL';maxsize = clb.rastersize;}
        txtOutF = iup.text{readonly = 'YES';expand = 'HORIZONTAL'}
        txtOutB = iup.text{readonly = 'YES';expand = 'HORIZONTAL'}
        txtR = iup.text{mask = '[abcdef0-9][abcdef0-9]?';expand = 'NO';size = '40x0', value = 'ff';action = ByTxt, valuechanged_cb =(function(h) if h.value == '' then h.value = 0 end; end),}
        txtG = iup.text{mask = '[abcdef0-9][abcdef0-9]?';expand = 'NO';size = '40x0', value = '00';action = ByTxt, valuechanged_cb =(function(h) if h.value == '' then h.value = 0 end; end),}
        txtB = iup.text{mask = '[abcdef0-9][abcdef0-9]?';expand = 'NO';size = '40x0', value = '00';action = ByTxt, valuechanged_cb =(function(h) if h.value == '' then h.value = 0 end; end),}

        clp = iup.colorbar{num_parts = math.floor((#tc2)^0.5);num_cells =#tc2;show_secondary = 'YES';expand = 'NO';rastersize = '260x200';
            select_cb = (function(h, cell, tp)
                local rgb = iup.GetAttributeId(h, 'CELL', cell), tp
                nTip = tp
                nCel = cell
                if tp == -1 then cF = cell else cB = cell end
                clb.rgb = rgb
                local _, _, r, g, b = rgb:find('([0-9]+) ([0-9]+) ([0-9]+)')
                txtR.value = string.format('%02x', r)
                txtG.value = string.format('%02x', g)
                txtB.value = string.format('%02x', b)
                StaticControls()
            end)
        }

        for i, c in pairs(tc2) do
            iup.SetAttributeId(clp, 'CELL', i - 1, c)
        end
        clb.drag_cb =(function(h, r, g, b)
            iup.SetAttributeId(clp, 'CELL', nCel, r..' '..g..' '..b )
            txtR.value = string.format('%02x', r)
            txtG.value = string.format('%02x', g)
            txtB.value = string.format('%02x', b)
            StaticControls()
        end)

        local dlg = iup.scitedialog{
            iup.hbox{
                iup.vbox{
                    clb;
                    iup.hbox{txtR;txtG;txtB};
                    txtSample;txtOutF;txtOutB,
                expand = 'NO'};
            clp};
            title = "Colors", defaultenter = "MOVE_BTN_OK", defaultesc = "MOVE_BTN_ESC", tabsize = editor.TabWidth,
            maxbox = "NO", minbox = "NO", shrink = "YES", sciteparent = "SCITE", sciteid = "color", resize ='NO',
        map_cb =(function() cB, cF = clp.secondary_cell, clp.primary_cell; StaticControls() end)}

        dlg.show_cb =(function(h, state)                             -- "#e0e0e0"  "999999"
            if state == 4 then
                dlg:postdestroy()
            end
        end)
    end
    local function OnSwitch()
        local t = 1000000
        if editor.Lexer ~= SCLEX_MSSQL then
            t = 1000
        end
        iup.GetGlobal('DLGBGCOLOR')
        scite.SendEditor(SCI_SETMOUSEDWELLTIME, t)
    end

    AddEventHandler("OnSwitchFile", OnSwitch)
    AddEventHandler("OnOpen", OnSwitch)

    AddEventHandler("OnDwellStart", function(pos, word)
        if pos ~= 0 then
            if #word == 6 and word:match('%x%x%x%x%x%x') then
                local _, _, r, g, b = word:find('(%x%x)(%x%x)(%x%x)$')
                lblSel.bgcolor = (('0x'..r) + 0)..' '..(('0x'..g) + 0)..' ' ..(('0x'..b) + 0);isColor = true
            elseif word == 'RGB' then
                local le = editor:GetLine(editor:LineFromPosition(pos))     --[, ]+%)
                local f, _, r, g, b = le:find('RGB%( *([0-9]+)[, ]+([0-9]+)[, ]+([0-9]+)')
                if f then
                    lblSel.bgcolor = r..' '..g..' '..b ;isColor = true
                else
                    f, _, r, g, b = le:find('RGB%( *&H(%x%x)[, ]+&H(%x%x)[, ]+&H(%x%x)')
                    if f then
                        lblSel.bgcolor = (('0x'..r) + 0)..' '..(('0x'..g) + 0)..' ' ..(('0x'..b) + 0) ;isColor = true
                    end
                end
            elseif isColor then
                lblSel.bgcolor = iup.GetGlobal('DLGBGCOLOR') ;isColor = false
            end
        elseif isColor then
            lblSel.bgcolor = iup.GetGlobal('DLGBGCOLOR') ;isColor = false
        end
    end)

    --AddEventHandler("OnSwitchFile", ShowCurrentColour)
    --AddEventHandler("OnDwellStart", ShowCurrentColour)
    lblSel = iup.text{size = '200x0'; readonly = 'YES', canfocus = "NO", bgcolor = iup.GetGlobal('DLGBGCOLOR'),
        tip = '����� ��������� ����������� �����',
        tips_cb =(function(h, x, y)
            h.tip = '����� ��������� ����������� �����'..Iif(editor.Lexer == SCLEX_FORMENJINE, '\n����� ����� ��� ��������', '')
        end);
        button_cb = (function(h, but, pressed, x, y, status)
            if iup.isdouble(status) and iup.isbutton1(status) then
                ColorDlg()
            elseif iup.isbutton3(status) then
                local mnu = iup.menu
                {
                    iup.item{title = "������� �������", action = ColorDlg}
                }:popup(iup.MOUSEPOS, iup.MOUSEPOS)
                return - 1
            end
    end)}

    h.Tabs.sel_color = {
        handle = iup.hbox{
            lblSel; alignment = 'ACENTER'
        };
    }
end



return {
    title = '����������� ����� ���������� ���� && ����� RGB ����� ��� ��������',
    code = 'sel_color',
    statusbar = Init,
}