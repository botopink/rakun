// jhonstart-dom-test — a minimal document for the browser half of front 30.
//
// Enough of the DOM for `render.mjs`'s fill and signal functions and its
// payload reader, and nothing more: a parser for the markup jhonstart's render
// writes (well-formed tags, double-quoted attributes, `<template>` content,
// raw `<script>` / `<style>` text, void elements), `querySelector(All)` over
// `tag`, `[attr]` and `[attr="value"]`, `getElementsByTagName`,
// `replaceChildren`, `cloneNode`, `remove`, `textContent`, and a serializer
// that writes attributes in their order. `history.replaceState`,
// `location.replace` and `dispatchEvent` are recorded, never performed.

const VOID = new Set(["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"]);
const RAW = new Set(["script", "style"]);

class Node {
  constructor(kind, tag) {
    this.kind = kind; // "element" | "text" | "fragment"
    this.tagName = tag || "";
    this.attrs = [];
    this.children = [];
    this.parent = null;
    this.data = "";
    if (tag === "template") this.content = new Node("fragment");
  }
  getAttribute(name) {
    const hit = this.attrs.find((a) => a[0] === name);
    return hit ? hit[1] : null;
  }
  hasAttribute(name) {
    return this.attrs.some((a) => a[0] === name);
  }
  setAttribute(name, value) {
    const hit = this.attrs.find((a) => a[0] === name);
    if (hit) hit[1] = String(value);
    else this.attrs.push([name, String(value)]);
  }
  append(child) {
    child.parent = this;
    this.children.push(child);
  }
  replaceChildren(...nodes) {
    this.children = [];
    for (const n of nodes) {
      if (n.kind === "fragment") for (const c of [...n.children]) this.append(c);
      else this.append(n);
    }
  }
  remove() {
    if (!this.parent) return;
    this.parent.children = this.parent.children.filter((c) => c !== this);
    this.parent = null;
  }
  cloneNode(deep) {
    const copy = new Node(this.kind, this.tagName);
    copy.data = this.data;
    copy.attrs = this.attrs.map((a) => [a[0], a[1]]);
    if (deep) {
      for (const c of this.children) copy.append(c.cloneNode(true));
      if (this.content) copy.content = this.content.cloneNode(true);
    }
    return copy;
  }
  get textContent() {
    if (this.kind === "text") return this.data;
    return this.children.map((c) => c.textContent).join("");
  }
  set innerHTML(html) {
    this.replaceChildren(...parse(html).children);
  }
  addEventListener() {}
  walk(visit) {
    for (const c of this.children) {
      if (c.kind === "element") {
        visit(c);
        c.walk(visit);
      }
    }
  }
  querySelectorAll(selector) {
    const test = matcher(selector);
    const out = [];
    this.walk((e) => {
      if (test(e)) out.push(e);
    });
    return out;
  }
  querySelector(selector) {
    return this.querySelectorAll(selector)[0] || null;
  }
  getElementsByTagName(tag) {
    return this.querySelectorAll(tag);
  }
}

function matcher(selector) {
  const m = /^([a-z0-9-]*)(?:\[([a-z0-9-]+)(?:="([^"]*)")?\])?$/.exec(selector);
  if (!m) throw new Error("fake_dom: unsupported selector " + selector);
  const [, tag, attr, value] = m;
  return (e) =>
    (tag === "" || e.tagName === tag) &&
    (attr === undefined || (e.hasAttribute(attr) && (value === undefined || e.getAttribute(attr) === value)));
}

function unescape(s) {
  return s.replace(/&quot;/g, '"').replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&");
}

function parse(html) {
  const root = new Node("fragment");
  let current = root;
  let i = 0;
  while (i < html.length) {
    if (html.startsWith("<!", i)) {
      i = html.indexOf(">", i) + 1;
      continue;
    }
    if (html.startsWith("</", i)) {
      const end = html.indexOf(">", i);
      const owner = current.owner || current;
      current = owner.parent || root;
      i = end + 1;
      continue;
    }
    if (html[i] === "<") {
      const end = html.indexOf(">", i);
      const inner = html.slice(i + 1, end);
      const tag = /^([a-zA-Z0-9-]+)/.exec(inner)[1].toLowerCase();
      const el = new Node("element", tag);
      const attrRe = /([a-zA-Z0-9_:-]+)(?:="([^"]*)")?/g;
      attrRe.lastIndex = tag.length;
      let a;
      while ((a = attrRe.exec(inner)) !== null) el.attrs.push([a[1], unescape(a[2] === undefined ? "" : a[2])]);
      current.append(el);
      i = end + 1;
      if (VOID.has(tag)) continue;
      if (RAW.has(tag)) {
        const close = html.indexOf("</" + tag + ">", i);
        const t = new Node("text");
        t.data = html.slice(i, close);
        el.append(t);
        i = close + tag.length + 3;
        continue;
      }
      if (tag === "template") {
        el.content.owner = el;
        current = el.content;
      } else {
        current = el;
      }
      continue;
    }
    const next = html.indexOf("<", i);
    const stop = next === -1 ? html.length : next;
    const t = new Node("text");
    t.data = unescape(html.slice(i, stop));
    current.append(t);
    i = stop;
  }
  return root;
}

function escapeText(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function serialize(node) {
  if (node.kind === "text") return node.parent && RAW.has(node.parent.tagName) ? node.data : escapeText(node.data);
  if (node.kind === "fragment") return node.children.map(serialize).join("");
  const attrs = node.attrs.map((a) => " " + a[0] + '="' + a[1].replace(/&/g, "&amp;").replace(/"/g, "&quot;") + '"').join("");
  const open = "<" + node.tagName + attrs + ">";
  if (VOID.has(node.tagName)) return open;
  const body = node.content ? serialize(node.content) : node.children.map(serialize).join("");
  return open + body + "</" + node.tagName + ">";
}

let events = [];

class PopStateEvent {
  constructor(type, init) {
    this.type = type;
    this.state = init ? init.state : null;
  }
}

export function install(html) {
  events = [];
  const doc = parse(html);
  globalThis.document = doc;
  globalThis.history = { replaceState: (_s, _t, url) => events.push("replaceState " + url) };
  globalThis.location = { replace: (url) => events.push("location.replace " + url) };
  globalThis.PopStateEvent = PopStateEvent;
  globalThis.Event = PopStateEvent;
  globalThis.dispatchEvent = (e) => events.push("event " + e.type);
  return 0;
}

export function markup() {
  return globalThis.document ? serialize(globalThis.document) : "";
}

export function recorded() {
  return events.join("\n");
}

export function call(name, arg) {
  const f = globalThis[name];
  if (typeof f !== "function") return "no function " + name;
  if (arg === "") f();
  else f(arg);
  return "called";
}

export function uninstall() {
  delete globalThis.document;
  delete globalThis.history;
  delete globalThis.location;
  delete globalThis.dispatchEvent;
  return 0;
}
