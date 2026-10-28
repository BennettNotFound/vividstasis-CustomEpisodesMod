# Custom Episodes

本项目基于 [Frollsy/vividstasis-CustomEpisodesMod](https://github.com/Frollsy/vividstasis-CustomEpisodesMod) 修改。此 README **主要介绍 Fork 新增与调整的行为**；剧情指令的完整说明见 [`docs/写作手册.md`](docs/写作手册.md)，资产名称见 [`docs/asset-names.md`](docs/asset-names.md)。

> [!NOTE]
> 现在的入口是 **NODE FLOWCHART + Shift + 确认**，不是旧版的独立 picker。主菜单输入已经够乱了，没必要再让两个选择器互相抢键。

## 0x00 · 入口与流程

```text
主菜单 · NODE FLOWCHART
  ├─ 普通确认             → 原版 Node Flowchart
  └─ Shift + 确认         → Custom Episodes
                              │
                              ├─ 读取 nodes.json / 兼容旧剧集
                              ├─ 选择自定义 node
                              └─ scene_story
                                  → IceFrost Custom Episodes runtime
                                  → end / goto / abort / 中途退出
                                  → scene_eventline（自定义模式）
                                  → 返回 Custom Episodes
```

**原版 Node Flowchart 没被替换。** 普通确认照常进入原版流程图；只有按住 `Shift` 再确认，才进入自定义节点图。确认键遵循游戏本身的输入绑定，而不是要求所有玩家必须按 Enter。

旧版 **独立 picker、F9 picker、主菜单抢输入逻辑** 不再作为入口。它们属于旧实现，不是这版的使用方式。

## 0x01 · Fork 改了什么

| 部分 | 原 Custom Episodes | 当前 Fork |
| --- | --- | --- |
| 剧集入口 | 主菜单快捷键 / 独立 picker | `NODE FLOWCHART` 上按 `Shift + 确认` |
| 剧集选择 | 文件夹列表 | 自定义 Node Flowchart，支持节点位置、连线与方向导航 |
| 节点配置 | 无独立节点配置 | `custom_story/nodes.json` |
| 章节显示 | 以剧集列表为主 | 章节背景、Node Flow BGM、同步 crossfade |
| 剧情运行 | Custom Episodes JSON runner | 由自定义 node 进入 `scene_story`，交给独立 coroutine runner |
| 剧情结束 | 返回主菜单 | 返回 `scene_eventline` 的自定义节点图 |
| 中途退出 | 旧版退出逻辑 | 暂停菜单退出后仍保留 custom mode，返回自定义节点图 |
| 旧剧集 | `Custom Episodes/<剧集>/story.json` | 保留兼容，未配置的旧剧集自动追加为节点 |
| 原版进度 | 与原版进度隔离 | 继续隔离，不写 vanilla `story_progress` |

核心变化不是多了个界面，而是**入口、节点状态、剧情执行和返回路径被接到同一条流程上**。否则进得去、退不回来，这种功能也只能叫半成品。

## 0x02 · 安装与文件位置

将本模组放进 VML / VSML 的 `mods/` 目录，并使用模组加载器应用补丁。模组文件夹名称按实际发行包为准，以下使用 `custom_episodes` 示意：

```text
VML/
├── vividstasisModLoader.exe
├── path.json
└── mods/
    └── custom_episodes/
        ├── codepatches.json
        ├── codes/
        ├── docs/
        ├── raw/
        │   └── custom_story/
        │       ├── nodes.json
        │       ├── episodes/
        │       └── assets/
        └── README.md
```

`path.json` 的 `game_path` 需要指向实际游戏目录。VML 会将 `raw/` 中的内容部署到游戏目录；**剧情 JSON 与资源的修改不需要每次重新编译 GML 补丁**。重新进入自定义节点图即可重新读取相关剧情文件。

部署后的主要内容：

```text
<游戏目录>/
├── custom_story/
│   ├── nodes.json
│   ├── episodes/
│   │   ├── _example/
│   │   │   ├── story.json
│   │   │   └── images/
│   │   └── rainynight/
│   │       └── story.json
│   └── assets/
└── Custom Episodes/              # 可选：旧版剧集兼容目录
    └── <旧剧集>/
        └── story.json
```

> [!IMPORTANT]
> `raw/` 是模组包内的部署目录，`custom_story/` 和 `Custom Episodes/` 才是游戏读取的实际目录。别把模组包路径和游戏运行路径混成一回事。

## 0x03 · 配置自定义节点

节点由 `custom_story/nodes.json` 管理。以下是**单个 node 的配置示例**，不是整个 `nodes.json` 的完整外层结构；文件顶层组织和章节配置请参考模组附带的 `nodes.json`。

```json
{
  "id": "example_station",
  "chapter": "custom_a",
  "x": 8,
  "y": 0,
  "episode": "CUSTOM 01",
  "title": "示例：警局的一分钟",
  "description": "一段发生在警局的短篇剧情。",
  "story": "episodes/_example/story.json",
  "requires": []
}
```

| 字段 | 用途 |
| --- | --- |
| `id` | 自定义 node 的标识 |
| `chapter` | 所属自定义章节 |
| `x` / `y` | 节点在流程图中的坐标 |
| `episode` | 节点的章节标签 |
| `title` | 节点标题 |
| `description` | 节点简介 |
| `story` | 剧情 JSON 路径，相对 `custom_story/` |
| `requires[]` | 节点之间的关联 / 连线配置 |
| `nav{}` | 方向键导航关系 |

章节背景、Node Flow BGM 与渐变时间也由 `nodes.json` 配置。具体字段与结构以随包示例为准，不要凭空猜一套配置格式然后指望 GameMaker 替你理解。

选择节点后，模组把该节点的 `story` 交给 Custom Episodes coroutine runner，在 `scene_story` 中播放。**不会把它伪装成原版节点，更不会写入原版剧情解锁进度。**

## 0x04 · 写一个 `story.json`

在 `custom_story/episodes/<剧集名>/` 下创建 `story.json`：

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

`lines` 是 Custom Episodes 的剧情步骤数组：`who` 引用 `characters` 中定义的角色；未指定 `kind` 的普通对白可以直接写 `who` 和 `text`。完整字段、参数、原版富文本标签和换行规则参见 [`docs/写作手册.md`](docs/写作手册.md)。

### 主要支持的指令

| 类型 | 指令 / 功能 |
| --- | --- |
| 文本 | `line`、`narration`、`clear`、`wait`、`delay`、原版 textbox / fullscreen textbox |
| 排版 | 中文 / 日文自动换行、手动 `\n`、逐行 `wrap` / `width` |
| 场景与音频 | `bg`、`bgm`、`se`、`bgm_gain`、`bgm_stop` |
| 画面 | `tint`、`fade`、`flash`、`resolution`、`highres`、`cg`、`hidegui` |
| 角色 | `portrait`、`change`、`bounce`、`move`、`flip`、`portrait_fade`、`hide`、`show`、`portrait_clear` |
| 信息 | `location`、`time`、`date` |
| 过场 | `video`，包含尺寸检测、跳过控制与播放失败超时处理 |
| 流程 | `end`、`goto`、`abort` |

资源处理规则：

- 内置背景、立绘、BGM、SE 可以直接使用游戏资产名。
- 外部 `PNG` / `JPG` / `JPEG` / `GIF` 图片，以及 `OGG` 音频，以**实际读取的 `story.json` 所在目录**为相对路径基准。
- 视频使用 `video` 指令；具体参数、格式兼容性与播放行为参见写作手册。
- 剧情使用原版文字绘制系统，不需要重新造一个 textbox。那个轮子已经够多了。

### 返回节点图

在**自定义 node 模式**下，`end`、`goto`、`abort` 都会结束当前剧情并返回 `scene_eventline`，而不是跳回主菜单。

从暂停菜单中途退出同样保留自定义模式，回到 **Custom Episodes** 节点图。普通原版剧情不走这套自定义 runner。

## 0x05 · 旧剧集兼容

旧版目录不需要整体搬迁，也不需要为了显示在节点图上给每个剧集手工加 node：

```text
Custom Episodes/
└── rainy_night/
    ├── story.json
    ├── images/
    └── audio/
```

重新进入自定义节点图时，**没有在新配置中登记的旧剧集会自动追加为节点**。

读取优先级如下：

1. 优先使用 `nodes.json` 配置的节点及 `custom_story/episodes/<剧集>/story.json`。
2. 新版剧情文件不存在时，再回退到 `Custom Episodes/<剧集>/story.json`。
3. 同一剧集只显示一次；外部图片、音频和视频相对**实际加载到的剧情文件**解析。

想给旧剧集自定义位置、标题、连线或方向导航，可以在 `nodes.json` 中配置对应的 node，并将 `story` 写为 `episodes/<剧集>/story.json`。即使新版路径下没有这个文件，仍可按兼容规则回退到旧目录。

旧版 `lines` JSON 格式继续支持。这是迁移兼容，不是让你把所有旧文件重新抄一遍。

## 0x06 · 谱面内剧情 gimmick

保留 Custom Episodes 的谱面剧情入口：

| Gimmick | 行为 |
| --- | --- |
| `custom_episode` | 开始谱面内剧情 |
| `custom_episode_next` | 在指定 beat 推进到下一步 |

谱面内的台词推进由 beat 触发控制；`delay` 等定时步骤仍有自己的等待逻辑。谱面模式的指令支持范围**不等于** `scene_story` 中完整的 `lines` 指令集。

相关实现与 `.vsm` 写法参见 [`docs/写作手册.md`](docs/写作手册.md)。谱面内剧情可以按自身的加载规则读取剧本及相对谱面目录的外部 OGG 资源。

## 0x07 · 实现说明

这版将入口控制与剧情执行分离：

- `o_mod_storyentry`：persistent 剧情运行时服务，**不再负责主菜单入口**。
- `nodes.json` / 自定义 Node Flowchart：负责节点展示、导航、关联与进入剧情。
- `o_cutsceneConductor`：根据是否处于 custom mode，选择不同的剧情 runner。

关键分流逻辑：

```gml
if (global.custom_story_mode == true) {
    coroutine = global.mod_cs_run_node_story();
} else {
    coroutine = script_execute(global.load_scene);
}
```

原版剧情继续使用 `global.load_scene`；自定义 node 使用 `global.mod_cs_run_node_story()`。这两个路径不应该互相污染。

### 进度与退出隔离

- 自定义 node 不写原版 `story_progress`，不覆盖原版节点解锁状态。
- `end` / `goto` / `abort` 以及暂停退出，返回自定义节点图。
- 只有 Shift + 确认进入 custom mode；普通确认仍按原版逻辑运行。

### 与旧版 README 不同的地方

如果你还在其他文档里看到以下说法，请以**当前 Fork** 为准：

| 旧说明 | 当前行为 |
| --- | --- |
| 主菜单 `Shift + Enter` 打开 picker | `NODE FLOWCHART` 上 `Shift + 确认` 打开自定义节点图 |
| F9 picker 是调试 / 选择入口 | 不再作为入口 |
| 剧情结束或暂停退出返回主菜单 | 自定义 node 模式返回自定义节点图 |
| 只扫描 `Custom Episodes/` | 新目录优先，兼容旧目录并自动补充未配置节点 |

## 0x08 · 文档与来源

- [`docs/写作手册.md`](docs/写作手册.md)：完整剧情 `lines` 语法、参数与谱面内用法。
- [`docs/asset-names.md`](docs/asset-names.md)：可引用的游戏资产名。
- [`raw/custom_story/nodes.json`](raw/custom_story/nodes.json)：节点及章节配置示例。
- [Frollsy/vividstasis-CustomEpisodesMod](https://github.com/Frollsy/vividstasis-CustomEpisodesMod)：原项目及早期实现说明。

## 0xFF · **简而言之，简而言之**

原版节点图照常使用；想播放自定义剧情，按住 Shift 进入另一套节点图。剧情、资源、节点分别配好，结束就返回自定义节点图。少一点隐藏快捷键，多一点可预测的状态转换。终于。
