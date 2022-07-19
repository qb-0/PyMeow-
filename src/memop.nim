import nimpy, vector

when defined(windows):
  import windows/memory
when defined(linux):
  import linux/memory

pyExportModule("pymeow")

proc pointerChain(a: Process, baseAddr: ByteAddress, offsets: openArray[int], size: int = 8): ByteAddress {.exportpy: "pointer_chain".} =
  result = if size == 8: a.read(baseAddr, ByteAddress) else: a.read(baseAddr, int32) 
  for o in offsets[0..^2]:
    result = if size == 8: a.read(result + o, ByteAddress) else: a.read(baseAddr, int32)
  result = result + offsets[^1]

proc readString(a: Process, address: ByteAddress, size: int = 30): string {.exportpy: "read_string".} =
  let s = a.readSeq(address, size, char)
  $cast[cstring](s[0].unsafeAddr)

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

proc writeString(a: Process, address: ByteAddress, data: string) {.exportpy: "write_string".} =
  a.writeArray(address, data.cstring.toOpenArrayByte(0, data.high))

template writeData = a.write(address, data)
template writeDatas = a.writeArray(address, data)
proc writeInt(a: Process, address: ByteAddress, data: int32) {.exportpy: "write_int".} = writeData
proc writeInts(a: Process, address: ByteAddress, data: openArray[int32]) {.exportpy: "write_ints".} = writeDatas
proc writeInt16(a: Process, address: ByteAddress, data: int16) {.exportpy: "write_int16".} = writeData
proc writeInts16(a: Process, address: ByteAddress, data: openArray[int16]) {.exportpy: "write_ints16".} = writeDatas
proc writeInt64(a: Process, address: ByteAddress, data: int64) {.exportpy: "write_int64".} = writeData
proc writeInts64(a: Process, address: ByteAddress, data: openArray[int64]) {.exportpy: "write_ints64".} = writeDatas
proc writeUInt(a: Process, address: ByteAddress, data: uint32) {.exportpy: "write_uint".} = writeData
proc writeUInts(a: Process, address: ByteAddress, data: openArray[uint32]) {.exportpy: "write_uints".} = writeDatas
proc writeUInt64(a: Process, address: ByteAddress, data: uint64) {.exportpy: "write_uint64".} = writeData
proc writeUInts64(a: Process, address: ByteAddress, data: openArray[uint64]) {.exportpy: "write_uints64".} = writeDatas
proc writeFloat(a: Process, address: ByteAddress, data: float32) {.exportpy: "write_float".} = writeData
proc writeFloats(a: Process, address: ByteAddress, data: openArray[float32]) {.exportpy: "write_floats".} = writeDatas
proc writeFloat64(a: Process, address: ByteAddress, data: float64) {.exportpy: "write_float64".} = writeData
proc writeFloats64(a: Process, address: ByteAddress, data: openArray[float64]) {.exportpy: "write_floats64".} = writeDatas
proc writeByte(a: Process, address: ByteAddress, data: byte) {.exportpy: "write_byte".} = writeData
proc writeBytes(a: Process, address: ByteAddress, data: openArray[byte]) {.exportpy: "write_bytes".} = writeDatas
proc writeVec2(a: Process, address: ByteAddress, data: Vec2) {.exportpy: "write_vec2".} = writeData
proc writeVec3(a: Process, address: ByteAddress, data: Vec3) {.exportpy: "write_vec3".} = writeData
proc writeBool(a: Process, address: ByteAddress, data: bool) {.exportpy: "write_bool".} = a.write(address, data.byte)
