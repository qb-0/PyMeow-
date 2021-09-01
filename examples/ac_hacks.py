from pymeow import *


class Pointer:
    local_player = 0x00509B74


class Offsets:
    health = 0xF8
    armor = 0xFC
    rifle_ammo = 0x150
    rifle_clip = 0x128
    pistol_ammo = 0x13C
    pistol_clip = 0x114
    nades = 0x158
    recoil = 0xEE444


def main():
    ac_proc = process_by_name("ac_client.exe")
    ac_base = ac_proc["baseaddr"]
    local_addr = read_int(ac_proc, Pointer.local_player)

    # No Recoil
    patch_bytes(ac_proc, ac_base + Offsets.recoil, [0, 0, 0, 0])

    # Health / Armor / Ammo
    write_int(ac_proc, local_addr + Offsets.health, 1337)
    write_int(ac_proc, local_addr + Offsets.armor, 1337)
    write_int(ac_proc, local_addr + Offsets.rifle_ammo, 1337)
    write_int(ac_proc, local_addr + Offsets.rifle_clip, 1337)
    write_int(ac_proc, local_addr + Offsets.pistol_ammo, 1337)
    write_int(ac_proc, local_addr + Offsets.pistol_clip, 1337)
    write_int(ac_proc, local_addr + Offsets.nades, 1337)

    # No decrement of ammo
    ammo_dec = aob_scan(
        ac_proc,
        "FF 0E 57 8B 7C 24 14 8D 74 24 28 E8 ? ? ? ? 5F 5E B0 01 5B 8B E5 5D C2 04 00 CC CC CC CC CC CC CC CC CC CC CC CC 55",
        ac_proc["modules"]["ac_client.exe"],
    )
    if ammo_dec:
        nop_code(ac_proc, ammo_dec, 2)

    # Rapid fire
    rapid_fire = aob_scan(
        ac_proc, "89 0A 8B 76 14", ac_proc["modules"]["ac_client.exe"]
    )
    if rapid_fire:
        nop_code(ac_proc, rapid_fire, 2)

    close(ac_proc)


if __name__ == "__main__":
    main()
