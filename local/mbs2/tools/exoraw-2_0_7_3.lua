local tTool = {
  id = 'exoraw',
  version = '2.0.7.3'
}



function tTool:applyToEnv(tEnv, tCfg)
  -- FIXME: Get this from somewhere else.
  local strExoRawPath = '/home/cthelen/.mbs/depack/com.hilscher.muhkuh/exoraw/exoraw-2.0.7_2/exoraw'

  function tEnv:ExoRaw(strOutputPath, strInputPath)
    local astrCmd = {
        strExoRawPath,
        '-b',
        '-q',
        '-o', strOutputPath,
        strInputPath
    }

    AddJob(
      strOutputPath,
      self.labelprefix .. 'ExoRaw ' .. strOutputPath,
      table.concat(astrCmd, ' ')
    )
    AddDependency(strOutputPath, strInputPath)

    return strOutputPath
  end

  return true
end


return tTool
