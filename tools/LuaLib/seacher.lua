
local s = class()

function s:resetSt()
    if self.style then
        if self.style then self.style = tostring(self.style)  end
        if self.style == '' then
            self.style = nil
        else
            self.st_exclude = (self.style:find('^%-'))
            self.st_vals = {}
            for s in self.style:gmatch('%d+') do
                table.insert(self.st_vals, tonumber(s))
            end
        end
    else
        self.st_vals = nil
        self.st_exclude = nil
        self.style = nil
    end
end

function s:init(t)
    self.wholeWord   = t.wholeWord
    self.matchCase   = t.matchCase
    self.wrapFind    = t.wrapFind
    self.backslash   = t.backslash
    self.regExp      = t.regExp
    self.style       = tostring(t.style or '')
    self.searchUp    = t.searchUp
    self.findWhat    = t.findWhat
    self.replaceWhat = t.replaceWhat
    self.e = t.e or editor
    self.unicMode = t.unicMode
    self.path = t.path
    self:resetSt()
end

function s:GetUnicMod()
    return self.unicMode or tonumber(props["editor.unicode.mode"])
end

function s:GetPath(bShort)
    if bShort then
        if self.path then
            local _, _, n = self.path:find('([^\\]*)$')
            return (n or ''):from_utf8()
        end
        return props[Iif(_G.iuprops['findres.groupbyfile'], "FileNameExt", "FilePath")]:from_utf8()
    end
    return (self.path or props["FilePath"]):from_utf8()
end

function s:UnSlashAsNeeded(strIn)
    local str
    if self.backslash and not self.regExp then
        str = strIn:gsub('\\\\', '����'):gsub('\\a', '\a'):gsub('\\b', '\b'):gsub('\\f', '\f'):gsub('\\n', '\n'):gsub('\\r', '\r'):gsub('\\t', '\t'):gsub('\\v', '\v'):gsub('����', '\\')
    else
        str = strIn
    end
    if str == nil then return "", 0 end
    local strLen = str:len()
    return str, strLen
end

function s:encode(s)
    if self.e.CodePage == 0 then return s:from_utf8() end
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
    else
        self.e = editor
    end
    self:resetSt()
end

function s:EditorMarkText(start, length, indic_number)
	local current_indic_number = self.e.IndicatorCurrent
	self.e.IndicatorCurrent = indic_number
	self.e:IndicatorFillRange(start, length)
	self.e.IndicatorCurrent = current_indic_number
end

-- ������� ������ �� ���������� ��������� ��������� �����
--   ���� ��������� ����������� - ��������� ��� ����� �� ���� ������
--   ���� �� ������� ������� � ����� - ��������� ���� �����

function s:EditorClearMarks(indic_number, start, length)
	local _first_indic, _end_indic
	local current_indic_number = self.e.IndicatorCurrent
	if indic_number == nil then
		_first_indic, _end_indic = 0, 31
	else
		_first_indic, _end_indic = indic_number, indic_number
	end
	if start == nil then
		start, length = 0, findres.Length
	end
	for indic = _first_indic, _end_indic do
		self.e.IndicatorCurrent = indic
        self.e:IndicatorClearRange(start, length)
	end
	self.e.IndicatorCurrent = current_indic_number
end

function s:CheckStyle(posFind)
    for i = 1, #(self.st_vals) do
       -- if self.st_exclude then
            if self.st_vals[i] == self.e.StyleAt[posFind] then return self.st_exclude end
       -- else
       --     if self.st_vals[i] == self.e.StyleAt[posFind] then return false end
       -- end
    end
    return not self.st_exclude
end

function s:FindInTarget(findWhat, lenFind, startPosition, endPosition)
    self.e.TargetStart = startPosition
    self.e.TargetEnd = endPosition
    local posFind = self.e:SearchInTarget(findWhat)

    if self.style and not self.st_set and self.e == editor then
        self.st_set = true
        local l = self.e.FirstVisibleLine
        self.e.FirstVisibleLine = self.e:VisibleFromDocLine(self.e.LineCount)
        self.e.FirstVisibleLine = l
    end
	while (self.style ~= nil and posFind ~= -1 and self:CheckStyle(posFind)) do
		if startPosition < endPosition then
			self.e.TargetStart = posFind + 1
			self.e.TargetEnd = endPosition
		else
			self.e.TargetStart = startPosition
			self.e.TargetEnd = posFind + 1
		end
		posFind = self.e:SearchInTarget(findWhat)
	end
    if posFind == -1 then self.st_set = nil end
	return posFind;
end

