local cMbs = {}

----------------------------------------------------------------------------------------------------------------------
--
-- Collect all registered tools.
-- FIXME: For now tools are a collection of files in this "mbs2" repository which have a fixed path to the
--        installation folder somewhere else. This is quite different from the old "mbs" system where tools were
--        installed automatically.
--
local astrRegisteredTools = {
  'arm-none-eabi-10_3-2021_10'
}
local path = require 'pl.path'
local atRegisteredools = {}
for _, strTool in ipairs(astrRegisteredTools) do
  local strModulePath = path.join('mbs2', 'tools', strTool)
  local fReqireResult, tTool = pcall(require, strModulePath)
  if fReqireResult~=true then
    error('Failed to load the tool "' .. strTool .. '": ' .. tostring(tTool))
  else
    table.insert(atRegisteredools, tTool)
  end
end
cMbs.tools = atRegisteredools

----------------------------------------------------------------------------------------------------------------------
--
-- Collect all standard builders.
--
local astrStandardBuilders = {
  'Bin2Obj',
  'gcc',
  'hboot_image',
  'Elf2Bin'
}
local atStandardBuilders = {}
for _, strBuilder in ipairs(astrStandardBuilders) do
  local strModulePath = path.join('mbs2', 'builder', strBuilder)
  local fReqireResult, tBuilder = pcall(require, strModulePath)
  if fReqireResult~=true then
    error('Failed to load the builder "' .. strBuilder .. '": ' .. tostring(tBuilder))
  else
    table.insert(atStandardBuilders, tBuilder)
  end
end
cMbs.builder = atStandardBuilders


--- Lookup a tool by the ID and a prefix for the version.
---@private
---@param strID string
---@param strVersion string
---@return table, nil|string # Return the first matching tool on success. Otherwise return nil and an error message.
function cMbs:__getTool(strID, strVersion)
  local tMatchingTool
  local strError
  for _, tTool in ipairs(self.tools) do
    local strItemID = tTool.id
    local strItemVersion = tTool.version
    if(
      type(strItemID)=='string' and
      type(strItemVersion)=='string' and
      strItemID==strID and
      string.find(strItemVersion, strVersion, 1, true)==1
    ) then
      tMatchingTool = tTool
      break
    end
  end
  if tMatchingTool==nil then
    strError = 'No matching tool found for ID "' .. strID .. '" and version ' .. strVersion
  end
  return tMatchingTool, strError
end



function cMbs:createEnv(strID, atRequiredTools, tCfg)
  -- Does an environment whith this ID already exist?
  if self.atEnv[strID]~=nil then
    error('An environment with the ID "' .. strID .. '" already exists.')
  end

  -- Create a new environment.
  local tEnv = NewSettings()
  local strError

  -- Set the label for all output lines, if there is something in the configuration.
  local strLabel = tCfg.label
  if type(strLabel)=='string' then
    tEnv.labelprefix = '[' .. strLabel .. '] '
  end

  -- Unlock the settings table to add the "mbs" object and all tools and builders.
  require 'mbs2/table_unlock'.TableUnlock(tEnv)

  -- Set the ID.
  tEnv.mbs_id = strID

  -- Add the "mbs" table as a key-value store which can be used in builders.
  -- Populate it with a st of known values from the configuration, like the asic typ.
  tEnv.mbs = {
    ASIC_TYP = tCfg.asic_typ
  }

  -- Aply all required tools.
  if type(atRequiredTools)=='table' then
    for _, tRequiredTool in ipairs(atRequiredTools) do
      local strToolID = tRequiredTool.id
      local strToolVersion = tRequiredTool.version
      if type(strToolID)=='string' and type(strToolVersion)=='string' then
        local tTool, strToolError = self:__getTool(strToolID, strToolVersion)
        if tTool==nil then
          tEnv = nil
          strError = string.format(
            'Failed to lookup the tool with ID "%s" and version %s : %s',
            strToolID,
            strToolVersion,
            tostring(strToolError)
          )
          break
        else
          local fApplyResult, strApplyError = tTool:applyToEnv(tEnv, tCfg)
          if fApplyResult~=true then
            tEnv = nil
            strError = string.format(
              'Failed to apply the tool with ID "%s" and version %s to the environment: %s',
              strToolID,
              strToolVersion,
              tostring(strApplyError)
            )
            break
          end
        end
      end
    end

    if tEnv~=nil then
      -- Apply all standard builders to the environment.
      for _, tBuilder in ipairs(self.builder) do
        local fApplyResult, strApplyError = tBuilder:applyToEnv(tEnv, tCfg)
        if fApplyResult~=true then
          tEnv = nil
          strError = string.format(
            'Failed to apply the builder with ID "%s" and version %s to the environment: %s',
            tostring(tBuilder.id),
            tostring(tBuilder.version),
            tostring(strApplyError)
          )
          break
        end
      end
    end
  end

  if tEnv==nil then
    error(strError)
  else
    TableLock(tEnv)

    -- Register the new environment.
    self.atEnv[strID] = tEnv
  end
end



function cMbs:hasEnv(strID)
  local tEnv = self.atEnv[strID]
  return (tEnv~=nil)
end



function cMbs:cloneEnv(strID, tCfg)
  local tEnvMaster = self.atEnv[strID]
  if tEnvMaster==nil then
    error('An environment with the ID "' .. strID .. '" was not found.')
  end

  local tEnv = tEnvMaster:Copy()

  -- Set the label for all output lines, if there is something in the configuration.
  local strLabel = tCfg.label
  if type(strLabel)=='string' then
    tEnv.labelprefix = '[' .. strLabel .. '] '
  end

  return tEnv
end



function cMbs:mergeEnv(tID, atKeyValuePairs)
  local strID
  if type(tID)=='string' then
    strID = tID
  elseif type(tID)=='table' and type(tID.mbs_id)=='string' then
    strID = tID.mbs_id
  else
    error('First argument must be a string or an environment object.')
  end

  local tEnv = self.atEnv[strID]
  if tEnv==nil then
    error('An environment with the ID "' .. strID .. '" was not found.')
  end

  local tMbs = tEnv.mbs
  for strKey, tValue in pairs(atKeyValuePairs) do
    tMbs[strKey] = tValue
  end

  return tEnv
end



function cMbs:cloneAnyEnv(tCfg)
  -- To get a reproducable behaviour, sort the available keys and take the first one.
  local astrKeys = {}
  for strKey in pairs(self.atEnv) do
    table.insert(astrKeys, strKey)
  end
  table.sort(astrKeys)
  if #astrKeys==0 then
    error('No environments found.')
  end
  local tEnvMaster = self.atEnv[astrKeys[1]]

  local tEnv = tEnvMaster:Copy()

  -- Set the label for all output lines, if there is something in the configuration.
  local strLabel = tCfg.label
  if type(strLabel)=='string' then
    tEnv.labelprefix = '[' .. strLabel .. '] '
  end

  return tEnv
end


return cMbs
