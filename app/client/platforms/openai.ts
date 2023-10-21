import {
  DEFAULT_API_HOST,
  DEFAULT_MODELS,
  OpenaiPath,
  REQUEST_TIMEOUT_MS,
} from "@/app/constant";
import { useAccessStore, useAppConfig, useChatStore } from "@/app/store";

import { ChatOptions, getHeaders, LLMApi, LLMModel, LLMUsage } from "../api";
import Locale from "../../locales";
import {
  EventStreamContentType,
  fetchEventSource,
} from "@fortaine/fetch-event-source";
import { prettyObject } from "@/app/utils/format";
import { getClientConfig } from "@/app/config/client";

/**
 * Models Text-Moderations OpenAI
 * Author: @H0llyW00dzZ
 **/
interface ModerationResponse {
  flagged: boolean;
  categories: Record<string, boolean>;
}

export interface OpenAIListModelResponse {
  object: string;
  data: Array<{
    id: string;
    object: string;
    root: string;
  }>;
}

export class ChatGPTApi implements LLMApi {
  private disableListModels = true;

  path(path: string): string {
    let openaiUrl = useAccessStore.getState().openaiUrl;
    const apiPath = "/api/openai";

    if (openaiUrl.length === 0) {
      const isApp = !!getClientConfig()?.isApp;
      openaiUrl = isApp ? DEFAULT_API_HOST : apiPath;
    }
    if (openaiUrl.endsWith("/")) {
      openaiUrl = openaiUrl.slice(0, openaiUrl.length - 1);
    }
    if (!openaiUrl.startsWith("http") && !openaiUrl.startsWith(apiPath)) {
      openaiUrl = "https://" + openaiUrl;
    }
    return [openaiUrl, path].join("/");
  }

  extractMessage(res: any) {
    return res.choices?.at(0)?.message?.content ?? "";
  }

