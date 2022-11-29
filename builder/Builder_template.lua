
-------------------------------------------------------------------------------------------------------------------
--
-- Builder
-- A BAM builder which replaces a set of fields.
--


-- Create the archive class.
local class = require 'pl.class'
local Template = class()


---
function Template:_init()
  self.pl = require'pl.import_into'()
  local rapidjson = require 'rapidjson'

  -- Add additonal package paths to the LUA search path -> Neccessary to add mbs2 paths to LUA search path
  self.tImport_mbs = require "import_mbs"()

  -- a proxy table of the mbs2 folder to load chunk of lua modules
  self.mbs2 = self.tImport_mbs.tProxy

  self.tLpeg_Support =  require "lpeg_support"()

  -- input argument by BAM calling this module
  local strParameter = _bam_targets[0]

  local tParameter, strParameterError = rapidjson.decode(strParameter)
  if tParameter==nil then
    local strMsg = string.format('ERROR: Failed to decode the input parameter "%s": %s', strParameter, strParameterError)
    error(strMsg)
  end

  self.tParameter = tParameter
end


---
function Template:run()
  local pl = self.pl
  local tParameter = self.tParameter
  local tLpeg_Support = self.tLpeg_Support

  -- Read the input file.
  -- NOTE: read the file as binary to keep line feeds.
  local strInputData, strReadError = pl.utils.readfile(tParameter.input, true)
  if strInputData==nil then
    local strMsg = string.format('ERROR: Failed to read the input file "%s": %s', tParameter.input, strReadError)
    error(strMsg)
  else

    -- Replace all parameters.
    local strReplaced = tLpeg_Support:Gsub(strInputData,nil,tParameter.replace)

    -- Write the replaced data to the output file.
    -- NOTE: write the file as binary to keep line feeds.
    local tWriteResult, strWriteError = pl.utils.writefile(tParameter.output, strReplaced, true)
    if tWriteResult~=true then
      local strMsg = string.format('ERROR: Failed to write the output file "%s": %s', tParameter.output, strWriteError)
      error(strMsg)
    end
  end
end

local tTemplate = Template()
tTemplate:run()





