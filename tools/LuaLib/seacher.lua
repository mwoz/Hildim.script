
local s = class()

function s:destroy()
    print("simple:destroy()")
end

function s:init(t)
    self.wholeWord   = t.wholeWord
    self.matchCase   = t.matchCase
    self.wrapFind    = t.wrapFind
    self.backslash   = t.backslash
    self.regExp      = t.regExp
    self.style       = t.style
    self.searchUp    = t.searchUp
    self.findWhat    = t.findWhat
    self.replaceWhat = t.replaceWhat
    self.e = editor
    self.send = scite.SendEditor
end

function s:UnSlashAsNeeded(strIn)
    local str
    if self.backslash and not self.regExp then
        str = strIn:gsub('\\\\', '¦'):gsub('\\a', '\a'):gsub('\\b', '\b'):gsub('\\f', '\f'):gsub('\\n', '\n'):gsub('\\r', '\r'):gsub('\\t', '\t'):gsub('\\v', '\v'):gsub('¦', '\\')
    else
        str = strIn
    end
    if str == nil then return "", 0 end
    local strLen = str:len()
    return str, strLen
end

function s:encode(s)
    if self.e.CodePage ~= 0 then return s:to_utf8(1251) end
    return s
end

function s:Reset(t)
    self.wholeWord   = t.wholeWord
    self.matchCase   = t.matchCase
    self.wrapFind    = t.wrapFind
    self.backslash   = t.backslash
    self.regExp      = t.regExp
    self.style       = t.style
    self.searchUp    = t.searchUp
    self.findWhat    = t.findWhat
    self.replaceWhat = t.replaceWhat
    if t.inFindRez then
        self.e = findres
        self.send = scite.SendFindRes
    else
        self.e = editor
        self.send = scite.SendEditor
    end
end

function s:EditorMarkText(start, length, indic_number)
	local current_indic_number = self.send(SCI_GETINDICATORCURRENT)
	self.send(SCI_SETINDICATORCURRENT, indic_number)
	self.send(SCI_INDICATORFILLRANGE, start, length)
	self.send(SCI_SETINDICATORCURRENT, current_indic_number)
end

-- Очистка текста от маркерного выделения заданного стиля
--   если параметры отсутствуют - очищаются все стили во всем тексте
--   если не указана позиция и длина - очищается весь текст
function s:EditorClearMarks(indic_number, start, length)
	local _first_indic, _end_indic
	local current_indic_number = self.send(SCI_GETINDICATORCURRENT)
	if indic_number == nil then
		_first_indic, _end_indic = 0, 31
	else
		_first_indic, _end_indic = indic_number, indic_number
	end
	if start == nil then
		start, length = 0, findres.Length
	end
	for indic = _first_indic, _end_indic do
		self.send(SCI_SETINDICATORCURRENT, indic)
		self.send(SCI_INDICATORCLEARRANGE, start, length)
	end
	self.send(SCI_SETINDICATORCURRENT, current_indic_number)
end

function s:FindInTarget(findWhat, lenFind, startPosition, endPosition)
    self.send(SCI_SETTARGETSTART, startPosition)
    self.send(SCI_SETTARGETEND, endPosition)

    local posFind = self.e:SearchInTarget(findWhat)
	while (self.style ~= nil and posFind ~= -1 and self.style ~= self.send(SCI_GETSTYLEAT, posFind)) do
		if startPosition < endPosition then
			self.send(SCI_SETTARGETSTART, posFind + 1)
			self.send(SCI_SETTARGETEND, endPosition)
		else
			self.send(SCI_SETTARGETSTART, startPosition)
			self.send(SCI_SETTARGETEND, posFind + 1)
		end
		posFind = self.e:SearchInTarget(findWhat)
	end
	return posFind;
end

