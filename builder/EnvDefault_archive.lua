---------------------------------------------------------------------------------------------------------------------
--
-- A BAM builder which creates an archive.
--

local strBuilderPath

local class = require "pl.class"
local Builder = class()

-- save environment functions/variables of the EnvDefault for mbs2
local EnvDefault = {}

function Builder:_init(strBuilder)
  self.EnvDefault = EnvDefault
  strBuilderPath = strBuilder
end


-------------------------------------------------------------------------------------------------------------------
--
-- EnvDefault
-- This is the interface code which registers a function in an environment.
--

---------------------------------------------------------------------------------------------------------------------
--
-- global declaration of variables
--

local pl = require'pl.import_into'()
local rapidjson = require 'rapidjson'


-----------------------------------------------------------------------------
--
-- Local helper functions.
--

--- resolve the archive table folder structure to a table with the key value pair: archive file path (key) and filesystem file path (value)
-- @param tArchiveStructure archive filesystem structure as table - table values represent the filesystem file path - each table key must include a table and represents a subfolder - entries without key represent the root folder
-- @return tResolvedArchiveStructure resolved archive filestructure as table: archive file path (key) and filesystem file path (value)
--[[
  example:
  local tArchiveStructure =
  {
    ["lua"] =
    {
      "target/lua/test.lua"
    }
    ["netx"] =
    {
      "target/netx/test.bin"
    }
    "installer/jonchki/install.lua"
  }

  local tArchive = resolve_archiveStructure(tArchiveStructure)

  tArchive =
  {
    ["install.lua"] = "installer/jonchki/install.lua",
    ["netx/test.bin"] = "target/netx/test.bin",
    [""target/lua/test.lua""] = "target/lua/test.lua"
  }
--]]
local function resolve_ArchiveStructure(tArchiveStructure)
  local tResolvedArchiveStructure = {}

  -- recursive function to resolve the archive structure from the table
  local function resolve(tArchiveTemp,strPath)
    strPath = strPath or ""

    for strFolder,tFilePath in pairs(tArchiveTemp) do
      -- subfolder
      if type(tFilePath) == "table" then
          resolve(tFilePath,pl.path.join(strPath,strFolder))
      else
        -- values represent filesystem file paths
        if type(tFilePath) ~= "string" then
          local strMsg = string.format('ERROR: The parameter "%s" must be a string.',tostring(tFilePath))
          error(strMsg)
        end

        local strAbsFilePath = pl.path.abspath(tFilePath)

        -- archive file path (key)
        local strArchivePath = pl.path.join(strPath,pl.path.basename(strAbsFilePath))

        -- add resolved archive structure : archive file path (key) and filesystem file path (value)
        tResolvedArchiveStructure[strArchivePath] = strAbsFilePath
      end
    end
  end

  resolve(tArchiveStructure)
  return tResolvedArchiveStructure
end


-------------------------------------------------------------------------------------------------
--
-- Create archive environment functions.
--

