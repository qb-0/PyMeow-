from pymeow import *

DEBUG = True


class Pointer:
    player_count = 0x187C18
    entity_list = 0x187C10
    local_player = 0x187C0C
    view_matrix = 0x17AFE0


class Offsets:
    name = 0x205
    health = 0xEC
    armor = 0xF0
    team = 0x30C
    pos = 0x4


class Entity:
    def __init__(self, addr, mem):
        self.mem = mem
        self.addr = addr

        self.info = dict()
        self.update()

    def update(self):
        self.info = {
            "name": read_string(self.mem, self.addr + Offsets.name),
            "hp": read_int(self.mem, self.addr + Offsets.health),
            "team": read_int(self.mem, self.addr + Offsets.team),
            "armor": read_int(self.mem, self.addr + Offsets.armor),
            "pos3d": read_vec3(self.mem, self.addr + Offsets.pos),
            "pos2d": vec2(),
        }


def main():
    mem = process_by_name("ac_client.exe", DEBUG)
    base = mem["modules"]["ac_client.exe"]["baseaddr"]
    overlay = overlay_init("AssaultCube")
    font = font_init(10, "Tahoma")
    set_foreground("AssaultCube")

    while overlay_loop(overlay):
        player_count = read_int(mem, base + Pointer.player_count)

        if player_count > 1:
            try:
                local_ent = Entity(read_int(mem, base + Pointer.local_player), mem)
                v_matrix = read_floats(mem, base + Pointer.view_matrix, 16)
            except:
                continue

            ent_buffer = read_ints(
                mem, read_int(mem, base + Pointer.entity_list), player_count
            )[1:]
            for addr in ent_buffer:
                try:
                    ent_obj = Entity(addr, mem)
                    ent_obj.info["pos2d"] = wts_ogl(
                        overlay, v_matrix, ent_obj.info["pos3d"]
                    )
                except:
                    continue

                if ent_obj.info["pos2d"] and ent_obj.info["hp"] > 0:
                    circle(
                        ent_obj.info["pos2d"]["x"] - 10,
                        ent_obj.info["pos2d"]["y"],
                        3,
                        rgb("blue") if ent_obj.info["team"] == 1 else rgb("red"),
                        False,
                    )
                    font_print_lines(
                        font,
                        ent_obj.info["pos2d"]["x"],
                        ent_obj.info["pos2d"]["y"],
                        [
                            ent_obj.info["name"],
                            f"Team: {ent_obj.info['team']}",
                            f"Health: {ent_obj.info['hp']}",
                            f"Armor:  {ent_obj.info['armor']}",
                            f"Distance:  {int(vec3_distance(ent_obj.info['pos3d'], local_ent.info['pos3d']))}",
                        ],
                        rgb("white"),
                    )

    overlay_deinit(overlay)
    close(mem)


if __name__ == "__main__":
    main()