function s:FindNext(fireEvent)

    if self.findWhat == nil or self.findWhat:len() == 0 then
        return -1
		-- Find();
	end

	local findTarget, lenFind = self:UnSlashAsNeeded(self.findWhat)
	if (lenFind == 0) then return -1 end

	local startPosition = Iif(self.searchUp, self.e.SelectionStart, self.e.SelectionEnd)
	local endPosition = Iif(self.searchUp, 0, self.e.Length)

	local flags = Iif(self.wholeWord, SCFIND_WHOLEWORD, 0) +
	        Iif(self.matchCase, SCFIND_MATCHCASE, 0) +
	        Iif(self.regExp, SCFIND_REGEXP, 0) +
	        Iif(props["find.replace.regexp.posix"]=='1', SCFIND_POSIX, 0)

	self.send(SCI_SETSEARCHFLAGS, flags)
	local posFind = self:FindInTarget(findTarget, findLen, startPosition, endPosition)

	if posFind == -1 and  self.wrapFind then
		-- // Failed to find in indicated direction
		-- // so search from the beginning (forward) or from the end (reverse)
		-- // unless wrapFind is false

        startPosition = Iif(self.searchUp, self.e.Length, 0)
        endPosition = Iif(self.searchUp, 0, self.e.Length)

		posFind = self:FindInTarget(findTarget, findLen, startPosition, endPosition)
		-- WarnUser(warnFindWrapped);
	end
	if posFind ~= -1 then

		-- //Вызовем нотификацию в скрипте
		if fireEvent then OnNavigation("Find") end

		local start = self.e.TargetStart
		local fin = self.e.TargetEnd
        self.e:EnsureVisibleEnforcePolicy(self.e:LineFromPosition(start))
        -- self.e:EnsureVisible(start, fin)
		-- EnsureRangeVisible;

        self.e:SetSel(start, fin)

        if fireEvent then OnNavigation("Find-") end
	end
	return posFind;
end

function s:ReplaceOnce()
--[[	if (!FindHasText())
		return;]]
    if self.searchUp then
        self.e:SetSel(self.e.SelectionEnd, self.e.SelectionEnd)
    else
        self.e:SetSel(self.e.SelectionStart, self.e.SelectionStart)
    end
	local pos = self:FindNext(true);

	if pos > -1 then
        local replaceTarget, replaceLen = self:UnSlashAsNeeded(self.replaceWhat)

		local lenReplaced = replaceLen;
		if self.regExp then
			lenReplaced = self.e:ReplaceTargetRE(replaceTarget);
		else
			self.e:ReplaceTarget(replaceTarget)
        end
        if self.searchUp then
            self.e:SetSel(pos, pos)
        else
            self.e:SetSel(pos + lenReplaced, pos + lenReplaced)
        end

		self:FindNext(true);
	end
    return pos
end

function s:onMarkOne(iMark, bClear)
    if bClear then self:EditorClearMarks(iMark) end
    return (function(lenTarget)
        if lenTarget then
            self:EditorMarkText(self.e.TargetStart, lenTarget, iMark)
            return lenTarget, true
        else
            return true
        end
    end)
end

function s:replaceOne()
    local replaceTarget, replaceLen = self:UnSlashAsNeeded(self.replaceWhat)
    return (function(lenTarget)
        local lenReplaced = replaceLen
        if lenTarget then
            if self.regExp then
                lenReplaced = self.e:ReplaceTargetRE(replaceTarget);
            else
                self.e:ReplaceTarget(replaceTarget)
            end
            return lenReplaced, true
        else
            return true
        end
    end)
end

function s:CollapseFindRez()
    scite.MenuCommand(IDM_FINDRESENSUREVISIBLE)
    local j = 0
    local lMax = _G.iuprops['findres.maxresultcount'] or 10
    for line = 0, findres.LineCount do
        if findres.StyleAt[findres:PositionFromLine(line)] == 1 then
            j = j + 1
            if j > lMax then
                findres.TargetStart = findres:PositionFromLine(line)
                findres.TargetEnd = findres.Length
                findres:ReplaceTarget('')
                break
            end
        end
    end

    for line = 0, findres.LineCount do
        local level = scite.SendFindRes(SCI_GETFOLDLEVEL, line)
        if (shell.bit_and(level,SC_FOLDLEVELHEADERFLAG)~=0 and SC_FOLDLEVELBASE + 1 == shell.bit_and(level,SC_FOLDLEVELNUMBERMASK))then
            scite.SendFindRes(SCI_SETFOLDEXPANDED, line)
            local lineMaxSubord = scite.SendFindRes(SCI_GETLASTCHILD, line,-1)
            if line < lineMaxSubord then scite.SendFindRes(SCI_HIDELINES, line + 1, lineMaxSubord) end
        end
    end
end

