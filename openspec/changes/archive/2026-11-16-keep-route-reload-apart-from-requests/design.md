# Design

## Context

See `proposal.md`, "Why".

## Goals / Non-Goals

**Goals:**

- A request that the app serves does not run during a draw of the routes.
- A reload of the routes never stops the server for longer than a fixed time.

**Non-Goals:**

- A job or a thread outside a request that uses a route helper. The middleware does not see it.
- The other processes of a server with more than one process. Each process has its own route set,
  and this change does not reload it.

## Decisions

**D1. A share of a lock for each request, the lock for a reload.** The middleware goes directly after
`CamaleonCms::MultipartEncodingGuard`, which the engine puts after `ActionDispatch::Executor`. A new request waits while a reload runs or
waits, so a stream of requests does not keep a reload waiting.

**D2. The share ends when the app returns, not when the body closes (intended).** A slow client of
a large response holds no share. A streamed response that uses a route helper in its body can still
see the draw.

**D3. A request that reloads gives up its share while it waits.** Two requests that each reload the
routes then do not wait for each other. The reloads run one after the other.

**D4. The reload waits for 10 seconds at most (`WAIT_TIMEOUT`).** A reload can run in a transaction.
For example, `site_after_install` installs plugins and a theme in the create of a site. A plugin can
also call `PluginRoutes.reload` in its own transaction.

A request that waits for a row that the transaction
locks then waits for the reload, and the reload waits for the request. After the time, the reload
draws the routes as Camaleon did before this lock, and it logs a warning.

- *Alternative: `ActiveSupport::Concurrency::ShareLock`.* Rejected: it has no time limit, so the
  case above stops each request of the server.
- *Alternative: reload after the commit (`after_commit`).* Rejected: it covers the post type and the
  site, but not `site_after_install` or the plugins.
