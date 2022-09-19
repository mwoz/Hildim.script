local sett = {}
function sett.ResetWrapProps()
	local ret, style, flag, loc, mode, indent, keys =
                    iup.GetParam(_T"Wrap Line Settings".."^WrapSettings",
					nil,
					_T'Wrap by:%l|Word Boundaries|Any Charactersó|Whitespaces|\n'..
					_T'Visual Flags-Draw:%l|No|At Beginning|At End|At Beginning and End|In Line Number|Line Number and End|Line Number and Beginning|All|\n'..
					_T'Visual Flags-In Line:%l|All Near Border|At End - Near Text|At Beginning - Near Text|All - Near Text|\n'..
					_T'Wrapped sublines aligned to%l|Left of Window|First Subline Indent|First Subline Indent + 1 level|\n'..
					_T'Wrapped Line Indent:'..'%i[1,10,1]\n'..
					_T'<Home>,<End> up to Nearest Wrapped up Line'..' %b\n',
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
            rgb = (tonumber(r) << 16)|(tonumber(g) << 8)|tonumber(b)
        end
        return '#'..string.format('%06X', rgb)
    end

    local ret, selection_back, selection_alpha, selection_additional_back, selection_additional_alpha, caret_line_back, caret_line_back_alpha,
    output_caret_line_back, output_caret_line_back_alpha, findres_caret_line_back, findres_caret_line_back_alpha,
    caret_fore, caret_width, caret_overstrike, caret_period, caret_additional_blinks =
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
        _T'- transparency'..'%i[0,255,1]\n'..
        _T'Caret'..'%t\n'..

        _T'Color'..'%c\n'..
        _T'Width'..'%i[0,4,1]\n'..
        _T'Rectangle for overtype mode'..'%b\n'..
        _T'Blink Period'..'%i[0,3000,50]\n'..
        _T'Additional Blinks'..'%b\n'
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
        tonumber(props['findres.caret.line.back.alpha']) or 20,
        Rgb2Str(props['caret.fore']),
        tonumber(props['caret.width']) or 1,
        tonumber(props['caret.overstrike.block']) or 0,
        tonumber(props['caret.period']) or 0,
        tonumber(props['caret.additional.blinks']) or 0
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
        props['caret.fore']                    = Str2Rgb(caret_fore)
        props['caret.width']                   = caret_width
        props['caret.overstrike.block']        = caret_overstrike
        props['caret.additional.blinks']       = caret_additional_blinks
        props['caret.period']                  = caret_period
        iup.SaveChProps(true)
        scite.ReloadProperties()
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
	local ret, size = iup.GetParam(_T"Store Search Results",
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
    local prevBuff = (tonumber(props['buffers']) or 100)
    local ret, ondbl, buff, zord, newpos, setbegin, coloriz, illum, satur, cEx, cPref,
    tabctrl_forecolor, ROColor, tabctrl_active_bakcolor, tabctrl_active_forecolor, tabctrl_active_readonly_forecolor, tabctrl_moved_color, opencmd
    = iup.GetParam(_T"Tabbar Preferences".."^TabbarProperties",
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
        _T'Close with Mouse Click%l|None|Left DblClick|Middle Click|Both|'..'\n'..
        _T'Maximum Tabs Amount:'..'%i[10,500,1]\n'..
        _T'Switching in Order of Usage'..'%b\n'..
        _T'Open New Tab%l|At End of List|After Current|At Beginning of List|'..'\n'..
        _T'Move Active Tab To Beginning'..'%b\n'..
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

        iup.GetDialogChild(iup.GetLayout(), 'TabCtrlLeft').showclose = Iif((tonumber(props['tabbar.tab.close.on.doubleclick']) or 0) > 0, 'NO', 'YES')
        iup.GetDialogChild(iup.GetLayout(), 'TabCtrlRight').showclose = Iif((tonumber(props['tabbar.tab.close.on.doubleclick']) or 0) > 0, 'NO', 'YES')
        iup.Redraw(iup.GetDialogChild(iup.GetLayout(), 'TabCtrlRight'), 1)
        iup.Redraw(iup.GetDialogChild(iup.GetLayout(), 'TabCtrlLeft'), 1)
        scite.BlockUpdate(UPDATE_FORCE)
        if prevBuff ~= tonumber(props['buffers']) then
            if 1 == iup.Alarm(_T"Tabbar Preferences", _T'Restart HildiM to apply the changes?', _TH"Yes", _TH"No") then
                scite.SetRestart('')
                scite.RunAsync(function() scite.MenuCommand(IDM_QUIT) end)
            end
        end
    end
end

function sett.ResetGlobalColors()

    local ret, bgcolor, txtbgcolor, fgcolor, txtfgcolor, txthlcolor, txtinactivcolor, hlcolor, borderhlcolor, bordercolor,
    splittercolor, scroll_forecolor , scroll_presscolor, scroll_highcolor , scroll_backcolor, tip_fgcolor, tip_bgcolor
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
        _T'Scrollbar Background'..'%c\n'..
        _T'Tooltip Foreground'..'%c\n'..
        _T'Tooltip Background'..'%c\n'..
        ''
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
        props['layout.scroll.backcolor'] ,
        props['layout.tip.forecolor']    ,
        props['layout.tip.backcolor']
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
        props['layout.tip.forecolor']     = tip_fgcolor
        props['layout.tip.backcolor']     = tip_bgcolor

        if 1 == iup.Alarm(_T'Interface Color', _T'Restart HildiM to apply the changes?', _TH"Yes", _TH"No") then
            scite.SetRestart('  -cmd scite.RunAsync(CORE.ResetGlobalColors)')
            scite.RunAsync(function() scite.MenuCommand(IDM_QUIT) end)
        end
    end

end

function sett.CurrentTabSettings()
    local ret, TabWidth, Indent, UseTabs =
    iup.GetParam(_T"Tab Preferences".."^CurrentTabSettings",
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

function sett.ScrollSize()
	local ret, size = iup.GetParam(_TM"Scroll Size...".."^ScrollSize",
        function(h, i) if i == -1 and tonumber(iup.GetParamParam(h, 0).value) < 11 then return 0 end return 1 end,
        _TH'Size:'..'%i[11,21,1]\n',
        tonumber(props['iup.scrollbarsize'])
    )
    if ret then

        if 1 == iup.Alarm(_T'Autoscroll Preferences', _T'Restart HildiM to apply the changes?', _TH"Yes", _TH"No") then
            props['iup.scrollbarsize'] = size
            scite.SetRestart('')
            scite.RunAsync(function() scite.MenuCommand(IDM_QUIT) end)
        end
    end
end

function sett.AutoScrollingProps()
    local ret,
    caret_policy_xslop, caret_policy_width, caret_policy_xstrict, caret_policy_xeven, caret_policy_xjumps,
    caret_policy_yslop, caret_policy_lines, caret_policy_ystrict, caret_policy_yeven, caret_policy_yjumps,
    caret_sticky, end_at_last_lin, iup_scrollbarsize
    = iup.GetParam(_T"Autoscroll Preferences".."^AutiscrollSettings",
        nil,
        _T'Horizontal Autoscroll'..'%t\n'..

        _T'Unwanted Zone (UZ)'..'%b\n'..
        _T'UZ Width, px'..'%i[0,500,20]\n'..
        _T'UZ - Enforce Strictly'..'%b\n'..
        _T'Asymmetric UZ'..'%b\n'..
        _T'Autoscroll for 3 UZ'..'%b\n'..

        _T'Vertical Autoscroll'..'%t\n'..

        _T'Unwanted Zone (UZ)'..'%b\n'..
        _T'UZ Height, lines'..'%i[0,500,20]\n'..
        _T'UZ - Enforce Strictly'..'%b\n'..
        _T'Asymmetric UZ'..'%b\n'..
        _T'Autoscroll for 3 UZ'..'%b\n'..

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
            if 1 == iup.Alarm(_T'Autoscroll Preferences', _T'Restart HildiM to apply the changes?', _TH"Yes", _TH"No") then
                props['iup.scrollbarsize'] = iup_scrollbarsize
                scite.SetRestart('')
                scite.RunAsync(function() scite.MenuCommand(IDM_QUIT) end)
            end
        end
    end
end

function sett.Colors_Work(tOut)
    local t = tOut or props
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

function sett.OpenNewInstance(w)
    local tCnf = iup.ConfigList()
    local sSnf = '%l|<Curent>|'
    for i = 1,  #tCnf do
        if type(tCnf[i].action) ~= 'function' then break end
        sSnf = sSnf..tCnf[i][1]..'|'
    end

    local asadm = ''
    if not scite.IsRunAsAdmin() then
        asadm = _T'Run As Administrator'..'%b\n'
    end

    local ret, fName, iSch, iCnf, bAllowSave, bAsAdm =
    iup.GetParam(_TM"Open New Instance".."^OpenInNewInstance",
            function(h, id)
                if id == iup.GETPARAM_INIT then
                    iup.GetParent(h).clientsize = '700'
                    local p = iup.GetParamHandle(h, 'PARAM2')
                    p.control.visibleitems = 15
                end
                return 1
            end,
        _T'File'..'%f\n'..
        _T'Color Scheme'..'%l|<Curent>|Default|Atrium|Darkblue|\n'..
        _T'Configuration'..sSnf..'\n'..
        _T'Allow Autosave Configuration'..'%b\n'..
        asadm,
        w,
        (_G.iuprops['newinstance.colourscheme'] or 0),
        (_G.iuprops['newinstance.configfile'] or 0),
        (_G.iuprops['newinstance.allow.save.config'] or 0),
        (_G.iuprops['newinstance.as.administrator'] or 0)
    )
    if ret then
        _G.iuprops['newinstance.colourscheme'] = iSch
        _G.iuprops['newinstance.configfile'] = iCnf
        _G.iuprops['newinstance.allow.save.config'] = bAllowSave

        if scite.IsRunAsAdmin() then
            bAsAdm = 0
        else
            _G.iuprops['newinstance.as.administrator'] = bAsAdm
        end

        local s = ''
        local strCommand = '-d-nSes-nRF'
        if bAllowSave == 0 then strCommand = strCommand..'-nSet' end

        if iSch > 0 then
            local sch =({'Colors_Default', 'Colors_Atrium', 'Colors_Darkblue'})[iSch]
            local tOut = {}
            sett[sch](tOut)
            for n, v in pairs(tOut) do
                s = s..n..'='..v..'\n'
            end
        end
        if iCnf > 0 then
            local sfname = props["scite.userhome"]..'\\'..tCnf[iCnf][1]
            strCommand = strCommand..'-config="'..sfname..'"'
            local e = {}
            e['_G'] = {}
            e['_G'].iuprops = {}
            loadfile(sfname, 't', e)()
            local t = e['_G'].iuprops["settings.lexers"]

            for i = 1, #t do
                s = s..'import $(SciteDefaultHome)\\languages\\'..t[i].file..'\n'
                local n = t[i].file:gsub('%.properties$', '.styles')
                if shell.fileexists(props["SciteUserHome"]..'\\'..n) then
                    s = s..'import $(scite.userhome)\\'..n..'\n'
                end
            end
        end
        if s ~= '' then
            local fn = props["SciteUserHome"]..'\\tmp.properties'
            local file = io.output(fn)
            file:write(s)
            file:close()
            strCommand = strCommand..'-props="'..fn..'"'
        end
        if (fName or '') ~= '' then
            strCommand = strCommand..' "'..fName..'"'
        end
        scite.NewInstance(strCommand, bAsAdm)
    end
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

function sett.Colors_Default(tOut)
    local t = tOut or props
    t["tabctrl.active.bakcolor"] = "255 255 255"
    t["tabctrl.active.forecolor"] = "90 33 33"
    t["tabctrl.active.readonly.forecolor"] = "111 108 108"
    t["tabctrl.cut.illumination"] = "90"
    t["tabctrl.cut.saturation"] = "50"
    t["tabctrl.forecolor"] = "0 0 0"
    t["tabctrl.moved.color"] = "120 120 255"
    t["tabctrl.readonly.color"] = "120 120 120"
    t["layout.hlcolor"] = "200 225 245"
    t["layout.borderhlcolor"] = "50 150 255"
    t["layout.bordercolor"] = "200 200 200"
    t["layout.bgcolor"] = "240 240 240"
    t["layout.txtbgcolor"] = "255 255 255"
    t["layout.fgcolor"] = "0 0 0"
    t["layout.txtfgcolor"] = "0 0 0"
    t["layout.txthlcolor"] = "15 60 195"
    t["layout.txtinactivcolor"] = "70 70 70"
    t["layout.bordercolor"] = "200 200 200"
    t["layout.splittercolor"] = "220 220 220"
    t["layout.scroll.forecolor"] = "190 190 190"
    t["layout.scroll.presscolor"] = "150 150 150"
    t["layout.scroll.highcolor"] = "170 170 170"
    t["layout.scroll.backcolor"] = "240 240 240"
    if tOut then return end
    scite.SetRestart('')
    scite.RunAsync(function() scite.MenuCommand(IDM_QUIT) end)
end

function sett.Colors_Atrium(tOut)
    local t = tOut or props
    t["tabctrl.active.bakcolor"] = "255 255 255"
    t["tabctrl.active.forecolor"] = "0 0 255"
    t["tabctrl.active.readonly.forecolor"] = "120 120 255"
    t["tabctrl.colorized"] = "1"
    t["tabctrl.cut.ext"] = "1"
    t["tabctrl.cut.illumination"] = "81"
    t["tabctrl.cut.prefix"] = "1"
    t["tabctrl.cut.saturation"] = "55"
    t["tabctrl.forecolor"] = "0 0 0"
    t["tabctrl.moved.color"] = "213 213 254"
    t["tabctrl.readonly.color"] = "82 82 82"
    t["layout.hlcolor"] = "200 225 245"
    t["layout.borderhlcolor"] = "50 150 255"
    t["layout.bordercolor"] = "221 157 216"
    t["layout.bgcolor"] = "165 211 206"
    t["layout.txtbgcolor"] = "255 255 255"
    t["layout.fgcolor"] = "0 0 0"
    t["layout.txtfgcolor"] = "2 2 2"
    t["layout.txthlcolor"] = "15 60 195"
    t["layout.txtinactivcolor"] = "97 97 97"
    t["layout.bordercolor"] = "221 157 216"
    t["layout.splittercolor"] = "178 223 218"
    t["layout.scroll.forecolor"] = "173 181 211"
    t["layout.scroll.presscolor"] = "81 102 178"
    t["layout.scroll.highcolor"] = "134 148 198"
    t["layout.scroll.backcolor"] = "238 245 244"
    if tOut then return end
    scite.SetRestart('')
    scite.RunAsync(function() scite.MenuCommand(IDM_QUIT) end)
end

function sett.Colors_Darkblue(tOut)
    local t = tOut or props
    t["tabctrl.active.bakcolor"] = "255 255 255"
    t["tabctrl.active.forecolor"] = "0 0 255"
    t["tabctrl.active.readonly.forecolor"] = "120 120 255"
    t["tabctrl.cut.illumination"] = "28"
    t["tabctrl.cut.saturation"] = "30"
    t["tabctrl.forecolor"] = "255 255 255"
    t["tabctrl.readonly.color"] = "214 214 214"
    t["tabctrl.moved.color"] = "213 213 254"
    t["tabctrl.readonly.color"] = "214 214 214"
    t["layout.hlcolor"] = "94 180 189"
    t["layout.borderhlcolor"] = "51 146 156"
    t["layout.bordercolor"] = "1 148 143"
    t["layout.bgcolor"] = "76 95 129"
    t["layout.txtbgcolor"] = "255 255 255"
    t["layout.fgcolor"] = "255 255 255"
    t["layout.txtfgcolor"] = "0 0 0"
    t["layout.txthlcolor"] = "255 149 239"
    t["layout.txtinactivcolor"] = "183 183 183"
    t["layout.splittercolor"] = "35 63 113"
    t["layout.scroll.forecolor"] = "120 165 125"
    t["layout.scroll.presscolor"] = "61 114 66"
    t["layout.scroll.highcolor"] = "81 139 87"
    t["layout.scroll.backcolor"] = "238 245 244"
    if tOut then return end
    scite.SetRestart('')
    scite.RunAsync(function() scite.MenuCommand(IDM_QUIT) end)
end

return sett
