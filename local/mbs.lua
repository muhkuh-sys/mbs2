-----------------------------------------------------------------------------
--
-- Global declaration of variables
--

-- Provide Penlight as an upvalue to all functions.
local pl = require'pl.import_into'()

-- Add additonal package paths to the LUA search path -> Neccessary to add mbs2 paths to LUA search path
local tImport_mbs = require "import_mbs"()

-- a proxy table of the mbs2 folder to load chunk of lua modules
local mbs2 = tImport_mbs.tProxy

--- Init lpeg
local lpeg = require "lpeglabel"

-- Init lpeg_support
local tLpeg_Support =  require "lpeg_support"()

-- Save typing:
local P, V, Cg, Ct, Cc, S, R, C, Cf, Cb, Cs, match,
OptionalSpace,Space,Comma =
lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.S, lpeg.R, lpeg.C, lpeg.Cf, lpeg.Cb, lpeg.Cs, lpeg.match,
tLpeg_Support.OptionalSpace,tLpeg_Support.Space,tLpeg_Support.Comma


-----------------------------------------------------------------------------
--
-- Local helper functions.
--

--- Unlock a table which has been locked with TableLock.
-- This removes the method "__newindex" from the metatable.
-- The method will not be stored, so it will be lost after a call to this function.
-- @param tbl The table to unlock.
-- @see TableLock
local function TableUnlock(tbl)
  -- Get the metatable for tbl.
  local mt = getmetatable(tbl)
  if mt then
    -- A metatable exists. Remove the "__newindex" method.
    mt.__newindex = nil
    -- Update the metatable.
    setmetatable(tbl, mt)
  end
end


-------------------------------------------------------------------------------------------------
--
-- Global helper functions.
--

--- Calls ab sub BAM module
-- @param strPath path of the sub BAM module
-- @param ... input parameter of the sub bam module
function SubBAM(strPath,...)

  -- Read the specified file.
  local strSubScript, strError =  pl.utils.readfile(strPath, false)
  if strSubScript == nil then
    local strMsg = string.format('ERROR: SubBAM failed to read script "%s": %s', strPath, strError)
    error(strMsg)
  end

  -- Get the current directory.
  local strOldWorkingDirectory = pl.path.currentdir()
  local strSubFolder = pl.path.abspath(pl.path.dirname(strPath))

  -- Change into the subfolder.
  pl.path.chdir(strSubFolder)

  -- Run the script.
  local tChunk, strError = pl.compat.load(strSubScript, strPath, 't')
  if tChunk == nil then
    local strMsg = string.format('ERROR: SubBAM failed to parse script "%s": %s', strPath, strError)
    error(strMsg)
  end

  local bStatus, SubBAM = pcall(tChunk)
  if bStatus ~= true then
    local strMsg = string.format('ERROR: Failed to call the script "%s": %s', strSubScript, SubBAM)
    error(strMsg)
  end

  -- initialize subBAM object by using of penlight class
  local tSubBAM = SubBAM(...)

  -- calls run if available
  if SubBAM["run"] ~= nil then
    -- execution of available object function "run" -- return value should be true (without error)
    bStatus = tSubBAM:run()
    if bStatus == nil then
      local strMsg = string.format('ERROR: Failed to execute object function "run" of the script "%s"',strSubScript)
      error(strMsg)
    end
  end

  -- Restore the old working folder.
  pl.path.chdir(strOldWorkingDirectory)

  return tSubBAM
end


-------------------------------------------------------------------------------------------------
--
-- Local extension function of BAM
--

--- Extend the lib driver
local function DriverGCC_Lib(output, inputs, settings)
  local strCmd = table.concat{
    -- output archive must be removed because ar will update existing archives, possibly leaving stray objects
    'rm -f ', output, ' 2> /dev/null; ',
    settings.lib.exe, ' rcD ', output, ' ', TableToString(inputs, '', ' '), settings.lib.flags:ToString()
  }
  return strCmd
