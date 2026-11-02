/** Static public information only: no scripts, forms, cookies or tracking.
 * @param {Request} request @param {Record<string,string>} pages */
export function publicPage(request, pages) {
  const path = new URL(request.url).pathname.replace(/\/$/, '');
  if (!Object.hasOwn(pages, path)) return null;
  if (!['GET', 'HEAD'].includes(request.method)) {
    return new Response('GET 또는 HEAD 요청만 지원합니다.', {status:405,headers:{Allow:'GET, HEAD'}});
  }
  return new Response(request.method === 'HEAD' ? null : pages[path], {headers:{
    'Content-Type':'text/html; charset=utf-8',
    'Cache-Control':'public, max-age=300',
    'Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
    'X-Content-Type-Options':'nosniff',
    'Referrer-Policy':'no-referrer',
    'Permissions-Policy':'geolocation=(), camera=(), microphone=()',
  }});
}
