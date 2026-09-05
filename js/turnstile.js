(function (global) {
  const SCRIPT_URL = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
  let siteKey = null;
  let scriptPromise = null;
  const widgets = new Map();
  const renderQueues = new Map();

  function loadScript() {
    if (global.turnstile) return Promise.resolve();
    if (scriptPromise) return scriptPromise;
    scriptPromise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = SCRIPT_URL;
      script.async = true;
      script.onload = () => resolve();
      script.onerror = () => reject(new Error('Falha ao carregar o captcha.'));
      document.head.appendChild(script);
    });
    return scriptPromise;
  }

  function purgeStaleWidgets() {
    widgets.forEach((_, el) => {
      if (!el?.isConnected) removeWidget(el);
    });
  }

  async function fetchSiteKey() {
    if (siteKey) return siteKey;
    const meta = document.querySelector('meta[name="turnstile-site-key"]');
    if (meta?.content?.trim()) {
      siteKey = meta.content.trim();
      return siteKey;
    }
    const fromWidget = document.querySelector('.cf-turnstile[data-sitekey]')?.dataset?.sitekey;
    if (fromWidget?.trim()) {
      siteKey = fromWidget.trim();
      return siteKey;
    }
    const response = await fetch('/api/turnstile/site-key', { credentials: 'same-origin' });
    const text = await response.text();
    let data = {};
    if (text.trim()) {
      try {
        data = JSON.parse(text);
      } catch {
        throw new Error('Resposta inválida do captcha.');
      }
    }
    if (!response.ok || !data.siteKey) {
      throw new Error(data.message || 'Captcha indisponível.');
    }
    siteKey = data.siteKey;
    return siteKey;
  }

  function resolveContainer(container) {
    if (!container) return null;
    return typeof container === 'string' ? document.querySelector(container) : container;
  }

  function isVisible(el) {
    if (!el || !el.isConnected) return false;
    const style = global.getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') {
      return false;
    }
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }

  function waitUntilVisible(el, attempts = 30) {
    return new Promise((resolve) => {
      let left = attempts;
      function tick() {
        if (isVisible(el) || left <= 0) {
          resolve();
          return;
        }
        left -= 1;
        requestAnimationFrame(tick);
      }
      tick();
    });
  }

  function isHealthy(el) {
    if (!el?.isConnected) return false;
    if (getResponse(el)) return true;

    const widgetId = widgets.get(el);
    if (widgetId != null && global.turnstile?.isExpired) {
      try {
        if (global.turnstile.isExpired(widgetId)) return false;
      } catch (_) {}
    }

    const iframe = el.querySelector('.cf-turnstile iframe, iframe');
    if (!iframe) return false;
    const rect = iframe.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }

  function removeWidget(el) {
    const widgetId = widgets.get(el);
    if (widgetId != null && global.turnstile) {
      try {
        global.turnstile.remove(widgetId);
      } catch (_) {
      }
    }
    widgets.delete(el);
    const target = el.querySelector(':scope > .cf-turnstile');
    if (target) target.replaceChildren();
  }

  function showError(container, message) {
    const el = resolveContainer(container);
    if (!el) return;
    let note = el.querySelector('.turnstile-error');
    if (!note) {
      note = document.createElement('div');
      note.className = 'turnstile-error';
      el.appendChild(note);
    }
    note.textContent = message;
  }

  async function render(container, options = {}) {
    const el = resolveContainer(container);
    if (!el) throw new Error('Container do captcha não encontrado.');

    const prev = renderQueues.get(el);
    if (prev) {
      try {
        await prev;
      } catch (_) {
      }
    }

    const task = (async () => {
      purgeStaleWidgets();
      await waitUntilVisible(el);
      await loadScript();
      const key = options.sitekey || await fetchSiteKey();
      if (!key) throw new Error('Site Key do captcha não configurada.');

      let target = el.querySelector(':scope > .cf-turnstile');
      if (!target) {
        target = document.createElement('div');
        target.className = 'cf-turnstile';
        el.appendChild(target);
      }

      removeWidget(el);

      await new Promise((resolve) => requestAnimationFrame(resolve));

      const widgetId = global.turnstile.render(target, {
        sitekey: key,
        theme: options.theme || 'dark',
        appearance: options.appearance || 'always',
        size: options.size || 'normal',
        callback: options.callback,
        'expired-callback': () => {
          options.onExpired?.();
          reset(el);
        },
        'error-callback': (code) => {
          options.onError?.(code);
          showError(el, code === '110200'
            ? 'Domínio não autorizado no Cloudflare. Adicione localhost ou seu domínio.'
            : 'Erro ao carregar captcha. Recarregue a página.');
        },
      });
      widgets.set(el, widgetId);
      return widgetId;
    })();

    renderQueues.set(el, task);
    try {
      return await task;
    } finally {
      if (renderQueues.get(el) === task) renderQueues.delete(el);
    }
  }

  function getResponse(container) {
    const el = resolveContainer(container);
    if (!el) return '';

    const widgetId = widgets.get(el);
    if (widgetId != null && global.turnstile?.getResponse) {
      try {
        const token = global.turnstile.getResponse(widgetId);
        if (token) return String(token).trim();
      } catch (_) {}
    }

    const input = el.querySelector('input[name="cf-turnstile-response"]');
    return input?.value?.trim() || '';
  }

  function reset(container) {
    const el = resolveContainer(container);
    const widgetId = widgets.get(el);
    if (widgetId != null && global.turnstile) {
      global.turnstile.reset(widgetId);
    }
  }

  function destroy(container) {
    const el = resolveContainer(container);
    if (!el) return;
    removeWidget(el);
    renderQueues.delete(el);
  }

  async function requireToken(container) {
    const el = resolveContainer(container);
    if (!el) throw new Error('Complete o captcha antes de continuar.');

    let token = getResponse(el);
    if (token) return token;

    for (let i = 0; i < 60; i += 1) {
      await new Promise((resolve) => global.setTimeout(resolve, 100));
      token = getResponse(el);
      if (token) return token;
    }

    throw new Error('Complete o captcha antes de continuar.');
  }

  global.TurnstileHelper = {
    render,
    getResponse,
    reset,
    destroy,
    requireToken,
    loadScript,
    fetchSiteKey,
    showError,
    isHealthy,
  };
})(window);
