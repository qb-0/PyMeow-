from time import sleep
from pymeow import *


def main():
    overlay = overlay_init()
    x = 500
    y = 500
    bar_length = 300
    bar_width = 5
    max_health = 200

    while overlay_loop(overlay):
        for health in range(max_health, 0, -1):
            # Vertical Healthbar
            value_bar(
                x, y,
                x, y + bar_length,
                bar_width,
                max_health,
                health,
            )

            # Horizontal Healthbar
            value_bar(
                x, y - 12,
                x + bar_length, y - 12,
                bar_width,
                max_health,
                health,
                vertical=False
            )

            corner_box(
                x + 7,
                y,
                bar_length - 7,
                bar_length,
                rgb("white"), rgb("black")
            )

            sleep(0.001)

            overlay_update(overlay)


if __name__ == '__main__':
    main()
