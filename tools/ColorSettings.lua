require'lpeg'
local patt
do
    local P, V, Cg, Ct, Cc, S, R, C, Carg, Cf, Cb, Cp, Cmt = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.S, lpeg.R, lpeg.C, lpeg.Carg, lpeg.Cf, lpeg.Cb, lpeg.Cp, lpeg.Cmt
    local cmnt = P'#' * P' '^0 * Cg(C((1 - S'\n\r')^1), 'comment') * S'\r\n'^- 2 *#(P' '^0 * P'style.' + P'colour.' + P'font.')
    local sep = P' '^0 * P',' * P' '^0
    local reffont = #(P'$(font.') * P'$(' * Cg(C((1 - P')')^1), 'reffont') * P')'
    local refcolour = #(P'$(colour.') * P'$(' * Cg(C((1 - P')')^1), 'refcolour') * P')'
    local refstyle = #(P'$(style.') * P'$(' * Cg(C((1 - P')')^1), 'refstyle') * P')'

    local hex = R('09', 'af', 'AF')
    local clr = C(P'#' * hex * hex * hex * hex * hex * hex)
    local back = P'back:' * Cg(clr, 'back')
    local fore = P'fore:' * Cg(clr, 'fore')
    local bold = Cg(C(P'not'^- 1 * P'bold'), 'bold')
    local italics = Cg(C(P'not'^- 1 * P'italics'), 'italics')
    local eolfilled = Cg(C(P'not'^- 1 * P'eolfilled'), 'eolfilled')
    local underlined = Cg(C(P'not'^- 1 * P'underlined'), 'underlined')
    local visible = Cg(C(P'not'^- 1 * P'visible'), 'visible')
    local changeable = Cg(C(P'not'^- 1 * P'changeable'), 'changeable')
    local hotspot = Cg(C(P'not'^- 1 * P'hotspot'), 'hotspot')
    local font = P'font:' * Cg(C((1 - S',\r\n')^1), 'font')
    local size = P'size:' * Cg(C(R'09'^1), 'size')
    local case = P'case:' * Cg(C(R'ul'), 'case')

    local val = P{reffont + refcolour + refstyle + back + fore + bold + italics + eolfilled +
    font + size + case + underlined + visible + changeable + hotspot + sep * V(1)}^1
    local body = P' '^0 *#(P'style.' + P'colour.' + P'font.') * Cg(C((1 - S'=')^1), 'name') * P'=' * val^-1

    patt = Ct(P{Ct((cmnt + P'\n') * body) + 1 * V(1)}^1)

end

local containers = {}
local tblColours, dlg, strText, mLst, tblLexers, tblView, tblGlobal, curentRow
local tblRefFnt, tblRefClr, tblRefStl
local reloadLex, fillControls

local function Ctrl(s)
    return iup.GetDialogChild(containers[2], s)
end

local function OnSaveClr(bClouse)
    local tblOut ={}
    local s
    for i = 1,  #tblView do
        local t = tblView[i]
        s = ''

        if t.refstyle   then s = s..',$('..t.refstyle..')' end
        if t.refcolour  then s = s..',$('..t.refcolour..')' end
        if t.reffont    then s = s..',$('..t.reffont..')' end
        if t.font       then s = s..',font:'..t.font end
        if t.size       then s = s..',size:'..t.size end
        if t.back       then s = s..',back:'..t.back end
        if t.fore       then s = s..',fore:'..t.fore end
        if t.changeable then s = s..','..t.changeable end
        if t.eolfilled  then s = s..','..t.eolfilled  end
        if t.bold       then s = s..','..t.bold       end
        if t.hotspot    then s = s..','..t.hotspot    end
        if t.visible    then s = s..','..t.visible    end
        if t.underlined then s = s..','..t.underlined end
        if t.italics    then s = s..','..t.italics    end
        if t.case       then s = s..',case:'.. t.case end
        if #s > 0 then s = s:sub(2) end
        s = t.name..'='..s
        if t.comment then s = '#'..t.comment..'\n'..s end
        table.insert(tblOut, s)
    end
    s = '#Autogenereted\n\n'..table.concat(tblOut, '\n\n')

    local strFName = tblLexers[Ctrl("cmb_switch").valuestring]..'.styles'
    local file = io.output(props["SciteUserHome"]..'\\'..strFName)
    file:write(s)
    file:close()

    if Ctrl("cmb_switch").value ~= '1' then
        local file, err = io.input(props["SciteUserHome"]..'\\Languages.properties')
        local s = file:read('*a')
        file:close()
        --print(s)
        if not s:lower():find(strFName:lower(), 1, true) then
            file = io.output(props["SciteUserHome"]..'\\Languages.properties')
            file:write(s..'\nimport $(scite.userhome)\\'..strFName..'\n')
            file:close()
        end
    end
    scite.Perform("reloadproperties:")
