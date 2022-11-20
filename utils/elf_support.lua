-- create an object of the module
local tElf_Support = {}

local pl = require'pl.import_into'()

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
local strLpeg_Support = "mbs2/utils/lpeg_support.lua"
local tLpeg_Support =  GetModule(strLpeg_Support)

local lpeg = require "lpeglabel"

-- Save typing:
local P, V, Cg, Ct, Cc, S, R, C, Cf, Cb, Cs, match,
OptionalSpace,Space,Comma,
Spaces,OptSpace,UpTo,Anywhere,List,SetEitherOrPattern,Gsub =
lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.S, lpeg.R, lpeg.C, lpeg.Cf, lpeg.Cb, lpeg.Cs, lpeg.match,
tLpeg_Support.OptionalSpace,tLpeg_Support.Space,tLpeg_Support.Comma,
tLpeg_Support.Spaces,tLpeg_Support.OptSpace,tLpeg_Support.UpTo,tLpeg_Support.Anywhere,
tLpeg_Support.List,tLpeg_Support.SetEitherOrPattern,tLpeg_Support.Gsub

---------------------------------------------------------------------------------------------------------------------
--
-- Auxiliary functions
--


-- process the command and return the result as string if the result is true
local function executeCmd(tCmd)

  if tCmd.CMD == nil then
    local strMsg = string.format("ERROR: Missing 'CMD' of the command. ")
    error(strMsg)
  elseif tCmd.SOURCE == nil then
      local strMsg = string.format("ERROR: Missing 'SOURCE' of the command. ")
      error(strMsg)
  elseif tCmd.FLAGS == nil then
    local strMsg = string.format("ERROR: Missing 'FLAGS' of the command. ")
    error(strMsg)
  end

  if not (type(tCmd.FLAGS) == "table" or type(tCmd.FLAGS) == "string") then
    local strMsg = string.format("ERROR: 'FLAGS' must be a table or a string. ")
    error(strMsg)
  elseif type(tCmd.CMD) ~= "string" then
    local strMsg = string.format("ERROR: 'CMD' must be a string. ")
    error(strMsg)
  elseif type(tCmd.SOURCE) ~= "string" then
    local strMsg = string.format("ERROR: 'SOURCE' must be a string. ")
    error(strMsg)
  end

  tCmd.FLAGS = (type(tCmd.FLAGS) == "table") and table.concat(tCmd.FLAGS,' ') or tCmd.FLAGS

  local strCMD_TEMPLATE = "${CMD} ${FLAGS} ${SOURCE}"
  local strCmd = tLpeg_Support.Gsub(strCMD_TEMPLATE,tCmd)

  local fResult,strReturnCode,strStdout,strError = pl.utils.executeex(strCmd)
  if fResult ~= true then
    local strMsg = string.format("ERROR: Processing of the command '%s' failed with the error message: '%s'",strCmd,strError)
    error(strMsg)
  end

  return strStdout
end


-- Auxiliary function: transform table to set (values)
local fToSet = function(tmatch)
  local tSet = {}
  for _,strValue in pairs(tmatch) do
    tSet[strValue] = true
  end
  return tSet
end

-- Auxiliary function: Base ^ Exponent
local fPow = function(tmatch)
  local uiBase = tonumber(tmatch.Base)
  local uiExponent = tonumber(tmatch.Exponent)
  local uiResult = nil
  if uiBase ~= nil and uiExponent ~= nil then
    uiResult = uiBase^uiExponent
  end
  return uiResult
end


-- Auxiliary function: transform hexadecimal values
local tonumber_base16 = function(tmatch)
  return tonumber(tmatch, 16)
end


---------------------------------------------------------------------------------------------------------------------
--
-- Module functions of Elf_Support
--


