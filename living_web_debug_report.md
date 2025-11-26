# Living Web Debugging Report

## Current Issues

1. **Infinite console logging / UI unresponsiveness** when the Living Web panel is active.
2. **Character selection clicks do not fire** (`phx-click` events are blocked) while the Living Web panel is open.
3. The browser console is flooded with logs (including server‑side logs streamed via LiveView), making it impossible to interact with the page.

## What Has Been Attempted

- **Disabled `console.log` statements** in `assets/js/hooks/xyflow_editor.js` by introducing a `DEBUG` flag.
- **Wrapped all remaining `console.log` calls** with `DEBUG &&` to silence them.
- **Added equality checks** for `nodes_updated`, `edges_updated`, and `potential_edges_updated` events to ignore redundant updates.
- **Implemented a circuit‑breaker** in the `nodes_updated` handler that stops processing if more than 50 updates occur within a second.
- **Added additional debug logs** for the circuit‑breaker.
- **Restarted the Phoenix server** multiple times to ensure the new JavaScript was compiled and served.

## Observations After Changes

- The server restarts complete without port conflicts.
- The circuit‑breaker logic is active (it will stop processing after 50 rapid updates), but the infinite loop still appears to be present according to the user.
- The client‑side equality checks should prevent re‑rendering when the server sends identical data, but the loop may be triggered by a different event (e.g., rapid `nodes_updated` with slightly different payloads or another event such as `node_moved`).
- No clear evidence that the server side is the source of the loop; the issue may still be a feedback loop between client and server.

## Open Questions / Next Steps

1. **What exact console output is observed?**
   - Are the logs coming from `console.warn`/`console.error` or from the LiveView server log streaming?
2. **Is the infinite loop triggered by a specific user action?**
   - Does simply opening the Living Web panel cause the loop, or does it require dragging/dropping nodes?
3. **Can we isolate the problematic event?**
   - Temporarily disable all `handleEvent` listeners (`nodes_updated`, `edges_updated`, `potential_edges_updated`, `node_moved`, `node_added`, etc.) one by one to see which one re‑triggers the server.
4. **Server‑side logging:**
   - Add explicit `Logger.debug` statements in `LivingWebPanelComponent` event handlers (`handle_event/3`) to see which events are being invoked repeatedly.
5. **Browser caching:**
   - Ensure the browser loads the latest JavaScript (hard‑refresh or clear cache) before testing again.
6. **Character selection:**
   - Verify that the left‑panel click events are not being stopped by the Xyflow editor’s global listeners. If needed, add `e.stopPropagation()` guards only for events originating from the right panel.

## Recommended Immediate Actions

- **Clear browser cache** (or open the app in an incognito window) and reload the page.
- **Temporarily comment out all `handleEvent` registrations** in `xyflow_editor.js` except for the essential ones (`nodes_updated` and `edges_updated`). Observe if the loop stops.
- **Add server‑side logging** to `LivingWebPanelComponent.handle_event/3` for all events that push updates to the client.
- **Provide a minimal reproduction**: a short video or steps that consistently trigger the loop, which will help pinpoint the exact event chain.

---

*This report was generated automatically after multiple attempts to resolve the infinite loop issue. Further investigation is required to pinpoint the exact cause.*
