HScript Folder Structure

Place HScript files here to automatically load them for specific game states.

Folder Structure:
/hscript/
  ├── global/          (Runs in ALL states)
  ├── PlayState/       (Only in gameplay)
  ├── MainMenuState/   (Only in main menu)
  ├── FreeplayState/   (Only in freeplay)
  └── [OtherState]/    (Other state classes)

File Extensions: .hx, .hscript, .hsc, .hxs

Import Support:
Use importScript("path/to/script") to import other HScript files.
Supports relative paths and automatic file extension detection.

HScript 文件夹结构

将 HScript 文件放在此处，以便在特定游戏状态中自动加载它们。

文件夹结构：
/hscript/
  ├── global/          (在所有状态中运行)
  ├── PlayState/       (仅在游戏中运行)
  ├── MainMenuState/   (仅在主菜单运行)
  ├── FreeplayState/   (仅在自由模式运行)
  └── [其他状态]/      (其他状态类)

文件扩展名: .hx, .hscript, .hsc, .hxs

导入支持：
使用 importScript("路径/到/脚本") 来导入其他 HScript 文件。
支持相对路径和自动文件扩展名检测。
（readme by DeepSeek lol）