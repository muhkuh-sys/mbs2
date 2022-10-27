---------------------------------------------------------------------------------------------------------------------
--
-- A BAM builder which replaces a set of fields.
--
local tEnv = ...
if tEnv==nil then
  -------------------------------------------------------------------------------------------------------------------
  --
  -- Builder
  -- This is the builder code which does the real work.
  --
  local pl = require'pl.import_into'()

  local strParameter = _bam_targets[0]

  local rapidjson = require 'rapidjson'
  local tParameter, strParameterError = rapidjson.decode(strParameter)
  if tParameter==nil then
    error(string.format('Failed to decode the input parameter "%s": %s', strParameter, strParameterError))
  else
    -- Read the input file.
    -- NOTE: read the file as binary to keep line feeds.
    local strInputData, strReadError = pl.utils.readfile(tParameter.input, true)
    if strInputData==nil then
      error(string.format('Failed to read the input file "%s": %s', tParameter.input, strReadError))
    else
      -- Replace all parameters.
      local strReplaced = string.gsub(strInputData, '%$%{([^}]+)%}', tParameter.replace)

      -- Write the replaced data to the output file.
      -- NOTE: write the file as binary to keep line feeds.
      local tWriteResult, strWriteError = pl.utils.writefile(tParameter.output, strReplaced, true)
      if tWriteResult~=true then
        error(string.format('Failed to write the output file "%s": %s', tParameter.output, strWriteError))
      end
    end
  end

else
  -------------------------------------------------------------------------------------------------------------------
  --
  -- Interface
  -- This is the interface code which registers a function in an environment.
  --
  local pl = require'pl.import_into'()

  function tEnv:Template(strTarget, strInput, atReplacement)
    local tFilterParameter = {
      input = pl.path.abspath(strInput),
      output = pl.path.abspath(strTarget),
      replace = atReplacement
    }

    local rapidjson = require 'rapidjson'
    local strFilterParameter = rapidjson.encode(tFilterParameter, { sort_keys=true })
    AddJob(
      tFilterParameter.output,
      string.format('Template %s', tFilterParameter.input),
      _bam_exe .. " -e mbs/builder/template.lua '" .. strFilterParameter .. "'"
    )
    return tFilterParameter.output
  end
end