  async chat(options: ChatOptions) {
    const textmoderation = useAppConfig.getState().textmoderation;
    const latest = OpenaiPath.TextModerationModels.latest;

    if (textmoderation && options.whitelist !== true) {
      const messages = options.messages.map((v) => ({
        role: v.role,
        content: v.content,
      }));

      const userMessages = messages.filter((msg) => msg.role === "user");
      const userMessage = userMessages[userMessages.length - 1]?.content;

      if (userMessage) {
        const moderationPath = this.path(OpenaiPath.ModerationPath);
        const moderationPayload = {
          input: userMessage,
          model: latest,
        };

        try {
          const moderationResponse = await this.sendModerationRequest(
            moderationPath,
            moderationPayload
          );

          if (moderationResponse.flagged) {
            const flaggedCategories = Object.entries(
              moderationResponse.categories
            )
              .filter(([category, flagged]) => flagged)
              .map(([category]) => category);

            if (flaggedCategories.length > 0) {
              const translatedReasons = flaggedCategories.map((category) => {
                const translation =
                  (Locale.Error.Content_Policy.Reason as any)[category];
                return translation ? translation : category; // Use category name if translation is not available
              });
              const translatedReasonText = translatedReasons.join(", ");
              const responseText = `${Locale.Error.Content_Policy.Title}\n${Locale.Error.Content_Policy.Reason.Title}: ${translatedReasonText}\n`;

              const responseWithGraph = responseText;
              options.onFinish(responseWithGraph);
              return;
            }
          }
        } catch (e) {
          console.log("[Request] failed to make a moderation request", e);
          const error = {
            error: (e as Error).message,
            stack: (e as Error).stack,
          };
          options.onFinish(JSON.stringify(error));
          return;
        }
      }
    }

    const messages = options.messages.map((v) => ({
      role: v.role,
      content: v.content,
    }));

    const modelConfig = {
      ...useAppConfig.getState().modelConfig,
      ...useChatStore.getState().currentSession().mask.modelConfig,
      ...{
        model: options.config.model,
      },
    };

    const defaultModel = modelConfig.model;

    const userMessages = messages.filter((msg) => msg.role === "user");
    const userMessage = userMessages[userMessages.length - 1]?.content;
    /**
     * DALL·E Models
     * Author: @H0llyW00dzZ
     * usage in this chat: prompt n: <number> size: <width>x<height>
     * Example: Andromeda Galaxy n: 3 size: 1024x1024
     **/

    const nMatch = userMessage.match(/n:\s*(\d+)\b/i);
    const sizeMatch = userMessage.match(/size:\s*(\d+x\d+)\b/i);

    const n = nMatch ? parseInt(nMatch[1]) : 1;
    const size = sizeMatch ? sizeMatch[1] : "1024x1024";

    const prompt = userMessage
      .replace(/n:\s*\d+\b/i, "")
      .replace(/size:\s*\d+x\d+\b/i, "")
      .trim();

    const requestPayloads = {
      chat: {
        messages,
        stream: options.config.stream,
        model: modelConfig.model,
        temperature: modelConfig.temperature,
        presence_penalty: modelConfig.presence_penalty,
        frequency_penalty: modelConfig.frequency_penalty,
        top_p: modelConfig.top_p,
      },
      image: {
        prompt: prompt,
        n: n,
        size: size,
        model: modelConfig.model,
      },
    };

    if (defaultModel.includes("DALL-E-2")) {
      console.log("[Request] openai payload: ", {
        image: requestPayloads.image,
      });
    } else {
      console.log("[Request] openai payload: ", {
        chat: requestPayloads.chat,
      });
    }


    const shouldStream = !!options.config.stream;
    const controller = new AbortController();
    options.onController?.(controller);

    try {
      const dallemodels =
        defaultModel.includes("DALL-E-2")
      let chatPath = dallemodels
        ? this.path(OpenaiPath.ImageCreationPath)
        : this.path(OpenaiPath.ChatPath);

      let requestPayload;
      if (
        defaultModel.includes("DALL-E-2")
      ) {
        /**
         * Use the image payload structure
         */
        const { model, ...imagePayload } = requestPayloads.image;
        requestPayload = imagePayload;
      } else {
        /**
         * Use the chat model payload structure
         */
        requestPayload = requestPayloads.chat;
      }

      const chatPayload = {
        method: "POST",
        body: JSON.stringify(requestPayload),
        signal: controller.signal,
        headers: getHeaders(),
      };

      // make a fetch request
      const requestTimeoutId = setTimeout(
        () => controller.abort(),
        REQUEST_TIMEOUT_MS,
      );

      if (shouldStream) {
        let responseText = "";
        let finished = false;

        const finish = () => {
          if (!finished) {
            options.onFinish(responseText);
            finished = true;
          }
        };

        controller.signal.onabort = finish;

        const isApp = !!getClientConfig()?.isApp;
        const apiPath = "api/openai/";

        fetchEventSource(chatPath, {
          ...chatPayload,
          async onopen(res) {
            clearTimeout(requestTimeoutId);
            const contentType = res.headers.get("content-type");
            console.log("[OpenAI] request response content type: ", contentType);

            if (contentType?.startsWith("text/plain")) {
              responseText = await res.clone().text();
            } else if (contentType?.startsWith("application/json")) {
              const jsonResponse = await res.clone().json();
              const imageUrl = jsonResponse.data?.[0]?.url;
              const prompt = requestPayloads.image.prompt;
              const index = requestPayloads.image.n - 1;
              const size = requestPayloads.image.size;
              const defaultModel = modelConfig.model;

              if (defaultModel.includes("DALL-E-2")) {
                const imageDescription = `#### ${prompt} (${index + 1})\n\n\n | ![${prompt}](${imageUrl}) |\n|---|\n| Size: ${size} |\n| [Download Here](${imageUrl}) |\n| 🤖 AI Models: ${defaultModel} |`;

                responseText = `${imageDescription}`;
              } if (defaultModel.includes("DALL-E-2-BETA-INSTRUCT-0613")) {
                const instructx = await fetch(
                  (isApp ? DEFAULT_API_HOST : apiPath) + OpenaiPath.ChatPath, // Pass the path parameter
                  {
                    method: "POST",
                    body: JSON.stringify({
                      messages: [
                        ...messages,
                      ],
                      model: "gpt-3.5-turbo-0613",
                      temperature: modelConfig.temperature,
                      presence_penalty: modelConfig.presence_penalty,
                      frequency_penalty: modelConfig.frequency_penalty,
                      top_p: modelConfig.top_p,
                    }),
                    headers: getHeaders(),
                  }
                );
                clearTimeout(requestTimeoutId);
                const instructxx = await instructx.json();

                const instructionDelta = instructxx.choices?.[0]?.message?.content;
                const instructionPayload = {
                  messages: [
                    ...messages,
                    {
                      role: "system",
                      content: instructionDelta,
                    },
                  ],
                  model: "gpt-3.5-turbo-0613",
                  temperature: modelConfig.temperature,
                  presence_penalty: modelConfig.presence_penalty,
                  frequency_penalty: modelConfig.frequency_penalty,
                  top_p: modelConfig.top_p,
                };

                const instructionResponse = await fetch(
                  (isApp ? DEFAULT_API_HOST : apiPath) + OpenaiPath.ChatPath,
                  {
                    method: "POST",
                    body: JSON.stringify(instructionPayload),
                    headers: getHeaders(),
                  }
                );

                const instructionJson = await instructionResponse.json();
                const instructionMessage = instructionJson.choices?.[0]?.message?.content; // Access the appropriate property containing the message
                const imageDescription = `| ![${prompt}](${imageUrl}) |\n|---|\n| Size: ${size} |\n| [Download Here](${imageUrl}) |\n| 🤖 AI Models: ${defaultModel} |`;

                responseText = `${imageDescription}\n\n${instructionMessage}`;
              } if (
                !res.ok ||
                !res.headers
                  .get("content-type")
                  ?.startsWith(EventStreamContentType) ||
                res.status !== 200
              ) {
                let anyinfo = await res.clone().text();
                try {
                  const infJson = await res.clone().json();
                  anyinfo = prettyObject(infJson);
                } catch { }
                if (res.status === 401) {
                  responseText = "\n\n" + Locale.Error.Unauthorized;
                }
                if (res.status !== 200) {
                  if (anyinfo) {
                    responseText += "\n\n" + anyinfo;
                  }
                }
                return;
              }
            }
            if (
              !res.ok ||
              !res.headers
                .get("content-type")
                ?.startsWith(EventStreamContentType) ||
              res.status !== 200
            ) {
              const responseTexts = [responseText];
              let extraInfo = await res.clone().text();
              try {
                const resJson = await res.clone().json();
                extraInfo = prettyObject(resJson);
              } catch {}

              if (res.status === 401) {
                responseTexts.push(Locale.Error.Unauthorized);
              }

              if (extraInfo) {
                responseTexts.push(extraInfo);
              }

              responseText = responseTexts.join("\n\n");

              return finish();
            }
          },
          onmessage(msg) {
            if (msg.data === "[DONE]" || finished) {
              return finish();
            }
            const text = msg.data;
            try {
              const json = JSON.parse(text);
              const delta = json.choices[0].delta.content;
              if (delta) {
                responseText += delta;
                options.onUpdate?.(responseText, delta);
              }
            } catch (e) {
              console.error("[Request] parse error", text, msg);
            }
          },
          onclose() {
            finish();
          },
          onerror(e) {
            options.onError?.(e);
            throw e;
          },
          openWhenHidden: true,
        });
      } else {
        const res = await fetch(chatPath, chatPayload);
        clearTimeout(requestTimeoutId);

        const resJson = await res.json();
        const message = this.extractMessage(resJson);
        options.onFinish(message);
      }
    } catch (e) {
      console.log("[Request] failed to make a chat request", e);
      options.onError?.(e as Error);
    }
  }

