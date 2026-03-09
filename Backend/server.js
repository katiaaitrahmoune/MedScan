import mongoose from "mongoose"
import app from "./app.js"
import dotenv from "dotenv"

dotenv.config({path:"./.env"})
const Port  = process.env.Port || 5000

async function db(){
try{
await mongoose.connect(process.env.MONGO_URI)

console.log("DataBase are connected succesfully")
}catch(error){
console.error("failed to connect",error.message)
process.exit(1)
}
}

db()
app.listen(Port, ()=>{
console.log(`server is running on port ${Port} .....`)
})