end

local function txt2rgb(txt)
    local _, _, r, g, b = txt:find('(..)(..)(..)')
    return ((('0x'..r) + 0)..' '..(('0x'..g) + 0)..' ' ..(('0x'..b) + 0))
end

local function enrichRow(tSrs, t)
    if not t then
        t = {}
        enrichRow(tblRefStl['style.*.32'], t)
    end
    if tSrs.refstyle  then if tblRefStl[tSrs.refstyle]  then enrichRow(tblRefStl[tSrs.refstyle] , t) else print('Ref not found', tSrs.refstyle) end end
    if tSrs.refcolour then if tblRefClr[tSrs.refcolour] then enrichRow(tblRefClr[tSrs.refcolour], t) else print('Ref not found', tSrs.refcolour) end end
    if tSrs.reffont   then if tblRefFnt[tSrs.reffont]   then enrichRow(tblRefFnt[tSrs.reffont]  , t) else print('Ref not found', tSrs.reffont) end  end
    for p, v in pairs(tSrs) do
        if p ~= 'refstyle' and p ~= 'refcolour' and p ~= 'refcolour' then
            t[p] = v
        end
    end
    return t
end

local function resetExample(tSrs)
    local t = enrichRow(tSrs)
    local c = Ctrl("txt_example")
    c.bgcolor = t.back or iup.GetGlobal("TXTBGCOLOR")
    c.fgcolor = t.fore or '0 0 0'
    local style = ''
    if (t.italics or '') == 'italics' then style = style..'Italic ' end
    if (t.bold or '') == 'bold' then style = style..'Bold ' end
    if (t.underlined or '') == 'underlined' then style = style..'Underline ' end
    c.fontstyle = style
    c.fontsize = t.size or '5'
end

local function tblFromControls()
    local t = {}
    if Ctrl("cmb_reffont").valuestring    ~= '' then t.reffont = Ctrl("cmb_reffont").valuestring    end
    if Ctrl("cmb_refcolour").valuestring  ~= '' then t.refcolour = Ctrl("cmb_refcolour").valuestring  end
    if Ctrl("cmb_refstyle").valuestring   ~= '' then t.refstyle = Ctrl("cmb_refstyle").valuestring   end
    if Ctrl("backcolour").value           ~= '' then t.back = '#'..Ctrl("backcolour").value end
    if Ctrl("forecolour").value           ~= '' then t.fore = '#'..Ctrl("forecolour").value           end
    if Ctrl("cmb_changeable").valuestring ~= '' then t.changeable = Ctrl("cmb_changeable").valuestring end
    if Ctrl("cmb_eolfilled").valuestring  ~= '' then t.eolfilled = Ctrl("cmb_eolfilled").valuestring  end
    if Ctrl("cmb_bold").valuestring       ~= '' then t.bold = Ctrl("cmb_bold").valuestring       end
    if Ctrl("cmb_hotspot").valuestring    ~= '' then t.hotspot = Ctrl("cmb_hotspot").valuestring    end
    if Ctrl("cmb_visible").valuestring    ~= '' then t.visible = Ctrl("cmb_visible").valuestring    end
    if Ctrl("cmb_underlined").valuestring ~= '' then t.underlined = Ctrl("cmb_underlined").valuestring end
    if Ctrl("cmb_italics").valuestring    ~= '' then t.italics = Ctrl("cmb_italics").valuestring    end
    if Ctrl("cmb_case").valuestring       ~= '' then t.case = Ctrl("cmb_case").valuestring       end
    if Ctrl("txt_font").value             ~= '' then t.font = Ctrl("txt_font").value             end
    if Ctrl("lbl_size").title..''         ~= '' then t.size = Ctrl("lbl_size").title         end
    return t
end

local function updateExample()
    resetExample(enrichRow(tblFromControls()))
end

local function create_3pos_list(name)
    local res = iup.list{name = 'cmb_'..name, dropdown = "YES", expand = 'NO', action = updateExample, }
    iup.SetAttribute(res, 1, "")
    iup.SetAttribute(res, 2, name)
    iup.SetAttribute(res, 3, "not"..name)
    return iup.hbox{iup.label{title = name}, iup.fill{}, res, alignment = 'ACENTER'}
end

