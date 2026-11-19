(async () => {
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const log = [];

  function firePointer(el, type) {
    const r = el.getBoundingClientRect();
    el.dispatchEvent(new PointerEvent(type, {
      bubbles: true, cancelable: true, composed: true,
      pointerId: 1, pointerType: 'mouse', isPrimary: true, button: 0,
      buttons: type === 'pointerdown' ? 1 : 0,
      clientX: Math.round(r.x + r.width / 2),
      clientY: Math.round(r.y + r.height / 2),
    }));
  }
  function fireMouse(el, type) {
    const r = el.getBoundingClientRect();
    el.dispatchEvent(new MouseEvent(type, {
      bubbles: true, cancelable: true, composed: true, button: 0,
      buttons: type === 'mousedown' ? 1 : 0,
      clientX: Math.round(r.x + r.width / 2),
      clientY: Math.round(r.y + r.height / 2),
    }));
  }
  function clickEl(el) {
    firePointer(el, 'pointerover');
    firePointer(el, 'pointermove');
    firePointer(el, 'pointerdown');
    fireMouse(el, 'mousedown');
    firePointer(el, 'pointerup');
    fireMouse(el, 'mouseup');
    el.click();
  }
  function setField(idx, val) {
    const els = Array.from(document.querySelectorAll('input, textarea'));
    const el = els[idx];
    if (!el) return { error: 'no element at ' + idx };
    const proto = el.tagName === 'TEXTAREA'
      ? window.HTMLTextAreaElement.prototype
      : window.HTMLInputElement.prototype;
    const setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
    setter.call(el, val);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
    return { ok: true, val: el.value, ph: el.placeholder || '' };
  }

  // 1. name
  log.push('name: ' + JSON.stringify(setField(0, 'http-8080')));

  // 2. port to open
  log.push('port: ' + JSON.stringify(setField(1, '8080')));

  await sleep(300);

  // 3. open the server select
  const selectBtn = Array.from(document.querySelectorAll('button'))
    .find((b) => (b.textContent || '').trim().startsWith('选择服务器'));
  if (!selectBtn) {
    return { log, error: 'server select not found', body: document.body.innerText.slice(0, 500) };
  }
  clickEl(selectBtn);
  await sleep(800);

  const options = Array.from(document.querySelectorAll('[role="option"]'))
    .map((e) => (e.textContent || '').trim())
    .filter(Boolean);
  log.push('options: ' + JSON.stringify(options));

  if (options.length === 0) {
    return { log, error: 'no server options - config may not be loaded', body: document.body.innerText.slice(0, 500) };
  }

  // 4. pick the first option
  const opt = Array.from(document.querySelectorAll('[role="option"]'))[0];
  clickEl(opt);
  await sleep(600);

  const inputs = Array.from(document.querySelectorAll('input, textarea')).map((el, i) => ({
    i, tag: el.tagName, ph: el.placeholder || '', val: (el.value || '').slice(0, 30),
  }));

  return {
    log,
    inputs,
    bodyHead: document.body.innerText.slice(0, 700),
    selects: Array.from(document.querySelectorAll('button[role="combobox"], [role="combobox"]'))
      .map((el) => (el.textContent || '').trim().slice(0, 40)),
  };
})()
