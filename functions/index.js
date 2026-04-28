const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {GoogleGenerativeAI} = require("@google/generative-ai");

const GEMINI_KEY = defineSecret("GEMINI_KEY");

async function callGeminiWithRetry(model, contents, retries = 3) {
  for (let i = 0; i < retries; i++) {
    try {
      const result = await model.generateContent({contents});
      return result.response;
    } catch (err) {
      const is503 = err.status === 503 || err.message?.includes("503");
      if (is503 && i < retries - 1) {
        const wait = (i + 1) * 3000;
        console.log(`Gemini 503, retrying in ${wait}ms...`);
        await new Promise((r) => setTimeout(r, wait));
      } else {
        throw err;
      }
    }
  }
}

exports.askGemini = onCall(
    {
      secrets: [GEMINI_KEY],
      invoker: "public",
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
        const model = genAI.getGenerativeModel({model: "gemini-2.5-flash"});

        const parts = [{text: prompt}];
        if (image) {
          parts.push({inlineData: {mimeType: mime, data: image}});
        }

        const contents = [{role: "user", parts}];
        const response = await callGeminiWithRetry(model, contents);

        return {text: response.text()};
      } catch (err) {
        console.error("askGemini error:", err);
        throw new HttpsError("internal", err.message || "Unknown error");
      }
    },
);