end


-- Extend the link driver
local function DriverGCC_Link(label, output, inputs, settings)
  -- Prepare the optional LD file option.
  local strLdOption = ''
  local strLdFile = settings.link.ldfile
  if strLdFile~='' then
    strLdOption = '-T ' .. strLdFile .. ' '
  end

  -- Prepare the optional map file option.
  local strMapOption
  local strMapFile = settings.link.mapfile
  if strMapFile=='' then
    strMapFile = output .. '.map'
  end
  strMapOption = '-Map ' .. strMapFile .. ' '

  -- Prepare the linker log file.
  local strLogFile = settings.link.logfile
  if strLogFile=='' then
    strLogFile = output .. '.log'
  end

  -- Construct the command for the linker.
  local strCmd = table.concat{
    settings.link.exe,
    ' --verbose',
    ' -o ', output, ' ',
    settings.link.inputflags, ' ',
    TableToString(inputs, '', ' '),
    TableToString(settings.link.extrafiles, '', ' '),
    TableToString(settings.link.libpath, '-L', ' '),
    TableToString(settings.link.libs, '-l', ' '),
    TableToString(settings.link.frameworkpath, '-F', ' '),
    TableToString(settings.link.frameworks, '-framework ', ' '),
    strLdOption,
    strMapOption,
    settings.link.flags:ToString(),
    ' >' .. strLogFile
  }
  AddJob(output, label, strCmd)
  AddClean(output, strMapFile)
  AddClean(output, strLogFile)
end


-------------------------------------------------------------------------------------------------
--
-- Create the default environment.
--

-- Create the BAM default environment class.
local class = pl.class
local atBUILDER_MODULES = {}
local EnvDefault = class(nil,nil,atBUILDER_MODULES)


---
function EnvDefault:_init()

  -- create default settings of BAM
  self.tEnvDefaultSettings = NewSettings()

  -- tools path
  self.strToolsPath = 'mbs2/tools'

  -- builder path
  self.strBuilderPath = 'mbs2/builder'

  -- Add a table for general key/value pairs. They can be set during the build process to add extra information.
  self.atVars = {}

  -- Add default settings:
  local tDefaultSettings =
  {
    READELF = "readelf", -- default readelf cmd for elf support
    OBJDUMP = "objdump",  -- default objdump cmd for elf support
    INTERPRETER_HBOOT = "python2.7",
    PATH_HBOOT = "mbs2/hboot_image_compiler/hboot_image_compiler"
  }

  self.atVars["DefaultSettings"] = tDefaultSettings

  -- Add a lookup table for the compiler. It maps the compiler ID to a setup function.
  self.atRegisteredCompiler = {}

  -- Extend the linker settings with an entry for the LD and a map file.
  TableUnlock(self.tEnvDefaultSettings.link)
  self.tEnvDefaultSettings.link.ldfile = ''
  self.tEnvDefaultSettings.link.mapfile = ''
  self.tEnvDefaultSettings.link.logfile = ''
  self.tEnvDefaultSettings.link.extension = ''
  TableLock(self.tEnvDefaultSettings.link)

  -- Extend the lib driver
  self.tEnvDefaultSettings.lib.Driver = DriverGCC_Lib

  -- Extend the link driver
  self.tEnvDefaultSettings.link.Driver = DriverGCC_Link

  -- Add some builder.
  self:AddBuilder(self.strBuilderPath)
end


