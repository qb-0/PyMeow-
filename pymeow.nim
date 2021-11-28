#[
  PyMeow - Python Game Hacking Library
  Meow @ 2020
]#

import src/vector

when defined(windows):
  import src/windows/[
    memory,
    misc,
    overlay,
  ]

when defined(linux):
  import src/linux/[
    memory,
  ]

{. warning[UnusedImport]:off .}