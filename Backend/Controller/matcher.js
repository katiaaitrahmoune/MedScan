import Fuse from "fuse.js"
import MED from "../appModele.js"

const NOISE_WORDS = [
  "cp", "cpr", "cps", "cmp",           // comprimé (tablet)
  "crem", "crm", "cr", "cream",         // cream
  "gel", "gél",                          // gel
  "sol", "soln", "solution",            // solution
  "susp", "suspension",                 // suspension
  "inj", "injection",                   // injection
  "sir", "sirop", "syrup",              // syrup
  "amp", "ampoule",                     // ampoule
  "sup", "supp", "suppositoire",        // suppository
  "pdr", "poudre", "powder",            // powder
  "sach", "sachet",                     // sachet
  "inh", "inhaler",                     // inhaler
  "oph", "opht",                        // ophthalmic
  "ear", "eye", "nasal",               // routes
  "tab", "tablet", "comprimé",         // tablet
  "cap", "caps", "capsule",            // capsule
  "x", "fois", "times",                // frequency indicators
]

function cleanForMatching(raw) {
  let cleaned = raw.toLowerCase()

  
  cleaned = cleaned.replace(/\d+\s*(mg|g|ml|mcg|iu|ui|%|p\b|u\b|cp\b)/gi, "")

  
  cleaned = cleaned.replace(/\b\d+\b/g, "")

  
  const noiseRegex = new RegExp(`\\b(${NOISE_WORDS.join("|")})\\b`, "gi")
  cleaned = cleaned.replace(noiseRegex, "")

 
  cleaned = cleaned.replace(/\s+/g, " ").trim()

  return cleaned
}

export async function matchMedications(rawMedications) {
  const allMedications = await MED.find({})

  const searchList = allMedications.map((med) => ({
    _id: med._id,
    name: med.name,
    common_abbreviation: med.common_abbreviation,
    brands: med.brands,
    aliases: med.aliases,
    category: med.category,
    sub_category: med.sub_category,
    dosage_forms: med.dosage_forms,
    common_doses: med.common_doses,
    notes: med.notes,
  }))

  const fuse = new Fuse(searchList, {
    keys: [
      { name: "name", weight: 0.5 },
      { name: "brands", weight: 0.35 },
      { name: "aliases", weight: 0.1 },
      { name: "common_abbreviation", weight: 0.05 },
    ],
    threshold: 0.5,         // looser to handle OCR misspellings like Mycozide/Mycozyde
    distance: 100,
    includeScore: true,
    minMatchCharLength: 3,
  })

  const results = []

  for (const rawString of rawMedications) {
    const cleanedName = cleanForMatching(rawString)

    // Extract dosage if present
    const dosageMatch = rawString.match(/\d+\s*(mg|g|ml|mcg|iu|ui|%)/i)
    const detectedDosage = dosageMatch ? dosageMatch[0].trim() : null

    console.log(`  🔍 "${rawString}" → cleaned: "${cleanedName}"`)

    const matches = fuse.search(cleanedName)

    if (matches.length > 0) {
      const best = matches[0]
      const confidence = Math.round((1 - best.score) * 100)

      results.push({
        raw: rawString,
        matched: true,
        confidence: `${confidence}%`,
        medication: {
          name: best.item.name,
          abbreviation: best.item.common_abbreviation || null,
          brands: best.item.brands || [],
          category: best.item.category || null,
          sub_category: best.item.sub_category || null,
          dosage_forms: best.item.dosage_forms || [],
          common_doses: best.item.common_doses || [],
          detectedDosage,
          notes: best.item.notes || null,
        },
      })
    } else {
      results.push({
        raw: rawString,
        matched: false,
        confidence: "0%",
        medication: null,
      })
    }
  }

  return results
}