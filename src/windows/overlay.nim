import
  nimpy, winim, os,
  nimgl/[glfw, glfw/native, opengl]
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

  Rgb = array[0..2, float32]

var OverlayWindow: GLFWWindow

proc overlayInit(target: string = "Fullscreen", exitKey: int32 = 0x23, borderOffset: int32 = 25): Overlay {.exportpy: "overlay_init".} =
  var rect: RECT
  assert glfwInit()

  glfwWindowHint(GLFWFloating, GLFWTrue)
  glfwWindowHint(GLFWDecorated, GLFWFalse)
  glfwWindowHint(GLFWResizable, GLFWFalse)
  glfwWindowHint(GLFWTransparentFramebuffer, GLFWTrue)
  glfwWindowHint(GLFWMouseButtonPassthrough, GLFWTrue)
  glfwWindowHint(GLFWSamples, 10)

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

  OverlayWindow = glfwCreateWindow(result.width.int32 - 1, result.height.int32 - 1, "PyMeow", icon=false)
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

proc update(a: Overlay) {.exportpy: "overlay_update".} =
  OverlayWindow.swapBuffers()
  glClear(GL_COLOR_BUFFER_BIT)
  glfwPollEvents()

proc deinit(a: Overlay) {.exportpy: "overlay_deinit".} =
  OverlayWindow.destroyWindow()
  glfwTerminate()

proc close(a: Overlay) {.exportpy: "overlay_close".} = 
  OverlayWindow.setWindowShouldClose(true)

proc loop(a: Overlay, update: bool = true, delay: int = 0): bool {.exportpy: "overlay_loop".} =
  sleep(delay)
  if GetAsyncKeyState(a.exitKey).bool:
    a.close()
  if update:
    a.update()
  not OverlayWindow.windowShouldClose()

proc hide(a: Overlay) {.exportpy: "overlay_hide".} =
  let visible = OverlayWindow.getWindowAttrib(GLFWVisible)
  if visible == GLFWTrue:
    OverlayWindow.hideWindow()
  else:
    OverlayWindow.showWindow()

proc setTitle(a: Overlay, title: string) {.exportpy: "overlay_set_title".} =
  OverlayWindow.setWindowTitle(title)

proc setPos(a: Overlay, x, y: int32) {.exportpy: "overlay_set_pos".} =
  SetWindowPos(a.hwnd, -1, x, y, 0, 0, 0x0001)

proc fontInit(height: int32, fontName: string): Font {.exportpy: "font_init".} =
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

proc deinit(a: Font) {.exportpy: "font_deinit".} = 
  glDeleteLists(a.font, 96)

proc print(a: Font, x, y: float, text: string, color: Rgb) {.exportpy: "font_print".} =
  glColor3f(color[0], color[1], color[2])
  glWindowPos2f(x, y)
  glPushAttrib(GL_LIST_BIT)
  glListBase(a.font - 32)
  glCallLists(text.len.int32, GL_UNSIGNED_BYTE, cast[pointer](text[0].unsafeAddr))
  glPopAttrib()

proc printLines(a: Font, x, y: float, lines: openArray[string], color: Rgb, offset: float32 = 2) {.exportpy: "font_print_lines".} =
  var yPos = y
  glColor3f(color[0], color[1], color[2])
  glPushAttrib(GL_LIST_BIT)
  glListBase(a.font - 32)
  for t in lines:
    glWindowPos2f(x, yPos)
    glCallLists(t.len.int32, GL_UNSIGNED_BYTE, cast[pointer](t[0].unsafeAddr))
    yPos -= a.height.float32 + offset
  glPopAttrib()