--- Add builder modules.
-- "EnvDefault_" : builder scripts to add object functions/variables to EnvDefault
-- "Builder_": builder scripts to execute AddJob by BAM
function EnvDefault:AddBuilder(strMbsBuilderPath)

  -- Pattern of builder modules
  local Module_Name = Ct((P"EnvDefault_" + P"Builder_") * Cg((P(1) - -1)^1,"name"))
  local Module_Builder = P"Builder_" * (P(1) - -1)^1
  local Module_EnvDefault = P"EnvDefault_" * (P(1) - -1)^1

  -- Read all tools in the builder folder.
  local astrToolLuaPaths = pl.dir.getfiles(strMbsBuilderPath, '*.lua')
  local atKnownBuilder = {}
  for _, strBuilderPath in ipairs(astrToolLuaPaths) do
    local strBuilderId = pl.path.splitext(pl.path.basename(strBuilderPath))

    -- match the specify module name
    local tmatch_Module_Name = Module_Name:match(strBuilderId)
    if tmatch_Module_Name ~= nil then

      -- create an builder entry
      if atKnownBuilder[tmatch_Module_Name.name] == nil then
        atKnownBuilder[tmatch_Module_Name.name] = {}
      end

      -- match "EnvDefault_" builder script
      if Module_EnvDefault:match(strBuilderId) then
        -- create "EnvDefault" builder entry with abspath and basename
        atKnownBuilder[tmatch_Module_Name.name].EnvDefault =
        {
          AbsPath = pl.path.abspath(strBuilderPath),
          Basename = strBuilderId
        }

      -- match "Builder_" builder script
      elseif Module_Builder:match(strBuilderId) then
        -- create "Builder" builder entry with abspath and basename
        atKnownBuilder[tmatch_Module_Name.name].Builder =
        {
          AbsPath = pl.path.abspath(strBuilderPath),
          -- Basename = strBuilderId
        }
      end
    else
      local strMsg = string.format('ERROR: Failed to match the module name of "%s".',strBuilderId)
      error(strMsg)
    end
  end

  -- Add all object functions/Variables to EnvDefault of all builder modules by calling of all "EnvDefault_" modules in the builder folder
  -- and set the path of the "Builder_" module
  for strBuilderName,tBuilderModule in pairs(atKnownBuilder) do

    if tBuilderModule.EnvDefault == nil then
      local strMsg = string.format('ERROR: There is no "EnvDefault_" builder module available of "%s"',strBuilderName)
      error(strMsg)
    end

    -- it is possible that there is no "Builder_" script for each "EnvDefault_" builder script
    local strBuilder_AbsPath = (tBuilderModule.Builder == nil) and "" or tBuilderModule.Builder.AbsPath

    -- either use require to load the Builder (if the package.path is available) or use load
    local fRequire = function()
      return require(tBuilderModule.EnvDefault.Basename)
    end

    local tObjBuilder
    local bStatus, Builder

    bStatus, Builder = pcall(fRequire)
    if bStatus ~= true then
      -- Fail to load module by using of require -> try to load the chunk

      -- Try to load the builder script.
      local strBuilderScript, strError = pl.utils.readfile(tBuilderModule.EnvDefault.AbsPath, false)
      if strBuilderScript == nil then
        local strMsg = string.format('ERROR: Failed to read script "%s": %s', tBuilderModule.EnvDefault.AbsPath, strError)
        error(strMsg)
      end

      -- Run the script.
      local tChunk, strError = pl.compat.load(strBuilderScript, tBuilderModule.EnvDefault.AbsPath, 't')
      if tChunk == nil then
        local strMsg = string.format('ERROR: Failed to parse script "%s": %s', tBuilderModule.EnvDefault.AbsPath, strError)
        error(strMsg)
      end

      bStatus, Builder = pcall(tChunk)
      if bStatus ~= true then
        local strMsg = string.format('ERROR: Failed to call the script "%s": %s', tBuilderModule.EnvDefault.AbsPath, Builder)
        error(strMsg)
      end
    end

    if Builder == nil and type(Builder) ~= "table" then
      local strMsg = string.format('ERROR: There is no "Builder" object available in the builder module "%s" ',tBuilderModule.EnvDefault.AbsPath)
      error(strMsg)
    end

    -- Create a builder instance
    tObjBuilder = Builder(strBuilder_AbsPath)

    if tObjBuilder == nil and type(tObjBuilder) ~= "table" then
      local strMsg = string.format('ERROR: Failed to create an instance of the "Builder" object of "%s" ',tBuilderModule.EnvDefault.AbsPath)
      error(strMsg)
    end

    if tObjBuilder.EnvDefault == nil and type(tObjBuilder.EnvDefault) ~= "table" then
      local strMsg = string.format('ERROR: There is no object variable "EnvDefault" availabe of "%s" ',tBuilderModule.EnvDefault.AbsPath)
      error(strMsg)
    end

    -- Update the table of builder modules by inserting the obeject table variable tObjBuilder.EnvDefault to the object EnvDefault
    pl.tablex.update(atBUILDER_MODULES,tObjBuilder.EnvDefault)
  end
