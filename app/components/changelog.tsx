import styles from "./changelog.module.scss";
import { IconButton } from "./button";
import { getClientConfig } from "@/app/config/client";

import { useNavigate } from "react-router-dom";
import { useEffect, useState } from "react";
import { Path } from "../constant";
import Locale from "../locales";

import ConfirmIcon from "../icons/confirm.svg";
import LoadingIcon from "../icons/three-dots.svg";
import dynamic from "next/dynamic";

const Markdown = dynamic(async () => (await import("./markdown")).Markdown, {
  loading: () => <LoadingIcon />,
});

export function ChangeLog(props: { onClose?: () => void }) {
  const navigate = useNavigate();
  const [mdText, setMdText] = useState("");
  const [pageTitle] = useState("📌 Change Log 📝");

  useEffect(() => {
    const fetchData = async () => {
      const commitInfo = getClientConfig();

      let table = `## 🚀 What's Changed ? ${commitInfo?.commitDate
          ? new Date(parseInt(commitInfo.commitDate)).toLocaleString()
          : "Unknown Date"
      } 🗓️\n`;

      if (commitInfo?.commitMessage.description) {
        const author = commitInfo.Author?.replace(/\s/g, "") || "Unknown Author";
        const coAuthored = commitInfo.commitMessage["Co-authored-by"] || [];
        const uniqueCoAuthored = [...new Set(coAuthored)]; // Filter out duplicates
        const changes = commitInfo.commitMessage.description.filter(
          (change: string) => !change.startsWith("...")
        );
        const changesFormatted = changes
          .map((change: string) => `\n\n\n   ${change}\n\n`)
          .join("\n\n\n");

        let coAuthorsSection = "";
        if (uniqueCoAuthored.length > 0) {
          const coAuthorLinks = uniqueCoAuthored.map(
            (coAuthor: string) =>
              `[${coAuthor.replace("[bot]", "").replace(/\s/g, "")}](https://github.com/${coAuthor.replace("[bot]", "").replace(/\s/g, "")})`
          );
          coAuthorsSection = `(Co-Authored by ${coAuthorLinks.join(", ")})`;
        }

        const authorSection = `[${author.replace("[bot]", "").replace(/\s/g, "")}](https://github.com/${author.replace("[bot]", "").replace(/\s/g, "")}) ${coAuthorsSection}`;
        const prLinkRegex = /#(\d+)/g; // Regular expression to match '#<number>' ref : autolinks github
        const prLink = commitInfo?.commitMessage.summary.replace(prLinkRegex, '[$&](https://github.com/H0llyW00dzZ/NeuroGPT/pull/$1/commits)');
        const descriptionWithLinks = commitInfo?.commitMessage.description.map((change: string) =>
          change.replace(prLinkRegex, '[$&](https://github.com/H0llyW00dzZ/NeuroGPT/pull/$1/commits)')
        ).join('\n\n\n');

        table += `\n\n\n![GitHub contributors](https://img.shields.io/github/contributors/Yidadaa/NeuroGPT.svg) ![GitHub commits](https://badgen.net/github/commits/H0llyW00dzZ/NeuroGPT) ![GitHub license](https://img.shields.io/github/license/H0llyW00dzZ/NeuroGPT) [![GitHub forks](https://img.shields.io/github/forks/Yidadaa/NeuroGPT.svg)](https://github.com/Yidadaa/NeuroGPT/network/members) [![GitHub stars](https://img.shields.io/github/stars/Yidadaa/NeuroGPT.svg)](https://github.com/Yidadaa/NeuroGPT/stargazers) [![Github All Releases](https://img.shields.io/github/downloads/Yidadaa/NeuroGPT/total.svg)](https://github.com/Yidadaa/NeuroGPT/releases/) [![CI: CodeQL Unit Testing Advanced](https://github.com/H0llyW00dzZ/NeuroGPT/actions/workflows/codeql.yml/badge.svg)](https://github.com/H0llyW00dzZ/NeuroGPT/actions/workflows/codeql.yml) \n\n\n  [![GitHub](https://img.shields.io/badge/--181717?logo=github&logoColor=ffffff)](https://github.com/${author}) ![${author.replace("[bot]", "")}](https://github.com/${author.replace("[bot]", "")}.png?size=25) ${authorSection} :\n\n${prLink}\n\n\n${descriptionWithLinks}\n\n\n\n\n\n`;
      } else {
        table += `###${commitInfo?.commitMessage.summary}###\nNo changes\n\n`;
      }

      setMdText(table);
    };

    fetchData();

  }, []);

  return (
    <div className={styles["changelog-page"]}>
      <div className={`changelog-title ${styles["changelog-title"]}`}>
        {pageTitle}
      </div>
      <div className={styles["changelog-content"]}>
        <div className={styles["markdown-body"]}>
          <Markdown content={mdText} />
        </div>
      </div>
      <div className={styles["changelog-actions"]}>
        <div className={styles["changelog-actions-button"]}>
          <IconButton
            text={Locale.UI.Close}
            icon={<ConfirmIcon />}
            onClick={() => navigate(-1)}
            bordered
          />
        </div>
      </div>
    </div>
  );
}
