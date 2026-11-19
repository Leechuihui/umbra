(() => {
  const txt = (el) => (el.textContent || '').trim();

  const all = Array.from(document.querySelectorAll('*'));
  const paletteCandidates = all.filter((el) => {
    const t = txt(el);
    return t.includes('输入命令或搜索') && el.children.length < 12;
  });

  const info = paletteCandidates.slice(0, 6).map((el) => ({
    tag: el.tagName,
    cls: (el.className || '').toString().slice(0, 120),
    role: el.getAttribute('role') || '',
    dataState: el.getAttribute('data-state') || '',
    childCount: el.children.length,
    text: txt(el).slice(0, 80),
  }));

  const dialogs = Array.from(
    document.querySelectorAll('[role="dialog"], [data-radix-portal], [data-state="open"]')
  ).map((el) => ({
    tag: el.tagName,
    role: el.getAttribute('role') || '',
    cls: (el.className || '').toString().slice(0, 100),
    text: txt(el).slice(0, 60),
  }));

  const triggers = Array.from(
    document.querySelectorAll('[data-state], [aria-haspopup], [role="menuitem"]')
  ).map((el) => ({
    tag: el.tagName,
    text: txt(el).slice(0, 20),
    state: el.getAttribute('data-state') || '',
    haspopup: el.getAttribute('aria-haspopup') || '',
    role: el.getAttribute('role') || '',
  })).slice(0, 20);

  return { paletteCandidates: info, dialogs, triggers };
})()