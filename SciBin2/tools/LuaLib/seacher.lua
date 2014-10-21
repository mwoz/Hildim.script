

function class()
    local c = {}
    c.__index = c
    c.__gc = function()
        if c.destroy then
            c.destroy()
        end
    end
    local mt = {}
    mt.__call = function(_, ...)
        self = setmetatable({}, c)
        if c.init then
            c.init(self, ...)
        end
        return self
    end
    return setmetatable(c, mt)
end

local s = class()

function s:__tostring()
    return "Lua module: simple [" .. self.name .. "]"
end
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
end

function s:UnSlashAsNeeded(strIn)
    local str
    if self.backslash and not self.regExp then
        str = strIn:gsub('\\\\', '¦'):gsub('\\a', '\a'):gsub('\\b', '\b'):gsub('\\f', '\f'):gsub('\\n', '\n'):gsub('\\r', '\r'):gsub('\\t', '\t'):gsub('\\v', '\v'):gsub('¦', '\\')
    else
        str = strIn
    end
    local strLen = str:len()
    return str, strLen
end

function s:encode(s)
    if editor.CodePage ~= 0 then return s:to_utf8(1251) end
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
end

function s:FindInTarget(findWhat, lenFind, startPosition, endPosition)
    scite.SendEditor(SCI_SETTARGETSTART, startPosition)
    scite.SendEditor(SCI_SETTARGETEND, endPosition)

    local posFind = editor:SearchInTarget(findWhat)
	while (self.style ~= nil and posFind ~= -1 and self.style ~= scite.SendEditor(SCI_GETSTYLEAT, posFind)) do
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

function s:FindNext(fireEvent)

    if self.findWhat == nil or self.findWhat:len() == 0 then
        return -1
		-- Find();
	end

	local findTarget, lenFind = s:UnSlashAsNeeded(self.findWhat)
	if (lenFind == 0) then return -1 end

	local startPosition = Iif(self.searchUp, editor.SelectionStart, editor.SelectionEnd)
	local endPosition = Iif(self.searchUp, 0, editor.Length)

	local flags = Iif(self.wholeWord, SCFIND_WHOLEWORD, 0) +
	        Iif(self.matchCase, SCFIND_MATCHCASE, 0) +
	        Iif(self.regExp, SCFIND_REGEXP, 0) +
	        Iif(props["find.replace.regexp.posix"]=='1', SCFIND_POSIX, 0)

	scite.SendEditor(SCI_SETSEARCHFLAGS, flags)
	local posFind = self:FindInTarget(findTarget, findLen, startPosition, endPosition)

	if posFind == -1 and  self.wrapFind then
		-- // Failed to find in indicated direction
		-- // so search from the beginning (forward) or from the end (reverse)
		-- // unless wrapFind is false

        startPosition = Iif(self.searchUp, editor.Length, 0)
        endPosition = Iif(self.searchUp, 0, editor.Length)

		posFind = self:FindInTarget(findTarget, findLen, startPosition, endPosition)
		-- WarnUser(warnFindWrapped);
	end
	if posFind ~= -1 then

		-- //Вызовем нотификацию в скрипте
		if fireEvent then OnNavigation("Find") end

		local start = editor.TargetStart
		local fin = editor.TargetEnd
        editor:EnsureVisible(start, fin)
		-- EnsureRangeVisible;

        editor:SetSel(start, fin)

        if fireEvent then OnNavigation("Find-") end
	end
	return posFind;
end

function s:ReplaceOnce()
--[[	if (!FindHasText())
		return;]]
    if self.searchUp then
        editor:SetSel(editor.SelectionEnd, editor.SelectionEnd)
    else
        editor:SetSel(editor.SelectionStart, editor.SelectionStart)
    end
	local pos = self:FindNext(true);

	if pos > -1 then
        local replaceTarget, replaceLen = s:UnSlashAsNeeded(self.replaceWhat)

		local lenReplaced = replaceLen;
		if self.regExp then
			lenReplaced = editor:ReplaceTargetRE(replaceTarget);
		else
			editor:ReplaceTarget(replaceTarget)
        end
        if self.searchUp then
            editor:SetSel(pos, pos)
        else
            editor:SetSel(pos + lenReplaced, pos + lenReplaced)
        end

		self:FindNext(true);
	end
end

function s:onMarkOne(iMark)
    EditorClearMarks(iMark)
    return (function(lenTarget)
        if lenTarget then
            EditorMarkText(editor.TargetStart, lenTarget, iMark)
            return lenTarget, true
        else
            return true
        end
    end)
end

function s:replaceOne()
    local replaceTarget, replaceLen = s:UnSlashAsNeeded(self.replaceWhat)
    return (function(lenTarget)
        local lenReplaced = replaceLen
        if lenTarget then
            if self.regExp then
                lenReplaced = editor:ReplaceTargetRE(replaceTarget);
            else
                editor:ReplaceTarget(replaceTarget)
            end
            return lenReplaced, true
        else
            return true
        end
    end)
end

