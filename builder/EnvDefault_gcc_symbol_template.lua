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

--- Extract
-- @param strTarget
-- @param strSourceElf
-- @param strGCC_Symbol_Template
-- @param strGCC_Symbol_Binfile
function EnvDefault:GccSymbolTemplate(strTarget, strSourceElf,strGCC_Symbol_Template,strGCC_Symbol_Binfile)

  -- check input parameters
  if strTarget == nil or type(strTarget) ~= "string" then
    local strMsg = string.format('ERROR: The input parameter "strTarget" must be a string.')
    error(strMsg)
  end

  if strSourceElf == nil or type(strSourceElf) ~= "string" then
    local strMsg = string.format('ERROR: The input parameter "strSourceElf" must be a string.')
    error(strMsg)
  end

  if strGCC_Symbol_Template == nil or type(strGCC_Symbol_Template) ~= "string" then
    local strMsg = string.format('ERROR: The input parameter "strGCC_Symbol_Template" must be a string.')
    error(strMsg)
  end

  if not (strGCC_Symbol_Binfile == nil or type(strGCC_Symbol_Binfile) == "string") then
    local strMsg = string.format('ERROR: The input parameter "strGCC_Symbol_Binfile" must be nil or a string.')
    error(strMsg)
  end

  local tParameter =
  {
    strSourceElf           = pl.path.abspath(strSourceElf),
    strTarget              = pl.path.abspath(strTarget),
    strGCC_Symbol_Template = pl.path.abspath(strGCC_Symbol_Template),
    strGCC_Symbol_Binfile  = (strGCC_Symbol_Binfile == nil) and "" or pl.path.abspath(strGCC_Symbol_Binfile), -- TODO: add %PROGRAM_DATA%"
    tEnvCmdTemplates =
    {
      READELF = self.atVars["DefaultSettings"].READELF,
      OBJDUMP = self.atVars["DefaultSettings"].OBJDUMP
    }
  }

  local strParameter = rapidjson.encode(tParameter, { sort_keys=true })

  AddJob(
    tParameter.strTarget, -- output
    string.format('GCC_Symbol_Template %s', tParameter.strTarget), -- label
    _bam_exe .. " " .. pl.utils.quote_arg({"-e", strBuilderPath, strParameter}) -- cmd
  )

  AddDependency(tParameter.strTarget, tParameter.strSourceElf) -- neccessary
  AddDependency(tParameter.strTarget, tParameter.strGCC_Symbol_Template) -- neccessary

  return tParameter.strTarget
end


return Builder