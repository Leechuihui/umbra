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

  // Find the "服务器" menu item (text may include a shortcut suffix).
  const items = Array.from(document.querySelectorAll('[role="menuitem"]'));
  const target = items.find((e) => (e.textContent || '').trim().startsWith('服务器'));
  if (!target) {
    return { log: ['服务器 item not found'], available: items.map((e) => (e.textContent || '').trim()) };
  }

  const r = target.getBoundingClientRect();
  log.push(`服务器 item rect: x=${Math.round(r.x)} y=${Math.round(r.y)} w=${Math.round(r.width)} h=${Math.round(r.height)}`);

  firePointer(target, 'pointerover');
  firePointer(target, 'pointermove');
  firePointer(target, 'pointerdown');
  fireMouse(target, 'mousedown');
  firePointer(target, 'pointerup');
  fireMouse(target, 'mouseup');
  target.click();

  await sleep(1200);

  return {
    log,
    menuStillOpen: Boolean(document.querySelector('[role="menu"]')),
    bodyLen: document.body.innerText.length,
    bodyHead: document.body.innerText.slice(0, 500),
    buttons: Array.from(document.querySelectorAll('button'))
      .map((b) => (b.textContent || '').trim())
      .filter(Boolean)
      .slice(0, 30),
  };
})()