local function create_case()
    local res = iup.list{name = 'cmb_case', dropdown = "YES", expand = 'NO', action = updateExample, }
    iup.SetAttribute(res, 1, "")
    iup.SetAttribute(res, 2, 'u')
    iup.SetAttribute(res, 3, "l")
    return iup.hbox{iup.label{title = 'case'}, iup.fill{}, res, alignment = 'ACENTER'}
end

local function loadList()
    mLst.numlin = #tblView
    for i = 1, #tblView do
        iup.SetAttributeId(mLst, "", i, tblView[i].name.." #"..(tblView[i].comment or ''))
        iup.SetAttributeId(mLst, "COLOR", i, iup.GetGlobal('TXTBGCOLOR'))

        local t = enrichRow(tblView[i])
        print(t.back)
        iup.SetAttributeId(mLst, "ITEMBGCOLOR", i, t.back or iup.GetGlobal("TXTBGCOLOR"))

        iup.SetAttributeId(mLst, "ITEMFGCOLOR", i, t.fore or '0 0 0')
    end
end

local function ApplyToRow()
    local t = tblFromControls()
    t.name = tblView[curentRow].name
    if tblView[curentRow].comment then t.comment = tblView[curentRow].comment end
    tblView[curentRow] = t
    loadList()
    mLst.listaction_cb(mLst, curentRow, 1)
end

local function create_colour_bar(name)
    local function onClr(h)
        local _, _, r, g, b = h.rgb:find('([0-9]+) ([0-9]+) ([0-9]+)')
        Ctrl(name).value = (string.format('%02x', r)..string.format('%02x', g)..string.format('%02x', b)):upper()
        updateExample()
    end
    local function onTxt(h)
        local c = h.caret
        if h.value:len() < 6 then
            h.value = h.value..string.rep('0', 6 - h.value:len())
        elseif h.value:len() > 6 then
            h.value = h.value:gsub('(......).*', '%1')
        end;
        h.caret = c
        Ctrl("colour_"..name).rgb = txt2rgb(h.value)
        updateExample()
    end
    local txtClr = iup.text{
        size = "40x0",
        mask = "[A-Fa-f0-9]*",
        value = 'FF0000',
        valuechanged_cb = onTxt,
        name = name,
        action = function(h,c, new_value) if c >= 97 and c <= 102 then return c - 32 end end
    }
    txtClr.SetValue = function(val)
        if not val then
            txtClr.value = nil
            Ctrl("chk_"..name).value = 'OFF'
            txtClr.active = 'NO'
            Ctrl("colour_"..name).active = 'NO'
            Ctrl("colour_"..name).rgb = txt2rgb('FF0000')
        else
            val = val:gsub('#', '')
            Ctrl("chk_"..name).value = 'ON'
            txtClr.active = 'YES'
            Ctrl("colour_"..name).active = 'YES'
            txtClr.value = val
            Ctrl("colour_"..name).rgb = txt2rgb(val)
        end
    end
    local res = iup.frame{

        iup.vbox{
            iup.colorbrowser{
                bgcolor = "240 240 240",
                rastersize = "181x181",
                border = "NO",
                name = "colour_"..name,
                valuechanged_cb = onClr,
            },
            iup.hbox{
                iup.label{title = name},
                iup.toggle{
                    name = "chk_"..name,
                    action = function(h)
                        if h.value == 'ON' then
                            Ctrl(name).SetValue('FF0000')
                        else
                            Ctrl(name).SetValue(nil)
                        end
                        updateExample()
                    end
                },
                txtClr,
                alignment = "ACENTER"
            }
        }
    }
    return res
end

