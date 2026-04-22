local archive = require 'archive'

local tBuilder = {
  id = 'Archive',
  version = '1.0.0',

  atArchiveFormats = {
    ['tar.bz2'] = {
      extension = 'tar.bz2',
      format = archive.ARCHIVE_FORMAT_TAR_GNUTAR,
      filter = {
        archive.ARCHIVE_FILTER_BZIP2
      }
    },
    ['tar.gz'] = {
      extension = 'tar.gz',
      format = archive.ARCHIVE_FORMAT_TAR_GNUTAR,
      filter = {
        archive.ARCHIVE_FILTER_GZIP
      }
    },
    ['tar.lzip'] = {
      extension = 'tar.lzip',
      format = archive.ARCHIVE_FORMAT_TAR_GNUTAR,
      filter = {
        archive.ARCHIVE_FILTER_LZIP
      }
    },
    ['tar.xz'] = {
      extension = 'tar.xz',
      format = archive.ARCHIVE_FORMAT_TAR_GNUTAR,
      filter = {
        archive.ARCHIVE_FILTER_XZ
      }
    },
    ['zip'] = {
      extension = 'zip',
      format = archive.ARCHIVE_FORMAT_ZIP,
      filter = {}
    }
  }
}



function tBuilder:__addContents(tArchive, tReader, tArchiveContents, astrPathElements)
  astrPathElements = astrPathElements or {}
  local fResult = true
  local strError

  local path = require 'pl.path'

  -- Loop over all entries on this folder level.
  for _, tEntry in ipairs(tArchiveContents) do
    -- Get the type of the entry, this can be "dir" or "file".
    local strType = tEntry.type
    if strType=='dir' then
      -- Add the directory name to the list of path elements.
      table.insert(astrPathElements, tEntry.name)
      -- Recurse into the directory structure.
      fResult, strError = self:__addContents(tArchive, tReader, tEntry.contents, astrPathElements)
      -- Stop processing the contents if an error occured.
      if fResult~=true then
        break
      end
      -- Remove the directory name from the list of path elements.
      table.remove(astrPathElements)

    elseif strType=='file' then
      -- Get the source path for the file.
      local strPathSrc = tEntry.src
      -- Read the file as an archive entry including owner, rights, access time and much more.
      local tArchiveEntry = tReader:entry_from_file(strPathSrc)
      if tArchiveEntry==nil then
        fResult = false
        strError = string.format(
          'Failed to get the file "%s": %s',
          strPathSrc,
          tReader:error_string()
        )
        break
      else
        -- Set the path and filename of the entry.
        local strBasename = tEntry.rename
        if strBasename==nil then
          strBasename = path.basename(tArchiveEntry:pathname())
        end
        local strPathAndName
        if #astrPathElements==0 then
          strPathAndName = strBasename
        else
          strPathAndName = path.join(
            table.concat(astrPathElements, '/'),
            strBasename
          )
        end
        tArchiveEntry:set_pathname(strPathAndName)

        local tArcResult = tArchive:write_header(tArchiveEntry)
        if tArcResult~=0 then
          fResult = false
          strError = string.format(
            'Failed to write the header for archive member "%s": %s',
            tEntry:pathname(),
            tArchive:error_string()
          )
          break
        else
          -- Copy the data.
          local tSrcFile, strOpenError = io.open(strPathSrc, 'rb')
          if tSrcFile==nil then
            strError = string.format(
              'Failed to open "%s" for reading: %s',
              strPathSrc,
              tostring(strOpenError)
            )
            break
          else
            -- Copy the data in chunks of 16k. Just in case we meet terabyte files here.
            repeat
              local strData = tSrcFile:read(16384)
              if strData~=nil then
                tArcResult = tArchive:write_data(strData)
                if tArcResult~=0 then
                  fResult = false
                  strError = string.format(
                    'Failed to write a chunk of data to archive member "%s": %s',
                    strPathAndName,
                    tArchive:error_string()
                  )
                  break
                end
              end
            until strData==nil
            if tArcResult~=0 then
              break
            else
              tArcResult = tArchive:finish_entry()
              if tArcResult~=0 then
                fResult = false
                strError = string.format(
                  'Failed to finish archive member "%s": %s',
                  tEntry:pathname(),
                  tArchive:error_string()
                )
                break
              end
            end
          end
        end
      end
    end
  end

  return fResult, strError
end



