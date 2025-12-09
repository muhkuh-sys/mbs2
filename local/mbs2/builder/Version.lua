local tBuilder = {
  id = 'Version',
  version = '1.0.0'
}



function tBuilder.__getGitDescription(strRepositoryPath)
  local luagit2 = require 'luagit2'

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
function tBuilder.__parseGitID(strGitId)
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



-- This method will be run in a new process.
function tBuilder:runBuildTask(tArguments)
  -- Read the input file.
  -- NOTE: read the file as binary to keep line feeds as they are.
  local utils = require 'pl.utils'
  local strInputPath = tArguments.input
  local strInputData, strReadError = utils.readfile(strInputPath, true)
  if strInputData==nil then
    error(string.format(
      'ERROR: Failed to read the input file "%s": %s', strInputPath, strReadError
    ))
  end

  local strReplaced = string.gsub(strInputData, tArguments.pattern, tArguments.replace)

  -- Write the replaced data to the output file.
  -- NOTE: write the file as binary to keep line feeds as they are.
  local strOutputPath = tArguments.output
  local tWriteResult, strWriteError = utils.writefile(strOutputPath, strReplaced, true)
  if tWriteResult~=true then
    error(string.format(
      'ERROR: Failed to write the output file "%s": %s',
      strOutputPath,
      strWriteError
    ))
  end
end



function tBuilder:applyToEnv(tEnv, tCfg)
  local strBuilderId = self.id

  function tEnv:Version(strOutputPath, strInputPath, tParameter)
    tParameter = tParameter or {}

    -- The default path is the current working folder.
    -- Override it with the parameter REPOSITORY_PATH.
    local path = require 'pl.path'
    local strGitRepositoryPath = tParameter.REPOSITORY_PATH
    if type(strGitRepositoryPath)~='string' then
      strGitRepositoryPath = path.currentdir()
    end

    -- Get the VCS version.
    local strProjectVersionVcs, strProjectVersionVcsLong, fIsTagged
    local fResult, strGitDescription = pcall(self.__getGitDescription, strGitRepositoryPath)
    if fResult then
      strProjectVersionVcs, strProjectVersionVcsLong, fIsTagged = self.__parseGitID(strGitDescription)
    else
      strProjectVersionVcs, strProjectVersionVcsLong, fIsTagged = 'unknown', 'unknown', false
    end
    local strSnapshot = (fIsTagged==false) and '-SNAPSHOT' or ''

    -- Get the project version.
    local astrProjectVersion = self.mbs.PROJECT_VERSION

    local atReplace = {
      PROJECT_VERSION_MAJOR = astrProjectVersion[1],
      PROJECT_VERSION_MINOR = astrProjectVersion[2],
      PROJECT_VERSION_MICRO = astrProjectVersion[3],
      PROJECT_VERSION_VCS = strProjectVersionVcs,
      PROJECT_VERSION_VCS_LONG = strProjectVersionVcsLong,
      PROJECT_VERSION = string.format(
        '%s.%s.%s%s',
        astrProjectVersion[1],
        astrProjectVersion[2],
        astrProjectVersion[3],
        strSnapshot
      )
    }
    local atExtraReplace = tParameter.REPLACE
    if type(atExtraReplace)=='table' then
      require 'pl.tablex'.update(atReplace, atExtraReplace)
    end

    -- The default pattern extracts an identifier enclosed in '${...}'.
    local strPattern = tParameter.PATTERN
    if type(strPattern)~='string' then
      strPattern = '%${([%a_][%w_]*)}'
    end

    local tJobParameter = {
      input = strInputPath,
      output = strOutputPath,
      replace = atReplace,
      pattern = strPattern
    }
    self:addLuaJob(strBuilderId, strBuilderId, strOutputPath, tJobParameter)
  end

  return true
end


return tBuilder