end


--- Update a set of key-value pairs with another set.
--  tTarget: table with key-value pairs which should be updated
--  tInput: table with key-value pairs. Non-string keys will be skipped.
--          value is converted to a string. Tables will be flattened and concatted.
function EnvDefault.__updateAsStrings(tTarget, tInput)
  for strKey, tValue in pairs(tInput) do
    -- Silently skip non-string keys.
    if type(strKey)=='string' then
      local strType = type(tValue)
      if strType=='table' then
        tValue = table.concat(TableFlatten(tValue), ' ')
      else
        tValue = tostring(tValue)
      end
      tTarget[strKey] = tValue
    end
  end
end


---
function EnvDefault:__easyCommand(tEnv, tTarget, tInput, strToolName, atOverrides)
  -- Get the absolute path to the target,
  local strTargetAbs = pl.path.abspath(tTarget)
  -- Flatten the inputs.
  local astrInput
  if type(tInput)=='table' then
    astrInput = TableFlatten(tInput)
  else
    astrInput = {tInput}
  end

  -- Create a list with all replacement variables.
  local atReplace = {}
  -- Start with all variables from the environment.
  self.__updateAsStrings(atReplace, tEnv.atVars)
  -- Add all elements from the optional parameters.
  self.__updateAsStrings(atReplace, atOverrides)
  -- Set the target and sources.
  atReplace.TARGET = strTargetAbs
  atReplace.SOURCES = table.concat(astrInput, ' ')

  -- Replace the command.
  local strCmdVar = strToolName .. '_CMD'
  local strCmdTemplate = tEnv.atVars[strCmdVar]
  if strCmdTemplate==nil then
    local strMsg = string.format('ERROR: Failed to run tool "%s": no "%s" setting found.', strToolName, strCmdVar)
    error(strMsg)
  end
  local strCmd = string.gsub(strCmdTemplate, '%$([%a_][%w_]+)', atReplace)

  -- Replace the label.
  local strLabelVar = strToolName .. '_LABEL'
  local strLabelTemplate = tEnv.atVars[strLabelVar]
  local strLabel
  if strLabelTemplate==nil then
    strLabel = strCmd
  else
    strLabel = string.gsub(strLabelTemplate, '%$([%a_][%w_]+)', atReplace)
  end

  AddJob(strTargetAbs, strLabel, strCmd, astrInput)

  return strTargetAbs
end


--- Object dump function
function EnvDefault:ObjDump(tTarget, tInput, ...)
  return self:__easyCommand(self, tTarget, tInput, 'OBJDUMP', {...})
end


--- Object copy function
function EnvDefault:ObjCopy(tTarget, tInput, ...)
  return self:__easyCommand(self, tTarget, tInput, 'OBJCOPY', {...})
end


--- Add a method to clone the environment.
function EnvDefault:Clone()
  return pl.tablex.deepcopy(self)
end


