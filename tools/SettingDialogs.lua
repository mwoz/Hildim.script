local sett = {}
function sett.ResetWrapProps()
	local ret, style, flag, loc, mode, indent, keys =
                    iup.GetParam(_T"Wrap Line Settings".."^WrapSettings",
					nil,
					_T'Wrap by:%l|Word Boundaries|Any Charactersó|Whitespaces|\n'..
					_T'Visual Flags-Draw:%l|No|At Begining|At End|At Begining and End|In Line Number|Line Number and End|Line Number and Begining|All|\n'..
					_T'Visual Flags-In Line:%l|All Near Border|At End - Near Text|At Begining - Near Text|All - Near Text|\n'..
					_T'Wrapped sublines aligned to%l|Left of Window|First Subline Indent|First Subline Indent + 1 level|\n'..
					_T'Wraped Line Indent:'..'%i[1,10,1]\n'..
					_T'<Home>,<End> up to Nearest Wraped up Line'..' %b\n',
                   (tonumber(props['wrap.style']) or 1) - 1,
                    tonumber(props['wrap.visual.flags']) or 0,
                    tonumber(props['wrap.visual.flags.location']) or 0,
                    tonumber(props['wrap.indent.mode']) or 0,
                    tonumber(props['wrap.visual.startindent']) or 0,
                    tonumber(props['wrap.aware.home.end.keys']) or 0
    )
	if ret then
        props['wrap.style'] = style + 1
        props['wrap.visual.flags'] = flag
        props['wrap.visual.flags.location'] = loc
        props['wrap.indent.mode'] = mode
        props['wrap.visual.startindent'] = indent
        props['wrap.aware.home.end.keys'] = keys
        iup.SaveChProps(true)
        editor.WrapMode = style + 1
	end
end

function sett.ResetSelColors()
    local function Rgb2Str(strrgb)
        local rgb = tonumber((strrgb or '#000000'):gsub('#', ''), 16)
        return ''..((rgb >> 16) & 255)..' '..((rgb >> 8) & 255)..' '..(rgb & 255)
    end
    local function Str2Rgb(s, def)
        local _, _, r, g, b = s:find('(%d+) (%d+) (%d+)')
        local rgb = 0
        if r then
            rgb = (r << 16)|(g << 8)|b
        end
        return '#'..string.format('%06X', rgb)
    end
    local ret, selection_back, selection_alpha, selection_additional_back, selection_additional_alpha, caret_line_back, caret_line_back_alpha,
    output_caret_line_back, output_caret_line_back_alpha, findres_caret_line_back, findres_caret_line_back_alpha =
    iup.GetParam(_T"Text Colors - Selection".."^TextColorsSelection",
        nil,
        _T'Selected Text - Color'..'%c\n'..
        _T'- transparency'..'%i[0,255,1]\n'..
        _T'Selected Block - Color'..'%c\n'..
        _T'- transparency'..'%i[0,255,1]\n'..
        _T'Line Containing Caret - Color'..'%c\n'..
        _T'- transparency'..'%i[0,255,1]\n'..
        _T'Output - Line Containing Caret - Color'..'%c\n'..
        _T'- transparency'..'%i[0,255,1]\n'..
        _T'Search Results - Line Containing Caret - Color'..'%c\n'..
        _T'- transparency'..'%i[0,255,1]\n'
        ,
        Rgb2Str(props['selection.back']),
        tonumber(props['selection.alpha']) or 30,
        Rgb2Str(props['selection.additional.back']),
        tonumber(props['selection.additional.alpha']) or 30,
        Rgb2Str(props['caret.line.back']),
        tonumber(props['caret.line.back.alpha']) or 20,
        Rgb2Str(props['output.caret.line.back']),
        tonumber(props['output.caret.line.back']) or 20,
        Rgb2Str(props['findres.caret.line.back']),
        tonumber(props['findres.caret.line.back.alpha']) or 20
    )
    if ret then

        props['selection.back']                = Str2Rgb(selection_back)
        props['selection.alpha']               = selection_alpha
        props['selection.additional.back']     = Str2Rgb(selection_additional_back)
        props['selection.additional.alpha']    = selection_additional_alpha
        props['caret.line.back']               = Str2Rgb(caret_line_back)
        props['caret.line.back.alpha']         = caret_line_back_alpha
        props['output.caret.line.back']        = Str2Rgb(output_caret_line_back)
        props['output.caret.line.back.alpha']  = output_caret_line_back_alpha
        props['findres.caret.line.back']       = Str2Rgb(findres_caret_line_back)
        props['findres.caret.line.back.alpha'] = findres_caret_line_back_alpha

        scite.Perform("reloadproperties:")
    end
