import 
  os, tables, strutils,
  winim, nimpy, regex
from strformat import fmt

pyExportModule("pymeow")

type
  Module* = object
    baseaddr: ByteAddress
    basesize: int

  Process* = object
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

    while Module32Next(snap, me.addr) != FALSE:
      var m = Module(
        baseaddr: cast[ByteAddress](me.modBaseAddr),
        basesize: me.modBaseSize,
      )
      result.modules[nullTerminated($$me.szModule)] = m

proc processByPid(pid: int32, debug: bool = false, rights: int32 = 0x1F0FFF): Process {.exportpy: "process_by_pid".} =
  result = pidInfo(pid)
  result.handle = OpenProcess(rights, 1, pid).int32
  result.debug = debug
  if result.handle == FALSE:
    raise newException(Exception, fmt"Unable to open Process [Pid: {pid}] [Error code: {GetLastError()}]")

proc processByName(name: string, debug: bool = false, rights: int32 = 0x1F0FFF): Process {.exportpy: "process_by_name".} =
  var
    pidArray = newSeq[int32](2048)
    read: int32

  assert EnumProcesses(pidArray[0].addr, 2048, read.addr) != FALSE

  for i in 0..<read div 4:
    var p = pidInfo(pidArray[i])
    if p.pid != 0 and name == p.name:
      p.handle = OpenProcess(rights, 1, p.pid).int32
      p.debug = debug
      if p.handle != 0:
        return p
      raise newException(Exception, fmt"Unable to open Process [Pid: {p.pid}] [Error code: {GetLastError()}]")
      
  raise newException(Exception, fmt"Process '{name}' not found")

iterator enumerateProcesses: Process {.exportpy: "enumerate_processes".} =
  var 
    pidArray = newSeq[int32](2048)
    read: int32

  assert EnumProcesses(pidArray[0].addr, 2048, read.addr) != FALSE

  for i in 0..<read div 4:
    var p = pidInfo(pidArray[i])
    if p.pid != 0:
      yield p

proc close(a: Process): bool {.exportpy.} = 
  CloseHandle(a.handle) == TRUE

proc memoryErr(m: string, a: ByteAddress) {.inline.} =
  raise newException(
    AccessViolationDefect,
    fmt"{m} failed [Address: 0x{a.toHex()}] [Error: {GetLastError()}]"
  )

proc read*(a: Process, address: ByteAddress, t: typedesc): t =
  if ReadProcessMemory(
    a.handle, cast[pointer](address), result.addr, sizeof(t), nil
  ) == FALSE:
    memoryErr("Read", address)
  if a.debug:
    echo "[R] [", type(result), "] 0x", address.toHex(), " -> ", result

proc write*(a: Process, address: ByteAddress, data: auto) =
  if WriteProcessMemory(
    a.handle, cast[pointer](address), data.unsafeAddr, sizeof(data), nil
  ) == FALSE:
    memoryErr("Write", address)
  if a.debug:
    echo "[W] [", type(data), "] 0x", address.toHex(), " -> ", data

proc writeArray*[T](a: Process, address: ByteAddress, data: openArray[T]) =
  if WriteProcessMemory(
    a.handle, cast[pointer](address), data.unsafeAddr, sizeof(T) * data.len, nil
  ) == FALSE:
    memoryErr("Write", address)

proc readSeq*(a: Process, address: ByteAddress, size: SIZE_T,  t: typedesc = byte): seq[t] =
  result = newSeq[t](size)
  if ReadProcessMemory(
    a.handle, cast[pointer](address), result[0].addr, size * sizeof(t), nil
  ) == FALSE:
    memoryErr("readSeq", address)
  if a.debug:
    echo "[R] [", type(result), "] 0x", address.toHex(), " -> ", result

proc aobScan(a: Process, pattern: string, module: Module = Module()): ByteAddress {.exportpy: "aob_scan".} =
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

proc nopCode(a: Process, address: ByteAddress, length: int = 1) {.exportpy: "nop_code".} =
  var oldProt: int32
  discard VirtualProtectEx(a.handle, cast[LPCVOID](address), length, 0x40, oldProt.addr)
  for i in 0..length-1:
    a.write(address + i, 0x90.byte)
  discard VirtualProtectEx(a.handle, cast[LPCVOID](address), length, oldProt, nil)

proc patchBytes(a: Process, address: ByteAddress, data: openArray[byte]) {.exportpy: "patch_bytes".} =
  var oldProt: int32
  discard VirtualProtectEx(a.handle, cast[LPCVOID](address), data.len, 0x40, oldProt.addr)
  for i, b in data:
    a.write(address + i, b)
  discard VirtualProtectEx(a.handle, cast[LPCVOID](address), data.len, oldProt, nil)

proc injectLibrary(a: Process, dllPath: string) {.exportpy: "inject_library".} =
  let vPtr = VirtualAllocEx(a.handle, nil, dllPath.len(), MEM_RESERVE or MEM_COMMIT, PAGE_EXECUTE_READWRITE)
  WriteProcessMemory(a.handle, vPtr, dllPath[0].unsafeAddr, dllPath.len, nil)
  if CreateRemoteThread(a.handle, nil, 0, cast[LPTHREAD_START_ROUTINE](LoadLibraryA), vPtr, 0, nil) == FALSE:
    raise newException(Exception, fmt"Injection failed [Error: {GetLastError()}]")

proc pageProtection(a: Process, address: ByteAddress, newProtection: int32 = 0x40): int32 {.exportpy: "page_protection".} =
  var mbi = MEMORY_BASIC_INFORMATION()
  discard VirtualQueryEx(a.handle, cast[LPCVOID](address), mbi.addr, cast[SIZE_T](sizeof(mbi)))
  discard VirtualProtectEx(a.handle, cast[LPCVOID](address), mbi.RegionSize, newProtection, result.addr)
