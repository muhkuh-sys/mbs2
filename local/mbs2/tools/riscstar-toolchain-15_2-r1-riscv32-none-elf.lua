local tTool = {
  id = 'riscstar-toolchain-riscv32-none-elf',
  version = '15.2-r1'
}



local atstrTargetFlags = {
  ['NETX9X2_ADA_MPW'] = {
    ccflags = {
      '-mabi=ilp32',
      '-march=rv32imac_zifencei_zicsr_zba_zbb_zbs'
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
  local strToolchainPath = '/home/cthelen/.mbs/depack/com.riscstar/riscv32-none-elf/riscstar-toolchain-15.2-r1-x86_64-riscv32-none-elf'
  local path = require 'pl.path'
  local strToolchainExePrefix = path.join(strToolchainPath, 'bin', 'riscv32-none-elf-')

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