end

function sett.ResetFontSize()
	local ret, size = iup.GetParam(_T"Interface Font".."^InterfaceFontSize",
					function(h,i) if i == -1 and tonumber(iup.GetParamParam(h,0).value) < 5 then return 0 end return 1 end,
					_T'Size'..'%i[5,19,1]\n', tonumber(props['iup.defaultfontsize']) or 9)
	if ret then
		props['iup.defaultfontsize'] = size
		if 1 == iup.Alarm(_T'Interface Font', _T'Restart HildiM to apply the changes?', _TH"Yes", _TH"No") then
            scite.SetRestart('')
            scite.RunAsync(function() scite.MenuCommand(IDM_QUIT) end)
        end
	end
end

function sett.SetFindresCount()
	local ret, size = iup.GetParam(_T"Strore Search Results",
					function(h,i) if i == -1 and tonumber(iup.GetParamParam(h,0).value) < 3 then return 0 end return 1 end,
					_T'Not Longer then'..'%i[1,30,1]\n', tonumber(_G.iuprops['findres.maxresultcount']) or 10)
	if ret then
		_G.iuprops['findres.maxresultcount'] = size
	end
end

function sett.ResetTabbarProps()
    local function oldClr(p, def)
        local c = props[p]
        if c == '' then c = def end
        return c
    end

    local ret, ondbl, buff, zord, newpos, setbegin, coloriz, illum, satur, cEx, cPref,
    tabctrl_forecolor, ROColor, tabctrl_active_bakcolor, tabctrl_active_forecolor, tabctrl_active_readonly_forecolor, tabctrl_moved_color, opencmd
    = iup.GetParam(_T"Tabbar Preferenses".."^TabbarProperties",
            function(h, id)
                local bact = Iif(iup.GetParamParam(h, 5).control.value == 'ON', 'YES', 'NO')
                iup.GetParamParam(h, 6).control.active = bact
                iup.GetParamParam(h, 7).control.active = bact
                iup.GetParamParam(h, 6).auxcontrol.active = bact
                iup.GetParamParam(h, 7).auxcontrol.active = bact
                iup.GetParamParam(h, 8).control.active = bact
                local bext = Iif(iup.GetParamParam(h, 8).control.value == 'ON' and bact == 'YES', 'YES', 'NO')
                iup.GetParamParam(h, 9).control.active = bext
                return 1
            end,
        _T'Close with DblClick'..'%b\n'..
        _T'Maximum Tabs Amount:'..'%i[10,500,1]\n'..
        _T'Switching in Order of Usage'..'%b\n'..
        _T'Open New Tab%l|At End of List|After Current|At Begining of List|'..'%b\n'..
        _T'Move Active Tab To Begining'..'%b\n'..
        _T'Inactive Tabs'..'%t\n'..
        _T'Highlight by Extension'..'%b\n'..
        _T'Saturation:'..'%i[10,99,1]\n'..
        _T'Intensity:'..'%i[10,99,1]\n'..
        _T'Hide Extension'..'%b\n'..
        _T'Hide Prefix'..'%b\n'..
        _T'Foreground'..'%c\n'..
        _T'Foreground Read-Only'..'%c\n'..
        _T'Active Tab'..'%t\n'..
        _T'Background'..'%c\n'..
        _T'Foreground'..'%c\n'..
        _T'Foreground Read-Only'..'%c\n'..
        _T'Draged-and-Droped'..' %c\n'..
        _T'Command line for "Open File Folder"'..'%t\n'..
        _T'Use %%P as folder path placeholder'..'%s\n'
        ,
        tonumber(props['tabbar.tab.close.on.doubleclick']) or 0,
        tonumber(props['buffers']) or 100,
        tonumber(props['buffers.zorder.switching']) or 0,
        tonumber(props['buffers.new.position']) or 0,
        ((tonumber(props['tabctrl.alwayssavepos']) or 0) + 1) % 2,
        tonumber(props['tabctrl.colorized']) or 0,
        tonumber(props['tabctrl.cut.illumination']) or 90,
        tonumber(props['tabctrl.cut.saturation']) or 50,
        tonumber(props['tabctrl.cut.ext']) or 0,
        tonumber(props['tabctrl.cut.prefix']) or 0,
        oldClr('tabctrl.forecolor' , '0 0 0'),
        oldClr('tabctrl.readonly.color' , '120 120 120'),
        oldClr('tabctrl.active.bakcolor' , '255 255 255'),
        oldClr('tabctrl.active.forecolor' , '0 0 255'),
        oldClr('tabctrl.active.readonly.forecolor' , '120 120 255'),
        oldClr('tabctrl.moved.color' , '120 120 255'),
        _G.iuprops['settings.tabmenu.opencmd'] or 'explorer "%P"'
    )
    if ret then
        props['tabbar.tab.close.on.doubleclick'] = ondbl
        props['buffers'] = buff
        props['buffers.zorder.switching'] = zord
        props['buffers.new.position'] = newpos
        props['tabctrl.alwayssavepos'] = (setbegin + 1) % 2
        props['tabctrl.colorized'] = coloriz
        props['tabctrl.cut.illumination'] = illum
        props['tabctrl.cut.saturation'] = satur
        props['tabctrl.cut.ext'] = cEx
        props['tabctrl.cut.prefix'] = cPref
        props['tabctrl.readonly.color'] = ROColor
        props['tabctrl.forecolor'] = tabctrl_forecolor
        props['tabctrl.active.bakcolor'] = tabctrl_active_bakcolor
        props['tabctrl.active.forecolor'] = tabctrl_active_forecolor
        props['tabctrl.active.readonly.forecolor'] = tabctrl_active_readonly_forecolor
        props['tabctrl.moved.color'] = tabctrl_moved_color
        _G.iuprops['settings.tabmenu.opencmd'] = opencmd

        iup.GetDialogChild(iup.GetLayout(), 'TabCtrlLeft').showclose = Iif((tonumber(props['tabbar.tab.close.on.doubleclick']) or 0) == 1, 'NO', 'YES')
        iup.GetDialogChild(iup.GetLayout(), 'TabCtrlRight').showclose = Iif((tonumber(props['tabbar.tab.close.on.doubleclick']) or 0) == 1, 'NO', 'YES')
        iup.Redraw(iup.GetDialogChild(iup.GetLayout(), 'TabCtrlRight'), 1)
        iup.Redraw(iup.GetDialogChild(iup.GetLayout(), 'TabCtrlLeft'), 1)
        scite.BlockUpdate(UPDATE_FORCE)
    end
