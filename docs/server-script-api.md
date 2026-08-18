# SeiunEngine 服务端 HScript API

服务端脚本放在 `server/scripts/` 或 `mods/server/`，扩展名 `.hx` 或 `.hscript`。

## 可用对象

- `server`：`online.server.SeiunServer`（高级用法）
- `api`：受限 API，当前方法：
  - `api.log(text)`
  - `api.rooms()` → `[{code,name,players,mode}]`
  - `api.announce(text)`
  - `api.setRoomPassword(code, password)`
  - `api.setRoomAnticheat(code, enabled)`

## 钩子

| 钩子 | 参数 |
|---|---|
| `onInit` | 无 |
| `onRoomCreate` | `code, name, host` |
| `onPlayerJoin` | `code, nickname, id` |
| `onPlayerLeave` | `code, nickname, id, reason` |
| `onInput` | `code, nickname, lane, pressed, songTime` |
| `onJudge` | `code, nickname, judge` |
| `onChat` | `code, nickname, text` |
| `onModSync` | `code, nickname, event, detail`（event: `manifest` / `complete` / `failed`） |
| `onGameStart` | `code` |
| `onGameEnd` | `code` |

## 安全模型

- 服务端脚本是服主可信代码，客户端脚本绝不会上传到服务端执行。
- 默认黑名单：`sys.io.File`、`sys.io.Process`、`sys.net.Socket`、`sys.net.UdpSocket`、`haxe.Http`。
- Lua 服务端脚本仅原生 C++ 构建可接入（linc_luajit）；Node 目标不支持 Lua。

## 示例

见 `server/scripts/example.hx`：

```haxe
function onChat(code, nickname, text) {
    if (text == "!help") api.announce("可用命令: !help");
}
```
