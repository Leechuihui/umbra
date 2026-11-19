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

  // Verify the form is complete before submitting.
  const inputs = Array.from(document.querySelectorAll('input, textarea')).map((el) => ({
    ph: el.placeholder || '', val: (el.value || '').slice(0, 30),
  }));
  log.push('inputs: ' + JSON.stringify(inputs));

  const serverBtn = Array.from(document.querySelectorAll('button'))
    .find((b) => (b.textContent || '').includes('127.0.0.1'));
  log.push('server selected: ' + Boolean(serverBtn) + ' -> ' + (serverBtn ? (serverBtn.textContent || '').trim() : 'none'));

  const createBtn = Array.from(document.querySelectorAll('button'))
    .find((b) => (b.textContent || '').trim() === '创建');
  if (!createBtn) {
    return { log, error: '创建 button not found', body: document.body.innerText.slice(0, 600) };
  }

  log.push('create disabled: ' + createBtn.disabled);
  if (createBtn.disabled) {
    return { log, error: 'create button is disabled - form incomplete' };
  }

  clickEl(createBtn);
  await sleep(3000);

  return {
    log,
    bodyHead: document.body.innerText.slice(0, 800),
    buttons: Array.from(document.querySelectorAll('button'))
      .map((b) => (b.textContent || '').trim())
      .filter(Boolean),
  };
})()