end

function sett.ResetGlobalColors()

    local ret, bgcolor, txtbgcolor, fgcolor, txtfgcolor, txthlcolor, txtinactivcolor, hlcolor, borderhlcolor, bordercolor,
    splittercolor, scroll_forecolor , scroll_presscolor, scroll_highcolor , scroll_backcolor
    = iup.GetParam(_T"Main Window Colors".."^MainWindowColor",
        nil,
        _T'Bar Background'..'%c\n'..
        _T'Edited Controls Background'..'%c\n'..
        _T'Bar Foreground'..'%c\n'..
        _T'Edited Controls Foreground'..'%c\n'..
        _T'Highlighted Menu Item'..'%c\n'..
        _T'Inactive Text Foreground'..'%c\n'..
        _T'Control Highlight'..'%c\n'..
        _T'Highlighted Control Border'..'%c\n'..
        _T'Control Border'..'%c\n'..
        _T'Splitters'..'%c\n'..
        _T'Scrollbar Slider'..'%c\n'..
        _T'Scrollbar Slider - Pressed'..'%c\n'..
        _T'Scrollbar Slider - Highlighted'..'%c\n'..
        _T'Scrollbar Background'..'%c\n'
        ,
        props['layout.bgcolor']          ,
        props['layout.txtbgcolor']       ,
        props['layout.fgcolor']          ,
        props['layout.txtfgcolor']       ,
        props['layout.txthlcolor']       ,
        props['layout.txtinactivcolor']  ,
        props['layout.hlcolor']          ,
        props['layout.borderhlcolor']    ,
        props['layout.bordercolor']      ,
        props['layout.splittercolor']    ,
        props['layout.scroll.forecolor'] ,
        props['layout.scroll.presscolor'],
        props['layout.scroll.highcolor'] ,
        props['layout.scroll.backcolor']
    )
    if ret then

        props['layout.hlcolor']           = hlcolor
        props['layout.borderhlcolor']     = borderhlcolor
        props['layout.bgcolor']           = bgcolor
        props['layout.txtbgcolor']        = txtbgcolor
        props['layout.fgcolor']           = fgcolor
        props['layout.txtfgcolor']        = txtfgcolor
        props['layout.txthlcolor']        = txthlcolor
        props['layout.txtinactivcolor']   = txtinactivcolor
        props['layout.bordercolor']       = bordercolor
        props['layout.splittercolor']     = splittercolor
        props['layout.scroll.forecolor']  = scroll_forecolor
        props['layout.scroll.presscolor'] = scroll_presscolor
        props['layout.scroll.highcolor']  = scroll_highcolor
        props['layout.scroll.backcolor']  = scroll_backcolor

        if 1 == iup.Alarm(_T'Interface Color', _T'Restart HildiM to apply the changes?', _TH"Yes", _TH"No") then
            scite.SetRestart('  -cmd scite.RunAsync(CORE.ResetGlobalColors)')
            scite.RunAsync(function() scite.MenuCommand(IDM_QUIT) end)
        end
    end

