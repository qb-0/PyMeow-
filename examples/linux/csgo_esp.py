from pymeow import *
from time import sleep


class Offsets:
    dwLocalPlayer = 0x22dd650
    dwEntityList = 0x230db08
    dwViewMatrix = 0x22e1ac4

    m_nForceBone = 0x2c54
    m_vecOrigin = 0x170
    m_bDormant = 0x125
    m_iHealth = 0x138
    m_iTeamNum = 0x12C


class Colors:
    orange = rgb("orange")
    cyan = rgb("cyan")
    black = rgb("black")
    white = rgb("white")


class Entity:
    def __init__(self, mem, addr, base, vm, ov):
        self.mem = mem
        self.addr = addr
        self.base = base
        self.vm = vm
        self.ov = ov

        self.head_pos3D = vec3()
        self.dormant = self.health = self.team = self.color = self.bone_matrix \
            = self.pos3D = self.pos2D = self.head_pos2D = None

    def update(self):
        self.dormant = read_bool(self.mem, self.addr + Offsets.m_bDormant)
        if self.dormant:
            return
        self.health = read_int(self.mem, self.addr + Offsets.m_iHealth)
        if self.health <= 0:
            return
        self.team = read_int(self.mem, self.addr + Offsets.m_iTeamNum)
        self.pos3D = read_vec3(self.mem, self.addr + Offsets.m_vecOrigin)
        try:
            self.pos2D = wts_dx(self.ov, self.vm, self.pos3D)
        except:
            return
        self.bone_matrix = read_int64(self.mem, self.addr + Offsets.m_nForceBone + 0x2C)
        self.head_pos3D["x"] = read_float(self.mem, self.bone_matrix + 0x30 * 8 + 0x0C)
        self.head_pos3D["y"] = read_float(self.mem, self.bone_matrix + 0x30 * 8 + 0x1C)
        self.head_pos3D["z"] = read_float(self.mem, self.bone_matrix + 0x30 * 8 + 0x2C)
        try:
            self.head_pos2D = wts_dx(self.ov, self.vm, self.head_pos3D)
        except:
            return
        self.color = Colors.orange if self.team == 2 else Colors.cyan
        return True

    def render_box(self):
        head = self.head_pos2D["y"] - self.pos2D["y"]
        width = head / 2
        center = width / -2

        corner_box(
            self.pos2D["x"] + center,
            self.pos2D["y"],
            width,
            head + 5,
            self.color,
            Colors.black
        )

    def render_health(self):
        head = self.head_pos2D["y"] - self.pos2D["y"]
        width = head / 2
        center = width / -2

        render_string(
            self.pos2D["x"],
            self.pos2D["y"] - 12,
            f"Health: {self.health}",
            Colors.white,
            True,
        )

        value_bar(
            self.pos2D["x"] + center - 5,
            self.pos2D["y"],
            self.pos2D["x"] + center - 5,
            self.head_pos2D["y"] + 5,
            2,
            100,
            self.health,
        )

    def render_snapline(self):
        dashed_line(
            self.ov["midX"],
            self.ov["height"],
            self.head_pos2D["x"],
            self.head_pos2D["y"],
            1,
            self.color,
            pattern="10101000111"
        )


def main():
    mem = process_by_name("csgo_linux64")
    client_base = mem["modules"]["client_client.so"]["baseaddr"]
    overlay = overlay_init(target="Counter-Strike: Global Offensive - OpenGL")

    while overlay_loop(overlay):
        local_addr = read_int64(mem, client_base + Offsets.dwLocalPlayer)
        if local_addr > 0:
            vm = read_floats(mem, client_base + Offsets.dwViewMatrix, 16)
            ent_buffer = read_ints64(mem, client_base + Offsets.dwEntityList + 32, 256)

            for i in range(1, 63):
                ent_addr = ent_buffer[i * 4]
                if ent_addr != 0 and ent_addr != local_addr:
                    ent = Entity(mem, ent_addr, client_base, vm, overlay)
                    if ent.update():
                        ent.render_box()
                        ent.render_health()
                        ent.render_snapline()

    overlay_deinit(overlay)


if __name__ == "__main__":
    main()
