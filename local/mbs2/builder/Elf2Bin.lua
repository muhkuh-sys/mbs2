----------------------------------------------------------------------------------------------------------------------
--
-- HBoot image compiler
--
-- This builder provides the "HBootImage" function. It is a simple interface to the HBoot image compiler for
-- non-secure images. Currently the old Python tool from the "mbs" buildsystem is used. As soon as this bug is
-- fixed, we can update to something more recent: https://ticket.hilscher.com/browse/NXTHBOTIMG-192
--

local tBuilder = {
  id = 'Elf2Bin',
  version = '1.0.0'
}


function tBuilder:applyToEnv(tEnv, tCfg)
  local tMbs = tEnv.mbs

  function tEnv:Elf2Bin(strOutputPath, strInputPath)
    local _tMbs = self.mbs
    local strObjcopy = _tMbs.GCC_OBJCOPY

    AddJob(
      strOutputPath,
      self.labelprefix .. 'Elf2Bin ' .. strOutputPath,
      table.concat({
        strObjcopy,
        '-O', 'binary',
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
