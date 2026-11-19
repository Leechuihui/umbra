(async () => {
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const log = [];

  // Radix DropdownMenuTrigger listens for pointerdown, not click.
  function firePointer(el, type) {
    const r = el.getBoundingClientRect();
    const opts = {
      bubbles: true,
      cancelable: true,
      composed: true,
      pointerId: 1,
      pointerType: 'mouse',
      isPrimary: true,
      button: 0,
      buttons: type === 'pointerdown' ? 1 : 0,
      clientX: Math.round(r.x + r.width / 2),
      clientY: Math.round(r.y + r.height / 2),
    };
    el.dispatchEvent(new PointerEvent(type, opts));
  }

  function fireMouse(el, type) {
    const r = el.getBoundingClientRect();
    el.dispatchEvent(new MouseEvent(type, {
      bubbles: true,
      cancelable: true,
      composed: true,
      button: 0,
      buttons: type === 'mousedown' ? 1 : 0,
      clientX: Math.round(r.x + r.width / 2),
      clientY: Math.round(r.y + r.height / 2),
    }));
  }

  // 1. locate the UMBRA menu trigger
  const triggers = Array.from(document.querySelectorAll('[aria-haspopup="menu"]'));
  log.push('menu triggers: ' + triggers.map((e) => (e.textContent || '').trim()).join(' | '));

  const umbra = triggers.find((e) => (e.textContent || '').trim() === 'UMBRA');
  if (!umbra) {
    return { log, error: 'UMBRA trigger not found' };
  }

  const rect = umbra.getBoundingClientRect();
  log.push(`UMBRA trigger rect: x=${Math.round(rect.x)} y=${Math.round(rect.y)} w=${Math.round(rect.width)} h=${Math.round(rect.height)}`);

  // 2. open it with a full pointer/mouse sequence
  firePointer(umbra, 'pointerover');
  firePointer(umbra, 'pointerenter');
  firePointer(umbra, 'pointerdown');
  fireMouse(umbra, 'mousedown');
  firePointer(umbra, 'pointerup');
  fireMouse(umbra, 'mouseup');
  umbra.click();

  await sleep(700);

  // 3. read what appeared
  const items = Array.from(document.querySelectorAll('[role="menuitem"]'))
    .map((e) => (e.textContent || '').trim())
    .filter(Boolean);

  const menuEl = document.querySelector('[role="menu"]');
  log.push('menu element present: ' + Boolean(menuEl));
  log.push('menuitem count: ' + items.length);

  return {
    log,
    items,
    triggerState: umbra.getAttribute('data-state'),
    bodyLen: document.body.innerText.length,
  };
})()
