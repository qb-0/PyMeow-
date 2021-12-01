import 
  strutils, math, colors, osproc,
  nimgl/[glfw, opengl], opengl/glut,
  nimpy, misc, x11/keysym, ../vector

pyExportModule("pymeow")

type
  Overlay* = object
    width*, height*, midX*, midY*: int32
    x*, y*: int32
    exitKey*: culong

  WinInfo = tuple
    x, y, width, height: int32

  Rgb = array[0..2, float32]


var OverlayWindow: GLFWWindow

#[
  overlay
]#

proc getWindowInfo(name: string): WinInfo =
  let 
    p = startProcess("xwininfo", "", ["-name", name], options={poUsePath, poStdErrToStdOut})
    (lines, exitCode) = p.readLines()

  template parseI: int32 = parseInt(i.split()[^1]).int32

  if exitCode != 1:
    for i in lines:
      if "te upper-left X:" in i:
        result.x = parseI
      elif "te upper-left Y:" in i:
        result.y = parseI
      elif "Width:" in i:
        result.width = parseI
      elif "Height:" in i:
        result.height = parseI
  else:
    raise newException(IOError, "XWinInfo failed")

proc overlayInit*(target: string = "Fullscreen", exitKey: culong = XK_End): Overlay {.exportpy: "overlay_init".} =
  var wInfo: WinInfo
  assert glfwInit()

  glfwWindowHint(GLFWFloating, GLFWTrue)
  glfwWindowHint(GLFWDecorated, GLFWFalse)
  glfwWindowHint(GLFWResizable, GLFWFalse)
  glfwWindowHint(GLFWTransparentFramebuffer, GLFWTrue)
  glfwWindowHint(GLFWSamples, 10)
  glfwWindowHint(GLFWMouseButtonPassthrough, GLFWTrue)

  let videoMode = getVideoMode(glfwGetPrimaryMonitor())
  if target == "Fullscreen":
    result.width = videoMode.width - 1
    result.height = videoMode.height - 1
    result.midX = videoMode.width div 2
    result.midY = videoMode.height div 2
    result.x = 0
    result.y = 0
  else:
    wInfo = getWindowInfo(target)
    result.width = wInfo.width
    result.height = wInfo.height
    result.x = wInfo.x
    result.y = wInfo.y
    result.midX = result.width div 2
    result.midY = result.height div 2

  result.exitKey = exitKey
  OverlayWindow = glfwCreateWindow(result.width.int32, result.height.int32, "PyMeow", icon=false)
  OverlayWindow.makeContextCurrent()
  glfwSwapInterval(1)
  
  assert glInit()
  glutInit()
  glPushAttrib(GL_ALL_ATTRIB_BITS)
  glMatrixMode(GL_PROJECTION)
  glLoadIdentity()
  glOrtho(0, result.width.float64, 0, result.height.float64, -1, 1)
  glDisable(GL_DEPTH_TEST)
  glDisable(GL_TEXTURE_2D)
  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

  if target != "Fullscreen":
    OverlayWindow.setWindowPos(wInfo.x, wInfo.y)

proc update*(a: Overlay) {.exportpy: "overlay_update".} =
  OverlayWindow.swapBuffers()
  glfwPollEvents()
  glClear(GL_COLOR_BUFFER_BIT)

proc deinit*(a: Overlay) {.exportpy: "overlay_deinit".} =
  OverlayWindow.destroyWindow()
  glfwTerminate()

proc close*(a: Overlay) {.exportpy: "overlay_close".} = 
  OverlayWindow.setWindowShouldClose(true) 

proc loop*(a: Overlay, update: bool = true): bool {.exportpy: "overlay_loop".} =
  if update: 
    a.update()
  if keyPressed(a.exitKey): 
    a.close()
  not OverlayWindow.windowShouldClose()

#[
  2d shapes
]#

proc box*(x, y, width, height, lineWidth: float, color: Rgb) {.exportpy.} =
  glLineWidth(lineWidth)
  glBegin(GL_LINE_LOOP)
  glColor3f(color[0], color[1], color[2])
  glVertex2f(x, y)
  glVertex2f(x + width, y)
  glVertex2f(x + width, y + height)
  glVertex2f(x, y + height)
  glEnd()

proc alphaBox*(x, y, width, height: float, color, outlineColor: Rgb, alpha: float) {.exportpy: "alpha_box".} =
  box(x, y, width, height, 1.0, outlineColor)
  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glBegin(GL_POLYGON)
  glColor4f(color[0], color[1], color[2], alpha)
  glVertex2f(x, y)
  glVertex2f(x + width, y)
  glVertex2f(x + width, y + height)
  glVertex2f(x, y + height)
  glEnd()
  glDisable(GL_BLEND)

proc cornerBox*(x, y, width, height: float, color, outlineColor: Rgb, lineWidth: float = 1) {.exportpy: "corner_box".} =
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

