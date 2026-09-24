import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { z } from "zod";

import { COACH_SYSTEM_PROMPT } from "./prompt";

/** Modelo del coach. Cambiarlo es cambiar esta variable de entorno. */
export const COACH_MODEL = process.env.COACH_MODEL ?? "claude-opus-5";

// ---- Esquema de salida: lo que el modelo puede decir, y nada más ----

const ChangeSchema = z.object({
  type: z.enum(["sets", "rest", "swap", "progression", "avoid"]),
  reason: z.string(),
  bodyPart: z.string().nullable(),
  delta: z.number().int().nullable(),
  fromId: z.string().nullable(),
  toId: z.string().nullable(),
  exerciseId: z.string().nullable(),
  action: z.enum(["add_weight", "add_rep", "hold", "deload"]).nullable(),
});

export const CheckinSchema = z.object({
  summary: z.string(),
  highlights: z.array(z.string()),
  changes: z.array(ChangeSchema),
  weekFocus: z.string(),
  coachNotes: z.array(z.string()),
  seekProfessional: z.boolean(),
  seekProfessionalReason: z.string().nullable(),
});

export type Checkin = z.infer<typeof CheckinSchema>;
export type Change = z.infer<typeof ChangeSchema>;

// ---- Lo mínimo que necesitamos leer del snapshot para validar ----

interface SnapshotExercise {
  id: string;
  name: string;
  bodyPart: string;
}
interface Snapshot {
  week?: { exercises?: SnapshotExercise[] }[];
  alternatives?: Record<string, { id: string; name: string }[]>;
  [key: string]: unknown;
}

/**
 * Filtra los cambios contra el snapshot: el modelo solo puede tocar lo que
 * existe. Devuelve los cambios válidos con nombres resueltos para la UI.
 */
export function validateChanges(changes: Change[], snapshot: Snapshot) {
  const exercises = new Map<string, SnapshotExercise>();
  for (const day of snapshot.week ?? []) {
    for (const e of day.exercises ?? []) exercises.set(e.id, e);
  }
  const alternatives = snapshot.alternatives ?? {};
  const bodyParts = new Set([...exercises.values()].map((e) => e.bodyPart));

  const out: (Change & { toName?: string; exerciseName?: string })[] = [];
  let swaps = 0;
  let restSeen = false;
  const setsSeen = new Set<string>();

  for (const c of changes) {
    if (out.length >= 5) break;
    switch (c.type) {
      case "sets": {
        if (!c.bodyPart || !bodyParts.has(c.bodyPart)) continue;
        if (setsSeen.has(c.bodyPart)) continue;
        const delta = Math.max(-1, Math.min(1, c.delta ?? 0));
        if (delta === 0) continue;
        setsSeen.add(c.bodyPart);
        out.push({ ...c, delta });
        break;
      }
      case "rest": {
        if (restSeen) continue;
        const delta = c.delta ?? 0;
        if (delta === 0) continue;
        restSeen = true;
        out.push({ ...c, delta: delta > 0 ? 15 : -15 });
        break;
      }
      case "swap": {
        if (swaps >= 3 || !c.fromId || !c.toId) continue;
        const alt = (alternatives[c.fromId] ?? []).find((a) => a.id === c.toId);
        if (!alt || !exercises.has(c.fromId)) continue;
        swaps++;
        out.push({ ...c, toName: alt.name });
        break;
      }
      case "progression": {
        if (!c.exerciseId || !c.action) continue;
        const ex = exercises.get(c.exerciseId);
        if (!ex) continue;
        out.push({ ...c, exerciseName: ex.name });
        break;
      }
      case "avoid": {
        if (!c.exerciseId) continue;
        const ex = exercises.get(c.exerciseId);
        if (!ex) continue;
        out.push({ ...c, exerciseName: ex.name });
        break;
      }
    }
  }
  return out;
}

/** Llama a Claude con el snapshot y devuelve el check-in ya validado. */
export async function runCheckin(
  client: Anthropic,
  snapshot: Snapshot,
): Promise<{ checkin: Checkin; usage: Anthropic.Messages.Usage; model: string }> {
  const isHaiku = COACH_MODEL.includes("haiku");
  const response = await client.messages.parse({
    model: COACH_MODEL,
    max_tokens: 4000,
    // El system prompt es fijo: se cachea y solo se paga entero la primera vez.
    system: [
      {
        type: "text",
        text: COACH_SYSTEM_PROMPT,
        cache_control: { type: "ephemeral" },
      },
    ],
    messages: [
      {
        role: "user",
        content:
          "Este es el snapshot de la persona (JSON). Haz el check-in semanal.\n\n" +
          JSON.stringify(snapshot),
      },
    ],
    output_config: {
      format: zodOutputFormat(CheckinSchema),
      // Haiku 4.5 no admite `effort`; en Opus 5 medio basta para esta tarea.
      ...(isHaiku ? {} : { effort: "medium" as const }),
    },
  });

  const parsed = response.parsed_output;
  if (!parsed) {
    throw new Error(`El coach no devolvió un check-in válido (stop_reason=${response.stop_reason})`);
  }
  const checkin: Checkin = {
    ...parsed,
    highlights: parsed.highlights.slice(0, 4),
    coachNotes: parsed.coachNotes.slice(0, 8),
    changes: validateChanges(parsed.changes, snapshot),
  };
  return { checkin, usage: response.usage, model: COACH_MODEL };
}