---
function EnvDefault:CreateEnvironment(astrTools)
  local tEnv = self:Clone()

  -- Read all tools in the mbs2/tools folder.
  local astrToolLuaPaths = pl.dir.getfiles(self.strToolsPath, '*.lua')
  local atKnownTools = {}
  for _, strToolPath in ipairs(astrToolLuaPaths) do
    local strToolId = pl.path.splitext(pl.path.basename(strToolPath))
    atKnownTools[strToolId] = pl.path.abspath(strToolPath)
  end

  -- Search all tools in the list.
  for _, strRawTool in ipairs(astrTools) do
    local strTool = string.gsub(strRawTool, '(%W)', '_')

    -- Try an exact match first.
    local strToolFullName
    local strPath = atKnownTools[strTool]
    if strPath ~= nil then
      strToolFullName = strTool
    else
      -- Look for an entry starting with the requested name.
      for strToolName, strToolPath in pairs(atKnownTools) do
        if strTool == string.sub(strToolName, 1, string.len(strTool)) then
          strPath = strToolPath
          strToolFullName = strToolName
          break
        end
      end
    end

    if strPath == nil then
      local strMsg = string.format('ERROR: Tool "%s" not found. These tools are available: %s', strTool, table.concat(pl.tablex.keys(atKnownTools), ', '))
      error(strMsg)
    end

    -- either use require to load the compiler setup (if the package.path is available) or use load
    local fRequire = function()
      return require(strToolFullName)
    end

    local bStatus, Setup_Compiler = pcall(fRequire)
    if bStatus ~= true then
      -- Fail to load module by using of require -> try to load the chunk

      -- Try to load the tool script.
      local strToolScript, strError = pl.utils.readfile(strPath, false)
      if strToolScript == nil then
        local strMsg = string.format('ERROR: Failed to read script "%s": %s', strPath, strError)
        error(strMsg)
      end

      -- Run the script.
      local tChunk, strError = pl.compat.load(strToolScript, strPath, 't')
      if tChunk == nil then
        local strMsg = string.format('ERROR: Failed to parse script "%s": %s', strPath, strError)
        error(strMsg)
      end
      -- Unlock the table as some tools add functions
      --    TableUnlock(tEnv)

      bStatus, Setup_Compiler = pcall(tChunk)
      if bStatus ~= true then
        local strMsg = string.format('ERROR: Failed to call the script "%s": %s', strPath, Setup_Compiler)
        error(strMsg)
      end

      -- TableLock(tEnv)
    end

    if Setup_Compiler == nil and type(Setup_Compiler) ~= "table" then
      local strMsg = string.format('ERROR: There is no "Setup_Compiler" object available of the script "%s"', strPath)
      error(strMsg)
    end

    -- create an instance of the compiler setup
    Setup_Compiler(tEnv)
  end

  return tEnv
end


---
function EnvDefault:AddCompiler(strCompilerID, strAsicTyp)
  -- By default the ASIC typ is the compiler ID.
  strAsicTyp = strAsicTyp or strCompilerID

  -- Search the compiler ID in the registered compilers.
  local fnSetup = self.atRegisteredCompiler[strCompilerID]
  if fnSetup==nil then
    local strMsg = string.format('ERROR: Failed to add compiler with ID "%s": not found in registered compilers', tostring(strCompilerID))
    error(strMsg)
  end

  -- Apply the compiler settings by calling the setup function.
  TableUnlock(self.tEnvDefaultSettings)
  fnSetup(self)
  TableLock(self.tEnvDefaultSettings)

  -- Set the ASIC Type define.
  self.tEnvDefaultSettings.cc.defines:Add(
    string.format('ASIC_TYP=ASIC_TYP_%s', strAsicTyp)
  )

  -- Add the compiler ID and ASIC type to the vars.
  self.atVars['COMPILER_ID'] = strCompilerID
  self.atVars['ASIC_TYP'] = strAsicTyp

  return self
end