local function create_dialog_clr()

    containers[7] = iup.hbox{

        iup.button{
            size = "50x0",
            title = "Apply To Row",
            action = ApplyToRow,
        },
        iup.fill{},
        iup.button{
            size = "50x0",
            title = "Save Styles",
            name = 'LCOLOR_BTN_OK',
            action = OnSaveClr,
        },
        iup.button{
            size = "50x0",
            title = "Close",
            name = "LCOLOR_BTN_ESC",
            action = (function() dlg:postdestroy() end)
        },
    }

    containers[3] = iup.vbox{name = 'v_right',
        iup.hbox{alignment = 'ACENTER',
            iup.label{title = 'Select Lexer:'},
            iup.list{
                dropdown = "YES",
                name = 'cmb_switch',
                map_cb = function(h)
                    tblLexers = {}
                    tblLexers['GLOBAL'] = "SciTEGlobal"
                    iup.SetAttribute(h, 1, "GLOBAL")

                    local tblLex = _G.iuprops['settings.lexers'] or {}
                    for i = 1, #tblLex do
                        iup.SetAttribute(h, i + 1, tblLex[i].view)
                        tblLexers[tblLex[i].view] = tblLex[i].file:gsub('%.properties$', '')
                    end

                    h.value = 1
                    h.visibleitems = #tblLex
                end,
                action = reloadLex
            },
        },
        iup.fill{},
        iup.text{name = 'txt_example', multiline = 'YES', wordwrap = 'YES', autohide = 'YES', size = '220x30', expand = 'NO'},
        iup.hbox{alignment = 'ACENTER', gap = 3,
            iup.label{title = 'Used Font:', size='50x'},
            iup.list{
                dropdown = "YES",
                name = 'cmb_reffont',
                sort = 'YES',
                size = '100x',
                visibleitems  = '20',
            },
        },
        iup.hbox{alignment = 'ACENTER', gap = 3,
            iup.label{title = 'Used Colour:', size = '50x'},
            iup.list{
                dropdown = "YES",
                name = 'cmb_refcolour',
                sort = 'YES',
                size = '100x',
                visibleitems = '20',
            },
        },
        iup.hbox{alignment = 'ACENTER', gap = 3,
            iup.label{title = 'Used Style:', size='50x'},
            iup.list{
                dropdown = "YES",
                name = 'cmb_refstyle',
                sort = 'YES',
                size = '100x',
                visibleitems  = '20',
            },
        },
        iup.hbox{
            create_colour_bar("forecolour"),
            create_colour_bar("backcolour"),
            sort = 'YES',
        },
        iup.hbox{
            iup.flatbutton{name = 'btn_font', title = 'Font', flat_action = function()
                local dlg = iup.fontdlg{ parentdialog = 'SCITE'}
                local f = Ctrl('txt_font').value
                if f ~= '' then dlg.value = f..', '..math.floor(Ctrl('val_size').value) end
                dlg:popup()
                if dlg.status == '1' then
                    local _, _, f = dlg.value:find('([^,]*)')
                    Ctrl('txt_font').value = f
                    updateExample()
                end
            end},
            iup.text{name = 'txt_font', readonly = 'YES', size = '100x'},
            iup.val{name = 'val_size', min = 0, max = 25, step = 0.04, valuechanged_cb = function(h)
                local v = math.floor(h.value)
                if v == 0 then v = '' end
                Ctrl('lbl_size').title = v
                updateExample()
            end},
            iup.label{name = 'lbl_size', size = '20x'}

        },
        iup.hbox{
            iup.vbox{
                create_3pos_list("italics"),
                create_3pos_list("underlined"),
                create_3pos_list("visible"),
                create_3pos_list("hotspot"),
            },
            iup.vbox{
                create_3pos_list("bold"),
                create_3pos_list("eolfilled"),
                create_3pos_list("changeable"),
                create_case()
            }
        },
        containers[7],
        expand = "YES",
    }

    containers[5] = iup.vbox{
        iup.matrixlist{
            expand = "YES",
            columnorder = "COLOR:LABEL",
            frametitlehighlight = "No",
            numcol = "1",
            ["height0"] = "0",
            numlin = "20",
            editable = 'NO',
            --scrollbar = "ALL",
            ["rasterwidth0"] = "0",
            ["rasterwidth1"] = "100",
            ["rasterwidth2"] = "200",
            numlin_visible = "10",
            name = "matrixList",
            listaction_cb = function(h, item, state)
                if state == 1 then
                    iup.SetAttributeId(h, "COLOR", item, '0 0 0')
                    h.focuscolor = iup.GetAttributeId(h, "ITEMBGCOLOR", item) or iup.GetGlobal('TXTBGCOLOR')
                    h.redraw = 'ALL'
                    fillControls(item)
                    curentRow = item
                else
                    iup.SetAttributeId(h, "COLOR", item, iup.GetGlobal('TXTBGCOLOR'))
                end
            end,
            listedition_cb = function() return iup.IGNORE end
        },
        expand = "YES",
    }

    containers[2] = iup.hbox{
        containers[5],
        containers[3],
    }

    return containers[2]
end

local function tblFromFile(strName)
    if not shell.fileexists(strName) then return end
    local tmpF = io.input(strName)
    if not tmpF then return end
    strText = tmpF:read('*a')
    tmpF:close()
    local t = patt:match(strText, 1)
    local tout = {}

    return t
end

