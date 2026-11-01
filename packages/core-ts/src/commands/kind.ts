/** Commands (R-14…R-22), in Swift `CommandKind.allCases` order. */
export const COMMAND_KINDS = ["repeat", "slower", "how_to_say", "explain", "continue", "mistakes", "finish"] as const;
export type CommandKind = (typeof COMMAND_KINDS)[number];

/** Executed locally, without the model (R-14, R-15, R-22): repeat and slower never call a provider. */
export function isLocalCommand(k: CommandKind): boolean {
  return k === "repeat" || k === "slower";
}
