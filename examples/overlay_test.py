import pymeow as pm

from math import fmod
from time import time
from random import randint


def main():
    overlay = pm.overlay_init()
    font = pm.font_init(20, "Impact")
    radius = 50
    r, g, b = 0.0, 0.3, 0.6
    x, y = overlay["midX"], overlay["midY"]
    speed = 5
    ball_left, ball_down = False, False

    frames, fps = 0, 0
    prev_time = time()
    stars = list()
    for _ in range(300):
        stars.append(
            pm.vec2(randint(0, overlay["width"]), randint(0, overlay["height"]))
        )

    while pm.overlay_loop(overlay, delay = 3):
        curr_time = time()
        frames += 1

        if curr_time - prev_time > 1.0:
            fps = frames
            frames = 0
            prev_time = curr_time

        [pm.pixel_v(vec, pm.rgb("white")) for vec in stars]
        pm.poly(overlay["midX"], overlay["midY"], 100, 0, 6, pm.rgb("aqua"))
        pm.font_print(
            font, overlay["midX"] - 20, overlay["midY"], f"FPS: {fps}", [b, r, g]
        )

        if ball_left:
            if x > overlay["width"] - radius:
                ball_left = False
            else:
                x += speed
        else:
            if x < -1 + radius:
                ball_left = True
            else:
                x -= speed

        if ball_down:
            if y > overlay["height"] - radius:
                ball_down = False
            else:
                y += speed
        else:
            if y < -1 + radius:
                ball_down = True
            else:
                y -= speed

        r = fmod(r + 0.001, 1)
        g = fmod(g + 0.002, 1)
        b = fmod(b + 0.003, 1)

        pm.circle(
            x=x,
            y=y,
            radius=radius,
            color=[r, g, b],
            filled=False,
        )
        pm.circle(
            x=x,
            y=y,
            radius=radius - 15,
            color=[g, b, r],
            filled=True,
        )


if __name__ == "__main__":
    main()