-- This method will be run in a new process.
function tBuilder:runBuildTask(tArguments)
  local fResult = false
  local strError

  -- Get the format attributes.
  local strArchiveFormat = tArguments.format
  local tFormatAttr = self.atArchiveFormats[strArchiveFormat]
  if tFormatAttr==nil then
    strError = 'Unknown archive format: ' .. tostring(strArchiveFormat)

  else
    local path = require 'pl.path'

    -- Create a new reader to get files from disk with metadata.
    local tReader = archive.ArchiveReadDisk()
    local tArcResult = 0
    if path.is_windows~=true then
      tArcResult = tReader:set_standard_lookup()
    end
    if tArcResult~=0 then
      strError = 'Failed to set standard lookup: ' .. tReader:error_string()

    else
      local uiBehavior = 0
      tArcResult = tReader:set_behavior(uiBehavior)
      if tArcResult~=0 then
        strError = 'Failed to set the standard behaviour: ' .. tReader:error_string()

      else
        -- Create a new archive.
        local tArchive = archive.ArchiveWrite()
        tArcResult = tArchive:set_format(tFormatAttr.format)
        if tArcResult~=0 then
          strError = string.format(
            'Failed to set the archive format to ID %d: %s',
            tFormatAttr.format,
            tArchive:error_string()
          )
        else
          for _, tFilter in ipairs(tFormatAttr.filter) do
            tArcResult = tArchive:add_filter(tFilter)
            if tArcResult~=0 then
              strError = string.format(
                'Failed to add filter with ID %d: %s',
                tFilter,
                tArchive:error_string()
              )
              break
            end
          end
          if tArcResult==0 then
            -- Remove any existing archive.
            local tDeleteResult = true
            local strOutputPath = tArguments.output
            if path.exists(strOutputPath)==strOutputPath then
              local strDeleteError
              tDeleteResult, strDeleteError = os.remove(strOutputPath)
              if tDeleteResult~=true then
                strError = string.format(
                  'Failed to delete the old archive "%s": %s',
                  strOutputPath,
                  strDeleteError
                )
              end
            end
            if tDeleteResult==true then
              tArcResult = tArchive:open_filename(strOutputPath)
              if tArcResult~=0 then
                strError = string.format(
                  'Failed to open the archive "%s" for writing: %s',
                  strOutputPath,
                  tArchive:error_string()
                )
              else
                -- Add and remove path elements while traversing the archive contents.
                local fAddContentsResult, strAddContentsError = self:__addContents(
                  tArchive,
                  tReader,
                  tArguments.contents
                )
                if fAddContentsResult~=true then
                  strError = 'Failed to add the archive contents: ' .. tostring(strAddContentsError)

                else
                  tArcResult = tArchive:close()
                  if tArcResult~=0 then
                    strError = string.format(
                      'Failed to close the archive "%s": %s',
                      strOutputPath,
                      tArchive:error_string()
                    )
                  else
                    fResult = true
                  end
                end
              end
            end
          end
        end
      end
    end

    tReader:close()
  end

  if fResult~=true then
    error('Failed to create the archive: ' .. strError)
  end
end



function tBuilder:applyToEnv(tEnv, tCfg)
  local strBuilderId = self.id

  local atArchiveFormatsUpvalue = self.atArchiveFormats
  function tEnv:Archive(strOutputPath, atContents, tParameter)
    tParameter = tParameter or {}

    -- Get the archive format from the parameter. Use the filename extension as a fallback.
    local strArchiveFormat = tParameter.FORMAT
    if type(strArchiveFormat)~='string' then
      -- Look for one of the known extensions.
      strArchiveFormat = nil
      for strExtension, tAttributes in pairs(atArchiveFormatsUpvalue) do
        local strExtensionWithDot = '.' .. strExtension
        -- Does the output path end with a dot followed by the extension?
        local sizExtensionWithDot = string.len(strExtensionWithDot)
        if string.sub(strOutputPath, -sizExtensionWithDot)==strExtensionWithDot then
          strArchiveFormat = strExtension
        end
      end
      if strArchiveFormat==nil then
        error('No archive format specified and failed to guess from the filename.')
      end
    end

    local tJobParameter = {
      contents = atContents,
      output = strOutputPath,
      format = strArchiveFormat
    }
    self:addLuaJob(strBuilderId, strBuilderId, strOutputPath, tJobParameter)

    -- Collect all files in the archive contents.
    local astrAllSrcFiles = require 'mbs2.archive_helper':getAllFiles(atContents)
    for _, strSrcFile in ipairs(astrAllSrcFiles) do
      AddDependency(strOutputPath, strSrcFile)
    end

    return strOutputPath
  end

  return true
end


return tBuilder
