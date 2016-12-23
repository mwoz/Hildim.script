local containers = {}
local tblColours, dlg, strText

local function Ctrl(s)
    return iup.GetDialogChild(containers[2],s)
end

local function SetStaticControls()
    local _,_,r,g,b = Ctrl("colorBr").rgb:find('([0-9]+) ([0-9]+) ([0-9]+)')
    Ctrl('txtRGB').value = string.format('%02x',r)..string.format('%02x',g)..string.format('%02x',b)
--[[    Ctrl('txtG').value =
    Ctrl('txtB').value = ]]
end

local function _OnClrChange(h)
    local mLst = Ctrl("matrixList")
    mLst["COLOR"..mLst.focusitem] = h.rgb
    local t = tblColours[mLst.focusitem - 0]
    if t.typ == 'b' then
        iup.SetAttribute(mLst, "ITEMBGCOLOR"..mLst.focusitem, h.rgb)
        if tblColours[mLst.focusitem + 1] and t.lId == tblColours[mLst.focusitem + 1].lId then
            iup.SetAttribute(mLst, "ITEMBGCOLOR"..(mLst.focusitem + 1), h.rgb)
            mLst.redraw = "L"..(mLst.focusitem + 1)
        end
    else
        iup.SetAttribute(mLst, "ITEMFGCOLOR"..mLst.focusitem, h.rgb)
        if tblColours[mLst.focusitem - 1] and t.lId == tblColours[mLst.focusitem - 1].lId then
            iup.SetAttribute(mLst, "ITEMFGCOLOR"..(mLst.focusitem - 1), h.rgb)
            iup.SetAttribute(mLst, "ITEMBGCOLOR"..(mLst.focusitem), iup.GetAttribute(mLst, "ITEMBGCOLOR"..(mLst.focusitem - 1)))
            mLst.redraw = "L"..(mLst.focusitem - 1)
        end
    end
    mLst.redraw = "L"..mLst.focusitem
end

local function OnClrChange(h)
    _OnClrChange(h)
    SetStaticControls()
end

local function ByTxt(h)
    local rgb=((('0x'..Ctrl('txtR').Value)+0)..' '..(('0x'..Ctrl('txtG').Value)+0)..' ' ..(('0x'..Ctrl('txtB').Value)+0))
    Ctrl("colorBr").rgb= rgb
    _OnClrChange(Ctrl("colorBr"))
end

local function OnSaveClr(bClouse)
    local mLst = Ctrl("matrixList")
    local strOut = '\n'

    local function GetRgb(i)
        local rgb = iup.GetAttributeId(mLst, "COLOR", i)
        local _,_,r,g,b = rgb:find('([0-9]+) ([0-9]+) ([0-9]+)')
        rgb = '#'..string.format('%02x',r)..string.format('%02x',g)..string.format('%02x',b)
        return rgb:upper()
    end

    local i = 1
    while i <= tonumber(mLst.count) do

        strOut = strOut..'# '..tblColours[i].comment..'\n'..tblColours[i].name..'='
        if tblColours[i].typ == 'b' then
            local j = i
            if tblColours[i + 1] and tblColours[i].lId == tblColours[i + 1].lId then
                i = i + 1
                strOut = strOut..'fore:'..GetRgb(i)..','
            end
            strOut = strOut..'back:'..GetRgb(j)
        else
            strOut = strOut..'fore:'..GetRgb(i)
        end
        strOut = strOut..'\n\n'
        i = i + 1
    end
    --[[print(strOut)]]
    local tmpF = io.output(props["SciteDefaultHome"]..'\\data\\home\\SciTEColors.properties')
    tmpF:write(strOut)
    tmpF:close()
    scite.Perform("reloadproperties:")
    if bClouse then dlg:postdestroy() end
end

