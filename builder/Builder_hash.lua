-------------------------------------------------------------------------------------------------------------------
--
-- Builder
-- A BAM builder which replaces a set of fields by using of ELF file.
--

-- Create the hash class.
local class = require 'pl.class'
local Hash = class()


---
function Hash:_init()
  local rapidjson = require 'rapidjson'
  local pl = require'pl.import_into'()
  self.pl = pl

  -- Add additonal package paths to the LUA search path -> Neccessary to add mbs2 paths to LUA search path
  self.tImport_mbs = require "import_mbs"()

  -- a proxy table of the mbs2 folder to load chunk of lua modules
  self.mbs2 = self.tImport_mbs.tProxy

  self.tLpeg_Support =  require "lpeg_support"()

  -- input argument by BAM calling this module
  local strParameter = _bam_targets[0]

  local tParameter, strParameterError = rapidjson.decode(strParameter)
  if tParameter == nil then
    local strMsg = string.format('ERROR: Failed to decode the input parameter "%s": %s', strParameter, strParameterError)
    error(strMsg)
  end

  self.strSource,self.strTarget,self.tHash_ID,self.strHash_template =
    tParameter.strSource,
    tParameter.strTarget,
    tParameter.tHash_ID,
    tParameter.strHash_template

  -- load the mhash plugin for the hash algorithms.
  self.mhash = require 'mhash'

  -- reading chunk size
  self.chunk_size = 4096

  -- all available hash algorithms
  self.atMhashHashes = {
    ['MD5']    = self.mhash.MHASH_MD5,
    ['SHA1']   = self.mhash.MHASH_SHA1,
    ['SHA224'] = self.mhash.MHASH_SHA224,
    ['SHA256'] = self.mhash.MHASH_SHA256,
    ['SHA384'] = self.mhash.MHASH_SHA384,
    ['SHA512'] = self.mhash.MHASH_SHA512
  }

  -- check, whether all hash algorithm IDs in the parameter tHash_ID are available.
  local atHashGenerateOrder = {}
  local tSetHash = pl.Set(pl.tablex.keys(self.atMhashHashes))
  for uiKey,strHash in ipairs(self.tHash_ID) do

    if type(strHash) ~= "string" then
      local strMsg = string.format('ERROR: The given hash algorithm ID "%s" is not a string.', strHash)
      error(strMsg)
    elseif tSetHash[string.upper(strHash)] ~= true then
      local strMsg = string.format('ERROR: The given hash algorithm ID "%s" is not available.', strHash)
      error(strMsg)
    else
      atHashGenerateOrder[uiKey] =
      {
        ID_UC = string.upper(strHash),
        ID    = strHash
      }
    end
  end

  self.atHashGenerateOrder = atHashGenerateOrder
end


--- Convert a string to a HEX dump.
-- Convert each char in the string to its HEX representation.
-- @param strBin The string with the data to dump.
-- @return A HEX dump of strBin.
function Hash:_bin_to_hex(strBin)
  local aHashHex = {}
  for iCnt=1,string.len(strBin) do
    table.insert(aHashHex, string.format("%02x", string.byte(strBin, iCnt)))
  end
  return table.concat(aHashHex)
end


---
function Hash:_get_hash_for_file(strPath, strHashName)
  local tResult = nil

  -- Create a new MHASH state.
  local tHashID = self.atMhashHashes[strHashName]
  local tState = self.mhash.mhash_state()
  tState:init(tHashID)

  -- Open the file and read it in chunks.
  local tFile, strError = io.open(strPath, 'rb')
  if tFile == nil then
    tResult = nil
    local strMsg = string.format('ERROR: Failed to open the file "%s" for reading: %s', strPath, strError)
    print(strMsg)
  else
    repeat
      local tChunk = tFile:read(self.chunk_size)
      if tChunk ~= nil then
        tState:hash(tChunk)
      end
    until tChunk == nil
    tFile:close()

    -- Get the binary hash.
    local strHashBin = tState:hash_end()

    -- Convert the binary hash into a string.
    tResult = self:_bin_to_hex(strHashBin)
  end

  return tResult
end


---
function Hash:generate_hashes_for_file(strPath)
  local atHashReplacements = {}
  local strRelPath = self.pl.path.relpath(strPath,self.pl.path.currentdir())

  -- Loop over all known hashes.
  for uiKey,tHashID in ipairs(self.atHashGenerateOrder) do
    local strHash = self:_get_hash_for_file(strPath, tHashID.ID_UC)
    if strHash == nil then
      local strMsg = string.format('ERROR: Failed to generate the hash value of "%s" with the algorithm "%s"',strPath,tHashID.ID_UC)
      error(strMsg)
    else
      atHashReplacements[uiKey] =
      {
        HASH  = strHash,
        PATH  = strRelPath,
        ID    = tHashID.ID,
        ID_UC = tHashID.ID_UC
      }
    end
  end

  return atHashReplacements
end


--- execute the hash calculation
function Hash:run()
  local tLpeg_Support = self.tLpeg_Support

  -- generate all hashes
  local atHashReplacements = self:generate_hashes_for_file(self.strSource)

  -- Replace all replacments in the template and add all hash values
  local strHashFile = ""
  for _,tHashReplacements in ipairs(atHashReplacements) do
    strHashFile = strHashFile .. tLpeg_Support:Gsub(self.strHash_template,nil,tHashReplacements)
  end

  -- Write the result.
  local tWriteResult, strWriteError = self.pl.utils.writefile(self.strTarget, strHashFile, true)
  if tWriteResult~=true then
    local strMsg = string.format('ERROR: Failed to write the output file "%s": %s', self.strTarget, strWriteError)
    error(strMsg)
  end
end

local tHash = Hash()
tHash:run()
