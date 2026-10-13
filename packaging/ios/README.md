# Folia iOS / GitHub Actions

复用原项目 React 前端和 @yakult-green-tea/qq-music-api 3.1.4 的 serverless/MQTT 协议源码。

QQ 音乐在 iOS 内运行请求处理器，默认无需另行部署 QQ API。HTTP 请求经 FoliaNetwork 的 URLSession 桥发送，保留原协议需要的 Cookie 和手动重定向；QQ 扫码使用原 MQTT codec，并在应用内持有 WebSocket 连接。微信扫码同样经过原协议。登录加密密钥持久保存在设备 Keychain。

## GitHub 云构建

Actions → Build iOS IPA → Run workflow。构建成功后下载 Folia-iOS-unsigned artifact，内含 IPA 和 SHA-256。

生成的 IPA 未签名，安装时需要使用侧载工具或自己的 Apple 证书重新签名。

## 当前验证边界

原生代码由 macOS/Xcode 编译；自动化验证覆盖 QQ 入口可用性、Cookie、请求/响应二进制传输和取消。
账号实际扫码与播放仍需 iPhone 真机验证，不会在构建时使用个人账号。
网易云、酷狗继续依赖单独接入；Electron 的 ffmpeg、桌面壁纸、Node 模组入口尚未移植。锁屏持续播放及后台切歌尚未做原生音频接入。

## macOS 本地构建

Node 24+、Xcode 26+：npm ci，然后 npm run mobile:build:ipa，输出到 ios/App/output。