--- Create an archive.
-- @param strArchivePath archive file path - the extension must be added by hand! It is not checked with the given filter and format parameters of the archive object
-- @param strFormat archive format of the archive object
-- @param tFilter table which includes the archive filter of the archive object
-- @param tArchiveStructure filestructure of the archive as table - see resolve_ArchiveStructure
-- @return strArchivePath archive file path
function EnvDefault:Archive(strArchivePath,strFormat,tFilter,tArchiveStructure)
  local archive = require 'archive'

  --- Init lpeg
  local lpeg = require "lpeglabel"

  -- Init lpeg_support
  local tLpeg_Support =  require "lpeg_support"()

  -- Save typing:
  local P, V, Cg, Ct, Cc, S, R, C, Cf, Cb, Cs, match,
  OptionalSpace,Space,Comma =
  lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.S, lpeg.R, lpeg.C, lpeg.Cf, lpeg.Cb, lpeg.Cs, lpeg.match,
  tLpeg_Support.OptionalSpace,tLpeg_Support.Space,tLpeg_Support.Comma


  -- check input parameters
  if strArchivePath == nil or type(strArchivePath) ~= "string" then
    local strMsg = string.format('ERROR: The input parameter "strArchivePath" must be a string.')
    error(strMsg)
  end

  if strFormat == nil or type(strFormat) ~= "string" then
    local strMsg = string.format('ERROR: The input parameter "strFormat" must be a string.')
    error(strMsg)
  end

  if tFilter ~= nil and type(tFilter) == "string" then
    tFilter = {tFilter}
  elseif tFilter == nil then
    tFilter = {}
  elseif not (tFilter == nil or type(tFilter) == "table") then
    local strMsg = string.format('ERROR: The input parameter "tFilter" must be nil or a table.')
    error(strMsg)
  end

  -- pattern of format and filter in the archive object
  local Filter = Ct(tLpeg_Support:Anywhere(P"ARCHIVE_FILTER_" * tLpeg_Support:UpTo(P(1),-1,"filter")))
  local Format = Ct(tLpeg_Support:Anywhere(P"ARCHIVE_FORMAT_" * tLpeg_Support:UpTo(P(1),-1,"format")))
  local atFilter_Archive = {}
  local atFormat_Archive = {}

  -- extract filter and format of archive
  for strKey_Archive,tValue_Archive in pairs(archive) do
    local tmatch_filter = Filter:match(strKey_Archive)
    if tmatch_filter ~= nil then
      atFilter_Archive[tmatch_filter.filter] = tValue_Archive
    end

    local tmatch_format = Format:match(strKey_Archive)
    if tmatch_format ~= nil then
      atFormat_Archive[tmatch_format.format] = tValue_Archive
    end
  end

  -- check, whether the format input parameter is available in the archive object
  if atFormat_Archive[string.upper(strFormat)] == nil then
    local strMsg = string.format('ERROR: The format "%s" is not available in the archive object. The following options of the format are possible:\n"%s"',
      strFormat,
      table.concat(pl.tablex.keys(atFormat_Archive),", ")
    )
    error(strMsg)
  end
  local uiFormat = atFormat_Archive[string.upper(strFormat)]

  -- check, whether the filter input parameters are available in the archive object
  local tFilterNumb = {}
  if tFilter ~= nil and type(tFilter) == "table" and next(tFilter) ~= nil then
    for uiKey,strFilter in ipairs(tFilter) do
      if type(strFilter) ~= "string" then
        local strMsg = string.format('ERROR: The input parameter "tFilter" must have string value entries.')
        error(strMsg)
      elseif type(uiKey) ~= "number" then
        local strMsg = string.format('ERROR: The input parameter "tFilter" must have number key entries.')
        error(strMsg)
      end

      if atFilter_Archive[string.upper(strFilter)] == nil then
        local strMsg = string.format('ERROR: The filter "%s" is not available in the archive object. The following options of the filter are possible:\n"%s"',
        strFilter,
        table.concat(pl.tablex.keys(atFilter_Archive),", ")
      )
        error(strMsg)
      end
      tFilterNumb[uiKey] = atFilter_Archive[string.upper(strFilter)]
    end
  end

  if tArchiveStructure == nil or type(tArchiveStructure) ~= "table" then
    local strMsg = string.format('ERROR: The input parameter "tArchiveStructure" must be a table.')
    error(strMsg)
  elseif next(tArchiveStructure) == nil then
    local strMsg = string.format('ERROR: The input parameter "tArchiveStructure" is empty.')
    error(strMsg)
  end

  -- resolve the archive table folder structure to a table with the key value pair: archive path (key) and filesystem file path (value)
  local tResolvedArchiveStructure = resolve_ArchiveStructure(tArchiveStructure)

  local tParameter =
  {
    strArchivePath            = pl.path.abspath(strArchivePath),
    uiFormat                  = uiFormat,
    tFilterNumb               = tFilterNumb,
    tResolvedArchiveStructure = tResolvedArchiveStructure,
  }

  local strParameter = rapidjson.encode(tParameter, { sort_keys=true })

  AddJob(
    tParameter.strArchivePath,
    string.format("Archive : %s",tParameter.strArchivePath),
    _bam_exe .. " " .. pl.utils.quote_arg({"-e", strBuilderPath,strParameter}) -- cmd
  )

  -- add all files as dependency that are necessary for the archive
  AddDependency(tParameter.strArchivePath, table.unpack(pl.tablex.values(tResolvedArchiveStructure)))

  return tParameter.strArchivePath
end


return Builder