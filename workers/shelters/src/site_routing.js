/** Keep API routes distinct from static web content, including unknown API paths.
 * @param {Request} request
 * @param {{fetch:(request:Request)=>Promise<Response>}|undefined} assets
 * @param {()=>Promise<Response>} api */
export async function routeSite(request, assets, api) {
  const path = new URL(request.url).pathname;
  if (!assets || path === '/health' || path === '/api' || path.startsWith('/api/')) return api();
  if (!['GET', 'HEAD'].includes(request.method)) {
    return new Response('Method not allowed', {status:405,headers:{Allow:'GET, HEAD'}});
  }
  return assets.fetch(request);
}
