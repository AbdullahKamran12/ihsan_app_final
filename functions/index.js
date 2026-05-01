const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {GoogleGenerativeAI} = require("@google/generative-ai");

const GEMINI_KEY = defineSecret("GEMINI_KEY");

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