/** Recompute product size groups now (normally done after each stock-file import). */
import 'dotenv/config';
import { regroupVariants } from '../modules/catalog/variants';

regroupVariants().then(
  (result) => {
    console.log(result);
    process.exit(0);
  },
  (error: unknown) => {
    console.error(error);
    process.exit(1);
  },
);
