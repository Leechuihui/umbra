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

  // The dropdown should already be open with one option visible.
  let opts = Array.from(document.querySelectorAll('[role="option"]'));
  log.push('options visible: ' + opts.length);

  if (opts.length === 0) {
    // Re-open the select.
    const trigger = Array.from(document.querySelectorAll('button'))
      .find((b) => (b.textContent || '').trim().startsWith('选择服务器'));
    if (!trigger) return { log, error: 'select trigger not found' };
    clickEl(trigger);
    await sleep(700);
    opts = Array.from(document.querySelectorAll('[role="option"]'));
    log.push('options after reopen: ' + opts.length);
  }

  if (opts.length === 0) {
    return { log, error: 'still no options' };
  }

  const opt = opts[0];
  const label = (opt.textContent || '').trim();
  log.push('clicking option: ' + label);

  // Radix SelectItem commits on pointerup, but a full sequence is safest.
  opt.scrollIntoView({ block: 'nearest' });
  await sleep(150);

  firePointer(opt, 'pointerover');
  firePointer(opt, 'pointermove');
  firePointer(opt, 'pointerdown');
  fireMouse(opt, 'mousedown');
  await sleep(80);
  firePointer(opt, 'pointerup');
  fireMouse(opt, 'mouseup');
  await sleep(80);
  opt.click();

  await sleep(900);

  const selects = Array.from(document.querySelectorAll('button'))
    .map((b) => (b.textContent || '').trim())
    .filter((t) => t.includes('127.0.0.1') || t.startsWith('选择服务器') || t.includes('admin'));

  return {
    log,
    dropdownClosed: document.querySelectorAll('[role="option"]').length === 0,
    serverTriggerText: selects,
    bodyHead: document.body.innerText.slice(0, 700),
  };
})()
