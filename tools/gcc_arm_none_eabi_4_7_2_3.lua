local tEnv, strToolFilePath = ...

local pl = require'pl.import_into'()

local function setup_compiler_common(tEnv)
  local strToolchainPath = pl.path.abspath(pl.path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3'))
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

  local atVars = tEnv.atVars
  atVars.OBJCOPY = pl.path.join(strToolchainPath, 'bin', strGccPlatform..'-objcopy')
  atVars.OBJCOPY_FLAGS = {'-O', 'binary'}
  atVars.OBJCOPY_CMD = '"$OBJCOPY" $OBJCOPY_FLAGS $SOURCES $TARGET'
  atVars.OBJCOPY_LABEL = 'Objcopy $TARGET'
  function tEnv:ObjDump(tTarget, tInput, ...)
    tEnv:__easyCommand(self, tTarget, tInput, 'OBJDUMP', {...})
  end

  atVars.OBJDUMP = pl.path.join(strToolchainPath, 'bin', strGccPlatform..'-objdump')
  atVars.OBJDUMP_FLAGS = {'--all-headers', '--disassemble', '--source'}
  atVars.OBJDUMP_CMD = '"$OBJDUMP" $OBJDUMP_FLAGS $SOURCES >$TARGET'
  atVars.OBJDUMP_LABEL = 'Objdump $TARGET'
  function tEnv:ObjCopy(tTarget, tInput, ...)
    tEnv:__easyCommand(self, tTarget, tInput, 'OBJCOPY', {...})
  end
end


local function setup_compiler_NETX500(tEnv)
  local path = pl.path

  setup_compiler_common(tEnv)

  tEnv.cc.flags:Merge {
    '-march=armv5te',
  }

  tEnv.link.libpath = {
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3/arm-none-eabi/lib/v5te/')),
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3/lib/gcc/arm-none-eabi/4.7.2/v5te/'))
  }
end


local function setup_compiler_NETX50(tEnv)
  local path = pl.path

  setup_compiler_common(tEnv)

  -- These are the defines for the compiler.
  -- TODO: move this somewhere else, e.g. compiler package.
  tEnv.cc.flags:Merge {
    '-march=armv5te'
  }

  tEnv.link.libpath = {
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3/arm-none-eabi/lib/v5te/')),
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3/lib/gcc/arm-none-eabi/4.7.2/v5te/'))
  }
end


local function setup_compiler_NETX56(tEnv)
  local path = pl.path

  setup_compiler_common(tEnv)

  -- These are the defines for the compiler.
  -- TODO: move this somewhere else, e.g. compiler package.
  tEnv.cc.flags:Merge {
    '-march=armv5te'
  }

  tEnv.link.libpath = {
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3/arm-none-eabi/lib/v5te/')),
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3/lib/gcc/arm-none-eabi/4.7.2/v5te/'))
  }
end


local function setup_compiler_NETX10(tEnv)
  local path = pl.path

  setup_compiler_common(tEnv)

  -- These are the defines for the compiler.
  -- TODO: move this somewhere else, e.g. compiler package.
  tEnv.cc.flags:Merge {
    '-march=armv5te'
  }

  tEnv.link.libpath = {
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3/arm-none-eabi/lib/v5te/')),
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3/lib/gcc/arm-none-eabi/4.7.2/v5te/'))
  }
end


tEnv.atRegisteredCompiler['NETX500'] = setup_compiler_NETX500
tEnv.atRegisteredCompiler['NETX50'] = setup_compiler_NETX50
tEnv.atRegisteredCompiler['NETX56'] = setup_compiler_NETX56
tEnv.atRegisteredCompiler['NETX10'] = setup_compiler_NETX10
