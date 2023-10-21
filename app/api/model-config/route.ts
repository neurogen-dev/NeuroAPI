import { NextResponse } from "next/server";
import { DEFAULT_MODELS } from "@/app/constant";

async function handle() {
  const model_list = DEFAULT_MODELS.map((model) => {
    return {
      name: model.name,
      available: model.available,
    };
  });
  return NextResponse.json({ model_list });
}

export const GET = handle;
