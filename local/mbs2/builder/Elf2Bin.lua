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

  function tEnv:Elf2Bin(strOutputPath, strInputPath, astrOnlySections)
    local _tMbs = self.mbs
    local strObjcopy = _tMbs.GCC_OBJCOPY

    local astrCmd = {
        strObjcopy,
        '-O', 'binary'
    }

    if type(astrOnlySections)=='string' then
      astrOnlySections = { astrOnlySections }
    end
    if type(astrOnlySections)=='table' then
      for _, strOnlySection in ipairs(astrOnlySections) do
        if type(strOnlySection)=='string' then
          table.insert(astrCmd, '--only-section=' .. strOnlySection)
        end
      end
    end

    table.insert(astrCmd, strInputPath)
    table.insert(astrCmd, strOutputPath)

    AddJob(
      strOutputPath,
      self.labelprefix .. 'Elf2Bin ' .. strOutputPath,
      table.concat(astrCmd, ' ')
    )
    AddDependency(strOutputPath, strInputPath)

    return strOutputPath
  end

  return true
end


return tBuilder
