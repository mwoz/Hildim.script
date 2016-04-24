local curLine = 0

editor:BeginUndoAction()
repeat
    local fstColorStart = editor:findtext('0 *= *"', SCFIND_REGEXP, editor:PositionFromLine(curLine))
    if not fstColorStart then break end
    curLine = editor:LineFromPosition(fstColorStart)

    local maxBg,maxId = -1, -1
    for i = 0, 15 do
        local fstColorStart = editor:findtext(''..i..' *= *"', SCFIND_REGEXP, editor:PositionFromLine(curLine))
        local fstColorEnd = editor:findtext('"', 0, fstColorStart + 9)

        local _,_,R,G,B = editor:textrange(fstColorStart, fstColorEnd):find('(%d+) (%d+) (%d+)')
        local bCur = tonumber(R) + tonumber(G) + tonumber(B)
        if bCur > maxBg then maxBg = bCur; maxId = i end

    end
    local fstColorStart = editor:findtext('"', 0, editor:PositionFromLine(curLine+maxId))
    local fstColorEnd = editor:findtext('"', 0, fstColorStart + 1) + 1
    --print(editor:textrange(fstColorStart, fstColorEnd),curLine)
    editor.TargetStart = fstColorStart
    editor.TargetEnd = fstColorEnd
    editor:ReplaceTarget("BGCOLOR")
    curLine = curLine + 16

until false
editor:EndUndoAction()
