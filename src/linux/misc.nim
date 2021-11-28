import 
  os, x11/[xlib, xtst], nimpy,
  colors
include x11/keysym

pyExportModule("pymeow")

var display = XOpenDisplay(nil)

proc keyPressed*(key: KeySym): bool {.exportpy: "key_pressed".} =
  var keys: array[0..31, char]
  discard XQueryKeymap(display, keys)
  let keycode = XKeysymToKeycode(display, key)
  (ord(keys[keycode.int div 8]) and (1 shl (keycode.int mod 8))) != 0

proc clickMouse* {.exportpy: "click_mouse"} =
  discard XTestFakeButtonEvent(display, 1, 1, 0)
  discard XFlush(display)
  sleep(2)
  discard XTestFakeButtonEvent(display, 1, 0, 0)
  discard XFlush(display)

proc moveMouse*(x, y: cint) {.exportpy: "move_mouse".} =
  discard XTestFakeMotionEvent(display, -1, x, y, 0)
  discard XFlush(display)

proc rgb(color: string): array[0..2, float32] {.exportpy.} =
  try:
    let c = parseColor(color).extractRGB()
    [c.r.float32, c.g.float32, c.b.float32]
  except:
    [0.float32, 0, 0]