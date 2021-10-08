import
  strutils, math, 
  nimpy, winim, nimgl/[glfw, glfw/native, opengl],
  vector
from strformat import fmt

pyExportModule("pymeow")

type
  Overlay* = object
    width*, height*, midX*, midY*: float
    hwnd: int
    exitKey: int32

  Font = object
    font: uint32
    fontHDC: int
    height: int32

var OverlayWindow: GLFWWindow

#[
  overlay
]#

proc overlay_init(target: string = "Fullscreen", exitKey: int32 = 0x23, borderOffset: int32 = 25): Overlay {.exportpy.} =
  var rect: RECT
  assert glfwInit()

  glfwWindowHint(GLFWFloating, GLFWTrue)
  glfwWindowHint(GLFWDecorated, GLFWFalse)
  glfwWindowHint(GLFWResizable, GLFWFalse)
  glfwWindowHint(GLFWTransparentFramebuffer, GLFWTrue)
  glfwWindowHint(GLFWMouseButtonPassthrough, GLFWTrue)
  glfwWindowHint(GLFWSamples, 8)

  result.exitKey = exitKey
  if target == "Fullscreen":
    let videoMode = getVideoMode(glfwGetPrimaryMonitor())
    result.width = videoMode.width.float32
    result.height = videoMode.height.float32
    result.midX = videoMode.width / 2
    result.midY = videoMode.height / 2
  else:
    let hwndWin = FindWindowA(nil, target)
    if hwndWin == 0:
      raise newException(Exception, fmt"Window ({target}) not found")
    GetWindowRect(hwndWin, rect.addr)
    result.width = rect.right.float32 - rect.left.float32
    result.height = rect.bottom.float32 - rect.top.float32 - borderOffset.float32
    result.midX = result.width / 2
    result.midY = result.height / 2

  OverlayWindow = glfwCreateWindow(result.width.int32 - 1, result.height.int32 - 1, "Meow", icon=false)
  OverlayWindow.setInputMode(GLFWCursorSpecial, GLFWCursorDisabled)
  OverlayWindow.makeContextCurrent()
  glfwSwapInterval(0)

  assert glInit()
  glPushAttrib(GL_ALL_ATTRIB_BITS)
  glMatrixMode(GL_PROJECTION)
  glLoadIdentity()
  glOrtho(0, result.width.float64, 0, result.height.float64, -1, 1)
  glDisable(GL_DEPTH_TEST)
  glDisable(GL_TEXTURE_2D)
  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

  result.hwnd = cast[int](getWin32Window(OverlayWindow))
  if target != "Fullscreen":
    SetWindowPos(result.hwnd, -1, rect.left, rect.top + borderOffset, 0, 0, 0x0001)

proc overlay_update(a: Overlay) {.exportpy.} =
  OverlayWindow.swapBuffers()
  glClear(GL_COLOR_BUFFER_BIT)
  glfwPollEvents()

proc overlay_deinit(a: Overlay) {.exportpy.} =
  OverlayWindow.destroyWindow()
  glfwTerminate()

proc overlay_close(a: Overlay) {.exportpy.} = 
  OverlayWindow.setWindowShouldClose(true)

proc overlay_loop(a: Overlay, update: bool = true): bool {.exportpy.} =
  if GetAsyncKeyState(a.exitKey).bool:
    a.overlay_close()
  if update:
    a.overlay_update()
  not OverlayWindow.windowShouldClose()

proc overlay_set_pos(a: Overlay, x, y: int32) {.exportpy.} =
  SetWindowPos(a.hwnd, -1, x, y, 0, 0, 0x0001)

#[
  bitmap font rendering
]#

proc font_init(height: int32, fontName: string): Font {.exportpy.} =
  result.fontHDC = wglGetCurrentDC()
  if result.fontHDC == 0:
    raise newException(Exception, "Font initialisation without a overlay")

  let
    hFont = CreateFont(-(height), 0, 0, 0, FW_DONTCARE, 0, 0, 0, ANSI_CHARSET,
        OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, FF_DONTCARE or
        DEFAULT_PITCH, cast[cstring](fontName[0].unsafeAddr))
    hOldFont = SelectObject(result.fontHDC, hFont)

  result.font = glGenLists(96)
  result.height = height
  wglUseFontBitmaps(result.fontHDC, 32, 96, result.font.int32)
  SelectObject(result.fontHDC, hOldFont)
  discard DeleteObject(hFont)

