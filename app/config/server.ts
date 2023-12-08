import binary from "spark-md5";
import { DEFAULT_MODELS } from "../constant";

declare global {
  namespace NodeJS {
    interface ProcessEnv {
      PROXY_URL?: string; // docker only

      OPENAI_API_KEY?: string;
      CODE?: string;

      BASE_URL?: string;
      OPENAI_ORG_ID?: string; // openai only

      VERCEL?: string;
      BUILD_MODE?: "standalone" | "export";
      BUILD_APP?: string; // is building desktop app
      VERCEL_ANALYTICS?: string; // vercel web analytics
      HIDE_USER_API_KEY?: string; // disable user's api key input
      DISABLE_GPT4?: string; // allow user to use gpt-4 or not
      DISABLE_CUSTOMMODELS?: boolean; // allow user to use custom models or not
      ENABLE_BALANCE_QUERY?: string; // allow user to query balance or not
      DISABLE_FAST_LINK?: string; // disallow parse settings from url or not
      CUSTOM_MODELS?: string; // to control custom models

      // azure only
      AZURE_URL?: string; // https://{azure-url}/openai/deployments/{deploy-name}
      AZURE_API_KEY?: string;
      AZURE_API_VERSION?: string;
    }
  }
}

const ACCESS_CODES = (function getAccessCodes(): Set<string> {
  const code = process.env.CODE;

  try {
    const codes = (code?.split(",") ?? [])
      .filter((v) => !!v)
      .map((v) => binary.hash(v.trim()));
    return new Set(codes);
  } catch (e) {
    return new Set();
  }
})();

export const getServerSideConfig = () => {
  if (typeof process === "undefined") {
    throw Error(
      "[Server Config] you are importing a nodejs-only module outside of nodejs",
    );
  }

  const apiKey = process.env.OPENAI_API_KEY;
  const accessCodes = process.env.CODE?.split(",") ?? [];
  const codes = new Set(accessCodes.map((code) => binary.hash(code.trim())));
  const needCode = codes.size > 0;

  const apiKeys = new Map<string, string>();
  accessCodes.forEach((code, index) => {
    const apiKeyIndex = index < (apiKey?.split(",")?.length ?? 0) ? index : 0;
    const hashedCode = binary.hash(code.trim());
    const apiKeyValue = (apiKey?.split(",")?.[apiKeyIndex]?.trim() ?? "")!;
    apiKeys.set(hashedCode, apiKeyValue);
  });

  const disableGPT4 = !!process.env.DISABLE_GPT4;
  let customModels = process.env.CUSTOM_MODELS ?? "";

  if (disableGPT4) {
    if (customModels) customModels += ",";
    customModels += DEFAULT_MODELS.filter((m) => m.name.startsWith("gpt-4"))
      .map((m) => "-" + m.name)
      .join(",");
  }

  const isAzure = !!process.env.AZURE_URL;

  return {
    baseUrl: process.env.BASE_URL,
    apiKey,
    openaiOrgId: process.env.OPENAI_ORG_ID,

    isAzure,
    azureUrl: process.env.AZURE_URL,
    azureApiKey: process.env.AZURE_API_KEY,
    azureApiVersion: process.env.AZURE_API_VERSION,

    codes,
    needCode,
    proxyUrl: process.env.PROXY_URL,
    isVercel: !!process.env.VERCEL,
    isVercelWebAnalytics: !!process.env.VERCEL_ANALYTICS,
    hideUserApiKey: !!process.env.HIDE_USER_API_KEY,
    disableGPT4,
    hideBalanceQuery: !process.env.ENABLE_BALANCE_QUERY,
    disableFastLink: !!process.env.DISABLE_FAST_LINK,
    customModels,
    apiKeys,
  };
};
