import express from "express"
import multer from "multer"
import { extractMedications } from "./Controller/gemini.js"
import { matchMedications } from "./Controller/matcher.js"

const med = express.Router()

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 15 * 1024 * 1024 }, // 15MB max
  fileFilter: (req, file, cb) => {
    // Log what the phone is actually sending
    console.log("📎 File mimetype:", file.mimetype, "| fieldname:", file.fieldname)
    // Accept everything — let Gemini handle it
    cb(null, true)
  },
})

med.get("/health", (req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() })
})

med.post("/scan", upload.single("prescription"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: "No image uploaded. Send image as form-data with key 'prescription'",
      })
    }

    console.log(`📸 Image received: ${req.file.originalname} (${req.file.size} bytes) — type: ${req.file.mimetype}`)

    // Step 1 — Gemini OCR
    console.log("🧠 Sending to Gemini...")

    // Force jpeg mimetype if Gemini doesn't recognize the format
    const mimeType = req.file.mimetype.startsWith("image/")
      ? req.file.mimetype
      : "image/jpeg"

    const rawMedications = await extractMedications(req.file.buffer, mimeType)
    console.log("✅ Gemini extracted:", rawMedications)

    if (rawMedications.length === 0) {
      return res.json({
        success: true,
        message: "No medications found in image",
        results: [],
      })
    }

    // Step 2 — Fuzzy match
    console.log("🔍 Matching against database...")
    const results = await matchMedications(rawMedications)
    const matchedCount = results.filter((r) => r.matched).length
    console.log(`✅ Matched ${matchedCount}/${rawMedications.length}`)

    return res.json({
      success: true,
      totalExtracted: rawMedications.length,
      totalMatched: matchedCount,
      results,
    })

  } catch (error) {
    console.error("❌ Scan error:", error.message)
    return res.status(500).json({ success: false, error: error.message })
  }
})

export default med