import {
	TsonAsyncOptions,
	createTsonParseEventSource,
	createTsonParseJsonStreamResponse,
	createTsonSSEResponse,
	createTsonSerializeJsonStreamResponse,
	tsonAsyncIterable,
	tsonBigint,
	tsonPromise,
} from "tupleson";

/**
 * Shared tupleSON options for the server and client for later.
 */
export const tsonOptions: TsonAsyncOptions = {
	// We need to specify the types we want to allow serialization of
	types: [
		// Allow serialization of promises
		tsonPromise,
		// Allow serialization of async iterators
		tsonAsyncIterable,
		// Allow serialization of bigints
		tsonBigint,
	],
};
export const createSSEResponse = createTsonSSEResponse(tsonOptions);
export const createEventSource = createTsonParseEventSource(tsonOptions);

export const createJsonStreamResponse =
	createTsonSerializeJsonStreamResponse(tsonOptions);
export const parseJsonStreamResponse =
	createTsonParseJsonStreamResponse(tsonOptions);

export function isAbortError(err: unknown): err is Error {
	return err instanceof Error && err.message.includes("aborted");
}