function s:onFindAll(maxlines)
    scite.MenuCommand(IDM_FINDRESENSUREVISIBLE)
    for line = 0, findrez.LineCount do
        local level = scite.SendFindRez(SCI_GETFOLDLEVEL, line)
        if (shell.bit_and(level,SC_FOLDLEVELHEADERFLAG)~=0 and SC_FOLDLEVELBASE == shell.bit_and(level,SC_FOLDLEVELNUMBERMASK))then
            scite.SendFindRez(SCI_SETFOLDEXPANDED, line)
            local lineMaxSubord = scite.SendFindRez(SCI_GETLASTCHILD, line,-1)
            if line < lineMaxSubord then scite.SendFindRez(SCI_HIDELINES, line + 1, lineMaxSubord) end
        end
    end
    local needCoding = (editor.CodePage ~= 0)
    scite.SendFindRez(SCI_SETSEL,0,0)
    local line, wCount, lCount = -1, 0, 0
    return (function(lenTarget)
        if lenTarget then
            wCount = wCount + 1
            local l = editor:LineFromPosition(editor.TargetStart)
            if l~=line then
                lCount = lCount + 1
                line = l
                if lCount == maxlines then
                    scite.SendFindRez(SCI_REPLACESEL, '.\\'..props["FileNameExt"]..':'..(l+1)..': ...\n')
                    return lenTarget, false
                end
                local str = editor:GetLine(l):gsub('^[ \t]+', '')
                if needCoding then str = str:from_utf8(1251) end
                scite.SendFindRez(SCI_REPLACESEL, '.\\'..props["FileNameExt"]..':'..(l+1)..': '..str )
            end
            return lenTarget, true
        else
            scite.SendFindRez(SCI_REPLACESEL, '>!!/\\  Occurrences: '..wCount..' in '..lCount..' lines\n' )
            scite.SendFindRez(SCI_SETSEL,0,0)
            scite.SendFindRez(SCI_REPLACESEL, '>??Internal search for "'..self.findWhat..'" in "'..props["FileNameExt"]..'" (Current)\n' )
            findrez.CurrentPos = 1
            if scite.SendFindRez(SCI_LINESONSCREEN) == 0 then scite.MenuCommand(IDM_TOGGLEOUTPUT) end

            return true
        end
    end)
end

function s:findWalk(inSelection, funcOnFind)
    local findTarget, findLen = s:UnSlashAsNeeded(self.findWhat)

    if findLen == 0 then return -1 end
	local startPosition = editor.SelectionStart;
	local endPosition = editor.SelectionEnd;
	local countSelections = scite.SendEditor(SCI_GETSELECTIONS)
    if inSelection then
        if scite.SendEditor(SCI_GETSELECTIONMODE) == SC_SEL_LINES then
            startPosition = editor:PositionFromLine(editor:LineFromPosition(startPosition))
            endPosition = editor:PositionFromLine(editor:LineFromPosition(endPosition) + 1)
        else
            for i = 0, countSelections - 1 do
                startPosition = Min(startPosition, scite.SendEditor(SCI_GETSELECTIONNSTART, i))
                endPosition = Max(endPosition, scite.SendEditor(SCI_GETSELECTIONNEND, i))
            end
        end
        if startPosition == endPosition then return -2 end
    else
        if self.searchUp or self.wrapFind then startPosition = 0 end
        if (not self.searchUp) or self.wrapFind then endPosition = editor.Length end
    end

    --local replaceTarget, replaceLen = s:UnSlashAsNeeded(self.replaceWhat)
	local flags = Iif(self.wholeWord, SCFIND_WHOLEWORD, 0) +
	        Iif(self.matchCase, SCFIND_MATCHCASE, 0) +
	        Iif(self.regExp, SCFIND_REGEXP, 0) +
	        Iif(props["find.replace.regexp.posix"]=='1', SCFIND_POSIX, 0)
	scite.SendEditor(SCI_SETSEARCHFLAGS, flags)
	local posFind = self:FindInTarget(findTarget, findLen, startPosition, endPosition);
	if (findLen == 1) and self.regExp and findTarget:byte() == string.byte('^') then
		-- // Special case for replace all start of line so it hits the first line
		posFind = startPosition;
		scite.SendEditor(SCI_SETTARGETSTART, startPosition)
		scite.SendEditor(SCI_SETTARGETEND, startPosition)
	end
	if (posFind ~= -1) and (posFind <= endPosition) then
		local lastMatch = posFind;
		local replacements = 0;
        editor:BeginUndoAction()
		-- // Replacement loop
		while posFind ~= -1 do
            local bContinue = true
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
                            posFind = self:FindInTarget(findTarget, findLen, lastMatch, endPosition);
                        end
                        break --continue;	--// No replacement
                    end
                end
                local movepastEOL = 0;
                if lenTarget <= 0 then
                    local chNext = scite.SendEditor(SCI_GETCHARAT, wEditor.Call(SCI_GETTARGETEND))
                    if chNext == '\r' or chNext == '\n' then movepastEOL = 1 end
                end
                local lenReplaced
                lenReplaced, bContinue = funcOnFind(lenTarget);

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
                    posFind = self:FindInTarget(findTarget, findLen, lastMatch, endPosition);
                end
                replacements = replacements + 1
		    until true
            if not bContinue then break end
        end
        funcOnFind(nil)
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

function s:ReplaceAll(inSel)
    return self:findWalk(inSel, self:replaceOne())
end

function s:FindAll(maxlines)
    return self:findWalk(false, self:onFindAll(maxlines))
end
function s:Count()
    return self:findWalk(false, (function(lenTarget) return lenTarget, true; end))
end
function s:MarkAll(bInSel, iMark)
    return self:findWalk(bInSel, self:onMarkOne(iMark))
end
function s:BookmarkAll(bInSel)
    return self:findWalk(bInSel, (function(lenTarget) editor:MarkerAdd(editor:LineFromPosition(editor.TargetStart),1); return lenTarget, true; end))
end
_G.seacher = s

