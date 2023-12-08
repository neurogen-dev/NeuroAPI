import { getClientConfig } from "../config/client";
import { SubmitKey } from "../store/config";
import { LocaleType } from "./index";

// if you are adding a new translation, please use PartialLocaleType instead of LocaleType

const isApp = !!getClientConfig()?.isApp;
const en: LocaleType = {
  WIP: "Coming Soon...",
  Error: {
    Unauthorized: isApp
      ? "Unauthorized access, please enter your OpenAI API Key in [auth](/#/auth) page."
      : "Unauthorized access, please enter access code in [auth](/#/auth) page, or enter your OpenAI API Key.",
    Content_Policy: {
      Title:
        "Your request got flagged because of a Content Policy Violation.",
      SubTitle: 
        "Read Here: https://platform.openai.com/docs/guides/moderation/overview",
      Reason: {
        Title: "Reason",
        sexual: "Sexual",
        hate: "Hate",
        harassment: "Harassment",
        "self-harm": "Self-harm",
        "sexual/minors": "Sexual/minors",
        "hate/threatening": "Hate/threatening",
        "violence/graphic": "Violence/graphic",
        "self-harm/intent": "Self-harm/intent",
        "self-harm/instructions": "Self-harm/instructions",
        "harassment/threatening": "Harassment/threatening",
        violence: "Violence",
      },
    },
  },
  Auth: {
    Title: "Need Access Code",
    Tips: "Please enter access code below",
    SubTips: "Or enter your OpenAI API Key",
    Input: "access code",
    Confirm: "Confirm",
    Later: "Later",
  },
  ChatItem: {
    ChatItemCount: (count: number) => `${count} messages`,
  },
  Chat: {
    SubTitle: (count: number) => `${count} messages`,
    EditMessage: {
      Title: "Edit All Messages",
      Topic: {
        Title: "Topic",
        SubTitle: "Change the current topic",
      },
    },
    Actions: {
      ChatList: "Go To Chat List",
      CompressedHistory: "Compressed History Memory Prompt",
      Export: "Export All Messages as Markdown",
      Copy: "Copy",
      Stop: "Stop",
      Retry: "Retry",
      Pin: "Pin",
      PinToastContent: "Pinned 1 messages to contextual prompts",
      PinToastAction: "View",
      Delete: "Delete",
      Edit: "Edit",
    },
    Commands: {
      new: "Start a new chat",
      newm: "Start a new chat with mask",
      next: "Next Chat",
      prev: "Previous Chat",
      restart: "Restart a client",
      clear: "Clear Context",
      del: "Delete Chat",
      save: "Save a current session chat",
      load: "Load a session chat",
      copymemoryai: "Copy a session of memory prompt ai",
      updatemasks: "Update a session of memory prompt for a mask",
      summarize: "Summarize the current session of this chat",
      UI: {
        MasksSuccess: "Successfully updated session of masks",
        MasksFail: "Failed to update session of masks",
        SummarizeSuccess: "Successfully summarize session of this chat",
        SummarizeFail: "Failed to summarize session of this chat",
      },      
    },
    InputActions: {
      Stop: "Stop",
      ToBottom: "To Latest",
      Theme: {
        auto: "Auto",
        light: "Light Theme",
        dark: "Dark Theme",
      },
      Prompt: "Prompts",
      Masks: "Masks",
      Clear: "Clear Context",
      Settings: "Settings",
    },
    Rename: "Rename Chat",
    Typing: "Typing…",
    Input: (submitKey: string) => {
      var inputHints = `${submitKey} to send`;
      if (submitKey === String(SubmitKey.Enter)) {
        inputHints += ", Shift + Enter to wrap";
      }
      return inputHints + ", / to search prompts, : to use commands";
    },
    Send: "Send",
    Config: {
      Reset: "Reset to Default",
      SaveAs: "Save as Mask",
    },
    IsContext: "Contextual Prompt",
  },
  Export: {
    Title: "Export Messages",
    Copy: "Copy All",
    Download: "Download",
    MessageFromYou: "Message From You",
    MessageFromChatGPT: "Message From ChatGPT",
    Share: "Share to ShareGPT",
    Format: {
      Title: "Export Format",
      SubTitle: "Markdown or PNG Image",
    },
    IncludeContext: {
      Title: "Including Context",
      SubTitle: "Export context prompts in mask or not",
    },
    Steps: {
      Select: "Select",
      Preview: "Preview",
    },
    Image: {
      Toast: "Capturing Image...",
      Modal: "Long press or right click to save image",
    },
  },
  Select: {
    Search: "Search",
    All: "Select All",
    Latest: "Select Latest",
    Clear: "Clear",
  },
  Memory: {
    Title: "Memory Prompt",
    EmptyContent: "Nothing yet.",
    Send: "Send Memory",
    Copy: "Copy Memory",
    Reset: "Reset Session",
    ResetConfirm:
      "Resetting will clear the current conversation history and historical memory. Are you sure you want to reset?",
  },
  Home: {
    NewChat: "New Chat",
    DeleteChat: "Confirm to delete the selected conversation?",
    DeleteToast: "Chat Deleted",
    Revert: "Revert",
  },
  Settings: {
    Title: "Settings",
    SubTitle: "All Settings",
    Danger: {
      Reset: {
        Title: "Reset All Settings",
        SubTitle: "Reset all setting items to default",
        Action: "Reset",
        Confirm: "Confirm to reset all settings to default?",
      },
      Clear: {
        Title: "Clear All Data",
        SubTitle: "Clear all messages and settings",
        Action: "Clear",
        Confirm: "Confirm to clear all messages and settings?",
      },
    },
    Lang: {
      Name: "Language", // ATTENTION: if you wanna add a new translation, please do not translate this value, leave it as `Language`
      All: "All Languages",
    },
    Avatar: "Avatar",
    FontSize: {
      Title: "Font Size",
      SubTitle: "Adjust font size of chat content",
    },
    InjectSystemPrompts: {
      Title: "Inject System Prompts",
      SubTitle: "Inject a global system prompt for every request",
    },
    InputTemplate: {
      Title: "Input Template",
      SubTitle: "Newest message will be filled to this template",
    },

    Update: {
      Version: (x: string) => `Version: ${x}`,
      IsLatest: "Latest version",
      CheckUpdate: "Check Update",
      IsChecking: "Checking update...",
      FoundUpdate: (x: string) => `Found new version: ${x}`,
      GoToUpdate: "Update",
      IsUpdating: "Updating...",
      UpdateSuccessful: "A Version has been updated to the latest version",
      UpdateFailed: "Update Failed",
    },
    SendKey: "Send Key",
    Theme: "Theme",
    TightBorder: "Tight Border",
    SendPreviewBubble: {
      Title: "Send Preview Bubble",
      SubTitle: "Preview markdown in bubble",
    },
    AutoGenerateTitle: {
      Title: "Auto Generate Title",
      SubTitle: "Generate a suitable title based on the conversation content",
    },
    Sync: {
      CloudState: "Last Update",
      NotSyncYet: "Not sync yet",
      Success: "Sync Success",
      Fail: "Sync Fail",

      Config: {
        Modal: {
          Title: "Config Sync",
          Check: "Check Connection",
        },
        SyncType: {
          Title: "Sync Type",
          SubTitle: "Choose your favorite sync service",
        },
        Proxy: {
          Title: "Enable CORS Proxy",
          SubTitle: "Enable a proxy to avoid cross-origin restrictions",
        },
        ProxyUrl: {
          Title: "Proxy Endpoint",
          SubTitle:
            "Only applicable to the built-in CORS proxy for this project",
        },
        AccessControl: {
          Title: "Enable Overwrite Access Control",
          SubTitle:
            "Only applicable to the overwrite access control setting such as an access code",
        },
        LockClient: {
          Title: "Enable Do Not Sync Current Data",
          SubTitle: "Only sync data from other sources, not the current data",
        },
        WebDav: {
          Endpoint: {
            Name: "WebDav Endpoint",
            SubTitle: "Configure the WebDav Endpoint",
          },
          UserName: {
            Name: "User Name",
            SubTitle: "Configure the User Name",
          },
          Password: {
            Name: "Password",
            SubTitle: "Configure the Password",
          },
          FileName: {
            Name: "File Name",
            SubTitle:
              "File Name, for example: backtrackz.json (must be a JSON file)",
          },
        },
        GithubGist: {
          GistID: {
            Name: "Github Gist ID",
            SubTitle:
              "Your Gist ID location, for example: gist.github.com/H0llyW00dzZ/<gistid>/etc. copy then paste the <gistid> here.",
          },
          FileName: {
            Name: "File Name",
            SubTitle:
              "File Name, for example: backtrackz.json (must be a JSON file)",
          },
          AccessToken: {
            Name: "Access Token",
            SubTitle:
              "Make sure you have permission for syncing. Enable Private & Public there.",
          },
        },

        UpStash: {
          Endpoint: "UpStash Redis REST Url",
          UserName: "Backup Name",
          Password: "UpStash Redis REST Token",
        },

        GoSync: {
          Endpoint: "GoSync REST Url",
          UserName: "Backup Name",
          Password: "GoSync REST Token",
          FileName: "File Name",
        },

      },

      LocalState: "Local Data",
      Overview: (overview: any) => {
        return `${overview.chat} chats，${overview.message} messages，${overview.prompt} prompts，${overview.mask} masks`;
      },
      ImportFailed: "Failed to import from file",
    },
    Mask: {
      Splash: {
        Title: "Mask Splash Screen",
        SubTitle: "Show a mask splash screen before starting new chat",
      },
      Builtin: {
        Title: "Hide Builtin Masks",
        SubTitle: "Hide builtin masks in mask list",
      },
    },
    Prompt: {
      Disable: {
        Title: "Disable auto-completion",
        SubTitle: "Input / to trigger auto-completion",
      },
      List: "Prompt List",
      ListCount: (builtin: number, custom: number) =>
        `${builtin} built-in, ${custom} user-defined`,
      Edit: "Edit",
      Modal: {
        Title: "Prompt List",
        Add: "Add One",
        Search: "Search Prompts",
      },
      EditModal: {
        Title: "Edit Prompt",
      },
    },
    HistoryCount: {
      Title: "Attached Messages Count",
      SubTitle: "Number of sent messages attached per request",
    },
    CompressThreshold: {
      Title: "History Compression Threshold",
      SubTitle:
        "Will compress if uncompressed messages length exceeds the value",
    },
    Token: {
      Title: "API Key",
      SubTitle: "Use your key to ignore access code limit",
      Placeholder: "OpenAI API Key",
    },

    Usage: {
      Title: "Account Balance",
      SubTitle(used: any, total: any) {
        const hardLimitusd = total.hard_limit_usd !== undefined ? new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(total.hard_limit_usd) : "unknown";
        const hardLimit = total.system_hard_limit_usd !== undefined ? new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(total.system_hard_limit_usd) : "unknown";
        const usedFormatted = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(used);
        return `Used this month ${usedFormatted}, Hard limit ${hardLimitusd}, Approved usage limit ${hardLimit}`;
      },
      IsChecking: "Checking...",
      Check: "Check",
      NoAccess: `Enter Session Key in API Key starting with prefix "sess-" to check balance.`,
    },
    AccessCode: {
      Title: "Access Code",
      SubTitle: "Access control enabled",
      Placeholder: "Need Access Code",
    },
    Endpoint: {
      Title: "Endpoint",
      SubTitle: "Custom endpoint must start with http(s)://",
    },
    Access: {
      AccessCode: {
        Title: "Access Code",
        SubTitle: "Access control Enabled",
        Placeholder: "Enter Code",
      },
      CustomEndpoint: {
        Title: "Custom Endpoint",
        SubTitle: "Use custom Azure or OpenAI service",
      },
      Provider: {
        Title: "Model Provider",
        SubTitle: "Select Azure or OpenAI",
      },
      OpenAI: {
        ApiKey: {
          Title: "OpenAI API Key",
          SubTitle: "User custom OpenAI Api Key",
          Placeholder: "sk-xxx",
        },

        Endpoint: {
          Title: "OpenAI Endpoint",
          SubTitle: "Must starts with http(s):// or use /api/openai as default",
        },
      },
      Azure: {
        ApiKey: {
          Title: "Azure Api Key",
          SubTitle: "Check your api key from Azure console",
          Placeholder: "Azure Api Key",
        },

        Endpoint: {
          Title: "Azure Endpoint",
          SubTitle: "Example: ",
        },

        ApiVerion: {
          Title: "Azure Api Version",
          SubTitle: "Check your api version from azure console",
        },
      },
      CustomModel: {
        Title: "Custom Models",
        SubTitle: "Custom model options, seperated by comma",
      },
    },

    Model: "Model",
    Temperature: {
      Title: "Temperature",
      SubTitle: "A larger value makes the more random output",
    },
    TopP: {
      Title: "Top P",
      SubTitle: "Do not alter this value together with temperature",
    },
    MaxTokens: {
      Title: "Max Tokens",
      SubTitle: "Maximum length of input tokens and generated tokens",
    },
    PresencePenalty: {
      Title: "Presence Penalty",
      SubTitle:
        "A larger value increases the likelihood to talk about new topics",
    },
    FrequencyPenalty: {
      Title: "Frequency Penalty",
      SubTitle:
        "A larger value decreasing the likelihood to repeat the same line",
    },
    NumberOfImages: {
      Title: "Number Image Create",
      SubTitle:
        "A number of images to generate\nMust be between 1 and 10. For dall-e-3, only 1 is supported.",
    },
    QualityOfImages: {
      Title: "Quality Image Create",
      SubTitle:
        "A quality of the image that will be generated\nThis Configuration is only supported for dall-e-3.",
    },
    SizeOfImages: {
      Title: "Size Image",
      SubTitle:
        "A size of the generated images\nDALL·E-2 : Must be one of `256x256`, `512x512`, or `1024x1024`.\nDALL-E-3 : Must be one of `1024x1024`, `1792x1024`, or `1024x1792`.",
    },
    StyleOfImages: {
      Title: "Style Image",
      SubTitle:
        "A style of the generated images\nMust be one of vivid or natural\nThis Configuration is only supported for dall-e-3",
    },
    SysFingerPrint: {
      Title : "System Finger Print A.k.a Seeds",
      SubTitle:
      "A fingerprint represents the backend configuration that the model runs with.",
    },
    TextModeration: {
      Title: "Text Moderation",
      SubTitle:
        "A Text Moderation to check whether content complies with OpenAI's usage policies.",
    },
  },
  Store: {
    DefaultTopic: "New Conversation",
    BotHello: "Hello! How can I assist you today?",
    Error: "Something went wrong, please try again later.",
    Prompt: {
      History: (content: string) =>
        "This is a summary of the chat history as a recap: " + content,
      Topic:
        "Please generate a four to five word title summarizing our conversation without any lead-in, punctuation, quotation marks, periods, symbols, or additional text. Remove enclosing quotation marks.",
      Summarize:
        "Summarize the discussion briefly in 200 words or less to use as a prompt for future context.",
    },
  },
  Copy: {
    Success: "Copied to clipboard",
    Failed: "Copy failed, please grant permission to access clipboard",
  },
  Download: {
    Success: "Content downloaded to your directory.",
    Failed: "Download failed.",
  },
  Context: {
    Toast: (x: any) => `With ${x} contextual prompts`,
    Edit: "Current Chat Settings",
    Add: "Add a Prompt",
    Clear: "Context Cleared",
    Revert: "Revert",
    ModelsDalle: (x: any) => `You are an AI Image explanation assistant based on request starting request from:\n "${x}"\n\n
    - Your responses should be informative and logical.\n
    - Keep your answers impersonal.\n
    - You don't have to mention that I'm unable to directly display images since you are AI text-based model.\n
    - You don't have to mention that I apologize, since you are a text-based AI model.\n
    - Replying and end the conversation.\n
    - Keep Follow Rules.`,
  },
  Plugin: {
    Name: "Plugin",
  },
  FineTuned: {
    Sysmessage: "You are an assistant that",
  },
  Changelog: {
    Name: "Change Log",
  },
  PrivacyPage: {
    Name: "Privacy",
    Confirm: "Agree",
  },
  Mask: {
    Name: "Mask",
    Page: {
      Title: "Prompt Template",
      SubTitle: (count: number) => `${count} prompt templates`,
      Search: "Search Templates",
      Create: "Create",
    },
    Item: {
      Info: (count: number) => `${count} prompts`,
      Chat: "Chat",
      View: "View",
      Edit: "Edit",
      Delete: "Delete",
      DeleteConfirm: "Confirm to delete?",
    },
    EditModal: {
      Title: (readonly: boolean) =>
        `Edit Prompt Template ${readonly ? "(readonly)" : ""}`,
      Download: "Download",
      Clone: "Clone",
    },
    Config: {
      Avatar: "Bot Avatar",
      Name: "Bot Name",
      Sync: {
        Title: "Use Global Config",
        SubTitle: "Use global config in this chat",
        Confirm: "Confirm to override custom config with global config?",
      },
      HideContext: {
        Title: "Hide Context Prompts",
        SubTitle: "Do not show in-context prompts in chat",
        UnHide: "Show Context prompts in chat",
        Hide: "Hide Context prompts in chat",
      },
      Share: {
        Title: "Share This Mask",
        SubTitle: "Generate a link to this mask",
        Action: "Copy Link",
      },
    },
  },
  NewChat: {
    Return: "Return",
    Skip: "Just Start",
    Title: "Pick a Mask",
    SubTitle: "Chat with the Soul behind the Mask",
    More: "Find More",
    NotShow: "Never Show Again",
    ConfirmNoShow: "Confirm to disable？You can enable it in settings later.",
  },

  UI: {
    Confirm: "Confirm",
    Cancel: "Cancel",
    Close: "Close",
    Create: "Create",
    Edit: "Edit",
    Export: "Export",
    Import: "Import",
    Sync: "Sync",
    Config: "Config",
  },
  Exporter: {
    Model: "Model",
    Messages: "Messages",
    Topic: "Topic",
    Time: "Date & Time",
  },

  URLCommand: {
    Code: "Detected access code from url, confirm to apply? ",
    Settings: "Detected settings from url, confirm to apply?",
  },
};

export default en;