function s:onFindAll(maxlines, bLive, bColapsPrev, strIn, bSearchCapt)
    if bColapsPrev and bSearchCapt then self:CollapseFindRez() end

    local strLive = Iif(bLive, "/\\", "")
    local needCoding = (self.e.CodePage ~= 0)
    scite.SendFindRes(SCI_SETSEL,0,0)
    local line, wCount, lCount = -1, 0, 0
    return (function(lenTarget)
        if lenTarget then
            wCount = wCount + 1
            local l = self.e:LineFromPosition(self.e.TargetStart)
            if l~=line then
                lCount = lCount + 1
                line = l
                local lNum
                if not _G.iuprops['findres.groupbyfile'] then
                    if bSearchCapt then lNum = '.\\:'..(l+1)..': '
                    else lNum = props["FilePath"]:from_utf8(1251)..':'..(l+1)..': ' end
                else
                    lNum = '\t'..(l+1)..': '
                end
                if lCount == maxlines then
                    scite.SendFindRes(SCI_REPLACESEL, lNum..'...\n')
                    return lenTarget, false
                end
                local str = self.e:GetLine(l):gsub('^[ \t]+', '')
                if needCoding then str = str:from_utf8(1251) end
                scite.SendFindRes(SCI_REPLACESEL, lNum..str )
             end
            return lenTarget, true
        else
            if bSearchCapt then scite.SendFindRes(SCI_REPLACESEL, '<'..strLive..'\n' ) end
            scite.SendFindRes(SCI_SETSEL,0,0)
            local strCapt = ''
            local strSrch = self.findWhat
            if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then strSrch = self.findWhat:from_utf8(1251) end
            if bSearchCapt then strCapt = strCapt..'>Search for "'..strSrch..'" in "'..props[Iif(_G.iuprops['findres.groupbyfile'], "FileNameExt", "FilePath")]:from_utf8(1251)..'" ('..strIn..')  Occurrences: '..wCount..' in '..lCount..' lines\n' end

            if _G.iuprops['findres.groupbyfile'] then strCapt = strCapt..' '..props["FilePath"]:from_utf8(1251)..'\n' end
            if bSearchCapt or wCount > 0 then  scite.SendFindRes(SCI_REPLACESEL, strCapt) end

            scite.SendFindRes(SCI_SETSEL,0,0)
            findres.CurrentPos = 1
            if scite.SendFindRes(SCI_LINESONSCREEN) == 0 then scite.MenuCommand(IDM_TOGGLEOUTPUT) end

            return wCount, lCount
        end
    end)
end

function s:findWalk(inSelection, funcOnFind)
    local findTarget, findLen = self:UnSlashAsNeeded(self.findWhat)

    if findLen == 0 then return -1 end
	local startPosition = self.e.SelectionStart;
	local endPosition = self.e.SelectionEnd;
	local countSelections = self.send(SCI_GETSELECTIONS)
    if inSelection then
        if self.send(SCI_GETSELECTIONMODE) == SC_SEL_LINES then
            startPosition = self.e:PositionFromLine(self.e:LineFromPosition(startPosition))
            endPosition = self.e:PositionFromLine(self.e:LineFromPosition(endPosition) + 1)
        else
            for i = 0, countSelections - 1 do
                startPosition = Min(startPosition, self.send(SCI_GETSELECTIONNSTART, i))
                endPosition = Max(endPosition, self.send(SCI_GETSELECTIONNEND, i))
            end
        end
        if startPosition == endPosition then return -2 end
    else
        if self.searchUp or self.wrapFind then startPosition = 0 end
        if (not self.searchUp) or self.wrapFind then endPosition = self.e.Length end
    end

    --local replaceTarget, replaceLen = self:UnSlashAsNeeded(self.replaceWhat)
	local flags = Iif(self.wholeWord, SCFIND_WHOLEWORD, 0) +
	        Iif(self.matchCase, SCFIND_MATCHCASE, 0) +
	        Iif(self.regExp, SCFIND_REGEXP, 0) +
	        Iif(props["find.replace.regexp.posix"]=='1', SCFIND_POSIX, 0)
	self.send(SCI_SETSEARCHFLAGS, flags)
	local posFind = self:FindInTarget(findTarget, findLen, startPosition, endPosition);
	if (findLen == 1) and self.regExp and findTarget:byte() == string.byte('^') then
		-- // Special case for replace all start of line so it hits the first line
		posFind = startPosition;
		self.send(SCI_SETTARGETSTART, startPosition)
		self.send(SCI_SETTARGETEND, startPosition)
	end
	if (posFind ~= -1) and (posFind <= endPosition) then
		local lastMatch = posFind;
		local replacements = 0;
        self.e:BeginUndoAction()
		-- // Replacement loop
		while posFind ~= -1 do
            local bContinue = true
            repeat  --фейковый цикл, чтобы брек сработал как continue
                local lenTarget = self.send(SCI_GETTARGETEND) - self.send(SCI_GETTARGETSTART)
                local insideASelection = true
                if inSelection and countSelections > 1 then
                    -- // We must check that the found target is entirely inside a selection
                    insideASelection = false
                    for i=0, countSelections - 1 do
                        local startPos= self.send(SCI_GETSELECTIONNSTART, i)
                        local endPos = self.send(SCI_GETSELECTIONNEND, i)
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
                            posFind = self:FindInTarget(findTarget, findLen, lastMatch, endPosition);
                        end
                        break --continue;	--// No replacement
                    end
                end
                local movepastEOL = 0;
                if lenTarget <= 0 then
                    local chNext = self.send(SCI_GETCHARAT, wEditor.Call(SCI_GETTARGETEND))
                    if chNext == '\r' or chNext == '\n' then movepastEOL = 1 end
                end
                local lenReplaced
                lenReplaced, bContinue = funcOnFind(lenTarget);

                -- // Modify for change caused by replacement
                endPosition = endPosition + lenReplaced - lenTarget;
                -- // For the special cases of start of line and end of line
                -- // something better could be done but there are too many special cases
                lastMatch = posFind + lenReplaced + movepastEOL;
                if lenTarget == 0 then lastMatch = self.e:PositionAfter(lastMatch) end
                if lastMatch >= endPosition then
                    -- // Run off the end of the document/selection with an empty match
                    posFind = -1;
                else
                    posFind = self:FindInTarget(findTarget, findLen, lastMatch, endPosition);
                end
                replacements = replacements + 1
		    until true
            if not bContinue then break end
        end
        local out1, out2 = funcOnFind(nil)
        if inSelection then
            if countSelections == 1 then self.send(SCI_SETSEL, startPosition, endPosition) end
        else
            --if props["find.replace.return.to.start"] ~= '1' then self.e:SetSel(lastMatch, lastMatch) end
        end

        self.e:EndUndoAction()
		return replacements, out1, out2
	end
	return 0, funcOnFind(nil);
