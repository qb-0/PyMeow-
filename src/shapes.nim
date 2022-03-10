import 
  nimpy, nimgl/opengl, vector, 
  math, strutils

pyExportModule("pymeow")

type Rgb = array[0..2, float32]

proc pixel(x, y: float, color: Rgb) {.exportpy.} =
  glBegin(GL_LINES)
  glColor3f(color[0], color[1], color[2])
  glVertex2f(x, y)
  glVertex2f(x + 1, y + 1)
  glEnd()

proc pixelV(pos: Vec2, color: Rgb) {.exportpy: "pixel_v".} =
  pixel(pos.x, pos.y, color)

proc box(x, y, width, height, lineWidth: float, color: Rgb) {.exportpy.} =
  glLineWidth(lineWidth)
  glBegin(GL_LINE_LOOP)
  glColor3f(color[0], color[1], color[2])
  glVertex2f(x, y)
  glVertex2f(x + width, y)
  glVertex2f(x + width, y + height)
  glVertex2f(x, y + height)
  glEnd()

proc boxV(pos: Vec2, width, height, lineWidth: float, color: Rgb) {.exportpy: "box_v".} =
  box(pos.x, pos.y, width, height, linewidth, color)

proc alphaBox(x, y, width, height: float, color, outlineColor: Rgb, alpha: float) {.exportpy: "alpha_box".} =
  box(x, y, width, height, 1.0, outlineColor)
  glBegin(GL_POLYGON)
  glColor4f(color[0], color[1], color[2], alpha)
  glVertex2f(x, y)
  glVertex2f(x + width, y)
  glVertex2f(x + width, y + height)
  glVertex2f(x, y + height)
  glEnd()

proc alphaBoxV(pos: Vec2, width, height: float, color, outlineColor: Rgb, alpha: float) {.exportpy: "alpha_box_v".} =
  alphaBox(pos.x, pos.y, width, height, color, outlineColor, alpha)

proc cornerBox(x, y, width, height: float, color, outlineColor: Rgb, lineWidth: float = 1) {.exportpy: "corner_box".} =
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

proc cornerBoxV(pos: Vec2, width, height: float, color, outlineColor: Rgb, lineWidth: float = 1) {.exportpy: "corner_box_v".} =
  corner_box(pos.x, pos.y, width, height, color, outlineColor, lineWidth)

proc line(x1, y1, x2, y2, lineWidth: float, color: Rgb) {.exportpy.} =
  glLineWidth(lineWidth)
  glBegin(GL_LINES)
  glColor3f(color[0], color[1], color[2])
  glVertex2f(x1, y1)
  glVertex2f(x2, y2)
  glEnd()

proc lineV(pos1, pos2: Vec2, lineWidth: float, color: Rgb) {.exportpy: "line_v".} =
  line(pos1.x, pos1.y, pos2.x, pos2.y, lineWidth, color)

proc dashedLine(x1, y1, x2, y2, lineWidth: float, color: Rgb, factor: int32 = 2, pattern: string = "11111110000", alpha: float32 = 0.5) {.exportpy: "dashed_line".} =
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

proc dashedLineV(pos1, pos2: Vec2, lineWidth: float, color: Rgb, factor: int32 = 2, pattern: string = "11111110000", alpha: float32 = 0.5) {.exportpy: "dashed_line_v".} =
  dashedLine(pos1.x, pos1.y, pos2.x, pos2.y, lineWidth, color, factor, pattern, alpha)

proc circle(x, y, radius: float, color: Rgb, filled: bool = true) {.exportpy.} =
  if filled: glBegin(GL_POLYGON)
  else: glBegin(GL_LINE_LOOP)

  glColor3f(color[0], color[1], color[2])
  for i in 0..<360:
    glVertex2f(
      cos(degToRad(i.float32)) * radius + x,
      sin(degToRad(i.float32)) * radius + y
    )
  glEnd()

proc circleV(pos: Vec2, radius: float, color: Rgb, filled: bool = true) {.exportpy: "circle_v".} =
  circle(pos.x, pos.y, radius, color, filled)

proc radCircle(x, y, radius: float, value: int, color: Rgb) {.exportpy: "rad_circle".} =
  glBegin(GL_POLYGON)
  glColor3f(color[0], color[1], color[2])
  for i in 0..value:
    glVertex2f(
      cos(degToRad(i.float32)) * radius + x,
      sin(degToRad(i.float32)) * radius + y
    )
  glEnd()

proc radCircleV(pos: Vec2, radius: float, value: int, color: Rgb) {.exportpy: "rad_circle_v".} =
  radCircle(pos.x, pos.y, radius, value, color)

proc valueBar(x1, y1, x2, y2, width, maxValue, value: float, vertical: bool = true) {.exportpy: "value_bar".} =
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

proc valueBarV(pos1, pos2: Vec2, width, maxValue, value: float, vertical: bool = true) {.exportpy: "value_bar_v".} =
  valueBar(pos1.x, pos1.y, pos2.x, pos2.y, width, maxValue, value, vertical)

proc poly(x, y, radius, rotation: float, sides: int, color: Rgb) {.exportpy.} =
  # Credits to RayLib
  var 
    s = if sides <= 3: 3.0 else: sides.float
    centralAngle = 0.0
  
  glPushMatrix()
  glTranslatef(x, y, 0.0)
  glRotatef(rotation, 0.0, 0.0, 1.0)

  glBegin(GL_TRIANGLES)
  for _ in 0..sides:
    glColor3f(color[0], color[1], color[2])
    glVertex2f(0, 0)
    glVertex2f(sin(degToRad(centralAngle)) * radius, cos(degToRad(centralAngle)) * radius)
    centralAngle += 360.0 / s
    glVertex2f(sin(degToRad(centralAngle)) * radius, cos(degToRad(centralAngle)) * radius)
  glEnd()
  glPopMatrix()

proc polyV(pos: Vec2, radius, rotation: float, sides: int, color: Rgb) {.exportpy: "poly_v".} =
  poly(pos.x, pos.y, radius, rotation, sides, color)

proc customShape(points: openArray[Vec2], color: Rgb, filled: bool = true, alpha: float = 1.0) {.exportpy: "custom_shape".} =
  if filled: glBegin(GL_POLYGON)
  else: glBegin(GL_LINE_LOOP)
  glColor4f(color[0], color[1], color[2], alpha)
  for p in points:
    glVertex2f(p.x, p.y)
  glEnd()
