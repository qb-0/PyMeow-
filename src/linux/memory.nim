import 
  os, tables, strformat, 
  strutils, sequtils, posix,
  regex, nimpy, ../vector

pyExportModule("pymeow")

type
  Process* = object
    name*: string
    pid*: int
    baseAddr*: ByteAddress
    modules*: Table[string, Module]
    debug*: bool

  Module* = object
    baseAddr*: ByteAddress
    moduleSize*: int
    regions*: seq[tuple[s: ByteAddress, e: ByteAddress, size: int]]

proc process_vm_readv(pid: int, local_iov: ptr IOVec, liovcnt: culong, remote_iov: ptr IOVec, riovcnt: culong, flags: culong): cint {.importc, header: "<sys/uio.h>", discardable.}
proc process_vm_writev(pid: int, local_iov: ptr IOVec, liovcnt: culong, remote_iov: ptr IOVec, riovcnt: culong, flags: culong): cint {.importc, header: "<sys/uio.h>", discardable.}

proc getModules(pid: int): Table[string, Module] =
  for l in lines(fmt"/proc/{pid}/maps"):
    let 
      s = l.split()
      name = s[^1].split("/")[^1]
    if name notin result:
      result[name] = Module()
    let hSplit = s[0].split("-")
    if result[name].baseAddr == 0:
      result[name].baseAddr = parseHexInt(hSplit[0])
    result[name].regions.add(
      (
        s: parseHexInt(hSplit[0]), 
        e: parseHexInt(hSplit[1]),
        size: parseHexInt(hSplit[1]) - parseHexInt(hSplit[0]),
      )
    )
    result[name].moduleSize = result[name].regions[^1].e - result[name].baseAddr

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
    echo fmt"[R] [{$type(result)}] 0x{address.toHex()} -> {result}"

proc write*(a: Process, address: ByteAddress, data: auto): int {.discardable.} =
  var
    iosrc, iodst: IOVec
    size = sizeof(data).uint
    d = data

  iosrc.iov_base = d.addr
  iosrc.iov_len = size
  iodst.iov_base = cast[pointer](address)
  iodst.iov_len = size
  process_vm_writev(a.pid, iosrc.addr, 1, iodst.addr, 1, 0)

  if a.debug:
    echo fmt"[W] [{$type(data)}] 0x{address.toHex()} -> {data}"

proc writeArray[T](a: Process, address: ByteAddress, data: openArray[T]): int {.discardable.} =
  var
    iosrc, iodst: IOVec
    size = (sizeof(T) * data.len).uint

  iosrc.iov_base = data.unsafeAddr
  iosrc.iov_len = size
  iodst.iov_base = cast[pointer](address)
  iodst.iov_len = size
  process_vm_writev(a.pid, iosrc.addr, 1, iodst.addr, 1, 0)

proc readString*(a: Process, address: ByteAddress): string {.exportpy: "read_string".} =
  let b = a.read(address, array[0..100, char])
  result = $cast[cstring](b[0].unsafeAddr)

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
    echo fmt"[R] [{$type(result)}] 0x{address.toHex()} -> {result}"

proc processByName*(name: string, debug: bool = false): Process {.exportpy: "process_by_name"} =
  if getuid() != 0:
    raise newException(IOError, "Root required!")

  let allFiles = toSeq(walkDir("/proc", relative = true))
  for pid in mapIt(filterIt(allFiles, isDigit(it.path[0])), parseInt(it.path)):
      let procName = readLines(fmt"/proc/{pid}/status", 1)[0].split()[1]
      if name in procName:
        result.name = procName
        result.pid = pid
        result.modules = getModules(pid)
        result.baseAddr = result.modules[result.name].baseAddr
        return
  raise newException(IOError, fmt"Process not found ({name})")

proc processByPid*(pid: int, debug: bool = false): Process {.exportpy: "process_by_pid".} =
  if getuid() != 0:
    raise newException(IOError, "Root required!")

  try:
    result.name = readLines(fmt"/proc/{pid}/status", 1)[0].split()[1]
    result.pid = pid
    result.modules = getModules(pid)
    result.baseAddr = result.modules[result.name].baseAddr
  except IOError:
    raise newException(IOError, fmt"Pid ({pid}) does not exist")

iterator enumerateProcesses: Process {.exportpy: "enumerate_processes".} =
  if getuid() != 0:
    raise newException(IOError, "Root required!")

  let allFiles = toSeq(walkDir("/proc", relative = true))
  for pid in mapIt(filterIt(allFiles, isDigit(it.path[0])), parseInt(it.path)):
    try:
      var r: Process
      r.name = readLines(fmt"/proc/{pid}/status", 1)[0].split()[1]
      r.pid = pid
      r.modules = getModules(pid)
      r.baseAddr = r.modules[r.name].baseAddr
      yield r
    except:
      continue

