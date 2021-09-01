import 
  os, tables, strutils,
  winim, nimpy, regex,
  vector
from strformat import fmt

pyExportModule("pymeow")

type
  Module = object
    baseaddr: ByteAddress
    basesize: int

  Process = object
    name: string
    handle: int
    pid: int32
    baseaddr: ByteAddress
    basesize: int
    modules: Table[string, Module]
    debug: bool

proc pidInfo(pid: int32): Process =
  var 
    snap = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE or TH32CS_SNAPMODULE32, pid)
    me = MODULEENTRY32(dwSize: sizeof(MODULEENTRY32).cint)

  defer: CloseHandle(snap)

  if Module32First(snap, me.addr) == 1:
    result = Process(
      name: nullTerminated($$me.szModule),
      pid: me.th32ProcessID,
      baseaddr: cast[ByteAddress](me.modBaseAddr),
      basesize: me.modBaseSize,
    )

    result.modules[result.name] = Module(
      baseaddr: result.baseaddr,
      basesize: result.basesize,
    )

    while Module32Next(snap, me.addr) != 0:
      var m = Module(
        baseaddr: cast[ByteAddress](me.modBaseAddr),
        basesize: me.modBaseSize,
      )
      result.modules[nullTerminated($$me.szModule)] = m

proc process_by_pid(pid: int32, debug: bool = false): Process {.exportpy.} =
  result = pidInfo(pid)
  result.handle = OpenProcess(PROCESS_ALL_ACCESS, 0, pid).int32
  result.debug = debug
  if result.handle == 0:
    raise newException(Exception, fmt"Unable to open Process [Pid: {pid}] [Error code: {GetLastError()}]")

proc process_by_name(name: string, debug: bool = false): Process {.exportpy.} =
  var 
    pidArray = newSeq[int32](2048)
    read: int32

  assert EnumProcesses(pidArray[0].addr, 2048, read.addr) != FALSE

  for i in 0..<read div 4:
    var p = pidInfo(pidArray[i])
    if p.pid != 0 and name == p.name:
      p.handle = OpenProcess(PROCESS_ALL_ACCESS, 0, p.pid).int32
      p.debug = debug
      if p.handle != 0:
        return p
      raise newException(Exception, fmt"Unable to open Process [Pid: {p.pid}] [Error code: {GetLastError()}]")
      
  raise newException(Exception, fmt"Process '{name}' not found")

iterator enumerate_processes: Process {.exportpy.} =
  var 
    pidArray = newSeq[int32](2048)
    read: int32

  assert EnumProcesses(pidArray[0].addr, 2048, read.addr) != FALSE

  for i in 0..<read div 4:
    var p = pidInfo(pidArray[i])
    if p.pid != 0: 
      yield p

proc wait_for_process(name: string, interval: int = 1500, debug: bool = false): Process {.exportpy.} =
  while true:
    try:
      return process_by_name(name, debug)
    except:
      sleep(interval)

proc close(a: Process): bool {.discardable, exportpy.} = 
  CloseHandle(a.handle) == 1

proc memoryErr(m: string, a: ByteAddress) {.inline.} =
  raise newException(
    AccessViolationDefect,
    fmt"{m} failed [Address: 0x{a.toHex()}] [Error: {GetLastError()}]"
  )

proc read(self: Process, address: ByteAddress, t: typedesc): t =
  if ReadProcessMemory(
    self.handle, cast[pointer](address), result.addr, sizeof(t), nil
  ) == 0:
    memoryErr("Read", address)

  if self.debug:
    echo fmt"[R] [{$type(result)}] 0x{address.toHex()} -> {result}"


proc write(self: Process, address: ByteAddress, data: any) =
  if WriteProcessMemory(
    self.handle, cast[pointer](address), data.unsafeAddr, sizeof(data), nil
  ) == 0:
    memoryErr("Write", address)
  
  if self.debug:
    echo fmt"[W] [{$type(data)}] 0x{address.toHex()} -> {data}"

proc writeArray[T](self: Process, address: ByteAddress, data: openArray[T]) =
  if WriteProcessMemory(
    self.handle, cast[pointer](address), data.unsafeAddr, sizeof(T) * data.len, nil
  ) == 0:
    memoryErr("Write", address)

