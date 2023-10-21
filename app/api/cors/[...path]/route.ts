import { NextRequest, NextResponse } from "next/server";

async function handle(
  req: NextRequest,
  { params }: { params: { path: string[] } },
) {
  if (req.method === "OPTIONS") {
    return NextResponse.json({ body: "OK" }, { status: 200 });
  }

  const [protocol, ...subpath] = params.path;
  const targetUrl = `${protocol}://${subpath.join("/")}`;

  const method = req.headers.get("method") ?? undefined;
  const shouldNotHaveBody = ["get", "head"].includes(
    method?.toLowerCase() ?? "",
  );

  function isRealDevicez(userAgent: string | null): boolean {
    // Author : @H0llyW00dzZ
    // Note : This just an experiment for a prevent suspicious bot
    // Modify this function to define your logic for determining if the user-agent belongs to a real device
    // For example, you can check if the user-agent contains certain keywords or patterns that indicate a real device
    if (userAgent) {
      return userAgent.includes("AppleWebKit") && !userAgent.includes("Headless");
    }
    return false;
  }
  

  const userAgent = req.headers.get("User-Agent");
  const isRealDevice = isRealDevicez(userAgent);

  if (!isRealDevice) {
    return NextResponse.json(
      {
        error: true,
        msg: "Access Forbidden",
      },
      {
        status: 403,
      },
    );
  }

  const fetchOptions: RequestInit = {
    headers: {
      authorization: req.headers.get("authorization") ?? "",
    },
    body: shouldNotHaveBody ? null : req.body,
    method,
    // @ts-ignore
    duplex: "half",
  };

  const fetchResult = await fetch(targetUrl, fetchOptions);

  console.log("[Cloud Sync]", targetUrl, {
    status: fetchResult.status,
    statusText: fetchResult.statusText,
  });

  return fetchResult;
}

export const POST = handle;
export const GET = handle;
export const OPTIONS = handle;

export const runtime = "edge";
