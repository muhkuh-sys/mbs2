----------------------------------------------------------------------------------------------------------------------
--
-- HBoot image compiler
--
-- This builder provides the "HBootImage" function. It is a simple interface to the HBoot image compiler for
-- non-secure images. Currently the old Python tool from the "mbs" buildsystem is used. As soon as this bug is
-- fixed, we can update to something more recent: https://ticket.hilscher.com/browse/NXTHBOTIMG-192
--

local tBuilder = {
  id = 'hboot',
  version = '1.0.0'
}


local atMapAsicToNetxType = {
  ['NETX90'] = 'NETX90'
}


local atMapNetxTypeToPatchTable = {
  ['NETX90B'] = 'hboot_netx90b_patch_table.xml',
  ['NETX90C'] = 'hboot_netx90c_patch_table.xml',
  ['NETX90']  = 'hboot_netx90_patch_table.xml'
}

function tBuilder:applyToEnv(tEnv, tCfg)
  -- TODO: Move this to a "tool" instance.
  local tMbs = tEnv.mbs
  tMbs.HBOOTIMAGECOMPILER_PATH = '/home/cthelen/Tools/hboot_image_compiler/0.0.1'

  function tEnv:HBootImage(strOutputPath, strInputPath, tHBootAttributes)
    local strPythonInterpreter = '/usr/bin/python3.10'

    local _tMbs = self.mbs
    local strHBootImageCompilerPath = _tMbs.HBOOTIMAGECOMPILER_PATH

    local strNetxType = tHBootAttributes.netx_type
    if type(strNetxType)~='string' then
      local strAsicTyp = _tMbs.ASIC_TYP
      if type(strAsicTyp)=='string' then
        strNetxType = atMapAsicToNetxType[strAsicTyp]
      end
    end
    if type(strNetxType)~='string' then
      error('The netX type is not set and there is no ASIC_TYP.')
    end

    local strPatchTable = tHBootAttributes.patch_table
    if type(strPatchTable)~='string' then
      strPatchTable = atMapNetxTypeToPatchTable[strNetxType]
      if type(strPatchTable)~='string' then
        error('No patch table set.')
      end
    end

    local path = require 'pl.path'
    if path.isabs(strPatchTable)~=true then
      strPatchTable = path.join(strHBootImageCompilerPath, 'patch_table', strPatchTable)
    end

    local strObjCopy = _tMbs.GCC_OBJCOPY
    if type(strObjCopy)~='string' then
      error('No "objcopy" set.')
    end
    local strObjDump = _tMbs.GCC_OBJDUMP
    if type(strObjDump)~='string' then
      error('No "objdump" set.')
    end
    local strReadElf = _tMbs.GCC_READELF
    if type(strReadElf)~='string' then
      error('No "readelf" set.')
    end

    local atKnownFiles = tHBootAttributes.HBOOTIMAGE_KNOWN_FILES
    local strAliases = ''
    local astrDependencies = {}
    if type(atKnownFiles)=='table' then
      local astrAliases = {}
      for strAliasID, strAliasPath in pairs(atKnownFiles) do
        table.insert(astrAliases, '--alias ' .. strAliasID .. '=' .. strAliasPath)
        table.insert(astrDependencies, strAliasPath)
      end
      -- Sort the table to get a reproduceable list.
      table.sort(astrAliases)
      strAliases = table.concat(astrAliases, ' ')
    end

    AddJob(
      strOutputPath,
      self.labelprefix .. 'HBootImage ' .. strOutputPath,
      strPythonInterpreter .. ' ' .. strHBootImageCompilerPath .. ' ' ..
      strInputPath .. ' ' .. strOutputPath .. ' ' ..
      '--netx-type ' .. strNetxType .. ' ' ..
      '--objcopy ' .. strObjCopy .. ' ' ..
      '--objdump ' .. strObjDump .. ' ' ..
      '--readelf ' .. strReadElf .. ' ' ..
      '--patch-table ' .. strPatchTable .. ' ' ..
      strAliases
    )
    for _, strDependency in ipairs(astrDependencies) do
      AddDependency(strOutputPath, strDependency)
    end
  end

  return true
end


return tBuilder