--- Set build path for a settings object.
-- All source files must be in strSourcePath or below.
-- The folder structure starting at strSourcePath will be duplicated at strOutputPath.
function EnvDefault:SetBuildPath(strSourcePath, strOutputPath)
  local strSourcePathAbs = pl.path.abspath(strSourcePath)
  local strOutputPathAbs = pl.path.abspath(strOutputPath)

  -- NOTE: This function uses the upvalues strSourcePathAbs and strOutputPathAbs.
  self.tEnvDefaultSettings.cc.Output = function(settings, strInput)
    -- Get the absolute path for the input file.
    local strAbsInput = pl.path.abspath(strInput)

    -- Get the relative path of the input element to the source path.
    local strRelPath = pl.path.relpath(strAbsInput, strSourcePathAbs)

    -- Append the output path.
    local strTargetPath = pl.path.join(strOutputPathAbs, strRelPath)

    -- Get the directory component of the target path.
    local strTargetFolder = pl.path.dirname(strTargetPath)

    if pl.path.exists(strTargetFolder)~=strTargetFolder then
      -- Create the path.
      pl.dir.makepath(strTargetFolder)
    end

    return strTargetPath
  end
end


---
function EnvDefault:AddInclude(...)
  local tIn = TableFlatten{...}
  for _, tSrc in ipairs(tIn) do
    self.tEnvDefaultSettings.cc.includes:Add(pl.path.abspath(tSrc))
  end
end


---
function EnvDefault:AddCCFlags(...)
  self.tEnvDefaultSettings.cc.flags:Merge( TableFlatten{...} )
end


---
function EnvDefault:AddDefines(...)
  local tIn = TableFlatten{...}
  for _, tSrc in ipairs(tIn) do
    self.tEnvDefaultSettings.cc.defines:Add(tSrc)
  end
end


---
function EnvDefault:Compile(...)
  local tIn = TableFlatten{...}
  local atSrc = {}
  for _, tSrc in ipairs(tIn) do
    table.insert(atSrc, pl.path.abspath(tSrc))
  end
  return Compile(self.tEnvDefaultSettings, atSrc)
end


---
function EnvDefault:StaticLibrary(tTarget, ...)
  local tIn = TableFlatten{...}
  local atSrc = {}
  for _, tSrc in ipairs(tIn) do
    table.insert(atSrc, pl.path.abspath(tSrc))
  end
  return StaticLibrary(self.tEnvDefaultSettings, pl.path.abspath(tTarget), atSrc)
end


---------------------------------------------------------------------------------------------------------------------
--
-- Linker extensions.
--

-- Set the extension of the linker
function EnvDefault:SetLinkExtension(strExtension)
  -- default value
  strExtension = strExtension or ""

  if type(strExtension) ~= "string" then
    local strMsg = string.format("ERROR: The strExtension must be a string.")
    error(strMsg)
  end
  self.tEnvDefaultSettings.link.extension = strExtension
end


-- This is the method for the environment. Users will call this in the "bam.lua" files.
function EnvDefault:Link(tTarget, strLdFile, ...)
  -- Add a new custom entry to the "link" table.
  self.tEnvDefaultSettings.link.ldfile = pl.path.abspath(strLdFile)
  -- Get all input files in a flat table.
  local tIn = TableFlatten{...}
  -- Make the path for all input files absolute.
  local atSrc = {}
  for _, tSrc in ipairs(tIn) do
    table.insert(atSrc, pl.path.abspath(tSrc))
  end
  -- Link the input files to the target.
  return Link(self.tEnvDefaultSettings, pl.path.abspath(tTarget), atSrc)
end


---------------------------------------------------------------------------------------------------------------------
--
-- Lib extensions.
--

-- Set the extension of the linker
function EnvDefault:SetLibPrefix(strPrefix)
  -- default value
  strPrefix = strPrefix or ""

  if type(strPrefix) ~= "string"  then
    local strMsg = string.format("ERROR: The strPrefix must be a string.")
    error(strMsg)
  end
  self.tEnvDefaultSettings.lib.prefix = strPrefix
end


return EnvDefault
