// In-memory stand-in for a Cloudflare KV namespace (get / put / delete / list).
// list() pages two keys at a time so tests exercise cursor handling.
export class FakeKV {
  constructor() { this.map = new Map(); this.meta = new Map(); this.puts = 0; this.gets = 0; }
  async get(key, opts) {
    this.gets++;
    const v = this.map.has(key) ? this.map.get(key) : null;
    if (v === null) return null;
    const type = typeof opts === "string" ? opts : opts?.type;
    return type === "json" ? JSON.parse(v) : v;
  }
  async put(key, value, opts) {
    this.puts++; this.map.set(key, String(value));
    if (opts?.metadata) this.meta.set(key, opts.metadata); else this.meta.delete(key);
  }
  async delete(key) { this.map.delete(key); }
  async list({ prefix = "", cursor } = {}) {
    const all = [...this.map.keys()].filter((k) => k.startsWith(prefix)).sort();
    const start = cursor ? Number(cursor) : 0;
    const page = all.slice(start, start + 2);
    const next = start + 2;
    return { keys: page.map((name) => (this.meta.has(name) ? { name, metadata: this.meta.get(name) } : { name })), list_complete: next >= all.length, cursor: next >= all.length ? undefined : String(next) };
  }
}
