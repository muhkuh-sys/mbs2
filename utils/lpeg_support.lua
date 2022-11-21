
-- create an object of the module
local tLpeg_Support = {}

local pl = require'pl.import_into'()

---------------------------------------------------------------------------------------------------------------------
--
-- Pattern and auxiliary functions of lpeg
--

--- Init lpeg
local lpeg = require "lpeglabel"

-- Save typing function names with "lpeg" in front of them:
local P, V, Cg, Ct, Cc, S, R, C, Cf, Cb, Cs = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.S, lpeg.R, lpeg.C, lpeg.Cf, lpeg.Cb, lpeg.Cs


-- Match optional whitespace.
local OptionalSpace = S(" \t") ^ 0
local Space = S(" \t") ^ 1
local Comma = P(",")
tLpeg_Support.OptionalSpace = OptionalSpace
tLpeg_Support.Space = Space
tLpeg_Support.Comma = Comma


-- Auxiliary function: add spaces around pattern
tLpeg_Support.Spaces = function(Pattern)
  return Space * Pattern * Space
end


-- Auxiliary function: add optinal spaces around pattern
tLpeg_Support.OptSpace = function(Pattern)
  return OptionalSpace * Pattern * OptionalSpace
end


-- Auxiliary function: match everything up to the pattern (return a caption)
tLpeg_Support.UpTo = function(SEARCH_PATTERN,END_PATTERN,strSearchPattern,fCapture)
  fCapture = fCapture or nil
  if fCapture ~= nil and type(fCapture) == "function" then
    return Cg((SEARCH_PATTERN - (END_PATTERN)) ^ 1 / fCapture,strSearchPattern) * END_PATTERN
  else
    return Cg((SEARCH_PATTERN - (END_PATTERN)) ^ 1,strSearchPattern) * END_PATTERN
  end
end


-- Auxiliary function: return a grammar which tries to match the given pattern in a string
tLpeg_Support.Anywhere = function(Pattern)
  return P {Pattern + 1 * lpeg.V(1)}
end


-- Auxiliary function: list-pattern with separator
tLpeg_Support.List = function(Pattern, Sep)
  return C(Pattern) * (Sep * C(Pattern)) ^ 0
end


-- Auxiliary function: Create an either or pattern of the table entries
tLpeg_Support.SetEitherOrPattern = function(tSearchingPattern)
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
function tLpeg_Support.Gsub(strTemplate,tReplacements,TEMPLATE_PATTERN)
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

  TEMPLATE_PATTERN = TEMPLATE_PATTERN or P"${" * C((P(1) - P"}")^0) * P"}"
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


-- Save typing:
--[==[
local P, V, Cg, Ct, Cc, S, R, C, Cf, Cb, Cs, match,
OptionalSpace,Space,Comma,
Spaces,OptSpace,UpTo,Anywhere,List,SetEitherOrPattern,Gsub =
lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.S, lpeg.R, lpeg.C, lpeg.Cf, lpeg.Cb, lpeg.Cs, lpeg.match,
tLpeg_Support.OptionalSpace,tLpeg_Support.Space,tLpeg_Support.Comma,
tLpeg_Support.Spaces,tLpeg_Support.OptSpace,tLpeg_Support.UpTo,tLpeg_Support.Anywhere,
tLpeg_Support.List,tLpeg_Support.SetEitherOrPattern,tLpeg_Support.Gsub
--]==]

return tLpeg_Support