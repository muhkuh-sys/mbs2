---------------------------------------------------------------------------------------------------------------------
--
-- A BAM builder which replaces a set of fields by using of ELF file.
--

local strBuilderPath

local class = require "pl.class"
local Builder = class()

-- save environment functions/variables of the EnvDefault for mbs2
local EnvDefault = {}

function Builder:_init(strBuilder)
  self.EnvDefault = EnvDefault
  strBuilderPath = strBuilder
end


-------------------------------------------------------------------------------------------------------------------
--
-- EnvDefault
-- This is the interface code which registers a function in an environment.
--

---------------------------------------------------------------------------------------------------------------------
--
-- global declaration of variables
--

local pl = require'pl.import_into'()
local rapidjson = require 'rapidjson'


-------------------------------------------------------------------------------------------------
--
-- Create environment functions.
--

---
function EnvDefault:Hash(strTarget,strSource,tHash_ID,strHash_template)

  -- check input parameters
  if strTarget == nil or type(strTarget) ~= "string" then
    local strMsg = string.format('ERROR: The input parameter "strTarget" must be a string.')
    error(strMsg)
  end

  if strSource == nil or type(strSource) ~= "string" then
    local strMsg = string.format('ERROR: The input parameter "strSource" must be a string.')
    error(strMsg)
  end

  if tHash_ID == nil then
    -- default value
    tHash_ID = {"sha1"}
  elseif type(tHash_ID) ~= "table" then
    local strMsg = string.format('ERROR: The input parameter "strSource" must be a table.')
    error(strMsg)
  end

  if strHash_template == nil then
    -- default value
    strHash_template = '${ID_UC}:${HASH}\n'
  elseif type(strHash_template) ~= "string" then
    local strMsg = string.format('ERROR: The input parameter "strHash_template" must be a string.')
    error(strMsg)
  end

  local tParameter =
  {
    strSource        = pl.path.abspath(strSource),
    strTarget        = pl.path.abspath(strTarget),
    tHash_ID         = tHash_ID,
    strHash_template = strHash_template,
  }

  local strParameter = rapidjson.encode(tParameter, { sort_keys=true })

  AddJob(
    tParameter.strTarget, -- output
    string.format('Hash %s', tParameter.strTarget), -- label
    _bam_exe .. " " .. pl.utils.quote_arg({"-e", strBuilderPath, strParameter}) -- cmd
  )

  AddDependency(tParameter.strTarget, tParameter.strSource) -- neccessary

  return tParameter.strTarget
end


return Builder