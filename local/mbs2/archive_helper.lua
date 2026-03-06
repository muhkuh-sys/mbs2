local _M = {}


function _M.dir(strName, tContents)
  return {
    type = 'dir',
    name = strName,
    contents = tContents
  }
end



function _M.file(strSrcPath, strRename)
  -- Check if the source path is a file.
  local path = require 'pl.path'
  if path.isfile(strSrcPath)~=true then
    error('The source path "' .. tostring(strSrcPath) .. '" is no file.')
  end
  return {
    type = 'file',
    src = strSrcPath,
    rename = strRename
  }
end



function _M:getHelper()
  return self.dir, self.file
end



function _M:getAllFiles(atArchiveContents, astrFiles)
  astrFiles = astrFiles or {}

  for _, tEntry in ipairs(atArchiveContents) do
    local strType = tEntry.type
    if strType=='dir' then
      -- Recurse into the directory structure.
      self:getAllFiles(tEntry.contents, astrFiles)
    elseif strType=='file' then
      table.insert(astrFiles, tEntry.src)
    end
  end

  return astrFiles
end


return _M