local function LexerColors()

    local cont = create_dialog_clr()
    mLst = Ctrl("matrixList")

    iup.SetHandle("LCOLOR_BTN_ESC", Ctrl('LCOLOR_BTN_ESC'))
    dlg = iup.scitedialog{cont,
        maxbox = "NO",
        title = "Colours and Fonts",
        defaultesc = "LCOLOR_BTN_ESC",
        resize = "YES",
        minbox = "NO",
        shrink = "YES",
        sciteparent = "SCITE",
        sciteid = "lexerColors",
        gap = '3',
        margin = '3x3',
        expandchildren = 'YES',
        minsize = '800x740',
        show_cb = function(h, state)
            if state == 4 then
                dlg:postdestroy()
            end
        end
    }

    dlg.resize_cb = function(h)
        local _, _, w = dlg.rastersize:find('(.*)x')
        local _, _, w2 = Ctrl('v_right').rastersize:find('(.*)x')
        Ctrl("matrixList").rasterwidth1 = 70
        Ctrl("matrixList").rasterwidth2 = tonumber(w) - tonumber(w2) - 100
        Ctrl("matrixList").fittosize = 'COLUMNS'
    end
    dlg.resize_cb()
end

fillControls = function(idx)
    if not tblView then return end
    local tSel = tblView[idx]
    Ctrl("backcolour").SetValue(tSel.back)
    Ctrl("forecolour").SetValue(tSel.fore)
    Ctrl("cmb_refcolour").valuestring = tSel.refcolour or ''
    Ctrl("cmb_refstyle").valuestring = tSel.refstyle or ''
    Ctrl("cmb_reffont").valuestring = tSel.reffont or ''

    Ctrl("cmb_changeable").valuestring = tSel.changeable or ''
    Ctrl("cmb_eolfilled").valuestring = tSel.eolfilled or ''
    Ctrl("cmb_bold").valuestring = tSel.bold or ''
    Ctrl("cmb_hotspot").valuestring = tSel.hotspot or ''
    Ctrl("cmb_visible").valuestring = tSel.visible or ''
    Ctrl("cmb_underlined").valuestring = tSel.underlined or ''
    Ctrl("cmb_italics").valuestring = tSel.italics or ''
    Ctrl("cmb_case").valuestring = tSel.case or ''

    Ctrl("txt_font").value = tSel.font or ''
    Ctrl("val_size").value = tSel.size or 0
    Ctrl("lbl_size").title = tSel.size or ''
    --Ctrl("txt_example").fontstyle = "Bold"
    Ctrl("txt_example").value = mLst.value
    resetExample(tSel)
end

reloadLex = function()
    local function fillLst(c, t)
        c.removeitem = 'ALL'
        c.appenditem = ''
        for n, _ in pairs(t) do
            c.appenditem = n
        end
        c.value = 1
    end

    tblGlobal = tblFromFile(props["SciteUserHome"]..'\\SciTEGlobal.styles')
    if not tblGlobal then tblGlobal = tblFromFile(props["SciteDefaultHome"]..'\\SciTEGlobal.properties') end
    if Ctrl("cmb_switch").valuestring == "GLOBAL" then
        tblView = tblGlobal
    else
        tblView = tblFromFile(props["SciteUserHome"]..'\\'..tblLexers[Ctrl("cmb_switch").valuestring]..'.styles')
        if not tblView then tblView = tblFromFile(props["SciteDefaultHome"]..'\\languages\\'..tblLexers[Ctrl("cmb_switch").valuestring]..'.properties') end
    end
    tblRefStl, tblRefClr, tblRefFnt = {}, {}, {}
    for i = 1,  #tblView do
        if tblView[i].name:find('^font.') then
            tblRefFnt[tblView[i].name] = tblView[i]
        elseif tblView[i].name:find('^colour.') then
            tblRefClr[tblView[i].name] = tblView[i]
        else
            tblRefStl[tblView[i].name] = tblView[i]
        end
    end

    if tblView ~= tblGlobal then
        for i = 1,  #tblGlobal do
            if tblGlobal[i].name:find('^font.') then
                tblRefFnt[tblGlobal[i].name] = tblGlobal[i]
            elseif tblGlobal[i].name:find('^colour.') then
                tblRefClr[tblGlobal[i].name] = tblGlobal[i]
            else
                tblRefStl[tblGlobal[i].name] = tblGlobal[i]
            end
        end
    end

    fillLst(Ctrl("cmb_refcolour"), tblRefClr)
    fillLst(Ctrl("cmb_reffont"), tblRefFnt)
    fillLst(Ctrl("cmb_refstyle"), tblRefStl)

    loadList()
    mLst.listaction_cb(mLst, 1, 1)
end

LexerColors()
reloadLex()