  async usage() {
    const formatDate = (d: Date) =>
      `${d.getFullYear()}-${(d.getMonth() + 1).toString().padStart(2, "0")}-${d
        .getDate()
        .toString()
        .padStart(2, "0")}`;
    const ONE_DAY = 1 * 24 * 60 * 60 * 1000;
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const startDate = formatDate(startOfMonth);
    const endDate = formatDate(new Date(Date.now() + ONE_DAY));

    const [used, subs] = await Promise.all([
      fetch(
        this.path(
          `${OpenaiPath.UsagePath}?start_date=${startDate}&end_date=${endDate}`
        ),
        {
          method: "GET",
          headers: getHeaders(),
        }
      ),
      fetch(this.path(OpenaiPath.SubsPath), {
        method: "GET",
        headers: getHeaders(),
      }),
    ]);

    if (used.status === 401) {
      throw new Error(Locale.Error.Unauthorized);
    }

    if (!used.ok || !subs.ok) {
      throw new Error("Failed to query usage from openai");
    }

    const response = (await used.json()) as {
      total_usage?: number;
      error?: {
        type: string;
        message: string;
      };
    };

    const total = (await subs.json()) as {
      hard_limit_usd?: number;
      system_hard_limit_usd?: number;
    };

    if (response.error && response.error.type) {
      throw Error(response.error.message);
    }

    if (response.total_usage) {
      response.total_usage = Math.round(response.total_usage) / 100;
    }

    if (total.hard_limit_usd) {
      total.hard_limit_usd = Math.round(total.hard_limit_usd * 100) / 100;
    }
  
    if (total.system_hard_limit_usd) {
      total.system_hard_limit_usd = Math.round(total.system_hard_limit_usd * 100) / 100;
    }
  
    return {
      used: response.total_usage,
      total: {
        hard_limit_usd: total.hard_limit_usd,
        system_hard_limit_usd: total.system_hard_limit_usd,
      },
    } as unknown as LLMUsage;    
  }

