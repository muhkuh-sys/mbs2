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



function DriverGCC_Get(exe, cache_name, flags_name)
  return function(label, output, input, settings)
    local cache = settings.cc[cache_name]
    if settings.invoke_count ~= cache.nr then
      cache.nr = settings.invoke_count
      local cc = settings.cc
      local d = TableToString(cc.defines, "-D", " ")
      local i = TableToString(cc.includes, '-I "', '" ') ..
                TableToString(cc.systemincludes, '-isystem "', '" ') ..
                TableToString(cc.frameworks, '-framework ', ' ')
      local f = cc.flags:ToString()
      f = f .. cc[flags_name]:ToString()
      if settings.debug > 0 then
        f = f .. "-g "
      end
      if settings.optimize > 0 then
        f = f .. "-O2 "
      end

      cache.str = cc[exe] .. " " .. f .. "-c " .. d .. i .. " -o "
    end

    local strCompileCommandsFile
    local tMbs = settings.mbs
    if type(tMbs)=='table' then
      strCompileCommandsFile = tMbs.COMPILE_COMMANDS_FILE
      local atCompileCommands = tMbs.COMPILE_COMMANDS
      local strCompileCommandsCwd = tMbs.COMPILE_COMMANDS_CWD

      if(
        type(strCompileCommandsFile)=='string' and
        type(atCompileCommands)=='table' and
        type(strCompileCommandsCwd)=='string'
      ) then
        local cc = settings.cc
        local astrArgs = {
          cc[exe],
        }
        for _, strFlag in ipairs(cc.flags) do
          table.insert(astrArgs, strFlag)
        end
        for _, strFlag in ipairs(cc[flags_name]) do
          table.insert(astrArgs, strFlag)
        end
        if settings.debug > 0 then
          table.insert(astrArgs, '-g')
        end
        if settings.optimize > 0 then
          table.insert(astrArgs, '-O2')
        end
        table.insert(astrArgs, '-c')
        for _, strDefine in ipairs(cc.defines) do
          table.insert(astrArgs, '-D' .. strDefine)
        end
        for _, strInclude in ipairs(cc.includes) do
          table.insert(astrArgs, '-I' .. strInclude)
        end
        for _, strInclude in ipairs(cc.systemincludes) do
          table.insert(astrArgs, '-isystem')
          table.insert(astrArgs, '"' .. strInclude .. '"')
        end
        for _, strFramework in ipairs(cc.frameworks) do
          table.insert(astrArgs, '-framework')
          table.insert(astrArgs, strFramework)
        end
        table.insert(astrArgs, '-o')
        table.insert(astrArgs, output)
        table.insert(astrArgs, input)

        table.insert(
          atCompileCommands,
          {
            directory = strCompileCommandsCwd,
            arguments = astrArgs,
            file = input
          }
        )

        -- FIXME: This writes the compile commands file again and again for each file to be compiled.
        --        A better solution is a special target for the compile_commands.json file which depends
        --        on all source files.
        local tFile = io.open(strCompileCommandsFile, 'w')
        if tFile~=nil then
          tFile:write(require 'rapidjson'.encode(atCompileCommands))
          tFile:close()
        end
      end
    end

    AddJob(output, label, cache.str .. output .. " " .. input)
--    if type(strCompileCommandsFile)=='string' then
--      AddDependency(output, strCompileCommandsFile)
--    end
  end
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
  tEnv.cc.DriverC = DriverGCC_Get('exe_c', '_c_cache', 'flags_c')
  tEnv.cc.DriverCXX = DriverGCC_Get('exe_cxx', '_cxx_cache', 'flags_cxx')
  tEnv.cc.Output = self.translateFilename

  tEnv.link.Driver = self.DriverGCC_Link

  function tEnv:CompileCommands(strTargetPath)
    local tMbs = self.mbs
    tMbs.COMPILE_COMMANDS_FILE = strTargetPath
    tMbs.COMPILE_COMMANDS_CWD = require 'pl.path'.currentdir()
    tMbs.COMPILE_COMMANDS = {}

    local strLabel = tEnv.labelprefix .. 'CompileCommands ' .. strTargetPath
--    AddJob(strTargetPath, strLabel, cache.str .. output .. " " .. input)
  end

  function tEnv:SetBuildPath(strOutputFolder, strInputPrefix)
    self.mbs.TRANSLATE_FILENAME_OUTPUT_FOLDER = strOutputFolder
    self.mbs.TRANSLATE_FILENAME_INPUT_PREFIX = strInputPrefix
  end

  function tEnv:AddIncludes(...)
    self.cc.includes:Merge(...)
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
  tMbs.COMPILE_COMMANDS_FILE = nil
  tMbs.COMPILE_COMMANDS_CWD = nil
  tMbs.COMPILE_COMMANDS = nil

  return true
end


return tBuilder
