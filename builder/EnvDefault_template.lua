---------------------------------------------------------------------------------------------------------------------
--
-- A BAM builder which replaces a set of fields.
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
local luagit2 = require 'luagit2'
local rapidjson = require 'rapidjson'


-------------------------------------------------------------------------------------------------
--
-- Local helper functions.
--

local function getGitDescription(strRepositoryPath)
  -- Get the VCS version.
  luagit2.init()

  local tRepo = luagit2.repository_open(strRepositoryPath)

  local tDescribeWorkdirOptions = {
    show_commit_oid_as_fallback = true
  }
  local tDescribeResult = luagit2.describe_workdir(tRepo, tDescribeWorkdirOptions)

  local tDescribeResultOptions = {
    abbreviated_size = 12,
    always_use_long_format = true,
    dirty_suffix = '+'
  }
  local tBufOutput = luagit2.describe_format(tDescribeResult, tDescribeResultOptions)
  local strGitId = luagit2.buf_details(tBufOutput)
  -- print(string.format('GIT description: "%s"', strGitId))

  luagit2.repository_free(tRepo)
  luagit2.shutdown()

  return strGitId
end


--- Parse a GIT description to a short and a long version.
--  GIT description             short version       long version
--  6b95dbdb5cbd                GIT6b95dbdb5cbd     GIT6b95dbdb5cbd
--  6b95dbdb5cbd+               GIT6b95dbdb5cbd+    GIT6b95dbdb5cbd+
--  v0.3.10.2-0-g306110218a64   GITv0.3.10.2        GITv0.3.10.2-306110218a64
--  v0.3.10.2-0-g306110218a64+  GIT306110218a64+    GIT306110218a64+
--  v0.3.10.1-5-g03afd761133f   GIT03afd761133f     GIT03afd761133f
--  v0.3.10.1-5-g03afd761133f+  GIT03afd761133f+    GIT03afd761133f+
local function parseGitID(strGitId)
  local strProjectVersionVcs = 'unknown'
  local strProjectVersionVcsLong = 'unknown'
  local fIsTagged = false

  -- print(string.format('Parsing GIT description "%s".', strGitId))
  local tMatch = string.match(strGitId, '^%x%x%x%x%x%x%x%x%x%x%x%x%+?$')
  if tMatch~=nil then
    -- print(string.format('This is a repository with no tags. Use the hash.'))
    strProjectVersionVcs = strGitId
    strProjectVersionVcsLong = strGitId
  else
    local strVersion, strRevsSinceTag, strHash, strDirty = string.match(strGitId, '^v([%d.]+)-(%d+)-g(%x%x%x%x%x%x%x%x%x%x%x%x)(%+?)$')
    if strVersion~=nil then
      local ulRevsSinceTag = tonumber(strRevsSinceTag)
      if ulRevsSinceTag==0 and strDirty=='' then
        -- print(string.format('This is a repository which is exactly on a tag without modification. Use the tag name.'))
        strProjectVersionVcs = string.format('v%s%s', strVersion, strDirty)
        strProjectVersionVcsLong = string.format('v%s-%s%s', strVersion, strHash, strDirty)
        fIsTagged = true
      else
        -- print(string.format('This is a repository with commits after the last tag. Use the hash.'))
        strProjectVersionVcs = string.format('%s%s', strHash, strDirty)
        strProjectVersionVcsLong = string.format('%s%s', strHash, strDirty)
      end
    else
      -- print(string.format('The description has an unknown format.'))
      strProjectVersionVcs = strGitId
      strProjectVersionVcsLong = strGitId
    end
  end

  -- Prepend "GIT" to the VCS ID.
  strProjectVersionVcs = 'GIT' .. strProjectVersionVcs
  strProjectVersionVcsLong = 'GIT' .. strProjectVersionVcsLong
--  print(string.format('PROJECT_VERSION_VCS = "%s"', strProjectVersionVcs))
--  print(string.format('PROJECT_VERSION_VCS_LONG = "%s"', strProjectVersionVcsLong))

  return strProjectVersionVcs, strProjectVersionVcsLong, fIsTagged
