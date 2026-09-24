import Anthropic from "@anthropic-ai/sdk";
import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

import { COACH_MODEL, runCheckin } from "./coach";

initializeApp();

// En producción: `firebase functions:secrets:set ANTHROPIC_API_KEY`.
// En el emulador: functions/.secret.local (ver .secret.local.example).
const anthropicKey = defineSecret("ANTHROPIC_API_KEY");

/** Lunes (yyyy-MM-dd) de la semana de una fecha, para tener un check-in por semana. */
function weekIdOf(dateStr: string): string {
  const d = new Date(dateStr + "T00:00:00Z");
  const day = (d.getUTCDay() + 6) % 7; // lunes = 0
  d.setUTCDate(d.getUTCDate() - day);
  return d.toISOString().slice(0, 10);
}

/**
 * Check-in semanal del coach.
 *
 * Entrada: { snapshot, force? }. El snapshot lo arma la app (AthleteSnapshot).
 * Salida: el check-in validado. Se guarda en users/{uid}/coach/checkins/{weekId}
 * y, salvo `force`, se devuelve el existente si ya hubo uno esta semana: es
 * la única llamada al modelo por usuario y semana, así el costo queda acotado.
 */
export const coachCheckin = onCall(
  { secrets: [anthropicKey], region: "us-central1", timeoutSeconds: 120, memory: "256MiB" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Inicia sesión para usar el coach.");

    const snapshot = request.data?.snapshot;
    if (!snapshot || typeof snapshot !== "object" || typeof snapshot.today !== "string") {
      throw new HttpsError("invalid-argument", "Falta el snapshot del atleta.");
    }
    const force = request.data?.force === true;
    const weekId = weekIdOf(snapshot.today);

    const db = getFirestore();
    const userRef = db.collection("users").doc(uid);
    const checkinRef = userRef.collection("coach").doc("checkins").collection("items").doc(weekId);

    if (!force) {
      const existing = await checkinRef.get();
      if (existing.exists) {
        logger.info("checkin cached", { uid, weekId });
        return { ...existing.data(), cached: true };
      }
    }

    const client = new Anthropic({ apiKey: anthropicKey.value() });
    let result;
    try {
      result = await runCheckin(client, snapshot);
    } catch (err) {
      if (err instanceof Anthropic.AuthenticationError) {
        throw new HttpsError("failed-precondition", "La clave de API del coach no es válida.");
      }
      if (err instanceof Anthropic.RateLimitError) {
        throw new HttpsError("resource-exhausted", "El coach está saturado; inténtalo en un minuto.");
      }
      if (err instanceof Anthropic.APIError) {
        logger.error("anthropic error", { status: err.status, message: err.message });
        throw new HttpsError("unavailable", "El coach no respondió. Inténtalo más tarde.");
      }
      throw err;
    }

    const payload = {
      weekId,
      createdAt: new Date().toISOString(),
      model: result.model,
      ...result.checkin,
      applied: false,
    };
    await checkinRef.set({ ...payload, savedAt: FieldValue.serverTimestamp() });
    await userRef.collection("coach").doc("notes").set(
      { items: result.checkin.coachNotes, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    logger.info("checkin done", {
      uid,
      weekId,
      model: COACH_MODEL,
      input: result.usage.input_tokens,
      cacheRead: result.usage.cache_read_input_tokens,
      cacheWrite: result.usage.cache_creation_input_tokens,
      output: result.usage.output_tokens,
    });
    return { ...payload, cached: false };
  },
);
