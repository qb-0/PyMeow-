import pymeow as pm

from math import fmod
from time import time, sleep


def main():
    overlay = pm.overlay_init()
    radius = 50
    r, g, b = 0.0, 0.3, 0.6
    x, y = overlay["midX"], overlay["midY"]
    speed = 5
    ball_left, ball_down = False, False

    frames, fps = 0, 0
    prev_time = time()

    star_offset = 100
    star_x = overlay["midX"]
    star_y = overlay["midY"]
    star_points = [
        pm.vec2(star_x, star_y + star_offset),
        pm.vec2(star_x + star_offset, star_y),
        pm.vec2(star_x, star_y - star_offset),
        pm.vec2(star_x - star_offset, star_y),
    ]

    while pm.overlay_loop(overlay):
        sleep(0.001)
        pm.custom_shape(star_points, pm.rgb("yellow"))
        curr_time = time()
        frames += 1

        if curr_time - prev_time > 1.0:
            fps = frames
            frames = 0
            prev_time = curr_time

        pm.render_string(
            overlay["midX"], overlay["midY"], f"FPS: {fps}", [b, r, g], True
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
