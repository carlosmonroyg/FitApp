# FitApp · backend del coach

Cloud Function `coachCheckin` (TypeScript, Node 22): recibe el snapshot del
atleta que arma la app, llama a Claude, valida la respuesta contra el
catálogo y la guarda en `users/{uid}/coach/…`. Una llamada por usuario y
semana (la segunda vez devuelve la guardada).

## Probar en local (sin plan Blaze)

1. Crea una clave en <https://console.anthropic.com> → *API keys*.
2. Copia `.secret.local.example` como `.secret.local` y pega la clave.
   (Opcional: copia `.env.example` como `.env` para elegir el modelo.)
3. Compila y arranca el emulador desde la raíz del repo:

   ```bash
   cd functions && npm install && npm run build && cd ..
   firebase emulators:start --only functions
   ```

   La función queda en `http://127.0.0.1:5001/fitapp-f888e/us-central1/coachCheckin`
   y el panel en <http://127.0.0.1:4000>.

4. Corre la app apuntando al emulador:
   - **Emulador Android**: `flutter run` (en debug usa `10.0.2.2:5001` solo).
   - **Teléfono físico** en la misma Wi-Fi: averigua la IP de tu PC
     (`ipconfig` → IPv4) y lanza
     `flutter run --dart-define=COACH_EMULATOR_HOST=192.168.1.20`.

5. En la app, inicia sesión con Google, entrena y registra series, y toca
   la tarjeta **Tu coach** en *Hoy* → *Pedir ahora*. En desarrollo hay un
   botón ↻ en la pantalla del coach para volver a pedir (`force`).

El emulador de Functions escribe en el Firestore **real** del proyecto
(`users/{uid}/coach/…`); es tu propia cuenta, así que no pasa nada.

## Producción

```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase deploy --only functions
```

Requiere plan Blaze. El modelo se elige con `COACH_MODEL` en `functions/.env`
(`claude-opus-5` por defecto; `claude-haiku-4-5` ≈ 5× más barato).
Los logs (`firebase functions:log`) muestran tokens de entrada, salida y
caché por check-in para vigilar el costo.
