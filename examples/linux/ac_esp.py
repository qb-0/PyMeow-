from pymeow import *

DEBUG = True

class Pointer:
    entity_list = 0x12E330
    local_player = 0x12E328
    view_matrix = 0x13D3DC


class Offsets:
    name = 0x23D
    health = 0x110
    team = 0x344
    pos = 0x8


class Entity:
    def __init__(self, addr, mem):
        self.mem = mem
        self.addr = addr

        self.name = read_string(self.mem, self.addr + Offsets.name)
        self.health = read_int(self.mem, self.addr + Offsets.health)
        self.team = read_int(self.mem, self.addr + Offsets.team)
        self.pos3d = read_vec3(self.mem, self.addr + Offsets.pos)
        self.color = rgb("cyan") if self.team == 1 else rgb("red")
        self.pos2d = None

    def render_info(self, local):
        render_string_lines(
            self.pos2d["x"],
            self.pos2d["y"],
            [
                self.name,
                f"Team: {self.team}",
                f"Health: {self.health}",
                f"Distance: {int(vec3_distance(self.pos3d, local.pos3d))}",
            ],
            rgb("white"),
        )

    def render_snapline(self, overlay):
        dashed_line(
            overlay["midX"],
            overlay["midY"],
            self.pos2d["x"] - 10,
            self.pos2d["y"],
            1.5,
            self.color
        )

    def render_circle(self):
        circle(
            self.pos2d["x"] - 10,
            self.pos2d["y"],
            3,
            self.color,
        )


def main():
    mem = process_by_name("linux_64_client", DEBUG)
    base = mem["baseAddr"]
    overlay = overlay_init("AssaultCube")
    entity_list = read_int(mem, base + Pointer.entity_list)

    while overlay_loop(overlay):
        local_player_addr = read_int(mem, base + Pointer.local_player)
        local_ent = Entity(local_player_addr, mem)
        matrix = read_floats(mem, base + Pointer.view_matrix, 16)

        for i in range(31):
            ent_addr = read_int(mem, entity_list + i * 8)
            if ent_addr != 0 and ent_addr != local_player_addr:
                ent_obj = Entity(ent_addr, mem)
                if ent_obj.health > 0:
                    try:
                        ent_obj.pos2d = wts_ogl(overlay, matrix, ent_obj.pos3d)
                    except:
                        continue

                    ent_obj.render_snapline(overlay)
                    ent_obj.render_info(local_ent)
                    ent_obj.render_circle()

    overlay_deinit(overlay)


if __name__ == "__main__":
    main()
