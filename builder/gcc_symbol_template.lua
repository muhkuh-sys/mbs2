---------------------------------------------------------------------------------------------------------------------
--
-- A BAM builder which replaces a set of fields by using of ELF file.
--
local tEnv, strBuilderPath = ...
if tEnv==nil then
  -------------------------------------------------------------------------------------------------------------------
  --
  -- Builder
  -- This is the builder code which does the real work.
  --

  local pl = require'pl.import_into'()
  local rapidjson = require 'rapidjson'

  -- Add additonal package paths to the LUA search path and return a proxy table of the mbs2 folder to load chunk of lua the modules
  local mbs2 = require "import_mbs"()

  local tElf_Support =  require "elf_support"
  local tLpeg_Support =  require "lpeg_support"


  -- copy data from table 2 to table 1 - check double entries
  local function copy_table(table_1,table_2)
    for strKey,tValue in pairs(table_2) do
      if table_1[strKey] ~= nil and table_1[strKey] == tValue then
        local strMsg = string.format("WARNING: The key:'%s' is still available with the same value in table_1.",strKey)
        print(strMsg)
      elseif table_1[strKey] ~= nil and table_1[strKey] ~= tValue then
        local strMsg = string.format("ERROR: The key:'%s' is still available with a different value in table_1.",strKey)
        error(strMsg)
      end

      table_1[strKey] = tValue
    end
  end

  -- input argument by BAM calling this module
  local strParameter = _bam_targets[0]

  local tParameter, strParameterError = rapidjson.decode(strParameter)
  if tParameter==nil then
    local strMsg = string.format('ERROR: Failed to decode the input parameter "%s": %s', strParameter, strParameterError)
    error(strMsg)
  end

  local tEnvCmdTemplates,strSourceElf,strTarget,strGCC_Symbol_Template,strGCC_Symbol_Binfile =
    tParameter.tEnvCmdTemplates,
    tParameter.strSourceElf,
    tParameter.strTarget,
    tParameter.strGCC_Symbol_Template,
    tParameter.strGCC_Symbol_Binfile

  -- Get the symbol table from the elf.
  local atSymbols = tElf_Support:get_symbol_table(tEnvCmdTemplates,strSourceElf)

  -- Get the macros from the ELF file.
  local atElfMacros = tElf_Support:get_macro_definitions(tEnvCmdTemplates,strSourceElf)
  copy_table(atSymbols,atElfMacros)

  -- Get the debug information from the ELF file.
  local atElfDebugSymbols = tElf_Support:get_debug_symbols(tEnvCmdTemplates,strSourceElf,atSymbols)
  copy_table(atSymbols,atElfDebugSymbols)

  -- Search and add the special "%EXECUTION_ADDRESS%".
  local uiExecutionAddress = tElf_Support:get_exec_address(tEnvCmdTemplates,strSourceElf)
  local strExecutionAddress = string.format("0x%08x",uiExecutionAddress)
  copy_table(atSymbols,{["%EXECUTION_ADDRESS%"] = strExecutionAddress})

  -- Search and add the special "%LOAD_ADDRESS%".
  local atSegments = tElf_Support:get_segment_table(tEnvCmdTemplates,strSourceElf)
  local ulLoadAddress = tElf_Support:get_load_address(atSegments)
  local strLoadAddress = string.format("0x%08x",ulLoadAddress)
  copy_table(atSymbols,{["%LOAD_ADDRESS%"] = strLoadAddress})

  --TODO:  Add here: "Search and replace the special "%PROGRAM_DATA%" pattern."

  -- Read the template.
  local strTemplate, strError = pl.utils.readfile(strGCC_Symbol_Template, false)
  if strTemplate==nil then
    local strMsg = string.format('ERROR: Failed to read templete "%s": %s', strGCC_Symbol_Template, strError)
    error(strMsg)
  end

  -- Replace all symbols in the template.
  local strResult = tLpeg_Support.Gsub(strTemplate,nil,atSymbols)

  -- Write the result.
  local tWriteResult, strWriteError = pl.utils.writefile(strTarget, strResult, true)
  if tWriteResult~=true then
    local strMsg = string.format('ERROR: Failed to write the output file "%s": %s', strTarget, strWriteError)
    error(strMsg)
  end

else
  -------------------------------------------------------------------------------------------------------------------
  --
  -- Interface
  -- This is the interface code which registers a function in an environment.
  --

  --- global declaration of variables:
  local pl = require'pl.import_into'()
  local rapidjson = require 'rapidjson'


  -------------------------------------------------------------------------------------------------
  --
  -- Create GccSymbolTemplate environment functions.
  --

  --- Extract
  -- @param strTarget
  -- @param strSourceElf
  -- @param strGCC_Symbol_Template
  -- @param strGCC_Symbol_Binfile
  function tEnv:GccSymbolTemplate(strTarget, strSourceElf,strGCC_Symbol_Template,strGCC_Symbol_Binfile)

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

    return tParameter.strTarget
  end
end