proc font_deinit(a: Font) {.exportpy.} = 
  glDeleteLists(a.font, 96)

proc font_print(a: Font, x, y: float, text: string, color: array[0..2, float32]) {.exportpy.} =
  glColor3f(color[0], color[1], color[2])
  glWindowPos2f(x, y)
  glPushAttrib(GL_LIST_BIT)
  glListBase(a.font - 32)
  glCallLists(cast[int32](text.len), GL_UNSIGNED_BYTE, cast[pointer](text[0].unsafeAddr))
  glPopAttrib()

proc font_print_lines(a: Font, x, y: float, lines: openArray[string], color: array[0..2, float32], offset: float32 = 2) {.exportpy.} =
  var yPos = y
  glColor3f(color[0], color[1], color[2])
  glPushAttrib(GL_LIST_BIT)
  glListBase(a.font - 32)
  for t in lines:
    glWindowPos2f(x, yPos)
    glCallLists(cast[int32](t.len), GL_UNSIGNED_BYTE, cast[pointer](t[0].unsafeAddr))
    yPos -= a.height.float32 + offset
  glPopAttrib()

#[
  2d shapes
]#

proc box(x, y, width, height, lineWidth: float, color: array[0..2, float32]) {.exportpy.} =
  glLineWidth(lineWidth)
  glBegin(GL_LINE_LOOP)
  glColor3f(color[0], color[1], color[2])
  glVertex2f(x, y)
  glVertex2f(x + width, y)
  glVertex2f(x + width, y + height)
  glVertex2f(x, y + height)
  glEnd()

proc box_v(pos: Vec2, width, height, lineWidth: float, color: array[0..2, float32]) {.exportpy.} =
  box(pos.x, pos.y, width, height, linewidth, color)

proc alpha_box(x, y, width, height: float, color, outlineColor: array[0..2, float32], alpha: float) {.exportpy.} =
  box(x, y, width, height, 1.0, outlineColor)
  glBegin(GL_POLYGON)
  glColor4f(color[0], color[1], color[2], alpha)
  glVertex2f(x, y)
  glVertex2f(x + width, y)
  glVertex2f(x + width, y + height)
  glVertex2f(x, y + height)
  glEnd()

proc alpha_box_v(pos: Vec2, width, height: float, color, outlineColor: array[0..2, float32], alpha: float) {.exportpy.} =
  alpha_box(pos.x, pos.y, width, height, color, outlineColor, alpha)

proc corner_box(x, y, width, height: float, color, outlineColor: array[0..2, float32], lineWidth: float = 1) {.exportpy.} =
  template drawCorner =
    glBegin(GL_LINES)
    # Lower Left
    glVertex2f(x, y); glVertex2f(x + lineW, y)
    glVertex2f(x, y); glVertex2f(x, y + lineH)

    # Lower Right
    glVertex2f(x + width, y); glVertex2f(x + width, y + lineH)
    glVertex2f(x + width, y); glVertex2f(x + width - lineW, y)

    # Upper Left
    glVertex2f(x, y + height); glVertex2f(x, y + height - lineH)
    glVertex2f(x, y + height); glVertex2f(x + lineW, y + height)

    # Upper Right
    glVertex2f(x + width, y + height); glVertex2f(x + width, y + height - lineH)
    glVertex2f(x + width, y + height); glVertex2f(x + width - lineW, y + height)
    glEnd()

  let
    lineW = width / 4
    lineH = height / 3

  glLineWidth(lineWidth + 2)
  glColor3f(outlineColor[0], outlineColor[1], outlineColor[2])
  drawCorner()
  glLineWidth(lineWidth)
  glColor3f(color[0], color[1], color[2])
  drawCorner()

proc corner_box_v(pos: Vec2, width, height: float, color, outlineColor: array[0..2, float32], lineWidth: float = 1) {.exportpy.} =
  corner_box(pos.x, pos.y, width, height, color, outlineColor, lineWidth)

