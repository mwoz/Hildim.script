require "seacher"
local containers
local oDeatt

local findSettings = seacher{}

local function Ctrl(s)
    return iup.GetDialogChild(containers[2],s)
end

local function ReadSettings()
    local cv = (function(s) return iup.GetDialogChild(containers[2],s).value end)
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
end

local function ReplaceAll(h)
    ReadSettings()
    findSettings:ReplaceAll(false)
    Ctrl("cmbFindWhat"):SaveHist()
    Ctrl("cmbReplaceWhat"):SaveHist()
    iup.PassFocus()
end

local function ReplaceSel(h)
    ReadSettings()
    findSettings:ReplaceAll(true)
    Ctrl("cmbFindWhat"):SaveHist()
    Ctrl("cmbReplaceWhat"):SaveHist()
    iup.PassFocus()
end

local function FindAll(h)
    ReadSettings()
    findSettings:FindAll(500)
    Ctrl("cmbFindWhat"):SaveHist()
    iup.PassFocus()
end

local function GetCount(h)
    ReadSettings()
    local count = findSettings:Count()
    print(count)
    Ctrl("cmbFindWhat"):SaveHist()
    iup.PassFocus()
end

local function FindNext(h)
    ReadSettings()
    local pos = findSettings:FindNext(true)
    Ctrl("cmbFindWhat"):SaveHist()
    iup.PassFocus()
end

local function ReplaceOnce(h)
    ReadSettings()
    local pos = findSettings:ReplaceOnce()
    Ctrl("cmbFindWhat"):SaveHist()
    Ctrl("cmbReplaceWhat"):SaveHist()
    iup.PassFocus()
end

