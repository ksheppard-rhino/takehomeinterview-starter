export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
  }
}

export async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`/api${path}`, init);
  if (!response.ok) {
    const body = await response.text();
    throw new ApiError(body || response.statusText, response.status);
  }
  return (await response.json()) as T;
}

export interface Health {
  status: string;
  database: string;
  storage_dir: string;
}

export const getHealth = () => api<Health>("/health");
