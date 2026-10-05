import React, { useEffect, useLayoutEffect, useRef, useState } from "react";
import { Pause, Play, SkipBack, SkipForward, Volume2, VolumeX, ArrowRight } from "lucide-react";
import { AYAT_KURSI } from "../data/ayatKursi";

interface FloatingAyahOverlayProps {
  isPlaying: boolean;
  onTogglePlay: () => void;
  onRestart: () => void;
  currentTime: number;
  duration: number;
  onSeek: (time: number) => void;
  isMuted: boolean;
  onToggleMute: () => void;
}

// Surrounding ayahs of Al-Baqarah, joined into one continuous justified surah text.
const BEFORE = "يَٰٓأَيُّهَا ٱلَّذِينَ ءَامَنُوٓا۟ أَنفِقُوا۟ مِمَّا رَزَقْنَٰكُم مِّن قَبْلِ أَن يَأْتِىَ يَوْمٌۭ لَّا بَيْعٌۭ فِيهِ وَلَا خُلَّةٌۭ وَلَا شَفَٰعَةٌۭ ۗ";
const AFTER = "لَآ إِكْرَاهَ فِى ٱلدِّينِ ۖ قَد تَّبَيَّنَ ٱلرُّشْدُ مِنَ ٱلْغَىِّ ۚ فَمَن يَكْفُرْ بِٱلطَّٰغُوتِ وَيُؤْمِنۢ بِٱللَّهِ";
const LINE = 64; // px; taller lines give the word box more presence
const VIEWPORT = LINE * 3;
const PAD = (VIEWPORT - LINE) / 2;
const marker = (n: string) => `\u00A0﴿${n}﴾`;

interface Box { left: number; top: number; width: number; height: number }

