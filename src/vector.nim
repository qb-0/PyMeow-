import nimpy, math

pyExportModule("pymeow")

type
  Vec2* = object
    x*, y*: float32
  Vec3* = object
    x*, y*, z*: float32

proc vec2(x, y: float32 = 0): Vec2 {.exportpy.} =
  result.x = x
  result.y = y
proc vec3(x, y, z: float32 = 0): Vec3 {.exportpy.} =
  result.x = x
  result.y = y
  result.z = z

proc vec2Add(a, b: Vec2): Vec2 {.exportpy: "vec2_add".} =
  result.x = a.x + b.x
  result.y = a.y + b.y
proc vec3Add(a, b: Vec3): Vec3 {.exportpy: "vec3_add".} =
  result.x = a.x + b.x
  result.y = a.y + b.y
  result.z = a.z + b.z

proc vec2Sub(a, b: Vec2): Vec2 {.exportpy: "vec2_sub".} =
  result.x = a.x - b.x
  result.y = a.y - b.y
proc vec3Sub(a, b: Vec3): Vec3 {.exportpy: "vec3_sub".} =
  result.x = a.x - b.x
  result.y = a.y - b.y
  result.z = a.z - b.z

proc vec2Mult(a, b: Vec2): Vec2 {.exportpy: "vec2_mult".} =
  result.x = a.x * b.x
  result.y = a.y * b.y
proc vec3Mult(a, b: Vec3): Vec3 {.exportpy: "vec3_mult".} =
  result.x = a.x * b.x
  result.y = a.y * b.y
  result.z = a.z * b.z

proc vec2Div(a, b: Vec2): Vec2 {.exportpy: "vec2_div".} =
  result.x = a.x / b.x
  result.y = a.y / b.y
proc vec3Div(a, b: Vec3): Vec3 {.exportpy: "vec3_div".} =
  result.x = a.x / b.x
  result.y = a.y / b.y
  result.z = a.z / b.z

proc vec2MagSq(a: Vec2): float32 {.exportpy: "vec2_magSq".} =
  (a.x * a.x) + (a.y * a.y)
proc vec3MagSq(a: Vec3): float32 {.exportpy: "vec3_magSq".} =
  (a.x * a.x) + (a.y * a.y) + (a.z * a.z)

proc vec2Mag(a: Vec2): float32 {.exportpy: "vec2_mag".} =
  sqrt(a.vec2_magSq())
proc vec3Mag(a: Vec3): float32 {.exportpy: "vec3_mag".} =
  sqrt(a.vec3_magSq())

proc vec2Distance(a, b: Vec2): float32 {.exportpy: "vec2_distance".} =
  vec2_mag(vec2_sub(a, b))
proc vec3Distance(a, b: Vec3): float32 {.exportpy: "vec3_distance".} =
  vec3_mag(vec3_sub(a, b))

proc vec2Closest(a: Vec2, b: varargs[Vec2]): Vec2 {.exportpy: "vec2_closest".} =
  var closest_value = float32.high
  for v in b:
    let dist = a.vec2_distance(v)
    if dist < closest_value:
      result = v
      closest_value = dist
proc vec3Closest(a: Vec3, b: varargs[Vec3]): Vec3 {.exportpy: "vec3_closest".} =
  var closest_value = float32.high
  for v in b:
    let dist = a.vec3_distance(v)
    if a.vec3_distance(v) < closest_value:
      result = v
      closest_value = dist