proc pointer_chain(a: Process, baseAddr: ByteAddress, offsets: openArray[int]): ByteAddress {.exportpy.} =
  result = a.read(baseAddr, ByteAddress)
  for o in offsets:
    result = a.read(result + o, ByteAddress)

proc readSeq(a: Process, address: ByteAddress, size: SIZE_T,  t: typedesc = byte): seq[t] =
  result = newSeq[t](size)
  if ReadProcessMemory(
    a.handle, cast[pointer](address), result[0].addr, size * sizeof(t), nil
  ) == 0:
    memoryErr("readSeq", address)

proc aob_scan(a: Process, pattern: string, module: Module = Module()): ByteAddress {.exportpy.} =
  var 
    scanBegin, scanEnd: int
    rePattern = re(
      pattern.toUpper().multiReplace((" ", ""), ("??", "?"), ("?", ".."), ("*", ".."))
    )

  if module.baseaddr != 0:
    scanBegin = module.baseaddr
    scanEnd = module.baseaddr + module.basesize
  else:
    var sysInfo = SYSTEM_INFO()
    GetSystemInfo(sysInfo.addr)
    scanBegin = cast[int](sysInfo.lpMinimumApplicationAddress)
    scanEnd = cast[int](sysInfo.lpMaximumApplicationAddress)

  var mbi = MEMORY_BASIC_INFORMATION()
  VirtualQueryEx(a.handle, cast[LPCVOID](scanBegin), mbi.addr, cast[SIZE_T](sizeof(mbi)))

  var curAddr = scanBegin
  while curAddr < scanEnd:
    curAddr += mbi.RegionSize.int
    VirtualQueryEx(a.handle, cast[LPCVOID](curAddr), mbi.addr, cast[SIZE_T](sizeof(mbi)))

    if mbi.State != MEM_COMMIT or mbi.State == PAGE_NOACCESS: continue

    var oldProt: int32
    VirtualProtectEx(a.handle, cast[LPCVOID](curAddr), mbi.RegionSize, PAGE_EXECUTE_READWRITE, oldProt.addr)
    let byteString = cast[string](a.readSeq(cast[ByteAddress](mbi.BaseAddress), mbi.RegionSize)).toHex()
    VirtualProtectEx(a.handle, cast[LPCVOID](curAddr), mbi.RegionSize, oldProt, nil)

    let r = byteString.findAllBounds(rePattern)
    if r.len != 0:
      return r[0].a div 2 + curAddr

proc nop_code(a: Process, address: ByteAddress, length: int = 1) {.exportpy.} =
  var oldProt: int32
  discard VirtualProtectEx(a.handle, cast[LPCVOID](address), length, 0x40, oldProt.addr)
  for i in 0..length-1:
    a.write(address + i, 0x90.byte)
  discard VirtualProtectEx(a.handle, cast[LPCVOID](address), length, oldProt, nil)

proc patch_bytes(a: Process, address: ByteAddress, data: openArray[byte]) {.exportpy.} =
  var oldProt: int32
  discard VirtualProtectEx(a.handle, cast[LPCVOID](address), data.len, 0x40, oldProt.addr)
  for i, b in data:
    a.write(address + i, b)
  discard VirtualProtectEx(a.handle, cast[LPCVOID](address), data.len, oldProt, nil)

proc inject_dll(a: Process, dllPath: string) {.exportpy.} =
  let vPtr = VirtualAllocEx(a.handle, nil, dllPath.len(), MEM_RESERVE or MEM_COMMIT, PAGE_EXECUTE_READWRITE)
  WriteProcessMemory(a.handle, vPtr, dllPath[0].unsafeAddr, dllPath.len, nil)
  if CreateRemoteThread(a.handle, nil, 0, cast[LPTHREAD_START_ROUTINE](LoadLibraryA), vPtr, 0, nil) == 0:
    raise newException(Exception, fmt"Injection failed [Error: {GetLastError()}]")

