declare module "*.jpg";
declare module "*.png";
declare module "*.woff2";
declare module "*.woff";
declare module "*.ttf";
declare module "*.scss" {
  const content: Record<string, string>;
  export default content;
}

declare module "*.svg";

declare interface Window {
  __TAURI__?: {
    writeText(text: string): Promise<void>;
    invoke(command: string, payload?: Record<string, unknown>): Promise<any>;
    dialog: {
      save(options?: Record<string, unknown>): Promise<string | null>;
    };
    fs: {
      writeBinaryFile(path: string, data: Uint8Array): Promise<void>;
    };
    process: {
      relaunch(): Promise<void>;
    };
    notification:{
      requestPermission(): Promise<Permission>;
      isPermissionGranted(): Promise<boolean>;
      sendNotification(options: string | Options): void;
    };
    updater: {
      checkUpdate(): Promise<UpdateResult>;
      installUpdate(): Promise<void>;
      onUpdaterEvent(handler: (status: UpdateStatusResult) => void): Promise<UnlistenFn>;
    };
    // had to add this for experimental later with golang in backend
    shell: {
      open(path: string, openWith?: string): Promise<void>;
    };
    path: {
      appCacheDir(): Promise<string>;
      appConfigDir(): Promise<string>;
      appDataDir(): Promise<string>;
      appDir(): Promise<string>;
      appLocalDataDir(): Promise<string>;
      appLogDir(): Promise<string>;
      audioDir(): Promise<string>;
      basename(path: string, ext?: string): Promise<string>;
      cacheDir(): Promise<string>;
      configDir(): Promise<string>;
      dataDir(): Promise<string>;
      desktopDir(): Promise<string>;
      dirname(path: string): Promise<string>;
      documentDir(): Promise<string>;
      downloadDir(): Promise<string>;
      executableDir(): Promise<string>;
      extname(path: string): Promise<string>;
      fontDir(): Promise<string>;
      homeDir(): Promise<string>;
      isAbsolute(path: string): Promise<boolean>;
      join(...paths: string[]): Promise<string>;
      localDataDir(): Promise<string>;
      logDir(): Promise<string>;
      normalize(path: string): Promise<string>;
      pictureDir(): Promise<string>;
      publicDir(): Promise<string>;
      resolve(...paths: string[]): Promise<string>;
      resourceDir(): Promise<string>;
      runtimeDir(): Promise<string>;
      templateDir(): Promise<string>;
      videoDir(): Promise<string>;
    };
    os: {
      arch(): Promise<Arch>;
      locale(): Promise<string | null>;
      platform(): Promise<Platform>;
      tempdir(): Promise<string>;
      type(): Promise<OsType>;
      version(): Promise<string>;
    };
  };
}
