require "seacher"
local containers
local oDeattFnd
local firstMark = tonumber(props["findtext.first.mark"])
local popUpFind
local _Plugins

local findSettings = seacher{}

local function Ctrl(s)
    return iup.GetDialogChild(containers[2],s)
end

local function PrepareFindText(s)
    if Ctrl("chkRegExp").value == "ON" or Ctrl("chkBackslash").value == "ON" then
        return s:gsub('\\', '\\\\'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
    else
        local _,_,ret = s:find('^([^\n\r\t]*)')
        return ret or ''
    end
end

local function SetInfo(msg, chColor)
    local strColor
    if chColor == 'E' then strColor = "255 0 0"
    elseif chColor == 'W' then strColor = "255 0 0"
    else strColor = "0 0 0" end
    Ctrl('lblInfo').title = msg
    Ctrl('lblInfo').fgcolor = strColor
end

local cv = (function(s) return iup.GetDialogChild(containers[2],s).value end)

local function ReadSettings()
    findSettings:Reset{
        wholeWord = (cv("chkWholeWord") == "ON")
        ,matchCase = (cv("chkMatchCase") == "ON")
        ,wrapFind = (cv("chkWrapFind") == "ON")
        ,backslash = (cv("chkBackslash") == "ON")
        ,regExp = (cv("chkRegExp") == "ON")
        ,style = Iif(cv("chkInStyle") == "ON",tonumber(cv("numStyle")),nil)
        ,searchUp = (containers["zUpDown"].valuepos == "0")
        ,findWhat = self:encode(cv("cmbFindWhat"))
        ,replaceWhat = self:encode(cv("cmbReplaceWhat"))
    }
    if Ctrl("chkRegExp").value == 'ON' then
        local err = scite.CheckRegexp(Ctrl("cmbFindWhat").value)
        if err then
            print(err)
            SetInfo('regex_error', 'E')
            return true
        end
    end
end

--Хендлеры контролов диалога
local function PostAction()
    if _G.dialogs['findrepl'] and Ctrl("zPin").valuepos == '1' then
        popUpFind.show_cb(popUpFind,4)
        popUpFind.close_cb(popUpFind)
    end
end

local function CloseFind()
    if _G.dialogs['findrepl'] then
        popUpFind.close_cb(popUpFind)
    end
end

local function ReplaceAll(h)
    if ReadSettings() then return end
    local count = findSettings:ReplaceAll(false)
    SetInfo('Произведено замен: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbFindWhat"):SaveHist()
    Ctrl("cmbReplaceWhat"):SaveHist()
    iup.PassFocus()
    PostAction()
end

local function ReplaceSel(h)
    if ReadSettings() then return end
    local count = findSettings:ReplaceAll(true)
    SetInfo('Произведено замен: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbFindWhat"):SaveHist()
    Ctrl("cmbReplaceWhat"):SaveHist()
    iup.PassFocus()
    PostAction()
end

local function FindSel(h)
    if ReadSettings() then return end
    local count = findSettings:FindAll(500, false, true)
    SetInfo('Найдено: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbFindWhat"):SaveHist()
    iup.PassFocus()
    PostAction()
end

local function FindAll(h)
    if ReadSettings() then return end
    local count = findSettings:FindAll(500, false)
    SetInfo('Найдено: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbFindWhat"):SaveHist()
    iup.PassFocus()
    PostAction()
end

local function GetCount(h)
    if ReadSettings() then return end
    local count = findSettings:Count()
    SetInfo('Найдено: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbFindWhat"):SaveHist()
    iup.PassFocus()
end

local function FindNext(h)
    if ReadSettings() then return end
    OnNavigation("Find")
    local pos = findSettings:FindNext(true)
    OnNavigation("Find-")
    if pos < 0 then SetInfo('Ничего не найдено', 'E')
    else SetInfo('', '') end
    Ctrl("cmbFindWhat"):SaveHist()
    iup.PassFocus()
    if Ctrl('tabFindRepl').valuepos == '0' then PostAction() end
end

local function ReplaceOnce(h)
    if ReadSettings() then return end
    OnNavigation("Repl")
    local pos = findSettings:ReplaceOnce()
    OnNavigation("Repl-")
    if pos < 0 then SetInfo('Ничего не найдено', 'E')
    else SetInfo('', '') end
    Ctrl("cmbFindWhat"):SaveHist()
    Ctrl("cmbReplaceWhat"):SaveHist()
    iup.PassFocus()
end

local function MarkAll(h)
    if ReadSettings() then return end
    local count = findSettings:MarkAll(Ctrl("chkMarkInSelection").value == "ON", firstMark - 1 + tonumber(Ctrl("matrixlistColor").focusitem))
    SetInfo('Помечено: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbFindWhat"):SaveHist()
    iup.PassFocus()
end

local function ClearMark(h)
    EditorClearMarks(firstMark - 1 + tonumber(Ctrl("matrixlistColor").focusitem))
end

local function ClearMarkAll(h)
    for i = 0,4 do
        EditorClearMarks(firstMark + i)
    end
end

local function BookmarkAll(h)
    if ReadSettings() then return end
    local count = findSettings:BookmarkAll(Ctrl("chkMarkInSelection").value == "ON")
    SetInfo('Помечено: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbFindWhat"):SaveHist()
    iup.PassFocus()
    PostAction()
end

local function FindInFiles()
    if ReadSettings() then return end

    if Ctrl("cmbFindWhat").value == '' then return end
    if Ctrl("cmbFilter").value == '' then Ctrl("cmbFilter").value = '*.*' end
    if Ctrl("cmbFolders").value == '' then Ctrl("cmbFolders").value = props['FileDir']:from_utf8(1251) end
    local fWhat = Ctrl("cmbFindWhat").value:to_utf8(1251)
    local fFilter = Ctrl("cmbFilter").value
    local fDir = Ctrl("cmbFolders").value:to_utf8(1251)
    local params = Iif(Ctrl("chkWholeWord").value=='ON', 'w','~')..
                   Iif(Ctrl("chkMatchCase").value=='ON', 'c','~')..'~'..
                   Iif(Ctrl("chkRegExp").value=='ON', 'r','~')..
                   Iif(Ctrl("chkSubFolders").value=='ON', 's','~')..
                   Iif(_G.iuprops['findres.groupbyfile'], 'g', '~')
    scite.PerformGrepEx(params,fWhat,fDir,fFilter)

    Ctrl("cmbFindWhat"):SaveHist()
    Ctrl("cmbFolders"):SaveHist()
    Ctrl("cmbFilter"):SaveHist()
    iup.PassFocus()
    PostAction()
end

local function ReplaceInBuffers()
    if ReadSettings() then return end
    local count = DoForBuffers(findSettings:ReplaceInBufer())
    SetInfo('Произведено замен: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbReplaceWhat"):SaveHist()
    Ctrl("cmbFindWhat"):SaveHist()
    iup.PassFocus()
    PostAction()
end

local function FindInBuffers()
    if ReadSettings() then return end
    findSettings:CollapseFindRez()
    local count = DoForBuffers(findSettings:FindInBufer(), 100)
    SetInfo('Всего найдено: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbFindWhat"):SaveHist()
    iup.PassFocus()
    PostAction()
end

local function GoToMarkDown()
    local iPos = editor.SelectionStart
    local mark = firstMark  - 1 + tonumber(Ctrl("matrixlistColor").focusitem)
    local nextStart = iPos
    local bMark = false
    iPos = scite.SendEditor(SCI_INDICATOREND, mark, nextStart)
    if iPos >= editor.TextLength then iPos = scite.SendEditor(SCI_INDICATOREND, mark, 0) end
    if iPos < editor.TextLength and iPos ~= nextStart then
        nextStart = scite.SendEditor(SCI_INDICATOREND, mark, iPos)
        if nextStart > 0 then
            OnNavigation("Mark")
            editor:SetSel(nextStart, nextStart+1)
            OnNavigation("Mark-")
            bMark = true
        end
    end
    SetInfo(Iif(bMark, '', 'Меток не обнаружено'), Iif(bMark, '', 'E'))
end
local function GoToMarkUp()
    local curPos = editor.SelectionStart
    local iPos = 0
    local mark = firstMark  - 1 + tonumber(Ctrl("matrixlistColor").focusitem)
    local nextStart = iPos
    local bMark = false
    iPos = scite.SendEditor(SCI_INDICATOREND, mark, nextStart)
    if iPos >= curPos then
        iPos = scite.SendEditor(SCI_INDICATOREND, mark, curPos)
        curPos = editor.TextLength
    end
    if iPos < editor.TextLength and iPos ~= nextStart then
        nextStart = scite.SendEditor(SCI_INDICATOREND, mark, iPos)
        local prevPos = iPos
        while iPos < curPos do
            prevPos = iPos
            iPos = scite.SendEditor(SCI_INDICATOREND, mark, nextStart)
            if iPos >= editor.TextLength or iPos == nextStart then break end

            nextStart = scite.SendEditor(SCI_INDICATOREND, mark, iPos)
        end
        OnNavigation("Mark")
        editor:SetSel(prevPos - 1, prevPos)
        OnNavigation("Mark-")
        bMark = true
    end
    SetInfo(Iif(bMark, '', 'Меток не обнаружено'), Iif(bMark, '', 'E'))
end

local function SetStaticControls()
    local notInFiles = (Ctrl("tabFindRepl").valuepos ~= '2')
    local notRE = (Ctrl("chkRegExp").value == 'OFF')
    Ctrl("numStyle").active = Iif(Ctrl("chkInStyle").value == 'ON' and notInFiles, 'YES', 'NO')
    Ctrl("chkInStyle").active = Iif(notInFiles, 'YES', 'NO')
    Ctrl("chkWrapFind").active = Iif(notInFiles, 'YES', 'NO')
    Ctrl("chkWholeWord").active = Iif(notRE, 'YES', 'NO')
    Ctrl("chkBackslash").active = Iif(notInFiles and notRE, 'YES', 'NO')
    Ctrl("btnArrowUp").active = Iif(notInFiles, 'YES', 'NO')
    Ctrl("btnArrowDown").active = Iif(notInFiles, 'YES', 'NO')
    oDeattFnd.onSetStaticControls()
end

local function onMapMColorList(h)
    for i = 0, 5 do
        local _,_,r,g,b = props["indic.style."..(i + firstMark - 1)]:find('#(%x%x)(%x%x)(%x%x)')
        local strClr = ((('0x'..r)+0)..' '..(('0x'..g)+0)..' ' ..(('0x'..b)+0))
        h["color"..i] = strClr
    end
end

local function DefaultAction()
    local nT = Ctrl("tabFindRepl").valuepos
    if nT == '0' then FindNext()
    elseif nT == '1' then ReplaceOnce()
    elseif nT == '2' then  FindInFiles()
    elseif nT == '3' then  MarkAll()
    end
end

local function SetFolder()
    local d = iup.filedlg{dialogtype='DIR', parentdialog='SCITE',directory=Ctrl("cmbFolders").value}
    d:popup()
    if d.status ~= '-1' then Ctrl("cmbFolders").value = d.value end
    d:destroy()
end
local function FolderUp()
    Ctrl("cmbFolders").value = Ctrl("cmbFolders").value:gsub('^(.*)\\[^\\]+\\?$','%1')
end

--перехватчики команд меню
local function ActivateFind_l(nTab)
    Ctrl("tabFindRepl").valuepos = nTab

    local wnd = editor
    if output.Focus then wnd = output
    elseif findres.Focus then wnd = findres end

    local s
    if wnd.SelectionStart == wnd.SelectionEnd then s = GetCurrentWord()
    else s = wnd:GetSelText() end
    if wnd.CodePage ~= 0 then s = s:from_utf8(1251) end
    s = PrepareFindText(s)
    if s ~= '' then Ctrl("cmbFindWhat").value = s end

    if _G.dialogs['findrepl'] then
        _G.dialogs['findrepl'].ShowDialog()
    elseif _Plugins.findrepl.Bar_obj then
        local tabCtrl = _Plugins.findrepl.Bar_obj.TabCtrl
        local ind
        for i = 0, tabCtrl.count - 1 do
            if iup.GetAttributeId(tabCtrl, "TABTITLE", i) == _Plugins.findrepl.id  then ind = i; break end
        end

        tabCtrl.valuepos = ind; _Plugins.functions.OnSwitchFile()
        if _G.iuprops[_Plugins.findrepl.Bar_obj.sciteid..'.win'] == '2' then _Plugins.findrepl.Bar_obj.handle.ShowDialog() end
    end

    if nTab ~= 2 then Ctrl("numStyle").value = wnd.StyleAt[wnd.SelectionStart] end

    if s ~= '' and nTab == 1 then iup.SetFocus(Ctrl('cmbReplaceWhat'))
    else iup.SetFocus(Ctrl('cmbFindWhat')) end

    if nTab == 2 then Ctrl('cmbFolders').value = props['FileDir']:from_utf8(1251) end
    SetStaticControls()
    return true
end

local function FindNextSel(bUp)
    if editor:LineFromPosition(editor.SelectionStart) == editor:LineFromPosition(editor.SelectionEnd) then
        str = editor:GetSelText()
        if str ~= '' then
            local prevUp = findSettings.searchUp
            ActivateFind_l(0)

            if ReadSettings() then return end
            OnNavigation("Find")
            findSettings.searchUp = bUp
            local pos = findSettings:FindNext(true)
            OnNavigation("Find-")
            if pos < 0 then SetInfo('Ничего не найдено', 'E')
            else SetInfo('', '') end
            Ctrl("cmbFindWhat"):SaveHist()

            findSettings.searchUp = prevUp
        end
    end
    return true
end

local function FindNextBack(bUp)
    if not findSettings.findWhat then ReadSettings() end
    if findSettings.findWhat == '' then return true end
    iup.PassFocus()
    local prevUp = findSettings.searchUp
    findSettings.searchUp = bUp
    OnNavigation("Find")
    local pos = findSettings:FindNext(true)
    OnNavigation("Find-")
    if pos < 0 then print("Error: '"..findSettings.findWhat.."' not found") end
    findSettings.searchUp = prevUp
    return true
end

local function PassOrClose()
    if _G.dialogs['findrepl'] and Ctrl("zPin").valuepos == '1' then
        PostAction()
    else
        iup.PassFocus()
    end
end


--создание диалога

local function create_dialog_FindReplace()
  containers = {}
  containers["zPin"] = iup.zbox{
    iup.flatbutton{
      impress = "IMAGE_Pin",
      visible = "NO",
      image = "IMAGE_PinPush",
      --size = "11x9",
      canfocus  = "NO",
      flat_action = (function(h) containers["zPin"].valuepos = "1" end),
    },
    iup.flatbutton{
      impress = "IMAGE_PinPush",
      visible = "NO",
      image = "IMAGE_Pin",
      canfocus  = "NO",
      --size = "11x9",
      flat_action = (function(h) containers["zPin"].valuepos = "0" end),
      },
    name = "zPin",
  }
  containers[4] = iup.hbox{
    iup.label{
      title = "Найти:",
    },
    iup.list{
      name = "cmbFindWhat",
      expand = "HORIZONTAL",
      rastersize = "1x0",
      editbox = "YES",
      dropdown = "YES",
      visibleitems = "18",
      edit_cb=(function(h, c, new_value) if new_value:find('[\n\r]') then h.value = PrepareFindText(new_value) return -1 end end),
      k_any = (function(_,c) if c..'' == iup.K_PGUP..'' then FolderUp() return true; elseif c == iup.K_CR then DefaultAction() elseif c == iup.K_ESC then PassOrClose() end; end),
    },
    containers["zPin"],
    iup.button{           ------------
      name = "BtnOK",
      action = DefAction,
      fontsize = 1, margin = '0x0',
      visible = 'NO'
    },
    margin = "0x00",
    expand = "HORIZONTAL",
    alignment = "ACENTER",

  }

  containers[3] = iup.frame{
    containers[4],
    expand = "HORIZONTAL",
    rastersize = "372x29",
  }

  containers[32] = iup.vbox{
    iup.button{
      image = "IMAGE_search",
      title = " далее",
      bgcolor = "255 255 255",
      name = "btnFind",
      action = FindNext,
      padding = "5x0"
    },
    iup.button{
      title = "Найти все",
      action = FindAll,
    },
    margin = "6x6",
    normalizesize = "HORIZONTAL",
  }

  containers[7] = iup.vbox{
    iup.hbox{
        margin = "0x0",
        iup.button{
          action = CloseFind,
          name = 'btn_esc',
          size = '1x1',
        },
    },
    iup.hbox{
      iup.button{
        title = "В выделенном",
        action = FindSel,
      },
      iup.button{
        title = "На вкладках",
        action = FindInBuffers,
      },
      iup.button{
        title = "Подсчитать",
        action = GetCount,
      },
      --normalizesize = "HORIZONTAL",
      gap = "3",
      alignment = "ABOTTOM",
      margin = "0x2",
      expand = "VERTICAL",
       margin = "0x0",
    },
      gap = "4",
      margin = "0x6",
      normalizesize = "VERTICAL",
  }

  containers[6]= iup.hbox{
    containers[32],
    containers[7],
    expandchildren = "YES",

  }

  containers[13] = iup.vbox{
    iup.button{
      title = " на:",
      image = "IMAGE_Replace",
      action = ReplaceOnce,
      canfocus  = "NO",
    },
    iup.button{
      image = "IMAGE_search",
      title = " далее",
      padding = "5x0",
      action = FindNext,
      canfocus  = "NO",
    },
    normalizesize = "HORIZONTAL",
  }

  containers[15] = iup.hbox{
    iup.button{
      title = "Заменить все",
      action = ReplaceAll,
    },
    iup.button{
      title = "В выделенном",
      action = ReplaceSel,
    },
    iup.button{
      title = "На вкладках",
      action = ReplaceInBuffers,
    },
    margin = "0x00",
  }

  containers[14] = iup.vbox{
    iup.list{
      name = "cmbReplaceWhat",
      expand = "HORIZONTAL",
      rastersize = "1x0",
      editbox = "YES",
      dropdown = "YES",
      edit_cb=(function(h, c, new_value) if new_value:find('[\n\r\t]') then _,_,h.value = new_value:find('^([^\n\r\t]*)')return -1 end end),
      visibleitems = "18",
    },
    containers[15],
    alignment = "ARIGHT",
  }

  containers[12] = iup.hbox{
    containers[13],
    containers[14],
    normalizesize = "VERTICAL",
    gap = "3",
    alignment = "ACENTER",
  }

  containers[11] = iup.vbox{
    containers[12],
    gap = "4",
  }

  containers[17] = iup.hbox{
    iup.label{
      title = "В папках:",
    },
    iup.list{
      name = "cmbFolders",
      expand = "HORIZONTAL",
      rastersize = "1x0",
      editbox = "YES",
      dropdown = "YES",
      visibleitems = "18",
    },
    iup.button{
      image = "IMAGE_ArrowUp",
      action = FolderUp,
      tip = "На уровень вверх\n(PgUp в строке поиска)",
    },
    iup.button{
      image = "IMAGE_Folder",
      action = SetFolder,
      tip = "Выбор папки",
    },
    gap = "3",
    alignment = "ACENTER",
    margin = "0x2",
  }

  containers[18] = iup.hbox{
    iup.label{
      size = "31x8",
      title = "Фильтр:",
    },
    iup.list{
      name = "cmbFilter",
      expand = "HORIZONTAL",
      rastersize = "1x0",
      editbox = "YES",
      dropdown = "YES",
      visibleitems = "18",
    },
    iup.toggle{
      name = "chkSubFolders",
      title = "В подпапках",
    },
    iup.button{
      image = "IMAGE_search",
      padding = "14x0",
      action = FindInFiles,
      tip = "Искать в файлах",
    },
    alignment = "ACENTER",
    margin = "0x00",
  }

  containers[16] = iup.vbox{
    containers[17],
    containers[18],
    gap = "4",
  }

  containers[21] = iup.hbox{
    iup.button{
      title = "Пометить",
      action = MarkAll,
    },
    iup.button{
      title = "Удалить",
      action = ClearMark,
    },
    iup.button{
      title = "Удалить все",
      action = ClearMarkAll,
      padding = "2",
    },
    --normalizesize = "HORIZONTAL",
    margin = "0x00",
  }
  containers[22] = iup.hbox{
    iup.toggle{
      title = "В выделенном",
      name = "chkMarkInSelection",
    },
    iup.button{
      title = "*** Закладками",
      action = BookmarkAll,
    },
    gap = "4",
    alignment = "ACENTER",
    margin = "0x00",
  }

  containers[33] = iup.vbox{
    iup.button{
      image = "IMAGE_ArrowUp",
      action = GoToMarkUp,
      tip = "Предыдущая метка",
    },
    iup.button{
      image = "IMAGE_ArrowDown",
      action = GoToMarkDown,
      tip = "Следующая метка",
    },
    margin = "0x3",
  }
  containers[31] = iup.vbox{
    containers[21],
    containers[22],
    margin = "0x3",
  }
  containers[30] = iup.vbox{
    iup.matrixlist{
      size = "53x0",
      expand = "NO",
      columnorder = "COLOR",
      frametitlehighlight = "No",
      ["rasterheight0"] = "0",
      ["rasterwidth0"] = "0",
      ["rasterwidth1"] = "40",
      hidefocus = "YES",
      numcol = "1",
      ["height0"] = "0",
      numlin = "5",
      heightdef = "5",
      scrollbar = "VERTICAL",
      count = "5",
      ["width0"] = "0",
      ["width1"] = "34",
      numlin_visible = "3",
      name="matrixlistColor",
      map_cb = onMapMColorList
    },

  }
  containers[29] = iup.hbox{
    containers[30],
    containers[31],
    containers[33],
    margin = "3x3",
  }
  containers[19] = iup.vbox{
    containers[29],
    margin = "0x00",
  }

  containers[5] = iup.tabs{
    containers[6],
    containers[11],
    containers[16],
    containers[19],
    ["tabtitle0"] = "Найти",
    ["tabtitle1"] = "Заменить",
    ["tabtitle2"] = "Найти в файлах",
    ["tabtitle3"] = "Метки",
    canfocus  = "NO",
    name = "tabFindRepl",
    tabchange_cb = SetStaticControls,

  }

  containers["zUpDown"] = iup.zbox{
    iup.button{
      impress = "IMAGE_ArrowDown",
      visible = "NO",
      image = "IMAGE_ArrowUp",
      size = "11x9",
      action = (function(h) containers["zUpDown"].valuepos = "1" end),
      name = "btnArrowDown",
    },
    iup.button{
      impress = "IMAGE_ArrowUp",
      visible = "NO",
      image = "IMAGE_ArrowDown",
      size = "11x9",
      action = (function(h) containers["zUpDown"].valuepos = "0" end),
      name = "btnArrowUp",
    },
    name = "zUpDown",
    valuepos = "1",
  }

  containers["hUpDown"] = iup.hbox{
    containers["zUpDown"],
    iup.label{
      title = "Направление",
      button_cb = (function(_,but, pressed, x, y, status)
        if iup.isbutton1(status) and pressed == 0 and Ctrl('btnArrowUp').active == "YES" then
            containers["zUpDown"].valuepos = Iif(containers["zUpDown"].valuepos == '0', '1', '0')
        end
      end),
    },
    margin = "0x00",
    gap = "00",
  }

  containers[26] = iup.vbox{
    containers["hUpDown"],
    iup.toggle{
      title = "Слово целиком",
      name = "chkWholeWord",
      map_cb = (function(h)  h.value = _G["dialogs.findreplace."..h.name] end),
      ldestroy_cb = (function(h) _G["dialogs.findreplace."..h.name] = h.value end),
    },
    iup.toggle{
      title = "Учитывать регистр",
      name = "chkMatchCase",
    },
    iup.toggle{
      title = "Зациклить поиск",
      name = "chkWrapFind",
      value = "ON",
    },
  }

  containers[28] = iup.hbox{
    iup.toggle{
      title = "Только в стиле:",
      name = "chkInStyle",
      action = SetStaticControls,
    },
    iup.text{
      mask = "[0-9]+",
      name = "numStyle",
      size = "22x10",
      font = "Segoe UI, 8",
    },
    margin = "0x00",
  }

  containers[27] = iup.vbox{
    iup.toggle{
      title = "Backslash (\\n,\\r,\\t...)",
      name = "chkBackslash",
    },
    iup.toggle{
      title = "Регулярные выражения",
      name = "chkRegExp",
      action = SetStaticControls,
    },
    containers[28],
    iup.label{
      name = "lblInfo",
      expand = "HORIZONTAL",
    },
  }

  containers[25] = iup.hbox{
    containers[26],
    containers[27],
  }

  containers[24] = iup.frame{
    containers[25],
  }

  containers[23] = iup.hbox{
    containers[24],
    margin = "3x2",
  }

  containers[2] = iup.vbox{fontsize=iup.GetGlobal("DEFAULTFONTSIZE"),
    containers[3],
    containers[5],
    containers[23],
    margin = "3x3",
    expandchildren = "YES",
    gap = "3",
    name = 'vboxFindRepl'
  }

--[[  containers[1] = iup.dialog{
    containers[2],
    maxbox = "NO",
    minbox = "NO",
    minsize = "384x270",
    toolbox = "YES",
  }]]

  return containers[2]
end

local function Init(h)
    _Plugins = h
    CORE.ActivateFind = ActivateFind_l --глобальная ссылка на нашу функцию

    oDeattFnd = iup.scitedetachbox{
        create_dialog_FindReplace();
        orientation="HORIZONTAL";barsize=5;minsize="100x100";name="FindReplDetach";defaultesc="FIND_BTN_ESC";
        k_any= (function(h,c) if c == iup.K_CR then DefaultAction() elseif c == iup.K_ESC then PassOrClose() end end),
        sciteid = 'findrepl';  Dlg_Title = "Поиск и замена"; expand='HORIZONTAL'; buttonImage='IMAGE_search'; onFormSetStaticControls = SetStaticControls;
        On_Detach = (function(h, hNew, x, y)
            iup.SetHandle("FIND_BTN_ESC",Ctrl('btn_esc'))
            local hMainLayout = iup.GetLayout()
             if not _Plugins.findrepl.Bar_obj then
                _G.iuprops['sidebarctrl.BottomSplit2.value'] = iup.GetDialogChild(hMainLayout, "BottomSplit2").value
                iup.GetDialogChild(hMainLayout, "BottomSplit2").barsize="0"
                iup.GetDialogChild(hMainLayout, "BottomSplit2").value="1000"
            else
                iup.GetDialogChild(hMainLayout, "FinReplExp").state="CLOSE";
            end
            popUpFind = hNew
            if _G.iuprops["sidebarctrl.zPin.unpinned.value"] then Ctrl("zPin").valuepos = _G.iuprops["sidebarctrl.zPin.unpinned.value"] end
        end);
        Dlg_Close_Cb = (function(h)
            local hMainLayout = iup.GetLayout()
            if not _Plugins.findrepl.Bar_obj then
                iup.GetDialogChild(hMainLayout, "BottomSplit2").value = _G.iuprops['sidebarctrl.BottomSplit2.value']
                iup.GetDialogChild(hMainLayout, "BottomSplit2").barsize="3"
            else
                iup.GetDialogChild(hMainLayout, "FinReplExp").state="OPEN";
            end
            _G.iuprops["sidebarctrl.zPin.unpinned.value"] = Ctrl("zPin").valuepos
        end);
        }
    local hboxPane = iup.GetDialogChild(oDeattFnd, 'findrepl_title_hbox')
    if hboxPane then
        local pin = Ctrl("zPin")
        iup.Detach(pin)
        iup.Insert(hboxPane, iup.GetDialogChild(oDeattFnd, "findrepl_title_btnattach"), pin)
    end

    Ctrl('tabFindRepl').rightclick_cb = (function()
        menuhandler:PopUp('MainWindowMenu¦View¦findrepl')
    end)


    _Plugins.findrepl = {
        handle = iup.vbox{oDeattFnd,font=iup.GetGlobal("DEFAULTFONT")};
        OnMenuCommand = (function(msg)
            if msg == IDM_FIND then return ActivateFind_l(0)
            elseif msg == IDM_REPLACE then return ActivateFind_l(1)
            elseif msg == IDM_FINDINFILES then return ActivateFind_l(2)
            elseif msg == IDM_FINDNEXT then
                ReadSettings()
                return FindNextBack(false)
            elseif msg == IDM_FINDNEXTBACK then
                ReadSettings()
                return FindNextBack(true)
            elseif msg == IDM_FINDNEXTSEL then return FindNextSel(false)
            elseif msg == IDM_FINDNEXTBACKSEL then return FindNextSel(true)
            end
        end);
        tabs_OnSelect = (function()
            if _Plugins.findrepl.Bar_obj and _Plugins.findrepl.Bar_obj.TabCtrl.value_handle.tabtitle == _Plugins.findrepl.id and not _G.dialogs['findrepl'] then
                iup.SetFocus(Ctrl("cmbFindWhat"))
            end
        end);
        }
    _Plugins.findrepl.handle_deattach = oDeattFnd
    _Plugins.findrepl.OnCreate = (function()
            SetStaticControls()
    end)

    AddEventHandler("OnFindCompleted", (function()
        findSettings:MarkResult()
    end))
end

return {
    title = 'Find Replace Dialog',
    code = 'findrepl',
    sidebar = Init,
    fixedheigth = true,
    description = [[Диалог поиска и замены. Если не подключить
ни к одной из панелей неиспользованных элементах
будет задочен в правом нижнем углу экрана]]
}


