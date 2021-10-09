import sys
from math import atan2, asin, pi
from pymeow import *


class Offsets:
    EntityList = 0x346C90
    PlayerCount = 0x346C9C
    ViewMatrix = 0x32D040
    GameMode = 0x26f6c0

    Health = 0x178
    Armor = 0x180
    State = 0x77
    Name = 0x274
    Team = 0x378
    ViewAngles = 0x3C


class Entity:
    def __init__(self, addr):
        self.addr = addr

        self.hpos3d = read_vec3(mem, addr)
        self.fpos3d = vec3(
            self.hpos3d["x"], self.hpos3d["y"], self.hpos3d["z"] - 15
        )
        self.health = read_int(mem, addr + Offsets.Health)
        self.armor = read_int(mem, addr + Offsets.Armor)
        self.team = read_string(mem, addr + Offsets.Team)
        self.alive = read_byte(mem, addr + Offsets.State) == 0
        self.name = read_string(mem, addr + Offsets.Name)
        self.distance = 0.0
        self.hpos2d = vec2()
        self.fpos2d = vec2()


try:
    mem = process_by_name("sauerbraten.exe")
    base = mem["baseaddr"]
    overlay = overlay_init("Cube 2: Sauerbraten")
    local = None
except Exception as e:
    sys.exit(e)


def is_team_game():
    return read_byte(mem, base + Offsets.GameMode) in \
        [2, 4, 6, 8, 10, 11, 12, 17, 13, 14, 18, 15, 16, 19, 20, 21, 22]


def get_ents():
    player_count = read_int(mem, base + Offsets.PlayerCount)
    if player_count > 1:
        ent_buffer = read_ints64(mem, read_int64(mem, base + Offsets.EntityList), player_count)

        try:
            global local
            local = Entity(ent_buffer[0])
        except:
            return

        vm = read_floats(mem, base + Offsets.ViewMatrix, 16)

        for e in ent_buffer[1:]:
            try:
                ent = Entity(e)
                if ent.alive:
                    if is_team_game() and ent.team == local.team:
                        continue

                    ent.hpos2d = wts_ogl(overlay, vm, ent.hpos3d)
                    ent.fpos2d = wts_ogl(overlay, vm, ent.fpos3d)
                    ent.distance = int(vec3_distance(local.hpos3d, ent.hpos3d) / 3)
                    yield ent
            except:
                continue


def aim_bot(ent_vecs):
    src = local.hpos3d
    dst = vec3_closest(src, ent_vecs)

    angle = vec2()
    angle["x"] = -atan2(dst["x"] - src["x"], dst["y"] - src["y"]) / pi * 180.0
    angle["y"] = asin((dst["z"] - src["z"]) / vec3_distance(src, dst)) * (180.0 / pi)
    write_vec2(mem, local.addr + Offsets.ViewAngles, angle)


def main():
    set_foreground("Cube 2: Sauerbraten")
    font = font_init(10, "Tahoma")

    while overlay_loop(overlay):
        ent_vecs = list()
        for e in get_ents():
            ent_vecs.append(e.hpos3d)
            head = e.fpos2d["y"] - e.hpos2d["y"]
            width = head / 1.7
            center = width / -2

            corner_box(
                e.hpos2d["x"] + center,
                e.hpos2d["y"],
                width,
                head + 5,
                rgb("red"),
                rgb("black"),
                0.15,
            )
            value_bar(
                e.fpos2d["x"] - center - 5,
                e.fpos2d["y"] + 5,
                e.fpos2d["x"] - center - 5,
                e.hpos2d["y"],
                2,
                150, e.health
            )
            font_print(
                font,
                e.hpos2d["x"] - (len(e.name) * 2.5) ,
                e.hpos2d["y"] + 10,
                e.name,
                rgb("white")
            )
            font_print(
                font,
                e.fpos2d["x"] - 8,
                e.fpos2d["y"] - 10,
                str(e.distance),
                rgb("white")
            )
            dashed_line(
                overlay["midX"],
                overlay["height"],
                e.hpos2d["x"],
                e.hpos2d["y"],
                1,
                rgb("silver"),
            )

        if key_pressed(88) and ent_vecs:
            aim_bot(ent_vecs)

    overlay_deinit(overlay)


if __name__ == "__main__":
    main()
