local containers
local needCoding = false

local findSettings = {}

function findSettings:UnSlashAsNeeded(strIn)
    local str
    if self.backslash and not self.regExp then
        str = strIn:gsub('\\\\', '¦'):gsub('\\a', '\a'):gsub('\\b', '\b'):gsub('\\f', '\f'):gsub('\\n', '\n'):gsub('\\r', '\r'):gsub('\\t', '\t'):gsub('\\v', '\v'):gsub('¦', '\\')
    else
        str = strIn
    end
    local strLen = str:len()
    return str, strLen
end

function findSettings:encode(s)
    if editor.CodePage ~= 0 then return s:to_utf8(1251) end
    return s
end

function findSettings:readSettings()
    local cv = (function(s) return iup.GetDialogChild(containers[2],s).value end)
    self.wholeWord = (cv("chkWholeWord") == "ON")
    self.matchCase = (cv("chkMatchCase") == "ON")
    self.wrapFind = (cv("chkWrapFind") == "ON")
    self.backslash = (cv("chkBackslash") == "ON")
    self.regExp = (cv("chkRegExp") == "ON")
    self.style = Iif(cv("chkInStyle") == "ON",tonumber(cv("numStyle")),nil)
    self.searchUp = (containers["zUpDown"].valuepos == "0")
    self.findWhat = self:encode(cv("cmbFindWhat"))
    self.replaceWhat = self:encode(cv("cmbReplaceWhat"))
end

local function GetSelection()
    local t = {}
    t.cpMim = editor.SelectionStart
    lkjopt.cpMax = editor.SelectionEnd
    return t
end

function replaceOne(fs)
    local replaceTarget, replaceLen = fs:UnSlashAsNeeded(fs.replaceWhat)

    return (function()
        local lenReplaced = replaceLen
        if fs.regExp then
            lenReplaced = editor:ReplaceTargetRE(replaceTarget);
        else
            editor:ReplaceTarget(replaceTarget)
        end
        return lenReplaced
    end)
end


local function FindInTarget(findWhat, lenFind, startPosition, endPosition, fs)
    scite.SendEditor(SCI_SETTARGETSTART, startPosition)
    scite.SendEditor(SCI_SETTARGETEND, endPosition)

    local posFind = editor:SearchInTarget(findWhat)

	while (fs.findInStyle and posFind ~= -1 and fs.findStyle ~= scite.SendEditor(SCI_GETSTYLEAT, posFind)) do
		if startPosition < endPosition then
			scite.SendEditor(SCI_SETTARGETSTART, posFind + 1)
			scite.SendEditor(SCI_SETTARGETEND, endPosition)
		else
			scite.SendEditor(SCI_SETTARGETSTART, startPosition)
			scite.SendEditor(SCI_SETTARGETEND, posFind + 1)
		end
		posFind = editor:SearchInTarget(findWhat)
	end
	return posFind;
end