end

function sett.CurrentTabSettings()
    local ret, TabWidth, Indent, UseTabs =
    iup.GetParam(_T"Tab Preferenses".."^CurrentTabSettings",
        nil,
        _T'Tab Size'..'%i[2,16,1]\n'..
        _T'Indentation Size'..'%i[2,16,1]\n'..
        _T'Use Tab'..'%b\n'
        ,
        editor.TabWidth,
        editor.Indent,
        Iif(editor.UseTabs, 1, 0)
    )
    if ret then

        editor.TabWidth = TabWidth
        editor.Indent   = Indent
        editor.UseTabs  = (UseTabs ~= 0)
    end
end

function sett.AutoScrollingProps()
    local ret,
    caret_policy_xslop, caret_policy_width, caret_policy_xstrict, caret_policy_xjumps, caret_policy_xeven,
    caret_policy_yslop, caret_policy_lines, caret_policy_ystrict, caret_policy_yjumps, caret_policy_yeven,
    caret_sticky, end_at_last_lin, iup_scrollbarsize
    = iup.GetParam(_T"Autoscroll Preferenses".."^AutiscrollSettings",
        nil,
        _T'Horizontal Autoscroll'..'%t\n'..

        _T'Unwanted Zone (UZ)'..'%b\n'..
        _T'UZ Width, px'..'%i[1,500,20]\n'..
        _T'UZ - Enforce Strictly'..'%b\n'..
        _T'Autoscroll for 3 UZ'..'%b\n'..
        _T'Asymmetric UZ'..'%b\n'..

        _T'Vertical Autoscroll'..'%t\n'..

        _T'Unwanted Zone (UZ)'..'%b\n'..
        _T'UZ Height, lines'..'%i[1,500,20]\n'..
        _T'UZ - Enforce Strictly'..'%b\n'..
        _T'Autoscroll for 3 UZ'..'%b\n'..
        _T'Asymmetric UZ'..'%b\n'..

        '%t\n'..
        _T'Save Horizontal Position'..'%b\n'..
        _T'Maximum Vertical Scroll Position'..'%t\n'..
        _T'Page Below Last Line'..'%b\n'..
        '%t\n'..
        _T'Scrollbar Size'..'%i[11,21,1]\n'
        ,
        tonumber(props['caret.policy.xslop']) or 0,
        tonumber(props['caret.policy.width']) or 0,
        tonumber(props['caret.policy.xstrict']) or 0,
        tonumber(props['caret.policy.xeven']) or 0,
        tonumber(props['caret.policy.xjumps']) or 0,

        tonumber(props['caret.policy.yslop']) or 0,
        tonumber(props['caret.policy.lines']) or 0,
        tonumber(props['caret.policy.ystrict']) or 0,
        tonumber(props['caret.policy.yeven']) or 0,
        tonumber(props['caret.policy.yjumps']) or 0,

        tonumber(props['caret.sticky']) or 0,

        tonumber(props['end.at.last.line']) or 0,
        tonumber(props['iup.scrollbarsize'])
    )
    if ret then
        props['caret.policy.xslop']    = caret_policy_x
        props['caret.policy.width']    = caret_policy_width
        props['caret.policy.xstrict']  = caret_policy_xstrict
        props['caret.policy.xeven']    = caret_policy_xeven
        props['caret.policy.xjumps']   = caret_policy_xjumps

        props['caret.policy.yslop']    = caret_policy_yslop
        props['caret.policy.lines']    = caret_policy_lines
        props['caret.policy.ystrict']  = caret_policy_ystrict
        props['caret.policy.yeven']    = caret_policy_yeven
        props['caret.policy.yjumps']   = caret_policy_yjumps

        props['caret.sticky']          = caret_sticky

        props['end.at.last.line'] = end_at_last_lin
        scite.ReloadProperties()
        if iup_scrollbarsize ~= tonumber(props['iup.scrollbarsize']) then
            if 1 == iup.Alarm(_T'Autoscroll Preferenses', _T'Restart HildiM to apply the changes?', _TH"Yes", _TH"No") then
                props['iup.scrollbarsize'] = iup_scrollbarsize
                scite.SetRestart('')
                scite.RunAsync(function() scite.MenuCommand(IDM_QUIT) end)
            end
        end
    end