export const FloatingAyahOverlay: React.FC<FloatingAyahOverlayProps> = ({
  isPlaying,
  onTogglePlay,
  onRestart,
  currentTime,
  duration,
  isMuted,
  onToggleMute,
}) => {
  const viewportRef = useRef<HTMLDivElement>(null);
  const textRef = useRef<HTMLDivElement>(null);
  const wordRefs = useRef<(HTMLSpanElement | null)[]>([]);
  const [isHovered, setIsHovered] = useState(false);
  const [wordBox, setWordBox] = useState<Box | null>(null);
  const [litWords, setLitWords] = useState<Set<number>>(new Set());

  const currentMs = currentTime * 1000;
  const tokens = AYAT_KURSI.tokens;

  // Active timed word; between words the previous one stays lit, as in the native app.
  let displayIndex = tokens.findIndex(
    (t) => t.is_spoken && t.start_ms !== null && t.end_ms !== null && currentMs >= t.start_ms && currentMs <= t.end_ms,
  );
  if (displayIndex === -1) {
    for (let i = tokens.length - 1; i >= 0; i--) {
      const t = tokens[i];
      if (t && t.is_spoken && t.start_ms !== null && currentMs >= t.start_ms) {
        displayIndex = i;
        break;
      }
    }
  }
  // Before the first word, light the first spoken word's line so the ayah never flashes bright.
  if (displayIndex === -1) displayIndex = tokens.findIndex((t) => t.is_spoken);

  // Measure the active word and the words sharing its line. Words are plain inline text so the
  // browser can justify them; their geometry comes from client rects, divided by the preview's
  // CSS scale so the transform does not distort the layout coordinates.
  useLayoutEffect(() => {
    const text = textRef.current;
    const word = wordRefs.current[displayIndex];
    if (!text || !word) return;
    const base = text.getBoundingClientRect();
    const scale = base.width / text.offsetWidth || 1;
    const rectOf = (el: HTMLElement) => {
      const r = el.getClientRects()[0] ?? el.getBoundingClientRect();
      return {
        left: (r.left - base.left) / scale,
        top: (r.top - base.top) / scale,
        width: r.width / scale,
        height: r.height / scale,
      };
    };
    const active = rectOf(word);
    const mid = active.top + active.height / 2;
    setWordBox({ left: active.left, top: mid - LINE / 2, width: active.width, height: LINE });
    const lit = new Set<number>();
    wordRefs.current.forEach((el, idx) => {
      if (el && Math.abs(rectOf(el).top + rectOf(el).height / 2 - mid) < LINE / 2) lit.add(idx);
    });
    setLitWords(lit);
  }, [displayIndex]);

  // Keep the active line centered in the viewport, as the native lyric view does.
  useEffect(() => {
    const viewport = viewportRef.current;
    if (!viewport || !wordBox) return;
    viewport.scrollTo({ top: Math.max(0, PAD + wordBox.top + wordBox.height / 2 - viewport.clientHeight / 2), behavior: "smooth" });
  }, [wordBox?.top]);

  const formatTime = (secs: number) => {
    const m = Math.floor(secs / 60);
    const s = Math.floor(secs % 60);
    return `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
  };

  const glide = "transition-[left,top,width,height] duration-[240ms] ease-in-out";
  const textShadow = "0 1px 1px rgba(0,0,0,1), 0 2px 4px rgba(0,0,0,0.9)";

  return (
    <div
      className="absolute bottom-8 right-8 z-40 w-[420px] select-none pointer-events-auto"
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      <div style={{ height: VIEWPORT }} className={`relative rounded-xl overflow-hidden transition-colors duration-150 ${isHovered ? "bg-black/20" : "bg-transparent"}`}>
        {/* Lyric viewport: manual scrolling is disabled, it only follows the recitation. */}
        <div
          ref={viewportRef}
          onClick={onTogglePlay}
          className="absolute inset-0 overflow-hidden mask-radial-fade cursor-pointer"
          title="Click to play or pause"
        >
          <div className="relative" style={{ paddingTop: PAD, paddingBottom: PAD }}>
            <div ref={textRef} dir="rtl" className="relative font-quran text-[31px] text-justify tracking-wide" style={{ lineHeight: `${LINE}px`, textShadow }}>
              {/* The word box and its underline glide behind the text. */}
              <div
                aria-hidden
                className={`absolute pointer-events-none ${glide}`}
                style={{
                  left: wordBox?.left ?? 0,
                  top: wordBox?.top ?? 0,
                  width: wordBox?.width ?? 0,
                  height: wordBox?.height ?? 0,
                  background: "rgba(255,255,255,0.18)",
                  borderBottom: "2px solid #fff",
                  borderRadius: 4,
                  opacity: wordBox ? 1 : 0,
                }}
              />
              <span className="relative text-white/30">{BEFORE}{marker("٢٥٤")} </span>
              {tokens.map((item, idx) => (
                <React.Fragment key={idx}>
                  <span
                    ref={(el) => { wordRefs.current[idx] = el; }}
                    className="relative transition-colors duration-[280ms]"
                    style={{ color: litWords.has(idx) ? "#fff" : "rgba(255,255,255,0.55)" }}
                  >
                    {item.token}
                  </span>{" "}
                </React.Fragment>
              ))}
              <span className="relative text-white">{marker("٢٥٥")}</span>
              <span className="relative text-white/30"> {AFTER}{marker("٢٥٦")}</span>
            </div>
          </div>
        </div>

        {/* Hover chrome overlays the edges of the text; it never reserves layout space. */}
        <div
          className={`absolute inset-x-0 top-0 h-9 px-2 flex items-center justify-between bg-black/40 text-white transition-opacity duration-150 ${isHovered ? "opacity-100" : "opacity-0 pointer-events-none"}`}
        >
          <div className="leading-tight">
            <div className="text-[12px] font-semibold">Al-Baqarah · 255</div>
            <div className="text-[10px] text-white/80">{isPlaying ? "Mishary Rashid Alafasy" : "Click the ayah to play"}</div>
          </div>
          <span className="text-[10px] font-mono text-white/80">{formatTime(currentTime)} / {formatTime(duration || 51.59)}</span>
        </div>

        <div
          className={`absolute inset-x-0 bottom-0 h-8 px-2 flex items-center justify-between bg-black/40 text-white transition-opacity duration-150 ${isHovered ? "opacity-100" : "opacity-0 pointer-events-none"}`}
        >
          <button onClick={(e) => { e.stopPropagation(); onToggleMute(); }} className="p-1 rounded hover:bg-white/10" title={isMuted ? "Unmute" : "Mute"}>
            {isMuted ? <VolumeX className="w-3.5 h-3.5 text-red-400" /> : <Volume2 className="w-3.5 h-3.5" />}
          </button>
          <div className="flex items-center gap-1">
            <button onClick={(e) => { e.stopPropagation(); onRestart(); }} className="p-1 rounded hover:bg-white/10" title="Restart ayah">
              <SkipBack className="w-3.5 h-3.5 fill-current" />
            </button>
            <button onClick={(e) => { e.stopPropagation(); onTogglePlay(); }} className="p-1 rounded hover:bg-white/10" title={isPlaying ? "Pause" : "Play"}>
              {isPlaying ? <Pause className="w-3.5 h-3.5 fill-current" /> : <Play className="w-3.5 h-3.5 fill-current" />}
            </button>
            <button className="p-1 rounded text-white/40 cursor-default" title="Next ayah (app only)" disabled>
              <SkipForward className="w-3.5 h-3.5 fill-current" />
            </button>
          </div>
          <div className="flex items-center gap-1 text-[10px] font-mono text-white/80" title="Playback mode">
            <ArrowRight className="w-3.5 h-3.5" /> 255/286
          </div>
        </div>
      </div>
    </div>
  );
};
