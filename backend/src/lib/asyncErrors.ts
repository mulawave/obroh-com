// Express 4 ignores the promise returned by async handlers, so a rejection
// never reaches the error middleware: the request hangs (or the process
// crashes) instead of getting a 500. Patch Layer so rejected promises are
// forwarded to next(err), matching Express 5 behaviour.
// Remove this module after upgrading to Express 5.

// eslint-disable-next-line @typescript-eslint/no-var-requires
const Layer = require("express/lib/router/layer");

type Next = (err?: unknown) => void;

const forwardRejection = (result: unknown, next: Next) => {
  if (result && typeof (result as Promise<unknown>).then === "function") {
    (result as Promise<unknown>).then(undefined, (err) => next(err ?? new Error("Rejected with no reason")));
  }
};

Layer.prototype.handle_request = function handle(req: unknown, res: unknown, next: Next) {
  const fn = this.handle;
  if (fn.length > 3) return next();
  try {
    forwardRejection(fn(req, res, next), next);
  } catch (err) {
    next(err);
  }
};

Layer.prototype.handle_error = function handleError(error: unknown, req: unknown, res: unknown, next: Next) {
  const fn = this.handle;
  if (fn.length !== 4) return next(error);
  try {
    forwardRejection(fn(error, req, res, next), next);
  } catch (err) {
    next(err);
  }
};
