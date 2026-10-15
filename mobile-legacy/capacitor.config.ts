import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.pwtgaming.app',
  appName: 'PWT Gaming',
  webDir: 'www',
  bundledWebRuntime: false,
  backgroundColor: '#05070b',
  android: {
    backgroundColor: '#05070b',
    allowMixedContent: false
  },
  ios: {
    backgroundColor: '#05070b',
    contentInset: 'automatic',
    scrollEnabled: true
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 1400,
      launchAutoHide: true,
      backgroundColor: '#05070b',
      showSpinner: false
    },
    StatusBar: {
      style: 'DARK',
      backgroundColor: '#05070b'
    },
    Keyboard: {
      resize: 'body',
      resizeOnFullScreen: true
    }
  }
};

export default config;
