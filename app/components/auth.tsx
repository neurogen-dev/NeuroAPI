import styles from "./auth.module.scss";
import { IconButton } from "./button";

import { useNavigate } from "react-router-dom";
import { Path } from "../constant";
import { useAccessStore } from "../store";
import Locale from "../locales";

import BotIcon from "../icons/bot.svg";
import { getClientConfig } from "../config/client";

export function AuthPage() {
  const navigate = useNavigate();
  const accessStore = useAccessStore();

  const goHome = () => navigate(Path.Home);
  const resetAccessCode = () => {
    accessStore.update((access) => {
      access.openaiApiKey = "";
      access.accessCode = "";
    });
  }; // Reset access code to empty string
  const goPrivacy = () => navigate(Path.PrivacyPage);
  const isApp = getClientConfig()?.isApp;
  const isSysHasOpenaiApiKey = getClientConfig()?.isSysHasOpenaiApiKey;

  return (
    <div className={styles["auth-page"]}>
      <div className={`no-dark ${styles["auth-logo"]}`}>
        <BotIcon />
      </div>

      <div className={styles["auth-title"]}>{Locale.Auth.Title}</div>
      <div className={styles["auth-tips"]}>{Locale.Auth.Tips}</div>

      {!isApp && ( // Conditionally render the input access code based on whether it's not an app
        <>
          {isSysHasOpenaiApiKey ? (
            <>
              <input
                className={styles["auth-input"]}
                type="password"
                placeholder={Locale.Auth.Input}
                value={accessStore.accessCode}
                onChange={(e) => {
                  accessStore.update(
                    (access) => (access.accessCode = e.currentTarget.value),
                  );
                }}
              />
              <div className={styles["auth-tips"]}>{Locale.Auth.SubTips}</div>
              <input
              className={styles["auth-input"]}
              type="password"
              placeholder={Locale.Settings.Token.Placeholder}
              value={accessStore.openaiApiKey}
              onChange={(e) => {
                accessStore.update(
                  (access) => (access.openaiApiKey = e.currentTarget.value),
                );
              }}
            />
            </>
          ) : (
            <>
              <div className={styles["auth-tips"]}>{Locale.Auth.SubTips}</div>
              <input
                className={styles["auth-input"]}
                type="password"
                placeholder={Locale.Settings.Token.Placeholder}
                value={accessStore.openaiApiKey}
                onChange={(e) => {
                  accessStore.update(
                    (access) => (access.openaiApiKey = e.currentTarget.value),
                  );
                }}
              />
            </>
          )}
        </>
      )}

      {isApp && ( // Conditionally render the input access token based on whether it's an app
        <>
          <div className={styles["auth-tips"]}>{Locale.Auth.SubTips}</div>
          <input
            className={styles["auth-input"]}
            type="password"
            placeholder={Locale.Settings.Access.OpenAI.ApiKey.Placeholder}
            value={accessStore.openaiApiKey}
            onChange={(e) => {
              accessStore.update(
                (access) => (access.openaiApiKey = e.currentTarget.value),
              );
            }}
          />
        </>
      )}

      <div className={styles["auth-actions"]}>
        <IconButton
          text={Locale.Auth.Confirm}
          type="primary"
          onClick={goPrivacy}
        />
        <IconButton
          text={Locale.Auth.Later}
          onClick={() => {
            resetAccessCode();
            goHome();
          }}
        />
      </div>
    </div>
  );
}
