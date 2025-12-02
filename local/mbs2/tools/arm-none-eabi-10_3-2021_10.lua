local tTool = {
  id = 'gcc-arm-none-eabi',
  version = '10.3-2021.10'
}



local atstrTargetFlags = {
  ['NETX90'] = {
    ccflags = {
      '-mcpu=cortex-m4',
      '-mthumb'
    },
    -- Use the ccflags also for the linker.
    ldflags = nil
  },

  ['NETX9X2_COM_MPW'] = {
    ccflags = {
      '-mcpu=cortex-a32',
      '-mthumb',
      -- Do not build code with unaligned accesses. They result in an exception.
      '-mno-unaligned-access'
    },
    -- Do not use the special v8-a libraries, as it uses unaligned accesses.
    ldflags = {
      '-mthumb',
      '-mno-unaligned-access'
    }
  },

  ['NETX9X2_SECENC_MPW'] = {
    ccflags = {
      '-mcpu=cortex-m0plus',
      '-mthumb'
    },
    -- Use the ccflags also for the linker.
    ldflags = nil
  }
}



function tTool:applyToEnv(tEnv, tCfg)
  -- The configuration must have an "asic_typ" attribute.
  local strAsicTyp
  if type(tCfg)=='table' and type(tCfg.asic_typ)=='string' then
    strAsicTyp = tCfg.asic_typ
  else
    error('No "asic_typ" found in the configuration.')
  end
  local atTargetFlags = atstrTargetFlags[strAsicTyp]
  if atTargetFlags==nil then
    error('Unsupported ASIC typ: ' .. strAsicTyp)
  end

  -- FIXME: Get this from somewhere else.
  local strToolchainBasePath = '/home/cthelen/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi'
  local path = require 'pl.path'
  local strToolchainPath = path.join(
    strToolchainBasePath,
    self.id .. '-' .. self.version
  )
  local strToolchainExePrefix = path.join(strToolchainPath, 'bin', 'arm-none-eabi-')

  local atToolchainCfg = {
    tool_attributes = self,
    asic_typ = strAsicTyp,
    bfdname = 'elf32-littlearm',
    bfdarch = 'ARM',
    toolchain_exe_prefix = strToolchainExePrefix,
    target_flags = atTargetFlags
  }
  local tGccToolchainBase = require 'mbs2.tools.gcc-toolchain-base'
  tGccToolchainBase:applyStandardGcc(tEnv, atToolchainCfg)

  -- Add special settings for this compiler.
  -- Set the standard to C17 to get static assertions.
  tEnv.cc.flags:Add('-std=c17')

  return true
end


return tTool