function findWalk(inSelection, fs, funcOnFind)
    local findTarget, findLen = fs:UnSlashAsNeeded(fs.findWhat)

    if findLen == 0 then return -1 end
	local startPosition = editor.SelectionStart;
	local endPosition = editor.SelectionEnd;
	local countSelections = scite.SendEditor(SCI_GETSELECTIONS)
    if inSelection then
        if scite.SendEditor(SCI_GETSELECTIONS) == SC_SEL_LINES then
            startPosition = editor:PositionFromLine(editor:LineFromPosition(startPosition))
            endPosition = editor:PositionFromLine(editor:LineFromPosition(endPosition) + 1)
        else
            for i = 0, countSelections do
                startPosition = Min(startPosition, scite.SendEditor(SCI_GETSELECTIONNSTART, i))
                startPosition = Max(startPosition, scite.SendEditor(SCI_GETSELECTIONNEND, i))
            end
        end
        if startPosition == endPosition then return -2 end
    else
        if fs.searchUp or fs.wrapFind then startPosition = 0 end
        if (not fs.searchUp) or fs.wrapFind then endPosition = editor.Length end
    end

    local replaceTarget, replaceLen = fs:UnSlashAsNeeded(fs.replaceWhat)
	local flags = Iif(fs.wholeWord, SCFIND_WHOLEWORD, 0) +
	        Iif(fs.matchCase, SCFIND_MATCHCASE, 0) +
	        Iif(fs.regExp, SCFIND_REGEXP, 0) +
	        Iif(props["find.replace.regexp.posix"]=='1', SCFIND_POSIX, 0)
	scite.SendEditor(SCI_SETSEARCHFLAGS, flags)
	local posFind = FindInTarget(findTarget, findLen, startPosition, endPosition, fs);
	if (findLen == 1) and fs.regExp and findTarget:byte() == string.byte('^') then
		-- // Special case for replace all start of line so it hits the first line
		posFind = startPosition;
		scite.SendEditor(SCI_SETTARGETSTART, startPosition)
		scite.SendEditor(SCI_SETTARGETEND, startPosition)
	end
	if (posFind ~= -1) and (posFind <= endPosition) then
		local lastMatch = posFind;
		local replacements = 0;
		scite.SendEditor(SCI_BEGINUNDOACTION)
        editor:BeginUndoAction()
		-- // Replacement loop
		while posFind ~= -1 do
            repeat  --фейковый цикл, чтобы брек сработал как continue
                local lenTarget = scite.SendEditor(SCI_GETTARGETEND) - scite.SendEditor(SCI_GETTARGETSTART)
                local insideASelection = true
                if inSelection and countSelections > 1 then
                    -- // We must check that the found target is entirely inside a selection
                    insideASelection = false
                    for i=0, countSelections - 1 do
                        local startPos= scite.SendEditor(SCI_GETSELECTIONNSTART, i)
                        local endPos = scite.SendEditor(SCI_GETSELECTIONNEND, i)
                        if posFind >= startPos and posFind + lenTarget <= endPos then
                            insideASelection = true
                            break
                        end
                    end
                    if not insideASelection then
                        -- // Found target is totally or partly outside the selections
                        lastMatch = posFind + 1;
                        if lastMatch >= endPosition then
                            -- // Run off the end of the document/selection with an empty match
                            posFind = -1;
                        else
                            posFind = FindInTarget(findTarget, findLen, lastMatch, endPosition, fs);
                        end
                        break --continue;	--// No replacement
                    end
                end
                local movepastEOL = 0;
                if lenTarget <= 0 then
                    local chNext = scite.SendEditor(SCI_GETCHARAT, wEditor.Call(SCI_GETTARGETEND))
                    if chNext == '\r' or chNext == '\n' then movepastEOL = 1 end
                end

                local lenReplaced = funcOnFind();

                -- // Modify for change caused by replacement
                endPosition = endPosition + lenReplaced - lenTarget;
                -- // For the special cases of start of line and end of line
                -- // something better could be done but there are too many special cases
                lastMatch = posFind + lenReplaced + movepastEOL;
                if lenTarget == 0 then lastMatch = editor:PositionAfter(lastMatch) end
                if lastMatch >= endPosition then
                    -- // Run off the end of the document/selection with an empty match
                    posFind = -1;
                else
                    posFind = FindInTarget(findTarget, findLen, lastMatch, endPosition, fs);
                end
                replacements = replacements + 1
		    until true
        end
        if inSelection then
			if countSelections == 1 then scite.SendEditor(SCI_SETSEL, startPosition, endPosition) end
		else
			if props["find.replace.return.to.start"] ~= '1' then editor:SetSel(lastMatch, lastMatch) end
		end
        editor:EndUndoAction()
		return replacements
	end
	return 0;
end

local function RaplaceAll(h)
    findSettings:readSettings()
    findWalk(false, findSettings, replaceOne(findSettings))
end

local function create_dialog_FindReplace()
  containers = {}
  containers["Pin"] = iup.zbox{
    iup.button{
      impress = "IMAGE_Pin",
      visible = "NO",
      image = "IMAGE_PinPush",
      size = "11x9",
      action = (function(h) containers["Pin"].valuepos = "1" end),
    },
    iup.button{
      impress = "IMAGE_PinPush",
      visible = "NO",
      image = "IMAGE_Pin",
      size = "11x9",
      action = (function(h) containers["Pin"].valuepos = "0" end),
    },
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
      map_cb = (function(h) h:FillByHist("find.what.history","find.what") end),
    },
    containers["Pin"],
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

  containers[6]= iup.vbox{
    containers[7],
    expandchildren = "YES",
    gap = "4",
  }

  containers[13] = iup.vbox{
    iup.button{
      title = "Заменить на:",
    },
    iup.button{
      title = "Найти далее",
    },
    normalizesize = "HORIZONTAL",
  }

  containers[15] = iup.hbox{
    iup.button{
      title = "Заменить все",
      action = RaplaceAll
    },
    iup.button{
      title = "В выделенном",
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
      title = "В папках:",
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
      title = "Фильтр:",
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
    valuepos = "1",
  }

  containers["hUpDown"] = iup.hbox{
    containers["zUpDown"],
    iup.label{
      title = "Направление",
    },
    margin = "0x00",
    gap = "00",
  }

  containers[26] = iup.vbox{
    containers["hUpDown"],
    iup.toggle{
      title = "Слово целиком",
      name = "chkWholeWord",
    },
    iup.toggle{
      title = "Учитывать регистр",
      name = "chkMatchCase",
    },
    iup.toggle{
      title = "Зациклить поиск",
      name = "chkWrapFind",
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
local function OnSwitch()
    needCoding = (editor.CodePage ~= 0)
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
		OnSave = OnSwitch;
        OnSwitchFile = OnSwitch;
        OnOpen = OnSwitch;
        }
end

FuncBmkTab_Init()
