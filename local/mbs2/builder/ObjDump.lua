local tBuilder = {
  id = 'ObjDump',
  version = '1.0.0'
}


function tBuilder:applyToEnv(_, tEnv, tCfg)
  local tMbs = tEnv.mbs

  function tEnv:ObjDump(strOutputPath, strInputPath, astrOptions)
    local _tMbs = self.mbs
    local strObjdump = _tMbs.GCC_OBJDUMP

    local astrCmd = {
        strObjdump
    }

    local strType = type(astrOptions)
    if strType=='string' then
      -- Convert a single sting to a table.
      astrOptions = { astrOptions }
    elseif strType=='nil' then
      -- Set default options if nothing was specified.
      astrOptions = {
        '--disassemble',
        '--source',
        '--all-headers',
        '--wide'
      }
    else
      error('Invalid options, must be string or table.')
    end

    for _, strOption in ipairs(astrOptions) do
      if type(strOption)=='string' then
        table.insert(astrCmd, strOption)
      end
    end

    table.insert(astrCmd, strInputPath)
    table.insert(astrCmd, '>' .. strOutputPath)

    AddJob(
      strOutputPath,
      self.labelprefix .. 'ObjDump ' .. strOutputPath,
      table.concat(astrCmd, ' ')
    )
    AddDependency(strOutputPath, strInputPath)

    return strOutputPath
  end

  return true
end


return tBuilder
