import { createWebDavClient } from "./webdav";
import { createUpstashClient } from "./upstash";
import { createGistClient } from "./gist";

export enum ProviderType {
  WebDAV = "webdav",
  UpStash = "upstash",
  GitHubGist = "githubGist",
}

export const SyncClients = {
  [ProviderType.UpStash]: createUpstashClient,
  [ProviderType.WebDAV]: createWebDavClient,
  [ProviderType.GitHubGist]: createGistClient,
} as const;

type SyncClientConfig = {
  [K in keyof typeof SyncClients]: Parameters<(typeof SyncClients)[K]>[0];
};

export type SyncClient<T extends ProviderType> = {
  get: (key: string) => Promise<string>;
  set: (key: string, value: string | Object) => Promise<void>;
  check: () => Promise<boolean>;
};

export function createSyncClient<T extends ProviderType>(
  provider: T,
  config: SyncClientConfig[T],
): SyncClient<T> {
  return SyncClients[provider](config) as SyncClient<T>;
}

