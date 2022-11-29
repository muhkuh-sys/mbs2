-------------------------------------------------------------------------------------------------------------------
--
-- Builder
-- A BAM builder which creates an archive.
--

-- Create the archive class.
local class = require 'pl.class'
local Archive = class()


---
function Archive:_init()
  self.archive = require 'archive'
  self.pl = require'pl.import_into'()

  local rapidjson = require 'rapidjson'

  -- input argument by BAM calling this module
  local strParameter = _bam_targets[0]

  local tParameter, strParameterError = rapidjson.decode(strParameter)
  if tParameter == nil then
    local strMsg = string.format('ERROR: Failed to decode the input parameter "%s": %s', strParameter, strParameterError)
    error(strMsg)
  end

  self.strArchivePath,self.uiFormat,self.tFilterNumb,self.tResolvedArchiveStructure =
    tParameter.strArchivePath,
    tParameter.uiFormat,
    tParameter.tFilterNumb,
    tParameter.tResolvedArchiveStructure

  -- set standard behavioue
  self.uiBehavior = 0

  -- Copy the data in chunks of 16k. Just in case we meet terabyte files here.
  self.uiChunkSize = 16384
end


--- create an archive.
-- see also jonchki function "pack_archive_archive" and repository "org.muhkuh.lua-archive" -> tests/test_create_archive_from_files.lua
function Archive:run()
  local pl = self.pl

  -- be optimistic
  local tArcResult = 0

  -- Create a read disk object.
  local tReader = self.archive.ArchiveReadDisk()

  -- windows specific
  if pl.path.is_windows ~= true then
    tArcResult = tReader:set_standard_lookup()
    if tArcResult ~= 0 then
      local strMsg = string.format('ERROR: Failed to set standard lookup: %s', tReader:error_string())
      error(strMsg)
    end
  end

  tArcResult = tReader:set_behavior(self.uiBehavior)
  if tArcResult ~= 0 then
    local strMsg = string.format('ERROR: Failed to set the standard behaviour: %s', tReader:error_string())
    error(strMsg)
  end

  -- Create a new archive.
  local tArchive = self.archive.ArchiveWrite()

  -- set format
  tArcResult = tArchive:set_format(self.uiFormat)
  if tArcResult ~= 0 then
    local strMsg = string.format('ERROR: Failed to set the archive format to ID %d: %s', self.uiFormat, tArchive:error_string())
    error(strMsg)
  end

  -- set filter
  for _, uiFilter in ipairs(self.tFilterNumb) do
    tArcResult = tArchive:add_filter(uiFilter)
    if tArcResult ~= 0 then
      local strMsg = string.format('ERROR: Failed to add filter with ID %d: %s', uiFilter, tArchive:error_string())
      error(strMsg)
    end
  end

  -- open the archive
  tArcResult = tArchive:open_filename(self.strArchivePath)
  if tArcResult ~= 0 then
    local strMsg = string.format('ERROR: Failed to open the archive "%s": %s', self.strArchivePath, tArchive:error_string())
    error(strMsg)
  end

  -- iterate over the resolved filesystem file path structure
  for strArchiveFilePath,strFilePath in pairs(self.tResolvedArchiveStructure) do

    -- check whether the file path exist.
    if pl.path.isfile(strFilePath) ~= true then
      local strMsg = string.format('ERROR: The file path does not exist: "%s".',strFilePath)
      error(strMsg)
    end

    -- set file entry
    local tEntry = tReader:entry_from_file(strFilePath)
    if tEntry == nil then
      local strMsg = string.format('ERROR: Failed to read the data of "%s"',strFilePath)
      error(strMsg)
    end

    -- set the new archive file path of the data
    tEntry:set_pathname(strArchiveFilePath)

    tArcResult = tArchive:write_header(tEntry)
    if tArcResult ~= 0 then
      local strMsg = string.format('ERROR: Failed to write the header for archive member "%s": %s', tEntry:pathname(), tArchive:error_string())
      error(strMsg)
    end

    -- Copy the data.
    local tFile, strError = io.open(strFilePath, 'rb')
    if tFile == nil then
      local strMsg = string.format('ERROR: Failed to open "%s" for reading: %s', strFilePath, tostring(strError))
      error(strMsg)
    end

    -- Copy the data in chunks.
    repeat
      local strData = tFile:read(self.uiChunkSize)
      if strData ~= nil then
        tArchive:write_data(strData)
        if tArcResult ~= 0 then
          local strMsg = string.format('ERROR: Failed to write a chunk of data to archive member "%s": %s', tEntry:pathname(), tArchive:error_string())
          error(strMsg)
        end
      end
    until strData == nil

    -- Finish the entry.
    tArcResult = tArchive:finish_entry()
    if tArcResult ~= 0 then
      local strMsg = string.format('ERROR: Failed to finish archive member "%s": %s', tEntry:pathname(), tArchive:error_string())
      error(strMsg)
    end
  end

  tArcResult = tReader:close()
  if tArcResult ~= 0 then
    local strMsg = string.format('ERROR: Failed to close the reader: %s', tReader:error_string())
    error(strMsg)
  end

  tArcResult = tArchive:close()
  if tArcResult ~= 0 then
    local strMsg = string.format('ERROR: Failed to close the archive "%s": %s', self.strArchivePath, tArchive:error_string())
    error(strMsg)
  end
end

local tArchive = Archive()
tArchive:run()