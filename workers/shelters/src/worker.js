import api from './index.js';
import {routeSite} from './site_routing.js';
import privacy from '../public/privacy.html';
import support from '../public/support.html';
import {publicPage} from './public_pages.js';

export default {
  /** @param {Request} request @param {import('./index.js').Env} env @param {import('./index.js').Context} ctx */
  fetch(request, env, ctx) {
    return publicPage(request, {'/privacy':privacy,'/support':support}) ?? routeSite(request, env.ASSETS, () => api.fetch(request, env, ctx));
  },
};
