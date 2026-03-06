local mhash = require 'mhash'

local tBuilder = {
  id = 'Hash',
  version = '1.0.0',

  knownHashes = {
    ['MD5'] = mhash.MHASH_MD5,
    ['SHA1'] = mhash.MHASH_SHA1,
    ['SHA224'] = mhash.MHASH_SHA224,
    ['SHA256'] = mhash.MHASH_SHA256,
    ['SHA384'] = mhash.MHASH_SHA384,
    ['SHA512'] = mhash.MHASH_SHA512
  }
}


--- Convert a string to a HEX dump.
--- Convert each char in the string to its HEX representation.
--- @param strBin string The string with the data to dump.
--- @return string # A HEX dump of strBin.
function tBuilder:__bin_to_hex(strBin)
  local aHashHex = {}
  for iCnt=1,string.len(strBin) do
    table.insert(aHashHex, string.format("%02x", string.byte(strBin, iCnt)))
  end
  return table.concat(aHashHex)
end



-- This method will be run in a new process.
function tBuilder:runBuildTask(tArguments)
  -- Collect the hashes in this table.
  local astrOutput = {}

  -- Get the has template.
  local strHashTemplate = tArguments.hashTemplate

  -- Translate the hash algorithms.
  local atKnownHashes = self.knownHashes

  -- Get the directory path of the target file. This is the working dir and
  -- all paths in the hash file must be relative to this.
  local path = require 'pl.path'
  local strOutputPath = tArguments.output
  local strWorkingDir = path.dirname(strOutputPath)
  local strSrcPath = tArguments.input
  local strSrcRelPath = path.relpath(strSrcPath, strWorkingDir)

  -- Create a new hash object with the requested algorithm.
  for _, strHash in ipairs(tArguments.hashAlgorithms) do
    local strHashUpper = string.upper(strHash)
    local tHash = atKnownHashes[strHashUpper]
    if tHash==nil then
      error('Unknown hash algorithm: ' .. tostring(strHash))
    else
      local tState = mhash.mhash_state()
      tState:init(tHash)

      -- Open the file and read it in chunks.
      local tFile, strError = io.open(strSrcPath, 'rb')
      if tFile==nil then
        error(string.format(
          'Failed to open the file "%s" for reading: %s',
          strSrcPath,
          strError
        ))
      else
        repeat
          local tChunk = tFile:read(16384)
          if tChunk~=nil then
            tState:hash(tChunk)
          end
        until tChunk==nil
        tFile:close()

        -- Get the binary hash.
        local strHashBin = tState:hash_end()

        -- Convert the binary hash into a string.
        local strHashHex = self:__bin_to_hex(strHashBin)

        local atSubstitute = {
          ID = strHash,
          ID_UC = strHashUpper,
          HASH = strHashHex,
          PATH = strSrcRelPath
        }
        local strData = string.gsub(strHashTemplate, '%${([A-Z_]+)}', atSubstitute)
        table.insert(astrOutput, strData)
      end
    end
  end

  local utils = require 'pl.utils'
  local fWrite, strWriteError = utils.writefile(strOutputPath, table.concat(astrOutput), false)
  if fWrite~=true then
    error(string.format(
      'Failed to write the hash sums to "%s": %s',
      strOutputPath,
      strWriteError
    ))
  end
end



function tBuilder:applyToEnv(tEnv, tCfg)
  local strBuilderId = self.id

  local atKnownHashesUpvalue = self.knownHashes
  function tEnv:Hash(strOutputPath, strInputPath, tParameter)
    tParameter = tParameter or {}

    -- Emulate the output of the sha384sum as a fallback.
    local stringx = require 'pl.stringx'
    local strHashAlgorithms = tParameter.HASH_ALGORITHM
    if type(strHashAlgorithms)~='string' then
      strHashAlgorithms = 'sha384'
    end
    local strHashTemplate = tParameter.HASH_TEMPLATE
    if type(strHashTemplate)~='string' then
      strHashTemplate = '${HASH} *${PATH}\n'
    end

    -- Validate the hash algorithms.
    local astrHashAlgorithmsRaw = stringx.split(strHashAlgorithms, ',')
    local astrHashAlgorithms = {}
    local astrUnknownHashes = {}
    for _, strHashRaw in ipairs(astrHashAlgorithmsRaw) do
      local strHash = stringx.strip(strHashRaw)
      local strHashUpper = string.upper(strHash)
      if atKnownHashesUpvalue[strHashUpper]==nil then
        table.insert(astrUnknownHashes, strHash)
      else
        table.insert(astrHashAlgorithms, strHash)
      end
    end
    if #astrUnknownHashes~=0 then
      error('Unknown hash algorithms requested: ' .. table.concat(astrUnknownHashes, ','))
    end

    local tJobParameter = {
      input = strInputPath,
      output = strOutputPath,
      hashAlgorithms = astrHashAlgorithms,
      hashTemplate = strHashTemplate
    }
    self:addLuaJob(strBuilderId, strBuilderId, strOutputPath, tJobParameter)
    AddDependency(strOutputPath, strInputPath)

    return strOutputPath
  end

  return true
end


return tBuilder
