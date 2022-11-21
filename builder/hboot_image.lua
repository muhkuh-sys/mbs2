---------------------------------------------------------------------------------------------------------------------
--
-- A BAM builder which applies Hboot image compiler.
--
local tEnv, strBuilderPath = ...
if tEnv==nil then
  -------------------------------------------------------------------------------------------------------------------
  --
  -- Builder
  -- This is the builder code which does the real work.
  --

else
  -------------------------------------------------------------------------------------------------------------------
  --
  -- Interface
  -- This is the interface code which registers a function in an environment.
  --

  --- global declaration of variables:
  local pl = require'pl.import_into'()
  local tLpeg_Support = require "lpeg_support"

  -- strPathElf is neccessary for the dependency of BAM
  function tEnv:HBootImage(strTarget, strHbootDefinition,strPathElf,tHbootArguments)

    --FIXME: the arguments must be adapted to the current release version of the hboot image compiler.
    local tFlags = {
      ["netx-type"]        = {["flag"] = "--netx-type",        ["type"]="string"},
      ["netx-type-public"] = {["flag"] = "--netx-type-public", ["type"]="string"},
      ["objcopy"]          = {["flag"] = "--objcopy",          ["type"]="string"},
      ["objdump"]          = {["flag"] = "--objdump",          ["type"]="string"},
      ["keyrom"]           = {["flag"] = "--keyrom",           ["type"]="string"},
      ["patch-table"]      = {["flag"] = "--patch-table",      ["type"]="string"},
      ["readelf"]          = {["flag"] = "--readelf",          ["type"]="string"},
      ["alias"]            = {["flag"] = "--alias",            ["type"]="table", ["table_type"] = "KeyValue"}, -- -> table
      ["define"]           = {["flag"] = "--define",           ["type"]="table", ["table_type"] = "KeyValue"}, -- -> table
      ["include"]          = {["flag"] = "--include",          ["type"]="table", ["table_type"] = "Value"}, -- -> table
      ["sniplib"]          = {["flag"] = "--sniplib",          ["type"]="table", ["table_type"] = "Value"}, -- -> table
      ["openssl-options"]  = {["flag"] = "--openssl-options",  ["type"]="string"},
      ["openssl-exe"]      = {["flag"] = "--openssl-exe",      ["type"]="string"},
      ["openssl-rand-off"] = {["flag"] = "--openssl-rand-off", ["type"]="string"},
    }

    local atArguments = {}

    for strArg, tValArg in pairs(tHbootArguments) do
      if tFlags[strArg] == nil then
        local strMsg = string.format('Error: The argument "%s" is not available.', strArg)
        error(strMsg)
      end

      if tFlags[strArg].type == type(tValArg) and type(tValArg) == "table" then
        if tFlags[strArg].table_type == "KeyValue" then
          for strNAME,strVALUE in pairs(tValArg) do
            atArguments[#atArguments + 1] = tFlags[strArg].flag .. " " .. strNAME .. "=" .. strVALUE
          end
        elseif tFlags[strArg].table_type == "Value" then
          for _,strVALUE in pairs(tValArg) do
            atArguments[#atArguments + 1] = tFlags[strArg].flag .. " " .. strVALUE
          end
        end
      elseif tFlags[strArg].type == type(tValArg) and type(tValArg) == "string" then
        atArguments[#atArguments + 1] = tFlags[strArg].flag .. " " .. tValArg
      else
        local strMsg = string.format('Error: The argument "%s" has the wrong type.', strArg)
        error(strMsg)
      end

    end

    local tCMD =
    {
      INTERPRETER_HBOOT = self.atVars["DefaultSettings"].INTERPRETER_HBOOT,
      PATH_HBOOT = self.atVars["DefaultSettings"].PATH_HBOOT,
      FLAGS = table.concat(atArguments," "),
      HBOOT_DEFINITION = strHbootDefinition,
      TARGET = strTarget,
    }

    local strCMD_TEMPLATE = "${INTERPRETER_HBOOT} ${PATH_HBOOT} ${FLAGS} ${HBOOT_DEFINITION} ${TARGET}"
    local strCMD = tLpeg_Support.Gsub(strCMD_TEMPLATE,tCMD)

    AddJob(
      strTarget,
      string.format("HBootImage : %s",strTarget),
      strCMD
    )

    AddDependency(strTarget, strPathElf) -- neccessary

    return strTarget
  end
end