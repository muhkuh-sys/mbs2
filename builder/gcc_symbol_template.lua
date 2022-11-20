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

  -- copy data from table 1 to table 2 - check double entries
  local function copy_table(table_1,table_2)
    for strKey,tValue in pairs(table_2) do
      if table_1[strKey] ~= nil and table_1[strKey] == tValue then
        local strMsg = string.format("Warning: The key:'%s' is still available with the same value in table_1.",strKey)
        print(strMsg)
      elseif table_1[strKey] ~= nil and table_1[strKey] ~= tValue then
        local strMsg = string.format("Error: The key:'%s' is still available with a different value in table_1.",strKey)
        error(strMsg)
      end

      table_1[strKey] = tValue
    end
  end

  -- TODO change by using of package path
  local function GetModule(strBuilder)
    -- Try to load the builder script.
    local strBuilderScript, strError = pl.utils.readfile(strBuilder, false)
    if strBuilderScript==nil then
      local strMsg = string.format('Failed to read script "%s": %s', strBuilder, strError)
      error(strMsg)
    end

    -- Run the script.
    local tChunk, strError = pl.compat.load(strBuilderScript, strBuilder, 't')
    if tChunk==nil then
      local strMsg = string.format('Failed to parse script "%s": %s', strBuilder, strError)
      error(strMsg)
    end

    local bStatus, tResult = pcall(tChunk)
    if bStatus==nil then
      local strMsg = string.format('Failed to call the script "%s": %s', strBuilder, tResult)
      error(strMsg)
    end

    return tResult
  end


-- TODO change by using of package path
  -- path of the auxilliary module: "Elf_Support"
  local strElf_Support = "mbs2/utils/elf_support.lua"
  local strLpeg_Support = "mbs2/utils/lpeg_support.lua"
  -- package.path = 'mbs2/utils/?.lua;mbs2/utils/?/init.lua;' .. package.path
  local tElf_Support =  GetModule(strElf_Support) -- require "elf_support"
  local tLpeg_Support =  GetModule(strLpeg_Support)

  -- input arg BAM
  local strParameter = _bam_targets[0]

  local tParameter, strParameterError = rapidjson.decode(strParameter)
  if tParameter==nil then
    local strMsg = string.format('Failed to decode the input parameter "%s": %s', strParameter, strParameterError)
    error(strMsg)
  else
    local tEnvCmdTemplates,strSourceElf,strOutput,strGCC_Symbol_Template,strGCC_Symbol_Binfile =
      tParameter.tEnvCmdTemplates,
      tParameter.strSourceElf,
      tParameter.strOutput,
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
      local strMsg = string.format('Failed to read templete "%s": %s', strGCC_Symbol_Template, strError)
      error(strMsg)
    end

    -- Replace all symbols in the template.
    local strResult = tLpeg_Support.Gsub(strTemplate,atSymbols)

    -- Write the result.
    local tWriteResult, strWriteError = pl.utils.writefile(tParameter.strOutput, strResult, true)
    if tWriteResult~=true then
      local strMsg = string.format('Failed to write the output file "%s": %s', tParameter.strOutput, strWriteError)
      error(strMsg)
    end
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

  function tEnv:GccSymbolTemplate(strTarget, strSourceElf,strGCC_Symbol_Template,strGCC_Symbol_Binfile)

    local tParameter =
    {
      strSourceElf           = pl.path.abspath(strSourceElf),
      strOutput              = pl.path.abspath(strTarget),
      strGCC_Symbol_Template = pl.path.abspath(strGCC_Symbol_Template),
      strGCC_Symbol_Binfile  = (strGCC_Symbol_Binfile == nil) and "" or pl.path.abspath(strGCC_Symbol_Binfile), -- TODO: add %PROGRAM_DATA%"
      tEnvCmdTemplates =
      {
        READELF = self.atCmdTemplates.READELF,
        OBJDUMP = self.atCmdTemplates.OBJDUMP
      }
    }

    local strParameter = rapidjson.encode(tParameter, { sort_keys=true })

    AddJob(
      tParameter.strOutput, -- output
      string.format('GCC_Symbol_Template %s', tParameter.strSourceElf), -- label
      _bam_exe .. " " .. pl.utils.quote_arg({"-e", strBuilderPath, strParameter}) -- cmd
    )
    AddDependency(tParameter.strOutput, tParameter.strSourceElf) -- neccessary

    return tParameter.strOutput
  end
end