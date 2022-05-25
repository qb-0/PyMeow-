import 
  strutils, math, osproc, os,
  nimgl/[glfw, opengl], opengl/glut,
  nimpy, misc, x11/keysym

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

proc loop*(a: Overlay, update: bool = true, delay: int = 0): bool {.exportpy: "overlay_loop".} =
  sleep(delay)
  if update: 
    a.update()
  if keyPressed(a.exitKey): 
    a.close()
  not OverlayWindow.windowShouldClose()

proc hide(a: Overlay) {.exportpy: "overlay_hide".} =
  let visible = OverlayWindow.getWindowAttrib(GLFWVisible)
  if visible == GLFWTrue:
    OverlayWindow.hideWindow()
  else:
    OverlayWindow.showWindow()

proc setTitle(a: Overlay, title: string) {.exportpy: "overlay_set_title".} =
  OverlayWindow.setWindowTitle(title)

template getFontPtr: pointer =
  case font
  of 0:
    GLUT_BITMAP_9_BY_15
  of 1:
    GLUT_BITMAP_8_BY_13
  of 2:
    GLUT_BITMAP_TIMES_ROMAN_10
  of 3:
    GLUT_BITMAP_TIMES_ROMAN_24
  of 4:
    GLUT_BITMAP_HELVETICA_10
  of 5:
    GLUT_BITMAP_HELVETICA_12
  of 6:
    GLUT_BITMAP_HELVETICA_18
  else:
    raise newException(IOError, "Font value out of range")

proc renderString*(x, y: float, text: string, color: Rgb, align: bool = false, font: int = 5) {.exportpy: "render_string".} =
  let f = getFontPtr()
  glColor3f(color[0], color[1], color[2])

  if align:
    glRasterPos2f(x - (glutBitmapLength(f, text).float / 2), y)
  else:
    glRasterPos2f(x, y)

  for c in text:
    glutBitmapCharacter(f, ord(c))

proc renderStringLines(x, y: float, lines: openArray[string], color: Rgb, align: bool = false, font: int = 5) {.exportpy: "render_string_lines".} =
  let 
    f = getFontPtr()
    fHeight = glutBitMapHeight(f).float
  var yPos = y

  glColor3f(color[0], color[1], color[2])

  for l in lines:
    if align:
      glRasterPos2f(x - (glutBitmapLength(f, l.cstring).float / 2), yPos)
    else:
      glRasterPos2f(x, yPos)

    yPos -= fHeight
    for c in l:
      glutBitmapCharacter(f, ord(c))