import { migrate, pool } from "./db.js";

const applied = await migrate();
console.log(applied.length ? `Angewandt: ${applied.join(", ")}` : "Keine offenen Migrationen.");
await pool.end();
