const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {GoogleGenerativeAI} = require("@google/generative-ai");

// ─── SECRETS ─────────────────────────────────────────────────
const GEMINI_KEY       = defineSecret("GEMINI_KEY");
const MAPS_WEB_KEY     = defineSecret("MAPS_WEB_KEY");
const MAPS_ANDROID_KEY = defineSecret("MAPS_ANDROID_KEY");
const MAPS_IOS_KEY     = defineSecret("MAPS_IOS_KEY");
const MAP_OVERALL_WORKING_KEY = defineSecret("MAP_OVERALL_WORKING_KEY");

// ─── GEMINI HELPER ────────────────────────────────────────────
async function callGeminiWithRetry(genAI, contents, retries = 1) {
  const model = genAI.getGenerativeModel({
    model: "gemini-2.5-flash",
    systemInstruction: "You are a precise data extraction assistant. Follow the user's instructions exactly. Return only valid JSON with no extra text, markdown, or explanation.",
  });

  for (let i = 0; i < retries; i++) {
    try {
      console.log(`Attempt ${i + 1}`);
      const result = await model.generateContent({contents});
      return result.response;
    } catch (err) {
      const isRetryable =
        err.status === 503 ||
        err.status === 429 ||
        err.status === 500 ||
        err.message?.includes("overloaded") ||
        err.message?.includes("503");

      if (isRetryable && i < retries - 1) {
        const wait = (i + 1) * 15000;
        console.log(`Overloaded, retrying in ${wait}ms...`);
        await new Promise((r) => setTimeout(r, wait));
      } else {
        throw err;
      }
    }
  }
}

// ─── FUNCTION: askGemini ──────────────────────────────────────
exports.askGemini = onCall(
    {
      secrets: [GEMINI_KEY],
      timeoutSeconds: 300,
      memory: "512MiB",
    },
    async (request) => {
      try {
        const {prompt, image, mime = "image/jpeg"} = request.data;

        if (!prompt) {
          throw new HttpsError("invalid-argument", "Prompt is required");
        }

        const genAI = new GoogleGenerativeAI(GEMINI_KEY.value());

        const parts = [];
        parts.push({text: prompt});
        if (image) {
          parts.push({inlineData: {mimeType: mime, data: image}});
        }

        const contents = [{role: "user", parts}];
        const response = await callGeminiWithRetry(genAI, contents);

        return {text: response.text()};
      } catch (err) {
        console.error("askGemini error:", err);
        if (err instanceof HttpsError) throw err;
        throw new HttpsError("internal", err.message || "Unknown error");
      }
    },
);

// ─── FUNCTION: getMapsKeys ────────────────────────────────────
// Called by your website and Flutter app at runtime.
// Pass { platform: 'web' | 'android' | 'ios' } and get back { key: '...' }.
//
// Dart:
//   final result = await FirebaseFunctions.instance
//       .httpsCallable('getMapsKeys')
//       .call({'platform': 'android'});
//   final key = result.data['key'] as String;
//
// Website (ihsan.html):
//   const fn = firebase.functions().httpsCallable('getMapsKeys');
//   const { data } = await fn({ platform: 'web' });
//   // inject data.key into the Maps <script> URL
exports.getMapsKeys = onCall(
    {
      secrets: [MAPS_WEB_KEY, MAPS_ANDROID_KEY, MAPS_IOS_KEY, MAP_OVERALL_WORKING_KEY],
      timeoutSeconds: 10,
      memory: "128MiB",
      cors: ["https://ihsanapp-e2d2d.web.app", "https://ihsanmasjid.com", "https://www.ihsanmasjid.com"],
    },
    async (request) => {
      // Uncomment to restrict to signed-in users only:
      // if (!request.auth) {
      //   throw new HttpsError("unauthenticated", "Login required");
      // }

      const {platform} = request.data;

      switch (platform) {
        case "web":     return {key: MAPS_WEB_KEY.value()};
        case "android": return {key: MAPS_ANDROID_KEY.value()};
        case "ios":     return {key: MAPS_IOS_KEY.value()};
        case "overall": return {key: MAP_OVERALL_WORKING_KEY.value()};
        default:
          throw new HttpsError(
              "invalid-argument",
              "platform must be 'web', 'android' or 'ios' or 'overall'",
          );
      }
    },
);