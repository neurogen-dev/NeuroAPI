import tauriConfig from "../../src-tauri/tauri.conf.json";

export const getBuildConfig = () => {
  const buildMode = process.env.BUILD_MODE ?? "standalone";
  const isApp = !!process.env.BUILD_APP;
  const version = "v" + tauriConfig.package.version;
  const isSysHasOpenaiApiKey = !!process.env.OPENAI_API_KEY

  const commitInfo = (() => {
    try {
      const childProcess = require("child_process");
      const commitDate: string = childProcess
        .execSync('git log -1 --format="%at000" --date=unix')
        .toString()
        .trim();
      const commitHash: string[] = childProcess
        .execSync('git log --pretty=format:"%H" -n 10')
        .toString()
        .trim()
        .split("\n");
      const commitMessage: string = childProcess
        .execSync('git log --pretty=format:"%B" -n 10')
        .toString()
        .trim();
      const Author: string = childProcess
        .execSync('git log --pretty=format:"%an" -n 1')
        .toString()
        .trim();
      const coAuthorLine: string = childProcess
        .execSync('git log --format="%h %(trailers:key=Co-authored-by)" -n 10')
        .toString()
        .trim();
      const coAuthorMatch: RegExpMatchArray | null = coAuthorLine.match(
        /Co-Authored-By:\s*(.*)|Co-authored-by:\s*(.*)/
      );
      const coAuthors: string[] = coAuthorMatch
        ? coAuthorLine
          .split(":")
          .slice(1)
          .map((author) => author.trim())
        : [];

      const coAuthored: boolean = coAuthors.length > 0;

      const [title, ...messages] = commitMessage.split("\n");

      const uniqueMessages = messages
        .filter((message) => !message.startsWith("Co-authored-by:"))
        .filter((message) => !message.startsWith("Signed-off-by:"))
        .map((message) => message.replace(/\r/g, ""))
        .filter((message) => message.trim() !== "");

      const signedOffBy: string[] = commitMessage
        .split("\n")
        .map((line) => line.trim())
        .filter((line) => line.startsWith("Signed-off-by:"))
        .map((line) => line.substring("Signed-off-by:".length).trim().split(" <")[0])
        .filter((author, index, self) => self.indexOf(author) === index);

      const coAuthoredBy: string[] = commitMessage
        .split("\n")
        .map((line) => line.trim())
        .filter((line) => line.startsWith("Co-Authored-By:") || line.startsWith("Co-authored-by:"))
        .map((line) => line.substring("Co-Authored-By:".length).trim().split(" <")[0])
        .filter((author, index, self) => self.indexOf(author) === index);

      const commitMessageObj = {
        summary: title || "No title",
        description: uniqueMessages.length > 0 ? uniqueMessages : undefined,
        "Co-authored-by": coAuthoredBy.length > 0 ? coAuthoredBy : undefined,
        "Signed-off-by": signedOffBy.length > 0 ? signedOffBy : undefined,
      };

      return {
        commitDate,
        commitHash,
        commitMessage: commitMessageObj,
        Author,
        coAuthored,
      };
    } catch (e) {
      console.error("[Build Config] No git or not from git repo.");
      return {
        commitDate: "unknown",
        commitHash: [],
        commitMessage: {
          summary: "unknown",
          description: undefined,
          "Co-authored-by": undefined,
          "Signed-off-by": undefined,
        },
        Author: "unknown",
        coAuthored: undefined,
      };
    }
  })();

  return {
    version,
    ...commitInfo,
    buildMode,
    isApp,
    isSysHasOpenaiApiKey,
  };
};

export type BuildConfig = ReturnType<typeof getBuildConfig>;
