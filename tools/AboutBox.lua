local function InitWndDialog()
    local web;
    local templ = [[
<!DOCTYPE HTML >
<html>
  <head>
    <meta http-equiv="Content-Type" content="text-html; charset=Windows-1251">
    <style type="text/css">
body, html {
    color:{color};
    font-size:18pt;
    background-color:{background_color};
    scrollbar-3dlight-color:{background_color};
    scrollbar-arrow-color:{background_color};
    scrollbar-base-color:{background_color};
    scrollbar-darkshadow-color:{background_color};
    scrollbar-face-color:{background_color};
    scrollbar-highlight-color:{background_color};
    scrollbar-shadow-color:{background_color}
}
   .hl {
    color:{hlcolor}
   }
   a {
    color:{color}
   }
   a:hover {
    color:{hlcolor}
   }
    </style>
    <title>About</title>
  </head>
  <body text="#000000">
    <div align="justify">
      <div>
        By Michal Voznesenskiy
      </div>
      <div>
        <span class="hl">{Version} {HildiMVer}</span> {HildiMDate}
      </div>
      <div>
        {Based} SciTE 2.24  Neil Hodgson. <br>
        December 1998-December 2010.
      </div>
        <span class="hl">Scintilla {ScintillaVer}</span> code editing component, Neil Hodgson <br>
        <a target="_blank" href="http://www.scintilla.org">http://www.scintilla.org</a>
      </div>
      <div>
        <span class="hl">UIP libraries {IUPVer}</span> by TeCGraf, PUC-Rio<br>
        <a target="_blank" href="http://iup.sourceforge.net">http://iup.sourceforge.net</a>
      </div>
      <div>
        <span class="hl">Lua 5.3</span> scripting language by TeCGraf, PUC-Rio</a>
        <a target="_blank" href="http://www.lua.org">http://www.lua.org</a>
      </div>
      <div>
        Plugins:
      </div>
        {PLUGINS}
    </div>
  </body>
</html>
]]
    local tempdll = [[
    <div class="hl">
        {OriginalFilename} {FileVersion}
    </div>
    <div>
        {FileDescription}
    </div>
]]
    local function Color2Html(strColor)
        local _, _, r, g, b = strColor:find('([0-9]+) ([0-9]+) ([0-9]+)')
        return '#'..string.format('%02x', r).. string.format('%02x', g)..string.format('%02x', b)
    end

    local function createDlg()
        local dlg
        web = iup.webbrowser{expand = 'YES'}
        local fclose = iup.flatbutton{image = 'CLOSE_µ', bgcolor = props['layout.bgcolor']; flat_action = function(h) dlg:postdestroy() end}

        dlg = iup.scitedialog{iup.backgroundbox{iup.hbox{iup.vbox{
                iup.hbox{iup.label{image = "HildiM_µ"},
                iup.label{title = "HildiM", font = "Cooper Black, 33"}, gap = '15', alignment = 'ACENTER'},
                 web, alignment = 'ACENTER'
        }; fclose}; bgcolor = iup.GetLayout().bgcolor, fgcolor = iup.GetLayout().txthlcolor},
            minsize = '400x300', maxbox = "NO", minbox = "NO", menubox = 'NO', sciteparent = "SCITE", sciteid = "About",
            customframedraw = 'YES', customframecaptionheight = -1, customframedraw_cb = CORE.paneldraw_cb,
            customframeactivate_cb = function(h, active) if active == 0 then h:postdestroy(); return end CORE.panelactivate_cb(false)(h, active) end
        }

        return dlg

    end

    local dlg = createDlg()
    iup.ShowXY(dlg, iup.CENTERPARENT, iup.CENTERPARENT, true)
    local t = scite.FileVersionInfo(props['SciteDefaultHome']..'/HildiM.exe')

    templ = templ:gsub('{HildiMVer}', t.FileVersion):gsub('{IUPVer}', t.IUPVersion):gsub('{Version}', _T'Version'):gsub('{Based}', _T'Based')
    templ = templ:gsub('{background_color}', Color2Html(props['layout.bgcolor'])):gsub('{color}', Color2Html(props['layout.fgcolor'])):gsub('{hlcolor}', Color2Html(props['layout.txthlcolor']))
    t = shell.getfiletime(props['SciteDefaultHome']..'/HildiM.exe')
    local dt = string.format('%02d.%02d.%4d %02d:%02d', t.Day, t.Month, t.Year, t.Hour, t.Minute)
    t = scite.FileVersionInfo(props['SciteDefaultHome']..'/SciLexer.dll')
    templ = templ:gsub('{ScintillaVer}', t.FileVersion):gsub('{HildiMDate}', dt)

    local tdll = scite.findfiles(props['SciteDefaultHome']..'/tools/lualib/*.dll')

    local strPlug = ''
    for i = 1,  #tdll do
        t = scite.FileVersionInfo(props['SciteDefaultHome']..'/tools/lualib/'..tdll[i].name)
        if t then
            strPlug = strPlug..tempdll:gsub('{OriginalFilename}', t.OriginalFilename or tdll[i].name):gsub('{FileVersion}', t.FileVersion or '1?'):gsub('{FileDescription}', t.FileDescription or '')
        end
    end
    templ = templ:gsub('{PLUGINS}', strPlug)
    web.html = templ

end

InitWndDialog()
