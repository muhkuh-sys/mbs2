local cGccToolchainBase = {}


function cGccToolchainBase:applyStandardGcc(tEnv, tCfg)
  local strAsicTyp = tCfg.asic_typ
  tEnv.cc.defines:Add('ASIC_TYP=ASIC_TYP_' .. strAsicTyp)

  local strToolchainExePrefix = tCfg.toolchain_exe_prefix
  tEnv.cc.exe_c = strToolchainExePrefix .. 'gcc'
  tEnv.cc.exe_cxx = strToolchainExePrefix .. 'g++'
  tEnv.dll.exe = strToolchainExePrefix .. 'gcc'
  tEnv.lib.exe = strToolchainExePrefix .. 'ar'
  tEnv.link.exe = strToolchainExePrefix .. 'gcc'

  local astrCCFlags = {
    '-ffreestanding',

    '-fdata-sections',
    '-ffunction-sections',

    '-mlong-calls',
    '-Wall',
    '-Wextra',
    '-Wconversion',
    '-Wshadow',
    '-Wcast-qual',
    '-Wwrite-strings',
    '-Wcast-align',
    '-Wpointer-arith',
    '-Wmissing-prototypes',
    '-Wstrict-prototypes',
    '-g3',
    '-gdwarf-2',
    '-pedantic'
  }
  tEnv.cc.flags:Merge(astrCCFlags)

  local astrTargetFlags = tCfg.target_flags
  tEnv.cc.flags:Merge(astrTargetFlags)
  tEnv.link.flags:Merge(astrTargetFlags)

  local astrLdPassFlags = {
    '--gc-sections',
    '--no-undefined',
    '-static'
  }
  local strPassLdPrefix = '-Wl,'
  for _, strLdFlag in ipairs(astrLdPassFlags) do
    tEnv.link.flags:Add(strPassLdPrefix .. strLdFlag)
  end
  local astrLdFlags = {
    '-nostdlib',
    '-nostartfiles'
  }
  tEnv.link.flags:Merge(astrLdFlags)

  tEnv.link.libs:Merge{'m', 'c', 'gcc'}
  tEnv.link.extension = '.elf'


  -- Set the name and architecture of the platforms binary format.
  -- Both settings are needed to import binary files to objects with the "objcopy" tool.
  local tMbs = tEnv.mbs
  tMbs.GCC_BFDNAME = tCfg.bfdname
  tMbs.GCC_BFDARCH = tCfg.bfdarch

  -- Set the complete path of the tools which are used in builders.
  tMbs.GCC_GCC = strToolchainExePrefix .. 'gcc'
  tMbs.GCC_GPP = strToolchainExePrefix .. 'g++'
  tMbs.GCC_AR = strToolchainExePrefix .. 'ar'
  tMbs.GCC_AS = strToolchainExePrefix .. 'as'
  tMbs.GCC_LD = strToolchainExePrefix .. 'ld'
  tMbs.GCC_OBJCOPY = strToolchainExePrefix .. 'objcopy'
  tMbs.GCC_OBJDUMP = strToolchainExePrefix .. 'objdump'
  tMbs.GCC_READELF = strToolchainExePrefix .. 'readelf'
end


return cGccToolchainBase
