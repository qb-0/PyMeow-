import sys
from pymeow import *


class Offsets:
    GameRenderer = 0x143FFBE10
    RenderView = 0x538
    ViewProj = 0x430
    ClientGameContext = 0x143DD7948
    PlayerManager = 0x58
    LocalPlayer = 0x568
    ClientArray = 0x768
    Team = 0x58
    ControlledControllable = 0x210
    HealthComponent = 0x2C8
    Height = 0x470
    SoldierPrediction = 0x758
    Occluded = 0xA58
    Health = 0x20
    Position = 0x20


try:
    mem = process_by_name("starwarsbattlefrontii.exe")
    render_view = read_int(
        mem, read_int(mem, Offsets.GameRenderer) + Offsets.RenderView
    )
    game_context = read_int(mem, Offsets.ClientGameContext)
    player_manager = read_int(mem, game_context + Offsets.PlayerManager)
    client_array = read_int(mem, player_manager + Offsets.ClientArray)
    overlay = overlay_init()
except Exception as e:
    sys.exit(e)


def wts(pos, vm):
    w = vm[3] * pos["x"] + vm[7] * pos["y"] + vm[11] * pos["z"] + vm[15]
    if w < 0.3:
        raise Exception("WTS")

    x = vm[0] * pos["x"] + vm[4] * pos["y"] + vm[8] * pos["z"] + vm[12]
    y = vm[1] * pos["x"] + vm[5] * pos["y"] + vm[9] * pos["z"] + vm[13]

    return vec2(
        overlay["midX"] + overlay["midX"] * x / w,
        overlay["midY"] + overlay["midY"] * y / w,
    )


class Entity:
    def __init__(self, addr):
        self.addr = addr
        self.team = 0
        self.health = 0
        self.height = 0.0
        self.pos3d = None
        self.headpos3d = None
        self.pos2d = None
        self.headpos2d = None
        self.visible = False
        self.alive = False

    def read(self):
        self.team = read_int(mem, self.addr + Offsets.Team)

        controlled = read_int64(mem, self.addr + Offsets.ControlledControllable)
        if controlled < 0:
            return

        try:
            health_comp = read_int64(mem, controlled + Offsets.HealthComponent)
        except:
            return

        self.height = read_float(mem, controlled + Offsets.Height)
        self.health = read_float(mem, health_comp + Offsets.Health)
        self.alive = self.health > 0
        if not self.alive:
            return

        try:
            soldier = read_int64(mem, controlled + Offsets.SoldierPrediction)
            self.pos3d = read_vec3(mem, soldier + Offsets.Position)
            self.headpos3d = vec3(
                self.pos3d["x"], self.pos3d["y"] + self.height - 18.5, self.pos3d["z"]
            )
        except:
            return

        self.visible = read_byte(mem, controlled + Offsets.Occluded) == 0

        return self


def ent_loop():
    if client_array:
        clients = read_ints64(mem, client_array, 64 * 2)
        for ent_addr in clients:
            if ent_addr:
                try:
                    e = Entity(ent_addr).read()
                except:
                    continue

                if e:
                    yield e


def main():
    set_foreground("STAR WARS Battlefront II")
    while overlay_loop(overlay):
        local_player = read_int64(mem, player_manager + Offsets.LocalPlayer)
        local_player = Entity(local_player).read()

        if local_player:
            for ent in ent_loop():
                if ent.team == local_player.team:
                    continue

                vm = read_floats(mem, render_view + Offsets.ViewProj, 16)

                try:
                    ent.pos2d = wts(ent.pos3d, vm)
                    ent.headpos2d = wts(ent.headpos3d, vm)
                except:
                    continue

                head = ent.headpos2d["y"] - ent.pos2d["y"]
                width = head / 2
                center = width / -2
                alpha_box(
                    ent.pos2d["x"] + center,
                    ent.pos2d["y"],
                    width,
                    head + 5,
                    rgb("green") if ent.visible else rgb("red"),
                    rgb("black"),
                    0.15,
                )


    overlay_deinit(overlay)


if __name__ == "__main__":
    main()
