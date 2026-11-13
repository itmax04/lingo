import { createHandler } from "./app";
import type { Env } from "./env";
import { routes } from "./routes";

// The entry module exports the handler only: the Workers runtime refuses any other export.
export default { fetch: createHandler(routes) } satisfies ExportedHandler<Env>;
