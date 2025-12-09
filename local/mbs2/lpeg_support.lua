--[==[
--- Init lpeg
local lpeg = require "lpeglabel"

-- Init lpeg_support
local tLpeg_Support =  require "lpeg_support"()

-- Save typing:
local P, V, Cg, Ct, Cc, S, R, C, Cf, Cb, Cs, match,
OptionalSpace,Space,Comma =
lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.S, lpeg.R, lpeg.C, lpeg.Cf, lpeg.Cb, lpeg.Cs, lpeg.match,
tLpeg_Support.OptionalSpace,tLpeg_Support.Space,tLpeg_Support.Comma
--]==]


---------------------------------------------------------------------------------------------------------------------
--
-- global declaration of variables
--

local lpeg = require "lpeglabel"

-- Save typing function names with "lpeg" in front of them:
local P, V, Cg, Ct, Cc, S, R, C, Cf, Cb, Cs = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.S, lpeg.R, lpeg.C, lpeg.Cf, lpeg.Cb, lpeg.Cs

-- auxiliary pattern
local OptionalSpace = S(" \t") ^ 0
local Space = S(" \t") ^ 1
local Comma = P(",")


local _M = {
  OptionalSpace = OptionalSpace,
  Space = Space,
  Comma = Comma
}

---------------------------------------------------------------------------------------------------------------------
--
-- auxiliary functions of lpeg
--

-- Auxiliary function: add spaces around pattern
function _M:Spaces(Pattern)
  return Space * Pattern * Space
end


-- Auxiliary function: add optinal spaces around pattern
function _M:OptSpace(Pattern)
  return OptionalSpace * Pattern * OptionalSpace
end


-- Auxiliary function: match everything up to the pattern (return a caption)
function _M:UpTo(SEARCH_PATTERN,END_PATTERN,strSearchPattern,fCapture)
  fCapture = fCapture or nil
  if fCapture ~= nil and type(fCapture) == "function" then
    return Cg((SEARCH_PATTERN - (END_PATTERN)) ^ 1 / fCapture,strSearchPattern) * END_PATTERN
  else
    return Cg((SEARCH_PATTERN - (END_PATTERN)) ^ 1,strSearchPattern) * END_PATTERN
  end
end


-- Auxiliary function: return a grammar which tries to match the given pattern in a string
function _M:Anywhere(Pattern)
  return P {Pattern + 1 * V(1)}
end


-- Auxiliary function: list-pattern with separator
function _M:List(Pattern, Sep)
  return C(Pattern) * (Sep * C(Pattern)) ^ 0
end


-- Auxiliary function: Create an either or pattern of the table entries
function _M:SetEitherOrPattern(tSearchingPattern)
  local Pattern = nil
  for _,strValue in ipairs(tSearchingPattern) do
    if Pattern == nil then
      Pattern = P(strValue)
    else
      Pattern = Pattern + P(strValue)
    end
  end
  return Pattern
end


-- Auxiliary function: Replace templates in a string with given replacement(s)
function _M:Gsub(strTemplate,TEMPLATE_PATTERN,tReplacements)
  TEMPLATE_PATTERN = TEMPLATE_PATTERN or P"${" * C((P(1) - P"}")^1) * P"}"

  local fReplace = function(tmatch)
    local strResult
    if type(tReplacements) == "table" then
      if tReplacements[tmatch] == nil then
        local strMsg = string.format("ERROR: Missing symbol:'%s' in the replacement table. ",tmatch)
        error(strMsg)
      end
      strResult = tReplacements[tmatch]
    elseif type(tReplacements) == "string" then
      strResult = tReplacements
    end

    return strResult
  end

  local Substitution = Cs((TEMPLATE_PATTERN / fReplace + 1)^0)

  -- with recursive pattern, a limit of max stack (max numb of symbols) can be reached (lpeg.setmaxstack, default = 400).
  --[[
  local Substitution =
  Cs(
    P{
      "start", --> this tells LPEG which rule to process first
      start     = (V"template" + 1* V"start")^0,
      template  = TEMPLATE_PATTERN / fReplace
    }
  )
  local strOutput
  for strLine in pl.stringx.lines(strTemplate) do
    local strTemp = Substitution:match(strLine)
    if strOutput == nil then
      strOutput = strTemp
    else
      strOutput = strOutput .. "\n" .. strTemp
    end
  end

  return strOutput
  --]]

  return Substitution:match(strTemplate)
end

return _M
