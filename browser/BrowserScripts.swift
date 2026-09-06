//
//  BrowserScripts.swift
//  Balance
//
//  Dedicated JavaScript user scripts injected into WKWebView
//

import Foundation

enum BrowserScripts {
    
    // MARK: - Document Start Scripts (Injected at .atDocumentStart)
    static let preload: String = #"""
    (function() {
        'use strict';

        // MARK: - Notifications API
        let currentNotificationPermission = 'default';

        function MockNotification(title, options) {
            if (currentNotificationPermission !== 'granted') return;
            let msg = { title: title };
            if (options) {
                msg.body = options.body;
                msg.icon = options.icon;
            }
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.notificationShow) {
                window.webkit.messageHandlers.notificationShow.postMessage(msg);
            }
        }

        Object.defineProperty(MockNotification, 'permission', {
            get: function() { return currentNotificationPermission; }
        });

        window.__balanceSetNotificationPermission = function(permission) {
            currentNotificationPermission = permission;
        };

        MockNotification.requestPermission = function(callback) {
            return new Promise((resolve) => {
                if (currentNotificationPermission !== 'default') {
                    if (callback) callback(currentNotificationPermission);
                    resolve(currentNotificationPermission);
                    return;
                }

                const callbackId = 'notif_' + Math.random().toString(36).substr(2, 9);
                window['__balanceNotificationCallback_' + callbackId] = function(result) {
                    currentNotificationPermission = result;
                    if (callback) callback(result);
                    resolve(result);
                    delete window['__balanceNotificationCallback_' + callbackId];
                };

                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.notificationRequestPermission) {
                    window.webkit.messageHandlers.notificationRequestPermission.postMessage({ id: callbackId });
                }
            });
        };

        window.Notification = MockNotification;

        // MARK: - Geolocation API
        let locationCallbacks = {};
        let watchCallbacks = {};
        let callbackIdCounter = 0;

        if (!navigator.geolocation) {
            navigator.geolocation = {};
        }

