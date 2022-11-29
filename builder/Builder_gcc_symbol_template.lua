-------------------------------------------------------------------------------------------------------------------
--
-- Builder
-- A BAM builder which replaces a set of fields by using of ELF file.
--

-- Create the GCC_Symbol_Template class.
local class = require 'pl.class'
local GCC_Symbol_Template = class()


---
function GCC_Symbol_Template:_init()
  self.pl = require'pl.import_into'()
  local rapidjson = require 'rapidjson'

  -- Add additonal package paths to the LUA search path -> Neccessary to add mbs2 paths to LUA search path
  self.tImport_mbs = require "import_mbs"()

  -- a proxy table of the mbs2 folder to load chunk of lua modules
  self.mbs2 = self.tImport_mbs.tProxy

  self.tElf_Support =  require "elf_support"()
  self.tLpeg_Support =  require "lpeg_support"()


  -- input argument by BAM calling this module
  local strParameter = _bam_targets[0]

  local tParameter, strParameterError = rapidjson.decode(strParameter)
  if tParameter==nil then
    local strMsg = string.format('ERROR: Failed to decode the input parameter "%s": %s', strParameter, strParameterError)
    error(strMsg)
  end

  self.tEnvCmdTemplates,self.strSourceElf,self.strTarget,self.strGCC_Symbol_Template,self.strGCC_Symbol_Binfile =
    tParameter.tEnvCmdTemplates,
    tParameter.strSourceElf,
    tParameter.strTarget,
    tParameter.strGCC_Symbol_Template,
    tParameter.strGCC_Symbol_Binfile

end


---------------------------------------------------------------------------------------------------------------------
--
-- Auxiliary functions
--

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


---
function GCC_Symbol_Template:run()
  local tElf_Support = self.tElf_Support
  local pl = self.pl
  local tLpeg_Support = self.tLpeg_Support

  local tEnvCmdTemplates,strSourceElf,strTarget,strGCC_Symbol_Template,strGCC_Symbol_Binfile =
  self.tEnvCmdTemplates,
  self.strSourceElf,
  self.strTarget,
  self.strGCC_Symbol_Template,
  self.strGCC_Symbol_Binfile


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
  local strResult = tLpeg_Support:Gsub(strTemplate,nil,atSymbols)

  -- Write the result.
  local tWriteResult, strWriteError = pl.utils.writefile(strTarget, strResult, true)
  if tWriteResult~=true then
    local strMsg = string.format('ERROR: Failed to write the output file "%s": %s', strTarget, strWriteError)
    error(strMsg)
  end
end

local tGCC_Symbol_Template = GCC_Symbol_Template()
tGCC_Symbol_Template:run()
