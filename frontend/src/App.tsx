import { useEffect, useState } from "react";

import { getHealth, type Health } from "./api";

export default function App() {
  const [health, setHealth] = useState<Health | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getHealth()
      .then(setHealth)
      .catch((e: Error) => setError(e.message));
  }, []);

  return (
    <main>
      <h1>Starter</h1>

      <section className="card">
        <h2>Starter check</h2>
        {error && <p className="bad">Cannot reach the API: {error}</p>}
        {!error && !health && <p className="muted">Checking…</p>}
        {health && (
          <p className="good">
            API up, database {health.database}, storage at{" "}
            <code>{health.storage_dir}</code>.
          </p>
        )}
      </section>

      <section className="card">
        <h2>Your turn</h2>
        <p className="muted">Replace this component.</p>
      </section>
    </main>
  );
}
