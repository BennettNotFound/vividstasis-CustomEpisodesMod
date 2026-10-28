# Custom Episodes × Custom Story Node Process

这是一个把 **冰霜的 Custom Episodes 剧情运行器** 接到 **Custom Story Node Process** 上的 VSML 版本。

现在只有一套入口：

```text
主菜单 NODE FLOWCHART
  ├─ 普通确认          -> 原版 Node Flowchart
  └─ Shift + 确认      -> Custom Story Node Process
                            -> 选择自定义 node
                            -> scene_story
                            -> IceFrost Custom Episodes runtime
                            -> 结束 / 中途退出
                            -> 返回 Custom Story Node Process
```

旧版 Custom Episodes 的独立 picker、F9 picker 和主菜单抢输入逻辑不再作为入口使用。

## 目录

```text
raw/custom_story/
├── nodes.json
├── episodes/
│   ├── _example/
│   │   ├── story.json
│   │   └── images/...
│   └── rainynight/
│       └── story.json
└── assets/
```

`nodes.json` 中每个 node 的 `story` 指向 `custom_story/` 下的剧情 JSON：

```json
{
  "id": "example_station",
  "chapter": "custom_a",
  "x": 8,
  "y": 0,
  "episode": "CUSTOM 01",
  "title": "示例：警局的一分钟",
  "story": "episodes/_example/story.json",
  "requires": []
}
```

剧情 JSON 使用冰霜 Custom Episodes 的 **`lines` 格式**，不是旧 Custom Story Node Process v0.1.8 的 `commands` 格式：

```json
{
  "title": "My Story",
  "bg": "bg_tg_precinct_int",
  "bgm": "bgs_story_road",
  "characters": {
    "sat": {
      "display_name": "Saturday",
      "color": "c_aqua",
      "portrait": "sat_neutral",
      "x": 350,
      "y": 140
    }
  },
  "lines": [
    { "kind": "narration", "text": "这是旁白。" },
    { "who": "sat", "text": "这是对白。" },
    { "kind": "end" }
  ]
}
```

## 保留的 Custom Episodes 功能

- 原版 textbox / fullscreen textbox
- 中文 / 日文自动换行
- `line` / `narration` / `clear` / `wait` / `delay`
- 背景、BGM、SE、BGM gain / stop
- tint / fade / flash
- resolution / highres / CG / hidegui
- portrait / change / bounce / move / flip / fade / hide / show
- 外部 PNG/JPG/GIF，路径相对当前 `story.json`
- 外部 OGG stream，路径相对当前 `story.json`
- `location` / `time` / `date`
- 视频过场（`video`）、视频尺寸检测和失败超时处理
- 谱面 gimmick：`custom_episode` 开始，`custom_episode_next` 按拍推进

## Node Process 行为

- Shift + 确认只进入自定义 Node Flowchart，不再打开旧 picker。
- 普通确认仍进入原版 Node Flowchart。
- `requires[]`、`nav{}`、chapter 背景、Node Flow BGM 与同步 crossfade 继续由 Custom Story Node Process 负责。
- node 启动剧情时把对应 `story` 文件交给 Custom Episodes coroutine runner。
- `end` / `goto` / `abort` 在 custom node 模式下返回 `scene_eventline`，不会掉回主菜单。
- 暂停菜单中途退出剧情也保留 custom mode，并回到自定义 Node Flowchart。
- 自定义 node 不写 vanilla `story_progress`，不覆盖原版 node 解锁状态。

## 写剧情

完整 `lines` 语法见 `docs/写作手册.md`（包内同时保留冰霜原始文档内容并针对 Node 入口做了说明）。资产名参考 `docs/asset-names.md`。

## 重要实现点

`o_mod_storyentry` 现在只是一个 persistent **剧情运行时服务**。它不再拥有主菜单入口。

`o_cutsceneConductor` 在 `global.custom_story_mode == true` 时执行：

```gml
coroutine = global.mod_cs_run_node_story();
```

否则仍执行原版：

```gml
coroutine = script_execute(global.load_scene);
```

原版剧情和自定义剧情分别使用各自的运行器。

## 迁移旧剧情

把原来的 `Custom Episodes/<剧集>/` 放到 `custom_story/episodes/<剧集>/`，在 `custom_story/nodes.json` 的 `nodes` 数组中添加节点，让 `story` 指向 `episodes/<剧集>/story.json`。外部图片、音频和视频仍相对该剧情 JSON 所在目录解析。修改配置后重新进入自定义节点图即可读取。

节点的 `requires` 定义连线，`nav` 定义方向键导航；章节背景、BGM 和渐变时间可参考随附的 `nodes.json`。节点标题、章节标签和简介分别来自 `title`、`episode` 和 `description`。
