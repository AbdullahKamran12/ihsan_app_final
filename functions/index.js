const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {GoogleGenerativeAI} = require("@google/generative-ai");
const https = require("https");

// ─── SECRETS ─────────────────────────────────────────────────
const GEMINI_KEY            = defineSecret("GEMINI_KEY");
const MAPS_WEB_KEY          = defineSecret("MAPS_WEB_KEY");
const MAPS_ANDROID_KEY      = defineSecret("MAPS_ANDROID_KEY");
const MAPS_IOS_KEY          = defineSecret("MAPS_IOS_KEY");
const MAP_OVERALL_WORKING_KEY = defineSecret("MAP_OVERALL_WORKING_KEY");

// ─── ALLOWED WEB ORIGINS ─────────────────────────────────────
const WEB_ORIGINS = [
  "https://ihsanapp-e2d2d.web.app",
  "https://ihsanmasjid.com",
  "https://www.ihsanmasjid.com",
];

// ─── CORS HELPER (onRequest only) ────────────────────────────
function handleCors(req, res) {
  const origin = req.headers.origin || "";
  if (WEB_ORIGINS.includes(origin)) {
    res.set("Access-Control-Allow-Origin", origin);
  }
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Max-Age", "3600");
  if (req.method === "OPTIONS") { res.status(204).send(""); return true; }
  return false;
}

// ─── HTTP GET HELPER ──────────────────────────────────────────
function httpGet(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = "";
      res.on("data", (chunk) => { data += chunk; });
      res.on("end", () => resolve(data));
      res.on("error", reject);
    }).on("error", reject);
  });
}

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
        err.status === 503 || err.status === 429 || err.status === 500 ||
        err.message?.includes("overloaded") || err.message?.includes("503");
      if (isRetryable && i < retries - 1) {
        const wait = (i + 1) * 15000;
        console.log(`Overloaded, retrying in ${wait}ms...`);
        await new Promise((r) => setTimeout(r, wait));
      } else { throw err; }
    }
  }
}

