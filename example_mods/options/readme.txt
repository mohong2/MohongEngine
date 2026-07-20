=== SeiunEngine 选项系统 - 模组扩展指南 ===

模组可以通过 JSON 文件向设置菜单添加选项。支持三种方式：

1. 向已有分类追加选项
2. 新增完整分类
3. 全局根目录（始终加载，不受当前模组影响）

> 重要存储机制：
> 模组选项（放在 mods/<modname>/options/ 下的）变量自动存入
> ClientPrefs.data.modSettings[模组名][变量名]
> 你不需要在 ClientPrefs 中预先声明变量，系统会自动管理
> 每个模组有独立的命名空间，不同模组间变量名不会冲突
> 全局根目录 mods/options/ 下的选项存入 modSettings['__GLOBAL__']

──────────────────────────────────────
1. 向已有分类追加选项
──────────────────────────────────────

在模组目录下创建 options/<分类ID>.json 或 options/<分类ID>.patch.json。
也支持目录模式：options/<分类ID>/*.json（所有文件合并加载）。

例如，向 Graphics 分类添加选项：
   mods/你的模组/options/graphics.json

或者拆分多个文件：
   mods/你的模组/options/graphics/
   ├── general.json
   ├── audio.json
   └── video.json

示例内容：
[
    {
        "nameKey": "option.myMod.mySetting",
        "defaultName": "My Custom Setting",
        "descKey": "option.myMod.mySetting.desc",
        "defaultDesc": "Description of my custom setting.",
        "variable": "myCustomVariable",
        "type": "bool",
        "defaultValue": false
    }
]

可用的内置分类 ID：
- graphics      - 图形设置
- visuals       - 视觉效果与 UI
- gameplay      - 游戏性设置
- extra_settings - 额外设置
- android_settings - Android 设置（仅移动端）

JSON 字段说明：
{
    "nameKey":       "语言文件中的键名（用于多语言）",
    "defaultName":   "默认显示名称（语言文件找不到时使用）",
    "descKey":       "语言文件中的描述键名",
    "defaultDesc":   "默认描述文本",
    "variable":      "变量名（模组选项自动存到 modSettings[模组名][此变量]）",
    "type":          "选项类型",
    "defaultValue":  "默认值",
    "showBoyfriend": true,      // 仅 bool 类型，是否显示男友角色
    "displayFormat": "%v FPS",  // 显示格式，%v=当前值，%d=默认值
    "minValue":      0,         // 最小值（int/float/percent）
    "maxValue":      100,       // 最大值（int/float/percent）
    "changeValue":   1,         // 单次步进值
    "scrollSpeed":   50,        // 按住时的滚动速度
    "decimals":      1,         // 小数位数（float/percent）
    "options":       ["A","B"], // 选项列表（string 类型）

    // ——— 回调（三选一或组合使用） ———
    "onChange":      "函数名",           // (1) Haxe 回调函数名（需通过 setCallback 注册）
    "onChangeLua":   "scripts/handler.lua",  // (2) 直接执行 Lua 脚本（路径相对 mod 目录）
    "onChangeHscript": "scripts/handler.hx", // (3) 直接执行 HScript 脚本（路径相对 mod 目录）

    "platform":      "desktop", // 平台限制：desktop/mobile/html5，不填则全平台
    "define":        "CHECK_FOR_UPDATES", // 编译标志条件
    "useModSettings": false     // 强制使用 modSettings 存储（即使非模组选项）
}

脚本回调机制：
- onChangeLua / onChangeHscript 指向的脚本文件会在选项值变更时被执行
- 脚本中可以定义 onOptionChange(variable, value) 函数来接收选项变化
- 脚本全局可访问 optionVariable（变量名）和 optionValue（当前值）
- 路径规则：模组选项相对 mods/<模组名>/ 目录，支持绝对路径
- 三个回调可以同时使用，会按 onChange → onChangeLua → onChangeHscript 顺序执行

示例 Lua 脚本（scripts/handler.lua）：
    function onOptionChange(variable, value)
        debugPrint("Option changed: " .. variable .. " = " .. tostring(value))
    end

示例 HScript 脚本（scripts/handler.hx）：
    function onOptionChange(variable, value) {
        trace('Option changed: ' + variable + ' = ' + value);
    }

注意：
- variable 是模组内唯一的变量名，不同模组可以有相同的 variable 名
- 系统会自动在 ClientPrefs.data.modSettings[模组名][variable] 中存取
- 模组选项设置会自动保存，无需额外代码

支持的 type 类型：
- bool      - 开关（复选框）
- int       - 整数（左右调节）
- float     - 浮点数
- percent   - 百分比（0.0~1.0 自动换算为 0%~100%）
- string    - 字符串（从 options 数组中循环选择）
- button    - 按钮（按下执行回调）

──────────────────────────────────────
2. 新增分类
──────────────────────────────────────

在模组目录下创建 options/categories.json。

示例内容：
[
    {
        "id": "my_mod_settings",
        "nameKey": "option.myMod.category",
        "defaultName": "My Mod Settings",
        "type": "settings",
        "optionsFile": "my_mod_settings"
    }
]

optionsFile 支持两种方式：

方式 A — 单文件：
   mods/你的模组/options/my_mod_settings.json

方式 B — 目录（推荐，可拆分多个 JSON）：
   mods/你的模组/options/my_mod_settings/
   ├── general.json
   ├── audio.json
   └── video.json
   所有 .json 文件按文件名排序合并加载。

示例（single file）：
[
    {
        "nameKey": "option.myMod.someSetting",
        "defaultName": "Some Setting",
        "descKey": "option.myMod.someSetting.desc",
        "defaultDesc": "Description.",
        "variable": "someVariable",
        "type": "bool",
        "defaultValue": false
    }
]

注：模组自建分类的选项也自动使用 modSettings 存储，无需额外配置。

分类 type 说明：
- "settings"  - 标准设置页（optionsFile 指向 JSON 文件或目录）
- "substate"  - 打开 ModSubState（substateClass 为脚本名，如 "MyPage"）
- "state"     - 打开 ModState（stateClass 为脚本名，如 "MyPage"）

模组分类的 substate/state 自动使用 ModSubState/ModState 脚本驱动，
内置分类优先使用编译类，失败则回退 ModSubState/ModState。

示例 - SubState（模组脚本驱动）：
{
    "id": "my_script_page",
    "nameKey": "option.myMod.scriptPage",
    "defaultName": "Script Page",
    "type": "substate",
    "substateClass": "MyCustomSubState"
}

示例 - State（模组脚本驱动）：
{
    "id": "my_script_state",
    "nameKey": "option.myMod.scriptState",
    "defaultName": "Script State",
    "type": "state",
    "stateClass": "MyCustomState"
}

──────────────────────────────────────
3. 全局根目录（mods/options/）
──────────────────────────────────────

options/ 根目录下的文件始终被加载，不受当前激活模组的影响。
适合放置所有模组共享的选项。

  mods/options/categories.json     ← 全局分类定义
  mods/options/<分类ID>.json       ← 全局选项
  mods/options/<分类ID>/*.json     ← 全局选项（目录模式）

全局根目录的选项存储在 modSettings['__GLOBAL__'] 命名空间。

──────────────────────────────────────
4. 回调注册
──────────────────────────────────────

如果选项需要特殊行为（如切换窗口模式、重启音效等），
模组可以注册自己的回调函数。在 HScript 中：

OptionLoader.setCallback("onMyCustomAction", function() {
    // 你的逻辑
});

JSON 中引用：
{
    "onChange": "onMyCustomAction"
}

──────────────────────────────────────
5. 热重载
──────────────────────────────────────

修改 mods/options/ 下的 JSON 文件后，退出再进入设置菜单即可生效，
无需重启游戏。每次打开设置菜单和从子页面返回时都会重新加载配置。

──────────────────────────────────────
6. 注意事项
──────────────────────────────────────

- 模组选项的 variable 自动使用 modSettings[模组名][variable] 存储，
  不会与内置 ClientPrefs.data 变量冲突，无需修改 ClientPrefs.hx。
- 向已有分类追加选项可用 .patch.json 后缀，例如 graphics.patch.json。
- 模组自建分类的选项文件放在模组自己的 options/ 目录下。
- 建议在 pack.json 中设置 "runsGlobally": true 让模组的选项目录始终可用。
- 全局根目录（mods/options/）始终加载，无需任何配置。