local function create_dialog_FindReplace()
  containers = {}
  containers["zPin"] = iup.zbox{
    iup.button{
      impress = "IMAGE_Pin",
      visible = "NO",
      image = "IMAGE_PinPush",
      size = "11x9",
      action = (function(h) containers["zPin"].valuepos = "1" end),
    },
    iup.button{
      impress = "IMAGE_PinPush",
      visible = "NO",
      image = "IMAGE_Pin",
      size = "11x9",
      action = (function(h) containers["zPin"].valuepos = "0" end),
    },
    name = "zPin",
    valuepos = "1",
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
      visible_items = "15",
      -- map_cb = (function(h) h:FillByHist("find.what.history","find.what") end),
    },
    containers["zPin"],
    margin = "0x00",
    expand = "HORIZONTAL",
    alignment = "ACENTER",
  }

  containers[3] = iup.frame{
    containers[4],
    expand = "HORIZONTAL",
    rastersize = "372x29",
  }

  containers[7] = iup.hbox{
    iup.button{
      image = "IMAGE_search",
      title = " далее",
      name = "btnFind",
      action = FindNext,
    },
    iup.button{
      title = "Найти все",
      action = FindAll,
    },
    iup.button{
      title = "На вкладках",
    },
    iup.button{
      title = "Подсчитать",
      action = GetCount,
    },
    normalizesize = "HORIZONTAL",
    gap = "3",
    alignment = "ABOTTOM",
  }

  containers[6]= iup.vbox{
    containers[7],
    expandchildren = "YES",
    gap = "4",
  }

  containers[13] = iup.vbox{
    iup.button{
      title = "Заменить на:",
      action = ReplaceOnce,
    },
    iup.button{
      image = "IMAGE_search",
      title = " далее",
      action = FindNext,
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
      visible_items = "15",
      -- map_cb = (function(h) h:FillByHist("find.replasewith.history",nil) end),
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
      visible_items = "15",
      -- map_cb = (function(h) h:FillByHist("find.directory.history","find.directory.history") end),
    },
    iup.button{
      title = "^^",
    },
    iup.button{
      title = "...",
    },
    gap = "3",
    alignment = "ACENTER",
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
      visible_items = "15",
      -- map_cb = (function(h) h:FillByHist("find.files.history",nil) end),
    },
    iup.toggle{
      name = "chkSubFolders",
      title = "В подпапках",
      map_cb = (function(h) h.value = Iif(props['find.in.subfolders'] == '1', 'ON', 'OFF') end),
    },
    iup.button{
      title = "Искать",
    },
    alignment = "ACENTER",
  }

  containers[16] = iup.vbox{
    containers[17],
    containers[18],
    gap = "4",
  }

  containers[21] = iup.hbox{
    iup.button{
      title = "Пометить",
    },
    iup.button{
      title = "Очистить",
    },
    iup.button{
      title = "Очистить все",
    },
    margin = "0x00",
    normalizesize = "HORIZONTAL",
  }

  containers[20] = iup.hbox{
    iup.label{
      title = "Метка:",
    },
    iup.list{
      size = "37x12",
      dropdown = "YES",
    },
    containers[21],
    gap = "4",
    alignment = "ACENTER",
  }

  containers[22] = iup.hbox{
    iup.fill{
    },
    iup.button{
      size = "86x12",
      title = "Пометить закладками",
    },
  }

  containers[19] = iup.vbox{
    containers[20],
    containers[22],
  }

  containers[5] = iup.tabs{
    containers[6],
    containers[11],
    containers[16],
    containers[19],
    ["tabvisible0"] = "YES",
    ["tabvisible1"] = "YES",
    ["tabvisible2"] = "YES",
    ["tabvisible3"] = "YES",
    ["tabtitle0"] = "Найти",
    ["tabtitle1"] = "Заменить",
    ["tabtitle2"] = "Найти в файлах",
    ["tabtitle3"] = "Метки",
    name = "tabFinrRepl"
  }

  containers["zUpDown"] = iup.zbox{
    iup.button{
      impress = "IMAGE_ArrowDown",
      visible = "NO",
      image = "IMAGE_ArrowUp",
      size = "11x9",
      action = (function(h) containers["zUpDown"].valuepos = "1" end),
    },
    iup.button{
      impress = "IMAGE_ArrowUp",
      visible = "NO",
      image = "IMAGE_ArrowDown",
      size = "11x9",
      action = (function(h) containers["zUpDown"].valuepos = "0" end),
    },
    name = "zUpDown",
    valuepos = "1",
  }

  containers["hUpDown"] = iup.hbox{
    containers["zUpDown"],
    iup.label{
      title = "Направление",
      button_cb = (function(_,but, pressed, x, y, status)
        if iup.isbutton1(status) and pressed == 0 then
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
      ldestroy_cb = (function(h)  _G["dialogs.findreplace."..h.name] = h.value end),
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
      title = "Backslash-выражения(\\n,\\r,\\t...)",
      name = "chkBackslash",
    },
    iup.toggle{
      title = "Регулярные выражения",
      name = "chkRegExp",
    },
    containers[28],
    iup.label{
      name = "lblInfo",
      title = "Info"
    },
  }

  containers[25] = iup.hbox{
    containers[26],
    containers[27],
  }

  containers[24] = iup.frame{
    containers[25],
    size = "241x49",
  }

  containers[23] = iup.hbox{
    containers[24],
    margin = "3x2",
  }

  containers[2] = iup.vbox{
    containers[3],
    containers[5],
    containers[23],
    margin = "3x3",
    expandchildren = "YES",
    gap = "3",
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

local function FuncBmkTab_Init()
    oDeatt = iup.detachbox{
        create_dialog_FindReplace();
        orientation="HORIZONTAL";barsize=5;minsize="100x100";
        detached_cb=(function(h, hNew, x, y)
            hNew.resize ="YES"
            hNew.shrink ="YES"
            hNew.minsize="384x270"
            hNew.title="Поиск и замена"
            hNew.maxbox="NO"
            hNew.minbox="NO"
            hNew.toolbox="YES"
            hNew.x=10
            hNew.y=10
            x=10;y=10
            hNew.rastersize = props['dialogs.findrepl.rastersize']
            props['findrepl.win']=1
            props['dialogs.sidebarp.rastersize'] = h.rastersize

            hNew.close_cb =(function(h)
                if _G.dialogs['findrepl'] ~= nil then
                    props['findrepl.win']=0
                    local w = props['dialogs.sidebarp.rastersize']:gsub('x%d*', '')
                    oDeatt.restore = 1
                    _G.dialogs['findrepl'] = nul
                    return -1
                end
            end)
            hNew.show_cb=(function(h,state)
                if state == 0 then
                    _G.dialogs['findrepl'] = oDeatt
                elseif state == 4 then
                    props["dialogs.findrepl.x"]= h.x
                    props["dialogs.findrepl.y"]= h.y
                    props['dialogs.findrepl.rastersize'] = h.rastersize
                end
            end)

            if tonumber(props["dialogs.findrepl.x"])== nil or tonumber(props["dialogs.findrepl.y"]) == nil then props["dialogs.findrepl.x"]=0;props["dialogs.findrepl.y"]=0 end
            return tonumber(props["dialogs.findrepl.x"])*2^16+tonumber(props["dialogs.findrepl.y"])
        end)
        }

    SideBar_obj.Tabs.findrepl = {
        handle = iup.vbox{oDeatt};
--[[		OnSave = OnSwitch;
        OnSwitchFile = OnSwitch;
        OnOpen = OnSwitch;]]
        }
end

FuncBmkTab_Init()