function create_dialog_clr()

  containers[6] = iup.hbox{
    iup.label{
      size = "40x0",
      title = "Color:"
    },
    iup.text{
      size = "40x0",
      mask = "[A-Fa-f0-9]*",
      value='ff0000',
      valuechanged_cb=(function(h)
        local c = h.caret
        if h.value:len()<6 then
            h.value=h.value..string.rep('0', 6 - h.value:len())
        elseif h.value:len()>6 then
            h.value = h.value:gsub('(......).*', '%1')
        end;
        h.caret = c
        local _,_,r,g,b = h.value:find('(..)(..)(..)')
        local rgb=((('0x'..r)+0)..' '..(('0x'..g)+0)..' ' ..(('0x'..b)+0))
        Ctrl("colorBr").rgb= rgb
        _OnClrChange(Ctrl("colorBr"))
      end),
      name = 'txtRGB',
    },
  }
  containers[7] = iup.hbox{

    iup.button{
      size = "40x0",
      title = "Apply",
      name = 'LCOLOR_BTN_OK',
      action = (function() OnSaveClr(false) end),
    },
    iup.button{
      size = "40x0",
      title = "Save",
      name = 'LCOLOR_BTN_OK',
      action = (function() OnSaveClr(true) end),
    },
    iup.button{
      size = "40x0",
      title = "Cancel",
      name = "LCOLOR_BTN_ESC",
      action = (function() dlg:postdestroy() end)
    },
    expand = "NO",
  }

  containers[3] = iup.vbox{
    iup.colorbrowser{
      hsi = "0.000000000 1.000000000 0.500000000",
      expand = "NO",
      posx = "0.000000000",
      posy = "0.000000000",
      bgcolor = "240 240 240",
      rastersize = "181x181",
      border = "NO",
      name = "colorBr",
      valuechanged_cb = OnClrChange,
    },
    containers[6],
    iup.fill{},
    containers[7],
    expand = "YES",
  }

  containers[5] = iup.vbox{
    iup.matrixlist{
      expand = "YES",
      columnorder = "COLOR:LABEL",
      frametitlehighlight = "No",
      hidefocus = "YES",
      numcol = "1",
      ["height0"] = "0",
      numlin = "20",
      --heightdef = "5",
      scrollbar = "VERTICAL",
      --count = "5",
      ["width0"] = "0",
      ["width1"] = "40",
      ["width2"] = "500",
      numlin_visible = "10",
      name="matrixList",
    },
    expand = "YES",
  }

  containers[2] = iup.hbox{
    containers[5],
    containers[3],
  }

  return containers[2]
end

local function LexerColors()

    local tmpF = io.input(props["SciteDefaultHome"]..'\\data\\home\\SciTEColors.properties')
    strText = tmpF:read('*a')
    tmpF:close()
    tblColours = {}
    local i = 0
    strText = strText:gsub('\n#%s*([^\n]*)\n(colour%.[^=]+)=([^\n]+)',
                (function(cmnt, prp, val)
                    _,_,r,g,b = val:find('back:#(%x%x)(%x%x)(%x%x)')
                    if r then
                        table.insert(tblColours, {lId = i, comment = cmnt, name = prp, colour = ((('0x'..r)+0)..' '..(('0x'..g)+0)..' ' ..(('0x'..b)+0)), typ = 'b'})
                    end
                    local _,_,r,g,b = val:find('fore:#(%x%x)(%x%x)(%x%x)')
                    if r then
                        table.insert(tblColours, {lId = i, comment = cmnt, name = prp, colour = ((('0x'..r)+0)..' '..(('0x'..g)+0)..' ' ..(('0x'..b)+0)), typ = 'f'})
                    end
                    i = i + 1
                end))

    local cont = create_dialog_clr()
    local mLst = Ctrl("matrixList")
    mLst.count = #tblColours
    mLst.numlin = #tblColours
    mLst.numlin_visible = #tblColours
    mLst.listedition_cb = (function() return -1 end)
    mLst.listclick_cb = (function(h,l,c,s) Ctrl("colorBr").rgb = h["COLOR"..l]; SetStaticControls() end)

    local prevBack = "255 255 255"
    local prevBackInd = -1
    for i = 1,#tblColours do
        iup.SetAttributeId(mLst, "COLOR", i, tblColours[i].colour)
        iup.SetAttributeId(mLst, "", i, tblColours[i].name.." #"..tblColours[i].comment)
        if tblColours[i].typ == "b" then
            if i < #tblColours and tblColours[i].lId == tblColours[i+1].lId then iup.SetAttribute(mLst, "ITEMFGCOLOR"..i, tblColours[i+1].colour) end
            iup.SetAttribute(mLst, "ITEMBGCOLOR"..i, tblColours[i].colour)
            prevBackInd = tblColours[i].lId
            prevBack = tblColours[i].colour
        else
            iup.SetAttribute(mLst, "ITEMFGCOLOR"..i, tblColours[i].colour)
            if prevBackInd == tblColours[i].lId then iup.SetAttribute(mLst, "ITEMBGCOLOR"..i, prevBack) end
        end
    end
    mLst.listclick_cb(mLst,1)

    dlg = iup.scitedialog{cont,
        maxbox = "NO",
        title = "Colors",
        editable = "NO",
        defaultesc = "LCOLOR_BTN_ESC",
        resize = "NO",
        minbox = "NO",
        defaultenter = "LCOLOR_BTN_OK",
        shrink = "YES",
        sciteparent="SCITE",
        sciteid="lexerColors",
        gap = '3',
        margin = '3x3',
        }
    dlg.show_cb=(function(h,state)
        if state == 4 then
            dlg:postdestroy()
        end
    end)
end

LexerColors()
