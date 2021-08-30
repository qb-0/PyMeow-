from pymeow import enumerate_processes

for proc in enumerate_processes():
    print(f"[{proc['name']}] Process ID: {proc['pid']}")
    for module, module_data in proc["modules"].items():
        print(f"\t{module}: {hex(module_data['baseaddr'])} - {hex(module_data['baseaddr'] + module_data['basesize'])}")