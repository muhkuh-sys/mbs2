local tBuilder = {
  id = 'Artifact',
  version = '1.0.0'
}



function tBuilder:applyToEnv(tEnv, tCfg)
  function tEnv:Artifact(strRepositoryBasePath, astrGroup, strModule, strArtifact, astrVersion, tArchiveContents)
    local strVersion = table.concat(astrVersion, '.')

    local path = require 'pl.path'
    local strModulePath = path.join(
      strRepositoryBasePath,
      table.unpack(astrGroup),
      strModule,
      strVersion
    )

    -- Create the artifact.
    local tArtifact = tEnv:Archive(
      path.join(strModulePath, string.format('%s-%s.tar.lzip', strArtifact, strVersion)),
      tArchiveContents
    )
    -- Generate the hash sums for the artifact.
    local tArtifactHash = tEnv:Hash(
      tArtifact .. '.hash',
      tArtifact,
      {
        HASH_ALGORITHM = 'md5,sha1,sha224,sha256,sha384,sha512',
        HASH_TEMPLATE = '${ID_UC}:${HASH}\n'
      }
    )
    -- Create the configuration from the template.
    local tConfiguration = tEnv:Version(
      path.join(strModulePath, string.format('%s-%s.xml', strArtifact, strVersion)),
      string.format('installer/jonchki/%s.xml', strModule)
    )
    -- Generate the hash sums for the artifact.
    local tConfigurationHash = tEnv:Hash(
      tConfiguration .. '.hash',
      tConfiguration,
      {
        HASH_ALGORITHM = 'md5,sha1,sha224,sha256,sha384,sha512',
        HASH_TEMPLATE = '${ID_UC}:${HASH}\n'
      }
    )

    return tArtifact, tArtifactHash, tConfiguration, tConfigurationHash
  end

  return true
end


return tBuilder