function s:FindNext(fireEvent, bScipSelect)

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
	        Iif(self.regExp, SCFIND_REGEXP + SCFIND_CXX11REGEX, 0) +
	        Iif(props["find.replace.regexp.posix"]=='1', SCFIND_POSIX, 0)

	self.e.SearchFlags = flags
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
	if posFind ~= -1 and not bScipSelect then

		-- //������� ����������� � �������
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
    local ss, se = self.e.SelectionStart, self.e.SelectionEnd
    if self.searchUp then
        self.e:SetSel(self.e.SelectionEnd, self.e.SelectionEnd)
    else
        self.e:SetSel(self.e.SelectionStart, self.e.SelectionStart)
    end
	local pos = self:FindNext(true);

    if ss ~= self.e.SelectionStart or se ~= self.e.SelectionEnd then return end

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

function s:onMarkOne(iMark, bClear, iMarker)
    if bClear then self:EditorClearMarks(iMark) end
    return (function(lenTarget)
        if lenTarget then
            self:EditorMarkText(self.e.TargetStart, lenTarget, iMark)
            if iMarker then self.e:MarkerAdd(self.e:LineFromPosition(self.e.TargetStart) , iMarker) end
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
        local level = findres.FoldLevel[line]
        if ((level & SC_FOLDLEVELHEADERFLAG)~=0 and SC_FOLDLEVELBASE + 1 == (level & SC_FOLDLEVELNUMBERMASK))then
            findres.FoldExpanded[line] = nil
            local lineMaxSubord = findres:GetLastChild(line,-1)
            if line < lineMaxSubord then findres:HideLines(line + 1, lineMaxSubord) end
        end
    end
end

function s:FindOptStr()
    local v = '>Search'
    if self.regExp then v = v..' RE' end
    if self.wholeWord then v = v..' WW' end
    if self.matchCase then v = v..' MC' end
    if self.backslash then v = v..' BS' end
    if self.style then v = v..' S'..self.style end
    v = v..' for:"'
    return v
end

function s:onFindAll(maxlines, bLive, bColapsPrev, strIn, bSearchCapt, iMarker, iIndic)
    if bColapsPrev and bSearchCapt then self:CollapseFindRez() end
    local strLive = Iif(bLive, "/\\", "")
    local needCoding = (self.e.CodePage ~= 0)
    findres:SetSel(0, 0)
    local line, wCount, lCount = -1, 0, 0
    local bShowAll = true
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
                    else lNum = self:GetPath()..':'..(l + 1)..': ' end
                else
                    lNum = '\t'..(l+1)..': '
                end
                if (lCount == (maxlines or (-2))) and not iMarker then
                    findres:ReplaceSel(lNum..'...\n')
                    return lenTarget, false
                end

                if (maxlines or (lCount + 1)) > lCount then
                    local str = self.e:GetLine(l):gsub('^[ \t]+', '')
                    if needCoding then str = str:from_utf8() end
                    findres:ReplaceSel(lNum..str)
                else
                    if bShowAll then findres:ReplaceSel(lNum..'...\n') end
                    bShowAll = false
                end

                if iMarker then
                    self.e:MarkerAdd(l, iMarker)
                end
             end
            if iIndic then
                local current_indic_number = self.e.IndicatorCurrent
                self.e.IndicatorCurrent = iIndic
                self.e:IndicatorFillRange(self.e.TargetStart, lenTarget)
                self.e.IndicatorCurrent = current_indic_number
            end
            return lenTarget, true
        else
            if bSearchCapt then findres:ReplaceSel('<'..strLive..'\n') end
            findres:SetSel(0, 0)
            local strCapt = ''
            local strSrch = self.findWhat
            if self:GetUnicMod() ~= IDM_ENCODING_DEFAULT then strSrch = self.findWhat:from_utf8() end
            if bSearchCapt then strCapt = strCapt..self:FindOptStr()..strSrch..'" in "'..self:GetPath(true)..'" ('..strIn..')  Occurrences: '..wCount..' in '..lCount..' lines\n' end

            if _G.iuprops['findres.groupbyfile'] then strCapt = strCapt..' '..self:GetPath()..'\n' end
            if bSearchCapt or wCount > 0 then  findres:ReplaceSel( strCapt) end

            findres:SetSel(0, 0)
            findres.CurrentPos = 1
            if findres.LinesOnScreen == 0 or CORE.BottomBarHidden() then scite.MenuCommand(IDM_TOGGLEOUTPUT)  end

            return wCount, lCount
        end
    end)
end

