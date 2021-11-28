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
{. warning[UnusedImport]:off .}