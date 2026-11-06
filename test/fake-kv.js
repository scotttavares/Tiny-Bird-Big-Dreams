// In-memory stand-in for a Cloudflare KV namespace (get / put / delete / list).
// list() pages two keys at a time so tests exercise cursor handling.
export class FakeKV {
  constructor() { this.map = new Map(); this.puts = 0; }
  async get(key, opts) {
    const v = this.map.has(key) ? this.map.get(key) : null;
    if (v === null) return null;
    const type = typeof opts === "string" ? opts : opts?.type;
    return type === "json" ? JSON.parse(v) : v;
  }
  async put(key, value) { this.puts++; this.map.set(key, String(value)); }
  async delete(key) { this.map.delete(key); }
  async list({ prefix = "", cursor } = {}) {
    const all = [...this.map.keys()].filter((k) => k.startsWith(prefix)).sort();
    const start = cursor ? Number(cursor) : 0;
    const page = all.slice(start, start + 2);
    const next = start + 2;
    return { keys: page.map((name) => ({ name })), list_complete: next >= all.length, cursor: next >= all.length ? undefined : String(next) };
  }
}
