import { HttpInterceptorFn } from '@angular/common/http';

import { environment } from '../../../environments/environment';

export const apiKeyInterceptor: HttpInterceptorFn = (req, next) => {
  if (!environment.apiKey || !req.url.startsWith(environment.apiBaseUrl)) {
    return next(req);
  }
  return next(req.clone({ setHeaders: { 'X-Api-Key': environment.apiKey } }));
};
