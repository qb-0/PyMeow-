from pymeow import *

"""
Example:
mem = Memory("linux_64_client", True)
print(mem.read(0x0000000005BACD38, "int"))
mem.write(0x0000000005BACD38, "int", 10)
print(mem.read(0x0000000005BACD38, "int"))
"""


class Memory:
    def __init__(self, process_name, debug=False):
        self.read_switch = {
            "int": read_int,
            "ints": read_ints,
            "int16": read_int16,
            "ints16": read_ints16,
            "int64": read_int64,
            "ints64": read_ints64,
            "uint": read_uint,
            "uints": read_uints,
            "uint64": read_uint64,
            "uints64": read_uint64,
            "float": read_float,
            "floats": read_floats,
            "float64": read_float64,
            "floats64": read_floats64,
            "byte": read_byte,
            "bytes": read_bytes,
            "vec2": read_vec2,
            "vec3": read_vec3,
            "bool": read_bool,
            "string": read_string,
        }

        self.write_switch = {
            "int": write_int,
            "ints": write_ints,
            "int16": write_int16,
            "ints16": write_ints16,
            "int64": write_int64,
            "ints64": write_ints64,
            "float": write_float,
            "floats": write_floats,
            "float64": write_float64,
            "floats64": write_floats64,
            "byte": write_byte,
            "bytes": write_bytes,
            "vec2": write_vec2,
            "vec3": write_vec3,
            "bool": write_bool,
            "string": write_string,
        }

        try:
            self.process = process_by_name(process_name, debug)
        except:
            raise Exception(f"Process {process_name} not found")

    def read(self, addr, type_str, size=1):
        type_str = type_str.lower()
        r_proc = self.read_switch.get(type_str, "")
        if not r_proc:
            raise Exception(f"Unknown data type {type_str}")

        if "s" in type_str and type_str != "string":
            return r_proc(self.process, addr, size)
        return r_proc(self.process, addr)

    def write(self, addr, type_str, data):
        type_str = type_str.lower()
        w_proc = self.write_switch.get(type_str, "")
        if not w_proc:
            raise Exception(f"Unknown data type {type_str}")

        w_proc(self.process, addr, data)
