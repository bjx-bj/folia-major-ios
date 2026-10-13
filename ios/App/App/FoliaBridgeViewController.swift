import Capacitor

// ios/App/App/FoliaBridgeViewController.swift — 注册应用内 QQ 协议所需的网络桥。
class FoliaBridgeViewController: CAPBridgeViewController {
    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(FoliaNetworkPlugin())
    }
}
