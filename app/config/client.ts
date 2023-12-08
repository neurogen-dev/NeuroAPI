import { BuildConfig, getBuildConfig } from "./build";

export function getClientConfig() {
  if (typeof document !== "undefined") {
    // client side
    const buildConfig = JSON.parse(queryMeta("config")) as BuildConfig;
    const commitMessage = buildConfig.commitMessage.description;
    return {
      ...buildConfig,
      commitMessage: {
        ...buildConfig.commitMessage,
        description: commitMessage,
      },
    };
  }

  if (typeof process !== "undefined") {
    // server side
    const buildConfig = getBuildConfig();
    const commitMessage = buildConfig.commitMessage.description;
    return {
      ...buildConfig,
      commitMessage: {
        ...buildConfig.commitMessage,
        description: commitMessage,
      },
    };
  }
}

function queryMeta(key: string, defaultValue?: string): string {
  let ret: string;
  if (document) {
    const meta = document.head.querySelector(
      `meta[name='${key}']`,
    ) as HTMLMetaElement;
    ret = meta?.content ?? "";
  } else {
    ret = defaultValue ?? "";
  }

  return ret;
}
