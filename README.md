# Azure Quiz Frontend

[![CI](https://github.com/Melvin-Simplon/capstone-quiz-frontend/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Melvin-Simplon/capstone-quiz-frontend/actions/workflows/ci.yml)
[![CD](https://github.com/Melvin-Simplon/capstone-quiz-frontend/actions/workflows/cd.yml/badge.svg?branch=main)](https://github.com/Melvin-Simplon/capstone-quiz-frontend/actions/workflows/cd.yml)
[![Quality Gate](https://sonarcloud.io/api/project_badges/measure?project=Melvin-Simplon_capstone-quiz-frontend&metric=alert_status)](https://sonarcloud.io/dashboard?id=Melvin-Simplon_capstone-quiz-frontend)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=Melvin-Simplon_capstone-quiz-frontend&metric=coverage)](https://sonarcloud.io/dashboard?id=Melvin-Simplon_capstone-quiz-frontend)
[![Angular](https://img.shields.io/badge/Angular-22-DD0031?logo=angular&logoColor=white)](package.json)
[![Node](https://img.shields.io/badge/Node-25-339933?logo=nodedotjs&logoColor=white)](.nvmrc)
[![Vitest](https://img.shields.io/badge/tests-Vitest-6E9F18?logo=vitest&logoColor=white)](package.json)
[![Hosting](https://img.shields.io/badge/hosting-Static%20Web%20Apps-0078D4?logo=microsoftazure&logoColor=white)](#deployment)
[![Deploy](https://img.shields.io/badge/deploy-OIDC%2C%20no%20stored%20secret-2EA043)](#deployment)

Angular application for revising Microsoft certifications, by module or by mock exam, reachable
from a plain link with no account to create. It consumes the REST API of the backend.

| | |
| --- | --- |
| Application | <https://witty-beach-0ed541703.2.azurestaticapps.net> |
| Backend | [capstone-quiz-backend](https://github.com/Melvin-Simplon/capstone-quiz-backend) |
| Infrastructure | [capstone-quiz-infrastructure](https://github.com/Melvin-Simplon/capstone-quiz-infrastructure) |

---

## Documentation

The [**wiki**](https://github.com/Melvin-Simplon/capstone-quiz-frontend/wiki) carries the
reasoning this file does not.

| Page | What it answers |
| --- | --- |
| [Security pipeline](https://github.com/Melvin-Simplon/capstone-quiz-frontend/wiki/Security-pipeline) | the six scanning categories, the tool chosen for each, and why |
| [Pipeline reference](https://github.com/Melvin-Simplon/capstone-quiz-frontend/wiki/Pipeline-reference) | every workflow, its trigger, and the check it produces |
| [Deployment](https://github.com/Melvin-Simplon/capstone-quiz-frontend/wiki/Deployment) | OIDC, tag-based discovery, the Key Vault door, the checks after the upload |
| [Decisions](https://github.com/Melvin-Simplon/capstone-quiz-frontend/wiki/Decisions) | the choices that are not obvious from the code, and what they cost |
| [Troubleshooting](https://github.com/Melvin-Simplon/capstone-quiz-frontend/wiki/Troubleshooting) | failures this repository has had, most of them silent |

---

## Stack

- Angular 22, standalone components and signals, Angular Material, ngx-translate for French and
  English
- Vitest, the Angular CLI 22 native test runner, on jsdom
- ESLint and Prettier, with husky and lint-staged on pre-commit

## Running locally

Prerequisites: the Node version in [`.nvmrc`](.nvmrc), and the backend answering on
`http://localhost:8080`.

```bash
npm install
npm start
```

The application serves on `http://localhost:4200` and targets the local API, see
`src/environments/environment.development.ts`. The API key is empty there, which is what switches
the backend's check off in local development.

```bash
npm test
npm run test:coverage
npm run lint
npm run format:check
```

## Structure

| Path | Holds |
| --- | --- |
| `src/app/core` | models, `QuizApiService` for the REST calls, `QuizSessionStore` for signal based session state |
| `src/app/features` | the four pages: certifications, modules, quiz, results |
| `src/environments` | the two placeholders the deployment substitutes |

## Building

```bash
npm run build:prod
```

The static output lands in `dist/azure-quiz-frontend/browser`, which is the folder deployed to
Static Web Apps.

`src/environments/environment.ts` holds two placeholders rather than values:
`REPLACE_WITH_PROD_API_URL` and `__BACKEND_API_KEY__`. They are substituted on the CI runner, at
deployment time. Neither a URL nor a key is ever committed here.

## Deployment

Merging into `main` runs [`.github/workflows/ci-cd.yml`](.github/workflows/ci-cd.yml): lint, format
check and unit tests, dependency and secret scanning, CodeQL, then the deployment, which waits on
all three.

A static site has no runtime, so what a server would read from its environment has to be baked into
the build. The deployment therefore:

1. resolves the backend URL and the site by their `component` tags, never by a name written here
2. opens the Key Vault firewall for its own address, reads the API key, and closes it again
   whatever happens next
3. substitutes the two placeholders, on the runner
4. builds, then reads the Static Web Apps deployment token through the Azure CLI rather than
   storing it as a repository secret
5. calls `GET /api/certifications` through the key it just baked in, and fails unless the answer is
   JSON

Both secrets are masked in the logs.

**The API key is readable in the shipped bundle.** That is what static hosting means: the key
identifies this frontend to the backend, it authenticates nobody. It is documented as a deliberate
trade-off in
[ADR 0003](https://github.com/WhiteMuush/simplon-quiz-infrastructure-bilan/blob/main/docs/adr/0003-public-backend-with-api-key.md),
along with the arrangement that should replace it in
[ADR 0011](https://github.com/WhiteMuush/simplon-quiz-infrastructure-bilan/blob/main/docs/adr/0011-linked-backend-not-taken.md).

## Out of scope

Provisioning the Azure resources, which lives in the infrastructure repository.
