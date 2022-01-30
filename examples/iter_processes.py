from pymeow import *

for proc in enumerate_processes():
    p = process_by_pid(proc["pid"])
    print(f"[{proc['name']} ({process_platform(p)}-bit)] Process ID: {proc['pid']}")
    for module, module_data in proc["modules"].items():
        print(
            f"\t{module}: {hex(module_data['baseaddr'])} - {hex(module_data['baseaddr'] + module_data['basesize'])}"
        )
    close(p)
