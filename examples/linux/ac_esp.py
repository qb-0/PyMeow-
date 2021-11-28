from pymeow import *


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
        self.pos2d = None


def main():
    mem = process_by_name("linux_64_client")
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
                        ent_obj.pos2d = wts_ogl(
                            overlay, matrix, ent_obj.pos3d
                        )
                    except:
                        continue

                    dashed_line(
                        overlay["midX"], 
                        overlay["midY"],
                        ent_obj.pos2d["x"] - 10,
                        ent_obj.pos2d["y"],
                        2,
                        rgb("blue") if ent_obj.team == 1 else rgb("red"),
                    )

                    circle(
                        ent_obj.pos2d["x"] - 10,
                        ent_obj.pos2d["y"],
                        3,
                        rgb("blue") if ent_obj.team == 1 else rgb("red"),
                    )

                    render_string_lines(
                        ent_obj.pos2d["x"],
                        ent_obj.pos2d["y"],
                        [
                            ent_obj.name,
                            f"Team: {ent_obj.team}",
                            f"Health: {ent_obj.health}",
                            f"Distance: {int(vec3_distance(ent_obj.pos3d, local_ent.pos3d))}"
                        ],
                        rgb("white")
                    )
    
    overlay_deinit(overlay)


if __name__ == "__main__":
    main()