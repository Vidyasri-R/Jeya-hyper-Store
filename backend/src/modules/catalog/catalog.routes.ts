import { Router } from 'express';
import { parseParams, parseQuery } from '../../common/validate';
import { productListQuerySchema, slugParamSchema, suggestQuerySchema } from './catalog.schemas';
import { catalogService } from './catalog.service';
import { homeListsService } from './home-lists';

/**
 * Public, unauthenticated catalogue. Short Cache-Control lets Cloudflare/CDN and
 * the app's HTTP cache absorb browsing traffic; stock freshness ≤ 60 s is fine
 * because checkout re-validates stock atomically.
 */
export const catalogRouter = Router();

catalogRouter.get('/categories', async (_req, res) => {
  res.set('Cache-Control', 'public, max-age=300');
  res.json({ categories: await catalogService.categoryTree() });
});

catalogRouter.get('/products', async (req, res) => {
  const query = parseQuery(productListQuerySchema, req);
  res.set('Cache-Control', 'public, max-age=60');
  res.json(await catalogService.listProducts(query));
});

catalogRouter.get('/products/:slug', async (req, res) => {
  const { slug } = parseParams(slugParamSchema, req);
  res.set('Cache-Control', 'public, max-age=60');
  res.json({ product: await catalogService.productDetail(slug) });
});

/** Customer home lists: admin-picked "Today's offers" / "Popular in your store", else automatic. */
catalogRouter.get('/home', async (_req, res) => {
  res.set('Cache-Control', 'public, max-age=60');
  res.json(await homeListsService.home());
});

catalogRouter.get('/search/suggest', async (req, res) => {
  const { q } = parseQuery(suggestQuerySchema, req);
  res.set('Cache-Control', 'public, max-age=120');
  res.json({ suggestions: await catalogService.suggest(q) });
});
