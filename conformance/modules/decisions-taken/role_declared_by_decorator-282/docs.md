# Decision 282 — No role is declared by an export's name.

The example is one blog route. `BlogPost` is the page, and everything rakun needs to know about it sits in its decorator: `#[page("blog/[slug]", paths: allPosts, head: postHead, partial: true)]` names the route, hands over `allPosts` as the paths to prerender and `postHead` as the page's head, and says the page renders as a partial. `allPosts` and `postHead` are ordinary functions, passed by value and typed by the decorator's parameters; their names mean nothing to the framework, and a rename changes nothing. The OG card works the same way: `BlogCard` carries `#[ogImage("blog/[slug]", size: ImageSize(width: 1200, height: 630), contentType: "image/png")]`, so the size and the content type are arguments, not two exports called `size` and `contentType`. A content collection would be its own `#[collection(…)]` decorator.

The program prints the prerendered slugs, `hello roles`, then the head for `/blog/roles`, `<title>Roles</title>`, then the rendered page, `<div><h1>Roles</h1><p>Said in a decorator.</p></div>`.

The refused form is a role read off a name. With this decorator in place, a module that also writes `pub fn generateStaticParams()`, `staticPaths`, `generateMetadata`, `partial`, `size`, `contentType` or `collections` is an error at that export, naming the decorator argument to write instead; rakun never looks a function up by its name. Route file names (`app/blog/[slug]/page.bpp`) remain the routing convention.

Cells in this repository that prove it: none yet. `rakun-bpp`'s `#[page]` takes only the segment today (`modules/rakun-bpp/src/routes.bp`), `rakun-app`'s `static_gen.bp` still reads a `generateStaticParams` row and `#[ogImage]` is not declared; the arguments `paths:`, `head:` and `partial:` and the error for a leftover named export come with front 150 (the rakun-app/rakun-ssr steps of 117, 121 and 53 that 165 folded into it), and until then the example does not build.

[draft/main.bp](draft/main.bp)
