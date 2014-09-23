-- Sample Zog Lexer

--[[
@@ Contents of the file sample.zog
proc clip(int @a)
« Clip into the positive zone »
   if (a > 0.1E-14)
     b = +3.14159 + .5
   end
end
]]--

local function GetWordList(prop)
  local t = {}
  local s = props[prop]
  for v in string.gmatch(s, "(%w+)") do
    t[v] = true
  end
  return t
end

local function ZogLexer(styler) -- by Philippe Lhoste
   local S_DEFAULT = 0
   local S_IDENTIFIER = 1
   local S_KEYWORD = 2
   local S_COMMENT = 3
   local S_UNICODECOMMENT = 4
   local S_NUMBER = 5
   local S_OPERATOR = 6
   local keywords = GetWordList("keywords.script_zog")

   local IsIdentifier = function ()
     local c = styler:Current()
     return c:find('^%a+$') ~= nil
   end

   local IsNumber = function (initial)
     local IsDigit = function (c) return c >= '0' and c <= '9' or c == '.' end
     local c = styler:Current()
     if initial ~= nil then
       return IsDigit(c) or ((c == '-' or c == '+') and IsDigit(styler.Next()))
     end
     return IsDigit(c) or c == 'e' or c == 'E' or c == '-' or c == '+'
   end

   local IsOperator = function ()
     return string.find("+-/*%()<>=@", styler:Current(), 1, true) ~= nil
   end

  -- print("Styling: ", styler.startPos, styler.lengthDoc, styler.initStyle)
   styler:StartStyling(styler.startPos, styler.lengthDoc, styler.initStyle)

   while styler:More() do
     local stst = styler:State()

     -- Exit state if needed
     if stst == S_IDENTIFIER then
       if not IsIdentifier() then -- End of identifier
         local identifier = styler:Token()
         if keywords[identifier] then -- Is it a keyword?
           styler:ChangeState(S_KEYWORD)
         end
         styler:SetState(S_DEFAULT)
       end
     elseif stst == S_COMMENT and styler:AtLineEnd() then
       styler:SetState(S_DEFAULT)
     elseif stst == S_UNICODECOMMENT then
       if styler:Match("»") then
         styler:ForwardSetState(S_DEFAULT)
       end
     elseif stst == S_NUMBER and not IsNumber() then
       styler:SetState(S_DEFAULT)
     elseif stst == S_OPERATOR then
       styler:SetState(S_DEFAULT)
     end

     -- Enter state if needed
     if styler:State() == S_DEFAULT then
       if styler:Match("«") then
         styler:SetState(S_UNICODECOMMENT)
       elseif styler:Match("@@") then
         styler:SetState(S_COMMENT)
       elseif IsIdentifier() then
         styler:SetState(S_IDENTIFIER)
       elseif IsNumber(true) then
         styler:SetState(S_NUMBER)
       elseif IsOperator() then
         styler:SetState(S_OPERATOR)
       end
     end

     styler:Forward()
   end
   styler:EndStyling()
end

AddEventHandler("OnStyle", function(styler)
  if styler.language == "script_zog" then
    ZogLexer(styler)
  end
end)