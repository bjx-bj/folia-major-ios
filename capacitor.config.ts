import type { CapacitorConfig } from '@capacitor/cli';

// Folia 的 iOS 容器：前端资源随应用离线打包。
const config: CapacitorConfig = {
  appId: 'top.izuna.foliamajor',
  appName: 'Folia',
  webDir: 'dist',
  ios: {
    backgroundColor: '#09090b',
    contentInset: 'automatic',
  },
};

export default config;
