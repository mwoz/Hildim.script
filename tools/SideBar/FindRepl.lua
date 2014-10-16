local containers

local function create_dialog_FindReplace()
  containers = {}

  containers[4] = iup.hbox{
    iup.label{
      title = "�����:",
    },
    iup.list{
      name = "cmbFind",
      expand = "HORIZONTAL",
      rastersize = "1x0",
      editbox = "YES",
      dropdown = "YES",
      visible_items = "15",
      map_cb = (function(h) h:FillByHist("find.what.history","find.what") end),
    },
    iup.toggle{
      impress = "IMAGE_PinPush",
      image = "IMAGE_Pin",
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

  containers[7] = iup.hbox{
    iup.button{
      image = "IMAGE_search",
      title = " �����",
      name = "btnFind",
    },
    iup.button{
      title = "����� ���",
    },
    iup.button{
      title = "�� ��������",
    },
    iup.button{
      title = "����������",
    },
    normalizesize = "HORIZONTAL",
    gap = "3",
    alignment = "ABOTTOM",
  }

  containers[10] = iup.hbox{
    iup.toggle{
      title = "�����",
    },
    iup.toggle{
      title = "����",
      value = "ON",
    },
  }

  containers[9] = iup.radio{
    containers[10],
  }

  containers[8] = iup.hbox{
    iup.label{
      title = "����������� ������(������)",
    },
    containers[9],
    alignment = "ACENTER",
  }

  containers[6] = iup.vbox{
    containers[7],
    containers[8],
    expandchildren = "YES",
    gap = "4",
  }

  containers[13] = iup.vbox{
    iup.button{
      title = "�������� ��:",
    },
    iup.button{
      title = "����� �����",
    },
    normalizesize = "HORIZONTAL",
  }

  containers[15] = iup.hbox{
    iup.button{
      title = "�������� ���",
    },
    iup.button{
      title = "� ����������",
    },
    iup.button{
      title = "�� ��������",
    },
    margin = "0x00",
  }

  containers[14] = iup.vbox{
    iup.list{
      name = "cmbReplace",
      expand = "HORIZONTAL",
      rastersize = "1x0",
      editbox = "YES",
      dropdown = "YES",
      visible_items = "15",
      map_cb = (function(h) h:FillByHist("find.replasewith.history",nil) end),
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
      title = "� ������:",
    },
    iup.list{
      name = "cmbFolders",
      expand = "HORIZONTAL",
      rastersize = "1x0",
      editbox = "YES",
      dropdown = "YES",
      visible_items = "15",
      map_cb = (function(h) h:FillByHist("find.directory.history","find.directory.history") end),
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
      title = "������:",
    },
    iup.list{
      name = "cmbFilter",
      expand = "HORIZONTAL",
      rastersize = "1x0",
      editbox = "YES",
      dropdown = "YES",
      visible_items = "15",
      map_cb = (function(h) h:FillByHist("find.files.history",nil) end),
    },
    iup.toggle{
      name = "chkSubFolders",
      title = "� ���������",
      map_cb = (function(h) h.value = Iif(props['find.in.subfolders'] == '1', 'ON', 'OFF') end),
    },
    iup.button{
      title = "������",
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
      title = "��������",
    },
    iup.button{
      title = "��������",
    },
    iup.button{
      title = "�������� ���",
    },
    margin = "0x00",
    normalizesize = "HORIZONTAL",
  }

  containers[20] = iup.hbox{
    iup.label{
      title = "�����:",
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
      title = "�������� ����������",
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
    ["tabtitle0"] = "�����",
    ["tabtitle1"] = "��������",
    ["tabtitle2"] = "����� � ������",
    ["tabtitle3"] = "�����",
  }

  containers[26] = iup.vbox{
    iup.toggle{
      title = "����� �������",
    },
    iup.toggle{
      title = "��������� �������",
    },
    iup.toggle{
      title = "��������� �����",
    },
  }

  containers[28] = iup.hbox{
    iup.toggle{
      title = "������ � �����:",
    },
    iup.text{
      mask = "[0-9,]+",
    },
    margin = "0x00",
  }

  containers[27] = iup.vbox{
    iup.toggle{
      title = "Backslash-���������(\\n,\\r,\\t...)",
    },
    iup.toggle{
      title = "���������� ���������",
    },
    containers[28],
  }

  containers[25] = iup.hbox{
    containers[26],
    containers[27],
  }

  containers[24] = iup.frame{
    containers[25],
    title = "����� ������",
    size = "241x49",
  }

  containers[23] = iup.hbox{
    containers[24],
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
            hNew.title="����� � ������"
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
--[[            hNew.map_cb = (function(h)
                print(chk_Pin.image)
                chk_Pin.impress = "IMAGE_PinPush"
                chk_Pin.image = "IMAGE_Pin"
            end)]]
            if tonumber(props["dialogs.findrepl.x"])== nil or tonumber(props["dialogs.findrepl.y"]) == nil then props["dialogs.findrepl.x"]=0;props["dialogs.findrepl.y"]=0 end
            return tonumber(props["dialogs.findrepl.x"])*2^16+tonumber(props["dialogs.findrepl.y"])
        end)
        }

    SideBar_obj.Tabs.findrepl = {
        handle = iup.vbox{oDeatt};

        }
end

FuncBmkTab_Init()
