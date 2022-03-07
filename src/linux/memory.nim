import 
  os, tables, strformat, 
  strutils, sequtils, posix,
  regex, nimpy

pyExportModule("pymeow")

type
  Process* = object
    name*: string
    pid*: Pid
    baseaddr*: ByteAddress
    modules*: Table[string, Module]
    debug*: bool

  Module* = object
    baseaddr*: ByteAddress
    moduleSize*: int
    regions*: seq[tuple[start: ByteAddress, `end`: ByteAddress, size: int, readable: bool]]

proc process_vm_readv(
  pid: Pid, 
  local_iov: ptr IOVec, 
  liovcnt: culong, 
  remote_iov: ptr IOVec, 
  riovcnt: culong, 
  flags: culong
): cint {.importc, header: "<sys/uio.h>", discardable.}

proc process_vm_writev(
  pid: Pid, 
  local_iov: ptr IOVec, 
  liovcnt: culong, 
  remote_iov: ptr IOVec, 
  riovcnt: culong, 
  flags: culong
): cint {.importc, header: "<sys/uio.h>", discardable.}

proc getModules(pid: Pid): Table[string, Module] =
  for l in lines(fmt"/proc/{pid}/maps"):
    let 
      s = l.split()
      name = s[^1].split("/")[^1]
    if name notin result:
      result[name] = Module()
    let hSplit = s[0].split("-")
    if result[name].baseaddr == 0:
      result[name].baseaddr = parseHexInt(hSplit[0])
    result[name].regions.add(
      (
        start: parseHexInt(hSplit[0]), 
        `end`: parseHexInt(hSplit[1]),
        size: parseHexInt(hSplit[1]) - parseHexInt(hSplit[0]),
        readable: "r" in s[1]
      )
    )
    result[name].moduleSize = result[name].regions[^1].`end` - result[name].baseaddr

proc processByPid(pid: Pid, debug: bool = false): Process {.exportpy: "process_by_pid".} =
  if getuid() != 0:
    raise newException(IOError, "Root required!")

  try:
    result.name = readLines(fmt"/proc/{pid}/status", 1)[0].split()[1]
    result.pid = pid
    result.modules = getModules(pid)
    result.baseaddr = result.modules[result.name].baseaddr
    result.debug = debug
  except IOError:
    raise newException(IOError, fmt"Pid ({pid}) does not exist")

proc processByName(name: string, debug: bool = false): Process {.exportpy: "process_by_name"} =
  if getuid() != 0:
    raise newException(IOError, "Root required!")

  let allFiles = toSeq(walkDir("/proc", relative = true))
  for pid in mapIt(filterIt(allFiles, isDigit(it.path[0])), parseInt(it.path)):
      let procName = readLines(fmt"/proc/{pid}/status", 1)[0].split()[1]
      if name in procName:
        result.name = procName
        result.pid = pid.Pid
        result.modules = getModules(pid.Pid)
        result.baseaddr = result.modules[result.name].baseaddr
        result.debug = debug
        return
  raise newException(IOError, fmt"Process not found ({name})")

proc kill(a: Process): bool {.exportpy.} =
  kill(a.pid, 9) == 0

iterator enumerateProcesses: Process {.exportpy: "enumerate_processes".} =
  if getuid() != 0:
    raise newException(IOError, "Root required!")

  let allFiles = toSeq(walkDir("/proc", relative = true))
  for pid in mapIt(filterIt(allFiles, isDigit(it.path[0])), parseInt(it.path)):
    try:
      var r: Process
      r.name = readLines(fmt"/proc/{pid}/status", 1)[0].split()[1]
      r.pid = pid.Pid
      r.modules = getModules(pid.Pid)
      r.baseaddr = r.modules[r.name].baseaddr
      yield r
    except:
      continue

proc read*(a: Process, address: ByteAddress, t: typedesc): t =
  var
    iosrc, iodst: IOVec
    size = sizeof(t).uint

  iodst.iov_base = result.addr
  iodst.iov_len = size
  iosrc.iov_base = cast[pointer](address)
  iosrc.iov_len = size
  discard process_vm_readv(a.pid, iodst.addr, 1, iosrc.addr, 1, 0)
  if a.debug:
    echo "[R] [", type(result), "] 0x", address.toHex(), " -> ", result

proc write*(a: Process, address: ByteAddress, data: auto) =
  var
    iosrc, iodst: IOVec
    size = sizeof(data).uint
    d = data

  iosrc.iov_base = d.addr
  iosrc.iov_len = size
  iodst.iov_base = cast[pointer](address)
  iodst.iov_len = size
  discard process_vm_writev(a.pid, iosrc.addr, 1, iodst.addr, 1, 0)
  if a.debug:
    echo "[W] [", type(data), "] 0x", address.toHex(), " -> ", data

proc writeArray*[T](a: Process, address: ByteAddress, data: openArray[T]): int {.discardable.} =
  var
    iosrc, iodst: IOVec
    size = (sizeof(T) * data.len).uint

  iosrc.iov_base = data.unsafeAddr
  iosrc.iov_len = size
  iodst.iov_base = cast[pointer](address)
  iodst.iov_len = size
  process_vm_writev(a.pid, iosrc.addr, 1, iodst.addr, 1, 0)

proc readSeq*(a: Process, address: ByteAddress, size: int, t: typedesc = byte): seq[t] =
  result = newSeq[t](size)
  var 
    iosrc, iodst: IOVec
    bsize = (size * sizeof(t)).uint

  iodst.iov_base = result[0].addr
  iodst.iov_len = bsize
  iosrc.iov_base = cast[pointer](address)
  iosrc.iov_len = bsize
  process_vm_readv(a.pid, iodst.addr, 1, iosrc.addr, 1, 0)
  if a.debug:
    echo "[R] [", type(result), "] 0x", address.toHex(), " -> ", result

proc aobScan*(a: Process, pattern: string, module: Module): ByteAddress {.exportpy: "aob_scan".} =
  var 
    curAddr = module.baseaddr
    rePattern = re(
      pattern.toUpper().multiReplace((" ", ""), ("?", "."), ("*", "."))
    )

  for r in module.regions:
    if not r.readable:
      curAddr += r.size
      continue
    let byteString = cast[string](a.readSeq(r.start, r.size)).toHex()
    let b = byteString.findAllBounds(rePattern)
    if b.len != 0:
      return b[0].a div 2 + curAddr
    curAddr += r.size

proc nopCode*(a: Process, address: ByteAddress, length: int = 1) {.exportpy: "nop_code".} =
  for i in 0..length-1:
    a.write(address + i, 0x90.byte)
