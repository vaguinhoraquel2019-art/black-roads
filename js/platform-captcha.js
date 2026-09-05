(function (global) {
  let container = null;
  let renderPromise = null;
  let solved = false;

  function setSolved(value) {
    if (solved === value) return;
    solved = value;
    global.dispatchEvent(new CustomEvent('captcha:change', { detail: { solved } }));
  }

  function ensureRendered() {
    if (!container) return Promise.reject(new Error('Captcha não inicializado.'));
    if (!renderPromise) {
      renderPromise = global.TurnstileHelper.render(container, {
        appearance: 'always',
        callback: () => setSolved(true),
        onExpired: () => setSolved(false),
        onError: () => setSolved(false),
      }).catch((err) => {
        renderPromise = null;
        setSolved(false);
        throw err;
      });
    }
    return renderPromise;
  }

  global.PlatformCaptcha = {
    init(containerId) {
      container = document.getElementById(containerId);
      if (!container) return;
      setSolved(false);
      ensureRendered().catch((err) => {
        console.error('[captcha] falha ao renderizar:', err.message);
      });
    },

    isSolved() {
      return solved || Boolean(container && global.TurnstileHelper.getResponse(container));
    },

    async requireActionToken() {
      if (!container) throw new Error('Captcha não disponível nesta página.');
      await ensureRendered();
      try {
        const token = await global.TurnstileHelper.requireToken(container);
        setSolved(true);
        return token;
      } catch (err) {
        setSolved(false);
        global.Notify?.error?.('Captcha', null, 'Complete o captcha antes de continuar.');
        throw err;
      }
    },

    reset() {
      setSolved(false);
      if (container) global.TurnstileHelper.reset(container);
    },
  };
})(window);