local iPrevMark
function s:findWalk(inSelection, funcOnFind)
    local findTarget, findLen = self:UnSlashAsNeeded(self.findWhat)
    if iPrevMark then editor:MarkerDeleteAll(iPrevMark) end
    iPrevMark = nil

    if findLen == 0 then return -1 end
	local startPosition = self.e.SelectionStart;
	local endPosition = self.e.SelectionEnd;
	local countSelections = self.e.Selections
    if inSelection then
        if self.e.SelectionMode == SC_SEL_LINES then
            startPosition = self.e:PositionFromLine(self.e:LineFromPosition(startPosition))
            endPosition = self.e:PositionFromLine(self.e:LineFromPosition(endPosition) + 1)
        else
            for i = 0, countSelections - 1 do
                startPosition = Min(startPosition, self.e.SelectionNStart[i])
                endPosition = Max(endPosition, self.e.SelectionNEnd[i])
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
	        Iif(self.regExp, SCFIND_REGEXP + SCFIND_CXX11REGEX, 0) +
	        Iif(props["find.replace.regexp.posix"]=='1', SCFIND_POSIX, 0)
	self.e.SearchFlags = flags
	local posFind = self:FindInTarget(findTarget, findLen, startPosition, endPosition);
	if (findLen == 1) and self.regExp and findTarget:byte() == string.byte('^') then
		-- // Special case for replace all start of line so it hits the first line
		posFind = startPosition;
		self.e.TargetStart = startPosition
		self.e.TargetEnd = startPosition
	end
	if (posFind ~= -1) and (posFind <= endPosition) then
		local lastMatch = posFind;
		local replacements = 0;
        self.e:BeginUndoAction()
		-- // Replacement loop
		while posFind ~= -1 do
            local bContinue = true
            repeat --�������� ����, ����� ���� �������� ��� continue
                local lenTarget = self.e.TargetEnd - self.e.TargetStart
                local insideASelection = true
                if inSelection and countSelections > 1 then
                    -- // We must check that the found target is entirely inside a selection
                    insideASelection = false
                    for i=0, countSelections - 1 do
                        local startPos= self.e.SelectionNStart[i]
                        local endPos = self.e.SelectionNEnd[i]
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
                    local chNext = self.e.CharAt[self.e.TargetEnd]
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
            if countSelections == 1 then self.e:SetSel(startPosition, endPosition) end
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
    local origStyle = self.style
    local origFind = self.findWhat
    if self:GetUnicMod() ~= IDM_ENCODING_DEFAULT then self.findWhat = self.findWhat:from_utf8() end
    self.style = ''..SCE_SEARCHRESULT_CURRENT_LINE
    self:resetSt()
    local p
    for i = 1, findres.LineCount - 1 do
        p = findres:PositionFromLine(i)
        if findres.StyleAt[p + 1] == SCE_SEARCHRESULT_SEARCH_HEADER then break end
    end
    if p then
        if p > 0 then
            findres:SetSel(0, p)
            findres:Colourise(0, p)
            self:findWalk(true, self:onMarkOne(31, false))
            findres:SetSel(0, 0)
        end
    end

    self.style = origStyle
    self.findWhat = origFind
    self.e = editor
    self:resetSt()
end

function s:FindAll(maxlines, bLive, bSel, iMarker, iIndic)
    local rez = self:findWalk((bSel == true), self:onFindAll(maxlines, bLive, true, Iif(self.e == coeditor, 'Neighbor', 'Current'), true, iMarker, iIndic))
    self:MarkResult()
    iPrevMark = iMarker
    return rez
end

function s:FindInBufer()
    local cnt, lin, fil = 0, 0, 0
    findres:SetSel(0, 0)
    findres:ReplaceSel('<\n')
    findres:SetSel(0, 0)
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
            findres:SetSel(0, 0)
            local strSrch = self.findWhat
            if self:GetUnicMod() ~= IDM_ENCODING_DEFAULT then strSrch = self.findWhat:from_utf8() end
            findres:ReplaceSel(self:FindOptStr()..strSrch..'" in buffers  Occurrences: '..cnt..' in '..lin..' lines in '..fil..' files\n')
            return cnt
        end
        self:MarkResult()
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
function s:MarkAll(bInSel, iMark, iMarker)
    return self:findWalk(bInSel, self:onMarkOne(iMark, true, iMarker))
end
function s:BookmarkAll(bInSel)
    return self:findWalk(bInSel, (function(lenTarget) self.e:MarkerAdd(self.e:LineFromPosition(self.e.TargetStart),1); return lenTarget, true; end))
end
_G.seacher = s

