(() => {
  const txt = (el) => (el.textContent || '').trim();
  const buttons = Array.from(document.querySelectorAll('button'))
    .map((b, i) => ({ i, text: txt(b).slice(0, 40), title: b.getAttribute('title') || '', aria: b.getAttribute('aria-label') || '' }))
    .filter((b) => b.text || b.title || b.aria);
  const inputs = Array.from(document.querySelectorAll('input, textarea'))
    .map((el, i) => ({ i, tag: el.tagName, type: el.type || '', ph: el.placeholder || '', val: (el.value || '').slice(0, 30) }));
  return {
    title: document.title,
    bodyLen: document.body.innerText.length,
    bodyHead: document.body.innerText.slice(0, 600),
    buttonCount: buttons.length,
    buttons: buttons.slice(0, 40),
    inputCount: inputs.length,
    inputs: inputs.slice(0, 20),
  };
})()