end

function sett.Colors_Work()
    props["tabctrl.active.bakcolor"] = "255 255 255"
    props["tabctrl.active.forecolor"] = "0 0 255"
    props["tabctrl.active.readonly.forecolor"] = "120 120 255"
    props["tabctrl.cut.illumination"] = "90"
    props["tabctrl.cut.saturation"] = "50"
    props["tabctrl.moved.color"] = "213 213 254"
    props["tabctrl.moved.color"] = "213 213 254"
    props["tabctrl.readonly.color"] = "120 120 120"
    props["layout.hlcolor"] = "200 225 245"
    props["layout.borderhlcolor"] = "50 150 255"
    props["layout.bordercolor"] = "178 22 22"
    props["layout.bgcolor"] = "120 212 139"
    props["layout.txtbgcolor"] = "243 252 255"
    props["layout.fgcolor"] = "206 0 0"
    props["layout.txtfgcolor"] = "216 112 255"
    props["layout.txthlcolor"] = "15 60 195"
    props["layout.txtinactivcolor"] = "177 97 97"
    props["layout.bordercolor"] = "178 22 22"
    props["layout.scroll.forecolor"] = "126 174 209"
    props["layout.scroll.presscolor"] = "42 115 168"
    props["layout.scroll.highcolor"] = "65 139 193"
    props["layout.scroll.backcolor"] = "240 240 240"
    scite.SetRestart('')
    scite.RunAsync(function() scite.MenuCommand(IDM_QUIT) end)
end

function sett.CreateColorSettings()
    local d = iup.filedlg{dialogtype = 'SAVE', parentdialog = 'SCITE', extfilter = 'Colors|*.colors;', directory = props["scite.userhome"].."\\" }
    d:popup()
    local filename = d.value
    d:destroy()
    if not filename then return end
    if not filename:find('%.colors$') then filename = filename..'.colors' end
    local fields = {
'tabctrl.active.bakcolor',
'tabctrl.active.forecolor',
'tabctrl.active.readonly.forecolor',
'tabctrl.cut.illumination',
'tabctrl.cut.saturation',
'tabctrl.forecolor',
'tabctrl.readonly.color',
'tabctrl.moved.color',
'tabctrl.readonly.color',
'layout.hlcolor',
'layout.borderhlcolor',
'layout.bordercolor',
'layout.bgcolor',
'layout.txtbgcolor',
'layout.fgcolor',
'layout.txtfgcolor',
'layout.txthlcolor',
'layout.txtinactivcolor',
'layout.splittercolor',
'layout.scroll.forecolor',
'layout.scroll.presscolor',
'layout.scroll.highcolor',
'layout.scroll.backcolor',
    }

    local strOut = ''
    for i = 1,  #fields do
        strOut = strOut..'props["'..fields[i]..'"] = "'..props[fields[i]]..'"\n'
    end
    strOut = strOut..[[
    scite.SetRestart('')
    scite.RunAsync(function() scite.MenuCommand(IDM_QUIT) end)
    ]]
    if pcall(io.output, filename) then
        io.write(strOut)
        io.close()
    end
end

function sett.ApplyColorsSettings()
    local d = iup.filedlg{dialogtype = 'OPEN', parentdialog = 'SCITE', extfilter = 'Colors|*.colors;', directory = props["scite.userhome"].."\\" }
    d:popup()
    local filename = d.value
    d:destroy()
    if not filename then return end
    local bSuc, pF = pcall(io.input, filename)
    if bSuc then
        text = pF:read('*a')
        pF:close()
        assert(load(text))()
    end
end

