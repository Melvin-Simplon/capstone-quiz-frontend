export const environment = {
  production: true,
  // Both values below are placeholders only — never commit real ones.
  // ci-cd.yml resolves the backend App Service and the Key Vault by tag at
  // deploy time (no hardcoded names) and substitutes both tokens in place
  // right before `npm run build`, on the ephemeral CI runner only.
  apiBaseUrl: 'https://REPLACE_WITH_PROD_API_URL/api',
  apiKey: '__BACKEND_API_KEY__',
};
