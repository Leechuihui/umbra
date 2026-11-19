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

  const btn = Array.from(document.querySelectorAll('button'))
    .find((b) => (b.textContent || '').trim() === '添加');
  if (!btn) {
    return { log: ['添加 not found'], body: document.body.innerText.slice(0, 400) };
  }
  clickEl(btn);
  await sleep(1200);

  const inputs = Array.from(document.querySelectorAll('input, textarea')).map((el, i) => ({
    i, tag: el.tagName, type: el.type || '',
    ph: el.placeholder || '', val: (el.value || '').slice(0, 30),
  }));

  const selects = Array.from(document.querySelectorAll('[role="combobox"], button[role="combobox"], [data-slot="select-trigger"]')).map((el, i) => ({
    i, tag: el.tagName, text: (el.textContent || '').trim().slice(0, 30),
  }));

  return {
    log,
    bodyHead: document.body.innerText.slice(0, 700),
    inputs,
    selects,
    buttons: Array.from(document.querySelectorAll('button'))
      .map((b) => (b.textContent || '').trim())
      .filter(Boolean),
  };
})()
