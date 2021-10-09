import sys
from pymeow import *
from requests import get


class Offsets:
    pass


class Colors:
    white = rgb("white")
    black = rgb("black")
    blue = rgb("blue")
    red = rgb("red")
    cyan = rgb("cyan")
    orange = rgb("orange")
    silver = rgb("silver")


class Entity:
    def __init__(self, addr, mem, gmod):
        self.wts = None
        self.addr = addr
        self.mem = mem
        self.gmod = gmod

        self.id = read_int(self.mem, self.addr + 0x64)
        self.health = read_int(self.mem, self.addr + Offsets.m_iHealth)
        self.dormant = read_int(self.mem, self.addr + Offsets.m_bDormant)
        self.team = read_int(self.mem, self.addr + Offsets.m_iTeamNum)
        self.bone_base = read_int(self.mem, self.addr + Offsets.m_dwBoneMatrix)
        self.pos = read_vec3(self.mem, self.addr + Offsets.m_vecOrigin)

    @property
    def name(self):
        radar_base = read_int(self.mem, self.gmod + Offsets.dwRadarBase)
        hud_radar = read_int(self.mem, radar_base + 0x78)
        return read_string(self.mem, hud_radar + 0x300 + (0x174 * (self.id - 1)))

    def bone_pos(self, bone_id):
        return vec3(
            read_float(self.mem, self.bone_base + 0x30 * bone_id + 0x0C),
            read_float(self.mem, self.bone_base + 0x30 * bone_id + 0x1C),
            read_float(self.mem, self.bone_base + 0x30 * bone_id + 0x2C),
        )

    def glow(self):
        """
        Should be used in a thread.
        """
        glow_addr = (
            read_int(self.mem, self.gmod + Offsets.dwGlowObjectManager)
            + read_int(self.mem, self.addr + Offsets.m_iGlowIndex) * 0x38
        )

        color = Colors.cyan if self.team != 2 else Colors.orange
        write_floats(self.mem, glow_addr + 4, color + [1.5])
        write_bytes(self.mem, glow_addr + 0x24, [1, 0])


def trigger_bot(mem, local, ent):
    cross = read_int(mem, local.addr + Offsets.m_iCrosshairId)
    if cross == ent.id and ent.team != local.team:
        mouse_click()


def main():
    try:
        # Credits to https://github.com/frk1/hazedumper
        haze = get("https://raw.githubusercontent.com/frk1/hazedumper/master/csgo.json").json()

        [setattr(Offsets, k, v) for k, v in haze["signatures"].items()]
        [setattr(Offsets, k, v) for k, v in haze["netvars"].items()]
    except:
        sys.exit("Unable to fetch Hazedumper's Offsets")

    csgo_proc = process_by_name("csgo.exe")
    game_module = csgo_proc["modules"]["client.dll"]["baseaddr"]
    overlay = overlay_init() # Windowed Fullscreen
    font = font_init(10, "Tahoma")
    set_foreground("Counter-Strike: Global Offensive")

    while overlay_loop(overlay):
        try:
            local_player_addr = read_int(csgo_proc, game_module + Offsets.dwLocalPlayer)
            local_ent = Entity(local_player_addr, csgo_proc, game_module)
        except:
            # No local player
            continue

        if local_player_addr:
            ent_addrs = read_ints(csgo_proc, game_module + Offsets.dwEntityList, 128)[0::4]
            view_matrix = read_floats(csgo_proc, game_module + Offsets.dwViewMatrix, 16)
            for ent_addr in ent_addrs:
                if ent_addr > 0 and ent_addr != local_player_addr:
                    ent = Entity(ent_addr, csgo_proc, game_module)
                    if not ent.dormant and ent.health > 0:
                        try:
                            ent.wts = wts_dx(overlay, view_matrix, ent.pos)
                            # ent.glow()
                            head_pos = wts_dx(overlay, view_matrix, ent.bone_pos(8))
                            head = head_pos["y"] - ent.wts["y"]
                            width = head / 2
                            center = width / -2

                            corner_box(
                                ent.wts["x"] + center,
                                ent.wts["y"],
                                width,
                                head + 5,
                                Colors.cyan if ent.team != 2 else Colors.red,
                                Colors.black,
                                0.15,
                            )
                            value_bar(
                                ent.wts["x"] + center - 5,
                                ent.wts["y"],
                                ent.wts["x"] + center - 5,
                                head_pos["y"] + 5,
                                2,
                                100, ent.health
                            )
                            font_print(
                                font,
                                ent.wts["x"] - len(ent.name) * 1.5,
                                ent.wts["y"] - 10,
                                ent.name,
                                Colors.white,
                            )
                            font_print(
                                font,
                                ent.wts["x"] - 2,
                                ent.wts["y"] - 20,
                                str(int(vec3_distance(ent.pos, local_ent.pos) / 20)),
                                Colors.white,
                            )
                            dashed_line(
                                overlay["midX"],
                                overlay["midY"],
                                ent.wts["x"],
                                ent.wts["y"],
                                1,
                                Colors.silver,
                            )
                            trigger_bot(csgo_proc, local_ent, ent)
                        except:
                            pass
    
    overlay_deinit(overlay)


if __name__ == "__main__":
    main()