end

function s:ReplaceAll(inSel)
    return self:findWalk(inSel, self:replaceOne())
end

function s:MarkResult()
    self.e = findres
    self.send = scite.SendFindRes
    local origStyle = self.style
    local origFind = self.findWhat
    if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then self.findWhat = self.findWhat:from_utf8(1251) end
    self.style = SCE_SEARCHRESULT_CURRENT_LINE
    local p
    for i = 1, findres.LineCount - 1 do
        p = findres:PositionFromLine(i)
        if findres.StyleAt[p + 1] == SCE_SEARCHRESULT_SEARCH_HEADER then break end
    end
    if not p then return end
    if p > 0 then
        findres:SetSel(0,p)
        findres:Colourise(0,p)
        self:findWalk(true, self:onMarkOne(31, false))
        findres:SetSel(0,0)
    end

    self.style = origStyle
    self.findWhat = origFind
    self.e = editor
    self.send = scite.SendEditor
end

function s:FindAll(maxlines, bLive)
    local rez = self:findWalk(false, self:onFindAll(maxlines, bLive, true, 'Current', true))
    self:MarkResult()
    return rez
end

function s:FindInBufer()
    local cnt, lin, fil = 0, 0, 0
    scite.SendFindRes(SCI_SETSEL,0,0)
    scite.SendFindRes(SCI_REPLACESEL, '<\n')
    scite.SendFindRes(SCI_SETSEL,0,0)
    return (function(nBuff, maxlines)
        local bCollapse = true
        local bSetEnding = false
        if nBuff then
            local _,c, l = self:findWalk(false, self:onFindAll(maxlines, bCollapse, nBuff == 0,'Buffer '..(nBuff + 1), false))
            bCollapse = false
            if c > 0 then fil = fil + 1 end
            cnt = cnt + c
            lin = lin + l
        else
            scite.SendFindRes(SCI_SETSEL,0,0)
            local strSrch = self.findWhat
            if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then strSrch = self.findWhat:from_utf8(1251) end
            scite.SendFindRes(SCI_REPLACESEL,'>Search for "'..strSrch..'" in buffers  Occurrences: '..cnt..' in '..lin..' lines in '..fil..' files\n')
            return cnt
        end
    end)
end
function s:ReplaceInBufer()
    local cnt = 0
    return (function(nBuff)
        if nBuff then cnt = cnt + self:findWalk(inSel, self:replaceOne())
        else return cnt
        end
    end)
end

function s:Count()
    return self:findWalk(false, (function(lenTarget) return lenTarget, true; end))
end
function s:MarkAll(bInSel, iMark)
    return self:findWalk(bInSel, self:onMarkOne(iMark, true))
end
function s:BookmarkAll(bInSel)
    return self:findWalk(bInSel, (function(lenTarget) self.e:MarkerAdd(self.e:LineFromPosition(self.e.TargetStart),1); return lenTarget, true; end))
end
_G.seacher = s

