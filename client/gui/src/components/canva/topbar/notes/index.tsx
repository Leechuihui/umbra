import { useEffect, useMemo, useState } from "react";
import { FilePlus2, NotebookPen, Search, Trash2, X } from "lucide-react";
import { usePanelT } from "@/i18n/panels/hook";

/**
 * UMBRA original engagement notebook.
 *
 * Lightweight operator notes stored locally (localStorage), designed to keep
 * engagement context — credential hints, host findings, TODOs — beside the
 * main workspaces without touching any team server.
 */

const STORAGE_KEY = "umbra-notes";

type Note = {
  id: string;
  title: string;
  body: string;
  updatedAt: number;
};

function readNotes(): Note[] {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(
      (n): n is Note =>
        !!n && typeof n.id === "string" && typeof n.title === "string" && typeof n.body === "string",
    );
  } catch {
    return [];
  }
}

function writeNotes(notes: Note[]) {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(notes));
  } catch {
    /* ignore quota errors */
  }
}

function makeId() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

export default function NotesPanel() {
  const t = usePanelT("notes");
  const [notes, setNotes] = useState<Note[]>(() => readNotes());
  const [activeId, setActiveId] = useState<string | null>(null);
  const [query, setQuery] = useState("");

  useEffect(() => {
    writeNotes(notes);
  }, [notes]);

  const active = notes.find((n) => n.id === activeId) ?? null;

  const visible = useMemo(() => {
    const q = query.trim().toLowerCase();
    const sorted = [...notes].sort((a, b) => b.updatedAt - a.updatedAt);
    if (!q) return sorted;
    return sorted.filter(
      (n) => n.title.toLowerCase().includes(q) || n.body.toLowerCase().includes(q),
    );
  }, [notes, query]);

  const createNote = () => {
    const note: Note = {
      id: makeId(),
      title: t("notes.untitled"),
      body: "",
      updatedAt: Date.now(),
    };
    setNotes((prev) => [note, ...prev]);
    setActiveId(note.id);
  };

  const patchActive = (patch: Partial<Pick<Note, "title" | "body">>) => {
    if (!activeId) return;
    setNotes((prev) =>
      prev.map((n) =>
        n.id === activeId ? { ...n, ...patch, updatedAt: Date.now() } : n,
      ),
    );
  };

  const deleteActive = () => {
    if (!activeId) return;
    setNotes((prev) => prev.filter((n) => n.id !== activeId));
    setActiveId(null);
  };

  return (
    <div className="flex h-full bg-[#171717] text-[#d4d4d4] text-[12px] select-none overflow-hidden">
      <div className="w-[15rem] shrink-0 flex flex-col border-r border-[#252525] min-h-0">
        <div className="flex items-center gap-1.5 px-3 py-2.5 border-b border-[#252525] shrink-0">
          <NotebookPen size={14} className="umbra-accent-text" />
          <span className="text-[13px] font-semibold text-[#cecece] flex-1">{t("notes.title")}</span>
          <button
            type="button"
            onClick={createNote}
            title={t("notes.new")}
            className="button-default p-1 rounded text-[#888] hover:text-[#d4d4d4] hover:bg-[#262626] cursor-pointer"
          >
            <FilePlus2 size={13} />
          </button>
        </div>
        <div className="p-2 shrink-0">
          <div className="relative">
            <Search size={12} className="absolute left-2 top-1/2 -translate-y-1/2 text-[#555]" />
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={t("notes.searchPlaceholder")}
              className="w-full !h-[26px] !min-h-[26px] !pl-7 text-[12px]"
            />
          </div>
        </div>
        <div className="flex-1 min-h-0 overflow-y-auto px-1.5 pb-2">
          {visible.length === 0 ? (
            <div className="px-2 py-6 text-center text-[11px] text-[#555]">{t("notes.empty")}</div>
          ) : (
            visible.map((n) => (
              <button
                key={n.id}
                type="button"
                onClick={() => setActiveId(n.id)}
                className={`w-full text-left rounded px-2 py-1.5 mb-0.5 cursor-pointer transition-colors ${
                  n.id === activeId
                    ? "bg-[#262626] text-[#e0e0e0]"
                    : "text-[#a0a0a0] hover:bg-[#1e1e1e]"
                }`}
              >
                <div className="truncate text-[12px]">{n.title || t("notes.untitled")}</div>
                <div className="truncate text-[10.5px] text-[#5a5a5a]">
                  {new Date(n.updatedAt).toLocaleDateString()}
                </div>
              </button>
            ))
          )}
        </div>
      </div>

      <div className="flex-1 min-w-0 flex flex-col min-h-0">
        {active ? (
          <>
            <div className="flex items-center gap-2 px-3 py-2 border-b border-[#252525] shrink-0">
              <input
                value={active.title}
                onChange={(e) => patchActive({ title: e.target.value })}
                placeholder={t("notes.untitled")}
                className="flex-1 !h-[28px] !min-h-[28px] !bg-transparent !border-transparent text-[13.5px] font-medium"
              />
              <button
                type="button"
                onClick={deleteActive}
                title={t("notes.delete")}
                className="button-default p-1 rounded text-[#888] hover:text-[#c97070] hover:bg-[#262626] cursor-pointer"
              >
                <Trash2 size={13} />
              </button>
              <button
                type="button"
                onClick={() => setActiveId(null)}
                title={t("notes.close")}
                className="button-default p-1 rounded text-[#888] hover:text-[#d4d4d4] hover:bg-[#262626] cursor-pointer"
              >
                <X size={13} />
              </button>
            </div>
            <textarea
              value={active.body}
              onChange={(e) => patchActive({ body: e.target.value })}
              placeholder={t("notes.bodyPlaceholder")}
              spellCheck={false}
              className="flex-1 min-h-0 w-full resize-none !rounded-none !border-0 bg-[#141414] px-3 py-2.5 text-[13px] leading-relaxed font-mona-mono outline-none"
            />
          </>
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center gap-2 text-[#555]">
            <NotebookPen size={26} className="opacity-40" />
            <span className="text-[12px]">{t("notes.selectHint")}</span>
          </div>
        )}
      </div>
    </div>
  );
}
