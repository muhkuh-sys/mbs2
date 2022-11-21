local tEnv, strToolFilePath = ...

local pl = require'pl.import_into'()


local function setup_compiler_common(tEnv)
  local strToolchainPath = pl.path.abspath(pl.path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.9.3_4'))
  local strGccPlatform = 'arm-none-eabi'

  -- Set the compiler executables.
  tEnv.cc.exe_c = pl.path.join(strToolchainPath, 'bin', strGccPlatform..'-gcc')
  tEnv.cc.exe_cxx = pl.path.join(strToolchainPath, 'bin', strGccPlatform..'-g++')
  tEnv.lib.exe = pl.path.join(strToolchainPath, 'bin', strGccPlatform..'-ar')
  tEnv.link.exe = pl.path.join(strToolchainPath, 'bin', strGccPlatform..'-ld')

  -- These are the defines for the compiler.
  tEnv.cc.flags:Merge {
    '-ffreestanding',
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
    '-std=c99',
    '-pedantic'
  }

  local atBuildTypes = {
    ['RELEASE'] = {
      '-O2'
    },
    ['DEBUG'] = {
      '-O0'
    }
  }

  local strBuildType = tEnv.atVars.BUILD_TYPE
  local atBuildTypeFlags = atBuildTypes[strBuildType]
  if atBuildTypeFlags==nil then
    error(string.format(
      'Unknown build type: "%s". Known build types are: %s',
      strBuildType,
      table.concat(pl.tablex.keys(atBuildTypeFlags), ',')
    ))
  end
  tEnv.cc.flags:Merge(atBuildTypeFlags)

  tEnv.link.libs = {
    'm',
    'c',
    'gcc'
  }

  tEnv.link.flags:Merge{
    '--gc-sections',
    '-nostdlib',
    '-static'
  }

  local atVars = tEnv.atVars
  atVars.OBJCOPY = pl.path.join(strToolchainPath, 'bin', strGccPlatform..'-objcopy')
  atVars.OBJCOPY_FLAGS = {'-O', 'binary'}
  atVars.OBJCOPY_CMD = '"$OBJCOPY" $OBJCOPY_FLAGS $SOURCES $TARGET'
  atVars.OBJCOPY_LABEL = 'Objcopy $TARGET'

  atVars.OBJDUMP = pl.path.join(strToolchainPath, 'bin', strGccPlatform..'-objdump')
  atVars.OBJDUMP_FLAGS = {'--all-headers', '--disassemble', '--source',"--wide"}
  atVars.OBJDUMP_CMD = '"$OBJDUMP" $OBJDUMP_FLAGS $SOURCES >$TARGET'
  atVars.OBJDUMP_LABEL = 'Objdump $TARGET'
end


local function setup_compiler_NETX90(tEnv)
  local path = pl.path

  setup_compiler_common(tEnv)

  -- These are the defines for the compiler.
  tEnv.cc.flags:Merge {
    '-march=armv7e-m',
    '-mthumb'
  }

  tEnv.link.libpath = {
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.9.3_4/arm-none-eabi/lib/armv7e-m/')),
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.9.3_4/lib/gcc/arm-none-eabi/4.9.3/armv7e-m/'))
  }
end


local function setup_compiler_NETX4000(tEnv)
  local path = pl.path

  setup_compiler_common(tEnv)

  -- These are the defines for the compiler.
  tEnv.cc.flags:Merge {
    '-march=armv7-r',
    '-mthumb'
  }

  tEnv.link.libpath = {
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.9.3_4/arm-none-eabi/lib/armv7-ar/thumb/')),
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.9.3_4/lib/gcc/arm-none-eabi/4.9.3/armv7-ar/thumb/'))
  }
end


tEnv.atRegisteredCompiler['NETX90'] = setup_compiler_NETX90
tEnv.atRegisteredCompiler['NETX4000'] = setup_compiler_NETX4000
