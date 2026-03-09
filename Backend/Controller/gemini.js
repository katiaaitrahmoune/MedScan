import { GoogleGenerativeAI } from "@google/generative-ai"
import dotenv from "dotenv"
dotenv.config({ path: "../.env" })

export async function extractMedications(imageBuffer, mimeType) {
  const genai = new GoogleGenerativeAI(process.env.GEMINI_API_KEY)
const model = genai.getGenerativeModel({
    model: "gemini-2.5-flash-lite"})

  const prompt = `
    You are an expert pharmacist reading a handwritten doctor prescription.
    
    Extract ALL medication names from this prescription image.
    
    Rules:
    - Extract the medication/brand name only — do NOT include the form (cp, cpr, crem, gel, inj, tab, amp...)
    - Include dosage if written (e.g. "Diflucan 150mg")
    - Read brand names very carefully — common ones include: Diflucan, Mycozyde, Lamisil, Augmentin, Flagyl, Doliprane, Ventolin, Zithromax, Amoxil, Clamoxyl, Voltaren, Imodium, etc.
    - If unsure between two similar brand names, pick the most medically common one
    - Return ONLY a raw JSON array of strings, no markdown, no explanation
    
    Example: ["Diflucan 150mg", "Mycozyde", "Lamisil"]
    If nothing found: []
  `

  const imagePart = {
    inlineData: {
      data: imageBuffer.toString("base64"),
      mimeType,
    },
  }

  const result = await model.generateContent([prompt, imagePart])
  const text = result.response.text().trim()

  const clean = text.replace(/```json|```/g, "").trim()
  const medications = JSON.parse(clean)

  if (!Array.isArray(medications)) throw new Error("Gemini did not return an array")

  return medications
}