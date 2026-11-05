 (() => {
     "use strict";
     if (window.__balanceSmartDarkMode) return;

     const MIN = 20;   // never pure black
     const MAX = 235;  // never pure white
     const LIGHT_THRESHOLD = 0.179; // luminance where black/white text have equal contrast
     const MARK = "data-auto-dark";
     const SKIP_TAGS = new Set([
         "SCRIPT", "STYLE", "NOSCRIPT", "IMG", "PICTURE", "VIDEO",
         "CANVAS", "IFRAME", "SVG", "OBJECT", "EMBED"
     ]);

     const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
     let observer = null;
     let pending = new Set();
     let frame = 0;
     let enabled = false;
     const originalStyles = new WeakMap();

     function setStyle(el, property, value) {
         let originals = originalStyles.get(el);
         if (!originals) {
             originals = new Map();
             originalStyles.set(el, originals);
         }
         if (!originals.has(property)) {
             originals.set(property, [el.style.getPropertyValue(property), el.style.getPropertyPriority(property)]);
         }
         el.setAttribute(MARK, "");
         el.style.setProperty(property, value, "important");
     }

     function parseColor(color) {
         const m = color.match(
             /rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)(?:[,\s/]+([\d.]+%?))?\s*\)/
         );
         if (!m) return null;

         let a = 1;
         if (m[4] !== undefined) {
             a = m[4].endsWith("%") ? parseFloat(m[4]) / 100 : parseFloat(m[4]);
         }
         return { r: +m[1], g: +m[2], b: +m[3], a };
     }

     function luminance({ r, g, b }) {
         const [R, G, B] = [r, g, b].map(v => {
             const c = v / 255;
             return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
         });
         return R * 0.2126 + G * 0.7152 + B * 0.0722;
     }

     const isLight = (c) => luminance(c) > LIGHT_THRESHOLD;

     const invertChannel = (v) => Math.max(MIN, Math.min(MAX, 255 - v));

     function invert({ r, g, b, a }) {
         const [R, G, B] = [r, g, b].map(invertChannel);
         return a < 1 ? `rgba(${R}, ${G}, ${B}, ${a})` : `rgb(${R}, ${G}, ${B})`;
     }

     function collect(root) {
         const list = [];
         if (root.nodeType !== Node.ELEMENT_NODE) return list;
         list.push(root, ...root.querySelectorAll("*"));
         return list.filter(el => !SKIP_TAGS.has(el.tagName.toUpperCase()));
     }

     function processElements(elements) {

         const writes = [];

         for (const el of elements) {
             if (el.hasAttribute(MARK)) continue;

             const style = getComputedStyle(el);
             const bg = parseColor(style.backgroundColor);
             const fg = parseColor(style.color);
             const change = {};


             if (bg && bg.a > 0 && isLight(bg)) change.background = invert(bg);

             if (fg && !isLight(fg)) change.color = invert(fg);

             if (change.background || change.color) writes.push([el, change]);
         }

         for (const [el, { background, color }] of writes) {
             if (background) setStyle(el, "background-color", background);
             if (color) setStyle(el, "color", color);
         }
     }

     function ensureRootBackground() {
         const html = parseColor(getComputedStyle(document.documentElement).backgroundColor);
         const body = parseColor(getComputedStyle(document.body).backgroundColor);
         const transparent = c => !c || c.a === 0;

         if (transparent(html) && transparent(body)) {
             setStyle(document.documentElement, "background-color", `rgb(${MIN}, ${MIN}, ${MIN})`);
         }
     }

     function applyDarkMode() {
         console.log("Applying dark mode...");
         processElements(collect(document.documentElement));
         ensureRootBackground();
         startObserver();
     }

     function removeDarkMode() {
         stopObserver();
         document.querySelectorAll(`[${MARK}]`).forEach(el => {
             const originals = originalStyles.get(el);
             if (originals) {
                 for (const [property, [value, priority]] of originals) {
                     if (value) el.style.setProperty(property, value, priority);
                     else el.style.removeProperty(property);
                 }
                 originalStyles.delete(el);
             }
             el.removeAttribute(MARK);
             if (!el.getAttribute("style")) el.removeAttribute("style");
         });
         console.log("Dark mode removed.");
     }

     function startObserver() {
         if (observer) return;
         observer = new MutationObserver(mutations => {
             for (const m of mutations) m.addedNodes.forEach(n => pending.add(n));
             if (!frame) frame = requestAnimationFrame(flush);
         });
         observer.observe(document.documentElement, { childList: true, subtree: true });
     }

     function stopObserver() {
         observer?.disconnect();
         observer = null;
         pending.clear();
         cancelAnimationFrame(frame);
         frame = 0;
     }

     function flush() {
         frame = 0;
         const batch = [...pending];
         pending = new Set();
         processElements(batch.flatMap(collect));
     }

     function sync() {
         if (enabled && mediaQuery.matches) {
             const bg = parseColor(getComputedStyle(document.body).backgroundColor);
             if (!observer && bg && bg.a > 0 && !isLight(bg)) return;
             applyDarkMode();
         } else {
             removeDarkMode();
         }
     }

     function refresh() {
         if (!enabled || !mediaQuery.matches) return;
         // Stylesheets can finish loading after the first pass. Recompute from
         // the site's original styles instead of keeping the early colors.
         removeDarkMode();
         sync();
     }

     window.__balanceSmartDarkMode = {
         setEnabled(value) {
             enabled = Boolean(value);
             if (document.readyState !== "loading") sync();
         }
     };

     function init() {

         mediaQuery.addEventListener("change", sync);

         sync();
     }

     if (document.readyState === "loading") {
         document.addEventListener("DOMContentLoaded", init);
     } else {
         init();
     }
     if (document.readyState !== "complete") {
         window.addEventListener("load", refresh, { once: true });
     }
 })();
