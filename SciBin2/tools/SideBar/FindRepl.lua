local containers

local function create_dialog_FindReplace()
  containers = {}

  containers[3] = iup.hbox{
    iup.label{
      title = "Найти:",
    },
    iup.list{
      expand = "HORIZONTAL",
      editbox = "YES",
      dropdown = "YES",
    },
    iup.toggle{
      impress = "IMAGE_PinPush",
      tip = "fdgdf",
      image = "IMAGE_Pin",
    },
    expand = "HORIZONTAL",
    alignment = "ACENTER",
  }

  containers[6] = iup.hbox{
    iup.button{
      title = "Найти далее",
    },
    iup.button{
      title = "Найти все",
    },
    iup.button{
      title = "На вкладках",
    },
    iup.button{
      title = "Подсчитать",
    },
    normalizesize = "HORIZONTAL",
    gap = "3",
    alignment = "ABOTTOM",
  }

  containers[9] = iup.hbox{
    iup.toggle{
      title = "Вверх",
    },
    iup.toggle{
      title = "Вниз",
      value = "ON",
    },
  }

  containers[8] = iup.radio{
    containers[9],
  }

  containers[7] = iup.hbox{
    iup.label{
      title = "Направление поиска(эамены)",
    },
    containers[8],
    alignment = "ACENTER",
  }

  containers[5] = iup.vbox{
    containers[6],
    containers[7],
    expandchildren = "YES",
    gap = "4",
  }

  containers[12] = iup.vbox{
    iup.button{
      title = "Заменить на:",
    },
    iup.button{
      title = "Найти далее",
    },
    normalizesize = "HORIZONTAL",
  }

  containers[14] = iup.hbox{
    iup.button{
      title = "Заменить все",
    },
    iup.button{
      title = "В выделенном",
    },
    iup.button{
      title = "На вкладках",
    },
    margin = "0x00",
  }

  containers[13] = iup.vbox{
    iup.list{
      expand = "HORIZONTAL",
      editbox = "YES",
      dropdown = "YES",
    },
    containers[14],
    alignment = "ARIGHT",
  }

  containers[11] = iup.hbox{
    containers[12],
    containers[13],
    normalizesize = "VERTICAL",
    gap = "3",
    alignment = "ACENTER",
  }

  containers[10] = iup.vbox{
    containers[11],
    gap = "4",
  }

  containers[16] = iup.hbox{
    iup.label{
      title = "В папках:",
    },
    iup.list{
      expand = "HORIZONTAL",
      editbox = "YES",
      dropdown = "YES",
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

  containers[17] = iup.hbox{
    iup.label{
      size = "31x8",
      title = "Фильтр:",
    },
    iup.list{
      expand = "HORIZONTAL",
      editbox = "YES",
      dropdown = "YES",
    },
    iup.toggle{
      title = "В подпапках",
    },
    iup.button{
      title = "Искать",
    },
    alignment = "ACENTER",
  }

  containers[15] = iup.vbox{
    containers[16],
    containers[17],
    gap = "4",
  }

  containers[20] = iup.hbox{
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

  containers[19] = iup.hbox{
    iup.label{
      title = "Метка:",
    },
    iup.list{
      size = "37x12",
      dropdown = "YES",
    },
    containers[20],
    gap = "4",
    alignment = "ACENTER",
  }

  containers[21] = iup.hbox{
    iup.fill{
    },
    iup.button{
      size = "86x12",
      title = "Пометить закладками",
    },
  }

  containers[18] = iup.vbox{
    containers[19],
    containers[21],
  }

  containers[4] = iup.tabs{
    containers[5],
    containers[10],
    containers[15],
    containers[18],
    ["tabvisible0"] = "YES",
    ["tabvisible1"] = "YES",
    ["tabvisible2"] = "YES",
    ["tabvisible3"] = "YES",
    ["tabtitle0"] = "Найти",
    ["tabtitle1"] = "Заменить",
    ["tabtitle2"] = "Найти в файлах",
    ["tabtitle3"] = "Метки",
  }

  containers[25] = iup.vbox{
    iup.toggle{
      title = "Слово целиком",
    },
    iup.toggle{
      title = "Учитывать регистр",
    },
    iup.toggle{
      title = "Зациклить поиск",
    },
  }

  containers[27] = iup.hbox{
    iup.toggle{
      title = "Только в стиле:",
    },
    iup.text{
      mask = "[0-9,]+",
    },
    margin = "0x00",
  }

  containers[26] = iup.vbox{
    iup.toggle{
      title = "Backslash-выражения(\\n,\\r,\\t...)",
    },
    iup.toggle{
      title = "Регулярные выражения",
    },
    containers[27],
  }

  containers[24] = iup.hbox{
    containers[25],
    containers[26],
  }

  containers[23] = iup.frame{
    containers[24],
    title = "Режим поиска",
    size = "241x49",
  }

  containers[22] = iup.hbox{
    containers[23],
  }

  containers[2] = iup.vbox{
    containers[3],
    containers[4],
    containers[22],
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
                    _G.dialogs['findrepl'] = h
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

        }
end

FuncBmkTab_Init()