proc line(x1, y1, x2, y2, lineWidth: float, color: array[0..2, float32]) {.exportpy.} =
  glLineWidth(lineWidth)
  glBegin(GL_LINES)
  glColor3f(color[0], color[1], color[2])
  glVertex2f(x1, y1)
  glVertex2f(x2, y2)
  glEnd()

proc line_v(pos1, pos2: Vec2, lineWidth: float, color: array[0..2, float32]) {.exportpy.} =
  line(pos1.x, pos1.y, pos2.x, pos2.y, lineWidth, color)

proc dashed_line(x1, y1, x2, y2, lineWidth: float, color: array[0..2, float32], factor: int32 = 2, pattern: string = "11111110000", alpha: float32 = 0.5) {.exportpy.} =
  glPushAttrib(GL_ENABLE_BIT)
  glLineStipple(factor, fromBin[uint16](pattern))
  glLineWidth(lineWidth)
  glEnable(GL_LINE_STIPPLE)

  glBegin(GL_LINES)
  glColor4f(color[0], color[1], color[2], alpha)
  glVertex2f(x1, y1)
  glVertex2f(x2, y2)
  glEnd()
  glPopAttrib()

proc dashed_line_v(pos1, pos2: Vec2, lineWidth: float, color: array[0..2, float32], factor: int32 = 2, pattern: string = "11111110000", alpha: float32 = 0.5) {.exportpy.} =
  dashed_line(pos1.x, pos1.y, pos2.x, pos2.y, lineWidth, color, factor, pattern, alpha)

proc circle(x, y, radius: float, color: array[0..2, float32], filled: bool = true) {.exportpy.} =
  if filled: glBegin(GL_POLYGON)
  else: glBegin(GL_LINE_LOOP)

  glColor3f(color[0], color[1], color[2])
  for i in 0..<360:
    glVertex2f(
      cos(degToRad(i.float32)) * radius + x,
      sin(degToRad(i.float32)) * radius + y
    )
  glEnd()

proc circle_v(pos: Vec2, radius: float, color: array[0..2, float32], filled: bool = true) {.exportpy.} =
  circle(pos.x, pos.y, radius, color, filled)

proc rad_circle(x, y, radius: float, value: int, color: array[0..2, float32]) {.exportpy.} =
  glBegin(GL_POLYGON)
  glColor3f(color[0], color[1], color[2])
  for i in 0..value:
    glVertex2f(
      cos(degToRad(i.float32)) * radius + x,
      sin(degToRad(i.float32)) * radius + y
    )
  glEnd()

proc rad_circle_v(pos: Vec2, radius: float, value: int, color: array[0..2, float32]) {.exportpy.} =
  rad_circle(pos.x, pos.y, radius, value, color)

proc value_bar(x1, y1, x2, y2, width, maxValue, value: float, vertical: bool = true) {.exportpy.} =
  if value > maxValue:
    raise newException(Exception, "ValueBar: Max Value > value")

  let
    x = value / maxValue
    barY = (y2 - y1) * x + y1
    barX = (x2 - x1) * x + x1
    color = [(2.0 * (1 - x)).float32, (2.0 * x).float32, 0.float32]

  line(x1, y1, x2, y2, width + 3.0, [0.float32, 0, 0])

  if vertical:
    line(x1, y1, x2, barY, width, color)
  else:
    line(x1, y1, barX, y2, width, color)

proc value_bar_v(pos1, pos2: Vec2, width, maxValue, value: float, vertical: bool = true) {.exportpy.} =
  value_bar(pos1.x, pos1.y, pos2.x, pos2.y, width, maxValue, value, vertical)

proc custom_shape(points: openArray[Vec2], color: array[0..2, float32], filled: bool = true, alpha: float = 1.0) {.exportpy.} =
  if filled: glBegin(GL_POLYGON)
  else: glBegin(GL_LINE_LOOP)
  glColor4f(color[0], color[1], color[2], alpha)
  for p in points:
    glVertex2f(p.x, p.y)
  glEnd()