proc aobScan*(a: Process, pattern: string, module: Module): ByteAddress {.exportpy: "aob_scan".} =
  var 
    curAddr = module.baseAddr
    rePattern = re(
      pattern.toUpper().multiReplace((" ", ""), ("?", "."), ("*", "."))
    )

  for r in module.regions:
    let byteString = cast[string](a.readSeq(r.s, r.size)).toHex()
    let b = byteString.findAllBounds(rePattern)
    if b.len != 0:
      return b[0].a div 2 + curAddr
    curAddr += r.size

proc nopCode*(a: Process, address: ByteAddress, length: int = 1) {.exportpy: "nop_code".} =
  for i in 0..length-1:
    a.write(address + i, 0x90.byte)

proc pointerChain(a: Process, baseAddr: ByteAddress, offsets: openArray[int]): ByteAddress {.exportpy: "pointer_chain".} =
  result = a.read(baseAddr, ByteAddress)
  for o in offsets:
    result = a.read(result + o, ByteAddress)

proc readInt(a: Process, address: ByteAddress): int32 {.exportpy: "read_int".} = a.read(address, int32)
proc readInts(a: Process, address: ByteAddress, size: int32): seq[int32] {.exportpy: "read_ints".} = a.readSeq(address, size, int32)
proc readInt16(a: Process, address: ByteAddress): int16 {.exportpy: "read_int16".} = a.read(address, int16)
proc readInts16(a: Process, address: ByteAddress, size: int32): seq[int16] {.exportpy: "read_ints16".} = a.readSeq(address, size, int16)
proc readInt64(a: Process, address: ByteAddress): int64 {.exportpy: "read_int64".} = a.read(address, int64)
proc readInts64(a: Process, address: ByteAddress, size: int32): seq[int64] {.exportpy: "read_ints64".} = a.readSeq(address, size, int64)
proc readUInt(a: Process, address: ByteAddress): uint32 {.exportpy: "read_uint".} = a.read(address, uint32)
proc readUInts(a: Process, address: ByteAddress, size: int32): seq[uint32] {.exportpy: "read_uints".} = a.readSeq(address, size, uint32)
proc readUInt64(a: Process, address: ByteAddress): uint64 {.exportpy: "read_uint64".} = a.read(address, uint64)
proc readUInts64(a: Process, address: ByteAddress, size: int32): seq[uint64] {.exportpy: "read_uints64".} = a.readSeq(address, size, uint64)
proc readFloat(a: Process, address: ByteAddress): float32 {.exportpy: "read_float".} = a.read(address, float32)
proc readFloats(a: Process, address: ByteAddress, size: int32): seq[float32] {.exportpy: "read_floats".} = a.readSeq(address, size, float32)
proc readFloat64(a: Process, address: ByteAddress): float64 {.exportpy: "read_float64".} = a.read(address, float64)
proc readFloats64(a: Process, address: ByteAddress, size: int32): seq[float64] {.exportpy: "read_floats64".} = a.readSeq(address, size, float64)
proc readByte(a: Process, address: ByteAddress): byte {.exportpy: "read_byte".} = a.read(address, byte)
proc readBytes(a: Process, address: ByteAddress, size: int32): seq[byte] {.exportpy: "read_bytes".} = a.readSeq(address, size, byte)
proc readVec2(a: Process, address: ByteAddress): Vec2 {.exportpy: "read_vec2".} = a.read(address, Vec2)
proc readVec3(a: Process, address: ByteAddress): Vec3 {.exportpy: "read_vec3".} = a.read(address, Vec3)
proc readBool(a: Process, address: ByteAddress): bool {.exportpy: "read_bool".} = a.read(address, byte).bool

template writeData = a.write(address, data)
template writeDatas = a.writeArray(address, data)
proc writeInt(a: Process, address: ByteAddress, data: int32) {.exportpy: "write_int".} = writeData
proc writeInts(a: Process, address: ByteAddress, data: openArray[int32]) {.exportpy: "write_ints".} = writeDatas
proc writeInt16(a: Process, address: ByteAddress, data: int16) {.exportpy: "write_int16".} = writeData
proc writeInts16(a: Process, address: ByteAddress, data: openArray[int16]) {.exportpy: "write_ints16".} = writeDatas
proc writeInt64(a: Process, address: ByteAddress, data: int64) {.exportpy: "write_int64".} = writeData
proc writeInts64(a: Process, address: ByteAddress, data: openArray[int64]) {.exportpy: "write_ints64".} = writeDatas
proc writeFloat(a: Process, address: ByteAddress, data: float32) {.exportpy: "write_float".} = writeData
proc writeFloats(a: Process, address: ByteAddress, data: openArray[float32]) {.exportpy: "write_floats".} = writeDatas
proc writeByte(a: Process, address: ByteAddress, data: byte) {.exportpy: "write_byte".} = writeData
proc writeBytes(a: Process, address: ByteAddress, data: openArray[byte]) {.exportpy: "write_bytes".} = writeDatas
proc writeVec2(a: Process, address: ByteAddress, data: Vec2) {.exportpy: "write_vec2".} = writeData
proc writeVec3(a: Process, address: ByteAddress, data: Vec3) {.exportpy: "write_vec3".} = writeData
proc writeBool(a: Process, address: ByteAddress, data: bool) {.exportpy: "write_bool".} = a.write(address, data.byte)