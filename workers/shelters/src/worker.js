import api from './index.js';
import {pushRoute,pollGovernment} from './push.ts';
import {routeSite} from './site_routing.js';
import privacy from '../public/privacy.html';
import support from '../public/support.html';
import {publicPage} from './public_pages.js';

export default {
  /** @param {unknown} event @param {import('./push.ts').PushEnv} env @param {import('./index.js').Context} ctx */
  scheduled(event,env,ctx){ctx.waitUntil(pollGovernment(env));},
  /** @param {Request} request @param {import('./index.js').Env & import('./push.ts').PushEnv} env @param {import('./index.js').Context} ctx */
  async fetch(request, env, ctx) {
    const push=await pushRoute(request,env);
    if(push){
      if(new URL(request.url).pathname==='/api/push/config'&&env.GOV_ALERT_API_KEY)ctx.waitUntil(pollGovernment(env));
      return push;
    }
    return publicPage(request, {'/privacy':privacy,'/support':support}) ?? routeSite(request, env.ASSETS, () => api.fetch(request, env, ctx));
  },
};
