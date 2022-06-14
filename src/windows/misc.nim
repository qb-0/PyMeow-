import
  os, nimpy, winim,
  overlay

pyExportModule("pymeow")

proc keyPressed(vKey: int32): bool {.exportpy: "key_pressed".} =
  GetAsyncKeyState(vKey).bool

proc pressKey(vKey: int32) {.exportpy: "press_key".} =
  var input: INPUT
  input.`type` = INPUT_KEYBOARD
  input.ki.wScan = 0
  input.ki.time = 0
  input.ki.dwExtraInfo = 0
  input.ki.wVk = vKey.uint16
  input.ki.dwFlags = 0
  SendInput(1, input.addr, sizeof(input).int32)

proc setForeground(winTitle: string): bool {.discardable, exportpy: "set_foreground".} = 
  SetForeGroundWindow(FindWindowA(nil, winTitle))

proc mouseMove(a: Overlay, x, y: float32) {.exportpy: "mouse_move".} =
  var input: INPUT
  input.mi = MOUSE_INPUT(
    dwFlags: MOUSEEVENTF_MOVE, 
    dx: (x - a.midX).int32,
    dy: -(y - a.midY).int32,
  )
  SendInput(1, input.addr, sizeof(input).int32)

proc mouseClick {.exportpy: "mouse_click".} =
  var 
    down: INPUT
    release: INPUT
  down.mi = MOUSE_INPUT(dwFlags: MOUSEEVENTF_LEFTDOWN)
  release.mi = MOUSE_INPUT(dwFlags: MOUSEEVENTF_LEFTUP)
  SendInput(1, down.addr, sizeof(down).int32)
  sleep(3)
  SendInput(1, release.addr, sizeof(release).int32)
