---------------------------------------------------------------------------------------------------------------------
--- Set additonal package paths of lua modules in mbs2
-- Additonally, a proxy table of the mbs2 folder will be returned to load chunk of lua modules
-- The proxy table calls a chunk loading functionw with the given path and save the chunk in the proxy table to prevent a reloading
-- for e.g.:
--[[

-- Add additonal package paths to the LUA search path and return a proxy table of the mbs2 folder to load chunk of lua the modules
local mbs2 = require "import_mbs"()

-- load chunk data:
local tElf_Support = mbs2.utils.elf_support()
local gcc_arm_none_eabi_4_9_3_4 = mbs2.tools.gcc_arm_none_eabi_4_9_3_4(tEnv, strBuilderPath)
local hboot_image = mbs2.builder.hboot_image(tEnv, strBuilderPath)

local tElf_Support = mbs2.utils.elf_support() -- call again - chunk still loaded in the proxy table

table structure within the proxy table (json):
{
    "builder": {
        "gcc_symbol_template": "mbs2/builder/gcc_symbol_template.lua",
        "hboot_image": "mbs2/builder/hboot_image.lua",
        "template": "mbs2/builder/template.lua"
    },
    "mbs": "mbs2/mbs.lua",
    "tools": {
        "gcc_arm_none_eabi_4_7_2_3": "mbs2/tools/gcc_arm_none_eabi_4_7_2_3.lua",
        "gcc_arm_none_eabi_4_9_3_4": "mbs2/tools/gcc_arm_none_eabi_4_9_3_4.lua"
    },
    "utils": {
        "elf_support": "mbs2/utils/elf_support.lua",
        "lpeg_support": "mbs2/utils/lpeg_support.lua"
    }
}

--]]


---------------------------------------------------------------------------------------------------------------------
--
-- SETTINGS:
--

-- Provide Penlight as an upvalue to all functions.
local pl = require'pl.import_into'()

-- additonal package paths
local tAddPaths =
{
  strToolsPath = 'mbs2/tools/?.lua;mbs2/tools/?/init.lua;',
  strBuilderPath = 'mbs2/builder/?.lua;mbs2/builder/?/init.lua;',
  strUtilsPath = 'mbs2/utils/?.lua;mbs2/utils/?/init.lua;'
}


local strRoot = "mbs2/" -- "."
local tExceptionFolder = pl.Set{"jonchki", "local", "hboot_image_compiler"}
-- in the case of files without extensions use: "no_extension"
local tExtensions = pl.Set{"lua"}

---------------------------------------------------------------------------------------------------------------------
--
-- Auxiliary functions
--

local lpeg = require"lpeglabel"

-- Save typing function names with "lpeg" in front of them:
local P, V, Cg, Ct, Cc, S, R, C, Cf, Cb, Cs = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.S, lpeg.R, lpeg.C, lpeg.Cf, lpeg.Cb, lpeg.Cs

-- Auxiliary function: transform table to set (values)
local fExtensionsToSet = function(tmatch)
  -- empty table?
  if tmatch ~= nil and next(tmatch) == nil then
    tmatch = {"no_extension"}
  end

  return pl.Set(tmatch)
end

local File =
Ct(
  P{
    "start", --> this tells LPEG which rule to process first
    start      =  V"filename" * V"extension" + 1* V"start",
    filename   = Cg(V"hiddenFile" * (1 - (P"." + -1)) ^ 1 ,"filename"),
    hiddenFile = P"."^-1,
    extension  = Cg( Ct( ( P"." * C((1 - (P"." + -1) )^1)  )^0) / fExtensionsToSet,"extension")
  }
)

local Path =
Ct(
  P{
    "start", --> this tells LPEG which rule to process first
    start      = V"FolderName" * (V"Sep" * V"FolderName" )^0,
    FolderName = C((P(1) - (V"Ending"))^1),
    Ending     = V"Sep" + -1,
    Sep        = P(pl.path.sep)
  }
)


--- Load and return chunk of module
local function GetChunk(strBuilder)
  -- Try to load the builder script.
  local strBuilderScript, strError = pl.utils.readfile(strBuilder, false)
  if strBuilderScript == nil then
    local strMsg = string.format('ERROR: Failed to read script "%s": %s', strBuilder, strError)
    error(strMsg)
  end

  -- Load the script.
  local tChunk, strError = pl.compat.load(strBuilderScript, strBuilder, 't')
  if tChunk == nil then
    local strMsg = string.format('ERROR: Failed to parse script "%s": %s', strBuilder, strError)
    error(strMsg)
  end

  -- call the chunk
  -- local bStatus, tResult = pcall(tChunk)
  -- if bStatus==nil then
  --   local strMsg = string.format('Failed to call the script "%s": %s', strBuilder, tResult)
  --   error(strMsg)
  -- end

  -- return tResult
  return tChunk
end


--- access key of proxy
local function checkAccess()
  return "__ACCESS__"
end


--- set the access of proxy table
local function setAccessProxy(atProxy)
  local tMetatable = getmetatable(atProxy)
  if tMetatable ~= nil and tMetatable.__PROXY == true then
    atProxy[checkAccess] = false
    for _,tProxy in pairs(atProxy) do
      if tProxy ~= nil and type(tProxy) == "table" then
        setAccessProxy(tProxy)
      end
    end
  end
end