  async models(): Promise<LLMModel[]> {
    if (this.disableListModels) {
      return DEFAULT_MODELS.slice();
    }

    const res = await fetch(this.path(OpenaiPath.ListModelPath), {
      method: "GET",
      headers: {
        ...getHeaders(),
      },
    });

    const resJson = (await res.json()) as OpenAIListModelResponse;
    const chatModels = resJson.data?.filter((m) => m.id.startsWith("gpt-"));
    console.log("[Models]", chatModels);

    if (!chatModels) {
      return [];
    }

    return chatModels.map((m) => ({
      name: m.id,
      available: true,
    }));
  }

  /**
   * Models Text-Moderations OpenAI
   * Author: @H0llyW00dzZ
   **/

  private async sendModerationRequest(
    moderationPath: string,
    moderationPayload: any
  ): Promise<ModerationResponse> {
    try {
      const moderationResponse = await fetch(moderationPath, {
        method: "POST",
        body: JSON.stringify(moderationPayload),
        headers: getHeaders(),
      });
  
      const moderationJson = await moderationResponse.json();
  
      if (moderationJson.results && moderationJson.results.length > 0) {
        let moderationResult = moderationJson.results[0]; // Access the first element of the array
  
        if (!moderationResult.flagged) {
          const stable = OpenaiPath.TextModerationModels.stable; // Fall back to "stable" if "latest" is still false
          moderationPayload.model = stable;
          const fallbackModerationResponse = await fetch(moderationPath, {
            method: "POST",
            body: JSON.stringify(moderationPayload),
            headers: getHeaders(),
          });
  
          const fallbackModerationJson = await fallbackModerationResponse.json();
  
          if (
            fallbackModerationJson.results &&
            fallbackModerationJson.results.length > 0
          ) {
            moderationResult = fallbackModerationJson.results[0]; // Access the first element of the array
          }
        }
  
        return moderationResult as ModerationResponse;
      } else {
        console.error("Moderation response is empty");
        throw new Error("Failed to get moderation response");
      }
    } catch (e) {
      console.error("[Request] failed to make a moderation request", e);
      return {} as ModerationResponse;
    }
  }
  /** TODO */
  private async sendRequest(path: string, payload: any) {
    try {
      const response = await fetch(path, {
        method: "POST",
        body: JSON.stringify(payload),
        headers: getHeaders(),
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch ${path}: ${response.status} ${response.statusText}`);
      }

      const data = await response.json();
      return data;
    } catch (error) {
      console.error(`Failed to send request to ${path}`, error);
      throw error;
    }
  }
}

export { OpenaiPath };
