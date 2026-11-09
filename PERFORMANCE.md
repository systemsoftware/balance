# Performance Overview

Balance Browser is engineered for high performance, efficiency, and seamless integration with macOS. By relying on native Apple frameworks and cutting-edge local processing, it delivers a fast and fluid browsing experience while maintaining a low footprint.

Here is a breakdown of the performance characteristics of Balance Browser.

## 1. Web Engine: WebKit

Unlike Chromium-based browsers (like Chrome, Edge, or Arc) or Electron-based applications, Balance Browser uses Apple's native **WebKit (`WKWebView`)** engine.

*   **Memory Efficiency:** WebKit is deeply integrated into macOS and optimized for its memory management systems. It uses significantly less RAM than Chromium's multi-process architecture.
*   **Battery Life:** WebKit is designed to be extremely power-efficient, maximizing battery life on MacBooks compared to its non-native counterparts.
*   **Rendering Speed:** Web pages benefit from native hardware acceleration and seamless scrolling built directly into the operating system.

## 2. User Interface: SwiftUI

*   **Native Execution:** The entire interface is built using **SwiftUI**. It is compiled down to highly optimized machine code rather than running through a JavaScript bridge or web wrapper.
*   **Hardware Acceleration:** UI rendering, including the custom Liquid Glass aesthetics and micro-animations, utilizes Apple's Metal framework under the hood, ensuring consistently high frame rates (60fps/120fps on ProMotion displays) without burdening the CPU.

## 3. Data Storage: SwiftData

*   **Local Persistence:** Browsing history, bookmarks, notes, and other user data are managed via **SwiftData**.
*   **Asynchronous Operations:** Backed by Core Data, SwiftData allows for fast, asynchronous read and write operations. The database is stored locally, ensuring that interacting with the Productive Sidebar or searching your history feels instantaneous.

## 4. AI Processing

Balance Browser uses on-device **Apple Foundation Models** by default for features like AI Chat and AI Page Summarization. Local performance scales directly with your hardware. Chat also offers an optional Private Cloud Compute model:

*   **Apple Silicon (M1/M2/M3/M4):** These processors feature dedicated Neural Engines (NPUs) and a unified memory architecture. Local AI tasks run exceptionally fast, with low latency and minimal impact on overall system performance or battery life.
*   **Local Privacy & Speed:** With the default on-device model, AI processing does not require a network round trip or a cloud server. Response time still depends on the device and request.
*   **Private Cloud Compute Option:** When enabled for a new chat session, prompts and attached page or image content are processed through Apple's Private Cloud Compute, so response time also depends on the network and service availability.

## Summary

Balance Browser provides the performance and efficiency of Safari—thanks to WebKit and native frameworks—while adding a powerful suite of productivity and AI tools on top. It is built to run effortlessly in the background or side-by-side with your most demanding professional apps.
