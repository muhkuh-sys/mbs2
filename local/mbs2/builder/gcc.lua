local tBuilder = {
  id = 'gcc',
  version = '1.0.0'
}

--- Translate an input path to an output path.
--- The default implementation writes the output to the same folder as the input file and just adds the extension.
--- THe settings mbs.TRANSLATE_FILENAME_OUTPUT_FOLDER and mbs.TRANSLATE_FILENAME_INPUT_PREFIX change this behaviour.
--- Setting mbs.TRANSLATE_FILENAME_OUTPUT_FOLDER to a non-empty string uses this as the output folder. It is joined
--- with each input path and the object extension. If an input path starts with the prefix defined in
--- mbs.TRANSLATE_FILENAME_INPUT_PREFIX, it is removed from the input path.
---
--- Examples:
---   input path  TRANSLATE_FILENAME_OUTPUT_FOLDER  TRANSLATE_FILENAME_INPUT_PREFIX  result
---   "src/a.c"   ""                                ""                               "src/a.c.o"
---   "src/a.c"   "targets"                         ""                               "targets/src/a.c.o"
---   "src/a.c"   "targets"                         "src"                            "targets/a.c.o"
---@param tSettings table
---@param strInputPath string The path to the input file.
---@return string # The translated path for the output file.
function tBuilder.translateFilename(tSettings, strInputPath)
  local strOutputPath
  local strOutputFolder = tSettings.mbs.TRANSLATE_FILENAME_OUTPUT_FOLDER
  if type(strOutputFolder)=='string' and strOutputFolder~='' then
    local path = require 'pl.path'
    -- Does the input file start with the common prefix?
    local strInputLocal = strInputPath
    local strInputPrefix = tSettings.mbs.TRANSLATE_FILENAME_INPUT_PREFIX
    if(
      type(strInputPrefix)=='string' and
      strInputPrefix~='' and
      path.common_prefix(strInputPath, strInputPrefix)==strInputPrefix
    ) then
      -- The input file starts with the common prefix. Remove it.
      -- NOTE: "relpath" seems to work with absolute paths only. Just add "/" as a prefix to both paths.
      strInputLocal = path.relpath('/' .. strInputPath, '/' .. strInputPrefix)
    end
    strOutputPath = path.join(strOutputFolder, strInputLocal .. tSettings.config_ext)
    local strOutputDir = path.dirname(strOutputPath)
    local dir = require 'pl.dir'
    dir.makepath(strOutputDir)
  else
    -- Place the compiled object in the same folder as the source.
    strOutputPath = strInputPath .. tSettings.config_ext
  end

  return strOutputPath
end



function tBuilder.DriverGCC_Link(label, output, inputs, settings)
  -- Remove the first file with an "ld" extension from the inputs and use it as the linker description file.
  local strLdFileArg
  local astrInputWithoutLd = {}
  for _, strInput in ipairs(inputs) do
    if PathFileExt(strInput)=='ld' and strLdFileArg==nil then
      strLdFileArg = '-T ' .. strInput .. ' '
    else
      table.insert(astrInputWithoutLd, strInput)
    end
  end
  strLdFileArg = strLdFileArg or ''

  -- Create the path for the map file.
  -- This is the output path with a "map" extension.
  local strMapFile = PathBase(output) .. '.map '

  AddJob(
    output,
    label,
    settings.link.exe .. " -o " .. output ..
    " " .. settings.link.inputflags .. " " .. TableToString(astrInputWithoutLd, '', ' ') ..
    TableToString(settings.link.extrafiles, '', ' ') ..
    TableToString(settings.link.libpath, '-L', ' ') ..
    TableToString(settings.link.libs, '-l', ' ') ..
    strLdFileArg ..
    '-Wl,-Map,' .. strMapFile .. ' ' ..
    TableToString(settings.link.frameworkpath, '-F', ' ') ..
    TableToString(settings.link.frameworks, '-framework ', ' ') ..
    settings.link.flags:ToString()
  )
end



function tBuilder:applyToEnv(tEnv, tCfg)
  tEnv.cc.Output = self.translateFilename

  tEnv.link.Driver = self.DriverGCC_Link

  function tEnv:SetBuildPath(strOutputFolder, strInputPrefix)
    self.mbs.TRANSLATE_FILENAME_OUTPUT_FOLDER = strOutputFolder
    self.mbs.TRANSLATE_FILENAME_INPUT_PREFIX = strInputPrefix
  end

  function tEnv:Compile(...)
    return Compile(self, ...)
  end

  function tEnv:Link(strTargetPath, ...)
    local tOutput = Link(self, strTargetPath, ...)

    local strMapFile = PathBase(strTargetPath) .. '.map '
    -- FIXME: This does not work, the map file is still there after a "clean".
    AddClean(tOutput, strMapFile)
  --  AddSideEffect(tOutput, strMapFile)

    return tOutput
  end

  function tEnv:StaticLibrary(strTargetPath, ...)
    return StaticLibrary(self, strTargetPath, ...)
  end

  local tMbs = tEnv.mbs
  tMbs.TRANSLATE_FILENAME_OUTPUT_FOLDER = ''
  tMbs.TRANSLATE_FILENAME_INPUT_PREFIX = ''

  return true
end


return tBuilder