// ─── FUNCTION: askGemini (onCall — Dart + website via SDK) ───
exports.askGemini = onCall(
    {
      secrets: [GEMINI_KEY],
      timeoutSeconds: 300,
      memory: "512MiB",
      region: "europe-west2",
      cors: WEB_ORIGINS,
    },
    async (request) => {
      try {
        const {prompt, image, mime = "image/jpeg"} = request.data;
        if (!prompt) throw new HttpsError("invalid-argument", "Prompt is required");
        const genAI = new GoogleGenerativeAI(GEMINI_KEY.value());
        const parts = [{text: prompt}];
        if (image) parts.push({inlineData: {mimeType: mime, data: image}});
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

// ─── FUNCTION: askGeminiWeb (onRequest — website fetch) ──────
// Same logic as askGemini but with explicit CORS headers so the
// website can call it without the Firebase SDK. Dart still uses
// askGemini (onCall) above — this endpoint is website-only.
exports.askGeminiWeb = onRequest(
    {
      secrets: [GEMINI_KEY],
      timeoutSeconds: 300,
      memory: "512MiB",
      region: "europe-west2",
    },
    async (req, res) => {
      if (handleCors(req, res)) return;
      try {
        const {prompt, image, mime = "image/jpeg"} = req.body || {};
        if (!prompt) { res.status(400).json({error: "prompt is required"}); return; }
        const genAI = new GoogleGenerativeAI(GEMINI_KEY.value());
        const parts = [{text: prompt}];
        if (image) parts.push({inlineData: {mimeType: mime, data: image}});
        const contents = [{role: "user", parts}];
        const response = await callGeminiWithRetry(genAI, contents);
        res.json({text: response.text()});
      } catch (err) {
        console.error("askGeminiWeb error:", err);
        res.status(500).json({error: err.message || "Unknown error"});
      }
    },
);

// ─── FUNCTION: getMapsKeys (onCall — Dart uses httpsCallable) ─
// The website now calls the getMapsKeysWeb onRequest endpoint instead,
// so Dart's httpsCallable envelope is preserved here untouched.
exports.getMapsKeys = onCall(
    {
      secrets: [MAPS_WEB_KEY, MAPS_ANDROID_KEY, MAPS_IOS_KEY, MAP_OVERALL_WORKING_KEY],
      timeoutSeconds: 10,
      memory: "128MiB",
      region: "europe-west2",
      cors: WEB_ORIGINS,
    },
    async (request) => {
      const {platform} = request.data;
      switch (platform) {
        case "web":     return {key: MAPS_WEB_KEY.value()};
        case "android": return {key: MAPS_ANDROID_KEY.value()};
        case "ios":     return {key: MAPS_IOS_KEY.value()};
        case "overall": return {key: MAP_OVERALL_WORKING_KEY.value()};
        default:
          throw new HttpsError("invalid-argument",
              "platform must be 'web', 'android', 'ios' or 'overall'");
      }
    },
);

// ─── FUNCTION: getMapsKeysWeb (onRequest — website fetch) ────
// Separate endpoint for the website so we control CORS headers
// explicitly. Dart is unaffected — it still calls getMapsKeys above.
exports.getMapsKeysWeb = onRequest(
    {
      secrets: [MAPS_WEB_KEY],
      timeoutSeconds: 10,
      memory: "128MiB",
      region: "europe-west2",
    },
    async (req, res) => {
      if (handleCors(req, res)) return;
      try {
        res.json({key: MAPS_WEB_KEY.value()});
      } catch (err) {
        console.error("getMapsKeysWeb error:", err);
        res.status(500).json({error: err.message});
      }
    },
);

// ─── FUNCTION: searchPlaces (onRequest — website fetch) ──────
// Proxies Google Places Text Search — browser can't call Places
// API directly due to CORS. Mirrors _searchPlaceByText in uploadMosque.dart.
// Input:  POST { query: string }
// Output: { results: [ { name, formatted_address, place_id,
//                        geometry: { location: { lat, lng } } } ] }
exports.searchPlaces = onRequest(
    {
      secrets: [MAPS_WEB_KEY],
      timeoutSeconds: 15,
      memory: "128MiB",
      region: "europe-west2",
    },
    async (req, res) => {
      if (handleCors(req, res)) return;
      try {
        const body = req.body || {};
        const query = body.query;
        if (!query || !query.trim()) {
          res.status(400).json({error: "query is required"}); return;
        }
        const key = MAPS_WEB_KEY.value();
        const url = "https://maps.googleapis.com/maps/api/place/textsearch/json" +
          "?query=" + encodeURIComponent(query) + "&key=" + key;
        const raw = await httpGet(url);
        const json = JSON.parse(raw);
        if (json.status !== "OK" && json.status !== "ZERO_RESULTS") {
          res.status(500).json({error: "Places API error: " + json.status}); return;
        }
        const results = (json.results || []).slice(0, 8).map((r) => ({
          name: r.name,
          formatted_address: r.formatted_address,
          place_id: r.place_id,
          geometry: {location: r.geometry?.location || {lat: 0, lng: 0}},
        }));
        res.json({results});
      } catch (err) {
        console.error("searchPlaces error:", err);
        res.status(500).json({error: err.message});
      }
    },
);

// ─── FUNCTION: reverseGeocode (onRequest — website fetch) ────
// Mirrors _updateCityFromCoordinates + adminAreaLevel2 in uploadMosque.dart.
// Priority: plus_code compound → postal_town → locality → admin_area_level_2.
// Input:  POST { lat: number, lng: number }
// Output: { city: string, area: string }
exports.reverseGeocode = onRequest(
    {
      secrets: [MAPS_WEB_KEY],
      timeoutSeconds: 15,
      memory: "128MiB",
      region: "europe-west2",
    },
    async (req, res) => {
      if (handleCors(req, res)) return;
      try {
        const {lat, lng} = req.body || {};
        if (lat == null || lng == null) {
          res.status(400).json({error: "lat and lng are required"}); return;
        }
        const key = MAPS_WEB_KEY.value();
        const url = "https://maps.googleapis.com/maps/api/geocode/json" +
          "?latlng=" + lat + "," + lng + "&key=" + key;
        const raw = await httpGet(url);
        const json = JSON.parse(raw);
        if (!json.results?.length) { res.json({city: "", area: ""}); return; }

        // 1. plus_code compound
        const compound = json.plus_code?.compound_code;
        if (compound) {
          const parts = compound.split(" ");
          if (parts.length >= 2) {
            const city = parts.slice(1).join(" ").replace(/, UK$/, "").trim();
            res.json({city, area: ""}); return;
          }
        }
        // 2. postal_town + admin_area_level_2
        let foundCity = null; let foundArea = null;
        for (const result of json.results) {
          for (const comp of result.address_components) {
            const types = comp.types || [];
            if (!foundArea && types.includes("administrative_area_level_2")) foundArea = comp.long_name;
            if (!foundCity && types.includes("postal_town")) foundCity = comp.long_name;
          }
          if (foundCity && foundArea) break;
        }
        // 3. locality fallback
        if (!foundCity) {
          for (const comp of json.results[0].address_components) {
            const types = comp.types || [];
            if (types.includes("locality") || types.includes("administrative_area_level_2")) {
              foundCity = comp.long_name; break;
            }
          }
        }
        res.json({city: foundCity || "", area: foundArea || ""});
      } catch (err) {
        console.error("reverseGeocode error:", err);
        res.status(500).json({error: err.message});
      }
    },
);