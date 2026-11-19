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

  const triggers = Array.from(document.querySelectorAll('[aria-haspopup="menu"]'));
  const umbra = triggers.find((e) => (e.textContent || '').trim() === 'UMBRA');
  if (!umbra) return { log, error: 'UMBRA trigger not found' };
  clickEl(umbra);
  await sleep(700);

  const items = Array.from(document.querySelectorAll('[role="menuitem"]'));
  log.push('menu items: ' + items.map((e) => (e.textContent || '').trim()).join(' | '));

  const target = items.find((e) => (e.textContent || '').trim().startsWith('监听器'));
  if (!target) return { log, error: 'listener item not found' };
  clickEl(target);
  await sleep(1200);

  const buttons = Array.from(document.querySelectorAll('button'))
    .map((b) => (b.textContent || '').trim())
    .filter(Boolean);

  return {
    log,
    menuClosed: !document.querySelector('[role="menu"]'),
    bodyHead: document.body.innerText.slice(0, 500),
    buttons,
  };
})()
