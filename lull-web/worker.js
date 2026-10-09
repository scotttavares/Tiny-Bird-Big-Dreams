export default {
  async fetch(request, env) {
    let res = await env.ASSETS.fetch(request);

    // SPA-style fallback: unknown HTML navigations -> landing page
    if (res.status === 404 && (request.headers.get('accept') || '').includes('text/html')) {
      res = await env.ASSETS.fetch(new Request(new URL('/', request.url), request));
    }

    const h = new Headers(res.headers);
    h.set('x-content-type-options', 'nosniff');
    h.set('referrer-policy', 'no-referrer');
    h.set('x-frame-options', 'SAMEORIGIN');
    h.set('permissions-policy', 'interest-cohort=()');
    return new Response(res.body, { status: res.status, statusText: res.statusText, headers: h });
  },
};
