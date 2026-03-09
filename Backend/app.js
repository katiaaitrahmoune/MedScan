
import express from "express"
import med from "./approute.js"
const app = express()

app.use(express.json())
app.use('/api',med)
export default app