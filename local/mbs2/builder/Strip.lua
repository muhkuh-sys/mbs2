local tBuilder = {
  id = 'Strip',
  version = '1.0.0'
}


function tBuilder:applyToEnv(_, tEnv, tCfg)
  local tMbs = tEnv.mbs

  function tEnv:Strip(strOutputPath, strInputPath, astrOptions)
    local _tMbs = self.mbs
    local strStrip = _tMbs.GCC_STRIP

    local astrCmd = {
        strStrip,
        '-o', strOutputPath
    }

    local strType = type(astrOptions)
    if strType=='string' then
      -- Convert a single sting to a table.
      astrOptions = { astrOptions }
    elseif strType=='nil' then
      -- Set default options if nothing was specified.
      astrOptions = {
        '--strip-unneeded',
        '--enable-deterministic-archives'
      }
    elseif strType~='table' then
      error('Invalid options, must be string or table.')
    end

    for _, strOption in ipairs(astrOptions) do
      if type(strOption)=='string' then
        table.insert(astrCmd, strOption)
      end
    end

    -- Add the file as the last element.
    table.insert(astrCmd, strInputPath)

    AddJob(
      strOutputPath,
      self.labelprefix .. 'Strip ' .. strOutputPath,
      table.concat(astrCmd, ' ')
    )
    AddDependency(strOutputPath, strInputPath)

    return strOutputPath
  end

  return true
end


return tBuilder
