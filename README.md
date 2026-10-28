# Custom Episodes

为 vivid/stasis 提供外部 JSON 剧情、自定义节点图和原版文本框播放的 VML/VSML 模组。

现在只有一套入口：

```text
主菜单 NODE FLOWCHART
  ├─ 普通确认          -> 原版 Node Flowchart
  └─ Shift + 确认      -> Custom Episodes
                            -> 选择自定义 node
                            -> scene_story
                            -> IceFrost Custom Episodes runtime
                            -> 结束 / 中途退出
                            -> 返回 Custom Episodes
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

剧情 JSON 使用 Custom Episodes 的 **`lines` 格式**：

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

## 节点图行为

- Shift + 确认只进入自定义 Node Flowchart，不再打开旧 picker。
- 普通确认仍进入原版 Node Flowchart。
- `requires[]`、`nav{}`、chapter 背景、Node Flow BGM 与同步 crossfade 继续由 Custom Episodes 负责。
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

## 读取旧剧情

旧版 `Custom Episodes/<剧集>/story.json` 可以直接保留，无需搬动文件或添加节点；重新进入自定义节点图后，未配置的旧剧集会自动追加到节点图中。

读取顺序：优先使用 `nodes.json` 配置及 `custom_story/episodes/<剧集>/story.json`，新版文件不存在时才回退到 `Custom Episodes/<剧集>/story.json`。同一剧集只显示一次，外部图片、音频和视频相对实际读取的剧情文件解析。旧版 JSON 的 `lines` 格式继续支持。

要自行配置旧剧情的节点位置、连线或标题，仍可在 `nodes.json` 中添加 `story: "episodes/<剧集>/story.json"`。

节点的 `requires` 定义连线，`nav` 定义方向键导航；章节背景、BGM 和渐变时间可参考随附的 `nodes.json`。节点标题、章节标签和简介分别来自 `title`、`episode` 和 `description`。
