local goodmark, errmark

local function Init()

end
return {
    title = '������ ������������������ VBS � FormEnjine ������',
    hidden = Init,
    destroy = function() CORE.FreeIndic(goodmark); CORE.FreeIndic(errmark) end,
}
