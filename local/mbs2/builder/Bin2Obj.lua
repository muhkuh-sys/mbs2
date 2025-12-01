----------------------------------------------------------------------------------------------------------------------
--
-- HBoot image compiler
--
-- This builder provides the "HBootImage" function. It is a simple interface to the HBoot image compiler for
-- non-secure images. Currently the old Python tool from the "mbs" buildsystem is used. As soon as this bug is
-- fixed, we can update to something more recent: https://ticket.hilscher.com/browse/NXTHBOTIMG-192
--

local tBuilder = {
  id = 'Bin2Obj',
  version = '1.0.0'
}


function tBuilder:applyToEnv(tEnv, tCfg)
  local tMbs = tEnv.mbs

  function tEnv:Bin2Obj(strOutputPath, strInputPath, tParameter)
    tParameter = tParameter or {}

    local _tMbs = self.mbs
    local strBfdName = _tMbs.GCC_BFDNAME
    local strBfdArch = _tMbs.GCC_BFDARCH
    local strObjcopy = _tMbs.GCC_OBJCOPY

    -- Get the section name from the parameter. Default to ".rodata".
    local strSectionName = tParameter.SECTION_NAME or '.rodata'

    -- The default symbol names are generated from the complete input path.
    -- Replace it with the file name only.
    local path = require 'pl.path'
    local strFlatPath = '_binary_' .. string.gsub(strInputPath, '[/.]', '_')
    local strFlatFile = tParameter.SYMBOL_NAME
    if strFlatFile==nil then
      strFlatFile = '_binary_' .. string.gsub(path.basename(strInputPath), '[/.]', '_')
    end

    AddJob(
      strOutputPath,
      self.labelprefix .. 'Bin2Obj ' .. strOutputPath,
      table.concat({
        strObjcopy,
        '-I', 'binary',
        '-O', strBfdName,
        '-B', strBfdArch,
        '--rename-section', '.data=' .. strSectionName,
        '--redefine-sym',  strFlatPath .. '_end=' .. strFlatFile .. '_end',
        '--redefine-sym',  strFlatPath .. '_size=' .. strFlatFile .. '_size',
        '--redefine-sym',  strFlatPath .. '_start=' .. strFlatFile .. '_start',
        strInputPath,
        strOutputPath
      }, ' ')
    )
    AddDependency(strOutputPath, strInputPath)

    return strOutputPath
  end

  return true
end


return tBuilder
