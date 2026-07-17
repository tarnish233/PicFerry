# PicFerry

**简体中文** | [English](README-en.md)

PicFerry 是一款原生 macOS 菜单栏上传工具，支持 GitHub 与 Gitee。它可以上传所选文件、剪贴板内容、截图、URL 和拖入的项目，并将结果复制为 URL、Markdown 或 HTML。

## 功能

- 从菜单栏选择文件、读取剪贴板或截取屏幕并上传
- 将文件或网页图片拖到菜单栏图标上传
- 在 GitHub 与 Gitee 图床配置之间快速切换
- 自定义 URL、Markdown、HTML 等输出格式及图片压缩比例
- 上传成功或失败后提供明确通知，并在上传历史中保留结果
- 支持全局快捷键和 `picferry` 命令行工具

## 系统要求

- macOS 26 或更高版本
- Apple Silicon（`arm64`）
- 开发环境需要 Xcode 26

## 安装

从 Releases 下载 `PicFerry-2.0.1-macos26-arm64.dmg`，打开后将 `PicFerry.app` 拖入“应用程序”文件夹。

当前测试包采用本地签名；如果 macOS 阻止首次打开，请在 Finder 中右键应用并选择“打开”。

## 编译

```bash
xcodebuild build \
  -project PicFerry.xcodeproj \
  -scheme 'PicFerry(Release)' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO
```

语言测试可使用 `PicFerry(简体中文)` 和 `PicFerry(繁体中文)` scheme。

## 创建 DMG

完成 Release 构建和签名后执行：

```bash
./Scripts/create-dmg.sh
```

默认读取 `build/release/PicFerry.app`，并在同一目录生成带“应用程序”快捷入口的 DMG。也可以传入自定义应用和输出路径：

```bash
./Scripts/create-dmg.sh /path/to/PicFerry.app /path/to/PicFerry.dmg
```

## 命令行

应用包内的可执行文件同时提供 CLI：

```bash
/Applications/PicFerry.app/Contents/MacOS/PicFerry \
  --upload ~/Desktop/example.png \
  --output markdown
```

为当前用户安装简短的 `picferry` 命令：

```bash
./Scripts/install-cli.sh
picferry --help
```

安装脚本只会在 `~/.local/bin` 下创建一个轻量启动脚本，请确认该目录已加入 `PATH`。

常用参数：

```text
-u, --upload    要上传的一个或多个文件路径或 URL
-o, --output    输出格式：url、markdown、md 或 html
-s, --silent    关闭错误信息输出
-h, --help      显示帮助
-v, --version   显示版本
```

## 应用信息

- 产品与可执行文件：`PicFerry`
- Bundle ID：`com.tarnish233.PicFerry`
- URL Scheme：`picferry://`
- 版本：`2.0.1 (41)`

## 许可证与致谢

项目采用 [Apache License 2.0](LICENSE)。PicFerry 基于原始 [uPic 项目](https://github.com/gee1k/uPic) 开发，并按许可证要求保留原版权和许可声明，详见 [NOTICE](NOTICE)。
