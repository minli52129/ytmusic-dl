# YTMusicDL

原生 macOS（SwiftUI）YouTube Music 下载器，内置 yt-dlp + FFmpeg，无需安装任何依赖。
代码全部在 GitHub Actions（Apple Silicon runner）上编译打包，本机零工具链即可出包。

## 功能

- 粘贴单曲 / 专辑 / 歌单链接，选择格式（MP3 / M4A / Opus / FLAC / WAV）下载
- 下载队列、并发控制、实时进度 / 速度 / 剩余时间
- 自动写入元数据与封面（`--embed-metadata --embed-thumbnail`）
- 下载历史（本地 JSON 持久化）、搜索、失败重试
- 可选从浏览器读取 Cookies（私人歌单）、HTTP 代理
- 完成后系统通知

## 使用（全流程不需要本地编译）

1. 在 GitHub 新建仓库（建议 Public，Actions 免费），推送本项目
   ```bash
   cd ytmusic-dl
   git init && git add . && git commit -m "init"
   git remote add origin git@github.com:<你的用户名>/ytmusic-dl.git
   git push -u origin main
   ```
2. 打开仓库的 **Actions** 页，等 `Build` 工作流跑完（约 10~15 分钟）
3. 在该次运行底部 **Artifacts** 下载 `YTMusicDL-macos-arm64`
4. 解压后首次打开前，在终端执行（移除下载隔离属性）：
   ```bash
   xattr -cr ~/Downloads/YTMusicDL.app
   ```
5. 拖入「应用程序」，双击即用。首次下载会请求通知权限，允许即可

发版建议：打 tag 自动生成 Release

```bash
git tag v1.0.0 && git push origin v1.0.0
```

## 更新内置 yt-dlp

yt-dlp 针对YouTube 改版更新频繁，建议每隔一段时间刷新：

1. 到仓库 **Actions → Build → Run workflow**
2. `yt_dlp_version` 留空 = 最新版（或填指定版本如 `2025.06.09`）
3. 跑完后重新下载安装 App 即可

ffmpeg / ffprobe 使用 [osxexperts.net](https://www.osxexperts.net) 的 ARM64 静态编译版，CI 脚本会自动尝试最新大版本。

## 项目结构

```
project.yml               XcodeGen 工程描述（.xcodeproj 由 CI 生成，不入库）
Sources/
  YTMusicDLApp.swift      应用入口
  Models/                 任务模型 / 音频格式
  Services/
    DownloadManager.swift 队列调度 + yt-dlp 输出解析（核心）
    YtDlpRunner.swift     Process 封装（stdout/stderr 合并逐行读取）
    AppPaths.swift        内置二进制定位 / chmod / 清理隔离属性
    HistoryStore.swift    历史 JSON 持久化
    Notifier.swift        系统通知
  Views/                  下载 / 历史 / 设置三个标签页
scripts/
  build-ytdlp.sh          pip + PyInstaller 打独立 yt-dlp 二进制
  fetch-ffmpeg.sh         下载 ARM64 静态 ffmpeg / ffprobe 并校验签名
  assemble.sh             组装 .app、嵌套 ad-hoc 签名、出 zip
.github/workflows/build.yml
```

## 技术要点

- **签名**：ad-hoc（`codesign -s -`），自用足够；若要分给他人需 Developer ID + 公证
- **沙箱**：未开启 App Sandbox（自用分发，非上架），否则无法调用外部二进制
- **架构**：CI 用 `macos-15`（arm64）runner，产物为 Apple Silicon 原生
- **进度解析**：`--progress-template` 输出机器可读格式，歌单用 `Downloading item N of M` 计算整体进度
- **首次启动**：App 会自动对内置二进制执行 `chmod +x` 和 `xattr -d` 清理隔离属性

## 已知限制

- 无自定义图标、无菜单栏模式（可后续添加）
- 年龄限制 / 私人歌单内容需在「设置」中选择浏览器读取 Cookies（Safari 不支持，需 Chrome 等）
- 仅 arm64 产物；Intel 机器需将 CI 换成 `macos-13`（x86_64 runner）并将 ffmpeg 换成 Intel 版