proc page_protection(a: Process, address: ByteAddress, newProtection: int32 = 0x40): int32 {.exportpy.} =
  var mbi = MEMORY_BASIC_INFORMATION()
  discard VirtualQueryEx(a.handle, cast[LPCVOID](address), mbi.addr, cast[SIZE_T](sizeof(mbi)))
  discard VirtualProtectEx(a.handle, cast[LPCVOID](address), mbi.RegionSize, newProtection, result.addr)

proc read_string(a: Process, address: ByteAddress): string {.exportpy.} =
  let r = a.read(address, array[0..100, char])
  $cast[cstring](r[0].unsafeAddr)
proc read_int(a: Process, address: ByteAddress): int32 {.exportpy.} = a.read(address, int32)
proc read_ints(a: Process, address: ByteAddress, size: int32): seq[int32] {.exportpy.} = a.readSeq(address, size, int32)
proc read_int16(a: Process, address: ByteAddress): int16 {.exportpy.} = a.read(address, int16)
proc read_ints16(a: Process, address: ByteAddress, size: int32): seq[int16] {.exportpy.} = a.readSeq(address, size, int16)
proc read_int64(a: Process, address: ByteAddress): int64 {.exportpy.} = a.read(address, int64)
proc read_ints64(a: Process, address: ByteAddress, size: int32): seq[int64] {.exportpy.} = a.readSeq(address, size, int64)
proc read_uint(a: Process, address: ByteAddress): uint32 {.exportpy.} = a.read(address, uint32)
proc read_uints(a: Process, address: ByteAddress, size: int32): seq[uint32] {.exportpy.} = a.readSeq(address, size, uint32)
proc read_float(a: Process, address: ByteAddress): float32 {.exportpy.} = a.read(address, float32)
proc read_floats(a: Process, address: ByteAddress, size: int32): seq[float32] {.exportpy.} = a.readSeq(address, size, float32)
proc read_float64(a: Process, address: ByteAddress): float64 {.exportpy.} = a.read(address, float64)
proc read_floats64(a: Process, address: ByteAddress, size: int32): seq[float64] {.exportpy.} = a.readSeq(address, size, float64)
proc read_byte(a: Process, address: ByteAddress): byte {.exportpy.} = a.read(address, byte)
proc read_bytes(a: Process, address: ByteAddress, size: int32): seq[byte] {.exportpy.} = a.readSeq(address, size, byte)
proc read_vec2(a: Process, address: ByteAddress): Vec2 {.exportpy.} = a.read(address, Vec2)
proc read_vec3(a: Process, address: ByteAddress): Vec3 {.exportpy.} = a.read(address, Vec3)
proc read_bool(a: Process, address: ByteAddress): bool {.exportpy.} = a.read(address, byte).bool

template write_data = a.write(address, data)
template write_datas = a.writeArray(address, data)
proc write_int(a: Process, address: ByteAddress, data: int32) {.exportpy.} = write_data
proc write_ints(a: Process, address: ByteAddress, data: openArray[int32]) {.exportpy.} = write_datas
proc write_int16(a: Process, address: ByteAddress, data: int16) {.exportpy.} = write_data
proc write_ints16(a: Process, address: ByteAddress, data: openArray[int16]) {.exportpy.} = write_datas
proc write_int64(a: Process, address: ByteAddress, data: int64) {.exportpy.} = write_data
proc write_ints64(a: Process, address: ByteAddress, data: openArray[int64]) {.exportpy.} = write_datas
proc write_float(a: Process, address: ByteAddress, data: float32) {.exportpy.} = write_data
proc write_floats(a: Process, address: ByteAddress, data: openArray[float32]) {.exportpy.} = write_datas
proc write_byte(a: Process, address: ByteAddress, data: byte) {.exportpy.} = write_data
proc write_bytes(a: Process, address: ByteAddress, data: openArray[byte]) {.exportpy.} = write_datas
proc write_vec2(a: Process, address: ByteAddress, data: Vec2) {.exportpy.} = write_data
proc write_vec3(a: Process, address: ByteAddress, data: Vec3) {.exportpy.} = write_data
proc write_bool(a: Process, address: ByteAddress, data: bool) {.exportpy.} = a.write(address, data.byte)