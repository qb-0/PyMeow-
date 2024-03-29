import 
  os, x11/[x, xlib, xtst], 
  nimpy

pyExportModule("pymeow")

var 
  display = XOpenDisplay(nil)
  root = XRootWindow(display, 0)

proc keyPressed*(key: KeySym): bool {.exportpy: "key_pressed".} =
  var keys: array[0..31, char]
  discard XQueryKeymap(display, keys)
  let keycode = XKeysymToKeycode(display, key)
  (ord(keys[keycode.int div 8]) and (1 shl (keycode.int mod 8))) != 0

proc pressKey*(key: KeySym, hold: bool = false) {.exportpy: "press_key".} =
  let keycode = XKeysymToKeycode(display, key)
  discard XTestFakeKeyEvent(display, keycode.cuint, 1, CurrentTime)
  if not hold:
    discard XTestFakeKeyEvent(display, keycode.cuint, 0, CurrentTime)

proc mouseClick* {.exportpy: "mouse_click"} =
  discard XTestFakeButtonEvent(display, 1, 1, 0)
  discard XFlush(display)
  sleep(2)
  discard XTestFakeButtonEvent(display, 1, 0, 0)
  discard XFlush(display)

proc mouseMove*(x, y: cint, relative: bool = false) {.exportpy: "mouse_move".} =
  if relative:
    discard XTestFakeRelativeMotionEvent(display, x, y, CurrentTime)
  else:
    discard XTestFakeMotionEvent(display, -1, x, y, CurrentTime)
  discard XFlush(display)

proc mousePosition: (int32, int32) {.exportpy: "mouse_position".} =
  var 
    qRoot, qChild: Window
    qRootX, qRootY, qChildX, qChildY: cint
    qMask: cuint

  discard XQueryPointer(display, root, qRoot.addr, qChild.addr, qRootX.addr, qRootY.addr, qChildX.addr, qChildY.addr, qMask.addr)
  (qRootX, qRootY)