function sett.Colors_Default()
    props["tabctrl.active.bakcolor"] = "255 255 255"
    props["tabctrl.active.forecolor"] = "90 33 33"
    props["tabctrl.active.readonly.forecolor"] = "111 108 108"
    props["tabctrl.cut.illumination"] = "90"
    props["tabctrl.cut.saturation"] = "50"
    props["tabctrl.forecolor"] = "0 0 0"
    props["tabctrl.moved.color"] = "120 120 255"
    props["tabctrl.readonly.color"] = "120 120 120"
    props["layout.hlcolor"] = "200 225 245"
    props["layout.borderhlcolor"] = "50 150 255"
    props["layout.bordercolor"] = "200 200 200"
    props["layout.bgcolor"] = "240 240 240"
    props["layout.txtbgcolor"] = "255 255 255"
    props["layout.fgcolor"] = "0 0 0"
    props["layout.txtfgcolor"] = "0 0 0"
    props["layout.txthlcolor"] = "15 60 195"
    props["layout.txtinactivcolor"] = "70 70 70"
    props["layout.bordercolor"] = "200 200 200"
    props["layout.splittercolor"] = "220 220 220"
    props["layout.scroll.forecolor"] = "190 190 190"
    props["layout.scroll.presscolor"] = "150 150 150"
    props["layout.scroll.highcolor"] = "170 170 170"
    props["layout.scroll.backcolor"] = "240 240 240"
    scite.SetRestart('')
    scite.RunAsync(function() scite.MenuCommand(IDM_QUIT) end)
end

function sett.Colors_Atrium()
    props["tabctrl.active.bakcolor"] = "255 255 255"
    props["tabctrl.active.forecolor"] = "0 0 255"
    props["tabctrl.active.readonly.forecolor"] = "120 120 255"
    props["tabctrl.colorized"] = "1"
    props["tabctrl.cut.ext"] = "1"
    props["tabctrl.cut.illumination"] = "81"
    props["tabctrl.cut.prefix"] = "1"
    props["tabctrl.cut.saturation"] = "55"
    props["tabctrl.forecolor"] = "0 0 0"
    props["tabctrl.moved.color"] = "213 213 254"
    props["tabctrl.readonly.color"] = "82 82 82"
    props["layout.hlcolor"] = "200 225 245"
    props["layout.borderhlcolor"] = "50 150 255"
    props["layout.bordercolor"] = "221 157 216"
    props["layout.bgcolor"] = "165 211 206"
    props["layout.txtbgcolor"] = "255 255 255"
    props["layout.fgcolor"] = "0 0 0"
    props["layout.txtfgcolor"] = "2 2 2"
    props["layout.txthlcolor"] = "15 60 195"
    props["layout.txtinactivcolor"] = "97 97 97"
    props["layout.bordercolor"] = "221 157 216"
    props["layout.splittercolor"] = "178 223 218"
    props["layout.scroll.forecolor"] = "173 181 211"
    props["layout.scroll.presscolor"] = "81 102 178"
    props["layout.scroll.highcolor"] = "134 148 198"
    props["layout.scroll.backcolor"] = "238 245 244"
    scite.SetRestart('')
    scite.RunAsync(function() scite.MenuCommand(IDM_QUIT) end)
end

function sett.Colors_Darkblue()
    props["tabctrl.active.bakcolor"] = "255 255 255"
    props["tabctrl.active.forecolor"] = "0 0 255"
    props["tabctrl.active.readonly.forecolor"] = "120 120 255"
    props["tabctrl.cut.illumination"] = "28"
    props["tabctrl.cut.saturation"] = "30"
    props["tabctrl.forecolor"] = "255 255 255"
    props["tabctrl.readonly.color"] = "214 214 214"
    props["tabctrl.moved.color"] = "213 213 254"
    props["tabctrl.readonly.color"] = "214 214 214"
    props["layout.hlcolor"] = "94 180 189"
    props["layout.borderhlcolor"] = "51 146 156"
    props["layout.bordercolor"] = "1 148 143"
    props["layout.bgcolor"] = "76 95 129"
    props["layout.txtbgcolor"] = "255 255 255"
    props["layout.fgcolor"] = "255 255 255"
    props["layout.txtfgcolor"] = "0 0 0"
    props["layout.txthlcolor"] = "255 149 239"
    props["layout.txtinactivcolor"] = "183 183 183"
    props["layout.splittercolor"] = "35 63 113"
    props["layout.scroll.forecolor"] = "120 165 125"
    props["layout.scroll.presscolor"] = "61 114 66"
    props["layout.scroll.highcolor"] = "81 139 87"
    props["layout.scroll.backcolor"] = "238 245 244"
    scite.SetRestart('')
    scite.RunAsync(function() scite.MenuCommand(IDM_QUIT) end)
end

return sett
