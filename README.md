## PyMeow ([Discord](https://discord.gg/B34S4aMYqY))
#### Cross platform (Windows / Linux) Python Library for external Game Hacking

#### [Windows Cheatsheet / Features](https://github.com/qb-0/PyMeow/blob/master/cheatsheet.txt)

##### <ins>Installation / Usage</ins>
- Make sure you use a **64bit** version of Python 3
- Download the latest PyMeow Module from the ![Release Section](https://github.com/qb-0/PyMeow/releases)
- Extract the files and use pip to install PyMeow: `pip install .`

##### <ins>Compiling</ins>
- Download and install [nim](https://nim-lang.org/install.html) and [git for windows](https://gitforwindows.org/)
- (Windows) Install external dependencies: `nimble -y install pixie winim nimgl nimpy`
- (Linux) Install external dependencies: `nimble -y install pixie x11 nimgl opengl@#master nimpy`
- Clone and Compile: `git clone https://github.com/qb-0/PyMeow && cd PyMeow && nim c pymeow`

##### <ins>Linux</ins>
The linux version is still under progress but is ready to use and follows almost the windows api.
![Assault Cube ESP](https://github.com/qb-0/PyMeow/blob/master/examples/linux/ac_esp.py)
![CSGo ESP](https://github.com/qb-0/PyMeow/blob/master/examples/linux/csgo_esp.py)
![Sauerbraten ESP+Aimbot](https://github.com/qb-0/PyMeow/blob/master/examples/linux/sauerbraten_espaim.py)

## [CSGo ESP](https://github.com/qb-0/PyMeow/blob/master/examples/csgo_esp.py):
<img src="https://github.com/qb-0/PyMeow/blob/master/examples/screenshots/csgo_py.png" alt="alt text" width="650" height="450">

## [Assault Cube ESP](https://github.com/qb-0/PyMeow/blob/master/examples/ac_esp.py)
<img src="https://github.com/qb-0/PyMeow/blob/master/examples/screenshots/ac2_py.png" alt="alt text" width="650" height="450">

## [SWBF2 ESP](https://github.com/qb-0/PyMeow/blob/master/examples/swbf2_esp.py)
<img src="https://github.com/qb-0/PyMeow/blob/master/examples/screenshots/swbf_py.png" alt="alt text" width="650" height="450">

## [Cube2: Sauberbraten ESP + Aimbot](https://github.com/qb-0/PyMeow/blob/master/examples/sauerbraten_espaim.py)
[<img src="https://img.youtube.com/vi/7F_16FQURGc/maxresdefault.jpg" width="650" height="450">](https://youtu.be/7F_16FQURGc)

## [Healthbar](https://github.com/qb-0/PyMeow/blob/master/examples/healthbar.py)
![](https://github.com/qb-0/PyMeow/blob/master/examples/screenshots/healthbar.gif)

###### credits to: [nimpy](https://github.com/yglukhov/nimpy), [winim](https://github.com/khchen/winim), [nimgl](https://github.com/nimgl/nimgl), [GuidedHacking](https://guidedhacking.com)
