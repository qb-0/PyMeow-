#[
  PyMeow - Python Game Hacking Library
  Meow @ 2020
]#

import src/[vector, shapes]

when defined(windows):
  import src/windows/[
    memory,
    misc,
    overlay,
  ]

when defined(linux):
  import src/linux/[
    memory,
    misc,
    overlay,
  ]

{. warning[UnusedImport]:off .}