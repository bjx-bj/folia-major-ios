# Folia iOS / GitHub Actions

当前移植复用 React Web 前端，使用 Capacitor 8 包装为 iOS 15+ 应用。

## 云构建

1. 将分支推送到自己的 GitHub 仓库。
2. 打开 Actions → Build iOS IPA → Run workflow，选择含本工作流的分支。
3. 可选填写 HTTPS 网易云、酷狗、QQ API 地址；未填写时使用仓库 Variables 中对应的 VITE_*_API_BASE。
4. 成功后下载 Folia-iOS-unsigned artifact，内含 IPA 和 SHA-256。

生成的 IPA 未签名，需要侧载工具或自己的 Apple 证书重新签名后才能安装；不会生成 App Store 签名包。

## 当前功能边界

前端和歌词动画随应用打包，无需通过在线网站加载 UI。在线音乐接口依赖远端 Node/Web 服务，Electron 内置的音乐 API、ffmpeg、桌面壁纸和模组 Node 入口没有移植到 iOS。
锁屏持续播放及后台切歌未做原生音频接入，尚未在 iPhone 真机验证。
HTTP API 未开放 ATS 例外，请配置 HTTPS 接口并允许 WebView 来源访问。

## 本地构建（macOS）

需要 Node 24+、Xcode 26+。执行 npm ci 和 npm run mobile:build:ipa，输出到 ios/App/output。
在 Windows 上可构建 Web 和同步工程，原生编译通过 GitHub macOS runner 执行。
