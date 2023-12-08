import { getClientConfig } from "../config/client";
import { Updater } from "../typing";
import { ApiPath, STORAGE_KEY, StoreKey } from "../constant";
import { createPersistStore } from "../utils/store";
import {
  AppState,
  getLocalAppState,
  GetStoreState,
  mergeAppState,
  setLocalAppState,
} from "../utils/sync";
import { downloadAs, readFromFile } from "../utils";
import { showToast } from "../components/ui-lib";
import Locale from "../locales";
import { createSyncClient, ProviderType, SyncClient } from "../utils/cloud";
import { corsPath } from "../utils/cors";

export interface WebDavConfig {
  endpoint: string;
  username: string;
  password: string;
  filename: string;
}

export interface GistConfig {
  filename: string;
  gistId: string;
  token: string;
}

export type SyncStore = GetStoreState<typeof useSyncStore> & {
  syncing: boolean;
};

const DEFAULT_SYNC_STATE = {
  provider: ProviderType.WebDAV,
  useProxy: true,
  proxyUrl: corsPath(ApiPath.Cors),
  enableAccessControl: false,

  githubGist: {
    filename: "",
    gistId: "",
    token: "",
  },

  webdav: {
    endpoint: "",
    username: "",
    password: "",
    filename: "",
  },

  upstash: {
    endpoint: "",
    username: STORAGE_KEY,
    apiKey: "",
    filename: "",
  },

  gosync: {
    filename: "",
    username: STORAGE_KEY,
    token: "",
  },

  lastSyncTime: 0,
  lastProvider: "",
  lastUpdateTime: 0,
  syncing: false,
  lockclient: false,
};
// alternative fix for tauri
const isApp = !!getClientConfig()?.isApp;

export const useSyncStore = createPersistStore(
  DEFAULT_SYNC_STATE,
  (set, get) => ({
    countSync() {
      const config = get()[get().provider];
      return Object.values(config).every((c) => c.toString().length > 0);
    },

    markSyncTime(provider: ProviderType) {
      set({ lastSyncTime: Date.now(), lastProvider: provider });
    },

    markUpdateTime() {
      set({ lastUpdateTime: Date.now() });
    },

    export() {
      const state = getLocalAppState();
      const datePart = isApp
        ? `${new Date().toLocaleDateString().replace(/\//g, '_')} ${new Date().toLocaleTimeString().replace(/:/g, '_')}`
        : new Date().toLocaleString();

      const fileName = `Backup-${datePart}.json`;
      downloadAs((state), fileName);
    },

    async import() {
      const rawContent = await readFromFile();

      try {
        const jsonChunks = rawContent.split("\n");
        const localState = getLocalAppState();

        for (const jsonChunk of jsonChunks) {
          const remoteState = JSON.parse(jsonChunk) as AppState;
          mergeAppState(localState, remoteState);
        }

        setLocalAppState(localState);
        location.reload();
      } catch (e) {
        console.error("[Import] Failed to import JSON file:", e);
        showToast(Locale.Settings.Sync.ImportFailed);
      }
    },

    getClient(provider: ProviderType): SyncClient<ProviderType> {
      const client = createSyncClient(provider, get());
      return client;
    },

    async sync(overwriteAccessControl: boolean = false) {
      if (get().syncing) {
        return false;
      }

      const localState = getLocalAppState();
      const provider = get().provider;
      const config = get()[provider];
      const client = this.getClient(provider);

      try {
        set({ syncing: true }); // Set syncing to true before performing the sync
        const rawContent = await client.get(config.filename);
        const remoteState = JSON.parse(rawContent) as AppState;

        if (get().lockclient) {
          setLocalAppState(remoteState);
        } else {
          mergeAppState(localState, remoteState);

          const sessions = localState[StoreKey.Chat].sessions;
          const currentSession =
            sessions[localState[StoreKey.Chat].currentSessionIndex];
          const filteredTopic =
            currentSession.topic === "New Conversation" &&
            currentSession.messages.length === 0;

          if (filteredTopic) {
            const remoteSessions = remoteState[StoreKey.Chat].sessions;
            const remoteCurrentSession =
              remoteSessions[remoteState[StoreKey.Chat].currentSessionIndex];
            const remoteFilteredTopic =
              remoteCurrentSession.topic === "New Conversation" &&
              remoteCurrentSession.messages.length > 0;

            if (!remoteFilteredTopic) {
              localState[StoreKey.Chat].sessions[
                localState[StoreKey.Chat].currentSessionIndex
              ].mask = {
                ...currentSession.mask,
                name: remoteCurrentSession.mask.name,
              };
            }
          }

          setLocalAppState(localState);
        }
      } catch (e) {
        console.log(
          `[Sync] Failed to get remote state from file '${config.filename}' for provider ['${provider}']:`,
          e,
          "Will attempt fixing it",
        );

        if (403) {
          console.error("[Sync] Sync failed due to '403 Forbidden' error");
          set({ syncing: false });
          return false;
        }
      }

      if (overwriteAccessControl !== false) { // default is false ref #DEFAULT_SYNC_STATE
        const accessControl = localState['access-control'];
        accessControl.openaiApiKey
        accessControl.accessCode
        accessControl.needCode
        accessControl.hideUserApiKey
        accessControl.hideBalanceQuery
        accessControl.disableGPT4
        accessControl.openaiUrl
      }

      if (provider === ProviderType.WebDAV) {
        await this.syncWebDAV(client, config.filename, localState);
      } else if (provider === ProviderType.GitHubGist) {
        await this.syncGitHubGist(client, config.filename, localState);
      }

      this.markSyncTime(provider);
      this.markUpdateTime(); // Call markUpdateTime to update lastUpdateTime
      set({ syncing: false });

      return true; // Add the return statement here
    },

    async syncWebDAV(client: SyncClient<ProviderType.WebDAV>, value: string, localState: AppState) {
      await client.set(value, JSON.stringify(localState));
    },

    async syncGitHubGist(client: SyncClient<ProviderType.GitHubGist>, value: GistConfig | string, localState: AppState | Object) {
      if (typeof value === 'string') {
        await client.set(localState as string, value);
      } else {
        await client.set(localState as string, value.filename);
      }
    },

    setLockClient(value: boolean) {
      set({ lockclient: value });
    },

    async check() {
      const client = this.getClient(get().provider);
      return await client.check();
    },
  }),
  {
    name: StoreKey.Sync,
    version: 1.2, // golang syncing 
    migrate(persistedState, version) {
      const newState = persistedState as typeof DEFAULT_SYNC_STATE;
      if (version < 1.1) {
        newState.upstash.username = STORAGE_KEY;
      }
      if (version < 1.2) {
        newState.gosync.username = STORAGE_KEY;
      }
      return newState as any;
    },
  },
);