end


-------------------------------------------------------------------------------------------------
--
-- Create environment functions.
--

--- Given replacements are used for the template
function EnvDefault:Template(strTarget, strInput, atReplacement)

  -- check input parameters
  if strTarget == nil or type(strTarget) ~= "string" then
    local strMsg = string.format('ERROR: The input parameter "strTarget" must be a string.')
    error(strMsg)
  end

  if strInput == nil or type(strInput) ~= "string" then
    local strMsg = string.format('ERROR: The input parameter "strInput" must be a string.')
    error(strMsg)
  end

  if atReplacement == nil or type(atReplacement) == "table" then
    local strMsg = string.format('ERROR: The input parameter "atReplacement" must be a table.')
    error(strMsg)
  end

  local tFilterParameter = {
    input = pl.path.abspath(strInput),
    output = pl.path.abspath(strTarget),
    replace = atReplacement
  }

  local strFilterParameter = rapidjson.encode(tFilterParameter, { sort_keys=true })

  AddJob(
    tFilterParameter.output, -- outputs
    string.format('Template %s', tFilterParameter.input), -- label
    _bam_exe .. " " .. pl.utils.quote_arg({"-e", strBuilderPath, strFilterParameter}) -- cmd
  )

  return tFilterParameter.output
end


--- The version and VCS are used as replacements (plus extra replacements) for the template
function EnvDefault:VersionTemplate(strTarget, strInput, atExtraReplacements)

  -- check input parameters
  if strTarget == nil or type(strTarget) ~= "string" then
    local strMsg = string.format('ERROR: The input parameter "strTarget" must be a string.')
    error(strMsg)
  end

  if strInput == nil or type(strInput) ~= "string" then
    local strMsg = string.format('ERROR: The input parameter "strInput" must be a string.')
    error(strMsg)
  end

  if not (atExtraReplacements == nil or type(atExtraReplacements) == "table") then
    local strMsg = string.format('ERROR: The input parameter "atExtraReplacements" must be nil or a table.')
    error(strMsg)
  end

  local strProjectVersionVcs, strProjectVersionVcsLong, fIsTagged
  local fResult, strGitDescription = pcall(getGitDescription, '.')
  if fResult then
    strProjectVersionVcs, strProjectVersionVcsLong, fIsTagged = parseGitID(strGitDescription)
  else
    strProjectVersionVcs, strProjectVersionVcsLong, fIsTagged = 'unknown', 'unknown', false
  end

  local strSnapshot = ''
  if fIsTagged==false then
    strSnapshot = '-SNAPSHOT'
  end

  local atReplacement = {
    PROJECT_VERSION_MAJOR = self.atVars.PROJECT_VERSION[1],
    PROJECT_VERSION_MINOR = self.atVars.PROJECT_VERSION[2] or '0',
    PROJECT_VERSION_MICRO = self.atVars.PROJECT_VERSION[3] or '0',
    PROJECT_VERSION_VCS = strProjectVersionVcs,
    PROJECT_VERSION_VCS_LONG = strProjectVersionVcsLong,
    PROJECT_VERSION = string.format(
      '%s.%s.%s%s',
      self.atVars.PROJECT_VERSION[1],
      self.atVars.PROJECT_VERSION[2] or '0',
      self.atVars.PROJECT_VERSION[3] or '0',
      strSnapshot
    )
  }
  if atExtraReplacements~=nil then
    pl.tablex.update(atReplacement, atExtraReplacements)
  end

  local tFilterParameter = {
    input = pl.path.abspath(strInput),
    output = pl.path.abspath(strTarget),
    replace = atReplacement
  }

  local strFilterParameter = rapidjson.encode(tFilterParameter, { sort_keys=true })

  AddJob(
    tFilterParameter.output, -- output
    string.format('VersionTemplate %s', tFilterParameter.output), -- label
    _bam_exe .. " " .. pl.utils.quote_arg({"-e", strBuilderPath, strFilterParameter}) -- cmd
  )

  return tFilterParameter.output
end


return Builder