        navigator.geolocation.getCurrentPosition = function(success, error, options) {
            const state = prompt("BALANCE_INTERNAL_LOCATION_CHECK");
            if (state === 'Deny') {
                if (error) error({ code: 1, message: 'User denied Geolocation' });
                return;
            }

            const id = ++callbackIdCounter;
            locationCallbacks[id] = { success: success, error: error };
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.balanceLocation) {
                window.webkit.messageHandlers.balanceLocation.postMessage({ type: 'get', id: id });
            }
        };

        navigator.geolocation.watchPosition = function(success, error, options) {
            const state = prompt("BALANCE_INTERNAL_LOCATION_CHECK");
            if (state === 'Deny') {
                if (error) error({ code: 1, message: 'User denied Geolocation' });
                return 0;
            }
            const id = ++callbackIdCounter;
            watchCallbacks[id] = { success: success, error: error };
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.balanceLocation) {
                window.webkit.messageHandlers.balanceLocation.postMessage({ type: 'watch', id: id });
            }
            return id;
        };

        navigator.geolocation.clearWatch = function(id) {
            delete watchCallbacks[id];
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.balanceLocation) {
                window.webkit.messageHandlers.balanceLocation.postMessage({ type: 'clear', id: id });
            }
        };

        window.__balanceLocationCallback = function(id, errCode, lat, lng, acc) {
            const cb = locationCallbacks[id] || watchCallbacks[id];
            if (!cb) return;

            if (errCode === 0) {
                if (cb.success) {
                    cb.success({
                        coords: { latitude: lat, longitude: lng, accuracy: acc },
                        timestamp: Date.now()
                    });
                }
            } else {
                if (cb.error) cb.error({ code: errCode, message: 'Location error' });
            }

            if (locationCallbacks[id]) {
                delete locationCallbacks[id];
            }
        };

        // MARK: - Window Print API
        window.print = function() {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.printPage) {
                window.webkit.messageHandlers.printPage.postMessage({});
            }
        };

        // MARK: - Web Share API
        if (!navigator.canShare) {
            navigator.canShare = function(data) {
                if (!data || typeof data !== 'object') return false;
                if (!data.url && !data.text && !data.title) return false;
                return true;
            };
        }

        navigator.share = function(data) {
            return new Promise((resolve, reject) => {
                if (!data || typeof data !== 'object' || (!data.url && !data.text && !data.title)) {
                    reject(new TypeError("Invalid share data: at least one of url, text, or title must be provided"));
                    return;
                }
                const callbackId = 'share_' + Math.random().toString(36).substr(2, 9);
                window['__balanceShareCallback_' + callbackId] = function(success, errorMsg) {
                    delete window['__balanceShareCallback_' + callbackId];
                    if (success) {
                        resolve();
                    } else {
                        reject(new DOMException(errorMsg || 'Share canceled', 'AbortError'));
                    }
                };
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.webShare) {
                    window.webkit.messageHandlers.webShare.postMessage({
                        id: callbackId,
                        title: data.title || '',
                        text: data.text || '',
                        url: data.url || ''
                    });
                } else {
                    delete window['__balanceShareCallback_' + callbackId];
                    reject(new DOMException('Share not supported', 'AbortError'));
                }
            });
        };

        // MARK: - Permissions API
        const originalPermissionsQuery = (navigator.permissions && typeof navigator.permissions.query === 'function')
            ? navigator.permissions.query.bind(navigator.permissions)
            : null;

        class BalancePermissionStatus extends EventTarget {
            constructor(name, state) {
                super();
                this._name = name;
                this._state = state;
                this.onchange = null;
            }
            get name() { return this._name; }
            get state() { return this._state; }
            _update(newState) {
                if (this._state !== newState) {
                    this._state = newState;
                    const event = new Event('change');
                    this.dispatchEvent(event);
                    if (typeof this.onchange === 'function') {
                        this.onchange.call(this, event);
                    }
                }
            }
        }

        if (!navigator.permissions) {
            navigator.permissions = {};
        }

        navigator.permissions.query = function(descriptor) {
            return new Promise((resolve, reject) => {
                if (!descriptor || typeof descriptor !== 'object' || !descriptor.name) {
                    reject(new TypeError("The name property is required"));
                    return;
                }
                const name = descriptor.name;
                const handledNames = ['geolocation', 'notifications', 'camera', 'microphone'];
                if (!handledNames.includes(name)) {
                    if (originalPermissionsQuery) {
                        originalPermissionsQuery(descriptor).then(resolve).catch(reject);
                        return;
                    }
                    resolve(new BalancePermissionStatus(name, 'prompt'));
                    return;
                }

                const callbackId = 'perm_' + Math.random().toString(36).substr(2, 9);
                window['__balancePermCallback_' + callbackId] = function(state) {
                    delete window['__balancePermCallback_' + callbackId];
                    resolve(new BalancePermissionStatus(name, state));
                };
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.balancePermissionsQuery) {
                    window.webkit.messageHandlers.balancePermissionsQuery.postMessage({ id: callbackId, name: name });
                } else {
                    delete window['__balancePermCallback_' + callbackId];
                    resolve(new BalancePermissionStatus(name, 'prompt'));
                }
            });
        };
    })();
    """#

    // MARK: - Document End Scripts (Injected at .atDocumentEnd)
    static let documentEnd: String = #"""
    (function() {
        'use strict';

        // MARK: - Scroll Position Observer
        window.addEventListener('scroll', () => {
            clearTimeout(window.scrollTimeout);
            window.scrollTimeout = setTimeout(() => {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.scrollObserver) {
                    window.webkit.messageHandlers.scrollObserver.postMessage({ x: window.scrollX, y: window.scrollY });
                }
            }, 250);
        });

        // MARK: - Autofill Listener & Form Helpers
        window.__balanceLastFocusedInput = null;

        function findInputLabel(el) {
            if (!el) return "";

            // 1. Explicit <label for="id">
            if (el.id) {
                try {
                    const labelEl = document.querySelector('label[for="' + CSS.escape(el.id) + '"]');
                    if (labelEl && labelEl.innerText && labelEl.innerText.trim()) {
                        return labelEl.innerText.trim();
                    }
                } catch (e) {}
            }

            // 2. Surrounding <label>
            const parentLabel = el.closest('label');
            if (parentLabel) {
                const clone = parentLabel.cloneNode(true);
                const inputs = clone.querySelectorAll('input, select, textarea, button');
                inputs.forEach(i => i.remove());
                const text = clone.innerText && clone.innerText.trim();
                if (text) return text;
            }

            // 3. aria-labelledby
            const ariaLabelledby = el.getAttribute('aria-labelledby');
            if (ariaLabelledby) {
                const ids = ariaLabelledby.split(/\s+/);
                const texts = ids.map(id => {
                    const node = document.getElementById(id);
                    return node ? (node.innerText || "").trim() : "";
                }).filter(Boolean);
                if (texts.length > 0) return texts.join(' ');
            }

            // 4. aria-label
            const ariaLabel = el.getAttribute('aria-label');
            if (ariaLabel && ariaLabel.trim()) {
                return ariaLabel.trim();
            }

            // 5. placeholder
            const placeholder = el.getAttribute('placeholder');
            if (placeholder && placeholder.trim()) {
                return placeholder.trim();
            }

            // 6. name or autocomplete attribute
            const name = el.getAttribute('name');
            if (name && name.trim()) {
                return name.trim();
            }

            const autocomplete = el.getAttribute('autocomplete');
            if (autocomplete && autocomplete.trim() && autocomplete !== 'off' && autocomplete !== 'on') {
                return autocomplete.trim();
            }

            return "";
        }

        function getElementViewportRect(el) {
            let rect = el.getBoundingClientRect();
            let top = rect.top;
            let left = rect.left;
            let width = rect.width;
            let height = rect.height;

            let currentWindow = window;
            while (currentWindow && currentWindow !== currentWindow.top) {
                try {
                    if (currentWindow.frameElement) {
                        let frameRect = currentWindow.frameElement.getBoundingClientRect();
                        top += frameRect.top;
                        left += frameRect.left;
                        currentWindow = currentWindow.parent;
                    } else {
                        break;
                    }
                } catch (e) {
                    break;
                }
            }

            return {
                x: left,
                y: top,
                width: width,
                height: height
            };
        }

        function notifyAutofill(el) {
            if (!el || (el.tagName !== 'INPUT' && el.tagName !== 'TEXTAREA')) return;

            const ignoredTypes = ['submit', 'button', 'checkbox', 'radio', 'file', 'hidden', 'image', 'reset', 'color', 'range'];
            const inputType = (el.type || 'text').toLowerCase();
            if (el.tagName === 'INPUT' && ignoredTypes.includes(inputType)) return;

            const label = findInputLabel(el);
            const isSearch = inputType === 'search' ||
                             (el.getAttribute('role') || '').toLowerCase() === 'searchbox' ||
                             el.name === 'q' ||
                             label.toLowerCase().includes('search');
            if (isSearch) return;

            window.__balanceLastFocusedInput = el;

            // Check if part of a password / login form
            let form = el.closest('form');
            let hasPassword = false;
            if (form) {
                let inputs = form.querySelectorAll('input');
                for (let input of inputs) {
                    if (input.type === 'password') {
                        hasPassword = true;
                        break;
                    }
                }
            } else if (inputType === 'password') {
                hasPassword = true;
            }

            const rect = getElementViewportRect(el);

            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.autofillRequest) {
                window.webkit.messageHandlers.autofillRequest.postMessage({
                    x: rect.x,
                    y: rect.y,
                    width: rect.width,
                    height: rect.height,
                    type: inputType,
                    tagName: el.tagName.toLowerCase(),
                    label: label,
                    name: el.name || '',
                    id: el.id || '',
                    value: el.value || '',
                    autocomplete: el.getAttribute('autocomplete') || '',
                    hasPassword: hasPassword
                });
            }
        }

        document.addEventListener('focusin', function(e) {
            notifyAutofill(e.target);
        });

        document.addEventListener('click', function(e) {
            if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) {
                notifyAutofill(e.target);
            }
        });

        window.__balancePopulateActiveField = function(value) {
            let el = document.activeElement;
            if (!el || (el.tagName !== 'INPUT' && el.tagName !== 'TEXTAREA')) {
                el = window.__balanceLastFocusedInput;
            }
            if (!el) return false;

            const proto = el.tagName === 'TEXTAREA' ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype;
            const nativeInputValueSetter = Object.getOwnPropertyDescriptor(proto, "value")?.set;

            if (nativeInputValueSetter) {
                nativeInputValueSetter.call(el, value);
            } else {
                el.value = value;
            }

            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
            return true;
        };

        window.__balanceGetActiveFieldValue = function() {
            let el = document.activeElement;
            if (!el || (el.tagName !== 'INPUT' && el.tagName !== 'TEXTAREA')) {
                el = window.__balanceLastFocusedInput;
            }
            if (!el) return null;
            return {
                value: el.value || '',
                type: (el.type || 'text').toLowerCase(),
                label: findInputLabel(el)
            };
        };

        window.__balanceAutofill = function(username, password) {
            let passwordInputs = document.querySelectorAll('input[type="password"]');
            for (let passwordInput of passwordInputs) {
                let scope = passwordInput.closest('form') || document;
                let textInputs = scope.querySelectorAll('input:not([type="password"]):not([type="hidden"]):not([type="submit"]):not([type="button"]):not([type="checkbox"]):not([type="radio"])');
                let usernameInput = null;
                if (textInputs.length > 0) {
                    for (let input of textInputs) {
                        if (input.compareDocumentPosition(passwordInput) & Node.DOCUMENT_POSITION_FOLLOWING) {
                            usernameInput = input;
                        }
                    }
                    if (!usernameInput) usernameInput = textInputs[0];
                }

                const nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value")?.set;

                if (usernameInput && username && username !== "Unknown") {
                    if (nativeInputValueSetter) {
                        nativeInputValueSetter.call(usernameInput, username);
                    } else {
                        usernameInput.value = username;
                    }
                    usernameInput.dispatchEvent(new Event('input', { bubbles: true }));
                    usernameInput.dispatchEvent(new Event('change', { bubbles: true }));
                }
                if (password) {
                    if (nativeInputValueSetter) {
                        nativeInputValueSetter.call(passwordInput, password);
                    } else {
                        passwordInput.value = password;
                    }
                    passwordInput.dispatchEvent(new Event('input', { bubbles: true }));
                    passwordInput.dispatchEvent(new Event('change', { bubbles: true }));
                }
                return;
            }
        };

        window.__balanceGetFormValues = function() {
            let passwordInputs = document.querySelectorAll('input[type="password"]');
            for (let passwordInput of passwordInputs) {
                if (passwordInput.value) {
                    let scope = passwordInput.closest('form') || document;
                    let textInputs = scope.querySelectorAll('input:not([type="password"]):not([type="hidden"]):not([type="submit"]):not([type="button"]):not([type="checkbox"]):not([type="radio"])');
                    let usernameInput = null;
                    if (textInputs.length > 0) {
                        for (let input of textInputs) {
                            if (input.compareDocumentPosition(passwordInput) & Node.DOCUMENT_POSITION_FOLLOWING) {
                                usernameInput = input;
                            }
                        }
                        if (!usernameInput) usernameInput = textInputs[0];
                    }

                    let username = (usernameInput && usernameInput.value) ? usernameInput.value : "Unknown";
                    return { username: username, password: passwordInput.value };
                }
            }
            return null;
        };

        // MARK: - Chrome Web Store Integration
        window.balanceInstalledExtensions = window.balanceInstalledExtensions || [];
        if (window.location.hostname.includes("chromewebstore.google.com")) {
            let checkInterval = setInterval(() => {
                let buttons = Array.from(document.querySelectorAll('button'));
                let installBtn = buttons.find(b => {
                    let text = b.innerText.toLowerCase();
                    let aria = (b.getAttribute('aria-label') || "").toLowerCase();
                    if (text.includes("switch to chrome") || aria.includes("switch to chrome")) return false;

                    return text.includes("available on chrome") ||
                           text.includes("add to chrome") ||
                           text.includes("install");
                });

                if (installBtn && !installBtn.hasAttribute('data-balance-injected')) {
                    let pathParts = window.location.pathname.split('/');
                    let extId = pathParts[pathParts.length - 1];

                    if (extId && extId.length === 32) {
                        let newBtn = installBtn.cloneNode(true);
                        newBtn.setAttribute('data-balance-injected', 'true');
                        newBtn.disabled = false;

                        let isInstalled = window.balanceInstalledExtensions.includes(extId);

                        let spans = newBtn.querySelectorAll('span');
                        let textSpan = Array.from(spans).find(s => s.innerText.includes("Chrome") || s.innerText.includes("Install"));

                        let btnText = isInstalled ? "Installed" : "Install in Balance";

                        if (textSpan) {
                            textSpan.innerText = btnText;
                        } else {
                            newBtn.innerText = btnText;
                        }

                        // Use inline interval to check if it gets installed dynamically
                        let checkDynamic = setInterval(() => {
                            if (window.balanceInstalledExtensions.includes(extId)) {
                                if (textSpan) textSpan.innerText = "Installed";
                                else newBtn.innerText = "Installed";
                                newBtn.style.backgroundColor = "#34C759";
                                newBtn.style.cursor = "default";
                                newBtn.disabled = true;
                                clearInterval(checkDynamic);
                            }
                        }, 500);

                        newBtn.style.backgroundColor = isInstalled ? "#34C759" : "#007AFF";
                        newBtn.style.color = "white";
                        newBtn.style.opacity = "1";
                        newBtn.style.cursor = isInstalled ? "default" : "pointer";
                        newBtn.style.pointerEvents = "auto";

                        installBtn.parentNode.replaceChild(newBtn, installBtn);

                        if (!isInstalled) {
                            newBtn.addEventListener('click', (e) => {
                                e.preventDefault();
                                e.stopPropagation();
                                if (textSpan) textSpan.innerText = "Installing...";
                                else newBtn.innerText = "Installing...";
                                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.installExtension) {
                                    window.webkit.messageHandlers.installExtension.postMessage(extId);
                                }

                                setTimeout(() => {
                                    if (textSpan) textSpan.innerText = "Installed";
                                    else newBtn.innerText = "Installed";
                                    newBtn.style.backgroundColor = "#34C759";
                                    if (!window.balanceInstalledExtensions.includes(extId)) {
                                        window.balanceInstalledExtensions.push(extId);
                                    }
                                }, 2000);
                            });
                        }
                    }
                }

                // Hide "Switch to Chrome" banners more aggressively
                let promos = document.querySelectorAll('*');
                for (let el of promos) {
                    if (el.children.length > 4) continue;
                    let text = (el.innerText || "").toLowerCase().trim();
                    if (text.includes("switch to chrome") || text.includes("download chrome") || text.includes("you need chrome")) {
                        let banner = el.closest('div[role="banner"]') || el.parentElement.parentElement;
                        if (banner && banner.style.display !== 'none' && banner.tagName !== 'BODY') {
                            banner.style.display = 'none';
                        }
                    }
                }
            }, 1000);
        }
    })();
    """#
}
