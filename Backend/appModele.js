import mongoose from "mongoose"

const medicationSchema = mongoose.Schema({
  name: { type: String, required: true },          
  common_abbreviation: { type: String },             
  brands: { type: [String], default: [] },           
  aliases: { type: [String], default: [] },         
  category: { type: String },
  sub_category: { type: String },
  dosage_forms: { type: [String] },                 
  common_doses: { type: [String] },                  
  notes: { type: String },
})

// Index for fast text search across all name-related fields
medicationSchema.index({ name: "text", brands: "text", aliases: "text" })

const MED = mongoose.model("Med", medicationSchema)
export default MED