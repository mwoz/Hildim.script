local goodmark, errmark

local function Init()

end
return {
    title = 'СТАРОЕ Автоформатирование VBS и FormEnjine файлов',
    hidden = Init,
    destroy = function() CORE.FreeIndic(goodmark); CORE.FreeIndic(errmark) end,
}
