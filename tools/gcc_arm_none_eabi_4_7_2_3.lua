-- Provide Penlight as an upvalue to all functions.
local pl = require'pl.import_into'()


---------------------------------------------------------------------------------------------------------------------
--
-- Local setup compiler functions
--

---
local function setup_compiler_common(tEnv)
  local strToolchainPath = pl.path.abspath(pl.path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3'))
  local strGccPlatform = 'arm-none-eabi'
  -- Set the compiler executables.
  tEnv.tEnvDefaultSettings.cc.exe_c = pl.path.join(strToolchainPath, 'bin', strGccPlatform..'-gcc')
  tEnv.tEnvDefaultSettings.cc.exe_cxx = pl.path.join(strToolchainPath, 'bin', strGccPlatform..'-g++')
  tEnv.tEnvDefaultSettings.lib.exe = pl.path.join(strToolchainPath, 'bin', strGccPlatform..'-ar')
  tEnv.tEnvDefaultSettings.link.exe = pl.path.join(strToolchainPath, 'bin', strGccPlatform..'-ld')

  -- These are the defines for the compiler.
  tEnv.tEnvDefaultSettings.cc.flags:Merge {
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
  tEnv.tEnvDefaultSettings.cc.flags:Merge(atBuildTypeFlags)

  tEnv.tEnvDefaultSettings.link.libs = {
    'm',
    'c',
    'gcc'
  }

  tEnv.tEnvDefaultSettings.link.flags:Merge{
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


---
local function setup_compiler_NETX500(tEnv)
  local path = pl.path

  setup_compiler_common(tEnv)

  tEnv.tEnvDefaultSettings.cc.flags:Merge {
    '-march=armv5te',
  }

  tEnv.tEnvDefaultSettings.link.libpath = {
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3/arm-none-eabi/lib/v5te/')),
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3/lib/gcc/arm-none-eabi/4.7.2/v5te/'))
  }
end


---
local function setup_compiler_NETX50(tEnv)
  local path = pl.path

  setup_compiler_common(tEnv)

  -- These are the defines for the compiler.
  -- TODO: move this somewhere else, e.g. compiler package.
  tEnv.tEnvDefaultSettings.cc.flags:Merge {
    '-march=armv5te'
  }

  tEnv.tEnvDefaultSettings.link.libpath = {
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3/arm-none-eabi/lib/v5te/')),
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3/lib/gcc/arm-none-eabi/4.7.2/v5te/'))
  }
end


---
local function setup_compiler_NETX56(tEnv)
  local path = pl.path

  setup_compiler_common(tEnv)

  -- These are the defines for the compiler.
  -- TODO: move this somewhere else, e.g. compiler package.
  tEnv.tEnvDefaultSettings.cc.flags:Merge {
    '-march=armv5te'
  }

  tEnv.tEnvDefaultSettings.link.libpath = {
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3/arm-none-eabi/lib/v5te/')),
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3/lib/gcc/arm-none-eabi/4.7.2/v5te/'))
  }
end


---
local function setup_compiler_NETX10(tEnv)
  local path = pl.path

  setup_compiler_common(tEnv)

  -- These are the defines for the compiler.
  -- TODO: move this somewhere else, e.g. compiler package.
  tEnv.tEnvDefaultSettings.cc.flags:Merge {
    '-march=armv5te'
  }

  tEnv.tEnvDefaultSettings.link.libpath = {
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3/arm-none-eabi/lib/v5te/')),
    path.abspath(path.expanduser('~/.mbs/depack/org.gnu.gcc/gcc-arm-none-eabi/gcc-arm-none-eabi-4.7.2_3/lib/gcc/arm-none-eabi/4.7.2/v5te/'))
  }
end


---------------------------------------------------------------------------------------------------------------------
--
-- setup compiler object functions
--


-- Create the Setup_Compiler class.
local class = pl.class
local Setup_Compiler = class()

function Setup_Compiler:_init(tEnv)
  tEnv.atRegisteredCompiler['NETX500'] = setup_compiler_NETX500
  tEnv.atRegisteredCompiler['NETX50'] = setup_compiler_NETX50
  tEnv.atRegisteredCompiler['NETX56'] = setup_compiler_NETX56
  tEnv.atRegisteredCompiler['NETX10'] = setup_compiler_NETX10
end


return Setup_Compiler


