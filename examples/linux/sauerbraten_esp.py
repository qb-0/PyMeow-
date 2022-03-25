import sys
from pymeow import *

try:
    mem = process_by_name("linux_64_client")
    base = mem["baseaddr"]
    overlay = overlay_init("Cube 2: Sauerbraten")
    local = None
except Exception as e:
    sys.exit(e)


class Offsets:
    EntityList = 0x5EDB70
    Local = 0x53A600
    PlayerCount = 0x5EDB7C
    ViewMatrix = 0x5D06E0

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
        self.fpos3d = vec3(self.hpos3d["x"], self.hpos3d["y"], self.hpos3d["z"] - 15)
        self.health = read_int(mem, addr + Offsets.Health)
        self.armor = read_int(mem, addr + Offsets.Armor)
        self.name = read_string(mem, addr + Offsets.Name)
        self.team = read_string(mem, addr + Offsets.Team)
        self.alive = read_byte(mem, addr + Offsets.State) == 0
        self.view_angles = read_vec2(mem, addr + Offsets.ViewAngles)
        self.color = None
        self.hpos2d = vec2()
        self.fpos2d = vec2()
        self.distance = 0.0

    def set_color(self):
        self.color = rgb("cyan") if self.team == local.team else rgb("red")

    def calc_wts(self, vm):
        try:
            self.hpos2d = wts_ogl(overlay, vm, self.hpos3d)
            self.fpos2d = wts_ogl(overlay, vm, self.fpos3d)
        except Exception as e:
            raise (e)

    def draw_box(self):
        head = self.fpos2d["y"] - self.hpos2d["y"]
        width = head / 1.7
        center = width / -2
        corner_box(
            self.hpos2d["x"] + center,
            self.hpos2d["y"],
            width,
            head + 5,
            self.color,
            rgb("black"),
            0.15,
        )

    def draw_health(self):
        head = self.fpos2d["y"] - self.hpos2d["y"]
        width = head / 1.7
        center = width / -2
        value_bar(
            self.fpos2d["x"] - center - 5,
            self.fpos2d["y"] + 5,
            self.fpos2d["x"] - center - 5,
            self.hpos2d["y"],
            2,
            150,
            self.health,
        )

    def draw_snapline(self):
        dashed_line(
            overlay["midX"],
            overlay["height"],
            self.hpos2d["x"] - 10,
            self.hpos2d["y"],
            1.5,
            self.color,
        )

    def draw_info(self):
        render_string(
            self.hpos2d["x"],
            self.hpos2d["y"] + 20,
            f"{self.name} ({self.distance})",
            rgb("white"),
            True,
        )


def get_ents():
    player_count = read_int(mem, base + Offsets.PlayerCount)
    if player_count > 1:
        ent_buffer = read_ints64(
            mem, read_int64(mem, base + Offsets.EntityList), player_count
        )

        try:
            global local
            local = Entity(ent_buffer[0])
        except:
            return

        for e in ent_buffer[1:]:
            try:
                ent = Entity(e)
                if ent.alive:
                    ent.distance = int(vec3_distance(local.hpos3d, ent.hpos3d) / 3)
                    yield ent
            except:
                continue


def main():
    while overlay_loop(overlay):
        vm = read_floats(mem, base + Offsets.ViewMatrix, 16)
        for e in get_ents():
            try:
                e.set_color()
                e.calc_wts(vm)
            except:
                continue

            e.draw_snapline()
            e.draw_box()
            e.draw_health()
            e.draw_info()


if __name__ == "__main__":
    main()
