---------------------------------------------------------------------------------------------------------------------
--
-- A BAM builder which replaces a set of fields.
--
local tEnv, strBuilderPath = ...
if tEnv==nil then
  -------------------------------------------------------------------------------------------------------------------
  --
  -- Builder
  -- This is the builder code which does the real work.
  --
  local pl = require'pl.import_into'()

  local strParameter = _bam_targets[0]

  local rapidjson = require 'rapidjson'
  local tParameter, strParameterError = rapidjson.decode(strParameter)
  if tParameter==nil then
    error(string.format('Failed to decode the input parameter "%s": %s', strParameter, strParameterError))
  else
    -- Read the input file.
    -- NOTE: read the file as binary to keep line feeds.
    local strInputData, strReadError = pl.utils.readfile(tParameter.input, true)
    if strInputData==nil then
      error(string.format('Failed to read the input file "%s": %s', tParameter.input, strReadError))
    else
      -- Replace all parameters.
      local strReplaced = string.gsub(strInputData, '%$%{([^}]+)%}', tParameter.replace)

      -- Write the replaced data to the output file.
      -- NOTE: write the file as binary to keep line feeds.
      local tWriteResult, strWriteError = pl.utils.writefile(tParameter.output, strReplaced, true)
      if tWriteResult~=true then
        error(string.format('Failed to write the output file "%s": %s', tParameter.output, strWriteError))
      end
    end
  end

else
  -------------------------------------------------------------------------------------------------------------------
  --
  -- Interface
  -- This is the interface code which registers a function in an environment.
  --
  local pl = require'pl.import_into'()

  function tEnv:Template(strTarget, strInput, atReplacement)
    local tFilterParameter = {
      input = pl.path.abspath(strInput),
      output = pl.path.abspath(strTarget),
      replace = atReplacement
    }

    local rapidjson = require 'rapidjson'
    local strFilterParameter = rapidjson.encode(tFilterParameter, { sort_keys=true })
    AddJob(
      tFilterParameter.output,
      string.format('Template %s', tFilterParameter.input),
      _bam_exe .. " -e " .. strBuilderPath .. " '" .. strFilterParameter .. "'"
    )
    return tFilterParameter.output
  end

  local function getGitDescription(strRepositoryPath)
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
    print(string.format('GIT description: "%s"', strGitId))

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

  --  tLog.debug('Parsing GIT description "%s".', strGitId)
    local tMatch = string.match(strGitId, '^%x%x%x%x%x%x%x%x%x%x%x%x%+?$')
    if tMatch~=nil then
  --    tLog.debug('This is a repository with no tags. Use the hash.')
      strProjectVersionVcs = strGitId
      strProjectVersionVcsLong = strGitId
    else
      local strVersion, strRevsSinceTag, strHash, strDirty = string.match(strGitId, '^v([%d.]+)-(%d+)-g(%x%x%x%x%x%x%x%x%x%x%x%x)(%+?)$')
      if strVersion~=nil then
        local ulRevsSinceTag = tonumber(strRevsSinceTag)
        if ulRevsSinceTag==0 and strDirty=='' then
  --        tLog.debug('This is a repository which is exactly on a tag without modification. Use the tag name.')
          strProjectVersionVcs = string.format('v%s%s', strVersion, strDirty)
          strProjectVersionVcsLong = string.format('v%s-%s%s', strVersion, strHash, strDirty)
        else
  --        tLog.debug('This is a repository with commits after the last tag. Use the hash.')
          strProjectVersionVcs = string.format('%s%s', strHash, strDirty)
          strProjectVersionVcsLong = string.format('%s%s', strHash, strDirty)
        end
      else
  --      tLog.debug('The description has an unknown format.')
        strProjectVersionVcs = strGitId
        strProjectVersionVcsLong = strGitId
      end
    end

    -- Prepend "GIT" to the VCS ID.
    strProjectVersionVcs = 'GIT' .. strProjectVersionVcs
    strProjectVersionVcsLong = 'GIT' .. strProjectVersionVcsLong
  --  tLog.debug('PROJECT_VERSION_VCS = "%s"', strProjectVersionVcs)
  --  tLog.debug('PROJECT_VERSION_VCS_LONG = "%s"', strProjectVersionVcsLong)

    return strProjectVersionVcs, strProjectVersionVcsLong
  end


  function tEnv:VersionTemplate(strTarget, strInput, atExtraReplacements)
    local strGitDescription = getGitDescription('.')
    local strProjectVersionVcs, strProjectVersionVcsLong = parseGitID(strGitDescription)
    print(strProjectVersionVcs, strProjectVersionVcsLong)

    local atReplacement = {
      PROJECT_VERSION_MAJOR = self.atVars.PROJECT_VERSION[1],
      PROJECT_VERSION_MINOR = self.atVars.PROJECT_VERSION[2] or '0',
      PROJECT_VERSION_MICRO = self.atVars.PROJECT_VERSION[3] or '0',
      PROJECT_VERSION_VCS = strProjectVersionVcs,
      PROJECT_VERSION_VCS_LONG = strProjectVersionVcsLong,
      PROJECT_VERSION = string.format(
        '%s.%s.%s',
        self.atVars.PROJECT_VERSION[1],
        self.atVars.PROJECT_VERSION[2] or '0',
        self.atVars.PROJECT_VERSION[3] or '0'
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

    local rapidjson = require 'rapidjson'
    local strFilterParameter = rapidjson.encode(tFilterParameter, { sort_keys=true })
    AddJob(
      tFilterParameter.output,
      string.format('VersionTemplate %s', tFilterParameter.input),
      _bam_exe .. " -e " .. strBuilderPath .. " '" .. strFilterParameter .. "'"
    )
    return tFilterParameter.output
  end
end