--- modifies a table to be read only.
local function proxy(tbl)
  tbl = tbl or {}

  -- closure variable to set access to the table
  local fAccess = true

  -- http://lua-users.org/wiki/MetatableEvents
  -- http://lua-users.org/wiki/GeneralizedPairsAndIpairs
  -- create metatable for the proxy
  local tMetaTable = {
    __index = function(tProxy, key)
      -- access the original table
      if key ~= checkAccess then
        -- chunk still available?

        -- not necessary - due to the property of __index: "__index is only accessed when:
        -- When the key being read from the main table does not already exist in the main table."

        -- local proxy_raw = rawget(tProxy,key)
        -- if proxy_raw ~= nil then
        --   return proxy_raw
        -- end

        local tmatch = tbl[key]
        if tmatch ~= nil then
          if type(tmatch) == "table" then
            -- return next level proxy table
            return tbl[key]
          elseif type(tmatch) == "string" then
            local tChunk = GetChunk(tmatch)
            -- set the chunk to the proxy table to prevent a reloading
            rawset(tProxy,key,tChunk)
            return tChunk
          end
        else
          local strMsg = string.format("ERROR: The key: '%s' is not available.",tostring(key))
          error(strMsg)
        end
      else
        return tProxy()
      end
    end,
    __newindex = function(tProxy, key, value)
      if key == checkAccess and fAccess == true and value == false then
        fAccess = value
      elseif fAccess == true then
        tbl[key] = value
      else
        local strMsg = string.format("ERROR: Read only table.")
        error(strMsg)
      end
    end,
    -- necessary due to that an iteration of the node table is required (not of the proxy table).
    __pairs = function(_)
      -- Iterator function takes the table and an index and returns the next index and associated value
      -- or nil to end iteration
      local function stateless_iter(tbl, key)
        local value
        key, value = next(tbl, key)
        if value ~= nil then
          return key, value
        end
      end
      -- Return an iterator function, the table, starting point
      return stateless_iter, tbl, nil
    end,
    -- Dont work - ipairs use __index
    __ipairs = function()
      return ipairs(tbl)
    end,
    __len = function(_)
      return #tbl
    end,
    __tostring = function()
      return pl.pretty.write(tbl, "")
    end,
    -- fake metatable
    -- __metatable = {__name = "<PROXY>"},
    __call = function()
      return fAccess
    end,
    __PROXY = true
  }

  local tProxy = {} -- setmetatable( {}, { __mode = "kv",} )
  setmetatable(tProxy, tMetaTable)

  return tProxy
end


--- create a proxy table of specified files in a folder
local function walk_dirTree(strRoot,tExceptionFolder,tExtensions)

  local function walk(strCurrentPath,TreeFile)
    local tFiles = pl.dir.getfiles(strCurrentPath)
    local tFolders = pl.dir.getdirectories(strCurrentPath)

    for _,strFile in pairs(tFiles) do
      local tmatch_Path = Path:match(strFile)
      if tmatch_Path == nil then
        local strMsg = string.format("ERROR: Failed to split path of '%s'. ",strFile)
        error(strMsg)
      end

      local strFileName = tmatch_Path[#tmatch_Path]

      local tmatch_File = File:match(strFileName)
      if tmatch_File == nil then
        local strMsg = string.format("ERROR: Failed to match the filename of '%s'. ",strFileName)
        error(strMsg)
      end

      -- intersection of both sets: check similarities - the number of intersection must be equal to the number of extensions
      local tSet_Intersection = tExtensions * tmatch_File.extension
      if #tSet_Intersection == #tmatch_File.extension then
        TreeFile[tmatch_File.filename] = strFile
      end
    end

    for _,strFolder in pairs(tFolders) do
      local tmatch_Path = Path:match(strFolder)
      if tmatch_Path == nil then
        local strMsg = string.format("ERROR: Failed to split path of '%s'. ",strFolder)
        error(strMsg)
      end

      local strFolderName = tmatch_Path[#tmatch_Path]
      if tExceptionFolder[strFolderName] ~= true then
        TreeFile[strFolderName] = proxy()
        walk(strFolder,TreeFile[strFolderName])
      end
    end
  end

  local TreeFile = proxy()
  walk(strRoot,TreeFile)
  setAccessProxy(TreeFile)
  return TreeFile
end


---------------------------------------------------------------------------------------------------------------------
--
-- Return functions
--

return function()
  -- Add additonal package paths folder to the LUA search path.
  for _,strPath in pairs(tAddPaths) do
    package.path = strPath .. package.path
  end

  -- additionally: return mbs2 proxy object wich can load any lua file as chunk in the folder mbs2
  local tMbs2 = walk_dirTree(strRoot,tExceptionFolder,tExtensions)


  -- DEBUGGING:
  --[[
  local function copyProxy(atProxy,atMbs2_copy)
    for strKey,tProxy in pairs(atProxy) do
      if tProxy ~= nil and type(tProxy) == "table" then
        atMbs2_copy[strKey] = {}
        copyProxy(tProxy,atMbs2_copy[strKey])
      else
        atMbs2_copy[strKey] = tProxy
      end
    end
  end

  local atMbs2_copy = {}
  copyProxy(tMbs2,atMbs2_copy)
  pl.pretty.dump(atMbs2_copy)

  local rapidjson = require 'rapidjson'
  local strTreeFile = rapidjson.encode(atMbs2_copy)
  pl.utils.writefile ("tMbs2_copy.json", strTreeFile, false)
  --]]

  return tMbs2
end