proc line*(x1, y1, x2, y2, lineWidth: float, color: Rgb) {.exportpy.} =
  glLineWidth(lineWidth)
  glBegin(GL_LINES)
  glColor3f(color[0], color[1], color[2])
  glVertex2f(x1, y1)
  glVertex2f(x2, y2)
  glEnd()

proc dashedLine*(x1, y1, x2, y2, lineWidth: float, color: Rgb, factor: int32 = 2, pattern: string = "11111110000", alpha: float32 = 0.5) {.exportpy: "dashed_line".} =
  glPushAttrib(GL_ENABLE_BIT)
  glLineStipple(factor, fromBin[uint16](pattern))
  glLineWidth(lineWidth)
  glEnable(GL_LINE_STIPPLE)
  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

  glBegin(GL_LINES)
  glColor4f(color[0], color[1], color[2], alpha)
  glVertex2f(x1, y1)
  glVertex2f(x2, y2)
  glEnd()
  glPopAttrib()

proc circle*(x, y, radius: float, color: Rgb, filled: bool = true) {.exportpy.} =
  if filled: glBegin(GL_POLYGON)
  else: glBegin(GL_LINE_LOOP)

  glColor3f(color[0], color[1], color[2])
  for i in 0..<360:
    glVertex2f(
      cos(degToRad(i.float32)) * radius + x,
      sin(degToRad(i.float32)) * radius + y
    )
  glEnd()

proc radCircle*(x, y, radius: float, value: int, color: Rgb) {.exportpy: "rad_circle".} =
  glBegin(GL_POLYGON)
  glColor3f(color[0], color[1], color[2])
  for i in 0..value:
    glVertex2f(
      cos(degToRad(i.float32)) * radius + x,
      sin(degToRad(i.float32)) * radius + y
    )
  glEnd()

proc valueBar*(x1, y1, x2, y2, width, maxValue, value: float, vertical: bool = true) {.exportpy: "value_bar".} =
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

proc renderString*(x, y: float, text: string, color: Rgb, align: bool = false) {.exportpy: "render_string".} =
  glColor3f(color[0], color[1], color[2])

  if align:
    glRasterPos2f(x - (glutBitmapLength(GLUT_BITMAP_HELVETICA_12, text).float / 2), y)
  else:
    glRasterPos2f(x, y)

  for c in text:
    glutBitmapCharacter(GLUT_BITMAP_HELVETICA_12, ord(c))

proc renderStringLines(x, y: float, lines: openArray[string], color: Rgb, align: bool = false, offset: float = 12) {.exportpy: "render_string_lines".} =
  glColor3f(color[0], color[1], color[2])
  var yPos = y

  for l in lines:
    if align:
      glRasterPos2f(x - (glutBitmapLength(GLUT_BITMAP_HELVETICA_12, l.cstring).float / 2), yPos)
    else:
      glRasterPos2f(x, yPos)

    yPos -= offset
    for c in l:
      glutBitmapCharacter(GLUT_BITMAP_HELVETICA_12, ord(c))

#[
  world to screen
]#

proc wtsOgl(a: Overlay, matrix: array[0..15, float32], pos: Vec3): Vec2 {.exportpy: "wts_ogl".} =
  var 
    clip: Vec3
    ndc: Vec2

  # z = w
  clip.z = pos.x * matrix[3] + pos.y * matrix[7] + pos.z * matrix[11] + matrix[15]
  if clip.z < 0.2:
    raise newException(Exception, "WTS")

  clip.x = pos.x * matrix[0] + pos.y * matrix[4] + pos.z * matrix[8] + matrix[12]
  clip.y = pos.x * matrix[1] + pos.y * matrix[5] + pos.z * matrix[9] + matrix[13]

  ndc.x = clip.x / clip.z
  ndc.y = clip.y / clip.z

  result.x = (a.width / 2 * ndc.x) + (ndc.x + a.width / 2)
  result.y = (a.height / 2 * ndc.y) + (ndc.y + a.height / 2)

proc wtsDx(a: Overlay, matrix: array[0..15, float32], pos: Vec3): Vec2 {.exportpy: "wts_dx".} =
  var 
    clip: Vec3
    ndc: Vec2

  # z = w
  clip.z = pos.x * matrix[12] + pos.y * matrix[13] + pos.z * matrix[14] + matrix[15]
  if clip.z < 0.2:
    raise newException(Exception, "WTS")

  clip.x = pos.x * matrix[0] + pos.y * matrix[1] + pos.z * matrix[2] + matrix[3]
  clip.y = pos.x * matrix[4] + pos.y * matrix[5] + pos.z * matrix[6] + matrix[7]

  ndc.x = clip.x / clip.z
  ndc.y = clip.y / clip.z

  result.x = (a.width / 2 * ndc.x) + (ndc.x + a.width / 2)
  result.y = (a.height / 2 * ndc.y) + (ndc.y + a.height / 2)