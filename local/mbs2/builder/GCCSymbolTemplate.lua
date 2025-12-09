local tBuilder = {
  id = 'GCCSymbolTemplate',
  version = '1.0.0'
}



-- copy data from table 2 to table 1 - check double entries
function tBuilder.__copy_table(table_1, table_2)
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



-- This method will be run in a new process.
function tBuilder:runBuildTask(tArguments)
  -- Get the symbol table from the elf.
  local tElf_Support =  require 'mbs2.elf_support'
  local atSymbols = tElf_Support:get_symbol_table(
    tArguments.readelf,
    tArguments.input_elf
  )

  -- Get the macros from the ELF file.
  local atElfMacros = tElf_Support:get_macro_definitions(
    tArguments.readelf,
    tArguments.input_elf
  )
  self.__copy_table(atSymbols,atElfMacros)

  -- Get the debug information from the ELF file.
  local atElfDebugSymbols = tElf_Support:get_debug_symbols(
    tArguments.readelf,
    tArguments.input_elf
  )
  self.__copy_table(atSymbols,atElfDebugSymbols)

  -- Search and add the special "%EXECUTION_ADDRESS%".
  local uiExecutionAddress = tElf_Support:get_exec_address(
    tArguments.readelf,
    tArguments.input_elf
  )
  local strExecutionAddress = string.format("0x%08x",uiExecutionAddress)
  self.__copy_table(atSymbols,{["%EXECUTION_ADDRESS%"] = strExecutionAddress})

  -- Search and add the special "%LOAD_ADDRESS%".
  local atSegments = tElf_Support:get_segment_table(
    tArguments.objdump,
    tArguments.input_elf
  )
  local ulLoadAddress = tElf_Support:get_load_address(atSegments)
  local strLoadAddress = string.format("0x%08x",ulLoadAddress)
  self.__copy_table(atSymbols,{["%LOAD_ADDRESS%"] = strLoadAddress})

  --TODO:  Add here: "Search and replace the special "%PROGRAM_DATA%" pattern."

  -- Read the template.
  local utils = require 'pl.utils'
  local strTemplate, strError = utils.readfile(tArguments.input_template, false)
  if strTemplate==nil then
    error(string.format(
      'ERROR: Failed to read templete "%s": %s',
      tArguments.input_template,
      strError
    ))
  end

  -- Replace all symbols in the template.
  local strResult = string.gsub(strTemplate, tArguments.pattern, atSymbols)

  -- Write the result.
  local tWriteResult, strWriteError = utils.writefile(tArguments.output, strResult, true)
  if tWriteResult~=true then
    error(string.format(
      'ERROR: Failed to write the output file "%s": %s',
      tArguments.output,
      strWriteError
    ))
  end
end



function tBuilder:applyToEnv(tEnv, tCfg)
  local strBuilderId = self.id

  function tEnv:GCCSymbolTemplate(strOutputPath, strInputElfPath, strInputTemplate, tParameter)
    tParameter = tParameter or {}

    -- The default pattern extracts an identifier enclosed in '${...}'.
    local strPattern = tParameter.PATTERN
    if type(strPattern)~='string' then
      strPattern = '%${([%a_][%w_]*)}'
    end

    local tMbs = self.mbs
    local tJobParameter = {
      input_elf = strInputElfPath,
      input_template = strInputTemplate,
      output = strOutputPath,
      pattern = strPattern,
      readelf = tMbs.GCC_READELF,
      objdump = tMbs.GCC_OBJDUMP
    }
    self:addLuaJob(strBuilderId, strBuilderId, strOutputPath, tJobParameter)

    -- The generated file depends on the ELF file and the template.
    AddDependency(strOutputPath, strInputElfPath)
    AddDependency(strOutputPath, strInputTemplate)
  end

  return true
end


return tBuilder
