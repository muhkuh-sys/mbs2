local tBuilder = {
  id = 'Artifact',
  version = '1.0.0'
}



function tBuilder:applyToEnv(tEnv, tCfg)
  function tEnv:Artifact(strRepositoryBasePath, astrGroup, strModule, strArtifact, astrVersion, tArchiveContents, tParameter)
    tParameter = tParameter or {}

    local strVersion = table.concat(astrVersion, '.')

    local path = require 'pl.path'
    local strModulePath = path.join(
      strRepositoryBasePath,
      table.unpack(astrGroup),
      strModule,
      strVersion
    )

    local strHashAlgorithm = tParameter.HASH_ALGORITHM
    if type(strHashAlgorithm)~='string' then
      strHashAlgorithm = 'md5,sha1,sha224,sha256,sha384,sha512'
    end
    local strHashTemplate = tParameter.HASH_TEMPLATE
    if type(strHashTemplate)~='string' then
      strHashTemplate = '${ID_UC}:${HASH}\n'
    end

    -- Create the artifact.
    local tArtifact = tEnv:Archive(
      path.join(strModulePath, string.format('%s-%s.tar.lzip', strArtifact, strVersion)),
      tArchiveContents,
      {
        FORMAT = tParameter.FORMAT
      }
    )
    -- Generate the hash sums for the artifact.
    local tArtifactHash = tEnv:Hash(
      tArtifact .. '.hash',
      tArtifact,
      {
        HASH_ALGORITHM = strHashAlgorithm,
        HASH_TEMPLATE = strHashTemplate
      }
    )
    -- Create the configuration from the template.
    local tConfiguration = tEnv:Version(
      path.join(strModulePath, string.format('%s-%s.xml', strArtifact, strVersion)),
      string.format('installer/jonchki/%s.xml', strModule),
      {
        REPOSITORY_PATH = tParameter.REPOSITORY_PATH,
        ENABLE_SNAPSHOT_MARKER = tParameter.ENABLE_SNAPSHOT_MARKER
      }
    )
    -- Generate the hash sums for the artifact.
    local tConfigurationHash = tEnv:Hash(
      tConfiguration .. '.hash',
      tConfiguration,
      {
        HASH_ALGORITHM = strHashAlgorithm,
        HASH_TEMPLATE = strHashTemplate
      }
    )

    return tArtifact, tArtifactHash, tConfiguration, tConfigurationHash
  end

  return true
end


return tBuilder