--- extract "Entry point address" from elf file header.
function tElf_Support:get_segment_table(tEnv,strFileName,astrSegmentsToConsider)

  local astrSegmentsToConsiderSet = (astrSegmentsToConsider ~= nil) and pl.Set(astrSegmentsToConsider) or nil

  -- pattern of segment table
  local ELF_SegmentTable =
  Ct{
    P{
      "start", --> this tells LPEG which rule to process first
      start     = V"Idx" * V"Name" * V"Size" * V"VMA" * V"LMA" * V"File_off" * V"Allgn" * V"Flags" + 1* V"start",
      Idx       = UpTo(R("09")^1,Space,"Idx",tonumber) + 1*V"Idx",
      Name      = UpTo(P(1),Space + -1,"Name") + 1*V"Name",
      Size      = UpTo(R("09","af", "AZ")^1,Space,"Size",tonumber_base16) + 1*V"Size",
      VMA       = UpTo(R("09","af", "AZ")^1,Space,"VMA",tonumber_base16) + 1*V"VMA",
      LMA       = UpTo(R("09","af", "AZ")^1,Space,"LMA",tonumber_base16) + 1*V"LMA",
      File_off  = UpTo(R("09","af", "AZ")^1,Space,"File_off",tonumber_base16) + 1*V"File_off",
      Allgn     = Cg(
                    Ct(
                      UpTo(R("09")^1,P"**","Base") *
                      UpTo(R("09")^1,Space,"Exponent")
                      ) / fPow
                    ,"Allgn")
                  + 1*V"Allgn",
      Flags     = Cg(Ct(List((P(1) - Comma)^1,OptSpace(P","))) / fToSet,"Flags"),
    }
  }

  -- process objdump command and return the result as string
  local strStdout = executeCmd(
    {
      CMD = tEnv.OBJDUMP,
      FLAGS = {'-h', '-w'},
      SOURCE = strFileName
    }
  )

  local atSegments = {}
  for strLine in pl.stringx.lines(strStdout) do
    local tmatch_segmentTable = ELF_SegmentTable:match(strLine)
    if tmatch_segmentTable ~= nil then
      if astrSegmentsToConsiderSet == nil or astrSegmentsToConsiderSet[tmatch_segmentTable.Name] ~= nil then
        atSegments[#atSegments + 1] = tmatch_segmentTable
      end
    end
  end

  return atSegments
end


---
function tElf_Support:segment_get_name(tSegment)
  return tSegment['name']
end


---
function tElf_Support:segment_get_size(tSegment)
  return tSegment['size']
end


---
function tElf_Support:segment_is_loadable(tSegment)
  return tSegment.Flags["CONTENTS"] == true and
          tSegment.Flags["ALLOC"] == true and
          tSegment.Flags["LOAD"] == true
end



--- extract load address
function tElf_Support:get_load_address(atSegments)
  -- Set an invalid lma
  local ulLowestLma = tonumber(tostring(100000000),16)

  -- Loop over all segments.
  for _,tSegment in pairs(atSegments) do
    -- Get the segment with the lowest 'lma' entry which has also the flags 'CONTENTS', 'ALLOC' and 'LOAD'.
    if tSegment.LMA < ulLowestLma and tSegment.Flags["CONTENTS"] == true and tSegment.Flags["ALLOC"] == true and tSegment.Flags["LOAD"] == true then
      ulLowestLma = tSegment.LMA
    end
  end

  if ulLowestLma == tonumber(tostring(100000000),16) then
    local strMsg = string.format("Error: Failed to extract load address!")
    error(strMsg)
  end

  return ulLowestLma
end


--- get estimated bin size
function tElf_Support:get_estimated_bin_size(atSegments)
  local ulLoadAddress = self:get_load_address(atSegments)
  local ulBiggestOffset = 0

  -- Loop over all segments.
  for _,tSegment in pairs(atSegments) do
    -- Get the segment with the biggest offset to ulLoadAddress which has also the flags 'CONTENTS', 'ALLOC' and 'LOAD'.
    if tSegment.Flags["CONTENTS"] == true and tSegment.Flags["ALLOC"] == true and tSegment.Flags["LOAD"] == true then
      local ulOffset = tSegment.LMA + tSegment.Size - ulLoadAddress
      if ulOffset > ulBiggestOffset then
        ulBiggestOffset = ulOffset
      end
    end
  end

  return ulBiggestOffset
end


--- extract "Entry point address" from elf file header.
-- Get the start address.
-- Try the global symbol first, then fall back to the file header.
-- The global symbol is better, as it holds not only the plain address, but
-- also thumb information.
-- The address from the file header does not have any thumb information.
function tElf_Support:get_exec_address(tEnv,strFileName)

  -- be pessimistic
  local iResult = false

  -- return value
  local uiValue = nil


  -- pattern of elf symbols
  local ELF_Symbols =
  Ct{
    P{
      "start", --> this tells LPEG which rule to process first
      start = V"Num" * V"Value" * V"Size" * V"Type" * V"Bind" * V"Vis" * V"Ndx" * V"Name" + 1* V"start",
      Num   = UpTo(R("09")^1,P':' * Space,"Num",tonumber),
      Value = UpTo(R("09","af", "AF")^1,Space,"Value",tonumber_base16),
      Size  = UpTo(R("09")^1,Space,"Size",tonumber),
      Type  = UpTo(R("09","af", "AZ")^1,Space,"Type"),
      Bind  = Cg(P'GLOBAL',"Bind") * Space, -- Only GLOBAL!
      Vis   = Cg(P"DEFAULT","Vis") * Space,
      Ndx   = UpTo(R("09","af", "AZ")^1,Space,"Ndx"),
      Name  = Cg(P"start","Name") * (Space + -1),
    }
  }

  -- pattern of entry point address
  local ELF_EntryPoint = -- e.g. "Entry point address:               0x4030"
  Ct{
    P{
      "start", --> this tells LPEG which rule to process first
      start =V"Name" * V"Value" + 1* V"start",
      Value = P"0x" * UpTo(R("09","af", "AF")^1,Space + -1,"Value",tonumber_base16) + 1*V"Value",
      Name  = P"Entry point address:" + 1*V"Name",
    }
  }

  -- process readelf command and return the result as string
  local strStdout = executeCmd(
    {
      CMD = tEnv.READELF,
      FLAGS = {'--file-header'},
      SOURCE = strFileName
    }
  )

  for strLine in pl.stringx.lines(strStdout) do
    local tmatch_entryPoint = ELF_EntryPoint:match(strLine)
    if tmatch_entryPoint ~= nil then
      if uiValue ~= nil then
        local strMsg = string.format("ERROR: There is a further 'Entry point address' in the elf file header.")
        error(strMsg)
      end

      uiValue = tmatch_entryPoint.Value
      iResult = true
    end
  end

  if uiValue == nil then
    -- process readelf command and return the result as string
    local strStdout = executeCmd(
      {
        CMD = tEnv.READELF,
        FLAGS = {'--syms'},
        SOURCE = strFileName
      }
    )

    for strLine in pl.stringx.lines(strStdout) do
      local tmatch_entryPoint = ELF_Symbols:match(strLine)
      if tmatch_entryPoint ~= nil then

        if uiValue ~= nil then
          local strMsg = string.format("ERROR: There is a further 'Entry point address' in the elf file header.")
          error(strMsg)
        end

        uiValue = tmatch_entryPoint.Value
        iResult = true
      end
    end
  end

  if iResult == false then
    local strMsg = string.format("ERROR: Failed to find the 'start address' in the elf file.")
    error(strMsg)
  end

  return uiValue
end


--- extract symbols from ELF file.
function tElf_Support:get_symbol_table(tEnv,strFileName)

  -- symbol table
  local atSymbols = {}

  -- pattern of elf symbols
  local ELF_Symbols =
  Ct{
    P{
      "start", --> this tells LPEG which rule to process first
      start = V"Num" * V"Value" * V"Size" * V"Type" * V"Bind" * V"Vis" * V"Ndx" * V"Name" + 1* V"start",
      Num   = UpTo(R("09")^1,P':' * Space,"Num",tonumber),
      Value = UpTo(R("09","af", "AF")^1,Space,"Value",tonumber_base16),
      Size  = UpTo(R("09")^1,Space,"Size",tonumber),
      Type  = UpTo(R("09","af", "AZ")^1,Space,"Type"),
      Bind  = Cg(P'GLOBAL',"Bind") * Space, -- Only GLOBAL!
      Vis   = UpTo(R("09","af", "AZ")^1,Space,"Vis"),
      Ndx   = UpTo(R("09","af", "AZ")^1,Space,"Ndx"),
      Name  = UpTo(P(1),Space + -1,"Name"),
    }
  }

  -- process readelf command and return the result as string
  local strStdout = executeCmd(
    {
      CMD = tEnv.READELF,
      FLAGS = {'--symbols', '--wide'},
      SOURCE = strFileName
    }
  )

  local atSymbols_multiEntry = {}

  -- extract symbol information with pattern of ELF symbols
  for strLine in pl.stringx.lines(strStdout) do
    local tmatch_symbols = ELF_Symbols:match(strLine)
    if tmatch_symbols ~= nil then
      local uiValue = tmatch_symbols.Value

      -- Does the symbol already exist? Is the value different?
      if (atSymbols[tmatch_symbols.Name] ~= nil and atSymbols[tmatch_symbols.Name] ~= uiValue) or atSymbols_multiEntry[tmatch_symbols.Name] == true then
        -- The symbol exists more than one time with different values. Now that's a problem.
        local strMsg = string.format("Error: The symbol:'%s' is still available with a different value in the table.",tmatch_symbols.Name)
        print(strMsg)

        -- delete symbol from the table and add it to atSymbols_multiEntry
        atSymbols[tmatch_symbols.Name] = nil
        atSymbols_multiEntry[tmatch_symbols.Name] = true

      -- Does the symbol already exist? Is the value the same?
      else
        if atSymbols[tmatch_symbols.Name] ~= nil and atSymbols[tmatch_symbols.Name] == tmatch_symbols.Value then
          local strMsg = string.format("Warning: The symbol:'%s' is still available with the same value in the table.",tmatch_symbols.Name)
          -- print(strMsg)
        end

        atSymbols[tmatch_symbols.Name] = uiValue
      end
    end
  end

  return atSymbols
end


--- extract macro symbols from elf file.
function tElf_Support:get_macro_definitions(tEnv,strFileName)
  -- Macro symbol table
  local atElfMacros = {}

  -- FIXME: The Definition of macros must be adapted to the gdwarf version (currently version 2)
  -- NOTE: This matches only macros without parameter.
  -- Setup of different marcro definitions
  local tMacro_definition =
  {
    "DW_MACINFO_define",
    "MACRO_GNU_define_indirect",
    "DW_MACRO_define_strp" -- match gcc 9.2 output
  }

  -- pattern of macro definition
  local ELF_MACRO =
  Ct{
    P{
      "start", --> this tells LPEG which rule to process first
      start = V"Macro_definition" * V"String_const" * V"Macro" * V"Value" + 1*V"start",
      Macro_definition = SetEitherOrPattern(tMacro_definition) + 1 * V"Macro_definition",
      String_const = OptSpace(P"-") *  P'lineno' * OptSpace(P":") * OptSpace(R("09","af", "AF")^1) * P'macro' * OptSpace(P":"),
      Macro = UpTo(P(1),Space,"Name") ,
      Value = UpTo(P(1)^1,-1,"Value"), -- Could be a value or a strings
    }
  }

  -- process readelf command and return the result as string
  local strStdout = executeCmd(
    {
      CMD = tEnv.READELF,
      FLAGS = {'--debug-dump=macro'},
      SOURCE = strFileName
    }
  )

  local atMacros_multiEntry = {}
  -- extract macro information
  for strLine in pl.stringx.lines(strStdout) do
    local tmatch_macro = ELF_MACRO:match(strLine)
    if tmatch_macro ~= nil then
      -- Does the macro already exist? Is the value different?
      if (atElfMacros[tmatch_macro.Name] ~= nil and atElfMacros[tmatch_macro.Name] ~= tmatch_macro.Value) or atMacros_multiEntry[tmatch_macro.Name] == true then
        -- The macro exists more than one time with different values. Now that's a problem.
        local strMsg = string.format("Error: The symbol:'%s' is still available with a different value in the table.",tmatch_macro.Name)
        -- print(strMsg)

        -- delete macro symbol from the table and add it to atMacros_multiEntry
        atElfMacros[tmatch_macro.Name] = nil
        atMacros_multiEntry[tmatch_macro.Name] = true

      -- Does the macro already exist? Is the value the same?
      else
        if atElfMacros[tmatch_macro.Name] ~= nil and atElfMacros[tmatch_macro.Name] == tmatch_macro.Value then
          local strMsg = string.format("Warning: The symbol:'%s' is still available with the same value in the table.",tmatch_macro.Name)
          -- print(strMsg)
        end

        atElfMacros[tmatch_macro.Name] = tmatch_macro.Value
      end
    end
  end

  return atElfMacros
end


--- Get back the tree structure of dwarf debug_info
-- @param strFileName path of ELF file
-- @return atRootTree_DebugInfo tree structure of debug_info as table
  -- information dwarf:
    -- used in the gcc : - -gdwarf-2
    -- Produce debugging information in DWARF version 2 format (if that is supported). This is the format used by DBX on IRIX 6.
    -- https://dwarfstd.org/doc/dwarf-2.0.0.pdf
    -- https://eli.thegreenplace.net/2011/02/07/how-debuggers-work-part-3-debugging-information/
  --
  -- Tree structure of debug_info (https://www.ibm.com/docs/en/zos/2.4.0?topic=architecture-dwarf-program-information):
    -- e.g. TAG: <1><42>: Abbrev Number: 5 (DW_TAG_enumeration_type)
    -- <1> : nested level indicator
    -- <42> : section offset
    -- enumeration_type : name of tag
    -- Abbrev Number: 5 : see debug_abbrev
  --
  -- .debug_abbrev	Abbreviations used in the .debug_info section
  -- https://developer.ibm.com/articles/au-dwarf-debug-format/#:~:text=DWARF%20(debugging%20with%20attributed%20record,can%20have%20children%20or%20siblings.
  --
function tElf_Support:get_debug_structure(tEnv,strFileName)

  -- pattern of Debugging Information Entry (DIE)
  local DW_TAG =
  Ct{
    P{
      "start", --> this tells LPEG which rule to process first
      start                  = V"Nested_Level_Indicator" * V"Section_Offset" * V"Abbrev_String" * V"Abbrev_Number" * V"TAG_Name" + 1 * V"start",
      Nested_Level_Indicator = P'<' * UpTo(R("09"),P'>',"Nested_Level_Indicator",tonumber) + 1 * V"Nested_Level_Indicator",
      Section_Offset         = P'<' * UpTo(R("09","af", "AF"),P'>:',"Section_Offset") + 1 * V"Section_Offset",
      Abbrev_String          = P'Abbrev Number:' + 1 * V"Abbrev_String",
      Abbrev_Number          = Cg(R("09")^1 / tonumber,"Abbrev_Number") + 1 * V"Abbrev_Number",
      TAG_Name               = P'(DW_TAG_' * UpTo(P(1),P')',"TAG_Name") + 1 * V"TAG_Name"
    }
  }

  -- pattern of DW_AT (Attribute) of Node
  local DW_AT =
  Ct{
    P{
      "start", --> this tells LPEG which rule to process first
      start          = V"Section_Offset" * V"Attribute_Name" * V"Value" + 1 * V"start",
      Section_Offset = P'<' * UpTo(R("09","af", "AF"),P'>',"Section_Offset"),
      Attribute_Name = P'DW_AT_' * UpTo(P(1),P':' + Space,"Attribute_Name") * P':'^0 + 1 * V"Attribute_Name",
      Value          = OptionalSpace * UpTo(P(1),P(-1),"Value")
    }
  }

  -- process readelf command and return the result as string
  local strStdout = executeCmd(
    {
      CMD = tEnv.READELF,
      FLAGS = {'--debug-dump=info'},
      SOURCE = strFileName
    }
  )

  -- create root table atRootTree_DebugInfo and the auxiliary variable atNodeTree
  local atRootTree_DebugInfo = {}
  local atNodeTree

  local atKeyTagNode = {}

  -- local tRoot_Compilation_Unit

  -- extract information with pattern of "Debugging Information Entry" (DIE) and of attributes (DW_AT) of the nodes
  for strLine in pl.stringx.lines(strStdout) do
    local tmatch_DW_TAG = DW_TAG:match(strLine)
    if tmatch_DW_TAG ~= nil then

      local strKeyTagNode = string.format("<%s><%s>",tostring(tmatch_DW_TAG.Nested_Level_Indicator),tmatch_DW_TAG.Section_Offset)
      if atKeyTagNode[strKeyTagNode] ~= nil then
        local strMsg = string.format("The tag node:'%s' is still available.",strKeyTagNode)
        error(strMsg)
      end
      atKeyTagNode[#atKeyTagNode + 1] = strKeyTagNode

      -- a new root Compilation_Unit node
      if tmatch_DW_TAG.Nested_Level_Indicator == 0 then
        -- add the new root Compilation_Unit node
        atRootTree_DebugInfo[strKeyTagNode] =
        {
          tNodeProperties =
          {
            uiNested_Level_Indicator = tmatch_DW_TAG.Nested_Level_Indicator,
            uiSection_Offset = tmatch_DW_TAG.Section_Offset,
            uiAbbrev_Number = tmatch_DW_TAG.Abbrev_Number,
            strTAG_Name = tmatch_DW_TAG.TAG_Name,
          },
          tChildNodes = {},
          tAttributes = {},
          tPrevNode = nil,
          -- tRoot_Compilation_Unit = {},
        }

        -- add the current Compilation_Unit root node table
        -- tRoot_Compilation_Unit = atRootTree_DebugInfo[strKeyTagNode]
        -- atRootTree_DebugInfo[strKeyTagNode].tRoot_Compilation_Unit = tRoot_Compilation_Unit

        -- advance into the current Compilation_Unit root node
        atNodeTree = atRootTree_DebugInfo[strKeyTagNode]
      else
        --process child nodes of the current Compilation_Unit root node
        if atNodeTree.tNodeProperties.uiNested_Level_Indicator == tmatch_DW_TAG.Nested_Level_Indicator then
          -- A further child node - go back to the parent node and add it to the child node table
          local strNodeName = string.format("<%s><%s>",tostring(atNodeTree.tNodeProperties.Nested_Level_Indicator),atNodeTree.tNodeProperties.Section_Offset)
          if atNodeTree.tPrevNode == nil then
            local strMsg = string.format("No previous node information available of node '%s'!",strNodeName)
            error(strMsg)
          end
          atNodeTree = atNodeTree.tPrevNode

        elseif atNodeTree.tNodeProperties.uiNested_Level_Indicator > tmatch_DW_TAG.Nested_Level_Indicator then
          -- It is a new branch of the tree - go back to the corresponding parent node
          local uiNested_Level_Indicator = atNodeTree.tNodeProperties.uiNested_Level_Indicator

          -- return to the parent node with the corresponding nested level indicator
          while (uiNested_Level_Indicator > tmatch_DW_TAG.Nested_Level_Indicator - 1) do
            local strNodeName = string.format("<%s><%s>",tostring(atNodeTree.tNodeProperties.Nested_Level_Indicator),atNodeTree.tNodeProperties.Section_Offset)
            if atNodeTree.tPrevNode == nil then
              local strMsg = string.format("No previous node information available of node '%s'!",strNodeName)
              error(strMsg)
            end
            atNodeTree = atNodeTree.tPrevNode

            uiNested_Level_Indicator = atNodeTree.tNodeProperties.uiNested_Level_Indicator
          end
        elseif atNodeTree.tNodeProperties.uiNested_Level_Indicator < tmatch_DW_TAG.Nested_Level_Indicator then
          -- The nested level indicator is higher -> a new child node - nothing to do
        end

        -- add child node entries to the parent node
        atNodeTree.tChildNodes[strKeyTagNode] =
        {
          tNodeProperties =
          {
            uiNested_Level_Indicator = tmatch_DW_TAG.Nested_Level_Indicator,
            uiSection_Offset         = tmatch_DW_TAG.Section_Offset,
            uiAbbrev_Number          = tmatch_DW_TAG.Abbrev_Number,
            strTAG_Name              = tmatch_DW_TAG.TAG_Name,
          },
          tChildNodes = {},
          tAttributes = {},
          tPrevNode = atNodeTree,
          -- tRoot_Compilation_Unit = tRoot_Compilation_Unit,
        }

        -- advance into the current node
        atNodeTree = atNodeTree.tChildNodes[strKeyTagNode]
      end
    else
      local tmatch_DW_AT = DW_AT:match(strLine)
      if tmatch_DW_AT ~= nil then
        -- add the attribute to the current node
        atNodeTree.tAttributes[tmatch_DW_AT.Attribute_Name] =
        {
          Section_Offset = tmatch_DW_AT.Section_Offset,
          Attribute_Name = tmatch_DW_AT.Attribute_Name,
          Value          = tmatch_DW_AT.Value
        }
      end
    end
  end

  return atRootTree_DebugInfo
end


--- Extract symbols of the tree node debug_info table.
function tElf_Support:__iter_debug_info(atSymbols,atRootTree_DebugInfo,tSearchPattern,fExtractData)

  -- recursive function to get further into the tree structure of atRootTree_DebugInfo by using the search pattern table.
  local function iterRootTree(tTree,uiSearchPatternLevel)
    uiSearchPatternLevel = uiSearchPatternLevel or 1
    for _,tNode in pairs(tTree) do
      -- is the tag name equal to the search pattern?
      if tNode.tNodeProperties.strTAG_Name == tSearchPattern[uiSearchPatternLevel] then
        if #tSearchPattern <= uiSearchPatternLevel then
          -- end of search pattern has been reached
          fExtractData(tNode,atSymbols)
        else
          -- next level of the search pattern
          iterRootTree(tNode.tChildNodes,uiSearchPatternLevel + 1)
        end
      end

      -- apply dynamic search pattern: in the case of that the first entry of the search pattern could not be find in lower nested levels.
      if pl.tablex.size(tNode.tChildNodes) > 0 then
        iterRootTree(tNode.tChildNodes,uiSearchPatternLevel)
      end
    end
  end

  -- apply recursive function
  iterRootTree(atRootTree_DebugInfo)
end


--- Extract symbols of enumerator and structure nodes of the tree node debug_info.
function tElf_Support:get_debug_symbols(tEnv,strFileName)

  local atElfDebugSymbols = {}

  -- get debug info tree node table
  local atRootTree_DebugInfo = self:get_debug_structure(tEnv,strFileName)

  local tSearchPattern_enumerator =
  {
    [1] = "enumeration_type",
    [2] = "enumerator"
  }

  local tSearchPattern_structure =
  {
    [1] = "structure_type"
  }

  -- pattern of name attribute (DW_AT)
  local Name_Attribute = -- e.g. (indirect string, offset: 0x6f4): fnSend
  Ct{
    P{
      "start", --> this tells LPEG which rule to process first
      start  = V"String" * V"Offset" * V"Name" + 1*V"start",
      String = P'(indirect string, offset:',
      Offset = P"0x" * UpTo(R("09","af", "AF"),P'):',"Offset") + 1*V"Offset",
      Name  = OptionalSpace * UpTo(P(1),P(-1),"Name")
    }
  }

  --TODO: it is not clear whether the second position represents always the offset?
  -- the number after DW_OP_plus_uconst shows also the offset as decimal not hexa number
  local Struct_Offset = -- e.g. "2 byte block: 23 4   (DW_OP_plus_uconst: 4)" or "3 byte block: 23 80 1 	(DW_OP_plus_uconst: 128)"
  Ct{
    P{
      "start", --> this tells LPEG which rule to process first
      start  = V"String_Const" * V"Numb_Const" * V"Offset_hex" * V"Offset_dec"  + 1 * V"start",
      String_Const = P"byte block:" + 1 * V"String_Const" ,
      Numb_Const = R("09","af", "AF")^1 + 1 * V"Numb_Const",
      Offset_hex = UpTo(R("09","af", "AF"),Space,"Offset_hex",tonumber_base16) + 1* V"Offset_hex",
      Offset_dec = P'(DW_OP_plus_uconst:' * OptionalSpace * UpTo(R("09","af", "AF"),P')',"Offset_dec",tonumber) + 1 * V"Offset_dec"
    }
  }

  -- symbol extraction function of enumerator nodes
  local fExtractData_enumerator = function(tNode,atSymbols)

    local uiNested_Level_Indicator,uiSection_Offset = tostring(tNode.tNodeProperties.uiNested_Level_Indicator),tNode.tNodeProperties.uiSection_Offset

    if tNode.tAttributes == nil then
      local strMsg = string.format("Error: The attribute table is not available of node '<%s><%s>'",uiNested_Level_Indicator,uiSection_Offset)
      error(strMsg)
    end

    if tNode.tAttributes["name"] == nil then
      local strMsg = string.format("Error: The attribute 'name' is not available of node '<%s><%s>'",uiNested_Level_Indicator,uiSection_Offset)
      error(strMsg)
    end

    if tNode.tAttributes["const_value"] == nil then
      local strMsg = string.format("Error: The attribute 'const_value' is not available of node '<%s><%s>'",uiNested_Level_Indicator,uiSection_Offset)
      error(strMsg)
    end

    local tmatch_Attribute = Name_Attribute:match(tNode.tAttributes["name"].Value)
    if tmatch_Attribute == nil then
      local strMsg = string.format("Error: Failed to get a match of the name of the attribute 'name' of node '<%s><%s>'",uiNested_Level_Indicator,uiSection_Offset)
      error(strMsg)
    end

    local strName = tmatch_Attribute.Name
    local uiOffset = tonumber(tNode.tAttributes["const_value"].Value)

    if atSymbols[strName] ~= nil and atSymbols[strName] == uiOffset then
      local strMsg = string.format("Warning: The data '%s' is still available with the same offset value in the symbol table.",strName)
      -- print(strMsg)
    elseif atSymbols[strName] ~= nil and atSymbols[strName] ~= uiOffset then
      local strMsg = string.format("Error: The data '%s' is still available with a different offset value in the symbol table.",strName)
      error(strMsg)
    end

    -- finally, add data to the symbol table
    atSymbols[strName] = uiOffset
  end

  -- symbol extraction function of structure nodes
  local fExtractData_structure = function(tNode,atSymbols)
    local uiNested_Level_Indicator,uiSection_Offset = tostring(tNode.tNodeProperties.uiNested_Level_Indicator),tNode.tNodeProperties.uiSection_Offset

    if tNode.tAttributes == nil then
      local strMsg = string.format("Error: The attribute table is not available of node '<%s><%s>'",uiNested_Level_Indicator,uiSection_Offset)
      error(strMsg)
    end

    -- the node must have the attribute "name" - this attribute is not for all structure type nodes available!
    if tNode.tAttributes["name"] ~= nil then
      local tmatch_Structure_Name = Name_Attribute:match(tNode.tAttributes.name.Value)
      if tmatch_Structure_Name == nil then
        local strMsg = string.format("Error: Faild to extract the name of node '<%s><%s>'",uiNested_Level_Indicator,uiSection_Offset)
        error(strMsg)
      end
      local strStructureName = tmatch_Structure_Name.Name

      if tNode.tAttributes["byte_size"] == nil then
        local strMsg = string.format("Error: The attribute 'byte_size' is not available of node '<%s><%s>'",uiNested_Level_Indicator,uiSection_Offset)
        error(strMsg)
      end

      local strSizeName = "SIZEOF_" .. strStructureName
      local uiSizeValue = tonumber(tNode.tAttributes["byte_size"].Value,16)

      if atSymbols[strSizeName] ~= nil and atSymbols[strSizeName] == uiSizeValue then
        local strMsg = string.format("Warning: The data '%s' is still available with the same offset value in the symbol table.",strSizeName)
        -- print(strMsg)
      elseif atSymbols[strSizeName] ~= nil and atSymbols[strSizeName] ~= uiSizeValue then
        local strMsg = string.format("Error: The data '%s' is still available with a different offset value in the symbol table.",strSizeName)
        error(strMsg)
      end

      -- Generate a symbol with the size of the structure.
      atSymbols[strSizeName] = uiSizeValue

      -- get offset values of the child node of the structure
      local atChildNodes = tNode.tChildNodes
      for _,tChildNode in pairs(atChildNodes) do
        -- consider only "member" chilld nodes
        if tChildNode.tNodeProperties.strTAG_Name == "member" then
          -- the member node must have following attributes: data_member_location and name
          if tChildNode.tAttributes ~= nil and tChildNode.tAttributes.data_member_location ~= nil and tChildNode.tAttributes.name then
            local tmatch_Member_Offset = Struct_Offset:match(tChildNode.tAttributes.data_member_location.Value)
            local tmatch_Member_Name = Name_Attribute:match(tChildNode.tAttributes.name.Value)
            -- Does the offset value of data_member_location exist? Is the attribute name available?
            if tmatch_Member_Offset ~= nil and tmatch_Member_Name ~= nil then
              -- Generate symbols for the offset of each member.
              local strOffsetName = 'OFFSETOF_' .. strStructureName .. '_' .. tmatch_Member_Name.Name
              local uiOffsetValue = tmatch_Member_Offset.Offset_dec -- Use the decimal value entry in the pattern

              if atSymbols[strOffsetName] ~= nil and atSymbols[strOffsetName] == uiOffsetValue then
                local strMsg = string.format("Warning: The data '%s' is still available with the same offset value in the symbol table.",strOffsetName)
                -- print(strMsg)
              elseif atSymbols[strOffsetName] ~= nil and atSymbols[strOffsetName] ~= uiOffsetValue then
                local strMsg = string.format("Error: The data '%s' is still available with a different offset value in the symbol table.",strOffsetName)
                error(strMsg)
              end

              atSymbols[strOffsetName] = uiOffsetValue
            end
          end
        end
      end
    end
  end

  -- extract symbol information of enumeration_type (const value)
  -- enumeration_type -> childs: enumerator
  self:__iter_debug_info(atElfDebugSymbols,atRootTree_DebugInfo,tSearchPattern_enumerator,fExtractData_enumerator)

  -- extract symbol information of structure_type (size and member offset)
  -- structure_type -> childs: member
  self:__iter_debug_info(atElfDebugSymbols,atRootTree_DebugInfo,tSearchPattern_structure,fExtractData_structure)


  -- just debugging:
  --[[
  local rapidjson = require "rapidjson"
  local strPathData = "elf_debug_info.json"
  local function clearReference(tTable)
    for strKey,tValue in pairs(tTable) do
        tValue["tPrevNode"] = nil
        -- tValue["tRoot_Compilation_Unit"] = nil
      if next(tValue["tChildNodes"]) ~= nil then
        clearReference(tValue.tChildNodes)
      end
    end
  end
  clearReference(atRootTree_DebugInfo)
  local strRoot = rapidjson.encode(atRootTree_DebugInfo)
  local fResults, strErrMsg = pl.utils.writefile(strPathData, strRoot, false)
  --]]

  return atElfDebugSymbols
end


return tElf_Support