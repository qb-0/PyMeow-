#[
  PyMeow - Python Game Hacking Library
  Meow @ 2020
]#
when defined(windows):
  import src/windows/[
    memory,
    misc,
    overlay,
    vector
  ]

when defined(linux):
  import src/linux/[
    memory,
    vector
  ]
{. warning[UnusedImport]:off .}