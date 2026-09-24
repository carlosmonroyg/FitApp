// Pruebas de la validación server-side: el modelo solo puede tocar lo que existe.
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { validateChanges } = require("../lib/coach.js");

const snapshot = {
  week: [
    { exercises: [
      { id: "a", name: "Press banca", bodyPart: "chest" },
      { id: "b", name: "Remo", bodyPart: "back" },
    ] },
  ],
  alternatives: { a: [{ id: "a2", name: "Press inclinado" }] },
};

const c = (o) => ({ bodyPart: null, delta: null, fromId: null, toId: null, exerciseId: null, action: null, reason: "r", ...o });

test("acota series a ±1 y descarta partes que no están en la semana", () => {
  const out = validateChanges([
    c({ type: "sets", bodyPart: "chest", delta: 3 }),
    c({ type: "sets", bodyPart: "chest", delta: -1 }), // duplicada: fuera
    c({ type: "sets", bodyPart: "upper legs", delta: 1 }), // no está: fuera
  ], snapshot);
  assert.equal(out.length, 1);
  assert.equal(out[0].delta, 1);
});

test("solo un ajuste de descanso, normalizado a ±15", () => {
  const out = validateChanges([
    c({ type: "rest", delta: 40 }),
    c({ type: "rest", delta: -15 }),
  ], snapshot);
  assert.equal(out.length, 1);
  assert.equal(out[0].delta, 15);
});

test("sustituciones solo desde las alternativas dadas", () => {
  const out = validateChanges([
    c({ type: "swap", fromId: "a", toId: "a2" }),
    c({ type: "swap", fromId: "a", toId: "zzz" }),
    c({ type: "swap", fromId: "b", toId: "a2" }),
  ], snapshot);
  assert.equal(out.length, 1);
  assert.equal(out[0].toName, "Press inclinado");
});

test("progresión y evitar resuelven el nombre y descartan ids inventados", () => {
  const out = validateChanges([
    c({ type: "progression", exerciseId: "b", action: "add_weight" }),
    c({ type: "progression", exerciseId: "nope", action: "hold" }),
    c({ type: "avoid", exerciseId: "a" }),
  ], snapshot);
  assert.deepEqual(out.map((x) => [x.type, x.exerciseName]), [
    ["progression", "Remo"],
    ["avoid", "Press banca"],
  ]);
});

test("nunca más de 5 cambios", () => {
  const many = Array.from({ length: 8 }, (_, i) =>
    c({ type: "progression", exerciseId: i % 2 ? "a" : "b", action: "hold" }));
  assert.equal(validateChanges(many, snapshot).length, 5);
});
