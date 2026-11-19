(async () => {
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const log = [];

  // 1. Close the command palette if it is open.
  document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', keyCode: 27, bubbles: true }));
  document.body.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', keyCode: 27, bubbles: true }));
  await sleep(400);
  log.push('after escape, bodyLen=' + document.body.innerText.length);

  // 2. Find the UMBRA menu button in the top bar.
  const all = Array.from(document.querySelectorAll('button, [role="menuitem"], [role="button"]'));
  const menuBtns = all
    .map((el, i) => ({ i, text: (el.textContent || '').trim().slice(0, 20), title: el.getAttribute('title') || '', aria: el.getAttribute('aria-label') || '' }))
    .filter((b) => b.text === 'UMBRA' || b.aria === 'UMBRA');
  log.push('UMBRA menu buttons: ' + JSON.stringify(menuBtns));

  return { log, bodyHead: document.body.innerText.slice(0, 400) };
})()