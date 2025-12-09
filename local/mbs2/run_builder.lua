-- Get the id and arguments from the ScriptArgs.
local atScriptArgs = _G.ScriptArgs
local strID = atScriptArgs.id
local strArgumentsJson = atScriptArgs.args

-- Check the types for the "id" and "args" script arguments. Both must be strings.
if type(strID)~='string' then
  error('ERROR: The builder specified no ID. This is an internal error.')
end
if type(strArgumentsJson)~='string' then
  error(string.format(
    'ERROR: The builder "%s" specified no arguments. This is an internal error.',
    strID
  ))
end

-- Try to decode the arguments as JSON.
local rapidjson = require 'rapidjson'
local tArguments, strDecodeArgumentsError = rapidjson.decode(strArgumentsJson)
if tArguments==nil then
  error(string.format(
    'ERROR: Failed to decode the arguments for builder "%s": %s\nRaw arguments:\n%s',
    strID,
    strDecodeArgumentsError,
    strArgumentsJson
  ))
end

-- Try to load the builder module.
local strBuilderModule = 'mbs2.builder.' .. strID
local fResultPcall, tBuilderModule = pcall(require, strBuilderModule)
if fResultPcall~=true then
  error(string.format(
    'Failed to load the builder module from "%s": %s',
    strBuilderModule,
    tostring(tBuilderModule)
  ))
end

-- The builder module must be a table with the function "runBuildTask".
if type(tBuilderModule)~='table' then
  error(string.format(
    'The builder module "%s" is no table. This is an internal error.',
    strBuilderModule
  ))
end
if type(tBuilderModule.runBuildTask)~='function' then
  error(string.format(
    'The builder module "%s" has no "runBuildTask" method. This is an internal error.',
    strBuilderModule
  ))
end

-- Run the build method.
tBuilderModule:runBuildTask(tArguments)
