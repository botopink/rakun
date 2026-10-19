# Decision 201 — A static root's miss falls through, as Next and `express.static` do: a static root is tried first; when no root resolves

rakun-service's static root in front of the routes. The program writes `public/robots.txt`, sets the chain's terminal — the routes, answering `page <path>` — registers `public/` at `/**` and installs the static entry. `GET /robots.txt` is the file (200). `GET /blog` matches the root's pattern but no file: the miss falls through to the routes, and the answer is `page /blog`. `POST /robots.txt` is not served from a root: it goes to the chain. `GET /a/../robots.txt` is refused at the entry (404, a refused segment) and `GET /%zz` too (400, a bad decode): a refusal stays final.

Cells of this repository that prove it: none yet. rakun-service's `static.bp` answers 404 for a path a root matched but no root resolved (its own header says it does not fall through), which departs from this decision; front 04-rakun/65 and 07-onze/49 step 4 bring the fall-through.

[draft/main.bp](draft/main.bp)
